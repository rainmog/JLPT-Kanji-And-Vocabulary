import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/vocab_repository.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import 'vocab_test_session_screen.dart';

class VocabTestIntroScreen extends ConsumerWidget {
  const VocabTestIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Target Vocabulary')),
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
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.fg)),
            ),
            const SizedBox(height: 20),
            _rule('2 questions per word — you must get BOTH correct in the same test to mark a word as learned.'),
            _rule('Question types: Japanese word → English meaning, and English meaning → Japanese word.'),
            _rule('Getting either question wrong resets both — you must get both right in the same session.'),
            _rule('Maximum 50 questions (25 words). Words are drawn randomly from your target set.'),
            _rule('Pass threshold: 70%. Failed words stay as targets — keep practicing and try again.'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _start(context),
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
      Expanded(child: Text(text, style: TextStyle(fontSize: 16, color: AppColors.fg))),
    ]),
  );

  Future<void> _start(BuildContext context) async {
    final targets = await vocabRepo.getTargetVocab();
    if (targets.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No target vocabulary selected. Go to Select Target Vocabulary first.'),
      ));
      return;
    }
    if (!context.mounted) return;
    Navigator.push(context, AppRoute.to(VocabTestSessionScreen(allTargets: targets)));
  }
}
