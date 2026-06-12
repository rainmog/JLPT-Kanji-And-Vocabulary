import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../theme_provider.dart';
import 'home_screen.dart';
import 'jlpt_test_intro_screen.dart';
import 'progress_screen.dart';
import 'vocabulary_dictionary_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          HomeScreen(),
          ProgressScreen(),
          VocabularyDictionaryScreen(),
          JlptTestScreen(),
        ],
      ),
      bottomNavigationBar: _AppNavBar(
        current: _tabIndex,
        colors: colors,
        onTap: (i) => setState(() => _tabIndex = i),
      ),
    );
  }
}

class _AppNavBar extends StatelessWidget {
  final int current;
  final ThemeColors colors;
  final void Function(int) onTap;

  const _AppNavBar({
    required this.current,
    required this.colors,
    required this.onTap,
  });

  static const _tabs = [
    (icon: Icons.auto_awesome_rounded, label: 'Study & Test'),
    (icon: Icons.bar_chart_rounded,    label: 'Progress'),
    (icon: Icons.menu_book_rounded,    label: 'Dictionary'),
    (icon: Icons.school_rounded,       label: 'JLPT'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: KDesign.line(colors))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            children: [
              for (int i = 0; i < _tabs.length; i++)
                _NavItem(
                  icon: _tabs[i].icon,
                  label: _tabs[i].label,
                  active: i == current,
                  colors: colors,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: active ? 54 : 40,
              height: 28,
              decoration: BoxDecoration(
                color: active ? KDesign.tint(colors) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color: active ? colors.accent : KDesign.inkFaint(colors),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                color: active ? colors.accent : KDesign.inkFaint(colors),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
