import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skripsi_manager/core/theme.dart';
import 'package:skripsi_manager/features/ai/data/isolate_helpers.dart';
import 'package:skripsi_manager/features/ai/data/translation_service.dart';
import 'package:skripsi_manager/features/files/domain/file_item.dart';
import 'package:skripsi_manager/features/files/presentation/files_page.dart';

// ─── Document cache ───────────────────────────────────────────────────────────

final _docCache = <String, List<String>>{};

Future<List<String>> _parseParagraphsInBackground(String path) async {
  if (_docCache.containsKey(path)) return _docCache[path]!;
  try {
    final file = File(path);
    if (!file.existsSync() || file.lengthSync() == 0) return [];
    final ext = path.split('.').last.toLowerCase();
    final bytes = await file.readAsBytes();
    final result = await compute(
      parseDocumentIsolate,
      ParsePayload(filePath: path, bytes: bytes, isPdf: ext == 'pdf'),
    );
    final paras = result.paragraphs.where((p) => p.trim().length > 20).toList();
    _docCache[path] = paras;
    return paras;
  } catch (e) {
    debugPrint('[ComparisonPage] Parse error for $path: $e');
    return [];
  }
}

// ─── Comparison Page ──────────────────────────────────────────────────────────

class ComparisonPage extends ConsumerStatefulWidget {
  const ComparisonPage({super.key});

  @override
  ConsumerState<ComparisonPage> createState() => _ComparisonPageState();
}

class _ComparisonPageState extends ConsumerState<ComparisonPage> {
  FileItem? _sourceFile;
  FileItem? _targetFile;
  bool _loading = false;
  String _statusText = '';
  CompareResult? _result;
  String? _errorMsg;

  // Translation mode: EN <-> ID
  bool _translateMode = false;
  bool _modelsReady = false;
  bool _modelsDownloading = false;
  final TranslationService _translationService = TranslationService();

  @override
  void dispose() {
    _translationService.dispose();
    super.dispose();
  }

  Future<void> _checkAndDownloadModels() async {
    if (_modelsReady) return;
    setState(() {
      _modelsDownloading = true;
      _statusText = 'Memeriksa model terjemahan...';
    });
    final ok = await _translationService.ensureModelsReady(
      onProgress: (msg) {
        if (mounted) setState(() => _statusText = msg);
      },
    );
    if (mounted) {
      setState(() {
        _modelsReady = ok;
        _modelsDownloading = false;
        _statusText = ok ? '' : 'Gagal mengunduh model terjemahan.';
      });
    }
  }

  Future<void> _toggleTranslateMode(bool val) async {
    setState(() => _translateMode = val);
    if (val && !_modelsReady) await _checkAndDownloadModels();
  }

  Future<void> _compare() async {
    if (_sourceFile == null || _targetFile == null) return;
    setState(() {
      _loading = true;
      _result = null;
      _errorMsg = null;
      _statusText = 'Membaca dokumen...';
    });

    try {
      // Parse both docs in background isolates concurrently
      final futures = await Future.wait([
        _parseParagraphsInBackground(_sourceFile!.path),
        _parseParagraphsInBackground(_targetFile!.path),
      ]);
      var source = futures[0];
      var target = futures[1];

      if (source.isEmpty || target.isEmpty) {
        setState(() {
          _errorMsg =
              'Dokumen tidak dapat diparsing. Pastikan format file benar.';
          _loading = false;
          _statusText = '';
        });
        return;
      }

      // ── Translation mode: translate all paragraphs to Indonesian for cross-lang compare
      if (_translateMode && _modelsReady) {
        if (!mounted) return;
        setState(() => _statusText = 'Menormalisasi dokumen sumber (ENG → ID)...');
        source = await _translateParagraphs(source);

        if (!mounted) return;
        setState(() => _statusText = 'Menormalisasi dokumen pembanding (ENG → ID)...');
        target = await _translateParagraphs(target);
      }

      if (!mounted) return;
      setState(() => _statusText = 'Menganalisis file...');
      await Future.delayed(const Duration(milliseconds: 30));

      if (!mounted) return;
      setState(() => _statusText = 'Membandingkan dokumen...');

      final result = await compute(
        compareDocumentsIsolate,
        ComparePayload(source: source, target: target),
      );

      if (mounted) {
        setState(() {
          _result = result;
          _loading = false;
          _statusText = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Error: $e';
          _loading = false;
          _statusText = '';
        });
      }
    }
  }

  /// Normalize a list of paragraphs to Indonesian using ML Kit.
  /// Automatically detects language and only translates if it's English.
  Future<List<String>> _translateParagraphs(List<String> paragraphs) async {
    final translated = <String>[];
    for (final para in paragraphs) {
      try {
        final result = await _translationService.normalizeToIndonesian(para);
        translated.add(result);
      } catch (_) {
        translated.add(para); // fallback to original
      }
    }
    return translated;
  }

  Future<void> _pickFile({required bool isSource}) async {
    final filesAsync = ref.read(allFilesProvider);
    final files = filesAsync.valueOrNull ?? [];
    final docFiles = files
        .where((f) => f.type == 'docx' || f.type == 'pdf')
        .toList();
    if (!mounted) return;
    final picked = await FilePickerSheet.show(
      context,
      files: docFiles,
      selected: isSource ? _sourceFile : _targetFile,
      title: isSource ? 'Pilih File Sumber' : 'Pilih File Pembanding',
    );
    if (picked != null) {
      setState(() {
        if (isSource) {
          _sourceFile = picked;
        } else {
          _targetFile = picked;
        }
        _result = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perbandingan Dokumen'),
        actions: [
          if (_result != null || _sourceFile != null || _targetFile != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Reset',
              onPressed: _loading
                  ? null
                  : () => setState(() {
                      _sourceFile = null;
                      _targetFile = null;
                      _result = null;
                      _errorMsg = null;
                      _docCache.clear();
                    }),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SelectorCard(
              label: 'Dokumen Sumber',
              file: _sourceFile,
              enabled: !_loading,
              onTap: () => _pickFile(isSource: true),
            ),
            const SizedBox(height: 12),
            _SelectorCard(
              label: 'Dokumen Pembanding',
              file: _targetFile,
              enabled: !_loading,
              onTap: () => _pickFile(isSource: false),
            ),
            const SizedBox(height: 12),

            // ── Translation mode toggle ─────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _translateMode
                      ? AppTheme.primary.withAlpha(80)
                      : AppTheme.divider,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.translate_rounded,
                    color: _translateMode
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Terjemahkan ke Bahasa Indonesia',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _translateMode
                                ? AppTheme.primary
                                : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          _modelsDownloading
                              ? _statusText.isNotEmpty
                                    ? _statusText
                                    : 'Mengunduh model...'
                              : _modelsReady
                              ? 'Model terjemahan siap (offline)'
                              : 'Membutuhkan download model ~50MB',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_modelsDownloading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Switch(
                      value: _translateMode,
                      onChanged: _loading ? null : _toggleTranslateMode,
                      activeTrackColor: AppTheme.primary.withAlpha(100),
                      activeThumbColor: AppTheme.primary,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Compare button
            ElevatedButton.icon(
              onPressed:
                  (_sourceFile != null &&
                      _targetFile != null &&
                      !_loading &&
                      !_modelsDownloading)
                  ? _compare
                  : null,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.compare_arrows_rounded),
              label: Text(
                _loading ? _statusText : 'Bandingkan Dokumen',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
            // Error message
            if (_errorMsg != null) ...[
              const SizedBox(height: 16),
              _ErrorCard(message: _errorMsg!),
            ],
            // Results
            if (_result != null) ...[
              const SizedBox(height: 24),
              _ResultView(result: _result!),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Error Card ───────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withAlpha(15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.error.withAlpha(60)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: AppTheme.error, fontSize: 13),
      ),
    );
  }
}

// ─── Selector Card ────────────────────────────────────────────────────────────

class _SelectorCard extends StatelessWidget {
  final String label;
  final FileItem? file;
  final bool enabled;
  final VoidCallback onTap;
  const _SelectorCard({
    required this.label,
    required this.file,
    required this.enabled,
    required this.onTap,
  });

  IconData _icon(FileItem f) => f.type == 'pdf'
      ? Icons.picture_as_pdf_rounded
      : Icons.description_rounded;

  Color _iconColor(FileItem f) =>
      f.type == 'pdf' ? const Color(0xFFF87171) : const Color(0xFF60A5FA);

  String _ext(FileItem f) =>
      f.type?.toUpperCase() ?? f.path.split('.').last.toUpperCase();

  String _fileSize(FileItem f) {
    try {
      final bytes = File(f.path).lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = file != null;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? AppTheme.primary.withAlpha(80) : AppTheme.divider,
          ),
        ),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: hasFile
                      ? _iconColor(file!).withAlpha(25)
                      : AppTheme.textSecondary.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasFile ? _icon(file!) : Icons.add_rounded,
                  color: hasFile ? _iconColor(file!) : AppTheme.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasFile ? file!.name : 'Ketuk untuk memilih',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: hasFile
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: hasFile
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                      ),
                      softWrap: true,
                      overflow: TextOverflow.visible,
                    ),
                    if (hasFile) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _iconColor(file!).withAlpha(25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _ext(file!),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _iconColor(file!),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _fileSize(file!),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Result View ──────────────────────────────────────────────────────────────

class _ResultView extends StatelessWidget {
  final CompareResult result;
  const _ResultView({required this.result});

  Color get _scoreColor {
    if (result.overallScore >= 0.7) return const Color(0xFFEF4444);
    if (result.overallScore >= 0.4) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  String get _verdict {
    if (result.overallScore >= 0.7) return 'Tinggi — Perlu Ditinjau';
    if (result.overallScore >= 0.4) return 'Sedang — Waspada';
    return 'Rendah — Aman';
  }

  @override
  Widget build(BuildContext context) {
    final pct = (result.overallScore * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _scoreColor.withAlpha(12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _scoreColor.withAlpha(60)),
          ),
          child: Column(
            children: [
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: _scoreColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kemiripan Dokumen',
                style: TextStyle(
                  fontSize: 13,
                  color: _scoreColor.withAlpha(180),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _verdict,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _scoreColor,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ScoreBadge(
                    label: '${result.matches.length} Mirip',
                    color: _scoreColor,
                  ),
                  const SizedBox(width: 8),
                  _ScoreBadge(
                    label: '${result.unmatchedSource.length} Unik',
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (result.matches.isNotEmpty) ...[
          const _SectionHeader(label: 'Paragraf Mirip'),
          const SizedBox(height: 8),
          ...result.matches.map((m) => _MatchCard(match: m)),
          const SizedBox(height: 20),
        ],
        if (result.unmatchedSource.isNotEmpty) ...[
          const _SectionHeader(label: 'Tidak Ditemukan di Pembanding'),
          const SizedBox(height: 8),
          ...result.unmatchedSource.take(5).map((t) => _UnmatchedCard(text: t)),
          if (result.unmatchedSource.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Text(
                '+ ${result.unmatchedSource.length - 5} paragraf lainnya',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _ScoreBadge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: color.withAlpha(20),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
      color: AppTheme.textSecondary,
    ),
  );
}

class _MatchCard extends StatelessWidget {
  final MatchItem match;
  const _MatchCard({required this.match});
  @override
  Widget build(BuildContext context) {
    final pct = (match.score * 100).toStringAsFixed(0);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$pct% mirip',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _TextBlock(
              label: 'Sumber',
              text: match.sourceText,
              bgColor: const Color(0xFFF0F9FF),
            ),
            const SizedBox(height: 8),
            _TextBlock(
              label: 'Pembanding',
              text: match.targetText,
              bgColor: const Color(0xFFF0FFF4),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  final String label;
  final String text;
  final Color bgColor;
  const _TextBlock({
    required this.label,
    required this.text,
    required this.bgColor,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 13, height: 1.5),
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
      ],
    ),
  );
}

class _UnmatchedCard extends StatelessWidget {
  final String text;
  const _UnmatchedCard({required this.text});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: AppTheme.textPrimary,
          height: 1.5,
        ),
        softWrap: true,
        overflow: TextOverflow.visible,
      ),
    ),
  );
}
