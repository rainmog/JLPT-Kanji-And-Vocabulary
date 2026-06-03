import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/session_controller.dart';
import '../repositories/kanji_repository.dart';
import '../theme.dart';
import 'session_screen.dart';
import '../utils/app_route.dart';

final _tagsProvider = FutureProvider((ref) => kanjiRepo.getAllTags());

class FilterScreen extends ConsumerStatefulWidget {
  final FilterMode mode;
  const FilterScreen({super.key, required this.mode});
  @override
  ConsumerState<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends ConsumerState<FilterScreen> {
  final Set<int> _selectedLevels = {4, 3, 2, 1};
  final Set<String> _selectedTags = {};

  @override
  Widget build(BuildContext context) {
    final tags = ref.watch(_tagsProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(widget.mode == FilterMode.practice ? 'Practice' : 'Review',
          style: TextStyle(color: AppColors.fg)),
        iconTheme: IconThemeData(color: AppColors.fg),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('JLPT LEVEL', style: TextStyle(fontSize: 10, color: AppColors.muted, letterSpacing: 1)),
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
          Text('TAGS (OPTIONAL)', style: TextStyle(fontSize: 10, color: AppColors.muted, letterSpacing: 1)),
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
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedLevels.isEmpty ? null : _startSession,
              child: Text(widget.mode == FilterMode.practice ? 'Start Practice' : 'Start Review'),
            ),
          ),
        ]),
        ),
      ),
    );
  }

  void _startSession() {
    Navigator.push(context, AppRoute.to(SessionScreen(
      mode: widget.mode.name,
      jlptLevels: _selectedLevels.toList(),
      tags: _selectedTags.toList(),
    )));
  }
}
