import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/quiz_controller.dart';
import '../services/preferences_service.dart';
import '../theme.dart';
import 'matching_game_config_screen.dart';
import 'session_screen.dart';
import '../utils/app_route.dart';

class SessionConfigScreen extends StatelessWidget {
  const SessionConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Practice Settings')),
      body: const SessionConfigBody(),
    );
  }
}

class SessionConfigBody extends ConsumerStatefulWidget {
  const SessionConfigBody({super.key});

  @override
  ConsumerState<SessionConfigBody> createState() => _SessionConfigBodyState();
}

class _SessionConfigBodyState extends ConsumerState<SessionConfigBody> {
  String selectedMode = 'sentence';
  Set<int> selectedLevels = {1, 2, 3, 4};
  Set<String> selectedTags = {};
  int questionCount = 20;
  int minDifficulty = 1;
  int maxDifficulty = 4;
  bool multipleChoice = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await PreferencesService.load();
    if (!mounted) return;
    setState(() {
      selectedMode = prefs['mode'];
      selectedLevels = prefs['levels'];
      selectedTags = prefs['tags'];
      questionCount = prefs['count'];
      minDifficulty = prefs['minDifficulty'];
      maxDifficulty = prefs['maxDifficulty'];
      multipleChoice = prefs['multipleChoice'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Start button at top
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: selectedLevels.isEmpty ? null : _startSession,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Start Practice', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.pillBg),
                onPressed: () => Navigator.push(context, AppRoute.to(
                  const MatchingGameConfigScreen(matchContext: MatchContext.kanji),
                )),
                child: Text('Matching Game', style: TextStyle(color: AppColors.fg, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 24),

            // Mode selection
            Text(
              'Practice Mode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Column(
              children: <Widget>[
                ...<String>['word', 'sentence', 'wordpractice'].map((mode) {
                  final isSelected = selectedMode == mode;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected ? AppColors.accent : AppColors.btnBg,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => setState(() {
                          selectedMode = mode;
                          if (mode == 'wordpractice') multipleChoice = true;
                        }),
                        child: Text(_modeLabel(mode)),
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
            const SizedBox(height: 20),

            // Input mode selector (sentence and word modes)
            if (selectedMode == 'sentence' || selectedMode == 'word') ...[
              Text(
                'Input Mode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !multipleChoice ? AppColors.accent : AppColors.btnBg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => setState(() => multipleChoice = false),
                      child: Text('Type the Answer'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: multipleChoice ? AppColors.accent : AppColors.btnBg,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => setState(() => multipleChoice = true),
                      child: Text('Multiple Choice'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // JLPT levels
            Text(
              'JLPT Levels',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: <Widget>[
                ...[1, 2, 3, 4].map((level) {
                  final isSelected = selectedLevels.contains(level);
                  return FilterChip(
                    label: Text('N$level'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          selectedLevels.add(level);
                        } else {
                          selectedLevels.remove(level);
                        }
                      });
                    },
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),

            // Question count slider
            Text(
              'Question Count: $questionCount',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Slider(
              value: questionCount.toDouble(),
              min: 5,
              max: 100,
              divisions: 19,
              label: questionCount.toString(),
              onChanged: (v) {
                final rounded = ((v.toInt() / 5).round() * 5).clamp(5, 100);
                setState(() => questionCount = rounded);
              },
            ),
            const SizedBox(height: 20),

            // Difficulty range
            Text(
              'Difficulty: $minDifficulty – $maxDifficulty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            RangeSlider(
              values: RangeValues(minDifficulty.toDouble(), maxDifficulty.toDouble()),
              min: 1,
              max: 9,
              divisions: 8,
              labels: RangeLabels(minDifficulty.toString(), maxDifficulty.toString()),
              onChanged: (RangeValues values) {
                setState(() {
                  minDifficulty = values.start.round();
                  maxDifficulty = values.end.round();
                });
              },
            ),
            const SizedBox(height: 20),

            // Study By Word Group
            Text(
              'Study By Word Group',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ref.watch(allTagsProvider).when(
              data: (allTags) {
                if (allTags.isEmpty) {
                  return Text('No tags available');
                }
                return Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: allTags.map((tag) {
                    final isSelected = selectedTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedTags.add(tag);
                          } else {
                            selectedTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                );
              },
              loading: () => const SizedBox(
                height: 50,
                child: CircularProgressIndicator(),
              ),
              error: (error, stackTrace) => Text(
                'Error loading tags: $error',
                style: TextStyle(color: Colors.red),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      );
  }

  void _startSession() {
    if (selectedLevels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select at least one JLPT level')),
      );
      return;
    }

    PreferencesService.save(
      mode: selectedMode,
      levels: selectedLevels,
      tags: selectedTags,
      count: questionCount,
      minDifficulty: minDifficulty,
      maxDifficulty: maxDifficulty,
      multipleChoice: multipleChoice,
    );

    ref.invalidate(quizControllerProvider);

    Navigator.push(
      context,
      AppRoute.to(SessionScreen(
        mode: selectedMode,
        jlptLevels: selectedLevels.toList()
          ..sort((a, b) => b.compareTo(a)),
        tags: selectedTags.toList(),
        questionCount: questionCount,
        minDifficulty: minDifficulty,
        maxDifficulty: maxDifficulty,
        multipleChoice: multipleChoice,
        targetOnly: false,
      )),
    );
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'word':
        return 'Kanji Compounds';
      case 'sentence':
        return 'Kanji in Sentences';
      case 'wordpractice':
        return 'On/Kun & Meaning Practice';
      default:
        return mode;
    }
  }
}
