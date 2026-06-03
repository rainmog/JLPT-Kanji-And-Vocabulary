import 'dart:math';
import 'package:flutter/material.dart';
import '../models/speed_read_question.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/kana_repository.dart';
import '../repositories/vocab_repository.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import '../widgets/scale_on_press.dart';
import 'speed_read_screen.dart';

enum SpeedReadContext { kanji, kana }

class SpeedReadConfigScreen extends StatefulWidget {
  final SpeedReadContext speedContext;
  final String? kanaType; // 'hiragana' | 'katakana'

  const SpeedReadConfigScreen({
    super.key,
    required this.speedContext,
    this.kanaType,
  });

  @override
  State<SpeedReadConfigScreen> createState() => _SpeedReadConfigScreenState();
}

class _SpeedReadConfigScreenState extends State<SpeedReadConfigScreen> {
  bool _loading = true;

  // Raw data
  List<VocabWord> _kanjiVocab = [];
  List<KanaCharacter> _kanaChars = [];

  // Config
  double _flashSeconds = 2.0;
  int _questionCount = 20;

  static const _difficulties = [
    (label: 'Easy', seconds: 3.0),
    (label: 'Normal', seconds: 2.0),
    (label: 'Hard', seconds: 1.0),
    (label: 'Strobe', seconds: 0.1),
  ];

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
          return SpeedReadQuestion(display: v.word, correct: v.reading, options: opts);
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
                  // Difficulty
                  Text('Difficulty',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
                  const SizedBox(height: 12),
                  ..._difficulties.map((d) {
                    final selected = _flashSeconds == d.seconds;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ScaleOnPress(
                        child: GestureDetector(
                          onTap: () => setState(() => _flashSeconds = d.seconds),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.accent.withValues(alpha: 0.15)
                                  : AppColors.btnBg,
                              borderRadius: BorderRadius.circular(AppColors.buttonRadius),
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
                                color: selected ? AppColors.accent : AppColors.muted,
                                size: 18,
                              ),
                              const SizedBox(width: 12),
                              Text(d.label,
                                  style: TextStyle(
                                      color: selected ? AppColors.fg : AppColors.muted,
                                      fontSize: 14)),
                              const Spacer(),
                              Text('${d.seconds < 1 ? d.seconds.toStringAsFixed(1) : d.seconds.toStringAsFixed(0)}s',
                                  style: TextStyle(color: AppColors.muted, fontSize: 13)),
                            ]),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // Question count
                  Text('Questions',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [10, 20, 30].map((n) {
                      final selected = _questionCount == n;
                      final available = _available >= n;
                      return ScaleOnPress(
                        child: GestureDetector(
                          onTap: available ? () => setState(() => _questionCount = n) : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.accent.withValues(alpha: 0.15)
                                  : AppColors.btnBg,
                              borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                              border: Border.all(
                                color: selected
                                    ? AppColors.accent.withValues(alpha: 0.6)
                                    : AppColors.pillBg,
                              ),
                            ),
                            child: Text(
                              '$n',
                              style: TextStyle(
                                color: available
                                    ? (selected ? AppColors.accent : AppColors.muted)
                                    : AppColors.muted.withValues(alpha: 0.4),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_available available'
                    '${_available < _questionCount ? ' — will use $_available' : ''}',
                    style: TextStyle(color: AppColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 32),

                  ScaleOnPress(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _available > 0 ? _launch : null,
                        child: const Text('Start Speed Reading'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
