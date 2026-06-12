import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/vocab_repository.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import '../widgets/scale_on_press.dart';
import 'vocab_list_screen.dart';

final _tagsProvider = FutureProvider.autoDispose<List<String>>((ref) {
  return vocabRepo.getAllTags();
});

class SelectVocabScreen extends ConsumerWidget {
  const SelectVocabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(_tagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Target Vocabulary')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By Level',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.muted)),
            const SizedBox(height: 10),
            _FilterButton(
              label: 'All Vocabulary',
              onTap: () => Navigator.push(context,
                AppRoute.to(const VocabListScreen(filter: VocabFilter.all()))),
            ),
            const SizedBox(height: 8),
            Row(children: [5, 4, 3, 2, 1].map((level) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _FilterButton(
                  label: 'N$level',
                  onTap: () => Navigator.push(context,
                    AppRoute.to(VocabListScreen(filter: VocabFilter.level(level)))),
                ),
              ),
            )).toList()),
            const SizedBox(height: 8),
            _FilterButton(
              label: 'Other',
              onTap: () => Navigator.push(context,
                AppRoute.to(const VocabListScreen(filter: VocabFilter.level(0)))),
            ),
            const SizedBox(height: 24),

            Text('By Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.muted)),
            const SizedBox(height: 10),
            tagsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e', style: TextStyle(color: AppColors.muted)),
              data: (tags) => tags.isEmpty
                ? Text('No categories yet. Import vocabulary data first.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) => _TagChip(
                      tag: tag,
                      onTap: () => Navigator.push(context,
                        AppRoute.to(VocabListScreen(filter: VocabFilter.tag(tag)))),
                    )).toList(),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FilterButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ScaleOnPress(
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () { soundService.playSelectButton(); onTap(); },
          child: Text(label),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  final VoidCallback onTap;
  const _TagChip({required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ScaleOnPress(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onPressed: onTap,
        child: Text(tag),
      ),
    );
  }
}
