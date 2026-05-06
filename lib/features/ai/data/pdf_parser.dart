import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:skripsi_manager/features/ai/data/document_parser.dart';

/// Parses PDF files using Syncfusion PDF library which can extract actual
/// selectable text from PDFs — not just metadata or byte rendering.
/// All heavy methods are pure static functions so they can run inside compute().
class PdfParser {
  // In-memory cache: filePath → DocumentModel
  static final Map<String, DocumentModel> _cache = {};

  static Future<DocumentModel> parse(String filePath) async {
    if (_cache.containsKey(filePath)) return _cache[filePath]!;

    final bytes = await File(filePath).readAsBytes();
    final model = await _parseBytes(bytes);
    _cache[filePath] = model;
    return model;
  }

  static void clearCache() => _cache.clear();
  static void clearEntry(String filePath) => _cache.remove(filePath);

  /// Pure function — safe to run inside Isolate.run() / compute().
  static DocumentModel parseSync(List<int> bytes) {
    return _parseBytesSync(bytes);
  }

  // ── Async wrapper (keeps callers clean) ────────────────────────────────────

  static Future<DocumentModel> _parseBytes(List<int> bytes) async {
    return _parseBytesSync(bytes);
  }

  // ── Core parsing — synchronous, pure ──────────────────────────────────────

  static DocumentModel _parseBytesSync(List<int> bytes) {
    final PdfDocument document;
    try {
      document = PdfDocument(inputBytes: bytes);
    } catch (_) {
      return DocumentModel(paragraphs: [], lines: [], chapters: []);
    }

    final rawLines = <String>[];

    try {
      final extractor = PdfTextExtractor(document);
      final pageCount = document.pages.count;

      // Process in chunks to avoid memory spikes on large files
      const chunkSize = 10;
      for (int start = 0; start < pageCount; start += chunkSize) {
        final end = (start + chunkSize).clamp(0, pageCount);
        for (int i = start; i < end; i++) {
          try {
            final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
            if (pageText.isNotEmpty) {
              // Split by newlines and add non-empty lines
              final lines = pageText.split('\n');
              for (final line in lines) {
                final trimmed = line.trim();
                if (trimmed.length > 2) rawLines.add(trimmed);
              }
            }
          } catch (_) {
            continue;
          }
        }
      }
    } finally {
      document.dispose();
    }

    final paragraphs = _buildParagraphs(rawLines);
    final chapters = _detectChapters(paragraphs);
    final lines = _splitToLines(paragraphs);

    return DocumentModel(
      paragraphs: paragraphs,
      lines: lines,
      chapters: chapters,
    );
  }

  // ── Paragraph merging ───────────────────────────────────────────────────────

  static List<String> _buildParagraphs(List<String> rawLines) {
    final paragraphs = <String>[];
    final buffer = StringBuffer();

    for (final line in rawLines) {
      // Chapter headings flush immediately as their own paragraph
      if (_isChapterHeading(line)) {
        if (buffer.isNotEmpty) {
          final p = buffer.toString().trim();
          if (p.length > 10) paragraphs.add(p);
          buffer.clear();
        }
        paragraphs.add(line.trim());
        continue;
      }

      buffer.write('$line ');

      final trimmed = line.trimRight();
      final endsWithSentence = trimmed.endsWith('.') ||
          trimmed.endsWith('?') ||
          trimmed.endsWith('!') ||
          trimmed.endsWith(':');
      final bufferFull = buffer.length > 400;

      if (endsWithSentence || bufferFull) {
        final p = buffer.toString().trim();
        if (p.length > 10) paragraphs.add(p);
        buffer.clear();
      }
    }

    if (buffer.isNotEmpty) {
      final p = buffer.toString().trim();
      if (p.length > 10) paragraphs.add(p);
    }

    return paragraphs;
  }

  // ── Chapter detection ───────────────────────────────────────────────────────

  static List<String> _detectChapters(List<String> paragraphs) {
    return paragraphs.where(_isChapterHeading).map((p) => p.trim()).toList();
  }

  static bool _isChapterHeading(String text) {
    final t = text.trim().toUpperCase();
    return t.startsWith('BAB ') ||
        RegExp(r'^BAB\s+[IVX\d]+').hasMatch(t) ||
        RegExp(r'^CHAPTER\s+[IVX\d]+').hasMatch(t) ||
        RegExp(r'^BAB\s+[IVX\d]+\s*$').hasMatch(t);
  }

  // ── Line splitting ──────────────────────────────────────────────────────────

  static List<String> _splitToLines(List<String> paragraphs) {
    final lines = <String>[];
    for (final p in paragraphs) {
      final sentences = p.split(RegExp(r'(?<=[.?!])\s+'));
      for (final s in sentences) {
        final trimmed = s.trim();
        if (trimmed.length > 4) lines.add(trimmed);
      }
    }
    return lines;
  }
}
