import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../services/onboarding_service.dart';
import '../services/export_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme_backgrounds.dart';
import '../widgets/sakura_overlay.dart';
import 'onboarding_welcome_back_screen.dart';
import 'onboarding_auto_progression_screen.dart';

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

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const Positioned.fill(child: HomeBgLayer()),
        const Positioned.fill(child: SakuraPetalsOverlay()),
        SafeArea(child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar with Skip button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      AppRoute.to(const OnboardingLevelSelectionScreen()),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Title area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  Text(
                    'Welcome to JLPT Kanji & Vocabulary',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.fg,
                      letterSpacing: -0.6,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'A few notes on how to get started.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Carousel card (Expanded)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
                child: _TutorialCarousel(
                  pageController: _pageController,
                  currentPage: _currentPage,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                ),
              ),
            ),

            // Get started button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  AppRoute.to(const OnboardingLevelSelectionScreen()),
                ),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: AppColors.pillBg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Get started',
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.fg,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        )),
      ]),
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
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.pillBg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
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
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < _pageCount; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == currentPage ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == currentPage ? AppColors.accent : AppColors.pillBg,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            const SizedBox(width: 8),
            Text(
              '${currentPage + 1} / $_pageCount',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.muted,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'This app has 3 kanji & vocab states',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppColors.fg,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _StateTile(variant: _StateTileVariant.not),
              _StateTile(variant: _StateTileVariant.target),
              _StateTile(variant: _StateTileVariant.learned),
            ],
          ),
          const SizedBox(height: 22),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
                height: 1.65,
              ),
              children: [
                const TextSpan(text: 'Choose “'),
                TextSpan(
                  text: 'target',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.fg,
                  ),
                ),
                const TextSpan(
                  text: '” kanji or vocabulary any time — only your targets appear in practice.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'You can turn a “target” into a “learned” kanji or vocabulary by correctly answering it in test mode. You can take tests to progress whenever you are ready.',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum _StateTileVariant { not, target, learned }

class _StateTile extends StatelessWidget {
  final _StateTileVariant variant;
  const _StateTile({required this.variant});

  @override
  Widget build(BuildContext context) {
    late Color cardColor;
    late Color borderColor;
    late Color inkColor;
    late String label;
    Color? badgeBg;
    IconData? badgeIcon;

    switch (variant) {
      case _StateTileVariant.not:
        cardColor = AppColors.surface;
        borderColor = AppColors.pillBg;
        inkColor = AppColors.muted;
        label = 'Not learned';
      case _StateTileVariant.target:
        cardColor = AppColors.accent.withValues(alpha: 0.13);
        borderColor = AppColors.accent;
        inkColor = AppColors.fg;
        label = 'Target';
        badgeBg = AppColors.accent;
        badgeIcon = Icons.star;
      case _StateTileVariant.learned:
        cardColor = const Color(0xFF4E9D69).withValues(alpha: 0.13);
        borderColor = const Color(0xFF4E9D69);
        inkColor = const Color(0xFF4E9D69);
        label = 'Learned';
        badgeBg = const Color(0xFF4E9D69);
        badgeIcon = Icons.check;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: borderColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '字',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: inkColor,
                  fontFamily: 'NotoSerifCJKjp',
                ),
              ),
            ),
            if (badgeBg != null && badgeIcon != null)
              Positioned(
                top: -7,
                right: -7,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: badgeBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(badgeIcon, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
          ),
        ),
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
          const SizedBox(height: 10),
          Text(
            'These are not directly tied-in to the overall progression system and are only there to help prepare specifically for these exams. You can check your scores in your test history to see your long term progress.',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.4),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TutorialPage3 extends ConsumerWidget {
  const _TutorialPage3();

  static const _themeOptions = [
    (AppTheme.sakura,      'Spring Sakura',  Color(0xFFD4677E)),
    (AppTheme.loveLetter,  'Love Letter',    Color(0xFF6F97C4)),
    (AppTheme.simpleDark,  'Simple Black',   Color(0xFF7D97FF)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeNotifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Pick a theme',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              color: AppColors.fg,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You can change this any time in Settings.',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          for (final (theme, label, swatch) in _themeOptions) ...[
            GestureDetector(
              onTap: () => ref.read(themeNotifier.notifier).setTheme(theme),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: currentTheme == theme
                      ? swatch.withValues(alpha: 0.12)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: currentTheme == theme ? swatch : AppColors.pillBg,
                    width: currentTheme == theme ? 1.8 : 1.2,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: swatch,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.fg,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: currentTheme == theme ? 1.0 : 0.0,
                    child: Icon(Icons.check_circle_rounded, size: 20, color: swatch),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.music_note_outlined, color: AppColors.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ambient background sounds are available too — they won\'t interfere with other apps\' audio.',
                style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.45),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ── Page 2: Level Selection ────────────────────────────────────────────────────

class OnboardingLevelSelectionScreen extends ConsumerWidget {
  const OnboardingLevelSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeColorsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        const Positioned.fill(child: HomeBgLayer()),
        const Positioned.fill(child: SakuraPetalsOverlay()),
        SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.pillBg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.fg),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                'Choose Your Level',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.fg,
                  letterSpacing: -0.6,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You can change this any time.',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Level rows
              _LevelRow(
                level: 'N5',
                title: 'Beginner',
                desc: 'Start by learning hiragana and katakana (the ABCs of Japanese) and some simple vocabulary. Then move on to easy kanji.',
                onTap: () => Navigator.push(context, AppRoute.to(OnboardingAutoProgressionScreen(level: 5))),
              ),
              const SizedBox(height: 9),
              _LevelRow(
                level: 'N4',
                title: 'Elementary',
                desc: 'You know your basics? Great! Time to build out your kanji repertoire and expand that vocabulary.',
                onTap: () => Navigator.push(context, AppRoute.to(OnboardingAutoProgressionScreen(level: 4))),
              ),
              const SizedBox(height: 9),
              _LevelRow(
                level: 'N3',
                title: 'Intermediate',
                desc: 'Starting to get comfortable? Take on everyday kanji and vocabulary that bridges beginner and advanced Japanese.',
                onTap: () => Navigator.push(context, AppRoute.to(OnboardingAutoProgressionScreen(level: 3))),
              ),
              const SizedBox(height: 9),
              _LevelRow(
                level: 'N2',
                title: 'Upper-Intermediate',
                desc: 'Getting serious! Tackle the breadth of kanji and vocabulary used in business and academic Japanese.',
                onTap: () => Navigator.push(context, AppRoute.to(OnboardingAutoProgressionScreen(level: 2))),
              ),
              const SizedBox(height: 9),
              _LevelRow(
                level: 'N1',
                title: 'Advanced',
                desc: 'The summit! Master the complete set of kanji and advanced vocabulary used in formal written Japanese.',
                onTap: () => Navigator.push(context, AppRoute.to(OnboardingAutoProgressionScreen(level: 1))),
              ),

              // "I have a user data file" dashed button
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () async {
                  try {
                    final ok = await exportService.importProgress(
                      context,
                      ref.read(settingsProvider),
                      (s) => ref.read(settingsProvider.notifier).update(s),
                    );
                    if (ok && context.mounted) {
                      await OnboardingService.markOnboardingComplete();
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          AppRoute.to(const OnboardingWelcomeBackScreen()),
                        );
                      }
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
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.pillBg,
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.upload_file, size: 17, color: AppColors.muted),
                      const SizedBox(width: 9),
                      Text(
                        'I have a user data file',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ]),
    );
  }
}

class _LevelRow extends StatelessWidget {
  final String level;
  final String title;
  final String desc;
  final VoidCallback onTap;

  const _LevelRow({
    required this.level,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.pillBg, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(13),
              ),
              alignment: Alignment.center,
              child: Text(
                level,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.fg,
                        ),
                      ),
                      Text(
                        'JLPT $level',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
