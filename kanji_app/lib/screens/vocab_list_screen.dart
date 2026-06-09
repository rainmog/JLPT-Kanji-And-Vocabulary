import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/vocab_repository.dart';
import '../theme.dart';
import '../widgets/item_info_sheet.dart';

sealed class VocabFilter {
  const VocabFilter();
  const factory VocabFilter.all() = _AllFilter;
  const factory VocabFilter.level(int level) = _LevelFilter;
  const factory VocabFilter.tag(String tag) = _TagFilter;

  String get title => switch (this) {
    _AllFilter() => 'All Vocabulary',
    _LevelFilter(level: final l) => 'N$l Vocabulary',
    _TagFilter(tag: final t) => t,
  };

  Future<List<VocabWord>> fetch() => switch (this) {
    _AllFilter() => vocabRepo.getAllVocab(),
    _LevelFilter(level: final l) => vocabRepo.getVocabByLevel(l),
    _TagFilter(tag: final t) => vocabRepo.getVocabByTag(t),
  };
}

class _AllFilter extends VocabFilter { const _AllFilter(); }
class _LevelFilter extends VocabFilter {
  final int level;
  const _LevelFilter(this.level);
}
class _TagFilter extends VocabFilter {
  final String tag;
  const _TagFilter(this.tag);
}

class VocabListScreen extends ConsumerStatefulWidget {
  final VocabFilter filter;
  const VocabListScreen({super.key, required this.filter});

  @override
  ConsumerState<VocabListScreen> createState() => _VocabListScreenState();
}

class _VocabListScreenState extends ConsumerState<VocabListScreen> {
  List<VocabWord> _words = [];
  Set<int> _targetIds = {};
  Set<int> _learnedIds = {};
  bool _loading = true;
  bool _busy = false;
  bool _addLearnedMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.filter.fetch(),
      vocabRepo.getTargetIds(),
      vocabRepo.getLearnedIds(),
    ]);
    if (!mounted) return;
    setState(() {
      _words = results[0] as List<VocabWord>;
      _targetIds = results[1] as Set<int>;
      _learnedIds = results[2] as Set<int>;
      _loading = false;
    });
  }

  Future<void> _toggle(VocabWord word) async {
    if (_addLearnedMode) {
      if (_learnedIds.contains(word.id)) return;
      setState(() => _learnedIds.add(word.id));
      await vocabRepo.markLearned(word.id);
      return;
    }
    if (_busy) return;

    if (_learnedIds.contains(word.id)) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Already Learned'),
          content: Text(
            '"${word.word}" is already learned. Set it back to unlearned?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
          ],
        ),
      );
      if (confirm != true) return;
      setState(() { _learnedIds.remove(word.id); _targetIds.remove(word.id); });
      await vocabRepo.markUnlearned(word.id);
      return;
    }

    _busy = true;
    final isTarget = _targetIds.contains(word.id);
    setState(() {
      if (isTarget) {
        _targetIds.remove(word.id);
      } else {
        _targetIds.add(word.id);
      }
    });
    await vocabRepo.toggleTarget(word.id, isTarget);
    _busy = false;
  }

  Future<void> _selectAll() async {
    if (_busy) return;
    final ids = _words.map((w) => w.id).toList();
    final hasUnlearned = ids.any((id) => !_targetIds.contains(id) && !_learnedIds.contains(id));

    if (!hasUnlearned) {
      // All are learned or targeted — ask to reset all to unlearned
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reset all to unlearned?'),
          content: const Text(
            'All words are already learned or targeted. Set all to unlearned?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
          ],
        ),
      );
      if (confirm != true) return;
      _busy = true;
      setState(() { _targetIds.removeAll(ids); _learnedIds.removeAll(ids); });
      for (final id in ids) {
        await vocabRepo.markUnlearned(id);
      }
      _busy = false;
    } else {
      // Set unlearned → target; leave learned untouched
      _busy = true;
      final toTarget = ids.where((id) => !_targetIds.contains(id) && !_learnedIds.contains(id)).toList();
      setState(() => _targetIds.addAll(toTarget));
      await vocabRepo.selectAllTargets(toTarget);
      _busy = false;
    }
  }

  Color _tileColor(VocabWord word) {
    if (_learnedIds.contains(word.id)) return AppColors.correct.withValues(alpha: 0.6);
    if (_targetIds.contains(word.id)) return AppColors.accent.withValues(alpha: 0.85);
    return AppColors.btnBg;
  }

  Color _tileTextColor(VocabWord word) {
    if (_targetIds.contains(word.id) && !_learnedIds.contains(word.id)) return AppColors.fg;
    return AppColors.kanjiColor;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.filter.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final ids = _words.map((w) => w.id).toList();
    final allSelected = ids.isNotEmpty &&
        ids.every((id) => _targetIds.contains(id) || _learnedIds.contains(id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filter.title),
        actions: [
          IconButton(
            icon: Icon(
              _addLearnedMode ? Icons.school : Icons.school_outlined,
              color: _addLearnedMode ? AppColors.accent : AppColors.fg,
            ),
            tooltip: 'Mark as Learned',
            onPressed: () => setState(() => _addLearnedMode = !_addLearnedMode),
          ),
        ],
      ),
      body: _words.isEmpty
        ? Center(child: Text('No words found.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted)))
        : Column(children: [
            InkWell(
              onTap: _selectAll,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: allSelected
                  ? AppColors.accent.withValues(alpha: 0.15)
                  : AppColors.surface,
                child: Row(children: [
                  Icon(
                    allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: allSelected ? AppColors.accent : AppColors.muted,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text('Select All',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                      color: allSelected ? AppColors.accent : AppColors.fg)),
                  const Spacer(),
                  Text('${_targetIds.intersection(ids.toSet()).length} / ${ids.length}',
                    style: TextStyle(fontSize: 13, color: AppColors.muted)),
                ]),
              ),
            ),
            Divider(height: 1, color: AppColors.pillBg),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.4,
                ),
                itemCount: _words.length,
                itemBuilder: (context, i) {
                  final word = _words[i];
                  final showReading = word.word != word.reading;
                  return GestureDetector(
                    onTap: () => _toggle(word),
                    onLongPress: () => showVocabInfoSheet(context, word),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _tileColor(word),
                        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            word.word,
                            style: TextStyle(
                              fontSize: 15,
                              color: _tileTextColor(word),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (showReading) ...[
                            const SizedBox(height: 2),
                            Text(
                              word.reading,
                              style: TextStyle(
                                fontSize: 10,
                                color: _tileTextColor(word).withValues(alpha: 0.75),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
    );
  }
}
