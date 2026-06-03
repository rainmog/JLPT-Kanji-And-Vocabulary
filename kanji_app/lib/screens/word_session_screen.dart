import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kanji_repository.dart';
import '../services/database_service.dart';
import '../theme.dart';
import 'word_result_screen.dart';
import '../utils/app_route.dart';

class WordSessionScreen extends ConsumerStatefulWidget {
  final List<int> jlptLevels;
  final List<String> tags;
  const WordSessionScreen({super.key, required this.jlptLevels, required this.tags});
  @override
  ConsumerState<WordSessionScreen> createState() => _WordSessionScreenState();
}

class _WordSessionScreenState extends ConsumerState<WordSessionScreen> {
  late List<WordQuestion> questions;
  int currentIndex = 0;
  bool loading = true;
  String? selectedReading;
  String? selectedMeaning;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final levelPlaceholders = List.filled(widget.jlptLevels.length, '?').join(',');
    final rows = await dbService.query(
      'SELECT * FROM kanji WHERE jlpt_level IN ($levelPlaceholders) ORDER BY RANDOM() LIMIT 20',
      widget.jlptLevels,
    );
    final kanji = rows.map(Kanji.fromMap).toList();

    final qs = <WordQuestion>[];
    for (final k in kanji) {
      final wrongReadings = kanji.where((x) => x.id != k.id).take(3).map((x) => x.onReading.split('・')[0]).toList();
      final wrongMeanings = kanji.where((x) => x.id != k.id).take(3).map((x) => x.meaning.split(',')[0]).toList();

      final readings = [k.onReading.split('・')[0], ...wrongReadings]..shuffle();
      final meanings = [k.meaning.split(',')[0], ...wrongMeanings]..shuffle();

      qs.add(WordQuestion(
        kanji: k,
        readings: readings,
        meanings: meanings,
        correctReading: k.onReading.split('・')[0],
        correctMeaning: k.meaning.split(',')[0],
      ));
    }

    setState(() {
      questions = qs;
      loading = false;
    });
  }

  void _submit() {
    if (selectedReading == null || selectedMeaning == null) return;
    final q = questions[currentIndex];
    final correct = selectedReading == q.correctReading && selectedMeaning == q.correctMeaning;

    Navigator.push<bool>(context, AppRoute.to(WordResultScreen(
      question: q,
      selectedReading: selectedReading!,
      selectedMeaning: selectedMeaning!,
      correct: correct,
    ))).then((advance) {
      if (!mounted) return;
      if (advance == true && currentIndex < questions.length - 1) {
        setState(() {
          currentIndex++;
          selectedReading = null;
          selectedMeaning = null;
        });
      } else if (currentIndex >= questions.length - 1) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (questions.isEmpty) return const Scaffold(body: Center(child: Text('No questions')));

    final q = questions[currentIndex];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top 1/3: Kanji word
              Expanded(
                flex: 1,
                child: Center(
                  child: Text(q.kanji.character,
                    style: TextStyle(fontSize: 80, color: AppColors.kanjiColor)),
                ),
              ),
              const SizedBox(height: 12),

              // Middle 1/3: Reading buttons
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text('Reading', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: q.readings.length,
                        itemBuilder: (context, index) {
                          final reading = q.readings[index];
                          final isSelected = selectedReading == reading;
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected ? AppColors.accent : AppColors.pillBg,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.containerRadius)),
                            ),
                            onPressed: () => setState(() => selectedReading = reading),
                            child: Text(reading,
                              style: TextStyle(
                                color: isSelected ? AppColors.fg : AppColors.kanjiColor,
                                fontSize: 10,
                              )),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Bottom 1/3: Meaning buttons
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Text('Meaning', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                        ),
                        itemCount: q.meanings.length,
                        itemBuilder: (context, index) {
                          final meaning = q.meanings[index];
                          final isSelected = selectedMeaning == meaning;
                          return ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSelected ? AppColors.accent : AppColors.pillBg,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.containerRadius)),
                            ),
                            onPressed: () => setState(() => selectedMeaning = meaning),
                            child: Text(meaning,
                              style: TextStyle(
                                color: isSelected ? AppColors.fg : AppColors.kanjiColor,
                                fontSize: 8,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Next/Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (selectedReading != null && selectedMeaning != null) ? _submit : null,
                  child: Text('Check Answer'),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.10),
            ],
          ),
        ),
      ),
    );
  }
}

class WordQuestion {
  final Kanji kanji;
  final List<String> readings;
  final List<String> meanings;
  final String correctReading;
  final String correctMeaning;

  WordQuestion({
    required this.kanji,
    required this.readings,
    required this.meanings,
    required this.correctReading,
    required this.correctMeaning,
  });
}
