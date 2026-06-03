import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/progress_repository.dart';
import '../services/database_service.dart';
import '../theme.dart';
import 'kanji_detail_screen.dart';
import '../utils/app_route.dart';

final _dictionaryProvider = FutureProvider.family<List<Kanji>, List<int>?>((ref, jlptLevels) async {
  if (jlptLevels == null || jlptLevels.isEmpty) {
    final rows = await dbService.query('SELECT * FROM kanji ORDER BY jlpt_level DESC, id ASC');
    return rows.map(Kanji.fromMap).toList();
  }
  final placeholders = List.filled(jlptLevels.length, '?').join(',');
  final rows = await dbService.query(
    'SELECT * FROM kanji WHERE jlpt_level IN ($placeholders) ORDER BY jlpt_level DESC, id ASC',
    jlptLevels,
  );
  return rows.map(Kanji.fromMap).toList();
});

final _tagDictionaryProvider = FutureProvider.family<List<Kanji>, String>((ref, tag) {
  return kanjiRepo.getKanjiForTag(tag);
});

final _learnedKanjiProvider = FutureProvider<Set<String>>((ref) async {
  final rows = await dbService.query("SELECT k.character FROM kanji k JOIN user_progress p ON k.id = p.kanji_id WHERE p.status = 'learned'");
  return rows.map((r) => r['character'] as String).toSet();
});

class DictionaryScreen extends ConsumerStatefulWidget {
  final List<int>? jlptLevels;
  final String? title;
  final String? tag;

  const DictionaryScreen({super.key, this.jlptLevels, this.title, this.tag});

  @override
  ConsumerState<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends ConsumerState<DictionaryScreen> {
  bool _addLearnedMode = false;

  @override
  Widget build(BuildContext context) {
    final kanjiAsync = widget.tag != null
        ? ref.watch(_tagDictionaryProvider(widget.tag!))
        : ref.watch(_dictionaryProvider(widget.jlptLevels));
    final learned = ref.watch(_learnedKanjiProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(
          _addLearnedMode ? 'Tap to mark as learned' : (widget.title ?? 'Dictionary'),
          style: TextStyle(color: AppColors.fg),
        ),
        iconTheme: IconThemeData(color: AppColors.fg),
        actions: [
          IconButton(
            icon: Icon(
              _addLearnedMode ? Icons.school : Icons.school_outlined,
              color: _addLearnedMode ? AppColors.accent : AppColors.fg,
            ),
            tooltip: 'Add Learned Kanji',
            onPressed: () => setState(() => _addLearnedMode = !_addLearnedMode),
          ),
        ],
      ),
      body: kanjiAsync.when(
        data: (kanji) => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: kanji.length,
          itemBuilder: (context, index) {
            final k = kanji[index];
            final isLearned = learned.whenData((learned) => learned.contains(k.character)).value ?? false;
            return GestureDetector(
              onTap: () async {
                if (_addLearnedMode) {
                  await progressRepo.markLearned(k.id);
                  ref.invalidate(_learnedKanjiProvider);
                } else {
                  Navigator.push(context, AppRoute.to(KanjiDetailScreen(kanji: k)));
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isLearned ? AppColors.btnBg : AppColors.pillBg,
                  border: Border.all(
                    color: isLearned ? AppColors.accentBright : AppColors.muted,
                    width: isLearned ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(AppColors.containerRadius),
                ),
                child: Center(
                  child: Text(
                    k.character,
                    style: TextStyle(
                      fontSize: 28,
                      color: isLearned ? AppColors.accentBright : AppColors.kanjiColor,
                      fontWeight: isLearned ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('Error loading kanji')),
      ),
    );
  }
}
