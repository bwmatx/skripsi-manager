class JournalItem {
  final String title;
  final String text;
  final int chapter;
  final int paragraphIndex; // index DALAM point, mulai dari 1
  final int lineIndex;
  final String? pointIndicator;

  const JournalItem({
    required this.title,
    required this.text,
    required this.chapter,
    required this.paragraphIndex,
    required this.lineIndex,
    this.pointIndicator,
  });
}
