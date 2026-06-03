import 'package:flutter/material.dart';
import '../repositories/kana_repository.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import '../widgets/scale_on_press.dart';
import 'kana_practice_screen.dart';
import 'matching_game_config_screen.dart';
import 'speed_read_config_screen.dart';

class KanaPracticeConfigScreen extends StatefulWidget {
  final String type; // 'hiragana' | 'katakana'
  const KanaPracticeConfigScreen({super.key, required this.type});

  @override
  State<KanaPracticeConfigScreen> createState() => _KanaPracticeConfigScreenState();
}

class _KanaPracticeConfigScreenState extends State<KanaPracticeConfigScreen> {
  KanaQuizType _quizType = KanaQuizType.kanaToRomajiMC;
  int _count = 20;
  int _targetCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final targeted = await kanaRepo.getTargeted(type: widget.type);
    if (!mounted) return;
    setState(() { _targetCount = targeted.length; _loading = false; });
  }

  List<KanaQuizType> get _availableTypes => widget.type == 'katakana'
    ? KanaQuizType.values
    : KanaQuizType.values.where((t) => t != KanaQuizType.hiraToKataMC && t != KanaQuizType.kataToHiraMC).toList();

  String _typeLabel(KanaQuizType t) {
    switch (t) {
      case KanaQuizType.kanaToRomajiMC: return 'Kana → Romaji (choice)';
      case KanaQuizType.romajiToKanaMC: return 'Romaji → Kana (choice)';
      case KanaQuizType.kanaToRomajiType: return 'Kana → Type romaji';
      case KanaQuizType.wordToRomajiType: return 'Word → Type romaji';
      case KanaQuizType.hiraToKataMC: return 'Hiragana → Katakana (choice)';
      case KanaQuizType.kataToHiraMC: return 'Katakana → Hiragana (choice)';
    }
  }

  Future<void> _start({bool testMode = false}) async {
    final targeted = await kanaRepo.getTargeted(type: widget.type);
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
      words = await kanaRepo.getWordsForTargetedRows(type: widget.type, targetedRows: rows);
      if (!mounted) return;
      if (words.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No matching words for your targets.')),
        );
        return;
      }
    }

    final allChars = await kanaRepo.getAll(type: widget.type);
    if (!mounted) return;
    Navigator.push(context, AppRoute.to(KanaPracticeScreen(
      chars: targeted,
      allChars: allChars,
      words: words,
      quizType: _quizType,
      count: _count,
      testMode: testMode,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'hiragana' ? 'Hiragana Practice' : 'Katakana Practice';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(title, style: TextStyle(color: AppColors.fg)),
        iconTheme: IconThemeData(color: AppColors.fg),
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_targetCount characters targeted',
                style: TextStyle(color: AppColors.muted, fontSize: 14)),
              const SizedBox(height: 24),
              Text('Quiz type', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
              const SizedBox(height: 12),
              ..._availableTypes.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ScaleOnPress(
                  child: GestureDetector(
                    onTap: () => setState(() => _quizType = t),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: _quizType == t
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : AppColors.btnBg,
                        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                        border: Border.all(
                          color: _quizType == t
                            ? AppColors.accent.withValues(alpha: 0.6)
                            : AppColors.pillBg,
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          _quizType == t ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: _quizType == t ? AppColors.accent : AppColors.muted,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Text(_typeLabel(t), style: TextStyle(
                          color: _quizType == t ? AppColors.fg : AppColors.muted,
                          fontSize: 14,
                        )),
                      ]),
                    ),
                  ),
                ),
              )),
              const SizedBox(height: 24),
              Text('Session size', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [10, 20, 30, 50].map((n) => ScaleOnPress(
                  child: GestureDetector(
                    onTap: () => setState(() => _count = n),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: _count == n ? AppColors.accent.withValues(alpha: 0.15) : AppColors.btnBg,
                        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                        border: Border.all(
                          color: _count == n ? AppColors.accent.withValues(alpha: 0.6) : AppColors.pillBg,
                        ),
                      ),
                      child: Text('$n', style: TextStyle(
                        color: _count == n ? AppColors.accent : AppColors.muted,
                        fontWeight: FontWeight.bold,
                      )),
                    ),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 32),
              ScaleOnPress(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _start(),
                    child: const Text('Start Practice'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ScaleOnPress(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pillBg,
                    ),
                    onPressed: () => _start(testMode: true),
                    child: Text('Start Test', style: TextStyle(color: AppColors.fg)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ScaleOnPress(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.pillBg),
                    onPressed: () => Navigator.push(context, AppRoute.to(
                      MatchingGameConfigScreen(matchContext: MatchContext.kana, kanaType: widget.type),
                    )),
                    child: Text('Matching Game', style: TextStyle(color: AppColors.fg)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ScaleOnPress(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.pillBg),
                    onPressed: () => Navigator.push(context, AppRoute.to(
                      SpeedReadConfigScreen(speedContext: SpeedReadContext.kana, kanaType: widget.type),
                    )),
                    child: Text('Speed Reading', style: TextStyle(color: AppColors.fg)),
                  ),
                ),
              ),
            ]),
          ),
    );
  }
}
