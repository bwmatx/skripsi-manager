import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:skripsi_manager/core/secrets.dart';
import 'package:skripsi_manager/features/ai/data/ai_persona.dart';
import 'package:skripsi_manager/features/ai/data/openrouter_service.dart';

// ── Sentinels ─────────────────────────────────────────────────────────────────
const _kQuotaExceeded = '__QUOTA_EXCEEDED__';
const _kKeyInvalid    = '__KEY_INVALID__';
const _kKeyDisabled   = '__KEY_DISABLED__';
const _kBaseUrl =
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=';

// ── Service ───────────────────────────────────────────────────────────────────

class GeminiService {
  static bool _isRequestActive = false;

  final _openRouter = OpenRouterService();

  // ── Chunk helper ─────────────────────────────────────────────────────────────

  List<String> chunkText(String text) {
    const chunkSize = 900;
    final chunks = <String>[];
    for (int i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize > text.length) ? text.length : i + chunkSize;
      chunks.add(text.substring(i, end));
    }
    return chunks;
  }

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Tries all Gemini keys in order; on total failure falls back to OpenRouter FREE.
  /// Returns human-readable Indonesian string on all error paths.
  Future<String> sendPromptWithFallback(String userPrompt) async {
    final geminiPrompt = '${AiPersona.geminiPrefix}$userPrompt';
    final geminiResult = await _sendWithKeyRotation(geminiPrompt);

    if (_isSuccess(geminiResult)) return geminiResult;

    debugPrint('[GeminiService] All keys failed ($geminiResult) → OpenRouter...');
    return _openRouter.sendPrompt(userPrompt);
  }

  /// Legacy method — kept for compatibility. Calls key rotation internally.
  Future<String> sendPrompt(String text) async {
    return _sendWithKeyRotation(text);
  }

  // ── Key rotation ──────────────────────────────────────────────────────────────

  /// Try each key in kGeminiApiKeys. Returns content or human-readable error.
  Future<String> _sendWithKeyRotation(String text) async {
    final keys = kGeminiApiKeys;
    if (keys.isEmpty) {
      return 'Error: Tidak ada Gemini API key yang terkonfigurasi.';
    }

    for (int i = 0; i < keys.length; i++) {
      debugPrint('[Gemini] Mencoba key ${i + 1}/${keys.length}');
      final result = await _callWithKey(keys[i], text);

      if (_isFailover(result)) {
        debugPrint('[Gemini] Key ${i + 1} habis/invalid → coba key berikutnya');
        continue;
      }
      return result; // success or non-failover error
    }

    return 'Limit harian semua Gemini API key telah habis.';
  }

  bool _isFailover(String r) =>
      r == _kQuotaExceeded || r == _kKeyInvalid || r == _kKeyDisabled;

  /// Public version — used by AiProviderManager adapter.
  bool isSuccess(String r) => _isSuccess(r);

  bool _isSuccess(String r) {
    if (r.isEmpty) return false;
    const bad = [
      'Error', 'Limit harian', 'Terlalu banyak',
      'Server AI sedang sibuk', 'Koneksi gagal',
    ];
    for (final b in bad) {
      if (r.startsWith(b)) return false;
    }
    if (r.startsWith('{') && r.contains('"error"')) return false;
    return true;
  }

  // ── Single-key HTTP call ──────────────────────────────────────────────────────

  Future<String> _callWithKey(String apiKey, String text) async {
    // Queue requests — avoid concurrent Gemini calls
    while (_isRequestActive) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    _isRequestActive = true;

    int retries = 0;
    String result = 'Error';

    try {
      final uri = Uri.parse('$_kBaseUrl$apiKey');

      while (retries <= 2) {
        await Future.delayed(const Duration(milliseconds: 800));

        try {
          final res = await http.post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': text}
                  ]
                }
              ]
            }),
          ).timeout(const Duration(seconds: 20));

          debugPrint('[Gemini] HTTP ${res.statusCode}');

          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final answer =
                data['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (answer != null && (answer as String).trim().isNotEmpty) {
              result = answer.trim();
            } else {
              result = 'Error: AI tidak memberikan jawaban.';
            }
            break;

          } else if (res.statusCode == 429) {
            final body = res.body.toLowerCase();
            if (body.contains('quota') ||
                body.contains('exceeded') ||
                body.contains('daily') ||
                body.contains('limit')) {
              // Key quota exhausted → try next key
              result = _kQuotaExceeded;
              break;
            }
            // Transient rate limit → retry
            retries++;
            if (retries > 2) {
              result = 'Terlalu banyak permintaan ke Gemini.';
              break;
            }
            await Future.delayed(const Duration(seconds: 4));

          } else if (res.statusCode == 400) {
            final body = res.body.toLowerCase();
            if (body.contains('api_key') || body.contains('invalid')) {
              result = _kKeyInvalid;
            } else {
              result = 'Error: Permintaan tidak valid ke Gemini.';
            }
            break;

          } else if (res.statusCode == 403) {
            result = _kKeyDisabled;
            break;

          } else if (res.statusCode == 503 || res.statusCode == 502) {
            retries++;
            if (retries > 2) {
              result = 'Server AI sedang sibuk. Silakan coba lagi.';
              break;
            }
            await Future.delayed(const Duration(seconds: 3));

          } else {
            debugPrint('[Gemini] Status ${res.statusCode}');
            result = 'Error: Gemini mengembalikan status ${res.statusCode}.';
            break;
          }
        } catch (_) {
          retries++;
          if (retries > 2) {
            result = 'Koneksi gagal atau timeout saat menghubungi AI.';
            break;
          }
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    } finally {
      _isRequestActive = false;
    }

    return result;
  }
}
