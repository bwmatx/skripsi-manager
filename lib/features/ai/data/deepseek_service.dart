import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:skripsi_manager/features/ai/data/ai_persona.dart';
import 'package:skripsi_manager/features/ai/data/ai_provider.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kBaseUrl = 'https://api.deepseek.com/chat/completions';
const _kDefaultModel = 'deepseek-v4-flash'; // Model yang digunakan
const _kTimeout = Duration(seconds: 20);

// ── Sentinels ─────────────────────────────────────────────────────────────────

const _kRateLimit = '__DS_RATE_LIMIT__';
const _kAuthError = '__DS_AUTH_ERROR__';
const _kServerError = '__DS_SERVER_ERROR__';
const _kTimeout2 = '__DS_TIMEOUT__';
const _kEmpty = '__DS_EMPTY__';
const _kParseError = '__DS_PARSE_ERROR__';
const _kNetworkError = '__DS_NETWORK_ERROR__';
const _kQuota = '__DS_QUOTA__';

/// DeepSeek Chat Completion provider.
///
/// Implements [AiProvider] — used by [AiProviderManager] as the second-priority
/// provider after Gemini. API key is loaded dynamically from [AiSettingsRepository]
/// (stored in FlutterSecureStorage) — never hardcoded.
///
/// Endpoint: https://api.deepseek.com/chat/completions
/// Compatible with OpenAI-format chat completion JSON.
class DeepSeekProvider extends AiProvider {
  /// Runtime API key — set by [AiProviderManager] from secure storage.
  final String apiKey;

  DeepSeekProvider({required this.apiKey});

  @override
  String get providerName => 'DeepSeek';

  @override
  bool checkAvailability() {
    return apiKey.isNotEmpty && apiKey.startsWith('sk-');
  }

  @override
  Future<String> generateResponse(String userPrompt) async {
    if (!checkAvailability()) {
      return 'Error: DeepSeek API key belum dikonfigurasi.';
    }

    debugPrint('[DeepSeek] Mengirim permintaan ke DeepSeek Chat API...');
    final stopwatch = Stopwatch()..start();

    // Single-turn: system + user
    final messages = [
      {'role': 'system', 'content': AiPersona.deepSeekSystemPrompt},
      {'role': 'user', 'content': userPrompt},
    ];

    final result = await _sendRequest(messages);

    stopwatch.stop();
    debugPrint(
      '[DeepSeek] Respons diterima dalam ${stopwatch.elapsedMilliseconds}ms',
    );

    if (_isSentinel(result)) {
      return _toUserMessage(result);
    }
    return result;
  }

  /// Multi-turn: terima chat history penuh untuk conversation context.
  /// [chatHistory] harus berupa list of {'role': 'user'/'assistant', 'content': '...'}.
  Future<String> generateResponseWithHistory(
    List<Map<String, String>> chatHistory,
  ) async {
    if (!checkAvailability()) {
      return 'Error: DeepSeek API key belum dikonfigurasi.';
    }

    debugPrint('[DeepSeek] Multi-turn request (${chatHistory.length} messages)...');
    final stopwatch = Stopwatch()..start();

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': AiPersona.deepSeekSystemPrompt},
      ...chatHistory,
    ];

    final result = await _sendRequest(messages);

    stopwatch.stop();
    debugPrint(
      '[DeepSeek] Multi-turn selesai dalam ${stopwatch.elapsedMilliseconds}ms',
    );

    if (_isSentinel(result)) {
      return _toUserMessage(result);
    }
    return result;
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  Future<String> _sendRequest(List<Map<String, String>> messages) async {
    try {
      debugPrint(
        '[DeepSeek] → Model: $_kDefaultModel | Key: ${apiKey.substring(0, 8)}... | msgs: ${messages.length}',
      );
      debugPrint(
        '[DeepSeek] → POST $_kBaseUrl (timeout: ${_kTimeout.inSeconds}s)',
      );

      final response = await http
          .post(
            Uri.parse(_kBaseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': _kDefaultModel,
              'messages': messages,
              'max_tokens': 1024,
              'temperature': 0.5,
              'stream': false,
            }),
          )
          .timeout(_kTimeout);

      debugPrint('[DeepSeek] HTTP ${response.statusCode}');

      switch (response.statusCode) {
        case 200:
          return _extractText(response.body);

        case 429:
          final body = response.body.toLowerCase();
          if (body.contains('quota') ||
              body.contains('limit') ||
              body.contains('exceeded')) {
            debugPrint('[DeepSeek] Quota/rate limit exceeded');
            return _kQuota;
          }
          debugPrint('[DeepSeek] Rate limit 429');
          return _kRateLimit;

        case 401:
        case 403:
          debugPrint('[DeepSeek] Auth error ${response.statusCode}');
          return _kAuthError;

        case 402:
          debugPrint('[DeepSeek] Insufficient balance (402)');
          return _kQuota;

        case 500:
        case 502:
        case 503:
        case 504:
          debugPrint('[DeepSeek] Server error ${response.statusCode}');
          return _kServerError;

        default:
          // Log body snippet to help debug model-not-found or other issues
          final snippet = response.body.length > 200
              ? response.body.substring(0, 200)
              : response.body;
          debugPrint(
            '[DeepSeek] Unexpected status ${response.statusCode}: $snippet',
          );
          return _kServerError;
      }
    } on http.ClientException catch (e) {
      debugPrint('[DeepSeek] ClientException: $e');
      return _kNetworkError;
    } catch (e) {
      // Catches TimeoutException and other errors
      debugPrint('[DeepSeek] Exception: $e');
      return _kTimeout2;
    }
  }

  /// Extract assistant text from OpenAI-compatible response body.
  String _extractText(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;

      // Guard: error field in 200 body
      if (data.containsKey('error')) {
        debugPrint('[DeepSeek] Error in 200 response: ${data['error']}');
        return _kServerError;
      }

      final content = data['choices']?[0]?['message']?['content'] as String?;
      if (content != null && content.trim().isNotEmpty) {
        return content.trim();
      }

      debugPrint('[DeepSeek] Empty content in response');
      return _kEmpty;
    } catch (e) {
      debugPrint('[DeepSeek] JSON parse error: $e');
      return _kParseError;
    }
  }

  bool _isSentinel(String r) {
    const sentinels = {
      _kRateLimit,
      _kAuthError,
      _kServerError,
      _kTimeout2,
      _kEmpty,
      _kParseError,
      _kNetworkError,
      _kQuota,
    };
    return sentinels.contains(r);
  }

  String _toUserMessage(String sentinel) {
    switch (sentinel) {
      case _kRateLimit:
        return 'Terlalu banyak permintaan ke DeepSeek. Silakan coba lagi sebentar.';
      case _kAuthError:
        return 'Error: DeepSeek API key tidak valid atau tidak memiliki akses.';
      case _kQuota:
        return 'Kuota DeepSeek telah habis. Periksa saldo akun DeepSeek Anda.';
      case _kServerError:
        return 'Server DeepSeek sedang bermasalah. Silakan coba lagi nanti.';
      case _kNetworkError:
        return 'Koneksi gagal saat menghubungi DeepSeek. Periksa koneksi internet Anda.';
      case _kTimeout2:
        return 'Timeout: DeepSeek tidak merespons tepat waktu.';
      case _kEmpty:
        return 'Error: DeepSeek tidak memberikan jawaban.';
      case _kParseError:
        return 'Error: Gagal membaca respons dari DeepSeek.';
      default:
        return 'Error: DeepSeek gagal memproses permintaan.';
    }
  }
}
