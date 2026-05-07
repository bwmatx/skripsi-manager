import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:xml/xml.dart';
import 'package:skripsi_manager/features/ai/domain/journal_model.dart';

// ── Data model ─────────────────────────────────────────────────────────────────

class DocumentModel {
  final List<String> paragraphs;
  final List<String> lines;
  final List<String> chapters;
  final List<String> references;

  DocumentModel({
    required this.paragraphs,
    required this.lines,
    List<String>? chapters,
    List<String>? references,
  })  : chapters = chapters ?? [],
        references = references ?? [];

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
      final references = <String>[];
      
      bool inReferenceSection = false;

      for (final p in paras) {
        if (_isChapterHeading(p) || _detectAcademicSection(p) != null) {
           final sec = _detectAcademicSection(p);
           inReferenceSection = (sec == 'Referensi');
        }
        
        if (inReferenceSection && p.length > 20 && _detectAcademicSection(p) != 'Referensi') {
           references.add(p.trim());
        }

        if (_isChapterHeading(p)) chapters.add(p.trim());
        lines.addAll(
          p.split(RegExp(r'(?<=[.?!])\s+')).where((s) => s.trim().length > 4),
        );
      }

      return DocumentModel(paragraphs: paras, lines: lines, chapters: chapters, references: references);
    } catch (_) {
      return DocumentModel(paragraphs: [], lines: [], chapters: [], references: []);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static bool _isChapterHeading(String text) {
    final t = text.trim().toUpperCase();
    return t.startsWith('BAB ') || RegExp(r'^BAB\s+[IVX\d]+$').hasMatch(t);
  }

  static String? _detectPoint(String text) {
    // Detects "A.", "B.", "1.", "1.1", "2.3.1" etc at the start of paragraph
    final match = RegExp(r'^(\d+(\.\d+)*|[A-N])[.\)]\s+').firstMatch(text.trim());
    return match?.group(1);
  }

  static bool _isSubBab(String text) {
    final t = text.trim();
    // Usually Sub Bab is "1.1 Judul", "2.1 Judul" and relatively short
    return RegExp(r'^\d+\.\d+\s+').hasMatch(t) && t.length < 100;
  }

  static String _extractTitle(String text, int maxLen) {
    final t = text.trim();
    return t.length <= maxLen ? t : '${t.substring(0, maxLen)}...';
  }

  static String? _detectAcademicSection(String text) {
    final t = text.trim().toLowerCase();
    // Section headers are usually short
    if (t.length > 60 || t.length < 3) return null;
    
    // Exact or starts-with matches for common academic sections
    if (t == 'abstrak' || t == 'abstract' || t.startsWith('abstrak ')) return 'Abstrak';
    if (t == 'pendahuluan' || t == 'introduction' || t.startsWith('pendahuluan ')) return 'Pendahuluan';
    if (t.contains('metode penelitian') || t.contains('metodologi') || t == 'methodology' || t == 'methods') return 'Metodologi';
    if (t.contains('hasil dan pembahasan') || t == 'hasil' || t == 'pembahasan' || t == 'results and discussion' || t == 'results' || t == 'discussion') return 'Hasil & Pembahasan';
    if (t == 'kesimpulan' || t == 'penutup' || t == 'conclusion' || t == 'conclusions' || t.startsWith('kesimpulan ')) return 'Kesimpulan';
    if (t == 'referensi' || t == 'daftar pustaka' || t == 'references') return 'Referensi';
    
    return null;
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
    String? currentSubBab;
    String? currentPoint;
    String currentChapterTitle = '';
    String? currentPointTitle;
    int pointParagraphIndex = 0;
    int bodyParaCount = 0; // body paragraphs emitted per chapter/section

    for (final para in paras) {
      if (_isChapterHeading(para)) {
        chapterIndex++;
        currentSubBab = null;
        currentPoint = null;
        currentPointTitle = null;
        currentChapterTitle = para.trim();
        pointParagraphIndex = 0;
        bodyParaCount = 0;
        continue;
      }

      if (_isSubBab(para)) {
        currentSubBab = _extractTitle(para, 40);
        currentPoint = null;
        currentPointTitle = null;
        pointParagraphIndex = 0;
        
        // Emit Sub Bab as a structural item
        journals.add(JournalItem(
          title: 'Sub Bab: $currentSubBab',
          text: para,
          chapter: chapterIndex,
          paragraphIndex: 0,
          lineIndex: 0,
        ));
        continue;
      }

      final section = _detectAcademicSection(para);
      if (section != null) {
        chapterIndex++;
        currentSubBab = null;
        currentPoint = null;
        currentPointTitle = null;
        currentChapterTitle = section;
        pointParagraphIndex = 0;
        bodyParaCount = 0;
        continue;
      }

      final detected = _detectPoint(para);
      if (detected != null) {
        currentPoint = detected;
        currentPointTitle = _extractTitle(para, 60);
        pointParagraphIndex = 0;
      }

      pointParagraphIndex++;

      final bool isCitation = journalRegex.hasMatch(para) || citationRegex.hasMatch(para);

      if (isCitation) {
        // ── Citation / Journal reference paragraph ──────────────────────────
        final String title;
        if (currentPoint != null && currentPointTitle != null) {
          title = 'Poin $currentPoint – ${_extractTitle(currentPointTitle, 50)}';
        } else if (currentSubBab != null) {
          title = 'Sub Bab: $currentSubBab';
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

      } else if (pointParagraphIndex == 1 && currentChapterTitle.isNotEmpty && currentPoint == null && currentSubBab == null) {
        // ── First paragraph of a section/chapter ────────────────────────────
        journals.add(JournalItem(
          title: 'Struktur: $currentChapterTitle',
          text: para,
          chapter: chapterIndex,
          paragraphIndex: pointParagraphIndex,
          lineIndex: 0,
        ));
        bodyParaCount++;

      } else if (para.length > 100 && currentChapterTitle.isNotEmpty && bodyParaCount < 4) {
        // ── Substantial body paragraph ───────────────────────────────────────
        // Build a hierarchical title
        String bodyTitle = 'Paragraf: $currentChapterTitle';
        if (currentSubBab != null) bodyTitle += ' → $currentSubBab';
        if (currentPoint != null) bodyTitle += ' (Poin $currentPoint)';

        journals.add(JournalItem(
          title: bodyTitle,
          text: para,
          chapter: chapterIndex,
          paragraphIndex: pointParagraphIndex,
          lineIndex: 0,
          pointIndicator: currentPoint,
        ));
        bodyParaCount++;
      }
    }

    return journals;
  }
}
