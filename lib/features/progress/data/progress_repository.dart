import 'package:skripsi_manager/core/database.dart';
import 'package:skripsi_manager/features/progress/domain/models.dart';

class ProgressRepository {
  Future<List<Chapter>> getChapters() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('chapters', orderBy: 'order_index ASC');
    return rows.map(Chapter.fromMap).toList();
  }

  Future<int> addChapter(String title) async {
    final db = await AppDatabase.instance;
    final count = (await db.query('chapters')).length;
    return db.insert('chapters', {'title': title, 'order_index': count + 1});
  }

  Future<void> deleteChapter(int id) async {
    final db = await AppDatabase.instance;
    await db.delete('tasks', where: 'chapter_id = ?', whereArgs: [id]);
    await db.delete('chapters', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Task>> getTasks(int chapterId) async {
    final db = await AppDatabase.instance;
    final rows = await db.query('tasks', where: 'chapter_id = ?', whereArgs: [chapterId]);
    return rows.map(Task.fromMap).toList();
  }

  Future<List<Task>> getAllTasks() async {
    final db = await AppDatabase.instance;
    final rows = await db.query('tasks');
    return rows.map(Task.fromMap).toList();
  }

  Future<int> addTask(int chapterId, String title, {String? note}) async {
    final db = await AppDatabase.instance;
    return db.insert('tasks', {
      'chapter_id': chapterId,
      'title': title,
      'note': note,
      'is_done': 0,
    });
  }

  Future<void> updateTask(Task task) async {
    final db = await AppDatabase.instance;
    await db.update(
      'tasks',
      {'title': task.title, 'note': task.note, 'is_done': task.isDone ? 1 : 0},
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<void> deleteTask(int id) async {
    final db = await AppDatabase.instance;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleTask(int id, bool isDone) async {
    final db = await AppDatabase.instance;
    await db.update('tasks', {'is_done': isDone ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }
}
