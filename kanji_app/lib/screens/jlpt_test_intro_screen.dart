import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../theme/app_theme_backgrounds.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/k_setup.dart';
import '../widgets/sakura_overlay.dart';
import '../widgets/falling_blocks_overlay.dart';
import '../widgets/snow_overlay.dart';
import '../widgets/space_age_overlay.dart';
import 'jlpt_test_session_screen.dart';
import 'test_history_screen.dart';

// ── New combined screen (level + section picker) ──────────────────────────────

class JlptTestScreen extends ConsumerStatefulWidget {
  const JlptTestScreen({super.key});

  @override
  ConsumerState<JlptTestScreen> createState() => _JlptTestScreenState();
}

class _JlptTestScreenState extends ConsumerState<JlptTestScreen> {
  int _level = 5;
  String? _section; // null = all sections
  Map<String, dynamic>? _savedProgress;
  bool _checked = false;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _checkSaved();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkSaved() async {
    setState(() { _checked = false; _savedProgress = null; });
    final saved = await loadJlptProgress(_level, section: _section);
    if (mounted) setState(() { _savedProgress = saved; _checked = true; });
  }

  void _setLevel(int level) {
    setState(() => _level = level);
    _checkSaved();
  }

  void _setSection(String? section) {
    setState(() => _section = section);
    _checkSaved();
  }

  void _startFresh() => Navigator.push(
    context,
    AppRoute.to(JlptTestSessionScreen(level: _level, section: _section)),
  );

  void _resume() {
    final saved = _savedProgress!;
    final index = saved['index'] as int;
    final rawAnswers = saved['answers'] as Map<String, dynamic>;
    final answers = rawAnswers.map((k, v) => MapEntry(int.parse(k), v as int));
    final vocabIds = (saved['vocabIds'] as List?)?.cast<int>();
    final grammarIds = (saved['grammarIds'] as List?)?.cast<int>();
    final readingIds = (saved['readingIds'] as List?)?.cast<int>();
    Navigator.push(context, AppRoute.to(JlptTestSessionScreen(
      level: _level,
      section: _section,
      resumeIndex: index,
      resumeAnswers: answers,
      resumeVocabIds: vocabIds,
      resumeGrammarIds: grammarIds,
      resumeReadingIds: readingIds,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final appTheme = ref.watch(themeNotifier);
    final hasAnimatedBg = const {AppTheme.galaxy, AppTheme.loveLetter, AppTheme.lily, AppTheme.totoro, AppTheme.midnightCity}.contains(appTheme);
    final hasSaved = _checked && _savedProgress != null;
    final resumeIndex = hasSaved ? (_savedProgress!['index'] as int) + 1 : 0;

    return Scaffold(
      backgroundColor: hasAnimatedBg ? Colors.transparent : colors.bg,
      body: Stack(children: [const Positioned.fill(child: HomeBgLayer()), const Positioned.fill(child: SakuraPetalsOverlay()), const Positioned.fill(child: SpaceAgeStarsOverlay()), const Positioned.fill(child: SnowOverlay()), const Positioned.fill(child: FallingBlocksOverlay()), SafeArea(
        child: PageView(
          controller: _pageController,
          onPageChanged: (_) {},
          children: [
            // ── Page 0: JLPT Practice picker ──────────────────────────────
            Column(children: [
              KSetupHeader(badge: '試', title: 'JLPT Practice', colors: colors),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                    // Swipe hint
                    Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.history_rounded, size: 14, color: KDesign.inkFaint(colors)),
                        const SizedBox(width: 6),
                        Text('Swipe left for test history',
                          style: TextStyle(fontSize: 12, color: KDesign.inkFaint(colors))),
                      ]),
                    ),
                    const SizedBox(height: 16),

                    KSetupField(
                      label: 'Level',
                      child: Row(
                        children: [5, 4, 3, 2, 1].map((n) {
                          final on = _level == n;
                          final last = n == 1;
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(right: last ? 0 : 9),
                              child: GestureDetector(
                                onTap: () => _setLevel(n),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: on ? colors.accent : colors.surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: on ? colors.accent : KDesign.line(colors)),
                                    boxShadow: on ? KDesign.shadowAccent(colors) : KDesign.shadowSm(colors),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text('N$n', style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800,
                                    color: on ? Colors.white : KDesign.inkSoft(colors),
                                  )),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    KSetupField(
                      label: 'Section',
                      child: KSeg(
                        options: const [
                          KSegOption(id: 'all', label: 'All'),
                          KSegOption(id: 'vocabulary', label: 'Vocab'),
                          KSegOption(id: 'grammar', label: 'Grammar'),
                          KSegOption(id: 'reading', label: 'Reading'),
                        ],
                        value: _section ?? 'all',
                        onChanged: (v) => _setSection(v == 'all' ? null : v),
                        colors: colors,
                      ),
                    ),

                    KSetupField(
                      label: 'What to expect',
                      child: KPanel(
                        colors: colors,
                        children: [
                          if (_section == null || _section == 'vocabulary')
                            KSettingRow(
                              icon: Icons.text_fields_rounded,
                              label: 'Vocabulary',
                              sub: 'Fill in the blank · kanji reading · kanji writing (~25 questions)',
                              colors: colors,
                              separator: false,
                            ),
                          if (_section == null || _section == 'grammar')
                            KSettingRow(
                              icon: Icons.account_tree_rounded,
                              label: 'Grammar',
                              sub: 'Particles, verb forms, and sentence ordering (~15 questions)',
                              colors: colors,
                              separator: _section == null,
                            ),
                          if (_section == null || _section == 'reading')
                            KSettingRow(
                              icon: Icons.menu_book_rounded,
                              label: 'Reading',
                              sub: 'Short passages with comprehension questions (~8 questions)',
                              colors: colors,
                              separator: _section == null || _section == 'reading',
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                    KPanel(
                      colors: colors,
                      children: [
                        KSettingRow(icon: Icons.shuffle_rounded, label: 'Questions are randomly selected each run', colors: colors),
                        KSettingRow(icon: Icons.hourglass_disabled_rounded, label: 'No time limit — this is practice', colors: colors, separator: true),
                        KSettingRow(icon: Icons.rate_review_rounded, label: 'Review missed questions at the end', colors: colors, separator: true),
                      ],
                    ),

                  ]),
                ),
              ),

              KStickyFooter(
                colors: colors,
                child: Column(children: [
                  if (hasSaved) ...[
                    KStartButton(
                      label: 'Resume (Q$resumeIndex)',
                      colors: colors,
                      onTap: _resume,
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _startFresh,
                      child: Container(
                        width: double.infinity, height: 50,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(color: KDesign.line(colors)),
                          boxShadow: KDesign.shadowSm(colors),
                        ),
                        child: Center(
                          child: Text('Start Fresh', style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: KDesign.inkSoft(colors),
                          )),
                        ),
                      ),
                    ),
                  ] else
                    KStartButton(
                      label: _section == null
                        ? 'Start N$_level Test'
                        : 'Start ${_sectionLabel(_section!)} Test',
                      colors: colors,
                      onTap: _startFresh,
                    ),
                ]),
              ),
            ]),

            // ── Page 1: Test history ───────────────────────────────────────
            TestHistoryScreen(embedded: true, initialFilter: 'jlpt'),
          ],
        ),
      ),
      ]),
    );
  }

  String _sectionLabel(String s) => switch (s) {
    'vocabulary' => 'Vocabulary',
    'grammar' => 'Grammar',
    'reading' => 'Reading',
    _ => 'N$_level',
  };
}
