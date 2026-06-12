import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../services/onboarding_service.dart';
import 'home_screen.dart';

class OnboardingN5Screen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.pillBg),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.arrow_back_ios_new, size: 20, color: colors.fg),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'How many to start with?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: colors.fg, letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              Text(
                'You can change this any time.',
                style: TextStyle(fontSize: 14, color: colors.muted),
              ),
              const SizedBox(height: 24),
              for (final opt in _options) ...[
                GestureDetector(
                  onTap: () => _apply(context, opt.kanji, opt.vocab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.pillBg, width: 1.5),
                    ),
                    child: Row(children: [
                      Expanded(child: Text(opt.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.fg))),
                      Icon(Icons.chevron_right_rounded, size: 18, color: colors.muted),
                    ]),
                  ),
                ),
                const SizedBox(height: 9),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
