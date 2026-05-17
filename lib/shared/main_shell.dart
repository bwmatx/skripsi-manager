import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:skripsi_manager/features/progress/presentation/progress_page.dart';
import 'package:skripsi_manager/features/files/presentation/files_page.dart';
import 'package:skripsi_manager/features/ai/presentation/ai_page.dart';
import 'package:skripsi_manager/features/ai/presentation/comparison_page.dart';
import 'package:skripsi_manager/features/account/presentation/account_page.dart';
import 'package:skripsi_manager/core/theme.dart';

final navIndexProvider = StateProvider<int>((ref) => 0);

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _pages = [
    ProgressPage(),
    FilesPage(),
    AiPage(),
    ComparisonPage(),
    AccountPage(),
  ];

  List<BottomNavigationBarItem> get _items => [
    BottomNavigationBarItem(icon: Icon(Icons.checklist_rounded), label: 'Progress'),
    BottomNavigationBarItem(icon: Icon(Icons.folder_rounded), label: 'Files'),
    BottomNavigationBarItem(
      icon: Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: SvgPicture.asset(
          'assets/icon/beauty.svg',
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn),
        ),
      ),
      activeIcon: Padding(
        padding: EdgeInsets.only(bottom: 4),
        child: SvgPicture.asset(
          'assets/icon/beauty.svg',
          width: 20,
          height: 20,
          colorFilter: const ColorFilter.mode(AppTheme.primary, BlendMode.srcIn),
        ),
      ),
      label: 'Arum',
    ),
    BottomNavigationBarItem(icon: Icon(Icons.compare_arrows_rounded), label: 'Compare'),
    BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Akun'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(navIndexProvider);
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(key: ValueKey(index), child: _pages[index]),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.divider)),
        ),
        child: BottomNavigationBar(
          currentIndex: index,
          items: _items,
          onTap: (i) => ref.read(navIndexProvider.notifier).state = i,
        ),
      ),
    );
  }
}
