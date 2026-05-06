import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';

/// ML Kit on-device translation service.
/// Supports English ↔ Indonesian translation offline after model download.
///
/// Usage:
///   final svc = TranslationService();
///   await svc.ensureModelsReady();  // downloads models if not present
///   final result = await svc.translateToIndonesian('This research aims to...');
///   svc.dispose();
class TranslationService {
  OnDeviceTranslator? _idToEn;
  OnDeviceTranslator? _enToId;

  final _modelManager = OnDeviceTranslatorModelManager();
  final _languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);

  bool _modelsReady = false;
  bool _isDownloading = false;

  bool get modelsReady => _modelsReady;
  bool get isDownloading => _isDownloading;

  // ── Model management ────────────────────────────────────────────────────────

  /// Check if models are already downloaded.
  Future<bool> checkModelsDownloaded() async {
    try {
      final idReady = await _modelManager.isModelDownloaded(
          TranslateLanguage.indonesian.bcpCode);
      final enReady = await _modelManager.isModelDownloaded(
          TranslateLanguage.english.bcpCode);
      return idReady && enReady;
    } catch (e) {
      debugPrint('[TranslationService] checkModels error: $e');
      return false;
    }
  }

  /// Download language models if not already present.
  /// [onProgress] is called with status message during download.
  Future<bool> ensureModelsReady({
    void Function(String status)? onProgress,
  }) async {
    if (_modelsReady) return true;
    if (_isDownloading) return false;

    _isDownloading = true;
    try {
      onProgress?.call('Memeriksa model terjemahan...');

      final alreadyReady = await checkModelsDownloaded();
      if (alreadyReady) {
        _initTranslators();
        _modelsReady = true;
        _isDownloading = false;
        return true;
      }

      onProgress?.call('Mengunduh model Bahasa Indonesia...');
      await _modelManager.downloadModel(
        TranslateLanguage.indonesian.bcpCode,
        isWifiRequired: false,
      );

      onProgress?.call('Mengunduh model Bahasa Inggris...');
      await _modelManager.downloadModel(
        TranslateLanguage.english.bcpCode,
        isWifiRequired: false,
      );

      _initTranslators();
      _modelsReady = true;
      onProgress?.call('Model siap digunakan!');
      return true;
    } catch (e) {
      debugPrint('[TranslationService] download error: $e');
      onProgress?.call('Gagal mengunduh model: $e');
      return false;
    } finally {
      _isDownloading = false;
    }
  }

  void _initTranslators() {
    _idToEn?.close();
    _enToId?.close();
    _idToEn = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.indonesian,
      targetLanguage: TranslateLanguage.english,
    );
    _enToId = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: TranslateLanguage.indonesian,
    );
  }

  // ── Translation ──────────────────────────────────────────────────────────────

  /// Detects the language of the given text.
  /// Returns BCP-47 language code (e.g., 'en', 'id') or 'und' if undetermined.
  Future<String> detectLanguage(String text) async {
    try {
      return await _languageIdentifier.identifyLanguage(text);
    } catch (e) {
      debugPrint('[TranslationService] Language ID error: $e');
      return 'und';
    }
  }

  /// Translate Indonesian → English.
  /// Returns null if models not ready or translation fails.
  Future<String?> translateToEnglish(String text) async {
    if (text.trim().isEmpty) return text;
    if (!_modelsReady || _idToEn == null) return null;
    try {
      return await _idToEn!.translateText(text);
    } catch (e) {
      debugPrint('[TranslationService] ID→EN error: $e');
      return null;
    }
  }

  /// Translate English → Indonesian.
  /// Returns null if models not ready or translation fails.
  Future<String?> translateToIndonesian(String text) async {
    if (text.trim().isEmpty) return text;
    if (!_modelsReady || _enToId == null) return null;
    try {
      return await _enToId!.translateText(text);
    } catch (e) {
      debugPrint('[TranslationService] EN→ID error: $e');
      return null;
    }
  }

  /// Auto-detect and translate text to Indonesian.
  /// If it's already Indonesian or undetermined, returns the original text.
  Future<String> normalizeToIndonesian(String text) async {
    if (text.trim().isEmpty) return text;
    final lang = await detectLanguage(text);
    if (lang == 'en') {
      final result = await translateToIndonesian(text);
      return result ?? text;
    }
    // If Indonesian or undetermined, return as is.
    return text;
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────────

  void dispose() {
    _idToEn?.close();
    _enToId?.close();
    _languageIdentifier.close();
    _idToEn = null;
    _enToId = null;
    _modelsReady = false;
  }

  /// Delete downloaded models (to free storage).
  Future<void> deleteModels() async {
    try {
      await _modelManager.deleteModel(TranslateLanguage.indonesian.bcpCode);
      await _modelManager.deleteModel(TranslateLanguage.english.bcpCode);
      _modelsReady = false;
      dispose();
    } catch (e) {
      debugPrint('[TranslationService] deleteModels error: $e');
    }
  }
}
