import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:skripsi_manager/features/ai/data/ai_persona.dart';
import 'package:skripsi_manager/features/ai/data/openrouter_service.dart';

// ignore: constant_identifier_names
const String GEMINI_API_KEY = "AIzaSyD3vFDAsB9DFGv7v7cjPaXuGEXQprGJPYk";

class GeminiService {
  final String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GEMINI_API_KEY';

  static bool _isRequestActive = false;

  // Shared OpenRouter instance — lazy, used only on fallback
  final _openRouter = OpenRouterService();

  List<String> chunkText(String text) {
    List<String> chunks = [];
    int chunkSize = 900;
    for (int i = 0; i < text.length; i += chunkSize) {
      chunks.add(text.substring(i, i + chunkSize > text.length ? text.length : i + chunkSize));
    }
    return chunks;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Preferred method for UI calls.
  /// Tries Gemini first (with academic persona prefix);
  /// if Gemini fails, falls back to OpenRouter FREE models (which use system message).
  /// Returns human-readable Indonesian string on all error paths.
  Future<String> sendPromptWithFallback(String userPrompt) async {
    // Gemini does not support dedicated system messages —
    // inject persona as a prefix in the user content.
    final geminiPrompt = '${AiPersona.geminiPrefix}$userPrompt';
    final geminiResult = await sendPrompt(geminiPrompt);

    if (_geminiSucceeded(geminiResult)) return geminiResult;

    // Gemini failed — escalate to OpenRouter FREE tier.
    // OpenRouter receives the raw userPrompt; persona is injected via system message inside OpenRouterService.
    debugPrint('[GeminiService] Gemini failed, escalating to OpenRouter...');
    return _openRouter.sendPrompt(userPrompt);
  }

  /// Detects whether the Gemini response is a success (not an error sentinel).
  bool _geminiSucceeded(String result) {
    if (result.isEmpty) return false;
    const errorPrefixes = [
      'Error',
      'Limit harian',
      'Terlalu banyak',
      'Server AI sedang sibuk',
      'Koneksi gagal',
    ];
    for (final prefix in errorPrefixes) {
      if (result.startsWith(prefix)) return false;
    }
    // Also catch raw JSON error bodies that slipped through
    if (result.startsWith('{') && result.contains('"error"')) return false;
    return true;
  }

  // ── Core Gemini call ───────────────────────────────────────────────────────

  Future<String> sendPrompt(String text) async {
    while (_isRequestActive) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    _isRequestActive = true;

    int retryCount = 0;
    String finalResult = 'Error';

    try {
      while (retryCount <= 3) {
        await Future.delayed(const Duration(milliseconds: 800));

        try {
          final response = await http.post(
            Uri.parse(_endpoint),
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
          ).timeout(const Duration(seconds: 15));

          debugPrint('[Gemini] HTTP ${response.statusCode}');

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final answer =
                data['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (answer != null && (answer as String).trim().isNotEmpty) {
              finalResult = answer.trim();
              break;
            }
            finalResult = 'Error: No text returned.';
            break;
          } else if (response.statusCode == 429) {
            final lowerBody = response.body.toLowerCase();
            if (lowerBody.contains('quota') ||
                lowerBody.contains('limit') ||
                lowerBody.contains('exceeded') ||
                lowerBody.contains('daily')) {
              finalResult = 'Limit harian Gemini telah habis.';
              break;
            }
            retryCount++;
            if (retryCount > 3) {
              finalResult = 'Terlalu banyak permintaan ke Gemini.';
              break;
            }
            await Future.delayed(const Duration(seconds: 4));
          } else if (response.statusCode == 503) {
            retryCount++;
            if (retryCount > 3) {
              finalResult = 'Server AI sedang sibuk. Silakan coba lagi.';
              break;
            }
            await Future.delayed(const Duration(seconds: 3));
          } else {
            debugPrint('[Gemini] Error body: ${response.body}');
            finalResult = 'Error: Gemini mengembalikan status ${response.statusCode}.';
            break;
          }
        } catch (e) {
          retryCount++;
          if (retryCount > 3) {
            finalResult = 'Koneksi gagal atau timeout.';
            break;
          }
          await Future.delayed(const Duration(seconds: 3));
        }
      }
    } finally {
      _isRequestActive = false;
    }

    return finalResult;
  }
}
