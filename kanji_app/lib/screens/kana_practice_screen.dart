import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../repositories/kana_repository.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../widgets/scale_on_press.dart';

enum KanaQuizType {
  kanaToRomajiMC,
  romajiToKanaMC,
  kanaToRomajiType,
  wordToRomajiType,
  hiraToKataMC,
  kataToHiraMC,
}

class _KanaQuestion {
  final KanaCharacter? char;   // null for word questions
  final KanaWord? word;        // null for char questions
  final KanaQuizType type;

  const _KanaQuestion({this.char, this.word, required this.type});
}

class KanaPracticeScreen extends StatefulWidget {
  final List<KanaCharacter> chars;
  final List<KanaCharacter> allChars;
  final List<KanaWord> words;
  final KanaQuizType quizType;
  final int count;
  final bool testMode;

  const KanaPracticeScreen({
    super.key,
    required this.chars,
    required this.allChars,
    required this.words,
    required this.quizType,
    required this.count,
    required this.testMode,
  });

  @override
  State<KanaPracticeScreen> createState() => _KanaPracticeScreenState();
}

class _KanaPracticeScreenState extends State<KanaPracticeScreen> {
  final _rng = Random();
  List<_KanaQuestion> _queue = [];
  int _currentIndex = 0;
  int _correct = 0;

  List<String> _options = [];
  String? _selectedOption;
  final _controller = TextEditingController();
  bool _showingFeedback = false;
  bool? _lastCorrect;
  Timer? _autoNextTimer;

  @override
  void initState() {
    super.initState();
    _buildQueue();
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _buildQueue() {
    List<_KanaQuestion> pool;

    if (widget.testMode) {
      // Fixed format: 1 kana→romaji MC + 1 romaji→kana MC per targeted char
      pool = [];
      for (final ch in widget.chars) {
        pool.add(_KanaQuestion(char: ch, type: KanaQuizType.kanaToRomajiMC));
        pool.add(_KanaQuestion(char: ch, type: KanaQuizType.romajiToKanaMC));
      }
      pool.shuffle(_rng);
    } else {
      final qt = widget.quizType;
      final isWord = qt == KanaQuizType.wordToRomajiType;
      final isHiraKata = qt == KanaQuizType.hiraToKataMC || qt == KanaQuizType.kataToHiraMC;

      if (isWord) {
        pool = widget.words.map((w) => _KanaQuestion(word: w, type: qt)).toList();
      } else if (isHiraKata) {
        final source = widget.allChars
          .where((c) => c.type == 'hiragana' && c.counterpart != null)
          .toList();
        pool = source.map((c) => _KanaQuestion(
          char: c,
          type: _rng.nextBool() ? KanaQuizType.hiraToKataMC : KanaQuizType.kataToHiraMC,
        )).toList();
      } else {
        pool = widget.chars.map((c) => _KanaQuestion(char: c, type: qt)).toList();
      }

      pool.shuffle(_rng);
      pool = pool.take(widget.count).toList();
    }

    _queue = pool;
    if (_queue.isEmpty) return;
    _prepareQuestion();
    setState(() {});
  }

  _KanaQuestion get _current => _queue[_currentIndex];

  void _prepareQuestion() {
    final q = _current;
    if (_isMC(q.type)) _buildOptions(q);
  }

  bool _isMC(KanaQuizType t) => t == KanaQuizType.kanaToRomajiMC ||
      t == KanaQuizType.romajiToKanaMC ||
      t == KanaQuizType.hiraToKataMC ||
      t == KanaQuizType.kataToHiraMC;

  void _buildOptions(_KanaQuestion q) {
    final correct = _correctAnswer(q);
    final pool = _distractorPool(q);
    pool.shuffle(_rng);
    final distractors = pool.where((d) => d != correct).take(3).toList();
    final opts = [correct, ...distractors]..shuffle(_rng);
    setState(() => _options = opts);
  }

  String _correctAnswer(_KanaQuestion q) {
    switch (q.type) {
      case KanaQuizType.kanaToRomajiMC:
      case KanaQuizType.kanaToRomajiType:
      case KanaQuizType.wordToRomajiType:
        return q.char?.romaji ?? q.word?.romaji ?? '';
      case KanaQuizType.romajiToKanaMC:
        return q.char!.character;
      case KanaQuizType.hiraToKataMC:
        return q.char!.counterpart!; // show hiragana → pick katakana
      case KanaQuizType.kataToHiraMC:
        return q.char!.character; // show katakana counterpart → pick hiragana
    }
  }

  List<String> _distractorPool(_KanaQuestion q) {
    switch (q.type) {
      case KanaQuizType.kanaToRomajiMC:
        // Prefer same row, else all
        final sameRow = widget.allChars
          .where((c) => c.type == q.char!.type && c.id != q.char!.id && c.row == q.char!.row)
          .map((c) => c.romaji).toList();
        if (sameRow.length >= 3) return sameRow;
        return widget.allChars
          .where((c) => c.type == q.char!.type && c.id != q.char!.id)
          .map((c) => c.romaji).toSet().toList();
      case KanaQuizType.romajiToKanaMC:
        final sameRow = widget.allChars
          .where((c) => c.type == q.char!.type && c.id != q.char!.id && c.row == q.char!.row)
          .map((c) => c.character).toList();
        if (sameRow.length >= 3) return sameRow;
        return widget.allChars
          .where((c) => c.type == q.char!.type && c.id != q.char!.id)
          .map((c) => c.character).toList();
      case KanaQuizType.hiraToKataMC:
        // Show hiragana → pick correct katakana; distractors = other katakana
        return widget.allChars
          .where((c) => c.type == 'katakana' && c.counterpart != q.char!.character && c.counterpart != null)
          .map((c) => c.character).toList();
      case KanaQuizType.kataToHiraMC:
        // Show katakana → pick correct hiragana; distractors = other hiragana
        return widget.allChars
          .where((c) => c.type == 'hiragana' && c.id != q.char!.id)
          .map((c) => c.character).toList();
      default:
        return [];
    }
  }

  String _prompt(_KanaQuestion q) {
    switch (q.type) {
      case KanaQuizType.kanaToRomajiMC:
      case KanaQuizType.kanaToRomajiType:
        return q.char!.character;
      case KanaQuizType.romajiToKanaMC:
        return q.char!.romaji;
      case KanaQuizType.wordToRomajiType:
        return q.word!.word;
      case KanaQuizType.hiraToKataMC:
        return q.char!.character; // show hiragana
      case KanaQuizType.kataToHiraMC:
        return q.char!.counterpart!; // show katakana
    }
  }

  String _promptLabel(_KanaQuestion q) {
    switch (q.type) {
      case KanaQuizType.kanaToRomajiMC: return 'Select the romaji';
      case KanaQuizType.romajiToKanaMC: return 'Select the ${q.char!.type}';
      case KanaQuizType.kanaToRomajiType: return 'Type the romaji';
      case KanaQuizType.wordToRomajiType: return 'Type the romaji reading';
      case KanaQuizType.hiraToKataMC: return 'Select the katakana';
      case KanaQuizType.kataToHiraMC: return 'Select the hiragana';
    }
  }

  bool _checkTyped(String input) {
    final q = _current;
    final norm = input.trim().toLowerCase();
    final acceptable = q.char?.acceptableRomaji ?? q.word?.acceptableRomaji ?? [];
    return acceptable.any((a) => a.toLowerCase() == norm);
  }

  bool _checkMC(String option) => option == _correctAnswer(_current);

  void _handleMcSelect(String option) {
    if (_showingFeedback) return;
    final correct = _checkMC(option);
    setState(() {
      _selectedOption = option;
      _showingFeedback = true;
      _lastCorrect = correct;
    });
    _onResult(correct);
    if (correct) _autoNextTimer = Timer(const Duration(seconds: 1), _next);
  }

  void _handleTypeSubmit() {
    if (_showingFeedback) return;
    final correct = _checkTyped(_controller.text);
    setState(() { _showingFeedback = true; _lastCorrect = correct; });
    _onResult(correct);
    if (correct) _autoNextTimer = Timer(const Duration(seconds: 1), _next);
  }

  void _onResult(bool correct) {
    if (correct) {
      soundService.playCorrect();
      _correct++;
    } else {
      soundService.playWrong();
    }
    if (widget.testMode && _current.char != null) {
      kanaRepo.recordResult(_current.char!.id, correct);
    }
  }

  void _next() {
    _autoNextTimer?.cancel();
    if (_currentIndex >= _queue.length - 1) {
      if (mounted) _showResults();
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOption = null;
      _showingFeedback = false;
      _lastCorrect = null;
      _controller.clear();
    });
    _prepareQuestion();
  }

  void _showResults() {
    final total = _queue.length;
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => _KanaResultScreen(correct: _correct, total: total, testMode: widget.testMode),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          title: Text('Practice', style: TextStyle(color: AppColors.fg)),
          iconTheme: IconThemeData(color: AppColors.fg),
        ),
        body: Center(child: Text('Nothing to practice.', style: TextStyle(color: AppColors.muted))),
      );
    }

    final q = _current;
    final isMC = _isMC(q.type);
    final promptText = _prompt(q);
    final promptLabel = _promptLabel(q);
    final correctAnswer = _correctAnswer(q);
    final progress = '${_currentIndex + 1} / ${_queue.length}';
    final isLargePrompt = q.type != KanaQuizType.romajiToKanaMC && q.type != KanaQuizType.wordToRomajiType;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(widget.testMode ? 'Kana Test' : 'Kana Practice',
          style: TextStyle(color: AppColors.fg)),
        iconTheme: IconThemeData(color: AppColors.fg),
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
              Text(promptLabel, style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 4),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Text(
                      promptText,
                      style: TextStyle(
                        fontSize: isLargePrompt ? 72 : 36,
                        color: AppColors.kanjiColor,
                        fontFamily: isLargePrompt ? 'NotoSerifCJKjp' : null,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              Divider(thickness: 1, color: AppColors.pillBg),
              const SizedBox(height: 8),
              if (isMC)
                _buildMcOptions(correctAnswer)
              else
                _buildTypeInput(),
              const SizedBox(height: 8),
              SizedBox(
                height: 76,
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
                          Expanded(child: Text(
                            _lastCorrect! ? 'Correct!' : 'Incorrect — $correctAnswer',
                            style: TextStyle(
                              color: _lastCorrect! ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          )),
                        ]),
                      ),
                      const SizedBox(height: 4),
                      Text('Tap anywhere to continue',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
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
              onTap: () { _autoNextTimer?.cancel(); _next(); },
            ),
          ),
      ]),
    );
  }

  Widget _buildMcOptions(String correctAnswer) {
    if (_options.isEmpty) return const CircularProgressIndicator();
    final isKanaOption = _current.type == KanaQuizType.romajiToKanaMC ||
        _current.type == KanaQuizType.hiraToKataMC ||
        _current.type == KanaQuizType.kataToHiraMC;
    return Column(
      children: _options.map((opt) {
        Color? bg;
        if (_showingFeedback && _selectedOption == opt) {
          bg = _checkMC(opt) ? AppColors.correctBg : AppColors.incorrectBg;
        } else if (_showingFeedback && opt == correctAnswer) {
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
                child: Text(
                  opt,
                  style: TextStyle(
                    fontSize: isKanaOption ? 22 : 15,
                    fontFamily: isKanaOption ? 'NotoSerifCJKjp' : null,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypeInput() {
    return Column(children: [
      TextField(
        controller: _controller,
        enabled: !_showingFeedback,
        autofocus: true,
        textCapitalization: TextCapitalization.none,
        decoration: InputDecoration(
          hintText: 'Type romaji...',
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.buttonRadius),
            borderSide: BorderSide.none,
          ),
        ),
        style: TextStyle(color: AppColors.fg, fontSize: 16),
        onSubmitted: (_) => _handleTypeSubmit(),
      ),
      const SizedBox(height: 12),
      ScaleOnPress(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _showingFeedback ? null : _handleTypeSubmit,
            child: const Text('Submit'),
          ),
        ),
      ),
    ]);
  }
}

class _KanaResultScreen extends StatelessWidget {
  final int correct;
  final int total;
  final bool testMode;
  const _KanaResultScreen({required this.correct, required this.total, required this.testMode});

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (correct / total * 100).round() : 0;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('Results', style: TextStyle(color: AppColors.fg)),
        iconTheme: IconThemeData(color: AppColors.fg),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$pct%', style: TextStyle(
              fontSize: 72, fontWeight: FontWeight.bold, color: AppColors.accentBright)),
            const SizedBox(height: 8),
            Text('$correct / $total correct',
              style: TextStyle(fontSize: 18, color: AppColors.muted)),
            if (testMode) ...[
              const SizedBox(height: 12),
              Text('Characters answered correctly 3× in a row are now marked learned.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
                textAlign: TextAlign.center),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
