import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:skripsi_manager/features/ai/data/document_parser.dart';
import 'package:skripsi_manager/features/ai/data/isolate_helpers.dart';
import 'package:skripsi_manager/features/ai/domain/journal_model.dart';

class SearchController {
  DocumentModel? _cachedDoc;
  List<JournalItem>? _cachedJournals;
  String? _cachedPath;

  /// Loads and parses the document in a background isolate via compute().
  /// Returns an error message string on failure, null on success.
  Future<String?> loadDocument(String filePath) async {
    if (_cachedPath == filePath && _cachedDoc != null) return null;

    try {
      final file = File(filePath);
      if (!file.existsSync()) return 'File tidak ditemukan: $filePath';

      final stat = file.statSync();
      if (stat.size == 0) return 'File kosong: $filePath';

      final ext = filePath.split('.').last.toLowerCase();
      final bytes = await file.readAsBytes();

      final result = await compute(
        parseDocumentIsolate,
        ParsePayload(filePath: filePath, bytes: bytes, isPdf: ext == 'pdf'),
      );

      _cachedDoc = DocumentModel(
        paragraphs: result.paragraphs,
        lines: result.lines,
        chapters: result.chapters,
      );
      _cachedJournals = DocumentParser.extractJournals(_cachedDoc!);
      _cachedPath = filePath;
      return null; // success
    } catch (e) {
      debugPrint('[SearchController] loadDocument error: $e');
      return 'Gagal memuat dokumen: $e';
    }
  }

  List<JournalItem> searchOffline(String query) {
    if (_cachedJournals == null) return [];
    if (query.isEmpty) return _cachedJournals!;
    final lowerQuery = query.toLowerCase();
    return _cachedJournals!
        .where((j) => j.text.toLowerCase().contains(lowerQuery))
        .toList();
  }

  bool get hasDocument =>
      _cachedDoc != null && _cachedDoc!.paragraphs.isNotEmpty;
  int get totalLines => _cachedDoc?.paragraphs.length ?? 0;
  int get totalJournals => _cachedJournals?.length ?? 0;

  /// Returns the first part of the document text for full analysis.
  String get documentText {
    if (_cachedDoc == null) return '';
    final text = _cachedDoc!.normalizedText;
    return text.length > 8000 ? text.substring(0, 8000) : text;
  }
}
