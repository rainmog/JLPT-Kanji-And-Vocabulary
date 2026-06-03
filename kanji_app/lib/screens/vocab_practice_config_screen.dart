import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/vocab_repository.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import '../widgets/scale_on_press.dart';
import 'matching_game_config_screen.dart';
import 'vocab_practice_screen.dart';

class VocabPracticeConfigScreen extends StatelessWidget {
  const VocabPracticeConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Practice Target Vocabulary')),
      body: const VocabPracticeConfigBody(),
    );
  }
}

class VocabPracticeConfigBody extends ConsumerStatefulWidget {
  final bool targetOnly;
  const VocabPracticeConfigBody({super.key, this.targetOnly = true});

  @override
  ConsumerState<VocabPracticeConfigBody> createState() =>
      _VocabPracticeConfigBodyState();
}

class _VocabPracticeConfigBodyState
    extends ConsumerState<VocabPracticeConfigBody> {
  bool _suppressFurigana = false;

  // Untargeted-only options
  Set<int> _selectedLevels = {1, 2, 3, 4, 5};
  Set<String> _selectedTags = {};
  int _questionCount = 20;

  Future<void> _start({required bool multipleChoice, required bool reverseMode}) async {
    List<VocabWord> words;
    if (widget.targetOnly) {
      words = await vocabRepo.getTargetVocab();
    } else {
      words = await vocabRepo.getVocabByTagsAndLevels(
        tags: _selectedTags.toList(),
        levels: _selectedLevels.toList(),
        limit: _questionCount,
      );
    }

    if (words.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.targetOnly
          ? 'No target vocabulary selected. Go to Select Target Vocabulary first.'
          : 'No vocabulary found for selected options.'),
      ));
      return;
    }
    if (!mounted) return;
    Navigator.push(
      context,
      AppRoute.to(VocabPracticeScreen(
        words: words,
        multipleChoice: multipleChoice,
        suppressFurigana: _suppressFurigana,
        reverseMode: reverseMode,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Untargeted-only filters ───────────────────────────────
        if (!widget.targetOnly) ...[
          Text('JLPT Levels',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            children: [5, 4, 3, 2, 1].map((level) {
              final isSelected = _selectedLevels.contains(level);
              return FilterChip(
                label: Text('N$level'),
                selected: isSelected,
                onSelected: (v) => setState(() =>
                  v ? _selectedLevels.add(level) : _selectedLevels.remove(level)),
              );
            }).toList(),
          ),
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
          const SizedBox(height: 10),
          ref.watch(_vocabTagsProvider).when(
            data: (tags) {
              if (tags.isEmpty) return const SizedBox.shrink();
              return Wrap(
                spacing: 10,
                runSpacing: 4,
                children: tags.map((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag),
                    selected: isSelected,
                    onSelected: (v) => setState(() =>
                      v ? _selectedTags.add(tag) : _selectedTags.remove(tag)),
                  );
                }).toList(),
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),
        ],

        // ── Display Options ───────────────────────────────────────
        Text('Display Options',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Text(
              "Don't show furigana for learned kanji",
              style: TextStyle(fontSize: 15, color: AppColors.fg),
            ),
          ),
          Switch(
            value: _suppressFurigana,
            onChanged: (v) => setState(() => _suppressFurigana = v),
            activeColor: AppColors.accent,
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 24),
          child: Text(
            'Words where all kanji are in your learned set will display in kanji form.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),

        // ── Japanese to English ───────────────────────────────────
        Text('Japanese to English — Answer Mode',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
        const SizedBox(height: 12),
        _ModeButton(
          label: 'Multiple Choice',
          onTap: () => _start(multipleChoice: true, reverseMode: false),
        ),
        const SizedBox(height: 8),
        _ModeButton(
          label: 'Type the Answer',
          onTap: () => _start(multipleChoice: false, reverseMode: false),
        ),
        const SizedBox(height: 24),

        // ── English to Japanese ───────────────────────────────────
        Text('English to Japanese — Answer Mode',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg)),
        const SizedBox(height: 12),
        _ModeButton(
          label: 'Multiple Choice',
          onTap: () => _start(multipleChoice: true, reverseMode: true),
        ),
        const SizedBox(height: 8),
        _ModeButton(
          label: 'Type the Answer',
          onTap: () => _start(multipleChoice: false, reverseMode: true),
        ),
        const SizedBox(height: 20),
        _ModeButton(
          label: 'Matching Game',
          onTap: () => Navigator.push(context, AppRoute.to(
            const MatchingGameConfigScreen(matchContext: MatchContext.vocab),
          )),
        ),
        const SizedBox(height: 20),
      ]),
    );
  }
}

final _vocabTagsProvider = FutureProvider((ref) => vocabRepo.getAllTags());

class _ModeButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ModeButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ScaleOnPress(
      child: SizedBox(
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
      ),
    );
  }
}
