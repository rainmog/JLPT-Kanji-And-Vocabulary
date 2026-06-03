import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/match_card.dart';
import '../services/sound_service.dart';
import '../theme.dart';

class MatchingGameScreen extends StatefulWidget {
  final List<MatchCard> cards;
  final int groupSize;
  final int columns;

  const MatchingGameScreen({
    super.key,
    required this.cards,
    required this.groupSize,
    required this.columns,
  });

  // Session-lifetime history; persists across Play Again
  static final List<({String time, int turns})> history = [];

  @override
  State<MatchingGameScreen> createState() => _MatchingGameScreenState();
}

class _MatchingGameScreenState extends State<MatchingGameScreen> {
  late List<MatchCard> _cards;
  late List<bool> _faceUp;
  late List<bool> _matched;
  late List<bool> _wrong;
  late List<int> _selected;
  late int _turns;
  late bool _started;
  late bool _gameComplete;
  final _stopwatch = Stopwatch();
  Timer? _displayTimer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _initState(widget.cards);
  }

  void _initState(List<MatchCard> cards) {
    _cards = List.of(cards);
    final n = _cards.length;
    _faceUp = List.filled(n, false);
    _matched = List.filled(n, false);
    _wrong = List.filled(n, false);
    _selected = [];
    _turns = 0;
    _started = false;
    _gameComplete = false;
    _stopwatch.reset();
    _displayTimer?.cancel();
    _displayTimer = null;
    _checking = false;
  }

  @override
  void dispose() {
    _displayTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  String get _timeString {
    final s = _stopwatch.elapsed.inSeconds;
    final m = s ~/ 60;
    return '$m:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _onCardTap(int index) {
    if (_checking) return;
    if (_matched[index] || _faceUp[index] || _wrong[index]) return;
    if (_selected.length >= widget.groupSize) return;

    if (!_started) {
      _started = true;
      _stopwatch.start();
      _displayTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }

    setState(() {
      _faceUp[index] = true;
      _selected.add(index);
    });

    if (_selected.length == widget.groupSize) {
      _checkMatch();
    }
  }

  Future<void> _checkMatch() async {
    _checking = true;
    _turns++;
    final groupId = _cards[_selected[0]].groupId;
    final isMatch = _selected.every((i) => _cards[i].groupId == groupId);

    if (isMatch) {
      soundService.playCorrect();
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        for (final i in _selected) {
          _matched[i] = true;
          _faceUp[i] = false;
        }
        _selected.clear();
      });
      if (_matched.every((m) => m)) {
        _stopwatch.stop();
        _displayTimer?.cancel();
        final entry = (time: _timeString, turns: _turns);
        MatchingGameScreen.history.insert(0, entry);
        if (MatchingGameScreen.history.length > 5) MatchingGameScreen.history.removeLast();
        setState(() => _gameComplete = true);
        soundService.playTestComplete();
      }
    } else {
      soundService.playWrong();
      setState(() {
        for (final i in _selected) { _wrong[i] = true; }
      });
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      setState(() {
        for (final i in _selected) {
          _wrong[i] = false;
          _faceUp[i] = false;
        }
        _selected.clear();
      });
    }
    _checking = false;
  }

  Future<bool> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bg,
        title: Text('Quit game?', style: TextStyle(color: AppColors.fg)),
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

  void _playAgain() {
    final shuffled = List.of(widget.cards)..shuffle(Random());
    setState(() => _initState(shuffled));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _gameComplete,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final quit = await _confirmQuit();
        if (quit) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_timeString, style: TextStyle(color: AppColors.fg, fontSize: 16)),
              Text('Turns: $_turns', style: TextStyle(color: AppColors.muted, fontSize: 14)),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.close, color: AppColors.fg),
              onPressed: () async {
                if (_gameComplete) {
                  Navigator.pop(context);
                  return;
                }
                final navigator = Navigator.of(context);
                final quit = await _confirmQuit();
                if (quit) navigator.pop();
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(builder: (ctx, constraints) => _buildGrid(constraints)),
              if (_gameComplete)
                _ResultOverlay(
                  timeString: _timeString,
                  turns: _turns,
                  history: MatchingGameScreen.history,
                  onPlayAgain: _playAgain,
                  onBack: () => Navigator.pop(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BoxConstraints constraints) {
    final cols = widget.columns;
    final rows = (_cards.length / cols).ceil();
    const gap = 6.0;
    const hPadding = 16.0;
    const vPadding = 24.0;
    final availW = constraints.maxWidth - hPadding * 2;
    final availH = constraints.maxHeight - vPadding * 2;
    final cardW = (availW - gap * (cols - 1)) / cols;
    final cardH = (availH - gap * (rows - 1)) / rows;
    final cardSize = min(cardW, cardH);
    final gridW = cardSize * cols + gap * (cols - 1);
    final gridH = cardSize * rows + gap * (rows - 1);

    return Center(
      child: SizedBox(
        width: gridW,
        height: gridH,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
          ),
          itemCount: _cards.length,
          itemBuilder: (_, i) => _CardTile(
            card: _cards[i],
            faceUp: _faceUp[i],
            matched: _matched[i],
            wrong: _wrong[i],
            onTap: () => _onCardTap(i),
          ),
        ),
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  final MatchCard card;
  final bool faceUp;
  final bool matched;
  final bool wrong;
  final VoidCallback onTap;

  const _CardTile({
    required this.card,
    required this.faceUp,
    required this.matched,
    required this.wrong,
    required this.onTap,
  });

  Color _bgColor() {
    if (matched) return Colors.transparent;
    if (wrong) return Colors.red.withValues(alpha: 0.15);
    if (faceUp) return AppColors.accent.withValues(alpha: 0.15);
    return AppColors.btnBg;
  }

  Color _borderColor() {
    if (matched) return AppColors.pillBg.withValues(alpha: 0.3);
    if (wrong) return Colors.red.withValues(alpha: 0.7);
    if (faceUp) return AppColors.accent.withValues(alpha: 0.7);
    return AppColors.pillBg;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: matched ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: _bgColor(),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _borderColor(), width: matched ? 1.5 : 2),
        ),
        child: matched ? const SizedBox.shrink() : _face(),
      ),
    );
  }

  Widget _face() {
    if (!faceUp && !wrong) {
      return Center(
        child: Text(
          '?',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 25,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return _cardContent();
  }

  Widget _cardContent() {
    final textColor = wrong ? Colors.red.shade300 : AppColors.fg;
    switch (card.type) {
      case MatchCardType.compoundKanji:
        return Center(
          child: Text(
            card.displayText,
            style: TextStyle(color: textColor, fontSize: 23, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        );
      case MatchCardType.reading:
        return Center(
          child: Text(
            card.displayText,
            style: TextStyle(color: textColor, fontSize: 19),
            textAlign: TextAlign.center,
          ),
        );
      case MatchCardType.meaning:
      case MatchCardType.english:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              card.displayText,
              style: TextStyle(color: textColor, fontSize: 16),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 3,
            ),
          ),
        );
      case MatchCardType.japanese:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.displayText,
              style: TextStyle(color: textColor, fontSize: 21, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (card.subText != null)
              Text(
                card.subText!,
                style: TextStyle(
                  color: wrong ? Colors.red.shade200 : AppColors.muted,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
          ],
        );
      case MatchCardType.kana:
        return Center(
          child: Text(
            card.displayText,
            style: TextStyle(color: textColor, fontSize: 31, fontWeight: FontWeight.bold),
          ),
        );
      case MatchCardType.romaji:
        return Center(
          child: Text(
            card.displayText,
            style: TextStyle(color: textColor, fontSize: 23),
          ),
        );
    }
  }
}

class _ResultOverlay extends StatelessWidget {
  final String timeString;
  final int turns;
  final List<({String time, int turns})> history;
  final VoidCallback onPlayAgain;
  final VoidCallback onBack;

  const _ResultOverlay({
    required this.timeString,
    required this.turns,
    required this.history,
    required this.onPlayAgain,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    // history[0] is the just-completed game; previous = history[1..5]
    final previous = history.length > 1 ? history.sublist(1) : <({String time, int turns})>[];

    return Container(
      color: AppColors.bg.withValues(alpha: 0.92),
      child: Center(
        child: SingleChildScrollView(
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
                  style: TextStyle(
                    color: AppColors.fg,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All pairs matched',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Stat(label: 'Time', value: timeString),
                    const SizedBox(width: 40),
                    _Stat(label: 'Turns', value: '$turns'),
                  ],
                ),

                // History
                if (previous.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Divider(color: AppColors.pillBg),
                  const SizedBox(height: 12),
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
                          width: 60,
                          child: Text(
                            e.time,
                            style: TextStyle(color: AppColors.fg, fontSize: 13),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 60,
                          child: Text(
                            '${e.turns} turns',
                            style: TextStyle(color: AppColors.muted, fontSize: 13),
                          ),
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
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: AppColors.accent,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }
}
