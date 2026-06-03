import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import '../services/onboarding_service.dart';
import 'home_screen.dart';

class OnboardingN5Screen extends StatelessWidget {
  const OnboardingN5Screen({super.key});

  static const _options = [
    (label: '5 kanji and 10 vocabulary',           kanji: 5,    vocab: 10),
    (label: '10 kanji and 20 vocabulary',           kanji: 10,   vocab: 20),
    (label: '20 kanji and 40 vocabulary',           kanji: 20,   vocab: 40),
    (label: '30 kanji and 60 vocabulary',           kanji: 30,   vocab: 60),
    (label: 'All kanji and vocabulary for JLPT N5', kanji: 9999, vocab: 9999),
  ];

  Future<void> _apply(BuildContext context, int kanji, int vocab) async {
    await OnboardingService.applyN5Targets(kanjiCount: kanji, vocabCount: vocab);
    await OnboardingService.markOnboardingComplete();
    if (context.mounted) {
      Navigator.pushReplacement(context, AppRoute.to(const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.fg),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Great! Let us know how many kanji and vocabulary you\'d like to start with!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.fg,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              for (final opt in _options) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.btnBg,
                    foregroundColor: AppColors.fg,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                    ),
                  ),
                  onPressed: () => _apply(context, opt.kanji, opt.vocab),
                  child: Text(opt.label, textAlign: TextAlign.center),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
