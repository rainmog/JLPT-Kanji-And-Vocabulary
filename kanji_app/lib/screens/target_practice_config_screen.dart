import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/preferences_service.dart';
import '../theme.dart';
import 'session_screen.dart';
import '../utils/app_route.dart';
import 'matching_game_config_screen.dart';
import 'speed_read_config_screen.dart';

class TargetPracticeConfigScreen extends ConsumerStatefulWidget {
  const TargetPracticeConfigScreen({super.key});

  @override
  ConsumerState<TargetPracticeConfigScreen> createState() =>
      _TargetPracticeConfigScreenState();
}

class _TargetPracticeConfigScreenState
    extends ConsumerState<TargetPracticeConfigScreen> {
  String selectedMode = 'sentence';
  int questionCount = 20;
  int minDifficulty = 1;
  int maxDifficulty = 4;
  bool multipleChoice = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await PreferencesService.load();
    if (!mounted) return;
    setState(() {
      selectedMode = prefs['mode'] == 'wordpractice' ? 'wordpractice' : prefs['mode'];
      questionCount = prefs['count'];
      minDifficulty = prefs['minDifficulty'];
      maxDifficulty = prefs['maxDifficulty'];
      multipleChoice = prefs['multipleChoice'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Practice Target Kanji')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Start button at top
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startSession,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Start Practice', style: TextStyle(fontSize: 18)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text('Practice Mode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...['word', 'sentence', 'wordpractice'].map((mode) {
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
            }),
            const SizedBox(height: 20),

            if (selectedMode != 'wordpractice') ...[
              Text('Input Mode',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: !multipleChoice ? AppColors.accent : AppColors.btnBg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => setState(() => multipleChoice = false),
                    child: const Text('Type the Answer'),
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
                    child: const Text('Multiple Choice'),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
            ],

            Text('Question Count: $questionCount',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Slider(
              value: questionCount.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              label: questionCount.toString(),
              onChanged: (v) {
                final rounded = ((v.toInt() / 5).round() * 5).clamp(5, 60);
                setState(() => questionCount = rounded);
              },
            ),
            const SizedBox(height: 20),

            Text('Difficulty: $minDifficulty – $maxDifficulty',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            RangeSlider(
              values: RangeValues(minDifficulty.toDouble(), maxDifficulty.toDouble()),
              min: 1,
              max: 9,
              divisions: 8,
              labels: RangeLabels(minDifficulty.toString(), maxDifficulty.toString()),
              onChanged: (v) => setState(() {
                minDifficulty = v.start.round();
                maxDifficulty = v.end.round();
              }),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.pillBg),
                onPressed: () => Navigator.push(context, AppRoute.to(
                  const SpeedReadConfigScreen(speedContext: SpeedReadContext.kanji),
                )),
                child: Text('Speed Reading', style: TextStyle(color: AppColors.fg, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startSession() {
    PreferencesService.save(
      mode: selectedMode,
      levels: {1, 2, 3, 4, 5},
      tags: const {},
      count: questionCount,
      minDifficulty: minDifficulty,
      maxDifficulty: maxDifficulty,
      multipleChoice: multipleChoice,
    );
    Navigator.push(context, AppRoute.to(SessionScreen(
      mode: selectedMode,
      jlptLevels: [1, 2, 3, 4, 5],
      tags: const [],
      questionCount: questionCount,
      minDifficulty: minDifficulty,
      maxDifficulty: maxDifficulty,
      multipleChoice: multipleChoice,
      targetOnly: true,
    )));
  }

  String _modeLabel(String mode) {
    switch (mode) {
      case 'word': return 'Compounds';
      case 'sentence': return 'Sentences';
      case 'wordpractice': return 'On/Kun & Meaning Practice';
      default: return mode;
    }
  }
}
