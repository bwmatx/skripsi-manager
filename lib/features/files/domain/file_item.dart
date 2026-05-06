class FileItem {
  final int id;
  final String name;
  final String path;
  final int? chapterId;
  final String? type;

  const FileItem({
    required this.id,
    required this.name,
    required this.path,
    this.chapterId,
    this.type,
  });

  factory FileItem.fromMap(Map<String, dynamic> m) => FileItem(
        id: m['id'] as int,
        name: m['name'] as String,
        path: m['path'] as String,
        chapterId: m['chapter_id'] as int?,
        type: m['type'] as String?,
      );
}
