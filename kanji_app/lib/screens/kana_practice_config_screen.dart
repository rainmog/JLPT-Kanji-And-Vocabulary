import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kana_repository.dart';
import '../services/sound_service.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/k_setup.dart';
import '../widgets/short_session_dialog.dart';
import 'kana_practice_screen.dart';
import 'matching_game_config_screen.dart';
import 'practice_preview_screen.dart';
import 'speed_read_config_screen.dart';

class KanaPracticeConfigScreen extends ConsumerStatefulWidget {
  final String type; // 'hiragana' | 'katakana'
  const KanaPracticeConfigScreen({super.key, required this.type});

  @override
  ConsumerState<KanaPracticeConfigScreen> createState() => _KanaPracticeConfigScreenState();
}

class _KanaPracticeConfigScreenState extends ConsumerState<KanaPracticeConfigScreen> {
  // 'hira' | 'kata' | 'both'
  String _script = 'hira';
  // 'k2r' = Kana→Rōmaji, 'r2k' = Rōmaji→Kana
  String _dir = 'k2r';
  // 'mc' | 'type'
  String _answerMode = 'mc';
  int _count = 20;
  int _targetCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _script = widget.type == 'katakana' ? 'kata' : 'hira';
    _load();
  }

  Future<void> _load() async {
    final targeted = await kanaRepo.getTargeted(type: widget.type);
    if (!mounted) return;
    setState(() { _targetCount = targeted.length; _loading = false; });
  }

  String get _activeType {
    if (_script == 'both') return widget.type;
    return _script == 'kata' ? 'katakana' : 'hiragana';
  }

  KanaQuizType get _quizType {
    if (_dir == 'k2r') {
      return _answerMode == 'mc' ? KanaQuizType.kanaToRomajiMC : KanaQuizType.kanaToRomajiType;
    }
    return KanaQuizType.romajiToKanaMC;
  }

  Future<void> _start() async {
    final type = _activeType;
    final targeted = await kanaRepo.getTargeted(type: type);
    if (!mounted) return;
    if (targeted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No targets selected. Add targets first.')),
      );
      return;
    }

    List<KanaWord> words = [];
    if (_quizType == KanaQuizType.wordToRomajiType) {
      final rows = targeted.map((c) => c.row).toSet().toList();
      words = await kanaRepo.getWordsForTargetedRows(type: type, targetedRows: rows);
      if (!mounted) return;
      if (words.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching words for your targets.')),
        );
        return;
      }
    }

    // Not-enough-targets: the char pool caps the session length.
    if (words.isEmpty && targeted.length < _count) {
      final ok = await confirmShortSession(
        context,
        colors: ref.read(themeColorsProvider),
        available: targeted.length,
        requested: _count,
      );
      if (!ok || !mounted) return;
    }

    final allChars = await kanaRepo.getAll(type: type);
    if (!mounted) return;
    soundService.playSelectButton();
    Navigator.push(context, AppRoute.to(PracticePreviewScreen(
      items: KanaPreviewItems(targeted),
      onBegin: (ctx) {
        Navigator.push(ctx, AppRoute.to(KanaPracticeScreen(
          chars: targeted,
          allChars: allChars,
          words: words,
          quizType: _quizType,
          count: _count,
          testMode: false,
        )));
      },
    )));
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final badge = widget.type == 'hiragana' ? 'あ' : 'ア';

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(children: [
          KSetupHeader(badge: badge, title: 'Practice Kana', colors: colors),

          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_targetCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 4),
                        child: Text(
                          '$_targetCount ${widget.type} characters targeted',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF9A7E86)),
                        ),
                      ),
                    KSetupField(
                      label: 'Script',
                      child: KSeg(
                        options: const [
                          KSegOption(id: 'hira', label: 'Hiragana'),
                          KSegOption(id: 'kata', label: 'Katakana'),
                          KSegOption(id: 'both', label: 'Both'),
                        ],
                        value: _script,
                        onChanged: (v) => setState(() => _script = v),
                        colors: colors,
                      ),
                    ),
                    KSetupField(
                      label: 'Direction',
                      child: KSeg(
                        options: const [
                          KSegOption(id: 'k2r', label: 'Kana → Rōmaji'),
                          KSegOption(id: 'r2k', label: 'Rōmaji → Kana'),
                        ],
                        value: _dir,
                        onChanged: (v) => setState(() => _dir = v),
                        colors: colors,
                      ),
                    ),
                    KSetupField(
                      label: 'Answer mode',
                      child: KSeg(
                        options: const [
                          KSegOption(id: 'mc', label: 'Multiple choice'),
                          KSegOption(id: 'type', label: 'Type the answer'),
                        ],
                        value: _answerMode,
                        onChanged: (v) => setState(() => _answerMode = v),
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
                          sub: 'Pair kana with romaji against the clock',
                          colors: colors,
                          onTap: () => Navigator.push(context, AppRoute.to(
                            MatchingGameConfigScreen(matchContext: MatchContext.kana, kanaType: widget.type),
                          )),
                        ),
                        const SizedBox(height: 9),
                        KGameButton(
                          icon: Icons.bolt_rounded,
                          label: 'Speed reading',
                          sub: 'Read as many as you can in 60 seconds',
                          colors: colors,
                          onTap: () => Navigator.push(context, AppRoute.to(
                            SpeedReadConfigScreen(speedContext: SpeedReadContext.kana, kanaType: widget.type),
                          )),
                        ),
                      ]),
                    ),
                  ]),
                ),
          ),

          KStickyFooter(
            colors: colors,
            child: KStartButton(label: 'Start practice', colors: colors, onTap: _start),
          ),
        ]),
      ),
    );
  }
}
