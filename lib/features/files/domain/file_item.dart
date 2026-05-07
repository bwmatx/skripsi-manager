class FileItem {
  final int id;
  final String name;
  final String path;
  final int? chapterId;
  final String? type;
  final String category;
  final String? authors;
  final String? year;
  final String? tags;
  final String? notes;
  final bool isFavorite;
  final DateTime? lastOpened;

  const FileItem({
    required this.id,
    required this.name,
    required this.path,
    this.chapterId,
    this.type,
    this.category = 'Referensi',
    this.authors,
    this.year,
    this.tags,
    this.notes,
    this.isFavorite = false,
    this.lastOpened,
  });

  factory FileItem.fromMap(Map<String, dynamic> m) => FileItem(
        id: m['id'] as int,
        name: m['name'] as String,
        path: m['path'] as String,
        chapterId: m['chapter_id'] as int?,
        type: m['type'] as String?,
        category: m['category'] as String? ?? 'Referensi',
        authors: m['authors'] as String?,
        year: m['year'] as String?,
        tags: m['tags'] as String?,
        notes: m['notes'] as String?,
        isFavorite: (m['is_favorite'] as int?) == 1,
        lastOpened: m['last_opened'] != null
            ? DateTime.fromMillisecondsSinceEpoch(m['last_opened'] as int)
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'path': path,
        'chapter_id': chapterId,
        'type': type,
        'category': category,
        'authors': authors,
        'year': year,
        'tags': tags,
        'notes': notes,
        'is_favorite': isFavorite ? 1 : 0,
        'last_opened': lastOpened?.millisecondsSinceEpoch,
      };
}
