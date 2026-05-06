import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skripsi_manager/core/theme.dart';
import 'package:skripsi_manager/features/progress/domain/models.dart';
import 'package:skripsi_manager/features/progress/domain/progress_providers.dart';
import 'package:skripsi_manager/features/account/data/account_repository.dart';

class ProgressPage extends ConsumerWidget {
  const ProgressPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chaptersProvider);
    final globalAsync = ref.watch(globalProgressProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Skripsi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddChapterDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          // Global progress card
          globalAsync.when(
            data: (p) => _GlobalProgressCard(done: p.$1, total: p.$2),
            loading: () => const SizedBox(height: 80),
            error: (_, _) => const SizedBox(),
          ),
          Expanded(
            child: chaptersAsync.when(
              data: (chapters) => chapters.isEmpty
                  ? const Center(
                      child: Text('Belum ada bab', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: chapters.length,
                      itemBuilder: (_, i) => _ChapterCard(chapter: chapters[i]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _submitProgress(context, ref),
        icon: const Icon(Icons.send_rounded),
        label: const Text('Submit Progress'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  Future<void> _submitProgress(BuildContext context, WidgetRef ref) async {
    final repo = AccountRepository();
    await repo.submitProgress();
    ref.invalidate(globalProgressProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Progress berhasil disubmit. Streak diperbarui!')),
    );
  }

  Future<void> _showAddChapterDialog(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Tambah Bab', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Judul Bab'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await ref.read(progressRepoProvider).addChapter(ctrl.text.trim());
              ref.invalidate(chaptersProvider);
              ref.invalidate(globalProgressProvider);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}

class _GlobalProgressCard extends StatelessWidget {
  final int done;
  final int total;
  const _GlobalProgressCard({required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : done / total;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primary, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progress Global', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            '${(pct * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text('$done dari $total tugas selesai',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ChapterCard extends ConsumerWidget {
  final Chapter chapter;
  const _ChapterCard({required this.chapter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider(chapter.id));

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: tasksAsync.when(
          data: (tasks) {
            final done = tasks.where((t) => t.isDone).length;
            final total = tasks.length;
            return Row(
              children: [
                Expanded(
                  child: Text(chapter.title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                ),
                Text('$done/$total',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            );
          },
          loading: () => Text(chapter.title,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
          error: (_, _) => Text(chapter.title),
        ),
        subtitle: tasksAsync.maybeWhen(
          data: (tasks) {
            final pct = tasks.isEmpty ? 0.0 : tasks.where((t) => t.isDone).length / tasks.length;
            return Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 4,
                  backgroundColor: AppTheme.divider,
                ),
              ),
            );
          },
          orElse: () => null,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_rounded, color: AppTheme.primary, size: 20),
              onPressed: () => _showAddTaskDialog(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.error, size: 20),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
        children: [
          tasksAsync.when(
            data: (tasks) => tasks.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Belum ada tugas',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                  )
                : Column(
                    children: tasks
                        .map((t) => _TaskTile(task: t, chapterId: chapter.id))
                        .toList(),
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Tambah Tugas', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Judul Tugas')),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Catatan (opsional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              await ref.read(progressRepoProvider).addTask(
                    chapter.id, titleCtrl.text.trim(),
                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
              ref.invalidate(tasksProvider(chapter.id));
              ref.invalidate(globalProgressProvider);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Hapus Bab?', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Semua tugas di ${chapter.title} akan dihapus.',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(progressRepoProvider).deleteChapter(chapter.id);
      ref.invalidate(chaptersProvider);
      ref.invalidate(globalProgressProvider);
    }
  }
}

class _TaskTile extends ConsumerWidget {
  final Task task;
  final int chapterId;
  const _TaskTile({required this.task, required this.chapterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Checkbox(
        value: task.isDone,
        onChanged: (v) async {
          await ref.read(progressRepoProvider).toggleTask(task.id, v ?? false);
          ref.invalidate(tasksProvider(chapterId));
          ref.invalidate(globalProgressProvider);
        },
      ),
      title: Text(
        task.title,
        style: TextStyle(
          color: task.isDone ? AppTheme.textSecondary : AppTheme.textPrimary,
          decoration: task.isDone ? TextDecoration.lineThrough : null,
          fontSize: 14,
        ),
      ),
      subtitle: task.note != null && task.note!.isNotEmpty
          ? Text(task.note!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
            onPressed: () => _showEditDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.error),
            onPressed: () async {
              await ref.read(progressRepoProvider).deleteTask(task.id);
              ref.invalidate(tasksProvider(chapterId));
              ref.invalidate(globalProgressProvider);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController(text: task.title);
    final noteCtrl = TextEditingController(text: task.note ?? '');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.card,
        title: const Text('Edit Tugas', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Judul Tugas')),
            const SizedBox(height: 12),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Catatan')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              if (titleCtrl.text.trim().isEmpty) return;
              await ref.read(progressRepoProvider).updateTask(task.copyWith(
                    title: titleCtrl.text.trim(),
                    note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim()));
              ref.invalidate(tasksProvider(chapterId));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
