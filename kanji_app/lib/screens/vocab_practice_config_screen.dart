import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/vocab_repository.dart';
import '../services/sound_service.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/k_setup.dart';
import 'matching_game_config_screen.dart';
import 'practice_preview_screen.dart';
import 'vocab_practice_screen.dart';

class VocabPracticeConfigScreen extends ConsumerStatefulWidget {
  const VocabPracticeConfigScreen({super.key});

  @override
  ConsumerState<VocabPracticeConfigScreen> createState() => _VocabPracticeConfigScreenState();
}

class _VocabPracticeConfigScreenState extends ConsumerState<VocabPracticeConfigScreen> {
  // 'jp2en' | 'en2jp'
  String _dir = 'jp2en';
  // 'mc' | 'type'
  String _answerMode = 'mc';
  bool _suppressFurigana = false;
  int _targetCount = 0;
  bool _loading = true;
  int _count = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final count = await vocabRepo.getTargetCount();
    if (!mounted) return;
    setState(() { _targetCount = count; _loading = false; });
  }

  Future<void> _start() async {
    final allWords = await vocabRepo.getTargetVocab();
    if (!mounted) return;
    if (allWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No target vocabulary. Add targets first.')),
      );
      return;
    }
    final words = allWords.length > _count
        ? (List<VocabWord>.from(allWords)..shuffle()).sublist(0, _count)
        : allWords;
    soundService.playSelectButton();
    Navigator.push(context, AppRoute.to(PracticePreviewScreen(
      items: VocabPreviewItems(words),
      onBegin: (ctx) {
        Navigator.push(ctx, AppRoute.to(VocabPracticeScreen(
          words: words,
          multipleChoice: _answerMode == 'mc',
          suppressFurigana: _suppressFurigana,
          reverseMode: _dir == 'en2jp',
        )));
      },
    )));
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(children: [
          KSetupHeader(badge: '語', title: 'Practice Vocabulary', colors: colors),

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
                          '$_targetCount words targeted',
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF9A7E86)),
                        ),
                      ),

                    KSetupField(
                      label: 'Direction',
                      child: KChoiceList(
                        options: const [
                          KChoiceItem(id: 'jp2en', label: 'Japanese → English', sub: 'See the word, recall the meaning', icon: Icons.translate_rounded),
                          KChoiceItem(id: 'en2jp', label: 'English → Japanese', sub: 'See the meaning, recall the word', icon: Icons.swap_horiz_rounded),
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
                      label: 'Display',
                      child: KPanel(
                        colors: colors,
                        children: [
                          KSettingRow(
                            icon: Icons.auto_stories_rounded,
                            label: 'Hide furigana',
                            sub: 'Show kanji without reading hints for learned characters',
                            colors: colors,
                            trailing: KToggle(
                              value: _suppressFurigana,
                              colors: colors,
                              onChanged: (v) => setState(() => _suppressFurigana = v),
                            ),
                          ),
                        ],
                      ),
                    ),

                    KSetupField(
                      label: 'Or try a game mode',
                      child: KGameButton(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Matching game',
                        sub: 'Pair vocab with meanings against the clock',
                        colors: colors,
                        onTap: () => Navigator.push(context, AppRoute.to(
                          const MatchingGameConfigScreen(matchContext: MatchContext.vocab),
                        )),
                      ),
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
