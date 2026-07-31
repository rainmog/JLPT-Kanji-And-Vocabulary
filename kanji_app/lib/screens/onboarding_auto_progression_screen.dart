import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kana_repository.dart';
import '../services/onboarding_service.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../utils/learning_constants.dart';
import '../widgets/k_setup.dart';
import 'main_shell.dart';

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
  late String _learnedVia;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _enabled = s.autoProgressionEnabled;
    _learnedVia = s.learnedVia;
  }

  Future<void> _finish() async {
    setState(() => _loading = true);
    try {
      // 1. Save auto-progression toggle
      final settings = ref.read(settingsProvider);
      await ref.read(settingsProvider.notifier).update(
        settings.copyWith(autoProgressionEnabled: _enabled, learnedVia: _learnedVia),
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
        AppRoute.to(const MainShell()),
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

  Widget _styleCard({
    required bool selected,
    required IconData icon,
    required String title,
    required String body,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.pillBg,
            width: selected ? 2 : 1.5,
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.fg,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, size: 20, color: AppColors.accent),
              ]),
              const SizedBox(height: 5),
              Text(
                body,
                style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _pointRow(String head, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(head, style: TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.accent,
          )),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(body, style: TextStyle(fontSize: 13.5, color: AppColors.fg, height: 1.45)),
        ),
      ]),
    );
  }

  /// Explains the spaced points system used by practice-mode learning.
  Widget _practicePointsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.pillBg, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.trending_up, size: 18, color: AppColors.accent),
          const SizedBox(width: 8),
          Text('How practice learning works', style: TextStyle(
            fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.fg,
          )),
        ]),
        const SizedBox(height: 14),
        _pointRow('+5', 'The first correct answer each day is worth the most.'),
        _pointRow('+1', 'Every extra correct answer that same day.'),
        _pointRow('−1', 'A wrong answer, never below zero.'),
        _pointRow('$kPracticePointsToLearn', 'Points needed before an item is learned.'),
        const SizedBox(height: 4),
        Text(
          'An item can appear up to $kPracticeDailyCap times a day, so it takes at least '
          '3 days to learn — short daily reviews stick far better than cramming. '
          'Once you run out of new items for the day, learned ones come back for review.',
          style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.55),
        ),
      ]),
    );
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

                // ── Learning style selector ──────────────────────────────
                Text(
                  'How you learn',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.fg,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose how an item becomes "learned". You can change this later in Settings.',
                  style: TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.5),
                ),
                const SizedBox(height: 14),
                _styleCard(
                  selected: _learnedVia == 'test',
                  icon: Icons.quiz_outlined,
                  title: 'Learn by Testing',
                  body: 'Take tests to prove what you know. Answer an item correctly in '
                      'a test and it becomes learned.',
                  onTap: () => setState(() => _learnedVia = 'test'),
                ),
                const SizedBox(height: 10),
                _styleCard(
                  selected: _learnedVia == 'practice',
                  icon: Icons.school_outlined,
                  title: 'Learn by Practicing',
                  body: 'No separate tests. Items build up points as you answer them '
                      'correctly in practice, and become learned over a few days.',
                  onTap: () => setState(() => _learnedVia = 'practice'),
                ),
                if (_learnedVia == 'practice') ...[
                  const SizedBox(height: 12),
                  _practicePointsCard(),
                ],

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
