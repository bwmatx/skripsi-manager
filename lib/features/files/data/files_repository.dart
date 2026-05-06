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

  String _detectType(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['pdf'].contains(ext)) return 'pdf';
    if (['doc', 'docx'].contains(ext)) return 'docx';
    if (['jpg', 'jpeg', 'png'].contains(ext)) return 'image';
    return 'other';
  }
}
