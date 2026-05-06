import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';
import 'package:skripsi_manager/features/ai/domain/journal_model.dart';

// ── Data model ─────────────────────────────────────────────────────────────────

class DocumentModel {
  final List<String> paragraphs;
  final List<String> lines;
  final List<String> chapters;

  DocumentModel({
    required this.paragraphs,
    required this.lines,
    List<String>? chapters,
  }) : chapters = chapters ?? [];

  // Normalized text — cached lazily
  String? _normalizedCache;
  String get normalizedText {
    _normalizedCache ??= paragraphs.join(' ');
    return _normalizedCache!;
  }

  bool get isEmpty => paragraphs.isEmpty;
  bool get isNotEmpty => paragraphs.isNotEmpty;
}

// ── Payload for compute() ──────────────────────────────────────────────────────

/// Passed into Isolate.run / compute so only primitive data crosses the boundary.
class DocxParsePayload {
  final List<int> bytes;
  const DocxParsePayload(this.bytes);
}

// ── Pure top-level function for compute() ────────────────────────────────────

/// Top-level function — required by Flutter compute().
DocumentModel parseDocxInIsolate(DocxParsePayload payload) {
  return DocumentParser._parseDocxBytes(payload.bytes);
}

// ── Parser ────────────────────────────────────────────────────────────────────

class DocumentParser {
  // In-memory cache: path → model
  static final Map<String, DocumentModel> _cache = {};

  static void clearCache() => _cache.clear();
  static void clearEntry(String path) => _cache.remove(path);

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Public synchronous entry point — safe to call from compute().
  static DocumentModel parseSync(List<int> bytes) => _parseDocxBytes(bytes);

  static Future<DocumentModel> parse(String filePath) async {
    if (_cache.containsKey(filePath)) return _cache[filePath]!;
    final bytes = await File(filePath).readAsBytes();
    final model = _parseDocxBytes(bytes);
    _cache[filePath] = model;
    return model;
  }

  static Future<List<JournalItem>> extractJournalsFromFile(String filePath) async {
    final doc = await parse(filePath);
    return _buildJournals(doc.paragraphs);
  }

  static List<JournalItem> extractJournals(DocumentModel document) {
    return _buildJournals(document.paragraphs);
  }

  // ── Internal: pure sync parsing — safe inside compute() ──────────────────────

  static DocumentModel _parseDocxBytes(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final xmlFile = archive.findFile('word/document.xml');
      if (xmlFile == null) return DocumentModel(paragraphs: [], lines: [], chapters: []);

      final xmlStr = String.fromCharCodes(xmlFile.content as List<int>);
      final doc = XmlDocument.parse(xmlStr);

      final body = doc.descendants
          .whereType<XmlElement>()
          .firstWhere(
            (e) => e.localName == 'body',
            orElse: () => XmlElement(XmlName('none')),
          );

      final paras = <String>[];
      // Process in chunks — iterate body paragraphs lazily
      for (final para in body.children.whereType<XmlElement>().where((e) => e.localName == 'p')) {
        final text = para.descendants
            .whereType<XmlElement>()
            .where((e) => e.localName == 't')
            .map((e) => e.innerText)
            .join()
            .trim();
        if (text.isNotEmpty) paras.add(text);
      }

      final lines = <String>[];
      final chapters = <String>[];
      for (final p in paras) {
        if (_isChapterHeading(p)) chapters.add(p.trim());
        lines.addAll(
          p.split(RegExp(r'(?<=[.?!])\s+')).where((s) => s.trim().length > 4),
        );
      }

      return DocumentModel(paragraphs: paras, lines: lines, chapters: chapters);
    } catch (_) {
      return DocumentModel(paragraphs: [], lines: [], chapters: []);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static bool _isChapterHeading(String text) {
    final t = text.trim().toUpperCase();
    return t.startsWith('BAB ') || RegExp(r'^BAB\s+[IVX\d]+$').hasMatch(t);
  }

  static String? _detectPoint(String text) {
    final match = RegExp(r'^([A-N])[.\)]\s*').firstMatch(text.trim());
    return match?.group(1);
  }

  static String _extractTitle(String text, int maxLen) {
    final t = text.trim();
    return t.length <= maxLen ? t : '${t.substring(0, maxLen)}...';
  }

  // ── Journal extraction ────────────────────────────────────────────────────────

  static List<JournalItem> _buildJournals(List<String> paras) {
    final journals = <JournalItem>[];

    final journalRegex = RegExp(
      r'\b(doi|journal|vol|no\.?|20\d{2}|19\d{2}|issn|isbn)\b',
      caseSensitive: false,
    );
    final citationRegex = RegExp(r'(\[\d+\]|\([A-Za-z][A-Za-z\s,\.]+, \d{4}\))');

    int chapterIndex = 0;
    String? currentPoint;
    String currentChapterTitle = '';
    String? currentPointTitle;
    int pointParagraphIndex = 0;

    for (final para in paras) {
      if (_isChapterHeading(para)) {
        chapterIndex++;
        currentPoint = null;
        currentPointTitle = null;
        currentChapterTitle = para.trim();
        pointParagraphIndex = 0;
        continue;
      }

      final detected = _detectPoint(para);
      if (detected != null) {
        currentPoint = detected;
        currentPointTitle = _extractTitle(para, 60);
        pointParagraphIndex = 0;
      }

      pointParagraphIndex++;

      if (journalRegex.hasMatch(para) || citationRegex.hasMatch(para)) {
        final String title;
        if (currentPoint != null && currentPointTitle != null) {
          title = 'Poin $currentPoint – ${_extractTitle(currentPointTitle, 50)}';
        } else if (currentChapterTitle.isNotEmpty) {
          title = currentChapterTitle;
        } else {
          title = _extractTitle(para, 60);
        }

        journals.add(JournalItem(
          title: title,
          text: para,
          chapter: chapterIndex,
          paragraphIndex: pointParagraphIndex,
          lineIndex: 0,
          pointIndicator: currentPoint,
        ));
      }
    }

    return journals;
  }
}
