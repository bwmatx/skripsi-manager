import 'package:skripsi_manager/core/database.dart';

/// A single message in the AI chat conversation.
class AiChatMessage {
  final int? id;
  final String itemKey;
  final String role; // 'user' or 'assistant'
  final String content;
  final DateTime createdAt;

  const AiChatMessage({
    this.id,
    required this.itemKey,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory AiChatMessage.fromMap(Map<String, dynamic> map) {
    return AiChatMessage(
      id: map['id'] as int?,
      itemKey: map['item_key'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() => {
        'item_key': itemKey,
        'role': role,
        'content': content,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}

/// Repository for persisting AI chat history to SQLite.
/// Uses the existing AppDatabase — no new DB connection.
class AiChatRepository {
  /// Load all messages for a given [itemKey] ordered by creation time.
  Future<List<AiChatMessage>> getMessages(String itemKey) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'ai_chat_history',
      where: 'item_key = ?',
      whereArgs: [itemKey],
      orderBy: 'created_at ASC',
    );
    return rows.map(AiChatMessage.fromMap).toList();
  }

  /// Insert a single message and return its new id.
  Future<int> addMessage(AiChatMessage msg) async {
    final db = await AppDatabase.instance;
    return db.insert('ai_chat_history', msg.toMap());
  }

  /// Delete all messages for [itemKey] (used by "Hapus Jawaban AI").
  Future<void> deleteHistory(String itemKey) async {
    final db = await AppDatabase.instance;
    await db.delete(
      'ai_chat_history',
      where: 'item_key = ?',
      whereArgs: [itemKey],
    );
  }
}
