import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/progress_repository.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import '../widgets/scale_on_press.dart';
import '../widgets/item_info_sheet.dart';

final _kanjiTagsProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => kanjiRepo.getAllTags(),
);

final _kanjiStatusProvider =
    FutureProvider.autoDispose<Map<int, List<(Kanji, String)>>>((ref) {
  return kanjiRepo.getAllKanjiWithStatus();
});

final _kanjiTagStatusProvider =
    FutureProvider.family<List<(Kanji, String)>, String>(
  (ref, tag) => kanjiRepo.getKanjiWithStatusForTag(tag),
);

class SelectTargetKanjiScreen extends ConsumerWidget {
  const SelectTargetKanjiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsAsync = ref.watch(_kanjiTagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Target Kanji')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By Level',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.muted)),
            const SizedBox(height: 10),
            _LevelButton(
              label: 'All Kanji',
              onTap: () => Navigator.push(context,
                AppRoute.to(const KanjiGridScreen(level: null))),
            ),
            const SizedBox(height: 8),
            Row(children: [5, 4, 3, 2, 1].map((level) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _LevelButton(
                  label: 'N$level',
                  onTap: () => Navigator.push(context,
                    AppRoute.to(KanjiGridScreen(level: level))),
                ),
              ),
            )).toList()),
            const SizedBox(height: 24),

            Text('By Category',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.muted)),
            const SizedBox(height: 10),
            tagsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e', style: TextStyle(color: AppColors.muted)),
              data: (tags) => tags.isEmpty
                ? Text('No categories available.',
                    style: TextStyle(color: AppColors.muted, fontSize: 13))
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) => _TagButton(
                      tag: tag,
                      onTap: () => Navigator.push(context,
                        AppRoute.to(KanjiGridScreen(level: null, tag: tag))),
                    )).toList(),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LevelButton({required this.label, required this.onTap});

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

class _TagButton extends StatelessWidget {
  final String tag;
  final VoidCallback onTap;
  const _TagButton({required this.tag, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ScaleOnPress(
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        onPressed: () { soundService.playSelectButton(); onTap(); },
        child: Text(tag),
      ),
    );
  }
}

class KanjiGridScreen extends ConsumerStatefulWidget {
  final int? level;
  final String? tag;
  const KanjiGridScreen({required this.level, this.tag});

  @override
  ConsumerState<KanjiGridScreen> createState() => KanjiGridScreenState();
}

class KanjiGridScreenState extends ConsumerState<KanjiGridScreen> {
  final Map<int, String> _localStatus = {};
  bool _addLearnedMode = false;

  String _statusFor(Kanji k, List<(Kanji, String)> items) {
    if (_localStatus.containsKey(k.id)) return _localStatus[k.id]!;
    for (final (kanji, status) in items) {
      if (kanji.id == k.id) return status;
    }
    return 'unlearned';
  }

  Future<void> _selectAll(List<(Kanji, String)> items) async {
    final hasUnlearned = items.any((item) => _statusFor(item.$1, items) == 'unlearned');

    if (!hasUnlearned) {
      // All are learned or targeted — ask to reset all to unlearned
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reset all to unlearned?'),
          content: const Text(
            'All kanji are already learned or targeted. Set all to unlearned?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
          ],
        ),
      );
      if (confirm != true) return;
      final allIds = items.map((item) => item.$1.id).toList();
      setState(() {
        for (final (k, _) in items) {
          _localStatus[k.id] = 'unlearned';
        }
      });
      await progressRepo.markAllUnlearned(allIds);
    } else {
      // Set unlearned → target; leave learned untouched
      final unlearnedItems = items
          .where((item) => _statusFor(item.$1, items) == 'unlearned')
          .map((item) => item.$1)
          .toList();
      final ids = unlearnedItems.map((k) => k.id).toList();
      setState(() {
        for (final k in unlearnedItems) {
          _localStatus[k.id] = 'target';
        }
      });
      await progressRepo.markAllTarget(ids);
    }
  }

  Future<void> _toggleTarget(Kanji k, String currentStatus, List<(Kanji, String)> items) async {
    if (_addLearnedMode) {
      await progressRepo.markLearned(k.id);
      setState(() => _localStatus[k.id] = 'learned');
      return;
    }
    if (currentStatus == 'learned') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Already Learned'),
          content: const Text(
            'You already know this kanji. Are you sure you want to put it back into the target stack?\n\n'
            'This will set the kanji to unlearned and you will need to test for it again or set it as learned in the dictionary.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
          ],
        ),
      );
      if (confirm != true) return;
      setState(() => _localStatus[k.id] = 'unlearned');
      await progressRepo.markUnlearned(k.id);
      return;
    }
    final newStatus = currentStatus == 'target' ? 'unlearned' : 'target';
    setState(() => _localStatus[k.id] = newStatus);
    if (newStatus == 'target') {
      await progressRepo.markTarget(k.id);
    } else {
      await progressRepo.markUnlearned(k.id);
    }
  }

  Color _tileColor(String status) {
    switch (status) {
      case 'target':
        return AppColors.accent.withValues(alpha: 0.85);
      case 'learned':
        return AppColors.correct.withValues(alpha: 0.6);
      default:
        return AppColors.btnBg;
    }
  }

  String get _screenTitle {
    if (widget.tag != null) return widget.tag!;
    if (widget.level == null) return 'All Kanji';
    return 'N${widget.level} Kanji';
  }

  Widget _buildBody(List<(Kanji, String)> items) {
    final allSelected = items.isNotEmpty &&
        items.every((item) => _statusFor(item.$1, items) != 'unlearned');
    final targetedCount = items
        .where((item) => _statusFor(item.$1, items) == 'target')
        .length;

    return Column(
      children: [
        InkWell(
          onTap: () => _selectAll(items),
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
              Text(
                'Select All',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: allSelected ? AppColors.accent : AppColors.fg,
                ),
              ),
              const Spacer(),
              Text(
                '$targetedCount / ${items.length}',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ]),
          ),
        ),
        Divider(height: 1, color: AppColors.pillBg),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: items.length,
            itemBuilder: (context, idx) {
              final (kanji, _) = items[idx];
              final status = _statusFor(kanji, items);
              return GestureDetector(
                onTap: () => _toggleTarget(kanji, status, items),
                onLongPress: () => showKanjiInfoSheet(context, kanji),
                child: Container(
                  decoration: BoxDecoration(
                    color: _tileColor(status),
                    borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    kanji.character,
                    style: TextStyle(
                      fontSize: 22,
                      color: status == 'target' ? AppColors.fg : AppColors.kanjiColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      appBar: AppBar(
        title: Text(_addLearnedMode ? 'Tap to mark as learned' : _screenTitle),
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
      body: widget.tag != null
          ? ref.watch(_kanjiTagStatusProvider(widget.tag!)).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: _buildBody,
            )
          : ref.watch(_kanjiStatusProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (allData) {
                final items = widget.level == null
                    ? allData.values.expand((l) => l).toList()
                    : (allData[widget.level] ?? []);
                return _buildBody(items);
              },
            ),
    );
    return scaffold;
  }
}
