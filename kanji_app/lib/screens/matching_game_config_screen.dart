import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/match_card.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/kana_repository.dart';
import '../repositories/vocab_repository.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/k_setup.dart';
import 'matching_game_screen.dart';

enum MatchContext { kanji, vocab, kana }

enum KanjiMatchMode { compoundReading, compoundMeaning, triple }

class MatchingGameConfigScreen extends ConsumerStatefulWidget {
  final MatchContext matchContext;
  final String? kanaType; // 'hiragana' | 'katakana'

  const MatchingGameConfigScreen({
    super.key,
    required this.matchContext,
    this.kanaType,
  });

  @override
  ConsumerState<MatchingGameConfigScreen> createState() => _MatchingGameConfigScreenState();
}

class _MatchingGameConfigScreenState extends ConsumerState<MatchingGameConfigScreen> {
  bool _loading = true;

  KanjiMatchMode _kanjiMode = KanjiMatchMode.compoundReading;
  List<VocabWord> _kanjiVocab = [];
  List<VocabWord> _vocabWords = [];
  List<KanaCharacter> _kanaChars = [];

  int _columns = 3;
  int _rows = 4;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    switch (widget.matchContext) {
      case MatchContext.kanji:
        final targeted = await kanjiRepo.getTargetKanjiList();
        final chars = targeted.map((k) => k.character).toSet();
        _kanjiVocab = await vocabRepo.getVocabContainingKanji(chars);
      case MatchContext.vocab:
        _vocabWords = await vocabRepo.getTargetVocab();
      case MatchContext.kana:
        _kanaChars = await kanaRepo.getTargeted(type: widget.kanaType);
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _setDefaultGrid();
    });
  }

  int get _availablePairs {
    switch (widget.matchContext) {
      case MatchContext.kanji:
        return _kanjiVocab.length;
      case MatchContext.vocab:
        return _vocabWords.length;
      case MatchContext.kana:
        return _kanaChars.length;
    }
  }

  bool get _isTriple =>
      widget.matchContext == MatchContext.kanji && _kanjiMode == KanjiMatchMode.triple;

  int get _groupSize => _isTriple ? 3 : 2;

  int get _groupsNeeded => (_columns * _rows) ~/ _groupSize;

  void _setDefaultGrid() {
    if (_isTriple) {
      _columns = 3;
      _rows = 5;
    } else {
      _columns = 3;
      _rows = 4;
    }
  }

  List<({int cols, int rows})> get _gridOptions {
    if (_isTriple) {
      return [(cols: 3, rows: 5), (cols: 3, rows: 6)];
    }
    return [(cols: 3, rows: 4), (cols: 4, rows: 4), (cols: 4, rows: 5)];
  }

  bool _gridEnabled(int cols, int rows) {
    final groups = (cols * rows) ~/ _groupSize;
    return _availablePairs >= groups;
  }

  List<MatchCard> _buildCards() {
    final rng = Random();
    switch (widget.matchContext) {
      case MatchContext.kanji:
        final pool = List.of(_kanjiVocab)..shuffle(rng);
        final selected = pool.take(_groupsNeeded).toList();
        final cards = <MatchCard>[];
        for (var i = 0; i < selected.length; i++) {
          final v = selected[i];
          final first = v.meanings.split(',').first.trim();
          cards.add(MatchCard(groupId: i, displayText: v.word, type: MatchCardType.compoundKanji));
          if (_kanjiMode == KanjiMatchMode.compoundReading ||
              _kanjiMode == KanjiMatchMode.triple) {
            cards.add(MatchCard(groupId: i, displayText: v.reading, type: MatchCardType.reading));
          }
          if (_kanjiMode == KanjiMatchMode.compoundMeaning ||
              _kanjiMode == KanjiMatchMode.triple) {
            cards.add(MatchCard(groupId: i, displayText: first, type: MatchCardType.meaning));
          }
        }
        return cards..shuffle(rng);

      case MatchContext.vocab:
        final pool = List.of(_vocabWords)..shuffle(rng);
        final selected = pool.take(_groupsNeeded).toList();
        final cards = <MatchCard>[];
        for (var i = 0; i < selected.length; i++) {
          final v = selected[i];
          final first = v.meanings.split(',').first.trim();
          cards.add(MatchCard(
            groupId: i,
            displayText: v.word,
            subText: v.reading,
            type: MatchCardType.japanese,
          ));
          cards.add(MatchCard(groupId: i, displayText: first, type: MatchCardType.english));
        }
        return cards..shuffle(rng);

      case MatchContext.kana:
        final pool = List.of(_kanaChars)..shuffle(rng);
        final selected = pool.take(_groupsNeeded).toList();
        final cards = <MatchCard>[];
        for (var i = 0; i < selected.length; i++) {
          final c = selected[i];
          cards.add(MatchCard(groupId: i, displayText: c.character, type: MatchCardType.kana));
          cards.add(MatchCard(groupId: i, displayText: c.romaji, type: MatchCardType.romaji));
        }
        return cards..shuffle(rng);
    }
  }

  void _launch() {
    if (!_gridEnabled(_columns, _rows)) return;
    final cards = _buildCards();
    Navigator.push(
      context,
      AppRoute.to(MatchingGameScreen(
        cards: cards,
        groupSize: _groupSize,
        columns: _columns,
      )),
    );
  }

  String get _title {
    switch (widget.matchContext) {
      case MatchContext.kanji:
        return 'Kanji Matching Game';
      case MatchContext.vocab:
        return 'Vocabulary Matching Game';
      case MatchContext.kana:
        return widget.kanaType == 'hiragana'
            ? 'Hiragana Matching Game'
            : 'Katakana Matching Game';
    }
  }

  String get _badge => switch (widget.matchContext) {
    MatchContext.kanji => '字',
    MatchContext.vocab => '語',
    MatchContext.kana => widget.kanaType == 'hiragana' ? 'ひ' : 'カ',
  };

  String get _availabilityLabel {
    final p = _availablePairs;
    final needed = _groupsNeeded;
    final unit = _isTriple ? 'triples' : 'pairs';
    return '$p $unit available'
        '${p < needed ? ' (need $needed for this grid)' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                KSetupHeader(badge: _badge, title: _title, colors: colors),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Kanji mode picker
                        if (widget.matchContext == MatchContext.kanji)
                          KSetupField(
                            label: 'Match mode',
                            child: KChoiceList(
                              options: const [
                                KChoiceItem(id: 'reading', label: 'Compound + Reading', icon: Icons.menu_book_rounded),
                                KChoiceItem(id: 'meaning', label: 'Compound + Meaning', icon: Icons.translate_rounded),
                                KChoiceItem(id: 'triple', label: 'Compound + Reading + Meaning', icon: Icons.auto_awesome_rounded),
                              ],
                              value: switch (_kanjiMode) {
                                KanjiMatchMode.compoundReading => 'reading',
                                KanjiMatchMode.compoundMeaning => 'meaning',
                                KanjiMatchMode.triple => 'triple',
                              },
                              onChanged: (v) => setState(() {
                                _kanjiMode = switch (v) {
                                  'reading' => KanjiMatchMode.compoundReading,
                                  'meaning' => KanjiMatchMode.compoundMeaning,
                                  _ => KanjiMatchMode.triple,
                                };
                                _setDefaultGrid();
                              }),
                              colors: colors,
                            ),
                          ),

                        // Grid size picker
                        KSetupField(
                          label: 'Grid size',
                          hint: _availabilityLabel,
                          child: Wrap(
                            spacing: 8,
                            children: _gridOptions.map((opt) {
                              final selected = _columns == opt.cols && _rows == opt.rows;
                              final enabled = _gridEnabled(opt.cols, opt.rows);
                              return GestureDetector(
                                onTap: enabled
                                    ? () => setState(() { _columns = opt.cols; _rows = opt.rows; })
                                    : null,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? colors.accent.withValues(alpha: 0.15)
                                        : colors.surface,
                                    borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                                    border: Border.all(
                                      color: selected
                                          ? colors.accent.withValues(alpha: 0.6)
                                          : KDesign.line(colors),
                                    ),
                                  ),
                                  child: Text(
                                    '${opt.cols}×${opt.rows}',
                                    style: TextStyle(
                                      color: enabled
                                          ? (selected ? colors.accent : colors.muted)
                                          : colors.muted.withValues(alpha: 0.4),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                KStickyFooter(
                  colors: colors,
                  child: KStartButton(
                    label: 'Start Matching Game',
                    colors: colors,
                    onTap: _launch,
                  ),
                ),
              ]),
      ),
    );
  }
}
