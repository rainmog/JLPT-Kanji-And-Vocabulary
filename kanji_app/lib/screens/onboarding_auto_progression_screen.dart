import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kana_repository.dart';
import '../services/onboarding_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/k_setup.dart';
import 'home_screen.dart';

class OnboardingAutoProgressionScreen extends ConsumerStatefulWidget {
  final int? level; // 5=N5 … 1=N1, null=clean start
  const OnboardingAutoProgressionScreen({super.key, required this.level});

  @override
  ConsumerState<OnboardingAutoProgressionScreen> createState() =>
      _OnboardingAutoProgressionScreenState();
}

class _OnboardingAutoProgressionScreenState
    extends ConsumerState<OnboardingAutoProgressionScreen> {
  late bool _enabled;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _enabled = ref.read(settingsProvider).autoProgressionEnabled;
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    try {
      // 1. Save auto-progression toggle
      final settings = ref.read(settingsProvider);
      await ref.read(settingsProvider.notifier).update(
        settings.copyWith(autoProgressionEnabled: _enabled),
      );

      // 2. Apply level setup
      final level = widget.level;
      if (level == null) {
        // Clean start — auto-progression handles filling from N5
        await OnboardingService.markOnboardingComplete();
      } else if (level == 5) {
        await OnboardingService.applyN5Targets(
          kanjiCount: _enabled ? 15 : 80,
          vocabCount: _enabled ? 30 : 663,
        );
        await OnboardingService.setKanaTargetBatch(count: 10);
        final s = ref.read(settingsProvider);
        await ref.read(settingsProvider.notifier).update(
          s.copyWith(homeTrackers: const ['kanji:N5', 'vocab:N5', 'hiragana:all', 'katakana:all']),
        );
        await OnboardingService.markOnboardingComplete();
      } else {
        await OnboardingService.applyLevelTargets(level: level);
        // N4+: set all kana as learned
        await kanaRepo.setAllLearned(type: 'hiragana');
        await kanaRepo.setAllLearned(type: 'katakana');
        final levelName = {4: 'N4', 3: 'N3', 2: 'N2', 1: 'N1'}[level]!;
        final s = ref.read(settingsProvider);
        await ref.read(settingsProvider.notifier).update(
          s.copyWith(homeTrackers: ['kanji:$levelName', 'vocab:$levelName']),
        );
        await OnboardingService.markOnboardingComplete();
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        AppRoute.to(const HomeScreen()),
        (_) => false,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _levelLabel {
    if (widget.level == null) return 'Clean Start';
    return 'JLPT N${widget.level}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(children: [
          // Back button row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(children: [
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
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.fg),
                ),
              ),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  'Automatic Progression',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppColors.fg,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _levelLabel,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: 28),

                // Explanation card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.pillBg, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.auto_awesome, size: 20, color: AppColors.accent),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'How it works',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.fg,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    Text(
                      'The app automatically keeps 15 kanji and 30 vocabulary set as targets for you, '
                      'progressing from easiest to hardest.',
                      style: TextStyle(fontSize: 14, color: AppColors.fg, height: 1.6),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'When you mark something as learned and your target count drops, '
                      'new targets are added automatically so you always have something to study.',
                      style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.6),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You can always add your own targets on top of this. '
                      'You can also adjust the quota or turn this off in Settings.',
                      style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.6),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // Toggle row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.pillBg, width: 1.5),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          'Enable automatic progression',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.fg,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Recommended for most learners',
                          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                        ),
                      ]),
                    ),
                    KToggle(
                      value: _enabled,
                      colors: colors,
                      onChanged: (v) => setState(() => _enabled = v),
                    ),
                  ]),
                ),
              ]),
            ),
          ),

          // Start button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                ),
                onPressed: _loading ? null : _finish,
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Start studying',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
