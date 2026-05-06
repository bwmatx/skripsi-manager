import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:skripsi_manager/core/secrets.dart';
import 'package:skripsi_manager/features/ai/data/ai_persona.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

// API key loaded from lib/core/secrets.dart (gitignored — tidak boleh di-commit)
const _kApiKey = kOpenRouterApiKey;
const _kEndpoint = 'https://openrouter.ai/api/v1/chat/completions';

/// Whitelist of FREE models — do NOT add paid models or openrouter/auto.
/// Fallback order: index 0 → index 1.
const _kFreeModels = [
  'openai/gpt-oss-120b:free',
  'google/gemma-4-31b-it:free',
];

// ─── Service ──────────────────────────────────────────────────────────────────

/// Calls OpenRouter API using FREE tier models only.
/// Used exclusively as a fallback when Gemini fails.
///
/// Fallback chain: gpt-oss-120b:free → gemma-4-31b-it:free → error message.
/// Never throws — all errors are returned as human-readable strings.
class OpenRouterService {
  static const _timeout = Duration(seconds: 20);

  /// Send [userPrompt] to OpenRouter with academic persona as system message.
  /// Automatically tries each FREE model in sequence.
  /// Returns human-readable Indonesian string on all failure paths.
  Future<String> sendPrompt(String userPrompt) async {
    for (int i = 0; i < _kFreeModels.length; i++) {
      final model = _kFreeModels[i];
      debugPrint('[OpenRouter] Trying model $i: $model');

      final result = await _tryModel(model, userPrompt);

      if (_isSuccess(result)) {
        debugPrint('[OpenRouter] Success with model: $model');
        return result;
      }

      debugPrint('[OpenRouter] Model $model failed ($result) → '
          '${i < _kFreeModels.length - 1 ? "trying next model" : "all models exhausted"}');
    }

    return 'AI sedang sibuk saat ini, silakan coba lagi nanti.';
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  /// Try a single [model]. Returns content string or error sentinel.
  Future<String> _tryModel(String model, String userPrompt) async {
    try {
      final response = await http
          .post(
            Uri.parse(_kEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_kApiKey',
              'HTTP-Referer': 'https://github.com/skripsi-manager',
              'X-Title': 'Skripsi Manager',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                // System message carries the academic persona
                {
                  'role': 'system',
                  'content': AiPersona.systemPrompt,
                },
                {
                  'role': 'user',
                  'content': userPrompt,
                },
              ],
              'max_tokens': 1024,
              'temperature': 0.5,
            }),
          )
          .timeout(_timeout);

      debugPrint('[OpenRouter] $model → HTTP ${response.statusCode}');

      switch (response.statusCode) {
        case 200:
          return _extractText(response.body);

        case 429:
          // Rate limit — try next model
          debugPrint('[OpenRouter] 429 rate limit on $model');
          return '__RATE_LIMIT__';

        case 401:
        case 403:
          // Auth errors — no point retrying other models with same key
          debugPrint('[OpenRouter] Auth error ${response.statusCode} on $model');
          return '__AUTH_ERROR__';

        case 503:
        case 502:
        case 504:
          // Server unavailable — try next model
          debugPrint('[OpenRouter] Server error ${response.statusCode} on $model');
          return '__SERVER_ERROR__';

        default:
          // Check if error body mentions "model unavailable" or "context length"
          final body = response.body.toLowerCase();
          if (body.contains('model') && (body.contains('unavailable') ||
              body.contains('not found') || body.contains('overloaded'))) {
            debugPrint('[OpenRouter] Model unavailable: $model');
            return '__MODEL_UNAVAILABLE__';
          }
          debugPrint('[OpenRouter] Unexpected ${response.statusCode}: ${response.body}');
          return '__SERVER_ERROR__';
      }
    } on http.ClientException catch (e) {
      debugPrint('[OpenRouter] ClientException on $model: $e');
      return '__NETWORK_ERROR__';
    } catch (e) {
      // Catches TimeoutException and others
      debugPrint('[OpenRouter] Exception on $model: $e');
      return '__TIMEOUT__';
    }
  }

  /// Extract the assistant's text from a successful OpenAI-compatible response.
  String _extractText(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Check for error inside a 200 response (OpenRouter sometimes does this)
      if (data.containsKey('error')) {
        debugPrint('[OpenRouter] Error in 200 body: ${data['error']}');
        return '__SERVER_ERROR__';
      }

      final content = data['choices']?[0]?['message']?['content'] as String?;
      if (content != null && content.trim().isNotEmpty) {
        return content.trim();
      }
      debugPrint('[OpenRouter] Empty content in response: $body');
      return '__EMPTY__';
    } catch (e) {
      debugPrint('[OpenRouter] JSON parse error: $e | body: $body');
      return '__PARSE_ERROR__';
    }
  }

  /// Returns true if [result] is a valid, user-displayable answer.
  bool _isSuccess(String result) {
    const sentinels = {
      '__RATE_LIMIT__',
      '__AUTH_ERROR__',
      '__SERVER_ERROR__',
      '__TIMEOUT__',
      '__EMPTY__',
      '__PARSE_ERROR__',
      '__NETWORK_ERROR__',
      '__MODEL_UNAVAILABLE__',
    };
    return !sentinels.contains(result);
  }
}
