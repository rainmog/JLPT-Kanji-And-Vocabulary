import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kana_repository.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/vocab_repository.dart';
import '../services/auto_progression_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../theme/app_theme_backgrounds.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/sakura_overlay.dart';
import 'credits_screen.dart';
import 'jlpt_test_intro_screen.dart';
import 'settings_screen.dart';
import 'study_picker_screen.dart';
import 'target_practice_config_screen.dart';
import 'targets_screen.dart';
import 'vocabulary_dictionary_screen.dart';

// All progress data needed for home trackers, fetched in one go
final _allProgressProvider = FutureProvider.autoDispose<_ProgressData>((ref) async {
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

final _kanjiTagsProvider = FutureProvider.autoDispose<List<String>>(
  (_) => kanjiRepo.getAllTags(),
);
final _vocabTagsProvider = FutureProvider.autoDispose<List<String>>(
  (_) => vocabRepo.getAllTags(),
);

final _targetCountProvider = FutureProvider.autoDispose<({int kanji, int vocab, int kana})>((ref) async {
  final kanjiCount = await kanjiRepo.getTargetKanjiList().then((l) => l.length);
  final vocabCount = await vocabRepo.getTargetCount();
  final kanaProgress = await kanaRepo.getProgress();
  final kanaTargeted = kanaProgress.targeted;
  return (kanji: kanjiCount, vocab: vocabCount, kana: kanaTargeted);
});

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
        final p = kanjiByLevel[6 - lvl]; // jlpt_level: 5=N5..1=N1
        if (p != null) return (label: 'Kanji N${lvl}', learned: p.learned, total: p.total);
      }
    }
    if (id.startsWith('vocab:N')) {
      final lvl = int.tryParse(id.substring(7));
      if (lvl != null) {
        final p = vocabByLevel[6 - lvl];
        if (p != null) return (label: 'Vocab N${lvl}', learned: p.learned, total: p.total);
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
    if (result.addedKanji > 0 || result.addedVocab > 0 || result.addedKana > 0) {
      ref.invalidate(_targetCountProvider);
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
    final progressAsync = ref.watch(_allProgressProvider);
    final targetAsync = ref.watch(_targetCountProvider);
    final goal = settings.dailyGoal;

    final line = KDesign.line(colors);
    final deep = KDesign.deep(colors);

    final appTheme = ref.watch(themeNotifier);
    final hasAnimatedBg = const {
      AppTheme.galaxy, AppTheme.tetris, AppTheme.loveLetter,
      AppTheme.lily, AppTheme.totoro, AppTheme.midnightCity,
    }.contains(appTheme);

    final bumper = MediaQuery.of(context).size.height * 0.05;

    return Scaffold(
      backgroundColor: hasAnimatedBg ? Colors.transparent : colors.bg,
      body: Stack(children: [
        const Positioned.fill(child: HomeBgLayer()),
        const Positioned.fill(child: SakuraPetalsOverlay()),
        SafeArea(child: Column(children: [
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

          const SizedBox(height: 14),

          // ── Configurable progress card ────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Stack(clipBehavior: Clip.none, children: [
              Container(
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: KDesign.heroRadius,
                  border: Border.all(color: line),
                  boxShadow: KDesign.shadowSm(colors),
                ),
                padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
                child: progressAsync.when(
                  data: (data) {
                    final trackers = settings.homeTrackers;
                    if (trackers.isEmpty) {
                      return Text('No trackers — tap + to add',
                        style: TextStyle(fontSize: 13, color: KDesign.inkSoft(colors)));
                    }
                    final resolved = trackers
                        .map((id) => data.resolve(id))
                        .whereType<({String label, int learned, int total})>()
                        .toList();
                    return Column(children: [
                      for (int i = 0; i < resolved.length; i++) ...[
                        if (i > 0) const SizedBox(height: 15),
                        _ProgressBar(
                          label: resolved[i].label,
                          learned: resolved[i].learned,
                          total: resolved[i].total,
                          colors: colors,
                        ),
                      ],
                    ]);
                  },
                  loading: () => const _ProgressBarSkeleton(label: 'Loading…'),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              if (settings.showTrackerPicker)
                Positioned(
                  bottom: -7, right: 8,
                  child: GestureDetector(
                    onTap: () => _showTrackerPicker(context, ref, settings, settingsNotifier, colors),
                    child: Container(
                      width: 14, height: 14,
                      decoration: BoxDecoration(
                        color: colors.accent,
                        shape: BoxShape.circle,
                        boxShadow: KDesign.shadowSm(colors),
                      ),
                      child: const Icon(Icons.add_rounded, size: 10, color: Colors.white),
                    ),
                  ),
                ),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Hero session block — expands to fill remaining space ───
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.accent, deep],
                  ),
                  borderRadius: KDesign.heroRadius,
                  boxShadow: KDesign.shadowAccent(colors),
                ),
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Stack(children: [
                  // Decorative circles
                  Positioned(
                    right: -34, top: -36,
                    child: Container(
                      width: 150, height: 150,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 38, bottom: -52,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            "CURRENT TARGETS",
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              letterSpacing: 1.4, color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                          const SizedBox(height: 11),
                          targetAsync.when(
                            data: (t) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Text('${t.kanji}', style: const TextStyle(
                                  fontSize: 27, fontWeight: FontWeight.w800,
                                  color: Colors.white, letterSpacing: -0.4, height: 1.05,
                                )),
                                const SizedBox(width: 8),
                                Text('target kanji', style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.85),
                                )),
                              ]),
                              const SizedBox(height: 4),
                              Row(children: [
                                Text('${t.vocab}', style: const TextStyle(
                                  fontSize: 27, fontWeight: FontWeight.w800,
                                  color: Colors.white, letterSpacing: -0.4, height: 1.05,
                                )),
                                const SizedBox(width: 8),
                                Text('target vocab', style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.85),
                                )),
                              ]),
                              if (t.kana > 0) ...[
                                const SizedBox(height: 4),
                                Row(children: [
                                  Text('${t.kana}', style: const TextStyle(
                                    fontSize: 27, fontWeight: FontWeight.w800,
                                    color: Colors.white, letterSpacing: -0.4, height: 1.05,
                                  )),
                                  const SizedBox(width: 8),
                                  Text('target kana', style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.85),
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
                        _GoalRing(done: 0, goal: goal),
                        const SizedBox(height: 4),
                        Text(
                          "TODAY'S GOAL",
                          style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ]),
                    ]),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          soundService.playSelectButton();
                          Navigator.push(context, AppRoute.to(const TargetPracticeConfigScreen()))
                              .then((_) => ref.invalidate(_targetCountProvider));
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.quiz_rounded, size: 18, color: Colors.white.withValues(alpha: 0.9)),
                            const SizedBox(width: 8),
                            const Text('Test Targets', style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white,
                            )),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: deep,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                          shadowColor: Colors.black26,
                        ),
                        onPressed: () {
                          soundService.playSelectButton();
                          Navigator.push(context, AppRoute.to(const StudyPickerScreen()));
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow_rounded, size: 20, color: deep),
                            const SizedBox(width: 8),
                            Text(
                              'Start studying',
                              style: TextStyle(
                                fontSize: 16.5, fontWeight: FontWeight.w800, color: deep,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Quick tiles ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _QuickTile(
                icon: Icons.adjust_rounded,
                label: 'Set targets',
                accent: true,
                colors: colors,
                onTap: () => Navigator.push(context, AppRoute.to(const TargetsScreen()))
                    .then((_) => ref.invalidate(_targetCountProvider)),
              ),
              const SizedBox(width: 12),
              _QuickTile(
                icon: Icons.menu_book_rounded,
                label: 'Dictionary',
                accent: false,
                colors: colors,
                onTap: () => Navigator.push(context, AppRoute.to(const VocabularyDictionaryScreen())),
              ),
              const SizedBox(width: 12),
              _QuickTile(
                icon: Icons.school_rounded,
                label: 'JLPT',
                accent: false,
                colors: colors,
                onTap: () => Navigator.push(context, AppRoute.to(const JlptTestScreen())),
              ),
            ]),
          ),

          SizedBox(height: bumper),
        ])),
      ]),
    );
  }

  void _showTrackerPicker(
    BuildContext context, WidgetRef ref,
    AppSettings settings, SettingsNotifier notifier,
    ThemeColors colors,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TrackerPickerSheet(
        colors: colors,
        selected: List<String>.from(settings.homeTrackers),
        onChanged: (updated) => notifier.update(settings.copyWith(homeTrackers: updated)),
      ),
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

class _ProgressBar extends StatelessWidget {
  final String label;
  final int learned, total;
  final ThemeColors colors;
  const _ProgressBar({required this.label, required this.learned, required this.total, required this.colors});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : learned / total;
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: KDesign.ink(colors))),
          RichText(text: TextSpan(children: [
            TextSpan(
              text: '$learned',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: colors.accent),
            ),
            TextSpan(
              text: ' / $total',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: KDesign.inkFaint(colors)),
            ),
          ])),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: KDesign.pillRadius,
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 8,
          backgroundColor: KDesign.tint(colors),
          valueColor: AlwaysStoppedAnimation(colors.accent),
        ),
      ),
    ]);
  }
}

class _ProgressBarSkeleton extends StatelessWidget {
  final String label;
  const _ProgressBarSkeleton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(width: 48, height: 14),
        ],
      ),
      const SizedBox(height: 8),
      const SizedBox(height: 8),
    ]);
  }
}

class _GoalRing extends StatelessWidget {
  final int done, goal;
  const _GoalRing({required this.done, required this.goal});

  @override
  Widget build(BuildContext context) {
    const size = 78.0, stroke = 8.0;
    final pct = goal == 0 ? 0.0 : (done / goal).clamp(0.0, 1.0);
    final r = (size - stroke) / 2;
    final circ = 2 * math.pi * r;

    return SizedBox(
      width: size, height: size,
      child: Stack(alignment: Alignment.center, children: [
        CustomPaint(
          size: const Size(size, size),
          painter: _RingPainter(pct: pct, stroke: stroke, r: r, circ: circ),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$done', style: const TextStyle(
            fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white, height: 1,
          )),
          Text('/ $goal', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.8),
          )),
        ]),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pct, stroke, r, circ;
  const _RingPainter({required this.pct, required this.stroke, required this.r, required this.circ});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fillPaint = Paint()
      ..color = Colors.white
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

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool accent;
  final ThemeColors colors;
  final VoidCallback onTap;
  const _QuickTile({required this.icon, required this.label, required this.accent, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () { soundService.playSelectButton(); onTap(); },
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent ? colors.accent : KDesign.line(colors)),
            boxShadow: KDesign.shadowSm(colors),
          ),
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
          child: Column(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: accent ? colors.accent : KDesign.tint(colors),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: accent ? Colors.white : colors.accent),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: KDesign.ink(colors), height: 1.25,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Tracker picker sheet ──────────────────────────────────────────────────────

class _TrackerPickerSheet extends ConsumerStatefulWidget {
  final ThemeColors colors;
  final List<String> selected;
  final void Function(List<String>) onChanged;
  const _TrackerPickerSheet({required this.colors, required this.selected, required this.onChanged});

  @override
  ConsumerState<_TrackerPickerSheet> createState() => _TrackerPickerSheetState();
}

class _TrackerPickerSheetState extends ConsumerState<_TrackerPickerSheet> {
  late List<String> _selected;
  late final PageController _pageController;

  static const _kanjiFixed = [
    ('kanji:all',    'All Kanji'),
    ('hiragana:all', 'All Hiragana'),
    ('katakana:all', 'All Katakana'),
    ('kanji:N5',     'Kanji N5'),
    ('kanji:N4',     'Kanji N4'),
    ('kanji:N3',     'Kanji N3'),
    ('kanji:N2',     'Kanji N2'),
    ('kanji:N1',     'Kanji N1'),
  ];

  static const _vocabFixed = [
    ('vocab:all', 'All Vocab'),
    ('vocab:N5',  'Vocab N5'),
    ('vocab:N4',  'Vocab N4'),
    ('vocab:N3',  'Vocab N3'),
    ('vocab:N2',  'Vocab N2'),
    ('vocab:N1',  'Vocab N1'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = List<String>.from(widget.selected);
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
    widget.onChanged(List<String>.from(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final tagsAsync = ref.watch(_kanjiTagsProvider);
    final vocabTagsAsync = ref.watch(_vocabTagsProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.62,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: KDesign.line(colors),
            borderRadius: BorderRadius.circular(99),
          ),
        ),

        // Tab row
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(children: [
            Expanded(
              child: Text('Track progress', style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800,
                color: KDesign.ink(colors),
              )),
            ),
            _PageTab(label: 'Kanji', page: 0, controller: _pageController, colors: colors),
            const SizedBox(width: 8),
            _PageTab(label: 'Vocab', page: 1, controller: _pageController, colors: colors),
          ]),
        ),

        Expanded(
          child: PageView(
            controller: _pageController,
            children: [
              // ── Kanji page ──
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  for (final (id, label) in _kanjiFixed)
                    _TrackerRow(
                      id: id, label: label,
                      checked: _selected.contains(id),
                      colors: colors,
                      onTap: () => _toggle(id),
                    ),
                  tagsAsync.when(
                    data: (tags) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: tags.map((tag) {
                        final id = 'kanji:tag:$tag';
                        final label = tag[0].toUpperCase() + tag.substring(1);
                        return _TrackerRow(
                          id: id, label: label,
                          checked: _selected.contains(id),
                          colors: colors,
                          onTap: () => _toggle(id),
                        );
                      }).toList(),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),

              // ── Vocab page ──
              ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  for (final (id, label) in _vocabFixed)
                    _TrackerRow(
                      id: id, label: label,
                      checked: _selected.contains(id),
                      colors: colors,
                      onTap: () => _toggle(id),
                    ),
                  vocabTagsAsync.when(
                    data: (tags) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: tags.map((tag) {
                        final id = 'vocab:tag:$tag';
                        final label = tag[0].toUpperCase() + tag.substring(1);
                        return _TrackerRow(
                          id: id, label: label,
                          checked: _selected.contains(id),
                          colors: colors,
                          onTap: () => _toggle(id),
                        );
                      }).toList(),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _PageTab extends StatefulWidget {
  final String label;
  final int page;
  final PageController controller;
  final ThemeColors colors;
  const _PageTab({required this.label, required this.page, required this.controller, required this.colors});

  @override
  State<_PageTab> createState() => _PageTabState();
}

class _PageTabState extends State<_PageTab> {
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  void _onScroll() {
    final p = widget.controller.page?.round() ?? 0;
    if (p != _currentPage) setState(() => _currentPage = p);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final on = _currentPage == widget.page;
    return GestureDetector(
      onTap: () => widget.controller.animateToPage(
        widget.page, duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: on ? widget.colors.accent : KDesign.tint(widget.colors),
          borderRadius: KDesign.chipRadius,
        ),
        child: Text(widget.label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: on ? Colors.white : widget.colors.accent,
        )),
      ),
    );
  }
}

class _TrackerRow extends StatelessWidget {
  final String id, label;
  final bool checked;
  final ThemeColors colors;
  final VoidCallback onTap;
  const _TrackerRow({required this.id, required this.label, required this.checked, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: KDesign.line(colors).withValues(alpha: 0.5))),
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: checked ? colors.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: checked ? colors.accent : KDesign.line(colors),
                width: 2,
              ),
            ),
            child: checked ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
          ),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: KDesign.ink(colors),
          )),
        ]),
      ),
    );
  }
}
