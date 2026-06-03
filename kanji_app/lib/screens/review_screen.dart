import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/vocab_repository.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import 'session_screen.dart';
import 'vocab_practice_screen.dart';

final _reviewTagsProvider = FutureProvider((ref) => kanjiRepo.getAllTags());
final _reviewVocabTagsProvider = FutureProvider((ref) => vocabRepo.getAllTags());

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageController.animateToPage(page,
      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        automaticallyImplyLeading: false,
        leading: _page == 1
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios, color: AppColors.accent),
              onPressed: () => _goTo(0),
            )
          : IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.fg),
              onPressed: () => Navigator.pop(context),
            ),
        title: Text(_page == 0 ? 'Kanji' : 'Vocabulary',
          style: TextStyle(color: AppColors.fg)),
        actions: [
          if (_page == 0)
            IconButton(
              icon: Icon(Icons.arrow_forward_ios, color: AppColors.accent),
              onPressed: () => _goTo(1),
            ),
        ],
        iconTheme: IconThemeData(color: AppColors.fg),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (p) => setState(() => _page = p),
        children: const [
          _KanjiReviewBody(),
          _VocabReviewBody(),
        ],
      ),
    );
  }
}

class _KanjiReviewBody extends ConsumerStatefulWidget {
  const _KanjiReviewBody();

  @override
  ConsumerState<_KanjiReviewBody> createState() => _KanjiReviewBodyState();
}

class _KanjiReviewBodyState extends ConsumerState<_KanjiReviewBody> {
  final Set<int> _selectedLevels = {4, 3, 2, 1};
  final Set<String> _selectedTags = {};
  String _selectedMode = 'sentence';
  bool _multipleChoice = true;
  int _questionCount = 20;
  int _minDifficulty = 1;
  int _maxDifficulty = 4;

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(_reviewTagsProvider);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedLevels.isEmpty ? null : _startReview,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Start Review', style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Text('Practice Mode',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
          const SizedBox(height: 10),
          ...['word', 'sentence', 'wordpractice'].map((mode) {
            final isSelected = _selectedMode == mode;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? AppColors.accent : AppColors.btnBg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => setState(() {
                    _selectedMode = mode;
                    if (mode == 'wordpractice') _multipleChoice = true;
                  }),
                  child: Text(_modeLabel(mode)),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),

          if (_selectedMode != 'wordpractice') ...[
            Text('Input Mode',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: !_multipleChoice ? AppColors.accent : AppColors.btnBg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => setState(() => _multipleChoice = false),
                  child: const Text('Type the Answer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _multipleChoice ? AppColors.accent : AppColors.btnBg,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => setState(() => _multipleChoice = true),
                  child: const Text('Multiple Choice'),
                ),
              ),
            ]),
            const SizedBox(height: 20),
          ],

          Text('JLPT Level',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [5, 4, 3, 2, 1].map((level) =>
            FilterChip(
              label: Text('N$level'),
              selected: _selectedLevels.contains(level),
              onSelected: (v) => setState(() => v ? _selectedLevels.add(level) : _selectedLevels.remove(level)),
              selectedColor: AppColors.btnBg,
              checkmarkColor: AppColors.accentBright,
              labelStyle: TextStyle(color: _selectedLevels.contains(level) ? AppColors.accentBright : AppColors.muted),
              backgroundColor: AppColors.pillBg,
              side: BorderSide.none,
            )
          ).toList()),
          const SizedBox(height: 20),

          Text('Question Count: $_questionCount',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
          Slider(
            value: _questionCount.toDouble(),
            min: 5,
            max: 100,
            divisions: 19,
            label: _questionCount.toString(),
            onChanged: (v) {
              final rounded = ((v.toInt() / 5).round() * 5).clamp(5, 100);
              setState(() => _questionCount = rounded);
            },
          ),
          const SizedBox(height: 20),

          Text('Difficulty: $_minDifficulty – $_maxDifficulty',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
          RangeSlider(
            values: RangeValues(_minDifficulty.toDouble(), _maxDifficulty.toDouble()),
            min: 1,
            max: 9,
            divisions: 8,
            labels: RangeLabels(_minDifficulty.toString(), _maxDifficulty.toString()),
            onChanged: (v) => setState(() {
              _minDifficulty = v.start.round();
              _maxDifficulty = v.end.round();
            }),
          ),
          const SizedBox(height: 20),

          Text('Study By Word Group',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
          const SizedBox(height: 8),
          tags.when(
            data: (list) => Wrap(spacing: 8, runSpacing: 4, children: list.map((tag) =>
              FilterChip(
                label: Text(tag),
                selected: _selectedTags.contains(tag),
                onSelected: (v) => setState(() => v ? _selectedTags.add(tag) : _selectedTags.remove(tag)),
                selectedColor: AppColors.btnBg,
                checkmarkColor: AppColors.accentBright,
                labelStyle: TextStyle(color: _selectedTags.contains(tag) ? AppColors.accentBright : AppColors.muted),
                backgroundColor: AppColors.pillBg,
                side: BorderSide.none,
              )
            ).toList()),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  void _startReview() {
    Navigator.push(context, AppRoute.to(SessionScreen(
      mode: _selectedMode,
      jlptLevels: _selectedLevels.toList(),
      tags: _selectedTags.toList(),
      questionCount: _questionCount,
      minDifficulty: _minDifficulty,
      maxDifficulty: _maxDifficulty,
      multipleChoice: _multipleChoice,
      reviewOnly: true,
    )));
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'word': return 'Kanji Compounds';
      case 'sentence': return 'Kanji in Sentences';
      case 'wordpractice': return 'On/Kun & Meaning Practice';
      default: return mode;
    }
  }
}

class _VocabReviewBody extends ConsumerStatefulWidget {
  const _VocabReviewBody();

  @override
  ConsumerState<_VocabReviewBody> createState() => _VocabReviewBodyState();
}

class _VocabReviewBodyState extends ConsumerState<_VocabReviewBody> {
  Set<int> _selectedLevels = {1, 2, 3, 4, 5};
  Set<String> _selectedTags = {};
  int _questionCount = 20;

  Future<void> _start({required bool multipleChoice, required bool reverseMode}) async {
    final words = await vocabRepo.getVocabByTagsAndLevels(
      tags: _selectedTags.toList(),
      levels: _selectedLevels.toList(),
      limit: _questionCount,
    );

    if (words.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No vocabulary found for selected options.'),
      ));
      return;
    }
    if (!mounted) return;
    Navigator.push(context, AppRoute.to(VocabPracticeScreen(
      words: words,
      multipleChoice: multipleChoice,
      reverseMode: reverseMode,
    )));
  }

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(_reviewVocabTagsProvider);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('JLPT Levels',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [5, 4, 3, 2, 1].map((level) =>
            FilterChip(
              label: Text('N$level'),
              selected: _selectedLevels.contains(level),
              onSelected: (v) => setState(() => v ? _selectedLevels.add(level) : _selectedLevels.remove(level)),
              selectedColor: AppColors.btnBg,
              checkmarkColor: AppColors.accentBright,
              labelStyle: TextStyle(color: _selectedLevels.contains(level) ? AppColors.accentBright : AppColors.muted),
              backgroundColor: AppColors.pillBg,
              side: BorderSide.none,
            )
          ).toList()),
          const SizedBox(height: 20),

          Text('Question Count: $_questionCount',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
          Slider(
            value: _questionCount.toDouble(),
            min: 5,
            max: 100,
            divisions: 19,
            label: _questionCount.toString(),
            onChanged: (v) {
              final rounded = ((v.toInt() / 5).round() * 5).clamp(5, 100);
              setState(() => _questionCount = rounded);
            },
          ),
          const SizedBox(height: 20),

          Text('Study By Word Group',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
          const SizedBox(height: 8),
          tags.when(
            data: (list) {
              if (list.isEmpty) return const SizedBox.shrink();
              return Wrap(spacing: 8, runSpacing: 4, children: list.map((tag) =>
                FilterChip(
                  label: Text(tag),
                  selected: _selectedTags.contains(tag),
                  onSelected: (v) => setState(() => v ? _selectedTags.add(tag) : _selectedTags.remove(tag)),
                  selectedColor: AppColors.btnBg,
                  checkmarkColor: AppColors.accentBright,
                  labelStyle: TextStyle(color: _selectedTags.contains(tag) ? AppColors.accentBright : AppColors.muted),
                  backgroundColor: AppColors.pillBg,
                  side: BorderSide.none,
                )
              ).toList());
            },
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 28),

          Text('Japanese to English — Answer Mode',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
          const SizedBox(height: 12),
          _startButton('Multiple Choice', () => _start(multipleChoice: true, reverseMode: false)),
          const SizedBox(height: 8),
          _startButton('Type the Answer', () => _start(multipleChoice: false, reverseMode: false)),
          const SizedBox(height: 24),

          Text('English to Japanese — Answer Mode',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
          const SizedBox(height: 12),
          _startButton('Multiple Choice', () => _start(multipleChoice: true, reverseMode: true)),
          const SizedBox(height: 8),
          _startButton('Type the Answer', () => _start(multipleChoice: false, reverseMode: true)),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _startButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.btnBg,
          foregroundColor: AppColors.kanjiColor,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }
}
