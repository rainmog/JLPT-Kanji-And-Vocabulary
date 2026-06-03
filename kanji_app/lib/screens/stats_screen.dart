import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/vocab_repository.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import 'dictionary_screen.dart';
import '../utils/app_route.dart';
import 'vocab_list_screen.dart';

final _progressProvider = FutureProvider.autoDispose((ref) => kanjiRepo.getProgressByLevel());
final _tagProgressProvider = FutureProvider.autoDispose((ref) => kanjiRepo.getProgressByTag());

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});
  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  final _pageController = PageController();
  int _page = 0;
  bool _addLearnedMode = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        automaticallyImplyLeading: false,
        leading: _page == 1
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios, color: AppColors.accent),
              onPressed: () => _pageController.animateToPage(0,
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
            )
          : IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.fg),
              onPressed: () => Navigator.pop(context),
            ),
        title: Text(_page == 0 ? 'Kanji' : 'Vocabulary',
          style: TextStyle(color: AppColors.fg)),
        actions: [
          if (_page == 0) ...[
            IconButton(
              icon: Icon(
                _addLearnedMode ? Icons.school : Icons.school_outlined,
                color: _addLearnedMode ? AppColors.accent : AppColors.fg,
              ),
              tooltip: 'Add Learned Kanji',
              onPressed: () => setState(() => _addLearnedMode = !_addLearnedMode),
            ),
            IconButton(
              icon: Icon(Icons.arrow_forward_ios, color: AppColors.accent),
              onPressed: () => _pageController.animateToPage(1,
                duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
            ),
          ],
        ],
        iconTheme: IconThemeData(color: AppColors.fg),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (p) => setState(() => _page = p),
        children: [
          _KanjiDictionaryPage(
            addLearnedMode: _addLearnedMode,
          ),
          _VocabDictionaryPage(),
        ],
      ),
    );
  }
}

class _KanjiDictionaryPage extends ConsumerWidget {
  final bool addLearnedMode;

  const _KanjiDictionaryPage({
    required this.addLearnedMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(_progressProvider);
    final tagProgress = ref.watch(_tagProgressProvider);
    return progress.when(
      data: (map) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (addLearnedMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Tap a level to mark its kanji as learned',
                style: TextStyle(fontSize: 13, color: AppColors.accent),
                textAlign: TextAlign.center,
              ),
            ),
          _SetHomeProgressLink(
            settingsKey: 'kanji',
            value: 'total',
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, AppRoute.to(const DictionaryScreen())),
              child: const Text('Full Kanji Dictionary'),
            ),
          ),
          const SizedBox(height: 8),
          ...[5, 4, 3, 2, 1].map((level) {
            final p = map[level];
            if (p == null) return const SizedBox.shrink();
            final fraction = p.total == 0 ? 0.0 : p.learned / p.total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SetHomeProgressLink(
                settingsKey: 'kanji',
                value: 'N$level',
                child: Material(
                  color: AppColors.pillBg,
                  borderRadius: BorderRadius.circular(AppColors.containerRadius),
                  child: InkWell(
                    onTap: () => Navigator.push(context, AppRoute.to(DictionaryScreen(jlptLevels: [level], title: 'N$level Kanji'))),
                    borderRadius: BorderRadius.circular(AppColors.containerRadius),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('JLPT N$level', style: TextStyle(color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('${p.learned}/${p.total}', style: TextStyle(color: AppColors.accentBright, fontSize: 14, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppColors.containerRadius),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 8,
                            backgroundColor: AppColors.bg,
                            valueColor: AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),

          tagProgress.when(
            data: (tags) {
              const hiddenTags = {'n1', 'n2', 'n3', 'n4', 'advanced', 'beginner', 'intermediate'};
              final visible = tags.entries.where((e) => !hiddenTags.contains(e.key)).toList();
              if (visible.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('By Word Group', style: TextStyle(fontSize: 10, color: AppColors.muted, letterSpacing: 1)),
                  ),
                  ...visible.map((e) {
                    final tag = e.key;
                    final p = e.value;
                    final fraction = p.total == 0 ? 0.0 : p.learned / p.total;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: AppColors.pillBg,
                        borderRadius: BorderRadius.circular(AppColors.containerRadius),
                        child: InkWell(
                          onTap: () => Navigator.push(context, AppRoute.to(DictionaryScreen(tag: tag, title: tag))),
                          borderRadius: BorderRadius.circular(AppColors.containerRadius),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text(tag, style: TextStyle(color: AppColors.fg, fontSize: 15, fontWeight: FontWeight.w600)),
                                Text('${p.learned}/${p.total}', style: TextStyle(color: AppColors.accentBright, fontSize: 13, fontWeight: FontWeight.w600)),
                              ]),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppColors.containerRadius),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  minHeight: 6,
                                  backgroundColor: AppColors.bg,
                                  valueColor: AlwaysStoppedAnimation(AppColors.accent),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

final _vocabProgressProvider = FutureProvider.autoDispose((ref) => vocabRepo.getProgressByLevel());
final _vocabTagProgressProvider = FutureProvider.autoDispose((ref) => vocabRepo.getProgressByTag());

class _SetHomeProgressLink extends ConsumerWidget {
  final String settingsKey; // 'kanji' or 'vocab'
  final String value;       // 'total' | 'N5'..'N1'
  final Widget child;

  const _SetHomeProgressLink({
    required this.settingsKey,
    required this.value,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final current = settingsKey == 'kanji' ? s.homeKanjiProgress : s.homeVocabProgress;
    final isActive = current == value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: isActive ? null : () {
                final updated = settingsKey == 'kanji'
                    ? s.copyWith(homeKanjiProgress: value)
                    : s.copyWith(homeVocabProgress: value);
                ref.read(settingsProvider.notifier).update(updated);
              },
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  isActive ? Icons.bar_chart : Icons.bar_chart_outlined,
                  size: 20,
                  color: isActive ? AppColors.accent : AppColors.muted,
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
        if (isActive)
          Padding(
            padding: const EdgeInsets.only(left: 28, top: 3, bottom: 2),
            child: Text(
              'Showing on homescreen.',
              style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}

class _VocabDictionaryPage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(_vocabProgressProvider);
    final tagsAsync = ref.watch(_vocabTagProgressProvider);
    return progressAsync.when(
      data: (map) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SetHomeProgressLink(
            settingsKey: 'vocab',
            value: 'total',
            child: ElevatedButton(
              onPressed: () => Navigator.push(context, AppRoute.to(
                const VocabListScreen(filter: VocabFilter.all()))),
              child: const Text('Full Vocabulary Dictionary'),
            ),
          ),
          const SizedBox(height: 8),
          ...[5, 4, 3, 2, 1].map((level) {
            final p = map[level];
            if (p == null) return const SizedBox.shrink();
            final fraction = p.total == 0 ? 0.0 : p.learned / p.total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SetHomeProgressLink(
                settingsKey: 'vocab',
                value: 'N$level',
                child: Material(
                  color: AppColors.pillBg,
                  borderRadius: BorderRadius.circular(AppColors.containerRadius),
                  child: InkWell(
                    onTap: () => Navigator.push(context, AppRoute.to(
                      VocabListScreen(filter: VocabFilter.level(level)))),
                    borderRadius: BorderRadius.circular(AppColors.containerRadius),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text('JLPT N$level', style: TextStyle(color: AppColors.fg, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('${p.learned}/${p.total}', style: TextStyle(color: AppColors.accentBright, fontSize: 14, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppColors.containerRadius),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 8,
                            backgroundColor: AppColors.bg,
                            valueColor: AlwaysStoppedAnimation(AppColors.accent),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),

          tagsAsync.when(
            data: (tagProgress) {
              if (tagProgress.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('By Word Group', style: TextStyle(fontSize: 10, color: AppColors.muted, letterSpacing: 1)),
                  ),
                  ...tagProgress.entries.map((e) {
                    final tag = e.key;
                    final p = e.value;
                    final fraction = p.total == 0 ? 0.0 : p.learned / p.total;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: AppColors.pillBg,
                        borderRadius: BorderRadius.circular(AppColors.containerRadius),
                        child: InkWell(
                          onTap: () => Navigator.push(context, AppRoute.to(
                            VocabListScreen(filter: VocabFilter.tag(tag)))),
                          borderRadius: BorderRadius.circular(AppColors.containerRadius),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text(tag, style: TextStyle(color: AppColors.fg, fontSize: 15, fontWeight: FontWeight.w600)),
                                Text('${p.learned}/${p.total}', style: TextStyle(color: AppColors.accentBright, fontSize: 13, fontWeight: FontWeight.w600)),
                              ]),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppColors.containerRadius),
                                child: LinearProgressIndicator(
                                  value: fraction,
                                  minHeight: 6,
                                  backgroundColor: AppColors.bg,
                                  valueColor: AlwaysStoppedAnimation(AppColors.accent),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}
