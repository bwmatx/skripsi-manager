import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skripsi_manager/core/theme.dart';
import 'package:skripsi_manager/features/ai/data/gemini_service.dart';
import 'package:skripsi_manager/features/history/data/analysis_history_repository.dart';

class ReferencePage extends StatefulWidget {
  final List<String> references;
  final String documentTitle;

  const ReferencePage({
    super.key,
    required this.references,
    required this.documentTitle,
  });

  @override
  State<ReferencePage> createState() => _ReferencePageState();
}

class _ReferencePageState extends State<ReferencePage> {
  final GeminiService _gemini = GeminiService();
  bool _loading = false;
  String? _formattedText;

  Future<void> _formatReferences() async {
    setState(() {
      _loading = true;
      _formattedText = null;
    });

    final joined = widget.references.take(50).join('\n'); // limit to 50
    final prompt = 'Berikut adalah daftar referensi / daftar pustaka dari sebuah jurnal akademik:\n\n'
        '$joined\n\n'
        'Tolong rapikan daftar referensi ini menjadi format APA yang benar, urutkan sesuai abjad, '
        'dan berikan sedikit penjelasan jika ada referensi yang kurang lengkap.';

    try {
      final res = await _gemini.sendPromptWithFallback(prompt);
      if (mounted) setState(() => _formattedText = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal merapikan referensi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveToHistory() async {
    final textToSave = _formattedText ?? widget.references.join('\n\n');
    final repo = AnalysisHistoryRepository();
    await repo.insert(AnalysisHistory(
      title: 'Daftar Pustaka: ${widget.documentTitle}',
      type: 'Daftar Pustaka',
      content: textToSave,
      createdAt: DateTime.now(),
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daftar Pustaka tersimpan ke Riwayat.')),
      );
    }
  }

  void _copyAll() {
    final textToCopy = _formattedText ?? widget.references.join('\n\n');
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Daftar Pustaka disalin!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showFormatted = _formattedText != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Pustaka'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Salin Semua',
            onPressed: _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Simpan ke Riwayat',
            onPressed: _saveToHistory,
          ),
        ],
      ),
      body: widget.references.isEmpty
          ? const Center(
              child: Text(
                'Tidak ditemukan daftar pustaka pada dokumen ini.',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            )
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppTheme.card,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ditemukan ${widget.references.length} referensi.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (!showFormatted)
                        ElevatedButton.icon(
                          onPressed: _loading ? null : _formatReferences,
                          icon: _loading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome, size: 16),
                          label: const Text('Rapikan Format'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 36),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: showFormatted
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _formattedText!,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: widget.references.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.card,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Text(
                                widget.references[idx],
                                style: const TextStyle(fontSize: 13, height: 1.4),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
