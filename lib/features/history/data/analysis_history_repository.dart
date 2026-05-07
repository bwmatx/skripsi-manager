import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skripsi_manager/core/database.dart';

class AnalysisHistory {
  final int? id;
  final String title;
  final String type; // 'AI Analysis', 'Comparison', 'Summary'
  final String content;
  final DateTime createdAt;

  const AnalysisHistory({
    this.id,
    required this.title,
    required this.type,
    required this.content,
    required this.createdAt,
  });

  factory AnalysisHistory.fromMap(Map<String, dynamic> map) {
    return AnalysisHistory(
      id: map['id'] as int?,
      title: map['title'] as String,
      type: map['type'] as String,
      content: map['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'type': type,
        'content': content,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}

class AnalysisHistoryRepository {
  Future<List<AnalysisHistory>> getAll() async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'analysis_history',
      orderBy: 'created_at DESC',
    );
    return rows.map(AnalysisHistory.fromMap).toList();
  }

  Future<int> insert(AnalysisHistory history) async {
    final db = await AppDatabase.instance;
    return await db.insert('analysis_history', history.toMap());
  }

  Future<void> delete(int id) async {
    final db = await AppDatabase.instance;
    await db.delete(
      'analysis_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

final analysisHistoryRepositoryProvider = Provider((ref) => AnalysisHistoryRepository());

final analysisHistoryListProvider = FutureProvider<List<AnalysisHistory>>((ref) async {
  return ref.read(analysisHistoryRepositoryProvider).getAll();
});
