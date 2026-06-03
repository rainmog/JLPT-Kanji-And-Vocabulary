import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import '../services/onboarding_service.dart';
import 'home_screen.dart';

class OnboardingLevelScreen extends StatelessWidget {
  final int level; // 4=N4, 3=N3, 2=N2, 1=N1

  const OnboardingLevelScreen({super.key, required this.level});

  Future<void> _apply(BuildContext context, LevelBounds bounds) async {
    await OnboardingService.applyBounds(bounds);
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
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Great! Let us know how you want to start using the app.',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.fg,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.btnBg,
                    foregroundColor: AppColors.fg,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                    ),
                  ),
                  onPressed: () => _apply(
                    context,
                    OnboardingService.levelBoundsForReview(level),
                  ),
                  child: const Text(
                    'I want to start by reviewing, with a few new things to learn in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                    ),
                  ),
                  onPressed: () => _apply(
                    context,
                    OnboardingService.levelBoundsForNewStuff(level),
                  ),
                  child: const Text(
                    'I\'m already confident in the previous levels, start me with just the new stuff.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
