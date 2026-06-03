import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import 'home_screen.dart';

class OnboardingWelcomeBackScreen extends StatelessWidget {
  const OnboardingWelcomeBackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.correct, size: 64),
                const SizedBox(height: 24),
                Text(
                  'Welcome back!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.fg,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your data has been loaded.',
                  style: TextStyle(fontSize: 16, color: AppColors.muted),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.bg,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                    ),
                  ),
                  onPressed: () => Navigator.pushReplacement(
                    context,
                    AppRoute.to(const HomeScreen()),
                  ),
                  child: const Text("Let's go", style: TextStyle(fontSize: 17)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
