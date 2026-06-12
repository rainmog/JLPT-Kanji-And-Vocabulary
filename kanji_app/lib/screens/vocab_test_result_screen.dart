import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/history_repository.dart';
import '../repositories/vocab_repository.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../theme_provider.dart';

class VocabTestResultScreen extends ConsumerStatefulWidget {
  final List<VocabWord> testedWords;
  final Map<int, ({bool? wordToMeaning, bool? meaningToWord})> scores;

  const VocabTestResultScreen({
    super.key,
    required this.testedWords,
    required this.scores,
  });

  @override
  ConsumerState<VocabTestResultScreen> createState() => _VocabTestResultScreenState();
}

class _VocabTestResultScreenState extends ConsumerState<VocabTestResultScreen> {
  bool _saving = true;
  bool _historySaved = false;

  @override
  void initState() {
    super.initState();
    soundService.playTestComplete();
    _applyResults();
    _saveHistory();
  }

  Future<void> _applyResults() async {
    for (final word in widget.testedWords) {
      final s = widget.scores[word.id];
      if (s == null) continue;
      if (s.wordToMeaning == true && s.meaningToWord == true) {
        await vocabRepo.markLearned(word.id);
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveHistory() async {
    if (_historySaved) return;
    _historySaved = true;
    final totalQuestions = widget.testedWords.length * 2;
    final correctCount = widget.scores.values.fold(0, (sum, s) {
      return sum + (s.wordToMeaning == true ? 1 : 0) + (s.meaningToWord == true ? 1 : 0);
    });
    await historyRepo.logResult(
      testType: 'vocab',
      score: correctCount,
      total: totalQuestions,
      detail: {'mode': 'both'},
    );
  }

  bool _passed(int vocabId) {
    final s = widget.scores[vocabId];
    return s != null && s.wordToMeaning == true && s.meaningToWord == true;
  }

  String _resultMessage(double pct) {
    if (pct >= 1.0) return 'Perfect. You are the Einstein of moon-speak.';
    if (pct >= 0.85) return 'Excellent. You have really studied hard.';
    if (pct >= 0.70) return 'Great job, easy test.';
    if (pct >= 0.50) return 'Not bad, but aim higher.';
    return 'A little more practice needed.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);
    final anim = ref.watch(settingsProvider).animationsEnabled;
    final passedCount = widget.testedWords.where((w) => _passed(w.id)).length;
    final total = widget.testedWords.length;
    final totalQuestions = total * 2;
    final correctCount = widget.scores.values.fold(0, (sum, s) {
      int c = 0;
      if (s.wordToMeaning == true) c++;
      if (s.meaningToWord == true) c++;
      return sum + c;
    });
    final percentage = totalQuestions == 0 ? 0.0 : correctCount / totalQuestions;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Text('Test Results', style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800,
                color: colors.fg, letterSpacing: -0.4,
              )),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(children: [
                  TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: correctCount),
                    duration: anim ? const Duration(milliseconds: 900) : Duration.zero,
                    curve: Curves.easeOut,
                    builder: (_, value, __) => Text(
                      '$value / $totalQuestions correct',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: colors.fg),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _resultMessage(percentage),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: colors.fg),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text('$passedCount / $total words learned this session',
                    style: TextStyle(fontSize: 14, color: colors.muted)),
                  const SizedBox(height: 20),

                  Expanded(
                    child: _saving
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.separated(
                          itemCount: widget.testedWords.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: colors.pillBg),
                          itemBuilder: (context, i) {
                            final word = widget.testedWords[i];
                            final didPass = _passed(word.id);
                            final s = widget.scores[word.id];
                            return ListTile(
                              leading: Icon(
                                didPass ? Icons.check_circle : Icons.cancel,
                                color: didPass ? AppColors.correct : AppColors.incorrect,
                              ),
                              title: Text(word.reading,
                                style: TextStyle(color: colors.fg, fontSize: 16)),
                              subtitle: Text(word.meanings,
                                style: TextStyle(color: colors.muted, fontSize: 13)),
                              trailing: s == null ? null : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(s.wordToMeaning == true ? Icons.check : Icons.close,
                                    size: 14,
                                    color: s.wordToMeaning == true ? AppColors.correct : AppColors.incorrect),
                                  Icon(s.meaningToWord == true ? Icons.check : Icons.close,
                                    size: 14,
                                    color: s.meaningToWord == true ? AppColors.correct : AppColors.incorrect),
                                ],
                              ),
                            );
                          },
                        ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                      ),
                      onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                      child: const Text('Back to Home', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
