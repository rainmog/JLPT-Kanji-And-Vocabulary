import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../services/onboarding_service.dart';
import '../services/export_service.dart';
import '../services/settings_service.dart';
import '../repositories/kana_repository.dart';
import 'home_screen.dart';
import 'onboarding_welcome_back_screen.dart';

// ── Page 1: Welcome ────────────────────────────────────────────────────────────

class OnboardingWelcomeScreen extends ConsumerStatefulWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  ConsumerState<OnboardingWelcomeScreen> createState() => _OnboardingWelcomeScreenState();
}

class _OnboardingWelcomeScreenState extends ConsumerState<OnboardingWelcomeScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeColorsProvider);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: screenHeight * 0.12),
              Text(
                'Welcome to JLPT Kanji & Vocabulary',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.fg,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'A few notes on how to get started.',
                style: TextStyle(fontSize: 15, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              _TutorialCarousel(
                pageController: _pageController,
                currentPage: _currentPage,
                onPageChanged: (i) => setState(() => _currentPage = i),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.btnBg,
                  foregroundColor: AppColors.fg,
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                  ),
                ),
                onPressed: () => Navigator.push(
                  context,
                  AppRoute.to(const OnboardingLevelSelectionScreen()),
                ),
                child: const Text('Get started'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _TutorialCarousel extends StatelessWidget {
  final PageController pageController;
  final int currentPage;
  final ValueChanged<int> onPageChanged;
  static const _pageCount = 3;

  const _TutorialCarousel({
    required this.pageController,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 440,
          decoration: BoxDecoration(
            color: AppColors.btnBg,
            borderRadius: BorderRadius.circular(AppColors.containerRadius),
          ),
          clipBehavior: Clip.hardEdge,
          child: PageView(
            controller: pageController,
            onPageChanged: onPageChanged,
            children: const [
              _TutorialPage1(),
              _TutorialPage2(),
              _TutorialPage3(),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < _pageCount; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == currentPage ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == currentPage ? AppColors.accent : AppColors.pillBg,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              '${currentPage + 1} / $_pageCount',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ],
    );
  }
}

class _TutorialPage1 extends StatelessWidget {
  const _TutorialPage1();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'This app has 3 kanji/vocab states:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StateChip(label: 'Not Learned', kanji: '字', color: AppColors.muted),
              _StateChip(label: 'Target', kanji: '字', color: AppColors.accent, showTarget: true),
              _StateChip(label: 'Learned', kanji: '字', color: AppColors.correct, showCheck: true),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'You can choose target kanji at any time; only these targeted kanji will appear in your practice sessions. '
            'To convert them to learned you must correctly identify them in the test mode which quizzes you on your targets.',
            style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final String label;
  final String kanji;
  final Color color;
  final bool showTarget;
  final bool showCheck;

  const _StateChip({
    required this.label,
    required this.kanji,
    required this.color,
    this.showTarget = false,
    this.showCheck = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.4)),
              ),
              child: Text(kanji, style: TextStyle(fontSize: 22, color: color)),
            ),
            if (showTarget)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('★', style: TextStyle(fontSize: 8, color: AppColors.bg)),
                ),
              ),
            if (showCheck)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.correct,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('✓', style: TextStyle(fontSize: 8, color: AppColors.bg)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(fontSize: 10, color: AppColors.muted)),
      ],
    );
  }
}

class _TutorialPage2 extends StatelessWidget {
  const _TutorialPage2();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'JLPT Practice Tests',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Icon(Icons.quiz_outlined, color: AppColors.accent, size: 36),
          const SizedBox(height: 12),
          Text(
            'Take JLPT practice tests of any level.',
            style: TextStyle(fontSize: 15, color: AppColors.fg),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'The questions are randomized from our database, so each test should be different. '
            'You can also check your score history to track your progress over time.',
            style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TutorialPage3 extends StatelessWidget {
  const _TutorialPage3();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Themes & Ambient Music',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Icon(Icons.palette_outlined, color: AppColors.accent, size: 36),
          const SizedBox(height: 10),
          Text(
            'Change your theme at any time from the Settings page.',
            style: TextStyle(fontSize: 15, color: AppColors.fg),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Icon(Icons.music_note_outlined, color: AppColors.accent, size: 36),
          const SizedBox(height: 10),
          Text(
            'Play ambient background sounds that won\'t interfere with other apps\' audio.',
            style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Page 2: Level Selection ────────────────────────────────────────────────────

class OnboardingLevelSelectionScreen extends ConsumerWidget {
  const OnboardingLevelSelectionScreen({super.key});

  Future<void> _applyAndGo(BuildContext context, WidgetRef ref, Future<void> Function() apply, {bool hideKana = false}) async {
    await apply();
    if (hideKana) {
      final settings = ref.read(settingsProvider);
      await ref.read(settingsProvider.notifier).update(settings.copyWith(hideKanaPractice: true));
      await kanaRepo.setAllLearned(type: 'hiragana');
      await kanaRepo.setAllLearned(type: 'katakana');
    }
    await OnboardingService.markOnboardingComplete();
    if (context.mounted) {
      Navigator.pushReplacement(context, AppRoute.to(const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeColorsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(32, 60, 32, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose your level.',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.fg,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This can be changed later.',
                    style: TextStyle(fontSize: 14, color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  _LevelButton(
                    label: 'Clean Start',
                    onTap: () => _applyAndGo(context, ref, () async {}),
                  ),
                  const SizedBox(height: 12),
                  _LevelButton(
                    label: 'JLPT N5',
                    onTap: () => _applyAndGo(context, ref,
                        () => OnboardingService.applyN5Targets(kanjiCount: 10, vocabCount: 20)),
                  ),
                  const SizedBox(height: 12),
                  _LevelButton(
                    label: 'JLPT N4',
                    onTap: () => _applyAndGo(context, ref,
                        () => OnboardingService.applyLevelTargets(level: 4),
                        hideKana: true),
                  ),
                  const SizedBox(height: 12),
                  _LevelButton(
                    label: 'JLPT N3',
                    onTap: () => _applyAndGo(context, ref,
                        () => OnboardingService.applyLevelTargets(level: 3),
                        hideKana: true),
                  ),
                  const SizedBox(height: 12),
                  _LevelButton(
                    label: 'JLPT N2',
                    onTap: () => _applyAndGo(context, ref,
                        () => OnboardingService.applyLevelTargets(level: 2),
                        hideKana: true),
                  ),
                  const SizedBox(height: 12),
                  _LevelButton(
                    label: 'JLPT N1',
                    onTap: () => _applyAndGo(context, ref,
                        () => OnboardingService.applyLevelTargets(level: 1),
                        hideKana: true),
                  ),
                  const SizedBox(height: 24),
                  Divider(color: AppColors.pillBg),
                  const SizedBox(height: 24),
                  _LevelButton(
                    label: 'I have a user data file',
                    onTap: () async {
                      try {
                        final ok = await exportService.importProgress(
                          context,
                          ref.read(settingsProvider),
                          (s) => ref.read(settingsProvider.notifier).update(s),
                        );
                        if (ok && context.mounted) {
                          await OnboardingService.markOnboardingComplete();
                          Navigator.pushReplacement(
                            context,
                            AppRoute.to(const OnboardingWelcomeBackScreen()),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Import failed: $e'),
                              backgroundColor: AppColors.incorrectBg,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LevelButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.btnBg,
        foregroundColor: AppColors.fg,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.buttonRadius),
        ),
      ),
      onPressed: onTap,
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}
