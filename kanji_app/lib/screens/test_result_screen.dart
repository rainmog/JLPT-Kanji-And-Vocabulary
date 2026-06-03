import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/history_repository.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/progress_repository.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';

class TestResultScreen extends ConsumerStatefulWidget {
  final List<Kanji> testedKanji;
  /// character → (correct, total) — must have 3 total to be eligible to pass
  final Map<String, (int, int)> kanjiScores;

  const TestResultScreen({
    super.key,
    required this.testedKanji,
    required this.kanjiScores,
  });

  @override
  ConsumerState<TestResultScreen> createState() => _TestResultScreenState();
}

class _TestResultScreenState extends ConsumerState<TestResultScreen> {
  bool _saving = false;
  bool _historySaved = false;

  @override
  void initState() {
    super.initState();
    soundService.playTestComplete();
    _applyResults();
    _saveHistory();
  }

  Future<void> _applyResults() async {
    setState(() => _saving = true);
    for (final kanji in widget.testedKanji) {
      final (correct, total) = widget.kanjiScores[kanji.character] ?? (0, 0);
      if (total >= 3 && correct == total) {
        await progressRepo.markLearned(kanji.id);
      }
      // Failed kanji stay as 'target' — no action needed
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _saveHistory() async {
    if (_historySaved) return;
    _historySaved = true;
    final totalCorrect = widget.kanjiScores.values.fold(0, (s, v) => s + v.$1);
    final totalQ = widget.kanjiScores.values.fold(0, (s, v) => s + v.$2);
    final detail = {
      'kanji': widget.testedKanji.map((k) {
        final (c, t) = widget.kanjiScores[k.character] ?? (0, 0);
        return [k.character, c, t];
      }).toList(),
    };
    await historyRepo.logResult(
      testType: 'target_kanji',
      score: totalCorrect,
      total: totalQ,
      detail: detail,
    );
  }

  bool _passed(String character) {
    final (correct, total) = widget.kanjiScores[character] ?? (0, 0);
    return total >= 3 && correct == total;
  }

  @override
  Widget build(BuildContext context) {
    final anim = ref.watch(settingsProvider).animationsEnabled;
    final passedCount = widget.testedKanji.where((k) => _passed(k.character)).length;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Test Results'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: passedCount),
                duration: anim ? const Duration(milliseconds: 900) : Duration.zero,
                curve: Curves.easeOut,
                builder: (_, value, __) => Text(
                  '$value / ${widget.testedKanji.length} kanji learned',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.fg,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: widget.testedKanji.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final kanji = widget.testedKanji[idx];
                          final passed = _passed(kanji.character);
                          final (correct, total) =
                              widget.kanjiScores[kanji.character] ?? (0, 0);
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: passed
                                  ? Colors.green.withValues(alpha: 0.12)
                                  : Colors.red.withValues(alpha: 0.10),
                              borderRadius:
                                  BorderRadius.circular(AppColors.containerRadius),
                              border: Border.all(
                                color: passed ? Colors.green : Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Row(children: [
                              Text(kanji.character,
                                  style: TextStyle(
                                      fontSize: 28,
                                      color: AppColors.kanjiColor)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(kanji.meaning.split(',')[0],
                                        style: TextStyle(
                                            fontSize: 14, color: AppColors.muted)),
                                    Text(
                                      passed ? 'Learned ✓' : 'Not yet — $correct/$total correct',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: passed ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                passed ? Icons.check_circle : Icons.cancel,
                                color: passed ? Colors.green : Colors.red,
                              ),
                            ]),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving
                      ? null
                      : () {
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Back to Home', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
