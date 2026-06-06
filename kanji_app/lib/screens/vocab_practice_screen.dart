import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/progress_repository.dart';
import '../repositories/vocab_repository.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../utils/romaji_converter.dart';
import '../utils/vocab_answer_validator.dart';
import '../widgets/ruby_text.dart';
import '../widgets/scale_on_press.dart';

class VocabPracticeScreen extends ConsumerStatefulWidget {
  final List<VocabWord> words;
  final bool multipleChoice;
  final bool suppressFurigana;
  final bool reverseMode;

  const VocabPracticeScreen({
    super.key,
    required this.words,
    required this.multipleChoice,
    this.suppressFurigana = false,
    this.reverseMode = false,
  });

  @override
  ConsumerState<VocabPracticeScreen> createState() => _VocabPracticeScreenState();
}

class _VocabPracticeScreenState extends ConsumerState<VocabPracticeScreen> {
  List<VocabWord> _queue = [];
  int _currentIndex = 0;
  bool _loading = true;
  Set<String> _learnedKanji = {};

  // MC state
  List<String> _options = [];
  String? _selectedOption;

  // Keyboard state
  final _controller = TextEditingController();
  bool _showingFeedback = false;
  bool? _lastCorrect;
  Timer? _autoNextTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final learned = await progressRepo.getLearnedKanjiCharacters();
    if (!mounted) return;
    setState(() {
      _queue = widget.words;
      _learnedKanji = learned;
      _loading = false;
    });
    if (widget.multipleChoice && _queue.isNotEmpty) _buildOptions();
  }

  VocabWord get _current => _queue[_currentIndex];

  Future<void> _buildOptions() async {
    if (widget.reverseMode) {
      final distractors = await vocabRepo.getDistractors(
        jlptLevel: _current.jlptLevel,
        count: 3,
        excludeIds: [_current.id],
      );
      if (!mounted) return;
      final opts = [_current.reading, ...distractors.map((d) => d.reading)]..shuffle();
      setState(() => _options = opts);
    } else {
      final distractors = await vocabRepo.getDistractors(
        jlptLevel: _current.jlptLevel,
        count: 3,
        excludeIds: [_current.id],
      );
      if (!mounted) return;
      final opts = [_current.meanings, ...distractors.map((d) => d.meanings)]..shuffle();
      setState(() => _options = opts);
    }
  }

  bool _isCorrect(String input) {
    if (widget.reverseMode) {
      final converted = RomajiConverter.convert(input.trim().toLowerCase());
      return converted == _current.reading || input.trim() == _current.reading;
    }
    return VocabAnswerValidator.validate(input, _current.acceptableAnswers);
  }

  bool _isOptionCorrect(String option) {
    if (widget.reverseMode) return option == _current.reading;
    return option == _current.meanings;
  }

  void _handleMcSelect(String option) {
    if (_showingFeedback) return;
    final correct = _isOptionCorrect(option);
    setState(() {
      _selectedOption = option;
      _showingFeedback = true;
      _lastCorrect = correct;
    });
    if (correct) {
      soundService.playCorrect();
      _autoNextTimer = Timer(const Duration(seconds: 1), _next);
    } else {
      soundService.playWrong();
    }
  }

  void _handleKeyboardSubmit() {
    if (_showingFeedback) return;
    final input = _controller.text;
    final correct = _isCorrect(input);
    setState(() {
      _showingFeedback = true;
      _lastCorrect = correct;
    });
    if (correct) {
      soundService.playCorrect();
      _autoNextTimer = Timer(const Duration(seconds: 1), _next);
    } else {
      soundService.playWrong();
    }
  }

  void _next() {
    _autoNextTimer?.cancel();
    if (_currentIndex >= _queue.length - 1) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOption = null;
      _showingFeedback = false;
      _lastCorrect = null;
      _controller.clear();
    });
    if (widget.multipleChoice) _buildOptions();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vocabulary Practice')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vocabulary Practice')),
        body: Center(child: Text('No words to practice.',
          style: TextStyle(color: AppColors.muted))),
      );
    }

    final word = _current;
    final progress = '${_currentIndex + 1} / ${_queue.length}';
    final hintText = widget.reverseMode ? 'Type Japanese reading...' : 'Type English meaning...';
    final correctAnswer = widget.reverseMode ? word.reading : word.meanings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vocabulary Practice'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(progress,
              style: TextStyle(color: AppColors.muted, fontSize: 14))),
          ),
        ],
      ),
      body: Stack(children: [
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Column(children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: widget.reverseMode
                        ? Text(word.meanings,
                            style: TextStyle(fontSize: 36, color: AppColors.kanjiColor),
                            textAlign: TextAlign.center)
                        : word.word == word.reading
                            ? Text(word.word,
                                style: TextStyle(fontSize: 52, color: AppColors.kanjiColor),
                                textAlign: TextAlign.center)
                            : RubyText(
                                '{${word.word}|${word.reading}}',
                                fontSize: 52,
                                color: AppColors.kanjiColor,
                                showFurigana: !widget.suppressFurigana,
                                suppressedKanji: widget.suppressFurigana ? null : _learnedKanji,
                                centered: true,
                              ),
                  ),
                ),
              ),
              Divider(thickness: 1, color: AppColors.pillBg),
              const SizedBox(height: 8),
              if (widget.multipleChoice)
                _buildMcOptions()
              else
                _buildKeyboard(hintText),
              const SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: _showingFeedback && _lastCorrect != null
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: _lastCorrect!
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppColors.containerRadius),
                          border: Border.all(
                            color: _lastCorrect! ? Colors.green : Colors.red,
                          ),
                        ),
                        child: Row(children: [
                          Icon(
                            _lastCorrect! ? Icons.check_circle : Icons.cancel,
                            color: _lastCorrect! ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _lastCorrect! ? 'Correct!' : 'Incorrect — $correctAnswer',
                              style: TextStyle(
                                color: _lastCorrect! ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 6),
                      Text('Tap anywhere to continue',
                          style: TextStyle(fontSize: 13, color: AppColors.muted),
                          textAlign: TextAlign.center),
                    ])
                  : null,
              ),
              const SizedBox(height: 8),
            ]),
          ),
        ),
        if (_showingFeedback)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _autoNextTimer?.cancel();
                _next();
              },
            ),
          ),
      ]),
    );
  }

  Widget _buildMcOptions() {
    if (_options.isEmpty) return const CircularProgressIndicator();
    return Column(
      children: _options.map((opt) {
        Color? bg;
        if (_showingFeedback && _selectedOption == opt) {
          bg = _isOptionCorrect(opt) ? AppColors.correctBg : AppColors.incorrectBg;
        } else if (_showingFeedback && _isOptionCorrect(opt)) {
          bg = AppColors.correctBg;
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ScaleOnPress(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: bg ?? AppColors.btnBg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _showingFeedback ? null : () => _handleMcSelect(opt),
                child: Text(opt, textAlign: TextAlign.center),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKeyboard(String hintText) {
    return Column(children: [
      TextField(
        controller: _controller,
        enabled: !_showingFeedback,
        autofocus: true,
        textCapitalization: TextCapitalization.none,
        decoration: InputDecoration(
          hintText: hintText,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.buttonRadius),
            borderSide: BorderSide.none,
          ),
        ),
        style: TextStyle(color: AppColors.fg, fontSize: 16),
        onSubmitted: (_) => _handleKeyboardSubmit(),
      ),
      const SizedBox(height: 12),
      ScaleOnPress(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _showingFeedback ? null : _handleKeyboardSubmit,
            child: const Text('Submit'),
          ),
        ),
      ),
    ]);
  }
}
