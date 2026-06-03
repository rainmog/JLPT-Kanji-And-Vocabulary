import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kanji_repository.dart';
import '../theme.dart';
import 'test_session_screen.dart';
import '../utils/app_route.dart';

class TestIntroScreen extends ConsumerWidget {
  const TestIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Target Kanji')),
      body: SafeArea(
        child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              child: Text('How The Test Works',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold,
                      color: AppColors.fg)),
            ),
            const SizedBox(height: 20),
            _rule('3 questions per kanji - you must get all 3 questions correct to pass. Then that kanji will be marked as learned.'),
            _rule('Kanji you fail will stay as targets - keep practicing and try again.'),
            _rule('There is a maximum of 30 questions in the test - 10 target kanji - taken randomly from your pool of current target kanji.'),
            _rule('Questions use sentences matched to each kanji\'s JLPT level.'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _startTest(context),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Start Test', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _rule(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('• ', style: TextStyle(color: AppColors.accent, fontSize: 18)),
      Expanded(child: Text(text, style: TextStyle(fontSize: 17, color: AppColors.fg))),
    ]),
  );

  Future<void> _startTest(BuildContext context) async {
    final targets = await kanjiRepo.getTargetKanjiList();
    if (targets.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No target kanji selected. Go to Select Target Kanji first.')),
      );
      return;
    }
    if (!context.mounted) return;
    final allN5 = targets.every((k) => k.jlptLevel == 5);
    Navigator.push(context, AppRoute.to(TestSessionScreen(allTargets: targets, forceFurigana: allN5)));
  }
}
