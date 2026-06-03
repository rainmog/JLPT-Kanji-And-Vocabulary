import 'package:flutter/material.dart';
import '../repositories/kana_repository.dart';
import '../theme.dart';
import '../widgets/scale_on_press.dart';

class SelectTargetKanaScreen extends StatefulWidget {
  final String type; // 'hiragana' | 'katakana'
  const SelectTargetKanaScreen({super.key, required this.type});

  @override
  State<SelectTargetKanaScreen> createState() => _SelectTargetKanaScreenState();
}

class _SelectTargetKanaScreenState extends State<SelectTargetKanaScreen> {
  List<KanaCharacter> _chars = [];
  List<String> _rows = [];
  bool _loading = true;
  bool _selectLearnedMode = false;
  final Set<int> _selectedForLearned = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final chars = await kanaRepo.getAll(type: widget.type);
    final rows = await kanaRepo.getRows(type: widget.type);
    if (!mounted) return;
    setState(() { _chars = chars; _rows = rows; _loading = false; });
  }

  Map<String, List<KanaCharacter>> get _byRow {
    final map = <String, List<KanaCharacter>>{};
    for (final ch in _chars) {
      map.putIfAbsent(ch.row, () => []).add(ch);
    }
    return map;
  }

  Future<void> _toggleChar(KanaCharacter ch) async {
    final next = ch.status == 'target' ? 'unlearned' : 'target';
    await kanaRepo.setStatus(ch.id, next);
    await _load();
  }

  Future<void> _toggleRow(String row) async {
    final rowChars = _byRow[row] ?? [];
    final allTargeted = rowChars.every((c) => c.status == 'target' || c.status == 'learned');
    final newStatus = allTargeted ? 'unlearned' : 'target';
    for (final ch in rowChars) {
      if (ch.status != 'learned') {
        await kanaRepo.setStatus(ch.id, newStatus);
      }
    }
    await _load();
  }

  Future<void> _setAllLearned() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Set all to learned?', style: TextStyle(color: AppColors.fg)),
        content: Text(
          'All ${widget.type} characters will be marked as learned.',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await kanaRepo.setAllLearned(type: widget.type);
    await _load();
  }

  Future<void> _confirmMarkSelectedLearned() async {
    if (_selectedForLearned.isEmpty) return;
    for (final id in _selectedForLearned) {
      await kanaRepo.setStatus(id, 'learned');
    }
    setState(() {
      _selectedForLearned.clear();
      _selectLearnedMode = false;
    });
    await _load();
  }

  Color _chipColor(String status) {
    switch (status) {
      case 'learned': return AppColors.correct;
      case 'target': return AppColors.accent;
      default: return AppColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.type == 'hiragana' ? 'Hiragana Targets' : 'Katakana Targets';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text(title, style: TextStyle(color: AppColors.fg)),
        iconTheme: IconThemeData(color: AppColors.fg),
        actions: [
          if (_selectLearnedMode)
            TextButton(
              onPressed: () => setState(() {
                _selectLearnedMode = false;
                _selectedForLearned.clear();
              }),
              child: Text('Cancel', style: TextStyle(color: AppColors.muted)),
            )
          else
            PopupMenuButton<String>(
              color: AppColors.surface,
              icon: Icon(Icons.more_vert, color: AppColors.fg),
              onSelected: (val) {
                if (val == 'set_all') _setAllLearned();
                if (val == 'select') setState(() => _selectLearnedMode = true);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'set_all',
                  child: Text('Set all to learned', style: TextStyle(color: AppColors.fg)),
                ),
                PopupMenuItem(
                  value: 'select',
                  child: Text('Select to mark learned', style: TextStyle(color: AppColors.fg)),
                ),
              ],
            ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Stack(children: [
            ListView.separated(
              padding: EdgeInsets.fromLTRB(16, 16, 16, _selectLearnedMode ? 80 : 16),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: _rows.length,
              itemBuilder: (context, i) {
                final row = _rows[i];
                final chars = _byRow[row] ?? [];
                final allTargeted = chars.every((c) => c.status == 'target' || c.status == 'learned');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(row, style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.muted,
                        )),
                      ),
                      if (!_selectLearnedMode)
                        TextButton(
                          onPressed: () => _toggleRow(row),
                          child: Text(
                            allTargeted ? 'Deselect all' : 'Select all',
                            style: TextStyle(fontSize: 12, color: AppColors.accent),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: chars.map((ch) {
                        final color = _chipColor(ch.status);
                        final selected = ch.status == 'target' || ch.status == 'learned';
                        final isSelectedForLearned = _selectedForLearned.contains(ch.id);

                        if (_selectLearnedMode) {
                          final canSelect = ch.status != 'learned';
                          return ScaleOnPress(
                            child: GestureDetector(
                              onTap: canSelect ? () => setState(() {
                                if (isSelectedForLearned) {
                                  _selectedForLearned.remove(ch.id);
                                } else {
                                  _selectedForLearned.add(ch.id);
                                }
                              }) : null,
                              child: Container(
                                width: 60,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelectedForLearned
                                    ? AppColors.correct.withValues(alpha: 0.2)
                                    : (selected ? color.withValues(alpha: 0.15) : AppColors.btnBg),
                                  borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                                  border: Border.all(
                                    color: isSelectedForLearned
                                      ? AppColors.correct
                                      : (selected ? color.withValues(alpha: 0.6) : AppColors.pillBg),
                                    width: isSelectedForLearned ? 2 : 1,
                                  ),
                                ),
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  Text(ch.character, style: TextStyle(
                                    fontSize: 20,
                                    color: isSelectedForLearned ? AppColors.correct
                                      : (selected ? color : AppColors.muted),
                                  )),
                                  const SizedBox(height: 2),
                                  Text(ch.romaji, style: TextStyle(
                                    fontSize: 9,
                                    color: isSelectedForLearned ? AppColors.correct
                                      : (selected ? color : AppColors.muted),
                                  )),
                                ]),
                              ),
                            ),
                          );
                        }

                        return ScaleOnPress(
                          child: GestureDetector(
                            onTap: ch.status == 'learned' ? null : () => _toggleChar(ch),
                            child: Container(
                              width: 60,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: selected ? color.withValues(alpha: 0.15) : AppColors.btnBg,
                                borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                                border: Border.all(
                                  color: selected ? color.withValues(alpha: 0.6) : AppColors.pillBg,
                                ),
                              ),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text(ch.character, style: TextStyle(
                                  fontSize: 20, color: selected ? color : AppColors.muted,
                                )),
                                const SizedBox(height: 2),
                                Text(ch.romaji, style: TextStyle(
                                  fontSize: 9, color: selected ? color : AppColors.muted,
                                )),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
            if (_selectLearnedMode)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: AppColors.bg,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedForLearned.isEmpty
                        ? AppColors.pillBg : AppColors.correct,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _selectedForLearned.isEmpty ? null : _confirmMarkSelectedLearned,
                    child: Text(
                      _selectedForLearned.isEmpty
                        ? 'Select characters to mark learned'
                        : 'Mark ${_selectedForLearned.length} as learned',
                      style: TextStyle(color: AppColors.bg, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ]),
    );
  }
}
