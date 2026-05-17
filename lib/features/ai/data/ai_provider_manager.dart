import 'package:flutter/foundation.dart';
import 'package:skripsi_manager/core/secrets.dart';
import 'package:skripsi_manager/features/ai/data/ai_persona.dart';
import 'package:skripsi_manager/features/ai/data/ai_provider.dart';
import 'package:skripsi_manager/features/ai/data/ai_settings_repository.dart';
import 'package:skripsi_manager/features/ai/data/deepseek_service.dart';
import 'package:skripsi_manager/features/ai/data/gemini_service.dart';
import 'package:skripsi_manager/features/ai/data/openrouter_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Gemini wrapper that adapts existing GeminiService to the AiProvider interface.
// The original GeminiService is UNCHANGED — we simply delegate to it.
// ─────────────────────────────────────────────────────────────────────────────

class _GeminiProviderAdapter extends AiProvider {
  final GeminiService _svc;
  _GeminiProviderAdapter(this._svc);

  @override
  String get providerName => 'Gemini';

  @override
  bool checkAvailability() => kGeminiApiKeys.isNotEmpty;

  @override
  Future<String> generateResponse(String userPrompt) {
    // PENTING: Gunakan sendPrompt() (bukan sendPromptWithFallback()) agar
    // fallback ke OpenRouter TIDAK terjadi di dalam GeminiService.
    // Fallback harus dikelola oleh AiProviderManager, bukan GeminiService.
    // Tambahkan geminiPrefix secara manual karena sendPrompt tidak inject prefix.
    final promptWithPersona = '${AiPersona.geminiPrefix}$userPrompt';
    return _svc.sendPrompt(promptWithPersona);
  }

  @override
  bool isSuccessResponse(String result) => _svc.isSuccess(result);
}

// ─────────────────────────────────────────────────────────────────────────────
// DeepSeek wrapper — adds native multi-turn history support.
// ─────────────────────────────────────────────────────────────────────────────

class _DeepSeekProviderAdapter extends AiProvider {
  final DeepSeekProvider _svc;
  _DeepSeekProviderAdapter(this._svc);

  @override
  String get providerName => 'DeepSeek';

  @override
  bool checkAvailability() => _svc.checkAvailability();

  @override
  Future<String> generateResponse(String userPrompt) =>
      _svc.generateResponse(userPrompt);

  /// Native multi-turn for DeepSeek.
  Future<String> generateResponseWithHistory(
    List<Map<String, String>> fullHistory,
  ) => _svc.generateResponseWithHistory(fullHistory);
}

// ─────────────────────────────────────────────────────────────────────────────
// OpenRouter wrapper adapting existing OpenRouterService to AiProvider interface.
// ─────────────────────────────────────────────────────────────────────────────

class _OpenRouterProviderAdapter extends AiProvider {
  final OpenRouterService _svc;
  final String dynamicKey; // key from secure storage (overrides secrets.dart)

  _OpenRouterProviderAdapter(this._svc, {this.dynamicKey = ''});

  @override
  String get providerName => 'OpenRouter';

  @override
  bool checkAvailability() {
    // Accept if either the static secrets.dart key or user's dynamic key is set
    return kOpenRouterApiKey.isNotEmpty || dynamicKey.isNotEmpty;
  }

  @override
  Future<String> generateResponse(String userPrompt) {
    return _svc.sendPrompt(userPrompt);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AiProviderManager — central orchestrator with priority + auto-fallback.
// ─────────────────────────────────────────────────────────────────────────────

/// Manages multi-provider AI access with priority fallback.
///
/// Priority (when autoFallback = true):
///   1. Preferred provider (default: Gemini)
///   2. DeepSeek
///   3. OpenRouter
///
/// If autoFallback = false: only the preferred provider is tried.
///
/// This class is a singleton created by [aiProviderManagerProvider].
class AiProviderManager {
  final GeminiService _geminiService;
  final OpenRouterService _openRouterService;
  final AiSettingsRepository _settingsRepo;

  AiProviderManager({
    GeminiService? geminiService,
    OpenRouterService? openRouterService,
    AiSettingsRepository? settingsRepo,
  })  : _geminiService = geminiService ?? GeminiService(),
        _openRouterService = openRouterService ?? OpenRouterService(),
        _settingsRepo = settingsRepo ?? AiSettingsRepository();

  // ── Public entry point ───────────────────────────────────────────────────────

  /// Send [userPrompt] through the provider chain.
  ///
  /// Behaviour:
  /// - Loads settings from secure storage.
  /// - Starts with the preferred provider.
  /// - Falls back down the chain if [settings.autoFallback] is true.
  /// - Returns a user-displayable string (success or error in Indonesian).
  Future<String> sendPromptWithFallback(String userPrompt) async {
    final settings = await _settingsRepo.loadAll();
    final chain = _buildProviderChain(settings);

    if (chain.isEmpty) {
      return 'Error: Tidak ada AI provider yang tersedia. Harap konfigurasi API key terlebih dahulu.';
    }

    String lastError = '';

    for (final provider in chain) {
      if (!provider.checkAvailability()) {
        debugPrint('[AiManager] ${provider.providerName} tidak tersedia (key kosong), skip.');
        continue;
      }

      debugPrint('[AiManager] Mencoba provider: ${provider.providerName}');
      final stopwatch = Stopwatch()..start();

      final result = await provider.generateResponse(userPrompt);

      stopwatch.stop();
      debugPrint(
        '[AiManager] ${provider.providerName} selesai dalam ${stopwatch.elapsedMilliseconds}ms',
      );

      if (provider.isSuccessResponse(result)) {
        debugPrint('[AiManager] ✓ Respons sukses dari ${provider.providerName}');
        return result;
      }

      // Provider failed — log and try next
      debugPrint(
        '[AiManager] ✗ ${provider.providerName} gagal: ${result.length > 80 ? result.substring(0, 80) : result}',
      );
      lastError = result;

      if (!settings.autoFallback) {
        debugPrint('[AiManager] Auto-fallback dinonaktifkan, berhenti.');
        break;
      }

      debugPrint('[AiManager] → Fallback ke provider berikutnya...');
    }

    // All providers failed
    return lastError.isNotEmpty
        ? lastError
        : 'AI sedang tidak tersedia saat ini. Silakan coba lagi nanti.';
  }

  /// Expose the Gemini chunk helper (used by existing ai_page.dart).
  List<String> chunkText(String text) => _geminiService.chunkText(text);

  /// Send a prompt with full conversation context.
  ///
  /// [chatHistory] — structured list of prior messages:
  ///   [{'role':'user','content':'...'}, {'role':'assistant','content':'...'}, ...]
  /// [newUserPrompt] — the latest user message to append.
  ///
  /// Each provider receives history in the best format it supports:
  /// - DeepSeek: native multi-turn messages array
  /// - Gemini / OpenRouter: flattened context string (existing behaviour)
  Future<String> sendWithHistory({
    required List<Map<String, String>> chatHistory,
    required String newUserPrompt,
  }) async {
    final settings = await _settingsRepo.loadAll();
    final chain = _buildProviderChain(settings);

    if (chain.isEmpty) {
      return 'Error: Tidak ada AI provider yang tersedia.';
    }

    // Build the full history including the new user message
    final fullHistory = [
      ...chatHistory,
      {'role': 'user', 'content': newUserPrompt},
    ];

    String lastError = '';

    for (final provider in chain) {
      if (!provider.checkAvailability()) {
        debugPrint('[AiManager] ${provider.providerName} tidak tersedia, skip.');
        continue;
      }

      debugPrint('[AiManager] Mencoba provider (history): ${provider.providerName}');
      final sw = Stopwatch()..start();
      String result;

      // DeepSeek natively supports multi-turn messages
      if (provider is _DeepSeekProviderAdapter) {
        result = await provider.generateResponseWithHistory(fullHistory);
      } else {
        // Gemini & OpenRouter: flatten history into a single prompt string
        result = await provider.generateResponse(
          _flattenHistory(chatHistory, newUserPrompt),
        );
      }

      sw.stop();
      debugPrint('[AiManager] ${provider.providerName} selesai dalam ${sw.elapsedMilliseconds}ms');

      if (provider.isSuccessResponse(result)) {
        debugPrint('[AiManager] ✓ Respons sukses dari ${provider.providerName}');
        return result;
      }

      debugPrint('[AiManager] ✗ ${provider.providerName} gagal: ${result.length > 80 ? result.substring(0, 80) : result}');
      lastError = result;

      if (!settings.autoFallback) break;
      debugPrint('[AiManager] → Fallback ke provider berikutnya...');
    }

    return lastError.isNotEmpty
        ? lastError
        : 'AI sedang tidak tersedia saat ini. Silakan coba lagi nanti.';
  }

  /// Flatten chat history into a single context string for providers
  /// that don't support native multi-turn messages (Gemini, OpenRouter).
  String _flattenHistory(
    List<Map<String, String>> history,
    String newUserPrompt,
  ) {
    final buf = StringBuffer();
    buf.writeln('Riwayat percakapan:');
    for (final msg in history) {
      final label = msg['role'] == 'user' ? 'Mahasiswa' : 'Dosen Pembimbing';
      buf.writeln('$label: ${msg['content']}');
    }
    buf.writeln('\nMahasiswa: $newUserPrompt');
    buf.writeln('\nBerikan jawaban sebagai dosen pembimbing akademik yang solutif dan profesional.');
    return buf.toString();
  }

  // ── Provider chain builder ────────────────────────────────────────────────────

  List<AiProvider> _buildProviderChain(AiSettings settings) {
    final gemini   = _GeminiProviderAdapter(_geminiService);
    final deepSeek = _DeepSeekProviderAdapter(
      DeepSeekProvider(apiKey: settings.deepSeekApiKey),
    );
    final orKey    = settings.openRouterApiKey.isNotEmpty
        ? settings.openRouterApiKey
        : kOpenRouterApiKey;
    final openRouter = _OpenRouterProviderAdapter(
      _openRouterService,
      dynamicKey: orKey,
    );

    // Build ordered list: preferred first, then fallbacks
    final List<AiProvider> chain = [];

    switch (settings.preferredProvider) {
      case AiProviderType.gemini:
        chain.addAll([gemini, deepSeek, openRouter]);
      case AiProviderType.deepSeek:
        chain.addAll([deepSeek, gemini, openRouter]);
      case AiProviderType.openRouter:
        chain.addAll([openRouter, gemini, deepSeek]);
    }

    return chain;
  }

  // ── Convenience: inject AiPersona prefix when needed ────────────────────────

  /// Build a full academic prompt (matches existing behaviour in ai_page.dart).
  static String buildAcademicPrompt(String rawPrompt) {
    return '${AiPersona.geminiPrefix}$rawPrompt';
  }
}
