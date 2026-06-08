import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/preferences_service.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/k_setup.dart';
import 'matching_game_config_screen.dart';
import 'session_screen.dart';
import 'speed_read_config_screen.dart';

class TargetPracticeConfigScreen extends ConsumerStatefulWidget {
  const TargetPracticeConfigScreen({super.key});

  @override
  ConsumerState<TargetPracticeConfigScreen> createState() =>
      _TargetPracticeConfigScreenState();
}

class _TargetPracticeConfigScreenState extends ConsumerState<TargetPracticeConfigScreen> {
  String _mode = 'sentence';
  bool _multipleChoice = true;
  int _count = 20;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await PreferencesService.load();
    if (!mounted) return;
    setState(() {
      _mode = prefs['mode'] == 'wordpractice' ? 'wordpractice' : prefs['mode'];
      _count = prefs['count'];
      _multipleChoice = prefs['multipleChoice'];
    });
  }

  void _startSession() {
    final settings = ref.read(settingsProvider);
    PreferencesService.save(
      mode: _mode,
      levels: {1, 2, 3, 4, 5},
      tags: const {},
      count: _count,
      multipleChoice: _multipleChoice,
    );
    soundService.playSelectButton();
    Navigator.push(context, AppRoute.to(SessionScreen(
      mode: _mode,
      jlptLevels: const [1, 2, 3, 4, 5],
      tags: const [],
      questionCount: _count,
      minDifficulty: settings.difficultyMin,
      maxDifficulty: settings.difficultyMax,
      multipleChoice: _multipleChoice,
      targetOnly: true,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(children: [
          KSetupHeader(badge: '字', title: 'Practice Kanji', colors: colors),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                KSetupField(
                  label: 'Practice mode',
                  child: KChoiceList(
                    options: const [
                      KChoiceItem(id: 'sentence', label: 'Sentences', sub: 'See it used in context', icon: Icons.menu_book_rounded),
                      KChoiceItem(id: 'word', label: 'Compounds', sub: 'Words built from this kanji', icon: Icons.auto_awesome_rounded),
                      KChoiceItem(id: 'wordpractice', label: 'On / Kun & meaning', sub: 'Readings and definitions', icon: Icons.school_rounded),
                    ],
                    value: _mode,
                    onChanged: (v) => setState(() { _mode = v; if (v == 'wordpractice') _multipleChoice = true; }),
                    colors: colors,
                  ),
                ),
                if (_mode != 'wordpractice')
                  KSetupField(
                    label: 'Answer mode',
                    child: KSeg(
                      options: const [
                        KSegOption(id: 'mc', label: 'Multiple choice'),
                        KSegOption(id: 'type', label: 'Type the answer'),
                      ],
                      value: _multipleChoice ? 'mc' : 'type',
                      onChanged: (v) => setState(() => _multipleChoice = v == 'mc'),
                      colors: colors,
                    ),
                  ),
                KSetupField(
                  label: 'Questions',
                  child: KCountChips(
                    options: const [10, 20, 30, 40],
                    value: _count,
                    onChanged: (v) => setState(() => _count = v),
                    colors: colors,
                  ),
                ),
                KSetupField(
                  label: 'Or try a game mode',
                  child: Column(children: [
                    KGameButton(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Matching game',
                      sub: 'Pair kanji with meanings against the clock',
                      colors: colors,
                      onTap: () => Navigator.push(context, AppRoute.to(
                        const MatchingGameConfigScreen(matchContext: MatchContext.kanji),
                      )),
                    ),
                    const SizedBox(height: 9),
                    KGameButton(
                      icon: Icons.bolt_rounded,
                      label: 'Speed reading',
                      sub: 'Read as many as you can in 60 seconds',
                      colors: colors,
                      onTap: () => Navigator.push(context, AppRoute.to(
                        const SpeedReadConfigScreen(speedContext: SpeedReadContext.kanji),
                      )),
                    ),
                  ]),
                ),
              ]),
            ),
          ),

          KStickyFooter(
            colors: colors,
            child: KStartButton(label: 'Start practice', colors: colors, onTap: _startSession),
          ),
        ]),
      ),
    );
  }
}
