import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kana_repository.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/vocab_repository.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/k_setup.dart';
import 'kana_practice_screen.dart';
import 'test_session_screen.dart';
import 'vocab_test_session_screen.dart';

class TestHubScreen extends ConsumerStatefulWidget {
  const TestHubScreen({super.key});

  @override
  ConsumerState<TestHubScreen> createState() => _TestHubScreenState();
}

class _TestHubScreenState extends ConsumerState<TestHubScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          children: [
            _KanjiTestPage(colors: colors),
            _VocabTestPage(colors: colors),
            _KanaTestPage(colors: colors),
          ],
        ),
      ),
    );
  }
}

// ── Kanji test page ───────────────────────────────────────────────────────────

class _KanjiTestPage extends StatefulWidget {
  final ThemeColors colors;
  const _KanjiTestPage({required this.colors});

  @override
  State<_KanjiTestPage> createState() => _KanjiTestPageState();
}

class _KanjiTestPageState extends State<_KanjiTestPage> {
  int _kanjiCount = 10;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Column(children: [
      KSetupHeader(badge: '字', title: 'Kanji Test', colors: colors),
      // Nav indicator — right-anchored
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Row(children: [
          const Spacer(),
          Text('Vocabulary', style: TextStyle(fontSize: 13, color: KDesign.inkFaint(colors))),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: KDesign.inkFaint(colors)),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KSetupField(
              label: 'How it works',
              child: KPanel(
                colors: colors,
                children: [
                  KSettingRow(icon: Icons.quiz_rounded, label: '3 questions per kanji', sub: 'All 3 must be correct to mark it as learned', colors: colors),
                  KSettingRow(icon: Icons.refresh_rounded, label: 'Fails stay as targets', sub: 'Keep practising and try again', colors: colors, separator: true),
                  KSettingRow(icon: Icons.text_snippet_rounded, label: 'Sentence-based questions', sub: 'Matched to each kanji\'s JLPT level', colors: colors, separator: true),
                ],
              ),
            ),

            KSetupField(
              label: 'Test size',
              child: KSeg(
                options: const [
                  KSegOption(id: '5', label: '5 kanji  ·  15 questions'),
                  KSegOption(id: '10', label: '10 kanji  ·  30 questions'),
                ],
                value: _kanjiCount == 5 ? '5' : '10',
                onChanged: (v) => setState(() => _kanjiCount = int.parse(v)),
                colors: colors,
              ),
            ),
          ]),
        ),
      ),
      KStickyFooter(
        colors: colors,
        child: KStartButton(label: 'Start Kanji Test', colors: colors, onTap: () => _start(context)),
      ),
    ]);
  }

  Future<void> _start(BuildContext context) async {
    final targets = await kanjiRepo.getTargetKanjiList();
    if (!context.mounted) return;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No target kanji. Add some via Set Targets first.'),
      ));
      return;
    }
    final allN5 = targets.every((k) => k.jlptLevel == 5);
    Navigator.push(context, AppRoute.to(TestSessionScreen(
      allTargets: targets,
      forceFurigana: allN5,
      kanjiCount: _kanjiCount,
    )));
  }
}

// ── Vocab test page ───────────────────────────────────────────────────────────

class _VocabTestPage extends StatelessWidget {
  final ThemeColors colors;
  const _VocabTestPage({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      KSetupHeader(badge: '語', title: 'Vocabulary Test', colors: colors),
      // Nav indicators — left and right
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Row(children: [
          Icon(Icons.arrow_back_ios_rounded, size: 12, color: KDesign.inkFaint(colors)),
          const SizedBox(width: 4),
          Text('Kanji', style: TextStyle(fontSize: 13, color: KDesign.inkFaint(colors))),
          const Spacer(),
          Text('Kana', style: TextStyle(fontSize: 13, color: KDesign.inkFaint(colors))),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: KDesign.inkFaint(colors)),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KSetupField(
              label: 'How it works',
              child: KPanel(
                colors: colors,
                children: [
                  KSettingRow(icon: Icons.quiz_rounded, label: '2 questions per word', sub: 'Both must be correct in the same test to mark it learned', colors: colors),
                  KSettingRow(icon: Icons.shuffle_rounded, label: 'Up to 25 words per test', sub: 'Drawn randomly from your target vocabulary', colors: colors, separator: true),
                  KSettingRow(icon: Icons.translate_rounded, label: 'Both directions', sub: 'Japanese → English and English → Japanese', colors: colors, separator: true),
                  KSettingRow(icon: Icons.percent_rounded, label: '70% pass threshold', sub: 'Failed words stay as targets', colors: colors, separator: true),
                ],
              ),
            ),
          ]),
        ),
      ),
      KStickyFooter(
        colors: colors,
        child: KStartButton(label: 'Start Vocabulary Test', colors: colors, onTap: () => _start(context)),
      ),
    ]);
  }

  Future<void> _start(BuildContext context) async {
    final targets = await vocabRepo.getTargetVocab();
    if (!context.mounted) return;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No target vocabulary. Add some via Set Targets first.'),
      ));
      return;
    }
    Navigator.push(context, AppRoute.to(VocabTestSessionScreen(allTargets: targets)));
  }
}

// ── Kana test page ────────────────────────────────────────────────────────────

class _KanaTestPage extends StatelessWidget {
  final ThemeColors colors;
  const _KanaTestPage({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      KSetupHeader(badge: 'か', title: 'Kana Test', colors: colors),
      // Nav indicator — left-anchored
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Row(children: [
          Icon(Icons.arrow_back_ios_rounded, size: 12, color: KDesign.inkFaint(colors)),
          const SizedBox(width: 4),
          Text('Vocabulary', style: TextStyle(fontSize: 13, color: KDesign.inkFaint(colors))),
        ]),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KSetupField(
              label: 'How it works',
              child: KPanel(
                colors: colors,
                children: [
                  KSettingRow(icon: Icons.quiz_rounded, label: '2 questions per character', sub: 'Kana → rōmaji and rōmaji → kana', colors: colors),
                  KSettingRow(icon: Icons.shuffle_rounded, label: 'All targeted kana', sub: 'Covers both hiragana and katakana targets', colors: colors, separator: true),
                  KSettingRow(icon: Icons.refresh_rounded, label: '3 correct in a row = learned', sub: 'Progress saved across sessions', colors: colors, separator: true),
                ],
              ),
            ),
          ]),
        ),
      ),
      KStickyFooter(
        colors: colors,
        child: KStartButton(label: 'Start Kana Test', colors: colors, onTap: () => _start(context)),
      ),
    ]);
  }

  Future<void> _start(BuildContext context) async {
    final targeted = await kanaRepo.getTargeted();
    if (!context.mounted) return;
    if (targeted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No target kana. Add some via Set Targets first.'),
      ));
      return;
    }
    final allChars = await kanaRepo.getAll();
    if (!context.mounted) return;
    Navigator.push(context, AppRoute.to(KanaPracticeScreen(
      chars: targeted,
      allChars: allChars,
      words: const [],
      quizType: KanaQuizType.kanaToRomajiMC,
      count: targeted.length * 2,
      testMode: true,
    )));
  }
}
