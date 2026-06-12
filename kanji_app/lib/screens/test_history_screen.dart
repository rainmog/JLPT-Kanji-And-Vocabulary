import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/history_repository.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../widgets/k_setup.dart';

class TestHistoryScreen extends ConsumerStatefulWidget {
  final bool embedded;
  final String initialFilter;
  const TestHistoryScreen({
    super.key,
    this.embedded = false,
    this.initialFilter = 'all',
  });

  @override
  ConsumerState<TestHistoryScreen> createState() => _TestHistoryScreenState();
}

class _TestHistoryScreenState extends ConsumerState<TestHistoryScreen> {
  List<TestHistoryEntry> _entries = [];
  late String _filter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
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

  Widget _buildContent(ThemeColors colors) {
    return Column(children: [
      if (!widget.embedded)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: KBackHeader(title: 'Test History', colors: colors),
        )
      else
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Test History', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800,
              color: KDesign.ink(colors), letterSpacing: -0.4,
            )),
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.assignment_rounded, size: 14, color: KDesign.inkFaint(colors)),
              const SizedBox(width: 6),
              Text('Swipe right for JLPT Practice',
                style: TextStyle(fontSize: 12, color: KDesign.inkFaint(colors))),
            ]),
            const SizedBox(height: 6),
          ]),
        ),

      // Filter chips — when embedded in JLPT context, hide kanji/vocab types
      SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            for (final (key, label) in [
              ('all', 'All'),
              ('jlpt', 'JLPT'),
              if (!widget.embedded) ...const [
                ('target_kanji', 'Kanji'),
                ('vocab', 'Vocab'),
              ],
            ]) ...[
              _FilterChip(label: label, selected: _filter == key,
                  colors: colors, onTap: () => _setFilter(key)),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),

      const SizedBox(height: 4),

      Expanded(
        child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
            ? Center(
                child: Text('No history yet', style: TextStyle(
                  fontSize: 15, color: KDesign.inkFaint(colors),
                )),
              )
            : _HistoryList(entries: _entries, colors: colors),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ref.watch(themeColorsProvider);

    if (widget.embedded) return _buildContent(colors);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(child: _buildContent(colors)),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ThemeColors colors;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? colors.accent : KDesign.line(colors)),
          boxShadow: selected ? KDesign.shadowAccent(colors) : KDesign.shadowSm(colors),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: selected ? Colors.white : KDesign.inkSoft(colors),
        )),
      ),
    );
  }
}

// ── Grouped list ──────────────────────────────────────────────────────────────

class _HistoryList extends StatelessWidget {
  final List<TestHistoryEntry> entries;
  final ThemeColors colors;
  const _HistoryList({required this.entries, required this.colors});

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<TestHistoryEntry>>{};
    for (final e in entries) {
      final d = e.dateTime;
      final key = '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      groups.putIfAbsent(key, () => []).add(e);
    }
    final dates = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: dates.fold<int>(0, (s, d) => s + 1 + (groups[d]?.length ?? 0)),
      itemBuilder: (context, idx) {
        int offset = 0;
        for (final date in dates) {
          if (idx == offset) return _DateHeader(date: date, colors: colors);
          offset++;
          final items = groups[date]!;
          if (idx < offset + items.length) {
            return _HistoryRow(entry: items[idx - offset], colors: colors);
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
  final ThemeColors colors;
  const _DateHeader({required this.date, required this.colors});

  @override
  Widget build(BuildContext context) {
    final parts = date.split('-');
    final label = '${parts[0]} / ${parts[1]} / ${parts[2]}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Text(label, style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w700,
        letterSpacing: 0.8, color: KDesign.inkFaint(colors),
      )),
    );
  }
}

class _HistoryRow extends StatefulWidget {
  final TestHistoryEntry entry;
  final ThemeColors colors;
  const _HistoryRow({required this.entry, required this.colors});

  @override
  State<_HistoryRow> createState() => _HistoryRowState();
}

class _HistoryRowState extends State<_HistoryRow> {
  bool _expanded = false;

  IconData get _icon => switch (widget.entry.testType) {
    'jlpt' => Icons.assignment_rounded,
    'target_kanji' => Icons.translate_rounded,
    'vocab' => Icons.menu_book_rounded,
    _ => Icons.quiz_rounded,
  };

  Color _scoreColor(ThemeColors c) {
    final pct = widget.entry.percentage;
    if (pct >= 0.8) return c.correct;
    if (pct >= 0.6) return c.accentBright;
    return c.incorrect;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final c = widget.colors;
    final sc = _scoreColor(c);
    final timeStr = '${e.dateTime.hour.toString().padLeft(2,'0')}:${e.dateTime.minute.toString().padLeft(2,'0')}';

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KDesign.line(c)),
          boxShadow: KDesign.shadowSm(c),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: KDesign.tint(c),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_icon, size: 18, color: c.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.label, style: TextStyle(
                    color: KDesign.ink(c), fontSize: 14.5, fontWeight: FontWeight.w700,
                  )),
                  Text(timeStr, style: TextStyle(color: KDesign.inkFaint(c), fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${e.score}/${e.total}', style: TextStyle(
                  color: sc, fontWeight: FontWeight.w800, fontSize: 13.5,
                )),
              ),
              const SizedBox(width: 8),
              Icon(
                _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                color: KDesign.inkFaint(c), size: 18,
              ),
            ]),
          ),
          if (_expanded) _DetailPanel(entry: e, colors: c),
        ]),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  final TestHistoryEntry entry;
  final ThemeColors colors;
  const _DetailPanel({required this.entry, required this.colors});

  @override
  Widget build(BuildContext context) {
    final detail = entry.detail;
    final c = colors;

    if (entry.testType == 'jlpt' && detail != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(children: [
          Divider(height: 1, color: KDesign.line(c)),
          const SizedBox(height: 10),
          for (final s in ['vocabulary', 'grammar', 'reading'])
            if (detail[s] != null) ...[
              _SectionBar(
                label: '${s[0].toUpperCase()}${s.substring(1)}',
                correct: (detail[s] as List)[0] as int,
                total: (detail[s] as List)[1] as int,
                colors: c,
              ),
              const SizedBox(height: 6),
            ],
        ]),
      );
    }

    if (entry.testType == 'target_kanji' && detail != null) {
      final kanjis = detail['kanji'] as List? ?? [];
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Column(children: [
          Divider(height: 1, color: KDesign.line(c)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: kanjis.map((item) {
              final ch = item[0] as String;
              final correct = item[1] as int;
              final total = item[2] as int;
              final pass = total > 0 && correct == total;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pass ? c.correctBg : c.incorrectBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(ch, style: TextStyle(
                  fontSize: 18, color: pass ? c.correct : c.incorrect,
                )),
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
  final ThemeColors colors;
  const _SectionBar({required this.label, required this.correct, required this.total, required this.colors});

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final pct = total == 0 ? 0.0 : correct / total;
    final color = pct >= 0.8 ? c.correct : pct >= 0.6 ? c.accentBright : c.incorrect;
    return Row(children: [
      SizedBox(
        width: 80,
        child: Text(label, style: TextStyle(
          color: KDesign.inkSoft(c), fontSize: 13, fontWeight: FontWeight.w600,
        )),
      ),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: KDesign.soft(c),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Text('$correct/$total', style: TextStyle(
        color: KDesign.ink(c), fontSize: 13, fontWeight: FontWeight.w700,
      )),
    ]);
  }
}
