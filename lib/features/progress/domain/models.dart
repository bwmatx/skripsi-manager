class Chapter {
  final int id;
  final String title;
  final int orderIndex;

  const Chapter({required this.id, required this.title, required this.orderIndex});

  factory Chapter.fromMap(Map<String, dynamic> m) => Chapter(
        id: m['id'] as int,
        title: m['title'] as String,
        orderIndex: m['order_index'] as int,
      );
}

class Task {
  final int id;
  final int chapterId;
  final String title;
  final String? note;
  final bool isDone;

  const Task({
    required this.id,
    required this.chapterId,
    required this.title,
    this.note,
    required this.isDone,
  });

  factory Task.fromMap(Map<String, dynamic> m) => Task(
        id: m['id'] as int,
        chapterId: m['chapter_id'] as int,
        title: m['title'] as String,
        note: m['note'] as String?,
        isDone: (m['is_done'] as int) == 1,
      );

  Task copyWith({String? title, String? note, bool? isDone}) => Task(
        id: id,
        chapterId: chapterId,
        title: title ?? this.title,
        note: note ?? this.note,
        isDone: isDone ?? this.isDone,
      );
}
