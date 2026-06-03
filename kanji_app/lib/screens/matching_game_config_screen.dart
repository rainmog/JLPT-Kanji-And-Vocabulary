import 'dart:math';
import 'package:flutter/material.dart';
import '../models/match_card.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/kana_repository.dart';
import '../repositories/vocab_repository.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import '../widgets/scale_on_press.dart';
import 'matching_game_screen.dart';

enum MatchContext { kanji, vocab, kana }

enum KanjiMatchMode { compoundReading, compoundMeaning, triple }

class MatchingGameConfigScreen extends StatefulWidget {
  final MatchContext matchContext;
  final String? kanaType; // 'hiragana' | 'katakana'

  const MatchingGameConfigScreen({
    super.key,
    required this.matchContext,
    this.kanaType,
  });

  @override
  State<MatchingGameConfigScreen> createState() => _MatchingGameConfigScreenState();
}

class _MatchingGameConfigScreenState extends State<MatchingGameConfigScreen> {
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

  String get _availabilityLabel {
    final p = _availablePairs;
    final needed = _groupsNeeded;
    final unit = _isTriple ? 'triples' : 'pairs';
    return '$p $unit available'
        '${p < needed ? ' (need $needed for this grid)' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(_title, style: TextStyle(color: AppColors.fg)),
        iconTheme: IconThemeData(color: AppColors.fg),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kanji mode picker
                  if (widget.matchContext == MatchContext.kanji) ...[
                    Text(
                      'Match mode',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.fg),
                    ),
                    const SizedBox(height: 12),
                    ...[
                      (KanjiMatchMode.compoundReading, 'Compound + Reading'),
                      (KanjiMatchMode.compoundMeaning, 'Compound + Meaning'),
                      (KanjiMatchMode.triple, 'Compound + Reading + Meaning'),
                    ].map(((KanjiMatchMode, String) entry) {
                      final (mode, label) = entry;
                      final selected = _kanjiMode == mode;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ScaleOnPress(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _kanjiMode = mode;
                              _setDefaultGrid();
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.accent.withValues(alpha: 0.15)
                                    : AppColors.btnBg,
                                borderRadius:
                                    BorderRadius.circular(AppColors.buttonRadius),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.accent.withValues(alpha: 0.6)
                                      : AppColors.pillBg,
                                ),
                              ),
                              child: Row(children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_unchecked,
                                  color:
                                      selected ? AppColors.accent : AppColors.muted,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: selected ? AppColors.fg : AppColors.muted,
                                    fontSize: 14,
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],

                  // Grid size picker
                  Text(
                    'Grid size',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.fg),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _gridOptions.map((opt) {
                      final selected = _columns == opt.cols && _rows == opt.rows;
                      final enabled = _gridEnabled(opt.cols, opt.rows);
                      return ScaleOnPress(
                        child: GestureDetector(
                          onTap: enabled
                              ? () => setState(
                                  () { _columns = opt.cols; _rows = opt.rows; })
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.accent.withValues(alpha: 0.15)
                                  : AppColors.btnBg,
                              borderRadius:
                                  BorderRadius.circular(AppColors.buttonRadius),
                              border: Border.all(
                                color: selected
                                    ? AppColors.accent.withValues(alpha: 0.6)
                                    : AppColors.pillBg,
                              ),
                            ),
                            child: Text(
                              '${opt.cols}×${opt.rows}',
                              style: TextStyle(
                                color: enabled
                                    ? (selected
                                        ? AppColors.accent
                                        : AppColors.muted)
                                    : AppColors.muted.withValues(alpha: 0.4),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _availabilityLabel,
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 32),

                  // Launch button
                  ScaleOnPress(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _gridEnabled(_columns, _rows) ? _launch : null,
                        child: const Text('Start Matching Game'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
