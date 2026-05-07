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
    return openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
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
        type TEXT,
        category TEXT DEFAULT 'Referensi',
        authors TEXT,
        year TEXT,
        tags TEXT,
        notes TEXT,
        is_favorite INTEGER DEFAULT 0,
        last_opened INTEGER
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

    // AI chat history — persists AI answers and follow-up Q&A per journal item
    await _createAiChatTable(db);

    // Analysis history — saved academic analysis and comparisons
    await _createAnalysisHistoryTable(db);

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

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createAiChatTable(db);
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE files ADD COLUMN category TEXT DEFAULT \'Referensi\'');
    }
    if (oldVersion < 4) {
      await _createAnalysisHistoryTable(db);
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE files ADD COLUMN authors TEXT');
      await db.execute('ALTER TABLE files ADD COLUMN year TEXT');
      await db.execute('ALTER TABLE files ADD COLUMN tags TEXT');
      await db.execute('ALTER TABLE files ADD COLUMN notes TEXT');
      await db.execute('ALTER TABLE files ADD COLUMN is_favorite INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE files ADD COLUMN last_opened INTEGER');
    }
  }

  static Future<void> _createAiChatTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_chat_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_key TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    // item_key = unique key per journal item (e.g. "bab1_para3_title_hash")
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_chat_item ON ai_chat_history(item_key)',
    );
  }

  static Future<void> _createAnalysisHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS analysis_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        type TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }
}

