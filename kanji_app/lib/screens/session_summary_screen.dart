import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';

class SessionSummaryScreen extends ConsumerStatefulWidget {
  final int correct;
  final int total;
  final List<String> learnedChars;
  final List<({String display, int count})> practiceCounts;
  // Practice-mode learning progress: each item's display char/word, whether it
  // reached 'learned' this session, and how many more correct answers remain.
  final List<({String display, bool learned, int percent})> practiceProgress;

  const SessionSummaryScreen({
    super.key,
    required this.correct,
    required this.total,
    required this.learnedChars,
    this.practiceCounts = const [],
    this.practiceProgress = const [],
  });

  @override
  ConsumerState<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scoreCtrl;
  late final Animation<double> _scoreAnim;

  @override
  void initState() {
    super.initState();
    soundService.playTestComplete();
    _scoreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scoreAnim = CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOut);
    if (ref.read(settingsProvider).animationsEnabled) {
      _scoreCtrl.forward();
    } else {
      _scoreCtrl.value = 1.0;
    }
  }

  @override
  void dispose() {
    _scoreCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.total == 0 ? 0 : (widget.correct / widget.total * 100).round();
    final missed = widget.total - widget.correct;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      'Session Complete',
                      style: TextStyle(
                        color: AppColors.fg,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Score
                    ScaleTransition(
                      scale: _scoreAnim,
                      child: RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${widget.correct}',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 68,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            TextSpan(
                              text: ' / ${widget.total}',
                              style: TextStyle(
                                color: AppColors.muted.withValues(alpha: 0.5),
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Percentage
                    Text(
                      '$pct% correct',
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Stat pills
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _StatPill(
                          icon: Icons.check,
                          label: '${widget.correct} correct',
                          color: AppColors.correct,
                        ),
                        const SizedBox(width: 10),
                        _StatPill(
                          icon: Icons.close,
                          label: '$missed missed',
                          color: AppColors.incorrect,
                        ),
                      ],
                    ),

                    // Learned chars
                    if (widget.learnedChars.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      Text(
                        'Correctly identified in this session:',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: widget.learnedChars.take(8).map((c) {
                          return Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.13),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: AppColors.accent.withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              c,
                              style: TextStyle(
                                color: AppColors.fg,
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppFonts.japaneseFont,
                                fontFamilyFallback: AppFonts.japaneseFallback,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],

                    if (widget.practiceProgress.isNotEmpty) ...[
                      const SizedBox(height: 30),
                      Builder(builder: (_) {
                        final newlyLearned =
                            widget.practiceProgress.where((p) => p.learned).length;
                        return Text(
                          newlyLearned > 0
                              ? '$newlyLearned reached Learned!'
                              : 'Learning progress',
                          style: TextStyle(
                            color: newlyLearned > 0 ? AppColors.correct : AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: AppColors.pillBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: widget.practiceProgress.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.display,
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: AppColors.kanjiColor,
                                      fontFamily: AppFonts.japaneseFont,
                                      fontFamilyFallback: AppFonts.japaneseFallback,
                                    ),
                                  ),
                                  if (item.learned)
                                    Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.check_circle, size: 16, color: AppColors.correct),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Learned',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.correct,
                                        ),
                                      ),
                                    ])
                                  else
                                    Text(
                                      '${item.percent}%',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                    ],

                    if (widget.practiceCounts.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Total times identified so far:',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: AppColors.pillBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: widget.practiceCounts.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.display,
                                    style: TextStyle(
                                      fontSize: 20,
                                      color: AppColors.kanjiColor,
                                      fontFamily: AppFonts.japaneseFont,
                                      fontFamilyFallback: AppFonts.japaneseFallback,
                                    ),
                                  ),
                                  Text(
                                    '${item.count}×',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: const Text(
                        'Back to Home',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.muted,
                        side: BorderSide(color: AppColors.pillBg, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: const Text(
                        'Study More',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.pillBg),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
