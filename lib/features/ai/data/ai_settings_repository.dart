import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:skripsi_manager/core/secrets.dart';
import 'package:skripsi_manager/features/ai/data/ai_provider.dart';

/// Keys for secure storage.
class _Keys {
  static const deepSeekApiKey   = 'ai_deepseek_api_key';
  static const openRouterApiKey = 'ai_openrouter_api_key';
  static const preferredProvider = 'ai_preferred_provider';
  static const autoFallback     = 'ai_auto_fallback';
}

/// Persists AI provider settings using [FlutterSecureStorage].
///
/// • Uses the SAME secure storage instance already in the project
///   (flutter_secure_storage is already a pubspec dependency).
/// • Never migrates the database — settings are stored as key-value pairs.
class AiSettingsRepository {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── DeepSeek ─────────────────────────────────────────────────────────────────

  Future<String> getDeepSeekApiKey() async {
    try {
      final stored = await _storage.read(key: _Keys.deepSeekApiKey);
      // If user has set a key, use it; otherwise fall back to compile-time default
      return (stored != null && stored.isNotEmpty) ? stored : kDeepSeekApiKey;
    } catch (e) {
      debugPrint('[AiSettings] getDeepSeekApiKey error: $e');
      return kDeepSeekApiKey;
    }
  }

  Future<void> saveDeepSeekApiKey(String key) async {
    try {
      await _storage.write(key: _Keys.deepSeekApiKey, value: key.trim());
    } catch (e) {
      debugPrint('[AiSettings] saveDeepSeekApiKey error: $e');
    }
  }

  // ── OpenRouter ───────────────────────────────────────────────────────────────

  Future<String> getOpenRouterApiKey() async {
    try {
      return await _storage.read(key: _Keys.openRouterApiKey) ?? '';
    } catch (e) {
      debugPrint('[AiSettings] getOpenRouterApiKey error: $e');
      return '';
    }
  }

  Future<void> saveOpenRouterApiKey(String key) async {
    try {
      await _storage.write(key: _Keys.openRouterApiKey, value: key.trim());
    } catch (e) {
      debugPrint('[AiSettings] saveOpenRouterApiKey error: $e');
    }
  }

  // ── Preferred provider ────────────────────────────────────────────────────────

  Future<AiProviderType> getPreferredProvider() async {
    try {
      final raw = await _storage.read(key: _Keys.preferredProvider);
      return AiProviderType.fromString(raw ?? '');
    } catch (e) {
      debugPrint('[AiSettings] getPreferredProvider error: $e');
      return AiProviderType.gemini;
    }
  }

  Future<void> savePreferredProvider(AiProviderType type) async {
    try {
      await _storage.write(key: _Keys.preferredProvider, value: type.name);
    } catch (e) {
      debugPrint('[AiSettings] savePreferredProvider error: $e');
    }
  }

  // ── Auto fallback toggle ──────────────────────────────────────────────────────

  Future<bool> getAutoFallback() async {
    try {
      final raw = await _storage.read(key: _Keys.autoFallback);
      return raw != 'false'; // default: true
    } catch (e) {
      debugPrint('[AiSettings] getAutoFallback error: $e');
      return true;
    }
  }

  Future<void> saveAutoFallback(bool enabled) async {
    try {
      await _storage.write(key: _Keys.autoFallback, value: enabled.toString());
    } catch (e) {
      debugPrint('[AiSettings] saveAutoFallback error: $e');
    }
  }

  // ── Snapshot for UI ───────────────────────────────────────────────────────────

  Future<AiSettings> loadAll() async {
    final results = await Future.wait([
      getDeepSeekApiKey(),
      getOpenRouterApiKey(),
      getPreferredProvider().then((v) => v),
      getAutoFallback().then((v) => v),
    ]);
    return AiSettings(
      deepSeekApiKey: results[0] as String,
      openRouterApiKey: results[1] as String,
      preferredProvider: results[2] as AiProviderType,
      autoFallback: results[3] as bool,
    );
  }
}

/// Value object that groups all AI settings.
class AiSettings {
  final String deepSeekApiKey;
  final String openRouterApiKey;
  final AiProviderType preferredProvider;
  final bool autoFallback;

  const AiSettings({
    required this.deepSeekApiKey,
    required this.openRouterApiKey,
    required this.preferredProvider,
    required this.autoFallback,
  });

  AiSettings copyWith({
    String? deepSeekApiKey,
    String? openRouterApiKey,
    AiProviderType? preferredProvider,
    bool? autoFallback,
  }) {
    return AiSettings(
      deepSeekApiKey: deepSeekApiKey ?? this.deepSeekApiKey,
      openRouterApiKey: openRouterApiKey ?? this.openRouterApiKey,
      preferredProvider: preferredProvider ?? this.preferredProvider,
      autoFallback: autoFallback ?? this.autoFallback,
    );
  }
}
