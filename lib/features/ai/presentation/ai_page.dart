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
import 'package:skripsi_manager/features/history/data/analysis_history_repository.dart';
import 'package:skripsi_manager/features/history/presentation/history_page.dart';
import 'package:skripsi_manager/features/ai/presentation/reference_page.dart';

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
      if (mounted)
        setState(() {
          _loading = false;
          _errorMsg = 'Gagal memuat daftar file: $e';
        });
    }
  }

  Future<void> _loadFile(FileItem file) async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
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
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Riwayat Analisis',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryPage()),
              );
            },
          ),
        ],
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
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppTheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMsg!,
                      style: const TextStyle(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedFile?.name ??
                                            'Pilih dokumen...',
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
                                          _selectedFile!.type?.toUpperCase() ??
                                              'FILE',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.expand_more_rounded,
                                  color: AppTheme.textSecondary,
                                ),
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
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
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
                              if (_ctrl.references.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ReferencePage(
                                          references: _ctrl.references,
                                          documentTitle:
                                              _selectedFile?.name ?? 'Dokumen',
                                        ),
                                      ),
                                    );
                                  },
                                  child: _StatChip(
                                    icon: Icons.library_books_rounded,
                                    label:
                                        '${_ctrl.references.length} Referensi',
                                    isAction: true,
                                  ),
                                ),
                              ],
                            ],
                          ),
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
                                isFullDocAnalysis: true,
                              );
                            }
                            final itemIndex = index - 1;
                            return ResultCard(
                              item: _searchResults[itemIndex],
                              searchQuery: _queryCtrl.text.trim(),
                            );
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
  final bool isAction;

  const _StatChip({
    required this.icon,
    required this.label,
    this.isAction = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAction ? AppTheme.primary : AppTheme.primary.withAlpha(18),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isAction
            ? [
                BoxShadow(
                  color: AppTheme.primary.withAlpha(60),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isAction ? Colors.white : AppTheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isAction ? FontWeight.w600 : FontWeight.normal,
              color: isAction ? Colors.white : AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Result card ──────────────────────────────────────────────────────────────

class ResultCard extends StatefulWidget {
  final JournalItem item;
  final String? searchQuery;
  final bool isFullDocAnalysis;

  const ResultCard({
    super.key,
    required this.item,
    this.searchQuery,
    this.isFullDocAnalysis = false,
  });

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

    final base =
        '${widget.item.chapter}_${widget.item.paragraphIndex}_$textHash';
    return base;
  }

  bool get _hasMessages => _messages.isNotEmpty;
  bool get _isFullDoc => widget.isFullDocAnalysis;
  bool get _isStructure => widget.item.title.startsWith('Struktur: ');
  bool get _isBodyPara => widget.item.title.startsWith('Paragraf: ');

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
      if (mounted)
        setState(() {
          _messages = msgs;
          _loadingHistory = false;
        });
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
    final prompt = _isFullDoc
        ? 'Sebagai dosen pembimbing akademik, buatkan analisis komprehensif untuk jurnal ini secara terstruktur. '
              'Sertakan poin-poin berikut:\n'
              '1. Ringkasan singkat jurnal\n'
              '2. Keyword / Kata kunci utama\n'
              '3. Metodologi penelitian yang digunakan\n'
              '4. Kesimpulan jurnal\n'
              '5. Highlight poin penting / kontribusi penelitian\n\n'
              'Teks dokumen:\n"$textToSend"'
        : _isBodyPara
        ? 'Sebagai dosen pembimbing akademik, analisis isi paragraf berikut dari bagian '
              '"${widget.item.title.replaceFirst("Paragraf: ", "")}". '
              'Jelaskan:\n'
              '1. Apa yang dibahas paragraf ini\n'
              '2. Poin akademis penting di dalamnya\n'
              '3. Relevansinya dalam konteks penelitian\n\n'
              'Paragraf:\n"$textToSend"'
        : _isStructure
        ? 'Sebagai dosen pembimbing akademik, analisis bagian ${widget.item.title.replaceAll("Struktur: ", "")} ini. '
              'Jelaskan poin pentingnya, apa yang dibahas di dalamnya, dan bagaimana bagian ini berkontribusi pada jurnal secara keseluruhan:\n\n'
              '"$textToSend"'
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
      _messages = [
        AiChatMessage(
          id: id,
          itemKey: msg.itemKey,
          role: msg.role,
          content: msg.content,
          createdAt: msg.createdAt,
        ),
      ];
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
    contextBuf.writeln(
      '\nBerikan jawaban sebagai dosen pembimbing akademik yang solutif dan profesional.',
    );

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

    final response = await _gemini.sendPromptWithFallback(
      contextBuf.toString(),
    );

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
        title: const Text(
          'Hapus Jawaban AI?',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 16),
        ),
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
    if (_isBodyPara) {
      // For body paragraphs, show section name extracted from title
      final section = widget.item.title.replaceFirst('Paragraf: ', '');
      final poin = widget.item.pointIndicator != null
          ? ' | Poin ${widget.item.pointIndicator}'
          : '';
      return '$section$poin';
    }
    if (_isStructure) {
      return widget.item.title.replaceFirst('Struktur: ', '');
    }
    final bab = 'BAB ${widget.item.chapter}';
    final poin = widget.item.pointIndicator != null
        ? ' | Poin ${widget.item.pointIndicator}'
        : '';
    final para = ' | ¶ ${widget.item.paragraphIndex}';
    return '$bab$poin$para';
  }

  /// Get preview text with max lines and ellipsis
  String _getPreviewText(String fullText, {int maxLines = 3}) {
    final lines = fullText.split(RegExp(r'\n+'));
    if (lines.length <= maxLines) {
      return fullText;
    }
    final preview = lines.take(maxLines).join('\n').trim();
    return preview.length > 400
        ? '${preview.substring(0, 400)}...'
        : '$preview...';
  }

  Widget _buildHighlightedText(
    String text, {
    required TextStyle style,
    Color? highlightColor,
  }) {
    final query = widget.searchQuery;
    if (query == null || query.isEmpty) {
      return Text(text, style: style);
    }

    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int start = 0;
    int indexOfMatch;

    while ((indexOfMatch = lowerText.indexOf(lowerQuery, start)) != -1) {
      if (indexOfMatch > start) {
        spans.add(TextSpan(text: text.substring(start, indexOfMatch)));
      }
      spans.add(
        TextSpan(
          text: text.substring(indexOfMatch, indexOfMatch + query.length),
          style: TextStyle(
            backgroundColor: highlightColor ?? AppTheme.primary.withAlpha(80),
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      );
      start = indexOfMatch + query.length;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return RichText(
      text: TextSpan(style: style, children: spans),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isHighlighted =
        widget.searchQuery != null &&
        widget.searchQuery!.isNotEmpty &&
        widget.item.text.toLowerCase().contains(
          widget.searchQuery!.toLowerCase(),
        );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: isHighlighted ? 4 : 1,
      shadowColor: isHighlighted
          ? AppTheme.primary.withAlpha(40)
          : Colors.black.withAlpha(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isHighlighted
              ? AppTheme.primary.withAlpha(120)
              : AppTheme.divider,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _isFullDoc
                          ? AppTheme.primary
                          : AppTheme.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (_isFullDoc)
                  const Icon(
                    Icons.stars_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.item.chapter != 0 || widget.item.pointIndicator != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bookmark_outline_rounded,
                      size: 12,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _locationLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            if (!_isFullDoc) const SizedBox(height: 14),
            if (!_isFullDoc) const Divider(height: 1),
            const SizedBox(height: 14),

            // ── Content display by type ──
            if (_isBodyPara) ...[
              // Body paragraph: show as quoted content block
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9), // Lighter slate blue-gray
                  borderRadius: BorderRadius.circular(12),
                  border: const Border(
                    left: BorderSide(color: AppTheme.primary, width: 4),
                  ),
                ),
                child: _buildHighlightedText(
                  _getPreviewText(widget.item.text),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF334155),
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_isStructure) ...[
              // Structure/section opening paragraph
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primary.withAlpha(30)),
                ),
                child: _buildHighlightedText(
                  _getPreviewText(widget.item.text),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else if (!_isFullDoc) ...[
              // Citation or other normal paragraph
              _buildHighlightedText(
                _getPreviewText(widget.item.text),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // Full Doc Analysis info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withAlpha(20)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Analisis dokumen lengkap tersedia untuk ringkasan dan poin-poin akademik penting.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                    icon: Icons.save_rounded,
                    label: 'Simpan',
                    onTap: () async {
                      final firstAi = _messages.firstWhere(
                        (m) => m.role == 'assistant',
                        orElse: () => _messages.first,
                      );
                      final repo = AnalysisHistoryRepository();
                      await repo.insert(
                        AnalysisHistory(
                          title: widget.item.title,
                          type: _isFullDoc
                              ? 'Analisis Akademik'
                              : (_isStructure
                                    ? 'Analisis Bagian'
                                    : 'Penjelasan Kutipan'),
                          content: firstAi.content,
                          createdAt: DateTime.now(),
                        ),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Analisis tersimpan ke riwayat.'),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
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
            crossAxisAlignment: isAi
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.end,
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
                      const Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'AI',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ] else
                      const Text(
                        'Kamu',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              // Bubble
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isAi ? AppTheme.primary.withAlpha(12) : AppTheme.card,
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
                  width: 20,
                  height: 20,
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
