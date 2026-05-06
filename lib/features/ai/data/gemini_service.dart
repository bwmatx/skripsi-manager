import 'dart:convert';
import 'package:http/http.dart' as http;

// ignore: constant_identifier_names
const String GEMINI_API_KEY = "AIzaSyD3vFDAsB9DFGv7v7cjPaXuGEXQprGJPYk";

class GeminiService {
  final String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$GEMINI_API_KEY';

  static bool _isRequestActive = false;

  List<String> chunkText(String text) {
    List<String> chunks = [];
    int chunkSize = 900;
    for (int i = 0; i < text.length; i += chunkSize) {
      chunks.add(text.substring(i, i + chunkSize > text.length ? text.length : i + chunkSize));
    }
    return chunks;
  }

  Future<String> sendPrompt(String text) async {
    while (_isRequestActive) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    _isRequestActive = true;

    int retryCount = 0;
    String finalResult = "Error";

    try {
      while (retryCount <= 3) {
        await Future.delayed(const Duration(milliseconds: 800));

        try {
          final response = await http.post(
            Uri.parse(_endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {"text": text}
                  ]
                }
              ]
            }),
          ).timeout(const Duration(seconds: 15));

          // ignore: avoid_print
          print(response.statusCode);
          // ignore: avoid_print
          print(response.body);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final answer = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
            if (answer != null) {
              finalResult = answer as String;
              break;
            }
            finalResult = "Error: No text returned.";
            break;
          } else if (response.statusCode == 429) {
            final lowerBody = response.body.toLowerCase();
            if (lowerBody.contains("quota") ||
                lowerBody.contains("limit") ||
                lowerBody.contains("exceeded") ||
                lowerBody.contains("daily")) {
              finalResult = "Limit harian Gemini telah habis. Silakan coba lagi besok.";
              break;
            }
            retryCount++;
            if (retryCount > 3) {
              finalResult = "Terlalu banyak permintaan. Coba lagi sebentar.";
              break;
            }
            await Future.delayed(const Duration(seconds: 4));
          } else if (response.statusCode == 503) {
            retryCount++;
            if (retryCount > 3) {
              finalResult = "Server AI sedang sibuk. Silakan coba lagi.";
              break;
            }
            await Future.delayed(const Duration(seconds: 3));
          } else {
            finalResult = response.body;
            break;
          }
        } catch (e) {
          retryCount++;
          if (retryCount > 3) {
            finalResult = "Koneksi gagal atau timeout.";
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
