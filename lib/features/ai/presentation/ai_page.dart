import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skripsi_manager/core/theme.dart';
import 'package:skripsi_manager/features/ai/data/ai_chat_repository.dart';
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
                      // File selector
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
                  child: !_ctrl.hasDocument
                      ? const SizedBox.shrink()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _searchResults.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return ResultCard(
                                item: JournalItem(
                                  title: 'Analisis Akademik Jurnal',
                                  text: _ctrl.documentText,
                                  chapter: 0,
                                  paragraphIndex: 0,
                                  lineIndex: 0,
                                ),
                              );
                            }
                            final itemIndex = index - 1;
                            return ResultCard(item: _searchResults[itemIndex]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ─── Stat chip ────────────────────────────────────────────────────────────────

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

// ─── Result card ──────────────────────────────────────────────────────────────

class ResultCard extends StatefulWidget {
  final JournalItem item;
  const ResultCard({super.key, required this.item});

  @override
  State<ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<ResultCard> {
  final _gemini = GeminiService();
  final _repo = AiChatRepository();
  final _followUpCtrl = TextEditingController();

  List<AiChatMessage> _messages = [];
  bool _loadingHistory = true;
  bool _sendingMsg = false;

  /// Unique key per journal item used as DB identifier.
  String get _itemKey {
    // text.hashCode ensures the key is unique to the document content
    final textHash = widget.item.text.length > 50 
        ? widget.item.text.substring(0, 50).hashCode.abs() 
        : widget.item.text.hashCode.abs();
    
    final base = '${widget.item.chapter}_${widget.item.paragraphIndex}_$textHash';
    return base;
  }

  bool get _hasMessages => _messages.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _followUpCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final msgs = await _repo.getMessages(_itemKey);
      if (mounted) setState(() { _messages = msgs; _loadingHistory = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  /// Initial "Tanyakan ke AI" — first message in this conversation.
  Future<void> _askAi() async {
    if (_sendingMsg) return;
    setState(() => _sendingMsg = true);

    final chunks = _gemini.chunkText(widget.item.text);
    final textToSend = chunks.take(2).join(' ');

    // Persona diinjeksi otomatis oleh GeminiService/OpenRouterService.
    // Di sini cukup kirim konteks akademik yang relevan.
    final isFullDoc = widget.item.chapter == 0;
    final prompt = isFullDoc
        ? 'Sebagai dosen pembimbing akademik, buatkan analisis komprehensif untuk jurnal ini secara terstruktur. '
          'Sertakan poin-poin berikut:\n'
          '1. Ringkasan singkat jurnal\n'
          '2. Keyword / Kata kunci utama\n'
          '3. Metodologi penelitian yang digunakan\n'
          '4. Kesimpulan jurnal\n'
          '5. Highlight poin penting / kontribusi penelitian\n\n'
          'Teks dokumen:\n"$textToSend"'
        : 'Analisis kutipan jurnal ilmiah berikut dan jelaskan maknanya '
          'secara akademis, termasuk relevansinya untuk penelitian:\n\n'
          '"$textToSend"';

    final response = await _gemini.sendPromptWithFallback(prompt);

    if (!mounted) return;

    // Persist first assistant message
    final msg = AiChatMessage(
      itemKey: _itemKey,
      role: 'assistant',
      content: response,
      createdAt: DateTime.now(),
    );
    final id = await _repo.addMessage(msg);
    setState(() {
      _messages = [AiChatMessage(
        id: id,
        itemKey: msg.itemKey,
        role: msg.role,
        content: msg.content,
        createdAt: msg.createdAt,
      )];
      _sendingMsg = false;
    });
  }

  /// Follow-up question from user.
  Future<void> _sendFollowUp() async {
    final question = _followUpCtrl.text.trim();
    if (question.isEmpty || _sendingMsg) return;

    _followUpCtrl.clear();
    setState(() => _sendingMsg = true);

    // Save user message
    final userMsg = AiChatMessage(
      itemKey: _itemKey,
      role: 'user',
      content: question,
      createdAt: DateTime.now(),
    );
    final userId = await _repo.addMessage(userMsg);

    // Bangun konteks percakapan untuk follow-up
    final contextBuf = StringBuffer();
    contextBuf.writeln('Kutipan jurnal yang sedang dibahas:');
    contextBuf.writeln('"${widget.item.text}"\n');
    contextBuf.writeln('Riwayat diskusi:');
    for (final m in _messages) {
      final roleLabel = m.role == 'user' ? 'Mahasiswa' : 'Dosen Pembimbing';
      contextBuf.writeln('$roleLabel: ${m.content}');
    }
    contextBuf.writeln('\nMahasiswa: $question');
    contextBuf.writeln('\nBerikan jawaban sebagai dosen pembimbing akademik yang solutif dan profesional.');

    if (mounted) {
      setState(() {
        _messages = [
          ..._messages,
          AiChatMessage(
            id: userId,
            itemKey: userMsg.itemKey,
            role: 'user',
            content: question,
            createdAt: userMsg.createdAt,
          ),
        ];
      });
    }

    final response = await _gemini.sendPromptWithFallback(contextBuf.toString());

    if (!mounted) return;

    final aiMsg = AiChatMessage(
      itemKey: _itemKey,
      role: 'assistant',
      content: response,
      createdAt: DateTime.now(),
    );
    final aiId = await _repo.addMessage(aiMsg);

    setState(() {
      _messages = [
        ..._messages,
        AiChatMessage(
          id: aiId,
          itemKey: aiMsg.itemKey,
          role: 'assistant',
          content: response,
          createdAt: aiMsg.createdAt,
        ),
      ];
      _sendingMsg = false;
    });
  }

  Future<void> _deleteHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Hapus Jawaban AI?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        content: const Text(
          'Seluruh riwayat percakapan AI untuk kutipan ini akan dihapus permanen.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _repo.deleteHistory(_itemKey);
    if (mounted) setState(() => _messages = []);
  }

  String get _locationLabel {
    final bab = 'BAB ${widget.item.chapter}';
    final poin = widget.item.pointIndicator != null ? ', Poin ${widget.item.pointIndicator}' : '';
    final para = ', Paragraf ${widget.item.paragraphIndex}';
    return '$bab$poin$para';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
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
            if (widget.item.chapter != 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
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
            if (widget.item.chapter != 0) const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Teks kutipan ──
            if (widget.item.chapter != 0) ...[
              Text(
                widget.item.text,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5),
              ),
              const SizedBox(height: 14),
            ],

            // ── AI Section ──
            if (_loadingHistory)
              const SizedBox(
                height: 24,
                child: Center(child: LinearProgressIndicator()),
              )
            else if (_hasMessages) ...[
              // Chat history
              _ChatThread(messages: _messages),
              const SizedBox(height: 4),

              // Action row: copy first + delete
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _IconActionBtn(
                    icon: Icons.copy_rounded,
                    label: 'Salin',
                    onTap: () {
                      final firstAi = _messages.firstWhere(
                        (m) => m.role == 'assistant',
                        orElse: () => _messages.first,
                      );
                      Clipboard.setData(ClipboardData(text: firstAi.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Jawaban disalin.')),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  _IconActionBtn(
                    icon: Icons.delete_outline_rounded,
                    label: 'Hapus',
                    color: AppTheme.error,
                    onTap: _deleteHistory,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Follow-up input
              _FollowUpInput(
                controller: _followUpCtrl,
                isSending: _sendingMsg,
                onSend: _sendFollowUp,
              ),
            ] else if (_sendingMsg)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    LinearProgressIndicator(),
                    SizedBox(height: 6),
                    Text(
                      'AI sedang memproses...',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _askAi,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('Tanyakan ke AI'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Chat thread ──────────────────────────────────────────────────────────────

class _ChatThread extends StatelessWidget {
  final List<AiChatMessage> messages;
  const _ChatThread({required this.messages});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: messages.map((m) {
        final isAi = m.role == 'assistant';
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: isAi ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              // Role label
              Padding(
                padding: EdgeInsets.only(
                  left: isAi ? 4 : 0,
                  right: isAi ? 0 : 4,
                  bottom: 4,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAi) ...[
                      const Icon(Icons.auto_awesome, size: 12, color: AppTheme.primary),
                      const SizedBox(width: 4),
                      const Text(
                        'AI',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primary),
                      ),
                    ] else
                      const Text(
                        'Kamu',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                  ],
                ),
              ),
              // Bubble
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isAi
                      ? AppTheme.primary.withAlpha(12)
                      : AppTheme.card,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isAi ? 0 : 12),
                    bottomRight: Radius.circular(isAi ? 12 : 0),
                  ),
                  border: Border.all(
                    color: isAi
                        ? AppTheme.primary.withAlpha(40)
                        : AppTheme.divider,
                    width: 1,
                  ),
                ),
                child: Text(
                  m.content,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: isAi ? AppTheme.textPrimary : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─── Follow-up input ──────────────────────────────────────────────────────────

class _FollowUpInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _FollowUpInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isSending,
              maxLines: null,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Tanya lanjutan...',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 6),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 6),
          isSending
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                  onPressed: onSend,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                ),
        ],
      ),
    );
  }
}

// ─── Small icon action button ─────────────────────────────────────────────────

class _IconActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _IconActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}
