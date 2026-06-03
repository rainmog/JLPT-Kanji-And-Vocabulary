import 'package:flutter/material.dart';
import '../repositories/history_repository.dart';
import '../theme.dart';

class TestHistoryScreen extends StatefulWidget {
  const TestHistoryScreen({super.key});

  @override
  State<TestHistoryScreen> createState() => _TestHistoryScreenState();
}

class _TestHistoryScreenState extends State<TestHistoryScreen> {
  List<TestHistoryEntry> _entries = [];
  String _filter = 'all';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await historyRepo.getHistory(
      testType: _filter == 'all' ? null : _filter,
    );
    if (mounted) setState(() { _entries = entries; _loading = false; });
  }

  void _setFilter(String f) {
    setState(() { _filter = f; _loading = true; });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('Test History', style: TextStyle(color: AppColors.fg)),
        iconTheme: IconThemeData(color: AppColors.fg),
      ),
      body: Column(children: [
        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            for (final (key, label) in [
              ('all', 'All'),
              ('jlpt', 'JLPT'),
              ('target_kanji', 'Kanji'),
              ('vocab', 'Vocab'),
            ]) ...[
              _FilterChip(label: label, selected: _filter == key,
                  onTap: () => _setFilter(key)),
              const SizedBox(width: 8),
            ],
          ]),
        ),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
                ? Center(child: Text('No history yet',
                    style: TextStyle(color: AppColors.muted)))
                : _HistoryList(entries: _entries)),
      ]),
    );
  }
}

// ── List grouped by date ──────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  final List<TestHistoryEntry> entries;
  const _HistoryList({required this.entries});

  @override
  Widget build(BuildContext context) {
    // Group by date string
    final groups = <String, List<TestHistoryEntry>>{};
    for (final e in entries) {
      final d = e.dateTime;
      final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      groups.putIfAbsent(key, () => []).add(e);
    }
    final dates = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: dates.fold<int>(0, (s, d) => s + 1 + (groups[d]?.length ?? 0)),
      itemBuilder: (context, idx) {
        int offset = 0;
        for (final date in dates) {
          if (idx == offset) {
            return _DateHeader(date: date);
          }
          offset++;
          final items = groups[date]!;
          if (idx < offset + items.length) {
            return _HistoryRow(entry: items[idx - offset]);
          }
          offset += items.length;
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final parts = date.split('-');
    final label = '${parts[0]} / ${parts[1]} / ${parts[2]}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
      child: Text(label, style: TextStyle(fontSize: 12, color: AppColors.muted,
          fontWeight: FontWeight.w600)),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  final TestHistoryEntry entry;
  const _HistoryRow({required this.entry});

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _expanded = false;

  IconData get _icon => switch (widget.entry.testType) {
    'jlpt' => Icons.assignment,
    'target_kanji' => Icons.translate,
    'vocab' => Icons.menu_book,
    _ => Icons.quiz,
  };

  Color get _scoreColor {
    final pct = widget.entry.percentage;
    if (pct >= 0.8) return AppColors.correct;
    if (pct >= 0.6) return AppColors.accentBright;
    return AppColors.incorrect;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final timeStr = '${e.dateTime.hour.toString().padLeft(2,'0')}:${e.dateTime.minute.toString().padLeft(2,'0')}';

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppColors.containerRadius),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(_icon, color: AppColors.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.label, style: TextStyle(color: AppColors.fg, fontSize: 15,
                    fontWeight: FontWeight.w500)),
                Text(timeStr, style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _scoreColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${e.score}/${e.total}',
                    style: TextStyle(color: _scoreColor, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.muted, size: 18),
            ]),
          ),
          if (_expanded) _DetailPanel(entry: e),
        ]),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final TestHistoryEntry entry;
  const _DetailPanel({required this.entry});

  @override
  Widget build(BuildContext context) {
    final detail = entry.detail;

    if (entry.testType == 'jlpt' && detail != null) {
      final sections = ['vocabulary', 'grammar', 'reading'];
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Column(children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          for (final s in sections)
            if (detail[s] != null) ...[
              _SectionBar(
                label: '${s[0].toUpperCase()}${s.substring(1)}',
                correct: (detail[s] as List)[0] as int,
                total: (detail[s] as List)[1] as int,
              ),
              const SizedBox(height: 6),
            ],
        ]),
      );
    }

    if (entry.testType == 'target_kanji' && detail != null) {
      final kanjis = detail['kanji'] as List? ?? [];
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Column(children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kanjis.map((item) {
              final ch = item[0] as String;
              final c = item[1] as int;
              final t = item[2] as int;
              final pass = t > 0 && c == t;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pass ? AppColors.correctBg : AppColors.incorrectBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(ch, style: TextStyle(
                    fontSize: 18, color: pass ? AppColors.correct : AppColors.incorrect)),
              );
            }).toList(),
          ),
        ]),
      );
    }

    return const SizedBox.shrink();
  }
}

class _SectionBar extends StatelessWidget {
  final String label;
  final int correct, total;
  const _SectionBar({required this.label, required this.correct, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : correct / total;
    final color = pct >= 0.8 ? AppColors.correct
        : pct >= 0.6 ? AppColors.accentBright
        : AppColors.incorrect;
    return Row(children: [
      SizedBox(width: 80, child: Text(label, style: TextStyle(color: AppColors.muted, fontSize: 13))),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: pct,
          backgroundColor: AppColors.btnBg,
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 8,
        ),
      )),
      const SizedBox(width: 8),
      Text('$correct/$total', style: TextStyle(color: AppColors.fg, fontSize: 13,
          fontWeight: FontWeight.w500)),
    ]);
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.btnBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
            color: selected ? AppColors.bg : AppColors.fg,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13)),
      ),
    );
  }
}
