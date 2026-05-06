import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  String? _filterType; // 'pdf', 'docx', null = all
  String? _filterSize; // 'small', 'medium', 'large', null = all

  List<FileItem> _applyFilter(List<FileItem> files) {
    return files.where((f) {
      // Type filter
      if (_filterType != null && f.type != _filterType) return false;
      // Size filter
      if (_filterSize != null) {
        try {
          final bytes = File(f.path).lengthSync();
          final mb = bytes / (1024 * 1024);
          if (_filterSize == 'small' && mb >= 1) return false;
          if (_filterSize == 'medium' && (mb < 1 || mb >= 5)) return false;
          if (_filterSize == 'large' && mb < 5) return false;
        } catch (_) {}
      }
      return true;
    }).toList();
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return Container(
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
                const Text(
                  'Filter File',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tipe File',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _FilterChipBtn(
                      label: 'Semua',
                      active: _filterType == null,
                      onTap: () {
                        setState(() => _filterType = null);
                        setLocal(() {});
                      },
                    ),
                    _FilterChipBtn(
                      label: 'PDF',
                      active: _filterType == 'pdf',
                      onTap: () {
                        setState(() => _filterType = 'pdf');
                        setLocal(() {});
                      },
                    ),
                    _FilterChipBtn(
                      label: 'DOCX',
                      active: _filterType == 'docx',
                      onTap: () {
                        setState(() => _filterType = 'docx');
                        setLocal(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ukuran File',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _FilterChipBtn(
                      label: 'Semua',
                      active: _filterSize == null,
                      onTap: () {
                        setState(() => _filterSize = null);
                        setLocal(() {});
                      },
                    ),
                    _FilterChipBtn(
                      label: 'Kecil (<1MB)',
                      active: _filterSize == 'small',
                      onTap: () {
                        setState(() => _filterSize = 'small');
                        setLocal(() {});
                      },
                    ),
                    _FilterChipBtn(
                      label: 'Sedang (1–5MB)',
                      active: _filterSize == 'medium',
                      onTap: () {
                        setState(() => _filterSize = 'medium');
                        setLocal(() {});
                      },
                    ),
                    _FilterChipBtn(
                      label: 'Besar (>5MB)',
                      active: _filterSize == 'large',
                      onTap: () {
                        setState(() => _filterSize = 'large');
                        setLocal(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(allFilesProvider);
    final hasFilter = _filterType != null || _filterSize != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('File Manager'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: hasFilter,
              smallSize: 8,
              child: const Icon(Icons.filter_list_rounded),
            ),
            tooltip: 'Filter',
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: filesAsync.when(
        data: (allFiles) {
          final files = _applyFilter(allFiles);
          if (allFiles.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open_rounded, size: 64, color: AppTheme.textSecondary),
                  SizedBox(height: 12),
                  Text('Belum ada file', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            );
          }
          if (files.isEmpty) {
            return const Center(
              child: Text('Tidak ada file sesuai filter', style: TextStyle(color: AppTheme.textSecondary)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            itemCount: files.length,
            itemBuilder: (_, i) => _FileTile(
              file: files[i],
              onDelete: () async {
                await _filesRepo.deleteFile(files[i].id);
                ref.invalidate(allFilesProvider);
              },
            ),
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
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      if (picked.path == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final dest = p.join(appDir.path, 'skripsi_files', picked.name);
      await Directory(p.dirname(dest)).create(recursive: true);
      await File(picked.path!).copy(dest);

      await _filesRepo.addFile(picked.name, dest);
      ref.invalidate(allFilesProvider);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${picked.name} berhasil diimpor')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengimpor file: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ─── File Tile ────────────────────────────────────────────────────────────────

class _FileTile extends StatelessWidget {
  final FileItem file;
  final VoidCallback onDelete;
  const _FileTile({required this.file, required this.onDelete});

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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
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
                ],
              ),
            ),
            // Actions
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                  onPressed: () => OpenFile.open(file.path),
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
      ),
    );
  }
}

// ─── Popup File Selector (reusable widget) ────────────────────────────────────

class FilePickerSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            const Divider(height: 1),
            if (files.isEmpty)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'Belum ada file DOCX/PDF',
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
                  itemCount: files.length,
                  itemBuilder: (_, i) {
                    final f = files[i];
                    final isSelected = selected?.id == f.id;
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
