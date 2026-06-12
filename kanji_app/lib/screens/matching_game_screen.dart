import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_card.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../theme/app_theme_backgrounds.dart';
import '../theme_provider.dart';
import '../widgets/falling_blocks_overlay.dart';
import '../widgets/sakura_overlay.dart';
import '../widgets/snow_overlay.dart';
import '../widgets/space_age_overlay.dart';

class MatchingGameScreen extends ConsumerStatefulWidget {
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
  ConsumerState<MatchingGameScreen> createState() => _MatchingGameScreenState();
}

class _MatchingGameScreenState extends ConsumerState<MatchingGameScreen> {
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
        backgroundColor: AppColors.surface,
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
                      _timeString,
                      style: TextStyle(
                        color: AppColors.fg,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Turns: $_turns',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 14),
                        GestureDetector(
                          onTap: () async {
                            if (_gameComplete) {
                              Navigator.pop(context);
                              return;
                            }
                            final navigator = Navigator.of(context);
                            final quit = await _confirmQuit();
                            if (quit) navigator.pop();
                          },
                          child: Icon(Icons.close, size: 24, color: AppColors.fg),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Grid area
              Expanded(
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
            ],
          ),
        ),
        ]),
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
    if (matched) return AppColors.correctBg;
    if (wrong) return AppColors.incorrectBg;
    if (faceUp) return AppColors.accent.withValues(alpha: 0.13);
    return AppColors.surface;
  }

  Color _borderColor() {
    if (matched) return AppColors.correct;
    if (wrong) return AppColors.incorrect;
    if (faceUp) return AppColors.accent;
    return AppColors.pillBg;
  }

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: _bgColor(),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _borderColor(), width: 1.5),
      boxShadow: (matched || faceUp || wrong)
          ? null
          : [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.07),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
    );

    if (matched) {
      return Opacity(
        opacity: 0.55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: decoration,
          child: _matchedFace(),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: decoration,
        child: _face(),
      ),
    );
  }

  Widget _matchedFace() {
    return _buildCardText(AppColors.correct);
  }

  Widget _face() {
    if (!faceUp && !wrong) {
      return Center(
        child: Text(
          '?',
          style: TextStyle(
            color: AppColors.muted.withValues(alpha: 0.4),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return _cardContent();
  }

  Widget _buildCardText(Color textColor) {
    switch (card.type) {
      case MatchCardType.compoundKanji:
        return Center(
          child: Text(
            card.displayText,
            style: TextStyle(
              color: textColor,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              fontFamily: 'NotoSerifCJKjp',
            ),
            textAlign: TextAlign.center,
          ),
        );
      case MatchCardType.reading:
        return Center(
          child: Text(
            card.displayText,
            style: TextStyle(color: textColor, fontSize: 16),
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
              style: TextStyle(color: textColor, fontSize: 14),
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
              style: TextStyle(
                color: textColor,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                fontFamily: 'NotoSerifCJKjp',
              ),
              textAlign: TextAlign.center,
            ),
            if (card.subText != null)
              Text(
                card.subText!,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
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
            style: TextStyle(
              color: textColor,
              fontSize: 31,
              fontWeight: FontWeight.bold,
              fontFamily: 'NotoSerifCJKjp',
            ),
          ),
        );
      case MatchCardType.romaji:
        return Center(
          child: Text(
            card.displayText,
            style: TextStyle(color: textColor, fontSize: 16),
          ),
        );
    }
  }

  Widget _cardContent() {
    final textColor = wrong ? AppColors.incorrect : AppColors.fg;
    switch (card.type) {
      case MatchCardType.compoundKanji:
        return Center(
          child: Text(
            card.displayText,
            style: TextStyle(
              color: textColor,
              fontSize: 30,
              fontWeight: FontWeight.bold,
              fontFamily: 'NotoSerifCJKjp',
            ),
            textAlign: TextAlign.center,
          ),
        );
      case MatchCardType.reading:
        return Center(
          child: Text(
            card.displayText,
            style: TextStyle(color: textColor, fontSize: 16),
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
              style: TextStyle(color: textColor, fontSize: 14),
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
              style: TextStyle(
                color: textColor,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                fontFamily: 'NotoSerifCJKjp',
              ),
              textAlign: TextAlign.center,
            ),
            if (card.subText != null)
              Text(
                card.subText!,
                style: TextStyle(
                  color: wrong ? AppColors.incorrect.withValues(alpha: 0.7) : AppColors.muted,
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
            style: TextStyle(
              color: textColor,
              fontSize: 31,
              fontWeight: FontWeight.bold,
              fontFamily: 'NotoSerifCJKjp',
            ),
          ),
        );
      case MatchCardType.romaji:
        return Center(
          child: Text(
            card.displayText,
            style: TextStyle(color: textColor, fontSize: 16),
          ),
        );
    }
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatPill(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.fg,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
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
      color: AppColors.bg.withValues(alpha: 0.95),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Complete!',
                style: TextStyle(
                  color: AppColors.fg,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'All pairs matched',
                style: TextStyle(color: AppColors.muted, fontSize: 15),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StatPill(Icons.timer_outlined, timeString, AppColors.accent),
                  const SizedBox(width: 10),
                  _StatPill(Icons.repeat, '$turns turns', AppColors.muted),
                ],
              ),

              // History
              if (previous.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Previous games',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
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

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  onPressed: onPlayAgain,
                  child: const Text('Play Again'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onBack,
                  child: Text('Back', style: TextStyle(color: AppColors.muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
