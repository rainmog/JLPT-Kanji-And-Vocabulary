import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/speed_read_question.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../theme/app_theme_backgrounds.dart';
import '../theme_provider.dart';
import '../widgets/falling_blocks_overlay.dart';
import '../widgets/sakura_overlay.dart';
import '../widgets/snow_overlay.dart';
import '../widgets/space_age_overlay.dart';

enum _Phase { showing, answering, feedback, done }

class SpeedReadScreen extends ConsumerStatefulWidget {
  final List<SpeedReadQuestion> questions;
  final double flashSeconds;

  const SpeedReadScreen({
    super.key,
    required this.questions,
    required this.flashSeconds,
  });

  static final List<({int correct, int total, String time})> history = [];

  @override
  ConsumerState<SpeedReadScreen> createState() => _SpeedReadScreenState();
}

class _SpeedReadScreenState extends ConsumerState<SpeedReadScreen> {
  late List<SpeedReadQuestion> _questions;
  int _index = 0;
  _Phase _phase = _Phase.showing;
  String? _selected;
  int _correct = 0;
  double _flashProgress = 1.0;
  Timer? _flashTimer;
  final _stopwatch = Stopwatch();

  static const _tickInterval = Duration(milliseconds: 50);
  static const _feedbackDelay = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _questions = List.of(widget.questions);
    _stopwatch.start();
    _startFlash();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  SpeedReadQuestion get _current => _questions[_index];

  String _formatTime(int s) {
    final m = s ~/ 60;
    return '$m:${(s % 60).toString().padLeft(2, '0')}';
  }

  String get _timeString => _formatTime(_stopwatch.elapsed.inSeconds);

  void _startFlash() {
    _flashTimer?.cancel();
    _flashProgress = 1.0;
    _phase = _Phase.showing;
    _selected = null;
    final totalTicks =
        (widget.flashSeconds * 1000 / _tickInterval.inMilliseconds).round();
    int tick = 0;
    _flashTimer = Timer.periodic(_tickInterval, (t) {
      tick++;
      if (!mounted) { t.cancel(); return; }
      setState(() => _flashProgress = 1.0 - (tick / totalTicks).clamp(0.0, 1.0));
      if (tick >= totalTicks) {
        t.cancel();
        if (mounted) setState(() => _phase = _Phase.answering);
      }
    });
  }

  void _onAnswer(String answer) {
    if (_phase != _Phase.answering) return;
    final isCorrect = answer == _current.correct;
    if (isCorrect) {
      _correct++;
      soundService.playCorrect();
    } else {
      soundService.playWrong();
    }
    setState(() {
      _selected = answer;
      _phase = _Phase.feedback;
    });
    Future.delayed(_feedbackDelay, () {
      if (!mounted) return;
      final next = _index + 1;
      if (next >= _questions.length) {
        _stopwatch.stop();
        final entry = (correct: _correct, total: _questions.length, time: _timeString);
        SpeedReadScreen.history.insert(0, entry);
        if (SpeedReadScreen.history.length > 5) SpeedReadScreen.history.removeLast();
        setState(() => _phase = _Phase.done);
        soundService.playTestComplete();
      } else {
        setState(() => _index = next);
        _startFlash();
      }
    });
  }

  void _restart() {
    _flashTimer?.cancel();
    setState(() {
      _questions = List.of(widget.questions)..shuffle(Random());
      _index = 0;
      _correct = 0;
      _selected = null;
      _flashProgress = 1.0;
    });
    _stopwatch.reset();
    _stopwatch.start();
    _startFlash();
  }

  Future<bool> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Quit?', style: TextStyle(color: AppColors.fg)),
        content: Text('Progress will be lost.', style: TextStyle(color: AppColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Quit', style: TextStyle(color: AppColors.muted)),
          ),
        ],
      ),
    );
    return quit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase == _Phase.done,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        _flashTimer?.cancel();
        final navigator = Navigator.of(context);
        final quit = await _confirmQuit();
        if (!mounted) return;
        if (quit) { navigator.pop(); return; }
        if (_phase == _Phase.showing || _phase == _Phase.answering) _startFlash();
      },
      child: Scaffold(
        backgroundColor: const {
          AppTheme.galaxy, AppTheme.loveLetter,
          AppTheme.lily, AppTheme.totoro, AppTheme.midnightCity,
        }.contains(ref.watch(themeNotifier)) ? Colors.transparent : AppColors.bg,
        body: Stack(children: [
          const Positioned.fill(child: HomeBgLayer()),
          const Positioned.fill(child: SakuraPetalsOverlay()),
          const Positioned.fill(child: SpaceAgeStarsOverlay()),
          const Positioned.fill(child: SnowOverlay()),
          const Positioned.fill(child: FallingBlocksOverlay()),
          SafeArea(
          child: Column(
            children: [
              // Custom header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _phase == _Phase.done
                          ? 'Complete!'
                          : '${_index + 1} / ${_questions.length}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.fg,
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        if (_phase == _Phase.done) { Navigator.pop(context); return; }
                        _flashTimer?.cancel();
                        final navigator = Navigator.of(context);
                        final quit = await _confirmQuit();
                        if (!mounted) return;
                        if (quit) { navigator.pop(); return; }
                        if (_phase == _Phase.showing || _phase == _Phase.answering) _startFlash();
                      },
                      child: Icon(Icons.close, size: 24, color: AppColors.fg),
                    ),
                  ],
                ),
              ),
              // Body content
              Expanded(
                child: _phase == _Phase.done
                    ? _ResultOverlay(
                        correct: _correct,
                        total: _questions.length,
                        timeString: _timeString,
                        history: SpeedReadScreen.history,
                        onPlayAgain: _restart,
                        onBack: () => Navigator.pop(context),
                      )
                    : _GameBody(
                        question: _current,
                        phase: _phase,
                        flashProgress: _flashProgress,
                        selected: _selected,
                        onAnswer: _onAnswer,
                      ),
              ),
            ],
          ),
        ),
        ]),
      ),
    );
  }
}

class _GameBody extends StatelessWidget {
  final SpeedReadQuestion question;
  final _Phase phase;
  final double flashProgress;
  final String? selected;
  final void Function(String) onAnswer;

  const _GameBody({
    required this.question,
    required this.phase,
    required this.flashProgress,
    required this.selected,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final isShowing = phase == _Phase.showing;
    final displayFontSize = question.display.length <= 2 ? 72.0 : 48.0;

    return Column(
      children: [
        // Flash card area — completely invisible when not showing
        Expanded(
          child: Center(
            child: AnimatedOpacity(
              opacity: isShowing ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: Text(
                question.display,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.fg,
                  fontSize: displayFontSize,
                  fontWeight: FontWeight.w700,
                  fontFamily: AppFonts.japaneseFont,
                  fontFamilyFallback: AppFonts.japaneseFallback,
                ),
              ),
            ),
          ),
        ),

        // Countdown bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: isShowing ? flashProgress : 0,
              minHeight: 5,
              backgroundColor: AppColors.pillBg,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // MC options pinned towards bottom
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _OptionButton(
                    opt: question.options[0],
                    correct: question.correct,
                    selected: selected,
                    phase: phase,
                    onAnswer: onAnswer,
                  ),
                  const SizedBox(width: 10),
                  _OptionButton(
                    opt: question.options[1],
                    correct: question.correct,
                    selected: selected,
                    phase: phase,
                    onAnswer: onAnswer,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _OptionButton(
                    opt: question.options[2],
                    correct: question.correct,
                    selected: selected,
                    phase: phase,
                    onAnswer: onAnswer,
                  ),
                  const SizedBox(width: 10),
                  _OptionButton(
                    opt: question.options[3],
                    correct: question.correct,
                    selected: selected,
                    phase: phase,
                    onAnswer: onAnswer,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String opt;
  final String correct;
  final String? selected;
  final _Phase phase;
  final void Function(String) onAnswer;

  const _OptionButton({
    required this.opt,
    required this.correct,
    required this.selected,
    required this.phase,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = AppColors.surface;
    Color border = AppColors.pillBg;
    Color textColor = AppColors.fg;

    if (phase == _Phase.feedback) {
      if (opt == correct) {
        bg = AppColors.correct;
        border = AppColors.correct;
        textColor = Colors.white;
      } else if (opt == selected) {
        bg = AppColors.incorrect;
        border = AppColors.incorrect;
        textColor = Colors.white;
      } else {
        // dim non-selected, non-correct options
        textColor = AppColors.muted.withValues(alpha: 0.5);
      }
    }

    return Expanded(
      child: GestureDetector(
        onTap: phase == _Phase.answering ? () => onAnswer(opt) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 80,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Center(
            child: Text(
              opt,
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFamily: AppFonts.japaneseFont,
                fontFamilyFallback: AppFonts.japaneseFallback,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  final int correct;
  final int total;
  final String timeString;
  final List<({int correct, int total, String time})> history;
  final VoidCallback onPlayAgain;
  final VoidCallback onBack;

  const _ResultOverlay({
    required this.correct,
    required this.total,
    required this.timeString,
    required this.history,
    required this.onPlayAgain,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final previous = history.length > 1 ? history.sublist(1) : <({int correct, int total, String time})>[];
    final pct = total > 0 ? (correct * 100 / total).round() : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(
            'Complete!',
            style: TextStyle(
              color: AppColors.fg,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$correct/$total',
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 48,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$pct% correct',
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
          const SizedBox(height: 20),
          // Stat pills row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatPill(label: 'Score', value: '$correct/$total'),
              const SizedBox(width: 10),
              _StatPill(label: 'Accuracy', value: '$pct%'),
              const SizedBox(width: 10),
              _StatPill(label: 'Time', value: timeString),
            ],
          ),

          if (previous.isNotEmpty) ...[
            const SizedBox(height: 24),
            Divider(color: AppColors.pillBg),
            const SizedBox(height: 10),
            Text(
              'Previous games',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            ...previous.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50,
                    child: Text('${e.correct}/${e.total}',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                        textAlign: TextAlign.right),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 40,
                    child: Text(e.time,
                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
                ],
              ),
            )),
          ],

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              onPressed: onPlayAgain,
              child: const Text(
                'Play Again',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onBack,
              child: Text(
                'Back',
                style: TextStyle(color: AppColors.muted, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.pillBg, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: AppColors.accent,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
