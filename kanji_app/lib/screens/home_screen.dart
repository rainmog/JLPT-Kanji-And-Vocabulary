import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kana_repository.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/progress_repository.dart';
import '../repositories/vocab_repository.dart';
import '../services/auto_progression_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../theme/app_theme_backgrounds.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/falling_blocks_overlay.dart';
import '../widgets/sakura_overlay.dart';
import '../widgets/snow_overlay.dart';
import '../widgets/space_age_overlay.dart';
import '../repositories/history_repository.dart';
import 'credits_screen.dart';
import 'settings_screen.dart';
import 'study_picker_screen.dart';
import 'targets_screen.dart';
import 'test_hub_screen.dart';

// All progress data needed for home trackers, fetched in one go
final allProgressProvider = FutureProvider.autoDispose<_ProgressData>((ref) async {
  final kanjiByLevel = await kanjiRepo.getProgressByLevel();
  final kanjiByTag   = await kanjiRepo.getProgressByTag();
  final vocabByLevel = await vocabRepo.getProgressByLevel();
  final vocabByTag   = await vocabRepo.getProgressByTag();
  final hiragana     = await kanaRepo.getProgress(type: 'hiragana');
  final katakana     = await kanaRepo.getProgress(type: 'katakana');

  int kTotal = 0, kLearned = 0;
  for (final e in kanjiByLevel.values) { kTotal += e.total; kLearned += e.learned; }
  int vTotal = 0, vLearned = 0;
  for (final e in vocabByLevel.values) { vTotal += e.total; vLearned += e.learned; }

  return _ProgressData(
    kanjiAll: (learned: kLearned, total: kTotal),
    vocabAll: (learned: vLearned, total: vTotal),
    hiragana: (learned: hiragana.learned, total: hiragana.total),
    katakana: (learned: katakana.learned, total: katakana.total),
    kanjiByLevel: kanjiByLevel,
    vocabByLevel: vocabByLevel,
    kanjiByTag: kanjiByTag,
    vocabByTag: vocabByTag,
  );
});

final _todayGoalProvider = FutureProvider.autoDispose<int>(
  (_) => progressRepo.getTodaySessionCount(),
);

final _graduationCandidatesProvider = FutureProvider.autoDispose<({
  bool hasKanji, bool hasVocab, bool hasKana
})>((_) async {
  const threshold = 10;
  final kanjiCount = await kanjiRepo.getHighPracticeTargetCount(threshold);
  final vocabCount = await vocabRepo.getHighPracticeTargetCount(threshold);
  final kanaCount = await kanaRepo.getHighPracticeTargetCount(threshold);
  return (
    hasKanji: kanjiCount >= 10,
    hasVocab: vocabCount >= 10,
    hasKana: kanaCount >= 10,
  );
});

final jlptTestDataProvider = FutureProvider.autoDispose
    .family<_JlptTestData, int>((ref, level) async {
  final all = await historyRepo.getHistory(testType: 'jlpt');
  final entries = all.where((e) => e.level == level).toList();
  return _JlptTestData.fromHistory(entries);
});

final _targetCountProvider = FutureProvider.autoDispose<({int kanji, int vocab, int kana})>((ref) async {
  final kanjiCount = await kanjiRepo.getTargetKanjiList().then((l) => l.length);
  final vocabCount = await vocabRepo.getTargetCount();
  final kanaProgress = await kanaRepo.getProgress();
  final kanaTargeted = kanaProgress.targeted;
  return (kanji: kanjiCount, vocab: vocabCount, kana: kanaTargeted);
});

class _SectionResult {
  final int score, total;
  const _SectionResult(this.score, this.total);
  double get pct => total == 0 ? 0 : score / total;
}

class _JlptTestData {
  final _SectionResult? vocab;
  final _SectionResult? grammar;
  final _SectionResult? reading;
  final _SectionResult? lastFullTest;
  final _SectionResult? combinedBests;

  const _JlptTestData({
    this.vocab, this.grammar, this.reading,
    this.lastFullTest, this.combinedBests,
  });

  bool get hasAnyData => vocab != null || grammar != null || reading != null;

  static _JlptTestData fromHistory(List<TestHistoryEntry> entries) {
    _SectionResult? vocabResult, grammarResult, readingResult, lastFullTest;
    int vocabBest = -1, grammarBest = -1, readingBest = -1;
    int vocabBestTotal = 0, grammarBestTotal = 0, readingBestTotal = 0;

    for (final e in entries) {
      if (e.section == null) {
        lastFullTest ??= _SectionResult(e.score, e.total);
        final d = e.detail;
        if (d != null) {
          final v = d['vocabulary'] as List?;
          final g = d['grammar'] as List?;
          final r = d['reading'] as List?;
          if (v != null) {
            vocabResult ??= _SectionResult(v[0] as int, v[1] as int);
            if ((v[0] as int) > vocabBest) { vocabBest = v[0] as int; vocabBestTotal = v[1] as int; }
          }
          if (g != null) {
            grammarResult ??= _SectionResult(g[0] as int, g[1] as int);
            if ((g[0] as int) > grammarBest) { grammarBest = g[0] as int; grammarBestTotal = g[1] as int; }
          }
          if (r != null) {
            readingResult ??= _SectionResult(r[0] as int, r[1] as int);
            if ((r[0] as int) > readingBest) { readingBest = r[0] as int; readingBestTotal = r[1] as int; }
          }
        }
      } else if (e.section == 'vocabulary') {
        vocabResult ??= _SectionResult(e.score, e.total);
        if (e.score > vocabBest) { vocabBest = e.score; vocabBestTotal = e.total; }
      } else if (e.section == 'grammar') {
        grammarResult ??= _SectionResult(e.score, e.total);
        if (e.score > grammarBest) { grammarBest = e.score; grammarBestTotal = e.total; }
      } else if (e.section == 'reading') {
        readingResult ??= _SectionResult(e.score, e.total);
        if (e.score > readingBest) { readingBest = e.score; readingBestTotal = e.total; }
      }
    }

    _SectionResult? combinedBests;
    if (vocabBest >= 0 || grammarBest >= 0 || readingBest >= 0) {
      final s = (vocabBest >= 0 ? vocabBest : 0) +
                (grammarBest >= 0 ? grammarBest : 0) +
                (readingBest >= 0 ? readingBest : 0);
      final t = vocabBestTotal + grammarBestTotal + readingBestTotal;
      combinedBests = _SectionResult(s, t);
    }

    return _JlptTestData(
      vocab: vocabResult, grammar: grammarResult, reading: readingResult,
      lastFullTest: lastFullTest, combinedBests: combinedBests,
    );
  }
}

({int remaining, int total}) _jlptCumulative(
    Map<int, ({int learned, int total})> byLevel, int goal) {
  int tot = 0, learned = 0;
  for (int lvl = goal; lvl <= 5; lvl++) {
    final p = byLevel[lvl];
    if (p != null) { tot += p.total; learned += p.learned; }
  }
  return (remaining: tot - learned, total: tot);
}

class _ProgressData {
  final ({int learned, int total}) kanjiAll;
  final ({int learned, int total}) vocabAll;
  final ({int learned, int total}) hiragana;
  final ({int learned, int total}) katakana;
  final Map<int, ({int learned, int total})> kanjiByLevel;
  final Map<int, ({int learned, int total})> vocabByLevel;
  final Map<String, ({int learned, int total})> kanjiByTag;
  final Map<String, ({int learned, int total})> vocabByTag;

  const _ProgressData({
    required this.kanjiAll, required this.vocabAll,
    required this.hiragana, required this.katakana,
    required this.kanjiByLevel, required this.vocabByLevel,
    required this.kanjiByTag, required this.vocabByTag,
  });

  // Resolve a tracker ID to (label, learned, total)
  ({String label, int learned, int total})? resolve(String id) {
    if (id == 'kanji:all')       return (label: 'All Kanji',    learned: kanjiAll.learned, total: kanjiAll.total);
    if (id == 'vocab:all')       return (label: 'All Vocab',     learned: vocabAll.learned, total: vocabAll.total);
    if (id == 'hiragana:all')    return (label: 'All Hiragana',  learned: hiragana.learned, total: hiragana.total);
    if (id == 'katakana:all')    return (label: 'All Katakana',  learned: katakana.learned, total: katakana.total);
    if (id.startsWith('kanji:N')) {
      final lvl = int.tryParse(id.substring(7));
      if (lvl != null) {
        final p = kanjiByLevel[lvl]; // jlpt_level: 5=N5..1=N1
        if (p != null) return (label: 'Kanji N$lvl', learned: p.learned, total: p.total);
      }
    }
    if (id.startsWith('vocab:N')) {
      final lvl = int.tryParse(id.substring(7));
      if (lvl != null) {
        final p = vocabByLevel[lvl];
        if (p != null) return (label: 'Vocab N$lvl', learned: p.learned, total: p.total);
      }
    }
    if (id.startsWith('kanji:tag:')) {
      final tag = id.substring(10);
      final p = kanjiByTag[tag];
      if (p != null) return (label: tag[0].toUpperCase() + tag.substring(1), learned: p.learned, total: p.total);
    }
    if (id.startsWith('vocab:tag:')) {
      final tag = id.substring(10);
      final p = vocabByTag[tag];
      if (p != null) return (label: 'Vocab: ${tag[0].toUpperCase()}${tag.substring(1)}', learned: p.learned, total: p.total);
    }
    return null;
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAutoProgression());
  }

  Future<void> _runAutoProgression() async {
    final settings = ref.read(settingsProvider);
    if (!settings.autoProgressionEnabled) return;
    final (:result, :updatedSettings) = await autoProgressionService.run(settings: settings);
    if (!mounted) return;
    await ref.read(settingsProvider.notifier).update(updatedSettings);
    if (!mounted) return;
    if (result.addedKanji > 0 || result.addedVocab > 0 || result.addedKana > 0) {
      ref.invalidate(_targetCountProvider);
      ref.invalidate(allProgressProvider);
    }
    if (result.hasCompletions && mounted) {
      _showCompletionDialog(result);
    }
  }

  void _showCompletionDialog(AutoProgressionResult result) {
    final lines = <String>[
      for (final lvl in result.newlyCompletedKanjiLevels)
        'All N$lvl kanji learned!',
      for (final lvl in result.newlyCompletedVocabLevels)
        'All N$lvl vocabulary learned!',
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Level Complete!'),
        content: Text(lines.join('\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep going!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final progressAsync = ref.watch(allProgressProvider);
    final targetAsync = ref.watch(_targetCountProvider);
    final todayDone = ref.watch(_todayGoalProvider).asData?.value ?? 0;
    final gradAsync = ref.watch(_graduationCandidatesProvider);
    final goal = settings.dailyGoal;

    final jlptTestAsync = settings.jlptGoal > 0
        ? ref.watch(jlptTestDataProvider(settings.jlptGoal))
        : const AsyncData<_JlptTestData>(_JlptTestData());

    final deep = KDesign.deep(colors);

    final appTheme = ref.watch(themeNotifier);
    final hasAnimatedBg = const {
      AppTheme.galaxy, AppTheme.loveLetter,
      AppTheme.lily, AppTheme.totoro, AppTheme.midnightCity,
    }.contains(appTheme);

    final bumper = MediaQuery.of(context).size.height * 0.034;
    final heroGap = MediaQuery.of(context).size.height * 0.030;

    return Scaffold(
      backgroundColor: hasAnimatedBg ? Colors.transparent : colors.bg,
      body: Stack(children: [
        const Positioned.fill(child: HomeBgLayer()),
        const Positioned.fill(child: SakuraPetalsOverlay()),
        const Positioned.fill(child: SpaceAgeStarsOverlay()),
        const Positioned.fill(child: SnowOverlay()),
        const Positioned.fill(child: FallingBlocksOverlay()),
        SafeArea(child: SingleChildScrollView(physics: const ClampingScrollPhysics(), child: Column(children: [
          SizedBox(height: bumper),

          // ── Top icon bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _TopIconBtn(
                  icon: settings.sfxEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  active: settings.sfxEnabled,
                  colors: colors,
                  onTap: () {
                    final updated = settings.copyWith(sfxEnabled: !settings.sfxEnabled);
                    settingsNotifier.update(updated);
                    soundService.sfxEnabled = updated.sfxEnabled;
                  },
                ),
                const SizedBox(width: 8),
                _TopIconBtn(
                  icon: settings.ambientEnabled ? Icons.music_note_rounded : Icons.music_off_rounded,
                  active: settings.ambientEnabled,
                  colors: colors,
                  onTap: () {
                    final updated = settings.copyWith(ambientEnabled: !settings.ambientEnabled);
                    settingsNotifier.update(updated);
                    soundService.ambientEnabled = updated.ambientEnabled;
                    if (!updated.ambientEnabled) {
                      soundService.stopAmbient();
                    } else if (settings.ambientSfx != 'none') {
                      soundService.setAmbient(settings.ambientSfx);
                    }
                  },
                ),
                const SizedBox(width: 8),
                _TopIconBtn(
                  icon: Icons.info_outline_rounded,
                  active: true,
                  colors: colors,
                  onTap: () => Navigator.push(context, AppRoute.to(const CreditsScreen())),
                ),
                const SizedBox(width: 8),
                _TopIconBtn(
                  icon: Icons.settings_rounded,
                  active: true,
                  colors: colors,
                  onTap: () => Navigator.push(context, AppRoute.to(const SettingsScreen())),
                ),
              ],
            ),
          ),

          const SizedBox(height: 25),

          // ── JLPT goal card ────────────────────────────────────────
          if (settings.showTrackerPicker)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: progressAsync.when(
                data: (data) => _JlptGoalCard(
                  goal: settings.jlptGoal,
                  kanjiProgress: settings.jlptGoal > 0
                      ? _jlptCumulative(data.kanjiByLevel, settings.jlptGoal)
                      : null,
                  vocabProgress: settings.jlptGoal > 0
                      ? _jlptCumulative(data.vocabByLevel, settings.jlptGoal)
                      : null,
                  testAsync: jlptTestAsync,
                  colors: colors,
                  onGoalSelected: (level) => settingsNotifier.update(settings.copyWith(jlptGoal: level)),
                ),
                loading: () => _JlptGoalCard(
                  goal: settings.jlptGoal,
                  kanjiProgress: null,
                  vocabProgress: null,
                  testAsync: jlptTestAsync,
                  colors: colors,
                  onGoalSelected: (level) => settingsNotifier.update(settings.copyWith(jlptGoal: level)),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

          SizedBox(height: heroGap),

          // ── Hero session block ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: KDesign.heroRadius,
                  border: Border.all(color: KDesign.line(colors), width: 1.5),
                  boxShadow: KDesign.shadowSm(colors),
                ),
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          "TODAY'S SESSION",
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            letterSpacing: 1.4, color: KDesign.inkSoft(colors),
                          ),
                        ),
                        const SizedBox(height: 11),
                        targetAsync.when(
                          data: (t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic, children: [
                              Text('${t.kanji}', style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800,
                                color: colors.accent, letterSpacing: -0.4, height: 1.05,
                              )),
                              const SizedBox(width: 8),
                              Text('target kanji', style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: KDesign.inkSoft(colors),
                              )),
                            ]),
                            const SizedBox(height: 4),
                            Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic, children: [
                              Text('${t.vocab}', style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w800,
                                color: colors.accent, letterSpacing: -0.4, height: 1.05,
                              )),
                              const SizedBox(width: 8),
                              Text('target vocabulary', style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: KDesign.inkSoft(colors),
                              )),
                            ]),
                            if (t.kana > 0) ...[
                              const SizedBox(height: 4),
                              Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic, children: [
                                Text('${t.kana}', style: TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w800,
                                  color: colors.accent, letterSpacing: -0.4, height: 1.05,
                                )),
                                const SizedBox(width: 8),
                                Text('target kana', style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: KDesign.inkSoft(colors),
                                )),
                              ]),
                            ],
                          ]),
                          loading: () => const SizedBox(height: 70),
                          error: (_, __) => const SizedBox(height: 70),
                        ),
                      ]),
                    ),
                    Column(children: [
                      _GoalRing(done: todayDone, goal: goal, colors: colors),
                      const SizedBox(height: 4),
                      Text(
                        "TODAY'S GOAL",
                        style: TextStyle(
                          fontSize: 9, fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: KDesign.inkSoft(colors),
                        ),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 22),
                  Container(height: 1, color: KDesign.line(colors)),
                  const SizedBox(height: 22),
                  // Test button + graduation nudge hidden in practice learning mode.
                  if (settings.learnedVia != 'practice') ...[
                    gradAsync.when(
                      data: (g) {
                        if (!g.hasKanji && !g.hasVocab && !g.hasKana) return const SizedBox.shrink();
                        final types = [
                          if (g.hasKana) 'kana',
                          if (g.hasKanji) 'kanji',
                          if (g.hasVocab) 'vocabulary',
                        ].join(', ');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            "You've correctly identified some of the $types a lot recently! Want to take a test and graduate them to learned?",
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: KDesign.inkSoft(colors),
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 12),
                    _ShimmerButton(
                      shimmer: gradAsync.maybeWhen(
                        data: (g) => g.hasKanji || g.hasVocab || g.hasKana,
                        orElse: () => false,
                      ),
                      colors: colors,
                      onPressed: () {
                        soundService.playSelectButton();
                        Navigator.push(context, AppRoute.to(const TestHubScreen()))
                            .then((_) {
                          if (mounted) {
                            ref.invalidate(allProgressProvider);
                            ref.invalidate(_targetCountProvider);
                            ref.invalidate(_graduationCandidatesProvider);
                            ref.invalidate(_todayGoalProvider);
                            final goal = ref.read(settingsProvider).jlptGoal;
                            if (goal > 0) ref.invalidate(jlptTestDataProvider(goal));
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 14),
                  ],
                  GestureDetector(
                    onTap: () {
                      soundService.playSelectButton();
                      Navigator.push(context, AppRoute.to(const StudyPickerScreen()))
                          .then((_) {
                        if (mounted) {
                          ref.invalidate(_todayGoalProvider);
                          ref.invalidate(_targetCountProvider);
                        }
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      height: 65,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [colors.accent, deep],
                        ),
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: KDesign.shadowAccent(colors),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                          SizedBox(width: 9),
                          Text(
                            'Start Studying',
                            style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {
                      soundService.playSelectButton();
                      Navigator.push(context, AppRoute.to(const TargetsScreen()))
                          .then((_) {
                        if (mounted) {
                          ref.invalidate(allProgressProvider);
                          ref.invalidate(_targetCountProvider);
                          ref.invalidate(_graduationCandidatesProvider);
                        }
                      });
                    },
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: KDesign.tint(colors),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.adjust_rounded, size: 15, color: colors.accent),
                          const SizedBox(width: 7),
                          Text(
                            'Set Targets',
                            style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700,
                              color: colors.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),

          SizedBox(height: heroGap),
        ]))),
      ]),
    );
  }

}

// ── Small components ──────────────────────────────────────────────────────────

class _TopIconBtn extends StatelessWidget {
  final IconData icon;
  final bool active;
  final ThemeColors colors;
  final VoidCallback onTap;
  const _TopIconBtn({required this.icon, required this.active, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: KDesign.chipRadius,
          border: Border.all(color: KDesign.line(colors)),
          boxShadow: KDesign.shadowSm(colors),
        ),
        child: Icon(icon, size: 20, color: active ? colors.accent : KDesign.inkFaint(colors)),
      ),
    );
  }
}

// ── JLPT goal card ────────────────────────────────────────────────────────────

class _JlptGoalCard extends StatefulWidget {
  final int goal;
  final ({int remaining, int total})? kanjiProgress;
  final ({int remaining, int total})? vocabProgress;
  final AsyncValue<_JlptTestData> testAsync;
  final ThemeColors colors;
  final void Function(int level)? onGoalSelected;

  const _JlptGoalCard({
    required this.goal,
    required this.kanjiProgress,
    required this.vocabProgress,
    required this.testAsync,
    required this.colors,
    this.onGoalSelected,
  });

  @override
  State<_JlptGoalCard> createState() => _JlptGoalCardState();
}

class _JlptGoalCardState extends State<_JlptGoalCard> {
  // 0 = remaining count, 1 = progress bar, 2 = %, 3 = fraction
  int _cycle = 0;

  void _tap() => setState(() => _cycle = (_cycle + 1) % 3);

  void _showGoalPicker(BuildContext context) {
    final colors = widget.colors;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            alignment: Alignment.center,
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: KDesign.line(colors),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Text('Choose JLPT Goal', style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w800, color: KDesign.ink(colors),
          )),
          const SizedBox(height: 6),
          Text('Progress card will track all levels up to and including your goal.',
            style: TextStyle(fontSize: 13, color: KDesign.inkSoft(colors), height: 1.4)),
          const SizedBox(height: 16),
          for (final (level, label, sub) in const [
            (5, 'N5', 'Beginner — 80 kanji, 657 vocab'),
            (4, 'N4', 'Elementary — 246 kanji, 1245 vocab cumulative'),
            (3, 'N3', 'Intermediate — 613 kanji, 2870 vocab cumulative'),
            (2, 'N2', 'Upper-intermediate — 986 kanji, 4459 vocab cumulative'),
            (1, 'N1', 'Advanced — all 2230 kanji, 5379 vocab cumulative'),
          ])
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                widget.onGoalSelected?.call(level);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: widget.goal == level ? KDesign.tint(colors) : colors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.goal == level ? colors.accent : KDesign.line(colors),
                    width: widget.goal == level ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: KDesign.ink(colors),
                    )),
                    Text(sub, style: TextStyle(fontSize: 12, color: KDesign.inkSoft(colors))),
                  ])),
                  if (widget.goal == level)
                    Icon(Icons.check_circle_rounded, size: 20, color: colors.accent),
                ]),
              ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final line = KDesign.line(colors);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: KDesign.heroRadius,
        border: Border.all(color: line),
        boxShadow: KDesign.shadowSm(colors),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          widget.goal == 0 ? 'JLPT GOAL' : 'PROGRESS TO N${widget.goal}',
          style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            letterSpacing: 1.4, color: KDesign.inkSoft(colors),
          ),
        ),
        if (widget.goal == 0) ...[
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showGoalPicker(context),
            child: Row(children: [
              Expanded(
                child: Text(
                  'Set your JLPT goal to track your progress. Tap here to choose.',
                  style: TextStyle(fontSize: 13, color: KDesign.inkSoft(colors), height: 1.4),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 18, color: KDesign.inkFaint(colors)),
            ]),
          ),
        ] else ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _tap,
            behavior: HitTestBehavior.opaque,
            child: Column(children: [
              _GoalStatRow(
                label: 'Kanji',
                data: widget.kanjiProgress,
                cycle: _cycle,
                colors: colors,
              ),
              const SizedBox(height: 8),
              _GoalStatRow(
                label: 'Vocabulary',
                data: widget.vocabProgress,
                cycle: _cycle,
                colors: colors,
              ),
            ]),
          ),
          widget.testAsync.when(
            data: (testData) {
              if (!testData.hasAnyData) {
                return Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(height: 1, color: line),
                    const SizedBox(height: 10),
                    Text(
                      'No N${widget.goal} practice tests yet. Take a JLPT N${widget.goal} test (bottom right tab) to get a benchmark for your level.',
                      style: TextStyle(fontSize: 12, color: KDesign.inkSoft(colors), height: 1.4),
                    ),
                  ]),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(height: 1, color: line),
                  const SizedBox(height: 10),
                  Text(
                    'MOST RECENT PRACTICE TEST',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      letterSpacing: 1.2, color: KDesign.inkSoft(colors),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _TestSectionRow(label: 'Vocabulary', result: testData.vocab, colors: colors),
                  _TestSectionRow(label: 'Grammar', result: testData.grammar, colors: colors),
                  _TestSectionRow(label: 'Reading Comprehension', result: testData.reading, colors: colors),
                  if (testData.lastFullTest != null || testData.combinedBests != null) ...[
                    const SizedBox(height: 8),
                    Container(height: 1, color: line.withValues(alpha: 0.5)),
                    const SizedBox(height: 8),
                  ],
                  if (testData.lastFullTest != null)
                    _TestTotalRow(
                      label: 'Last full test',
                      result: testData.lastFullTest!,
                      colors: colors,
                    ),
                  if (testData.combinedBests != null)
                    _TestTotalRow(
                      label: 'Combined section bests',
                      result: testData.combinedBests!,
                      colors: colors,
                    ),
                ]),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ]),
    );
  }
}

class _GoalStatRow extends StatelessWidget {
  final String label;
  final ({int remaining, int total})? data;
  final int cycle;
  final ThemeColors colors;

  const _GoalStatRow({
    required this.label, required this.data,
    required this.cycle, required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final d = data;
    final learned = d == null ? 0 : d.total - d.remaining;
    final pct = (d == null || d.total == 0) ? 0.0 : learned / d.total;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: KDesign.ink(colors),
          )),
          if (d != null) _cycleLabel(d, learned, pct),
        ],
      ),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: KDesign.pillRadius,
        child: LinearProgressIndicator(
          value: d == null ? null : pct,
          minHeight: 5,
          backgroundColor: KDesign.tint(colors),
          valueColor: AlwaysStoppedAnimation(colors.accent),
        ),
      ),
    ]);
  }

  Widget _cycleLabel(({int remaining, int total}) d, int learned, double pct) {
    switch (cycle) {
      case 0:
        return Text(
          '${d.remaining} remaining',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KDesign.inkSoft(colors)),
        );
      case 1:
        return Text(
          '${(pct * 100).round()}% complete',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.accent),
        );
      case 2:
      default:
        return Text(
          '$learned / ${d.total}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: KDesign.inkSoft(colors)),
        );
    }
  }
}

class _TestSectionRow extends StatelessWidget {
  final String label;
  final _SectionResult? result;
  final ThemeColors colors;
  const _TestSectionRow({required this.label, required this.result, required this.colors});

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: KDesign.ink(colors),
            )),
        ),
        if (r == null)
          Text(
            'no test history',
            style: TextStyle(fontSize: 12, color: KDesign.inkFaint(colors)),
          )
        else ...[
          Text(
            '${r.score} / ${r.total}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.accent),
          ),
          const SizedBox(width: 6),
          Text(
            '(${(r.pct * 100).round()}%)',
            style: TextStyle(fontSize: 11, color: KDesign.inkSoft(colors)),
          ),
        ],
      ]),
    );
  }
}

class _TestTotalRow extends StatelessWidget {
  final String label;
  final _SectionResult result;
  final ThemeColors colors;
  const _TestTotalRow({required this.label, required this.result, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Expanded(
          child: Text(label, style: TextStyle(
            fontSize: 11, color: KDesign.inkSoft(colors), fontWeight: FontWeight.w600,
          )),
        ),
        Text(
          '${result.score}/${result.total}  ',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: KDesign.ink(colors)),
        ),
        Text(
          '${(result.pct * 100).round()}%',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colors.accent),
        ),
      ]),
    );
  }
}

class _GoalRing extends StatelessWidget {
  final int done, goal;
  final ThemeColors colors;
  const _GoalRing({required this.done, required this.goal, required this.colors});

  @override
  Widget build(BuildContext context) {
    const size = 78.0, stroke = 8.0;
    final pct = goal == 0 ? 0.0 : (done / goal).clamp(0.0, 1.0);
    const r = (size - stroke) / 2;
    const circ = 2 * math.pi * r;

    return SizedBox(
      width: size, height: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(
          size: const Size(size, size),
          painter: _RingPainter(pct: pct, stroke: stroke, r: r, circ: circ, colors: colors),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$done', style: TextStyle(
            fontSize: 19, fontWeight: FontWeight.w800, color: colors.accent, height: 1,
          )),
          Text('/ $goal', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: KDesign.inkSoft(colors),
          )),
        ]),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct, stroke, r, circ;
  final ThemeColors colors;
  const _RingPainter({required this.pct, required this.stroke, required this.r, required this.circ, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final trackPaint = Paint()
      ..color = KDesign.soft(colors)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = colors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, trackPaint);
    if (pct > 0) {
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * pct, false, fillPaint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct;
}

// ── Shimmer-capable Test Targets button ───────────────────────────────────────

class _ShimmerButton extends StatefulWidget {
  final bool shimmer;
  final VoidCallback onPressed;
  final ThemeColors colors;
  const _ShimmerButton({required this.shimmer, required this.onPressed, required this.colors});

  @override
  State<_ShimmerButton> createState() => _ShimmerButtonState();
}

class _ShimmerButtonState extends State<_ShimmerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    if (widget.shimmer) _ctrl.repeat();
  }

  @override
  void didUpdateWidget(_ShimmerButton old) {
    super.didUpdateWidget(old);
    if (widget.shimmer && !old.shimmer) {
      _ctrl.repeat();
    } else if (!widget.shimmer && old.shimmer) {
      _ctrl.stop();
      _ctrl.value = 0;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final button = SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: widget.colors.accent,
          side: BorderSide(color: KDesign.line(widget.colors), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: widget.onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.quiz_rounded, size: 18, color: widget.colors.accent),
            const SizedBox(width: 8),
            Text('Test', style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: widget.colors.accent,
            )),
          ],
        ),
      ),
    );

    if (!widget.shimmer) return button;

    return Stack(
      children: [
        button,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                final pos = _ctrl.value;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(pos * 4 - 2.5, -0.5),
                        end: Alignment(pos * 4 - 1.5, 0.5),
                        colors: [
                          widget.colors.accent.withValues(alpha: 0.0),
                          widget.colors.accent.withValues(alpha: 0.18),
                          widget.colors.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
