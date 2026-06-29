import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/speed_read_question.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/kana_repository.dart';
import '../repositories/vocab_repository.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/k_setup.dart';
import 'speed_read_screen.dart';

enum SpeedReadContext { kanji, kana }

class SpeedReadConfigScreen extends ConsumerStatefulWidget {
  final SpeedReadContext speedContext;
  final String? kanaType; // 'hiragana' | 'katakana'

  const SpeedReadConfigScreen({
    super.key,
    required this.speedContext,
    this.kanaType,
  });

  @override
  ConsumerState<SpeedReadConfigScreen> createState() => _SpeedReadConfigScreenState();
}

class _SpeedReadConfigScreenState extends ConsumerState<SpeedReadConfigScreen> {
  bool _loading = true;

  // Raw data
  List<VocabWord> _kanjiVocab = [];
  List<KanaCharacter> _kanaChars = [];

  // Config
  double _flashSeconds = 0.3;
  int _questionCount = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    switch (widget.speedContext) {
      case SpeedReadContext.kanji:
        final targeted = await kanjiRepo.getTargetKanjiList();
        final chars = targeted.map((k) => k.character).toSet();
        _kanjiVocab = await vocabRepo.getVocabContainingKanji(chars);
      case SpeedReadContext.kana:
        _kanaChars = await kanaRepo.getTargeted(type: widget.kanaType);
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  int get _available {
    switch (widget.speedContext) {
      case SpeedReadContext.kanji: return _kanjiVocab.length;
      case SpeedReadContext.kana: return _kanaChars.length;
    }
  }

  int get _effectiveCount => _questionCount.clamp(1, _available);

  List<SpeedReadQuestion> _buildQuestions() {
    final rng = Random();
    switch (widget.speedContext) {
      case SpeedReadContext.kanji:
        final pool = List.of(_kanjiVocab)..shuffle(rng);
        final selected = pool.take(_effectiveCount).toList();
        final allReadings = pool.map((v) => v.reading).toSet().toList();
        return selected.map((v) {
          final wrong = (List.of(allReadings)..shuffle(rng))
              .where((r) => r != v.reading)
              .take(3)
              .toList();
          final opts = [v.reading, ...wrong]..shuffle(rng);
          final meanings = v.meanings
              .split(RegExp(r'[;,]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .take(2)
              .join(', ');
          return SpeedReadQuestion(
            display: v.word,
            correct: v.reading,
            options: opts,
            meaning: meanings.isEmpty ? null : meanings,
          );
        }).toList();

      case SpeedReadContext.kana:
        final pool = List.of(_kanaChars)..shuffle(rng);
        final selected = pool.take(_effectiveCount).toList();
        final allRomaji = pool.map((c) => c.romaji).toSet().toList();
        return selected.map((c) {
          final wrong = (List.of(allRomaji)..shuffle(rng))
              .where((r) => r != c.romaji)
              .take(3)
              .toList();
          // Pad if not enough distractors
          while (wrong.length < 3) { wrong.add('—'); }
          final opts = [c.romaji, ...wrong]..shuffle(rng);
          return SpeedReadQuestion(display: c.character, correct: c.romaji, options: opts);
        }).toList();
    }
  }

  void _launch() {
    if (_available == 0) return;
    final questions = _buildQuestions();
    Navigator.push(context, AppRoute.to(SpeedReadScreen(
      questions: questions,
      flashSeconds: _flashSeconds,
    )));
  }

  String get _title {
    switch (widget.speedContext) {
      case SpeedReadContext.kanji: return 'Kanji Speed Reading';
      case SpeedReadContext.kana:
        return widget.kanaType == 'hiragana'
            ? 'Hiragana Speed Reading'
            : 'Katakana Speed Reading';
    }
  }

  String get _badge => switch (widget.speedContext) {
    SpeedReadContext.kanji => '字',
    SpeedReadContext.kana => widget.kanaType == 'hiragana' ? 'ひ' : 'カ',
  };

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(children: [
          KSetupHeader(badge: _badge, title: _title, colors: colors),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KSetupField(
                          label: 'Difficulty',
                          child: KChoiceList(
                            options: const [
                              KChoiceItem(id: '0.3',  label: 'Easy',   sub: '0.3s per card'),
                              KChoiceItem(id: '0.2',  label: 'Medium', sub: '0.2s per card'),
                              KChoiceItem(id: '0.1',  label: 'Hard',   sub: '0.1s per card'),
                              KChoiceItem(id: '0.05', label: 'Strobe', sub: '0.05s per card'),
                            ],
                            value: _flashSeconds.toString(),
                            onChanged: (v) => setState(() => _flashSeconds = double.parse(v)),
                            colors: colors,
                          ),
                        ),
                        KSetupField(
                          label: 'Questions',
                          hint: '$_available available${_available < _questionCount ? ' — will use $_effectiveCount' : ''}',
                          child: KCountChips(
                            options: const [10, 20, 30],
                            value: _questionCount,
                            onChanged: (v) => setState(() => _questionCount = v),
                            colors: colors,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          KStickyFooter(
            colors: colors,
            child: KStartButton(
              label: 'Start Speed Reading',
              colors: colors,
              onTap: _launch,
            ),
          ),
        ]),
      ),
    );
  }
}
