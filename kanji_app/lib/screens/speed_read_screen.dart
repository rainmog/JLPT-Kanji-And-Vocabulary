import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/speed_read_question.dart';
import '../services/sound_service.dart';
import '../theme.dart';

enum _Phase { showing, answering, feedback, done }

class SpeedReadScreen extends StatefulWidget {
  final List<SpeedReadQuestion> questions;
  final double flashSeconds;

  const SpeedReadScreen({
    super.key,
    required this.questions,
    required this.flashSeconds,
  });

  static final List<({int correct, int total, String time})> history = [];

  @override
  State<SpeedReadScreen> createState() => _SpeedReadScreenState();
}

class _SpeedReadScreenState extends State<SpeedReadScreen> {
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
        backgroundColor: AppColors.bg,
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
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          automaticallyImplyLeading: false,
          title: Text(
            _phase == _Phase.done
                ? 'Complete!'
                : '${_index + 1} / ${_questions.length}',
            style: TextStyle(color: AppColors.fg, fontSize: 16),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.close, color: AppColors.fg),
              onPressed: () async {
                if (_phase == _Phase.done) { Navigator.pop(context); return; }
                _flashTimer?.cancel();
                final navigator = Navigator.of(context);
                final quit = await _confirmQuit();
                if (!mounted) return;
                if (quit) { navigator.pop(); return; }
                if (_phase == _Phase.showing || _phase == _Phase.answering) _startFlash();
              },
            ),
          ],
        ),
        body: SafeArea(
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
    final dimFontSize = question.display.length <= 2 ? 36.0 : 24.0;

    return Column(
      children: [
        // Flash card area
        Expanded(
          flex: 3,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: isShowing ? AppColors.fg : Colors.transparent,
                fontSize: displayFontSize,
                fontWeight: FontWeight.bold,
              ),
              child: Text(question.display, textAlign: TextAlign.center),
            ),
          ),
        ),

        // Countdown bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: isShowing ? flashProgress : 0,
              backgroundColor: AppColors.pillBg,
              color: AppColors.accent,
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // MC options
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 2.2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: question.options.map((opt) {
                Color bg = AppColors.btnBg;
                Color border = AppColors.pillBg;
                if (phase == _Phase.feedback) {
                  if (opt == question.correct) {
                    bg = Colors.green.withValues(alpha: 0.2);
                    border = Colors.green.withValues(alpha: 0.7);
                  } else if (opt == selected) {
                    bg = Colors.red.withValues(alpha: 0.15);
                    border = Colors.red.withValues(alpha: 0.7);
                  }
                }
                return GestureDetector(
                  onTap: phase == _Phase.answering ? () => onAnswer(opt) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                      border: Border.all(color: border, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        opt,
                        style: TextStyle(color: AppColors.fg, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.btnBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.pillBg),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Complete!',
              style: TextStyle(color: AppColors.fg, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Stat(label: 'Score', value: '$correct/$total'),
                const SizedBox(width: 32),
                _Stat(label: 'Accuracy', value: '$pct%'),
                const SizedBox(width: 32),
                _Stat(label: 'Time', value: timeString),
              ],
            ),

            if (previous.isNotEmpty) ...[
              const SizedBox(height: 20),
              Divider(color: AppColors.pillBg),
              const SizedBox(height: 12),
              Text('Previous games', style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 8),
              ...previous.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text('${e.correct}/${e.total}',
                          style: TextStyle(color: AppColors.fg, fontSize: 13),
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

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPlayAgain,
                child: const Text('Play Again'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.pillBg),
                onPressed: onBack,
                child: Text('Back', style: TextStyle(color: AppColors.muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value,
          style: TextStyle(color: AppColors.accent, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: AppColors.muted, fontSize: 11)),
    ]);
  }
}
