import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static Database? _db;

  static Future<Database> get instance async {
    _db ??= await _init();
    return _db!;
  }

  static Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'skripsi_manager.db');
    return openDatabase(path, version: 1, onCreate: _onCreate);
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE chapters (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        order_index INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        chapter_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        note TEXT,
        is_done INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        chapter_id INTEGER,
        type TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE account (
        id INTEGER PRIMARY KEY DEFAULT 1,
        name TEXT,
        date_of_birth TEXT,
        thesis_title TEXT,
        current_streak INTEGER NOT NULL DEFAULT 0,
        last_activity_date TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Default PIN
    await db.insert('settings', {'key': 'pin', 'value': '123123'});

    // Seed chapters Bab 1–5
    for (int i = 1; i <= 5; i++) {
      await db.insert('chapters', {'title': 'Bab $i', 'order_index': i});
    }

    // Default account row
    await db.insert('account', {
      'id': 1,
      'name': '',
      'date_of_birth': '',
      'thesis_title': '',
      'current_streak': 0,
      'last_activity_date': '',
    });
  }
}
