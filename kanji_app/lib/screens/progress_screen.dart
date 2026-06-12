import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/kana_repository.dart';
import '../repositories/progress_repository.dart';
import '../repositories/vocab_repository.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../theme/app_theme_backgrounds.dart';
import '../widgets/sakura_overlay.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _kanjiProgressProvider = FutureProvider.autoDispose<({
  Map<int, ({int learned, int total})> byLevel,
  Map<String, ({int learned, int total})> byTag,
})>((_) async {
  final byLevel = await kanjiRepo.getProgressByLevel();
  final byTag   = await kanjiRepo.getProgressByTag();
  return (byLevel: byLevel, byTag: byTag);
});

final _vocabProgressProvider = FutureProvider.autoDispose<({
  Map<int, ({int learned, int total})> byLevel,
  Map<String, ({int learned, int total})> byTag,
})>((_) async {
  final byLevel = await vocabRepo.getProgressByLevel();
  final byTag   = await vocabRepo.getProgressByTag();
  return (byLevel: byLevel, byTag: byTag);
});

final _kanaProgressProvider = FutureProvider.autoDispose<({
  ({int learned, int targeted, int total}) hiragana,
  ({int learned, int targeted, int total}) katakana,
})>((_) async {
  final hiragana = await kanaRepo.getProgress(type: 'hiragana');
  final katakana = await kanaRepo.getProgress(type: 'katakana');
  return (hiragana: hiragana, katakana: katakana);
});

final _totalQuestionsProvider = FutureProvider.autoDispose<int>(
  (_) async => progressRepo.getTotalAllTimeQuestionCount(),
);

// ── Screen ────────────────────────────────────────────────────────────────────

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final kanjiAsync = ref.watch(_kanjiProgressProvider);
    final vocabAsync = ref.watch(_vocabProgressProvider);
    final kanaAsync = ref.watch(_kanaProgressProvider);
    final totalQuestionsAsync = ref.watch(_totalQuestionsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(children: [
        const Positioned.fill(child: HomeBgLayer()),
        const Positioned.fill(child: SakuraPetalsOverlay()),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                Text(
                  'Progress',
                  style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w800,
                    color: KDesign.ink(colors), letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 20),

                // Dual rings
                kanjiAsync.when(
                  data: (k) => vocabAsync.when(
                    data: (v) => _DualRingsCard(
                      kanjiLearned: k.byLevel.values.fold(0, (s, e) => s + e.learned),
                      kanjiTotal:   k.byLevel.values.fold(0, (s, e) => s + e.total),
                      vocabLearned: v.byLevel.values.fold(0, (s, e) => s + e.learned),
                      vocabTotal:   v.byLevel.values.fold(0, (s, e) => s + e.total),
                      colors: colors,
                    ),
                    loading: () => _skeletonCard(colors),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  loading: () => _skeletonCard(colors),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),

                // Kanji by level
                _SectionLabel(label: 'KANJI BY JLPT LEVEL', colors: colors),
                const SizedBox(height: 8),
                kanjiAsync.when(
                  data: (k) => _LevelBreakdownCard(
                    byLevel: k.byLevel,
                    colors: colors,
                    isKanji: true,
                    onGroupsTap: () => _showTagGroups(context, k.byTag, colors, 'Kanji'),
                  ),
                  loading: () => _skeletonCard(colors, height: 240),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),

                // Vocab by level
                _SectionLabel(label: 'VOCABULARY BY JLPT LEVEL', colors: colors),
                const SizedBox(height: 8),
                vocabAsync.when(
                  data: (v) => _LevelBreakdownCard(
                    byLevel: v.byLevel,
                    colors: colors,
                    isKanji: false,
                    onGroupsTap: () => _showTagGroups(context, v.byTag, colors, 'Vocab'),
                  ),
                  loading: () => _skeletonCard(colors, height: 280),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),

                // Kana
                _SectionLabel(label: 'KANA', colors: colors),
                const SizedBox(height: 8),
                kanaAsync.when(
                  data: (k) => _KanaCard(
                    hiragana: k.hiragana,
                    katakana: k.katakana,
                    colors: colors,
                  ),
                  loading: () => _skeletonCard(colors, height: 110),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),

                // Total questions
                totalQuestionsAsync.when(
                  data: (total) => _TotalQuestionsCard(total: total, colors: colors),
                  loading: () => _skeletonCard(colors, height: 60),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _skeletonCard(ThemeColors colors, {double height = 120}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KDesign.line(colors)),
      ),
    );
  }

  void _showTagGroups(
    BuildContext context,
    Map<String, ({int learned, int total})> byTag,
    ThemeColors colors,
    String label,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TagGroupsSheet(byTag: byTag, colors: colors, label: label),
    );
  }
}

// ── Dual rings card ───────────────────────────────────────────────────────────

class _DualRingsCard extends StatelessWidget {
  final int kanjiLearned, kanjiTotal, vocabLearned, vocabTotal;
  final ThemeColors colors;

  const _DualRingsCard({
    required this.kanjiLearned, required this.kanjiTotal,
    required this.vocabLearned, required this.vocabTotal,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KDesign.line(colors)),
        boxShadow: KDesign.shadowSm(colors),
      ),
      child: Row(children: [
        Expanded(child: _Ring(
          label: 'Kanji',
          learned: kanjiLearned,
          total: kanjiTotal,
          color: colors.accent,
          colors: colors,
        )),
        Container(width: 1, height: 80, color: KDesign.line(colors)),
        Expanded(child: _Ring(
          label: 'Vocab',
          learned: vocabLearned,
          total: vocabTotal,
          color: const Color(0xFF4E9D69),
          colors: colors,
        )),
      ]),
    );
  }
}

class _Ring extends StatelessWidget {
  final String label;
  final int learned, total;
  final Color color;
  final ThemeColors colors;

  const _Ring({
    required this.label, required this.learned, required this.total,
    required this.color, required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    const size = 72.0, stroke = 7.0;
    final pct = total == 0 ? 0.0 : (learned / total).clamp(0.0, 1.0);
    final pctLabel = total == 0 ? '0%' : '${(pct * 100).round()}%';
    return Column(children: [
      SizedBox(
        width: size, height: size,
        child: Stack(alignment: Alignment.center, children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _RingPainter(pct: pct, color: color, stroke: stroke),
          ),
          Text(
            pctLabel,
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800,
              color: KDesign.ink(colors),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      Text(
        label,
        style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: KDesign.ink(colors),
        ),
      ),
      const SizedBox(height: 2),
      Text(
        '$learned / $total',
        style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: KDesign.inkSoft(colors),
        ),
      ),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  final double pct;
  final Color color;
  final double stroke;
  const _RingPainter({required this.pct, required this.color, required this.stroke});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = (size.width - stroke) / 2;
    final track = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(Offset(cx, cy), r, track);
    if (pct > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -math.pi / 2,
        2 * math.pi * pct,
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pct != pct || old.color != color;
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final ThemeColors colors;
  const _SectionLabel({required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11.5, fontWeight: FontWeight.w800,
        letterSpacing: 0.9, color: KDesign.inkSoft(colors),
      ),
    );
  }
}

// ── Level breakdown card ──────────────────────────────────────────────────────

class _LevelBreakdownCard extends StatelessWidget {
  final Map<int, ({int learned, int total})> byLevel;
  final ThemeColors colors;
  final bool isKanji;
  final VoidCallback onGroupsTap;

  const _LevelBreakdownCard({
    required this.byLevel,
    required this.colors,
    required this.isKanji,
    required this.onGroupsTap,
  });

  // JLPT levels in order N5→N1 (stored as 5→1 in DB)
  static const _levels = [5, 4, 3, 2, 1];
  static const _labels = ['N5', 'N4', 'N3', 'N2', 'N1'];

  @override
  Widget build(BuildContext context) {
    final line = KDesign.line(colors);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
        boxShadow: KDesign.shadowSm(colors),
      ),
      child: Column(
        children: [
          for (int i = 0; i < _levels.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: line),
            _LevelRow(
              label: _labels[i],
              data: byLevel[_levels[i]] ?? (learned: 0, total: 0),
              colors: colors,
            ),
          ],
          Divider(height: 1, thickness: 1, color: line),
          if (!isKanji) ...[
            _LevelRow(
              label: 'Other',
              data: byLevel[0] ?? (learned: 0, total: 0),
              colors: colors,
            ),
            Divider(height: 1, thickness: 1, color: line),
          ],
          // "Progress by other groups" button
          GestureDetector(
            onTap: onGroupsTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Progress by other groups',
                    style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700,
                      color: KDesign.inkSoft(colors),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(Icons.chevron_right_rounded, size: 16, color: KDesign.inkFaint(colors)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelRow extends StatelessWidget {
  final String label;
  final ({int learned, int total}) data;
  final ThemeColors colors;

  const _LevelRow({required this.label, required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    final pct = data.total == 0 ? 0.0 : (data.learned / data.total).clamp(0.0, 1.0);
    final done = data.learned == data.total && data.total > 0;
    final started = data.learned > 0;
    final badgeColor = done
        ? const Color(0xFF4E9D69)
        : started
            ? colors.accent
            : KDesign.inkFaint(colors).withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: done
                ? const Color(0xFF4E9D69).withValues(alpha: 0.14)
                : started
                    ? colors.accent.withValues(alpha: 0.12)
                    : KDesign.tint(colors),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w800,
              color: badgeColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label == 'Other' ? 'Other' : 'JLPT $label',
                  style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700,
                    color: KDesign.ink(colors),
                  ),
                ),
                Text(
                  '${data.learned} / ${data.total}',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: KDesign.inkSoft(colors),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: KDesign.tint(colors),
                valueColor: AlwaysStoppedAnimation(
                  done ? const Color(0xFF4E9D69) : colors.accent,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Kana card ─────────────────────────────────────────────────────────────────

class _KanaCard extends StatelessWidget {
  final ({int learned, int targeted, int total}) hiragana;
  final ({int learned, int targeted, int total}) katakana;
  final ThemeColors colors;

  const _KanaCard({
    required this.hiragana,
    required this.katakana,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final line = KDesign.line(colors);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
        boxShadow: KDesign.shadowSm(colors),
      ),
      child: Column(children: [
        _KanaRow(label: 'Hiragana', data: hiragana, colors: colors),
        Divider(height: 1, thickness: 1, color: line),
        _KanaRow(label: 'Katakana', data: katakana, colors: colors),
      ]),
    );
  }
}

class _KanaRow extends StatelessWidget {
  final String label;
  final ({int learned, int targeted, int total}) data;
  final ThemeColors colors;

  const _KanaRow({required this.label, required this.data, required this.colors});

  @override
  Widget build(BuildContext context) {
    final pct = data.total == 0 ? 0.0 : (data.learned / data.total).clamp(0.0, 1.0);
    final done = data.learned == data.total && data.total > 0;
    final started = data.learned > 0 || data.targeted > 0;
    final badgeColor = done
        ? const Color(0xFF4E9D69)
        : started
            ? colors.accent
            : KDesign.inkFaint(colors).withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: done
                ? const Color(0xFF4E9D69).withValues(alpha: 0.14)
                : started
                    ? colors.accent.withValues(alpha: 0.12)
                    : KDesign.tint(colors),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label == 'Hiragana' ? 'あ' : 'ア',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: badgeColor),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700,
                    color: KDesign.ink(colors),
                  ),
                ),
                Text(
                  '${data.learned} / ${data.total}',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: KDesign.inkSoft(colors),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: KDesign.tint(colors),
                valueColor: AlwaysStoppedAnimation(
                  done ? const Color(0xFF4E9D69) : colors.accent,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Total questions card ───────────────────────────────────────────────────────

class _TotalQuestionsCard extends StatelessWidget {
  final int total;
  final ThemeColors colors;

  const _TotalQuestionsCard({required this.total, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KDesign.line(colors)),
        boxShadow: KDesign.shadowSm(colors),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Questions Answered',
            style: TextStyle(
              fontSize: 13.5, fontWeight: FontWeight.w700,
              color: KDesign.ink(colors),
            ),
          ),
          Text(
            total.toString(),
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800,
              color: colors.accent, letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tag groups bottom sheet ────────────────────────────────────────────────────

class _TagGroupsSheet extends StatelessWidget {
  final Map<String, ({int learned, int total})> byTag;
  final ThemeColors colors;
  final String label;

  const _TagGroupsSheet({
    required this.byTag,
    required this.colors,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final entries = byTag.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));
    final line = KDesign.line(colors);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: line, borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(children: [
              Expanded(
                child: Text(
                  '$label by Group',
                  style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: KDesign.ink(colors), letterSpacing: -0.3,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close_rounded, size: 22, color: KDesign.inkSoft(colors)),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No group data yet.',
                style: TextStyle(color: KDesign.inkSoft(colors)),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: entries.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: line),
                itemBuilder: (context, i) {
                  final e = entries[i];
                  final pct = e.value.total == 0
                      ? 0.0
                      : (e.value.learned / e.value.total).clamp(0.0, 1.0);
                  final tagLabel = e.key[0].toUpperCase() + e.key.substring(1);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tagLabel,
                            style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: KDesign.ink(colors),
                            ),
                          ),
                          Text(
                            '${e.value.learned} / ${e.value.total}',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: KDesign.inkSoft(colors),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 5,
                          backgroundColor: KDesign.tint(colors),
                          valueColor: AlwaysStoppedAnimation(colors.accent),
                        ),
                      ),
                    ]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
