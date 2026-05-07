import 'package:skripsi_manager/core/database.dart';
import 'package:skripsi_manager/features/files/domain/file_item.dart';

class FilesRepository {
  Future<List<FileItem>> getFiles({int? chapterId}) async {
    final db = await AppDatabase.instance;
    final rows = chapterId != null
        ? await db.query('files', where: 'chapter_id = ?', whereArgs: [chapterId])
        : await db.query('files');
    return rows.map(FileItem.fromMap).toList();
  }

  Future<int> addFile(String name, String path, {int? chapterId, String? type}) async {
    final db = await AppDatabase.instance;
    return db.insert('files', {
      'name': name,
      'path': path,
      'chapter_id': chapterId,
      'type': type ?? _detectType(name),
    });
  }

  Future<void> deleteFile(int id) async {
    final db = await AppDatabase.instance;
    await db.delete('files', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateCategory(int id, String category) async {
    final db = await AppDatabase.instance;
    await db.update('files', {'category': category}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateMetadata(int id, {
    String? authors,
    String? year,
    String? tags,
    String? notes,
  }) async {
    final db = await AppDatabase.instance;
    final Map<String, dynamic> data = {};
    if (authors != null) data['authors'] = authors;
    if (year != null) data['year'] = year;
    if (tags != null) data['tags'] = tags;
    if (notes != null) data['notes'] = notes;
    
    if (data.isEmpty) return;

    await db.update(
      'files',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> toggleFavorite(int id, bool isFavorite) async {
    final db = await AppDatabase.instance;
    await db.update('files', {'is_favorite': isFavorite ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markAsOpened(int id) async {
    final db = await AppDatabase.instance;
    await db.update('files', {'last_opened': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);
  }

  String _detectType(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['pdf'].contains(ext)) return 'pdf';
    if (['doc', 'docx'].contains(ext)) return 'docx';
    if (['jpg', 'jpeg', 'png'].contains(ext)) return 'image';
    return 'other';
  }
}
