import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skripsi_manager/core/theme.dart';
import 'package:skripsi_manager/features/ai/data/search_controller.dart' as ai;
import 'package:skripsi_manager/features/ai/domain/journal_model.dart';
import 'package:skripsi_manager/features/ai/data/gemini_service.dart';
import 'package:skripsi_manager/features/files/data/files_repository.dart';
import 'package:skripsi_manager/features/files/domain/file_item.dart';
import 'package:skripsi_manager/features/files/presentation/files_page.dart';

class AiPage extends StatefulWidget {
  const AiPage({super.key});

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  final _ctrl = ai.SearchController();
  final _queryCtrl = TextEditingController();
  List<FileItem> _availableFiles = [];
  FileItem? _selectedFile;
  bool _loading = false;
  String? _errorMsg;
  List<JournalItem> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableFiles();
  }

  Future<void> _loadAvailableFiles() async {
    setState(() => _loading = true);
    try {
      final repo = FilesRepository();
      final all = await repo.getFiles();
      final docs = all.where((f) {
        final ext = f.path.toLowerCase();
        return ext.endsWith('.docx') ||
            ext.endsWith('.doc') ||
            ext.endsWith('.pdf');
      }).toList();
      if (mounted) {
        setState(() {
          _availableFiles = docs;
          if (docs.isNotEmpty) _selectedFile = docs.first;
          _loading = false;
        });
        if (_selectedFile != null) _loadFile(_selectedFile!);
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = 'Gagal memuat daftar file: $e'; });
    }
  }

  Future<void> _loadFile(FileItem file) async {
    setState(() { _loading = true; _errorMsg = null; });
    final err = await _ctrl.loadDocument(file.path);
    if (mounted) {
      setState(() {
        _loading = false;
        _errorMsg = err;
      });
      if (err == null) _search();
    }
  }

  void _onFileSelected(FileItem? file) {
    if (file == null || file == _selectedFile) return;
    setState(() {
      _selectedFile = file;
      _searchResults.clear();
    });
    _loadFile(file);
  }

  void _search() {
    if (!_ctrl.hasDocument) return;
    final query = _queryCtrl.text.trim();
    setState(() {
      _searchResults = _ctrl.searchOffline(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Asisten Skripsi'),
      ),
      body: _loading && !_ctrl.hasDocument
          ? const Center(child: CircularProgressIndicator())
          : _errorMsg != null && !_ctrl.hasDocument
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
                        const SizedBox(height: 12),
                        Text(_errorMsg!, style: const TextStyle(color: AppTheme.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadAvailableFiles,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    children: [
                      // File selector — popup bottom sheet
                      if (_availableFiles.isNotEmpty)
                        GestureDetector(
                          onTap: () async {
                            final picked = await FilePickerSheet.show(
                              context,
                              files: _availableFiles,
                              selected: _selectedFile,
                              title: 'Pilih Dokumen Skripsi',
                            );
                            if (picked != null) _onFileSelected(picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _selectedFile != null
                                    ? AppTheme.primary.withAlpha(80)
                                    : AppTheme.divider,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _selectedFile?.type == 'pdf'
                                      ? Icons.picture_as_pdf_rounded
                                      : Icons.description_rounded,
                                  color: _selectedFile?.type == 'pdf'
                                      ? const Color(0xFFF87171)
                                      : AppTheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedFile?.name ?? 'Pilih dokumen...',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _selectedFile != null
                                              ? AppTheme.textPrimary
                                              : AppTheme.textSecondary,
                                          fontWeight: _selectedFile != null
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                        softWrap: true,
                                        overflow: TextOverflow.visible,
                                      ),
                                      if (_selectedFile != null)
                                        Text(
                                          _selectedFile!.type?.toUpperCase() ?? 'FILE',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.expand_more_rounded, color: AppTheme.textSecondary),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Search bar
                      TextField(
                        controller: _queryCtrl,
                        enabled: _ctrl.hasDocument,
                        decoration: InputDecoration(
                          labelText: 'Cari jurnal, sitasi, atau kata kunci',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _queryCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _queryCtrl.clear();
                                    _search();
                                  },
                                )
                              : null,
                        ),
                        onSubmitted: (_) => _search(),
                        onChanged: (_) => _search(),
                      ),
                      const SizedBox(height: 10),
                      // Stats row
                      if (_ctrl.hasDocument)
                        Row(
                          children: [
                            _StatChip(
                              icon: Icons.menu_book_rounded,
                              label: '${_ctrl.totalLines} paragraf',
                            ),
                            const SizedBox(width: 8),
                            _StatChip(
                              icon: Icons.format_quote_rounded,
                              label: '${_ctrl.totalJournals} kutipan',
                            ),
                            const SizedBox(width: 8),
                            _StatChip(
                              icon: Icons.filter_list_rounded,
                              label: '${_searchResults.length} hasil',
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                // Results list
                Expanded(
                  child: _searchResults.isEmpty && _ctrl.hasDocument
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textSecondary),
                              SizedBox(height: 8),
                              Text(
                                'Tidak ada kutipan/jurnal ditemukan.',
                                style: TextStyle(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            return ResultCard(item: _searchResults[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ---------- Stat chip ----------

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
        ],
      ),
    );
  }
}

// ---------- Result card ----------

class ResultCard extends StatefulWidget {
  final JournalItem item;
  const ResultCard({super.key, required this.item});

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  String? aiResponse;
  bool isLoading = false;
  final GeminiService _gemini = GeminiService();

  String get _locationLabel {
    final bab = 'BAB ${widget.item.chapter}';
    final poin = widget.item.pointIndicator != null ? ', Poin ${widget.item.pointIndicator}' : '';
    final para = ', Paragraf ${widget.item.paragraphIndex}';
    return '$bab$poin$para';
  }

  void _askAi() async {
    setState(() => isLoading = true);
    final chunks = _gemini.chunkText(widget.item.text);
    final textToSend = chunks.take(2).join(' ');
    final response = await _gemini.sendPrompt(
      'Kamu adalah asisten akademik. Jelaskan secara singkat, jelas, dan akademis maksud dari kutipan atau referensi jurnal berikut ini:\n\n$textToSend',
    );
    if (mounted) {
      setState(() {
        aiResponse = response;
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Judul card
            Text(
              widget.item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            // Label lokasi
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primary.withAlpha(18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _locationLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Teks kutipan
            Text(
              widget.item.text,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5),
            ),
            const SizedBox(height: 14),
            // Respon AI / tombol
            if (aiResponse != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.primary.withAlpha(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.auto_awesome, size: 14, color: AppTheme.primary),
                            SizedBox(width: 6),
                            Text(
                              'Jawaban AI',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.copy_rounded, size: 16, color: AppTheme.primary),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: aiResponse!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Jawaban disalin.')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(aiResponse!, style: const TextStyle(fontSize: 13, height: 1.5)),
                  ],
                ),
              ),
            ] else if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ElevatedButton.icon(
                onPressed: _askAi,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Tanyakan ke AI'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 42),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
