import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:skripsi_manager/core/theme.dart';
import 'package:skripsi_manager/features/files/data/files_repository.dart';
import 'package:skripsi_manager/features/files/domain/file_item.dart';

final _filesRepo = FilesRepository();

final allFilesProvider = FutureProvider<List<FileItem>>((ref) {
  return _filesRepo.getFiles();
});

class FilesPage extends ConsumerStatefulWidget {
  const FilesPage({super.key});

  @override
  ConsumerState<FilesPage> createState() => _FilesPageState();
}

class _FilesPageState extends ConsumerState<FilesPage> {
  String _searchQuery = '';
  String? _filterType; // 'pdf', 'docx', null = all
  String? _filterCategory; // 'Jurnal', 'Skripsi', 'Referensi', null = all
  String _sortBy = 'name'; // 'name', 'date', 'size'
  bool _sortAsc = true;

  List<FileItem> _applyFilter(List<FileItem> files) {
    final filtered = files.where((f) {
      if (_filterType != null && f.type != _filterType) return false;
      if (_filterCategory != null && f.category != _filterCategory) return false;
      
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchName = f.name.toLowerCase().contains(query);
        final matchAuthor = (f.authors ?? '').toLowerCase().contains(query);
        final matchTags = (f.tags ?? '').toLowerCase().contains(query);
        if (!matchName && !matchAuthor && !matchTags) return false;
      }
      return true;
    }).toList();
    return _applySort(filtered);
  }

  List<FileItem> _applySort(List<FileItem> files) {
    final sorted = List<FileItem>.from(files);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortBy) {
        case 'size':
          int sizeOf(FileItem f) {
            try { return File(f.path).lengthSync(); } catch (_) { return 0; }
          }
          cmp = sizeOf(a).compareTo(sizeOf(b));
          break;
        case 'date':
          cmp = a.id.compareTo(b.id); // id is autoincrement ~ insertion date
          break;
        default: // 'name'
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
      return _sortAsc ? cmp : -cmp;
    });
    return sorted;
  }

  String _sortLabel() {
    if (_sortBy == 'date') return _sortAsc ? 'Tanggal ↑' : 'Tanggal ↓';
    if (_sortBy == 'size') return _sortAsc ? 'Ukuran ↑' : 'Ukuran ↓';
    return _sortAsc ? 'Abjad A–Z' : 'Abjad Z–A';
  }

  void _showTypePopup(BuildContext context) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx, offset.dy + box.size.height + 4,
        offset.dx + box.size.width, offset.dy + box.size.height + 200,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem(value: 'ALL', child: Text('Semua Tipe')),
        const PopupMenuItem(value: 'pdf', child: Text('PDF')),
        const PopupMenuItem(value: 'docx', child: Text('DOCX')),
      ],
    );
    if (result != null) {
      setState(() => _filterType = (result == 'ALL') ? null : result);
    }
  }

  void _showCategoryPopup(BuildContext context, List<FileItem> allFiles) async {
    final cats = <String>{'Jurnal', 'Skripsi', 'Referensi'};
    for (final f in allFiles) {
      if (f.category.isNotEmpty) cats.add(f.category);
    }
    final catList = cats.toList()..sort();

    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx, offset.dy + box.size.height + 4,
        offset.dx + box.size.width + 100, offset.dy + box.size.height + 200,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        const PopupMenuItem(value: 'ALL', child: Text('Semua Koleksi')),
        ...catList.map((c) => PopupMenuItem(value: c, child: Text(c))),
      ],
    );
    if (result != null) {
      setState(() => _filterCategory = (result == 'ALL') ? null : result);
    }
  }

  void _showSortPopup(BuildContext context) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset offset = box.localToGlobal(Offset.zero);
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx, offset.dy + box.size.height + 4,
        offset.dx + box.size.width + 100, offset.dy + box.size.height + 200,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: const [
        PopupMenuItem(value: 'name_asc',  child: Text('Abjad A–Z')),
        PopupMenuItem(value: 'name_desc', child: Text('Abjad Z–A')),
        PopupMenuItem(value: 'date_desc', child: Text('Tanggal Terbaru')),
        PopupMenuItem(value: 'date_asc',  child: Text('Tanggal Terlama')),
        PopupMenuItem(value: 'size_desc', child: Text('Ukuran Terbesar')),
        PopupMenuItem(value: 'size_asc',  child: Text('Ukuran Terkecil')),
      ],
    );
    if (result == null) return;
    setState(() {
      switch (result) {
        case 'name_asc':  _sortBy = 'name'; _sortAsc = true;  break;
        case 'name_desc': _sortBy = 'name'; _sortAsc = false; break;
        case 'date_desc': _sortBy = 'date'; _sortAsc = false; break;
        case 'date_asc':  _sortBy = 'date'; _sortAsc = true;  break;
        case 'size_desc': _sortBy = 'size'; _sortAsc = false; break;
        case 'size_asc':  _sortBy = 'size'; _sortAsc = true;  break;
      }
    });
  }

  // Filter UI helper.
  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(allFilesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Manager'),
      ),
      body: filesAsync.when(
        data: (allFiles) {
          final files = _applyFilter(allFiles);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Search Bar ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Cari judul, penulis, atau tag...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.divider),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              
              // ── Filter Row: 3 compact popup buttons ───────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Builder(builder: (ctx) => _PopupFilterBtn(
                      label: _filterType == null ? 'Tipe File' : _filterType!.toUpperCase(),
                      icon: Icons.description_outlined,
                      active: _filterType != null,
                      onTap: () => _showTypePopup(ctx),
                    )),
                    const SizedBox(width: 8),
                    Builder(builder: (ctx) => _PopupFilterBtn(
                      label: _filterCategory == null ? 'Koleksi' : _filterCategory!,
                      icon: Icons.folder_outlined,
                      active: _filterCategory != null,
                      onTap: () => _showCategoryPopup(ctx, allFiles),
                    )),
                    const SizedBox(width: 8),
                    Builder(builder: (ctx) => _PopupFilterBtn(
                      label: _sortLabel(),
                      icon: Icons.sort_rounded,
                      active: _sortBy != 'name' || !_sortAsc,
                      onTap: () => _showSortPopup(ctx),
                    )),
                    if (_filterType != null || _filterCategory != null || _sortBy != 'name' || !_sortAsc) ...[
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => setState(() {
                          _filterType = null;
                          _filterCategory = null;
                          _sortBy = 'name';
                          _sortAsc = true;
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.error.withAlpha(20),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.error.withAlpha(60)),
                          ),
                          child: const Icon(Icons.close_rounded, size: 13, color: AppTheme.error),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (allFiles.isEmpty)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 64, color: AppTheme.textSecondary),
                        SizedBox(height: 12),
                        Text('Belum ada file', style: TextStyle(color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                )
              else if (files.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Tidak ada file sesuai filter', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: files.length,
                    itemBuilder: (_, i) => _FileTile(
                      file: files[i],
                      onDelete: () async {
                        await _filesRepo.deleteFile(files[i].id);
                        ref.invalidate(allFilesProvider);
                      },
                      onCategoryChanged: (newCat) async {
                        await _filesRepo.updateCategory(files[i].id, newCat);
                        ref.invalidate(allFilesProvider);
                      },
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickFile(context, ref),
        icon: const Icon(Icons.attach_file_rounded),
        label: const Text('Import File'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Future<void> _pickFile(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
        allowMultiple: true, // multiple import
      );
      if (result == null || result.files.isEmpty) return;

      // Load existing files for duplicate check
      final existingFiles = await _filesRepo.getFiles();

      final appDir = await getApplicationDocumentsDirectory();
      final destDir = p.join(appDir.path, 'skripsi_files');
      await Directory(destDir).create(recursive: true);

      int imported = 0;
      int skipped = 0;
      final skippedNames = <String>[];

      for (final picked in result.files) {
        if (picked.path == null) continue;

        final srcFile = File(picked.path!);
        int srcSize;
        try {
          srcSize = srcFile.lengthSync();
        } catch (_) {
          skipped++;
          skippedNames.add(picked.name);
          continue;
        }

        // Duplicate check: same name AND same file size = skip
        final isDuplicate = existingFiles.any((f) {
          if (f.name != picked.name) return false;
          try {
            return File(f.path).lengthSync() == srcSize;
          } catch (_) {
            return false;
          }
        });

        if (isDuplicate) {
          skipped++;
          skippedNames.add(picked.name);
          continue;
        }

        final dest = p.join(destDir, picked.name);
        await srcFile.copy(dest);
        await _filesRepo.addFile(picked.name, dest);
        imported++;
      }

      ref.invalidate(allFilesProvider);

      if (!context.mounted) return;

      String msg;
      if (imported > 0 && skipped == 0) {
        msg = '$imported file berhasil diimpor.';
      } else if (imported > 0 && skipped > 0) {
        msg = '$imported file diimpor, $skipped sudah ada (dilewati).';
      } else {
        msg = 'Semua file sudah pernah diimpor sebelumnya.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: imported > 0 ? null : Colors.orange[800],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengimpor file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

// ─── File Tile ────────────────────────────────────────────────────────────────

class _FileTile extends ConsumerWidget {
  final FileItem file;
  final VoidCallback onDelete;
  final ValueChanged<String> onCategoryChanged;

  const _FileTile({
    required this.file,
    required this.onDelete,
    required this.onCategoryChanged,
  });

  IconData get _icon {
    switch (file.type) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'docx':
      case 'doc':
        return Icons.description_rounded;
      case 'image':
        return Icons.image_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color get _iconColor {
    switch (file.type) {
      case 'pdf':
        return const Color(0xFFF87171);
      case 'docx':
      case 'doc':
        return const Color(0xFF60A5FA);
      case 'image':
        return const Color(0xFF34D399);
      default:
        return AppTheme.textSecondary;
    }
  }

  String _fileSize() {
    try {
      final bytes = File(file.path).lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '—';
    }
  }

  void _showCategoryOptions(BuildContext context, WidgetRef ref) {
    final allFiles = ref.read(allFilesProvider).valueOrNull ?? [];
    final categories = {'Referensi', 'Jurnal', 'Skripsi'};
    for (var f in allFiles) {
      if (f.category.isNotEmpty) categories.add(f.category);
    }
    final catList = categories.toList()..sort();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Pilih Koleksi / Kategori',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: catList.length + 1,
                itemBuilder: (ctx, i) {
                  if (i == catList.length) {
                    return ListTile(
                      leading: const Icon(Icons.add_rounded, color: AppTheme.primary),
                      title: const Text('Buat Koleksi Baru...', style: TextStyle(color: AppTheme.primary)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final newCat = await showDialog<String>(
                          context: context,
                          builder: (ctx2) {
                            final tc = TextEditingController();
                            return AlertDialog(
                              title: const Text('Koleksi Baru'),
                              content: TextField(
                                controller: tc,
                                decoration: const InputDecoration(hintText: 'Nama Koleksi'),
                                autofocus: true,
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx2), child: const Text('Batal')),
                                ElevatedButton(onPressed: () => Navigator.pop(ctx2, tc.text.trim()), child: const Text('Simpan')),
                              ],
                            );
                          },
                        );
                        if (newCat != null && newCat.isNotEmpty) {
                          onCategoryChanged(newCat);
                        }
                      },
                    );
                  }
                  return ListTile(
                    title: Text(catList[i]),
                    trailing: catList[i] == file.category ? const Icon(Icons.check_rounded, color: AppTheme.primary) : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      onCategoryChanged(catList[i]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMetadata(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MetadataSheet(
        file: file,
        onSaved: () => ref.invalidate(allFilesProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        onTap: () => _showMetadata(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category label above title and icon
            GestureDetector(
              onTap: () => _showCategoryOptions(context, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.primary.withAlpha(50)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      file.category,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.edit_rounded, size: 12, color: AppTheme.primary),
                  ],
                ),
              ),
            ),
            if (file.lastOpened != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Terakhir dibuka: ${file.lastOpened!.day}-${file.lastOpened!.month}-${file.lastOpened!.year}',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File type icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _iconColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_icon, color: _iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                // File info — full name, no truncation
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _iconColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          file.type?.toUpperCase() ?? 'FILE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _iconColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fileSize(),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (file.authors != null && file.authors!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${file.authors} ${file.year != null ? "(${file.year})" : ""}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (file.tags != null && file.tags!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: file.tags!.split(',').map((t) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.divider,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              t.trim(),
                              style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
            // Actions
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    file.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 20,
                    color: file.isFavorite ? Colors.amber : AppTheme.textSecondary,
                  ),
                  onPressed: () async {
                    await _filesRepo.toggleFavorite(file.id, !file.isFavorite);
                    ref.invalidate(allFilesProvider);
                  },
                  tooltip: file.isFavorite ? 'Hapus dari Favorit' : 'Tambah ke Favorit',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                  onPressed: () async {
                    await _filesRepo.markAsOpened(file.id);
                    ref.invalidate(allFilesProvider);
                    OpenFile.open(file.path);
                  },
                  tooltip: 'Buka',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: AppTheme.error,
                  ),
                  tooltip: 'Hapus',
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppTheme.card,
                        title: const Text(
                          'Hapus File?',
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                        content: Text(
                          file.name,
                          style: const TextStyle(color: AppTheme.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Batal'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.error,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) onDelete();
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ),
  ),
);
  }
}

// ─── Metadata Editor Sheet ──────────────────────────────────────────────────

class _MetadataSheet extends StatefulWidget {
  final FileItem file;
  final VoidCallback onSaved;

  const _MetadataSheet({required this.file, required this.onSaved});

  @override
  State<_MetadataSheet> createState() => _MetadataSheetState();
}

class _MetadataSheetState extends State<_MetadataSheet> {
  late TextEditingController _authorsCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _tagsCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _authorsCtrl = TextEditingController(text: widget.file.authors);
    _yearCtrl = TextEditingController(text: widget.file.year);
    _tagsCtrl = TextEditingController(text: widget.file.tags);
    _notesCtrl = TextEditingController(text: widget.file.notes);
  }

  @override
  void dispose() {
    _authorsCtrl.dispose();
    _yearCtrl.dispose();
    _tagsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await _filesRepo.updateMetadata(
      widget.file.id,
      authors: _authorsCtrl.text,
      year: _yearCtrl.text,
      tags: _tagsCtrl.text,
      notes: _notesCtrl.text,
    );
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  void _copyCitation() {
    final author = _authorsCtrl.text.isNotEmpty ? _authorsCtrl.text : 'Unknown';
    final year = _yearCtrl.text.isNotEmpty ? _yearCtrl.text : 'n.d.';
    final title = widget.file.name.replaceAll(RegExp(r'\.pdf|\.docx|\.doc'), '');
    
    // Simple APA format approximation
    final apa = '$author. ($year). $title.';
    
    Clipboard.setData(ClipboardData(text: apa));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Citation tersalin (APA)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text('Metadata Jurnal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: _authorsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Penulis (contoh: John Doe, Jane Smith)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _yearCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tahun (contoh: 2024)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _tagsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Tag (pisahkan dengan koma)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Catatan Pribadi',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _copyCitation,
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: const Text('Copy Citation'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Popup File Selector (reusable widget) ────────────────────────────────────

class FilePickerSheet extends StatefulWidget {
  final List<FileItem> files;
  final FileItem? selected;
  final String title;

  const FilePickerSheet({
    super.key,
    required this.files,
    required this.title,
    this.selected,
  });

  static Future<FileItem?> show(
    BuildContext context, {
    required List<FileItem> files,
    FileItem? selected,
    String title = 'Pilih File',
  }) {
    return showModalBottomSheet<FileItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          FilePickerSheet(files: files, selected: selected, title: title),
    );
  }

  @override
  State<FilePickerSheet> createState() => _FilePickerSheetState();
}

class _FilePickerSheetState extends State<FilePickerSheet> {
  String? _filterCategory;

  @override
  Widget build(BuildContext context) {
    final filteredFiles = widget.files.where((f) {
      if (_filterCategory != null && f.category != _filterCategory) return false;
      return true;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _FilterChipBtn(
                    label: 'Semua',
                    active: _filterCategory == null,
                    onTap: () => setState(() => _filterCategory = null),
                  ),
                  ...(() {
                    final cats = {'Referensi', 'Jurnal', 'Skripsi'};
                    for (var f in widget.files) {
                      if (f.category.isNotEmpty) cats.add(f.category);
                    }
                    final catList = cats.toList()..sort();
                    return catList.map((c) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _FilterChipBtn(
                        label: c,
                        active: _filterCategory == c,
                        onTap: () => setState(() => _filterCategory = c),
                      ),
                    ));
                  })(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            if (filteredFiles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Tidak ada file sesuai filter',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: filteredFiles.length,
                  itemBuilder: (_, i) {
                    final f = filteredFiles[i];
                    final isSelected = widget.selected?.id == f.id;
                    return _SheetFileTile(
                      file: f,
                      isSelected: isSelected,
                      onTap: () => Navigator.of(context).pop(f),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SheetFileTile extends StatelessWidget {
  final FileItem file;
  final bool isSelected;
  final VoidCallback onTap;

  const _SheetFileTile({
    required this.file,
    required this.isSelected,
    required this.onTap,
  });

  IconData get _icon {
    switch (file.type) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'docx':
      case 'doc':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  Color get _iconColor {
    switch (file.type) {
      case 'pdf':
        return const Color(0xFFF87171);
      case 'docx':
      case 'doc':
        return const Color(0xFF60A5FA);
      default:
        return AppTheme.textSecondary;
    }
  }

  String _fileSize() {
    try {
      final bytes = File(file.path).lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withAlpha(15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(_icon, color: _iconColor, size: 20),
        ),
        title: Text(
          file.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
          ),
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
        subtitle: Text(
          '${file.type?.toUpperCase() ?? 'FILE'}  ·  ${_fileSize()}',
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: isSelected
            ? const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primary,
                size: 20,
              )
            : null,
      ),
    );
  }
}

// ─── Popup Filter Button ──────────────────────────────────────────────────────

class _PopupFilterBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _PopupFilterBtn({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary.withAlpha(20) : AppTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.divider,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? AppTheme.primary : AppTheme.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                color: active ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down_rounded,
                size: 16, color: active ? AppTheme.primary : AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ─── Filter Chip Button ───────────────────────────────────────────────────────

class _FilterChipBtn extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChipBtn({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppTheme.primary : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppTheme.primary : AppTheme.divider,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            color: active ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}


