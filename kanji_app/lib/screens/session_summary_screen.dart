import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';

class SessionSummaryScreen extends ConsumerStatefulWidget {
  final int correct;
  final int total;
  final List<String> learnedChars;

  const SessionSummaryScreen({
    super.key,
    required this.correct,
    required this.total,
    required this.learnedChars,
  });

  @override
  ConsumerState<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends ConsumerState<SessionSummaryScreen> {
  @override
  void initState() {
    super.initState();
    soundService.playTestComplete();
  }

  @override
  Widget build(BuildContext context) {
    final anim = ref.watch(settingsProvider).animationsEnabled;
    final pct = widget.total == 0 ? 0 : (widget.correct / widget.total * 100).round();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Session Complete', style: TextStyle(color: AppColors.fg, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: widget.correct),
              duration: anim ? const Duration(milliseconds: 900) : Duration.zero,
              curve: Curves.easeOut,
              builder: (_, value, __) => Text(
                '$value / ${widget.total}',
                style: TextStyle(color: AppColors.accentBright, fontSize: 48, fontWeight: FontWeight.bold),
              ),
            ),
            Text('$pct% correct', style: TextStyle(color: AppColors.muted, fontSize: 14)),
            if (widget.learnedChars.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text('Learned this session:', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: widget.learnedChars.map((c) =>
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.pillBg, borderRadius: BorderRadius.circular(AppColors.containerRadius)),
                  child: Text(c, style: TextStyle(color: AppColors.kanjiColor, fontSize: 20)),
                )
              ).toList()),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: const Text('Back to Home'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
