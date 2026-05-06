class FileItem {
  final int id;
  final String name;
  final String path;
  final int? chapterId;
  final String? type;
  final String category;

  const FileItem({
    required this.id,
    required this.name,
    required this.path,
    this.chapterId,
    this.type,
    this.category = 'Referensi',
  });

  factory FileItem.fromMap(Map<String, dynamic> m) => FileItem(
        id: m['id'] as int,
        name: m['name'] as String,
        path: m['path'] as String,
        chapterId: m['chapter_id'] as int?,
        type: m['type'] as String?,
        category: m['category'] as String? ?? 'Referensi',
      );
}
