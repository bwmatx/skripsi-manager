import 'package:skripsi_manager/features/ai/data/document_parser.dart';
import 'package:skripsi_manager/features/ai/data/pdf_parser.dart';

// ── Payload types (only primitives cross isolate boundary) ───────────────────

class ParsePayload {
  final String filePath;
  final List<int> bytes;
  final bool isPdf;
  const ParsePayload({required this.filePath, required this.bytes, required this.isPdf});
}

class ComparePayload {
  final List<String> source;
  final List<String> target;
  const ComparePayload({required this.source, required this.target});
}

// ── Result types ─────────────────────────────────────────────────────────────

class ParseResult {
  final List<String> paragraphs;
  final List<String> lines;
  final List<String> chapters;
  const ParseResult({
    this.paragraphs = const [],
    this.lines = const [],
    this.chapters = const [],
  });
}

class CompareResult {
  final double overallScore;
  final List<MatchItem> matches;
  final List<String> unmatchedSource;
  final List<String> unmatchedTarget;
  const CompareResult({
    required this.overallScore,
    required this.matches,
    required this.unmatchedSource,
    required this.unmatchedTarget,
  });
}

class MatchItem {
  final String sourceText;
  final String targetText;
  final double score;
  const MatchItem({required this.sourceText, required this.targetText, required this.score});
}

// ── Top-level functions for compute() ────────────────────────────────────────

/// Called via compute(parseDocumentIsolate, payload)
ParseResult parseDocumentIsolate(ParsePayload payload) {
  try {
    final DocumentModel model;
    if (payload.isPdf) {
      model = PdfParser.parseSync(payload.bytes);
    } else {
      model = DocumentParser.parseSync(payload.bytes);
    }
    return ParseResult(
      paragraphs: model.paragraphs,
      lines: model.lines,
      chapters: model.chapters,
    );
  } catch (_) {
    return const ParseResult(paragraphs: [], lines: [], chapters: []);
  }
}

/// Called via compute(compareDocumentsIsolate, payload)
CompareResult compareDocumentsIsolate(ComparePayload payload) {
  return _ComparisonEngine.compare(payload.source, payload.target);
}

// ── Comparison engine (runs in isolate) ──────────────────────────────────────

class _ComparisonEngine {
  static const _stopwordsId = {
    'yang', 'dan', 'di', 'ke', 'dari', 'ini', 'itu', 'dengan', 'untuk',
    'pada', 'atau', 'adalah', 'dalam', 'tidak', 'juga', 'sudah', 'oleh',
    'akan', 'ada', 'sehingga', 'karena', 'dapat', 'sebagai', 'telah',
    'bahwa', 'jika', 'maka', 'namun', 'tetapi', 'saat', 'ketika',
  };
  static const _stopwordsEn = {
    'the', 'a', 'an', 'of', 'in', 'is', 'to', 'and', 'for',
    'that', 'are', 'was', 'it', 'be', 'as', 'at', 'by', 'we',
    'this', 'with', 'on', 'from', 'or', 'but', 'not', 'have',
  };

  static const _crossLangMap = <String, String>{
    'penelitian': 'research', 'metode': 'method', 'hasil': 'result',
    'kesimpulan': 'conclusion', 'analisis': 'analysis', 'sistem': 'system',
    'data': 'data', 'pengembangan': 'development', 'aplikasi': 'application',
    'algoritma': 'algorithm', 'evaluasi': 'evaluation',
    'implementasi': 'implementation', 'kinerja': 'performance',
    'akurasi': 'accuracy', 'klasifikasi': 'classification',
    'deteksi': 'detection', 'jaringan': 'network', 'pembelajaran': 'learning',
    'pelatihan': 'training', 'pengujian': 'testing', 'validasi': 'validation',
    'optimasi': 'optimization', 'prediksi': 'prediction', 'fitur': 'feature',
    'pengguna': 'user', 'antarmuka': 'interface', 'keamanan': 'security',
    'kualitas': 'quality', 'efisiensi': 'efficiency',
    'perancangan': 'design', 'rancangan': 'design', 'proses': 'process',
    'struktur': 'structure', 'fungsi': 'function', 'variabel': 'variable',
    'parameter': 'parameter', 'nilai': 'value', 'tingkat': 'level',
    'faktor': 'factor', 'pengaruh': 'influence', 'hubungan': 'relation',
    'perbandingan': 'comparison', 'perbedaan': 'difference',
    'kesamaan': 'similarity', 'dokumen': 'document', 'teks': 'text',
    'kata': 'word',
  };

  static String _normalize(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _stemId(String word) {
    for (final p in ['meng', 'peng', 'mem', 'pem', 'men', 'pen', 'ber', 'ter', 'ke', 'me', 'di', 'pe']) {
      if (word.startsWith(p) && word.length > p.length + 3) { word = word.substring(p.length); break; }
    }
    for (final s in ['kan', 'an', 'i', 'lah', 'kah']) {
      if (word.endsWith(s) && word.length > s.length + 3) { word = word.substring(0, word.length - s.length); break; }
    }
    return word;
  }

  static String _stemEn(String word) {
    if (word.endsWith('ing') && word.length > 6) return word.substring(0, word.length - 3);
    if (word.endsWith('tion') && word.length > 6) return word.substring(0, word.length - 4);
    if (word.endsWith('ed') && word.length > 5) return word.substring(0, word.length - 2);
    if (word.endsWith('ly') && word.length > 5) return word.substring(0, word.length - 2);
    if (word.endsWith('s') && word.length > 4) return word.substring(0, word.length - 1);
    return word;
  }

  static List<String> _tokenize(String text) {
    return _normalize(text).split(' ').where((w) => w.length > 3).where(
      (w) => !_stopwordsId.contains(w) && !_stopwordsEn.contains(w),
    ).map((w) {
      final mapped = _crossLangMap[w] ?? w;
      final stemmed = _crossLangMap.containsKey(w)
          ? _stemEn(mapped)
          : RegExp(r'[aiueo]').allMatches(w).length > w.length * 0.35
              ? _stemId(w)
              : _stemEn(w);
      return stemmed.isEmpty ? mapped : stemmed;
    }).toList();
  }

  static Set<String> _keywords(String text) => _tokenize(text).toSet();

  static double _jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty && b.isEmpty) return 0;
    final intersection = a.intersection(b).length;
    final union = a.union(b).length;
    return union == 0 ? 0 : intersection / union;
  }

  static double _keywordMatch(Set<String> a, Set<String> b) {
    if (a.isEmpty) return 0;
    return a.intersection(b).length / a.length;
  }

  static Map<String, double> _tfScore(List<String> tokens) {
    final freq = <String, int>{};
    for (final t in tokens) { freq[t] = (freq[t] ?? 0) + 1; }
    final max = freq.values.isEmpty ? 1 : freq.values.reduce((a, b) => a > b ? a : b);
    return freq.map((k, v) => MapEntry(k, v / max));
  }

  static double _weightedOverlap(String a, String b) {
    final tokA = _tokenize(a);
    final tokB = _tokenize(b);
    if (tokA.isEmpty || tokB.isEmpty) return 0;
    final tfA = _tfScore(tokA);
    final tfB = _tfScore(tokB);
    final shared = tfA.keys.toSet().intersection(tfB.keys.toSet());
    if (shared.isEmpty) return 0;
    final score = shared.fold<double>(0, (s, k) => s + (tfA[k]! + tfB[k]!) / 2);
    final norm = (tokA.length + tokB.length) / 2;
    return (score / norm).clamp(0.0, 1.0);
  }

  static double paragraphSimilarity(String a, String b) {
    // Pre-filter: skip very short paragraphs
    if (a.length < 20 || b.length < 20) return 0;
    final kA = _keywords(a);
    final kB = _keywords(b);
    if (kA.isEmpty || kB.isEmpty) return 0;
    // Early exit: if zero keyword overlap, score will be very low
    if (kA.intersection(kB).isEmpty) return 0;
    final jaccard = _jaccard(kA, kB);
    final kwMatch = _keywordMatch(kA, kB);
    final tf = _weightedOverlap(a, b);
    return (jaccard * 0.35 + kwMatch * 0.30 + tf * 0.35).clamp(0.0, 1.0);
  }

  static CompareResult compare(List<String> source, List<String> target) {
    const threshold = 0.25;
    const batchSize = 20;
    final matches = <MatchItem>[];
    final usedTargetIdx = <int>{};
    final unmatchedSource = <String>[];

    // Pre-build keyword sets for target paragraphs (avoid recomputing)
    final targetKeywords = target.map(_keywords).toList();

    // Process source in batches
    for (int si = 0; si < source.length; si += batchSize) {
      final end = (si + batchSize).clamp(0, source.length);
      for (int i = si; i < end; i++) {
        final sp = source[i];
        // Skip very short or empty
        if (sp.trim().length < 20) { unmatchedSource.add(sp); continue; }
        final kSp = _keywords(sp);
        if (kSp.isEmpty) { unmatchedSource.add(sp); continue; }

        double bestScore = 0;
        int bestIdx = -1;

        for (int ti = 0; ti < target.length; ti++) {
          if (usedTargetIdx.contains(ti)) continue;
          // Early exit: skip targets with zero keyword overlap
          if (kSp.intersection(targetKeywords[ti]).isEmpty) continue;
          final score = paragraphSimilarity(sp, target[ti]);
          if (score > bestScore) {
            bestScore = score;
            bestIdx = ti;
          }
        }

        if (bestScore >= threshold && bestIdx != -1) {
          matches.add(MatchItem(sourceText: sp, targetText: target[bestIdx], score: bestScore));
          usedTargetIdx.add(bestIdx);
        } else {
          unmatchedSource.add(sp);
        }
      }
    }

    final unmatchedTarget = <String>[];
    for (int i = 0; i < target.length; i++) {
      if (!usedTargetIdx.contains(i)) unmatchedTarget.add(target[i]);
    }

    final overallScore = source.isEmpty
        ? 0.0
        : (matches.fold<double>(0, (s, m) => s + m.score) / source.length).clamp(0.0, 1.0);

    return CompareResult(
      overallScore: overallScore,
      matches: matches,
      unmatchedSource: unmatchedSource,
      unmatchedTarget: unmatchedTarget,
    );
  }
}
