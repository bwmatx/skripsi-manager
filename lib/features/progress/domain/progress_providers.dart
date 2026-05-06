import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skripsi_manager/features/progress/data/progress_repository.dart';
import 'package:skripsi_manager/features/progress/domain/models.dart';

final progressRepoProvider = Provider((_) => ProgressRepository());

// All chapters
final chaptersProvider = FutureProvider<List<Chapter>>((ref) {
  return ref.read(progressRepoProvider).getChapters();
});

// Tasks for a given chapter
final tasksProvider = FutureProvider.family<List<Task>, int>((ref, chapterId) {
  return ref.read(progressRepoProvider).getTasks(chapterId);
});

// Global progress: (done, total)
final globalProgressProvider = FutureProvider<(int, int)>((ref) async {
  final all = await ref.read(progressRepoProvider).getAllTasks();
  final done = all.where((t) => t.isDone).length;
  return (done, all.length);
});
