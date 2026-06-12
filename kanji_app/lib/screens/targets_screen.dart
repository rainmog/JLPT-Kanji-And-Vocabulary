import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/kana_repository.dart';
import '../repositories/vocab_repository.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/k_setup.dart';
import 'select_target_kanji_screen.dart';
import 'select_target_kana_screen.dart';
import 'vocab_list_screen.dart';

// ── Progress data provider ────────────────────────────────────────────────────

final _levelProgressProvider = FutureProvider.autoDispose<({
  Map<int, ({int learned, int total})> kanji,
  Map<int, ({int learned, int total})> vocab,
  ({int learned, int targeted, int total}) kanaHira,
  ({int learned, int targeted, int total}) kanaKata,
})>((ref) async {
  final kanjiStatus = await kanjiRepo.getAllKanjiWithStatus();
  final kanjiProgress = <int, ({int learned, int total})>{};
  for (final entry in kanjiStatus.entries) {
    final list = entry.value;
    kanjiProgress[entry.key] = (
      learned: list.where((e) => e.$2 == 'learned').length,
      total: list.length,
    );
  }
  final vocabProgress = await vocabRepo.getProgressByLevel();
  final vocabMap = vocabProgress.map((k, v) => MapEntry(k, (learned: v.learned, total: v.total)));
  final hira = await kanaRepo.getProgress(type: 'hiragana');
  final kata = await kanaRepo.getProgress(type: 'katakana');
  return (kanji: kanjiProgress, vocab: vocabMap, kanaHira: hira, kanaKata: kata);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class TargetsScreen extends ConsumerWidget {
  const TargetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final progressAsync = ref.watch(_levelProgressProvider);

    Map<int, ({int learned, int total})> kanjiProgress = {};
    Map<int, ({int learned, int total})> vocabProgress = {};
    ({int learned, int targeted, int total}) kanaHira = (learned: 0, targeted: 0, total: 46);
    ({int learned, int targeted, int total}) kanaKata = (learned: 0, targeted: 0, total: 46);
    progressAsync.whenData((p) {
      kanjiProgress = p.kanji;
      vocabProgress = p.vocab;
      kanaHira = p.kanaHira;
      kanaKata = p.kanaKata;
    });

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: KBackHeader(title: 'Your Targets', colors: colors),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Daily goal ──────────────────────────────────────────
                KSectionLabel(text: 'Daily goal', colors: colors),
                _GoalStepper(
                  value: settings.dailyGoal,
                  colors: colors,
                  onChanged: (v) => notifier.update(settings.copyWith(dailyGoal: v)),
                ),

                // ── Kanji targets ───────────────────────────────────────
                KSectionLabel(text: 'Kanji targets', colors: colors),
                _LevelGrid(
                  levels: const [5, 4, 3, 2, 1],
                  progress: kanjiProgress,
                  colors: colors,
                  onTap: (level) => Navigator.push(context, AppRoute.to(
                    KanjiGridScreen(level: level, tag: null),
                  )),
                ),

                // ── Vocabulary targets ──────────────────────────────────
                KSectionLabel(text: 'Vocabulary targets', colors: colors),
                _LevelGrid(
                  levels: const [5, 4, 3, 2, 1],
                  progress: vocabProgress,
                  colors: colors,
                  onTap: (level) => Navigator.push(context, AppRoute.to(
                    VocabListScreen(filter: VocabFilter.level(level)),
                  )),
                ),

                // ── Kana targets ────────────────────────────────────────
                KSectionLabel(text: 'Kana targets', colors: colors),
                Row(children: [
                  _KanaBtn(
                    label: 'Hiragana',
                    learned: kanaHira.learned,
                    total: kanaHira.total,
                    colors: colors,
                    onTap: () => Navigator.push(context, AppRoute.to(
                      const SelectTargetKanaScreen(type: 'hiragana'),
                    )),
                  ),
                  const SizedBox(width: 10),
                  _KanaBtn(
                    label: 'Katakana',
                    learned: kanaKata.learned,
                    total: kanaKata.total,
                    colors: colors,
                    onTap: () => Navigator.push(context, AppRoute.to(
                      const SelectTargetKanaScreen(type: 'katakana'),
                    )),
                  ),
                ]),

                // ── Info ────────────────────────────────────────────────
                const SizedBox(height: 18),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: KDesign.inkFaint(colors)),
                  const SizedBox(width: 7),
                  Text('Tap a set to choose what to study.', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: KDesign.inkFaint(colors),
                  )),
                ]),
              ]),
            ),
          ),

          KStickyFooter(
            colors: colors,
            child: KStartButton(
              label: 'Save Targets',
              colors: colors,
              onTap: () {
                soundService.playSelectButton();
                Navigator.pop(context);
              },
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Daily goal stepper ────────────────────────────────────────────────────────

class _GoalStepper extends StatelessWidget {
  final int value;
  final ThemeColors colors;
  final void Function(int) onChanged;
  const _GoalStepper({required this.value, required this.colors, required this.onChanged});

  String get _estimate {
    final mins = (value * 0.5).round();
    final rounded = (mins / 5).round() * 5;
    return '~$rounded min/day';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: KDesign.line(colors)),
        boxShadow: KDesign.shadowSm(colors),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 23),
      child: Row(children: [
        // Minus
        _StepBtn(
          icon: Icons.remove_rounded,
          enabled: value > 5,
          colors: colors,
          onTap: () => onChanged((value - 5).clamp(5, 100)),
        ),
        // Number + estimate
        Expanded(
          child: Column(children: [
            Text('$value', style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w800,
              color: KDesign.ink(colors), letterSpacing: -1, height: 1,
            )),
            const SizedBox(height: 4),
            Text(_estimate, style: TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w600,
              color: KDesign.inkSoft(colors),
            )),
          ]),
        ),
        // Plus
        _StepBtn(
          icon: Icons.add_rounded,
          enabled: value < 100,
          colors: colors,
          onTap: () => onChanged((value + 5).clamp(5, 100)),
        ),
      ]),
    );
  }
}

class _StepBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final ThemeColors colors;
  final VoidCallback onTap;
  const _StepBtn({required this.icon, required this.enabled, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: enabled ? KDesign.tint(colors) : colors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: KDesign.line(colors)),
        ),
        child: Icon(icon, size: 22, color: enabled ? colors.accent : KDesign.inkFaint(colors)),
      ),
    );
  }
}

// ── N-level grid of 5 buttons ─────────────────────────────────────────────────

class _LevelGrid extends StatelessWidget {
  final List<int> levels;
  final Map<int, ({int learned, int total})> progress;
  final ThemeColors colors;
  final void Function(int) onTap;
  const _LevelGrid({required this.levels, required this.progress, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: levels.map((n) {
        final p = progress[n];
        final isDone = p != null && p.total > 0 && p.learned == p.total;
        final last = n == levels.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: last ? 0 : 8),
            child: _LevelBtn(
              label: 'N$n',
              isDone: isDone,
              colors: colors,
              onTap: () => onTap(n),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _LevelBtn extends StatefulWidget {
  final String label;
  final bool isDone;
  final ThemeColors colors;
  final VoidCallback onTap;
  const _LevelBtn({required this.label, required this.isDone, required this.colors, required this.onTap});

  @override
  State<_LevelBtn> createState() => _LevelBtnState();
}

class _LevelBtnState extends State<_LevelBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final done = widget.isDone;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: done ? KDesign.goldSoft : c.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: done ? KDesign.gold : KDesign.line(c),
              width: done ? 2.0 : 1.0,
            ),
            boxShadow: KDesign.shadowSm(c),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (done)
                const Icon(Icons.star_rounded, size: 14, color: KDesign.gold)
              else
                const SizedBox(height: 14),
              Text(widget.label, style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800,
                color: done ? KDesign.gold : KDesign.ink(c),
              )),
              Text(
                done ? 'Done' : '',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: done ? KDesign.gold : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Kana button (wider, two per row) ─────────────────────────────────────────

class _KanaBtn extends StatefulWidget {
  final String label;
  final int learned, total;
  final ThemeColors colors;
  final VoidCallback onTap;
  const _KanaBtn({required this.label, required this.learned, required this.total, required this.colors, required this.onTap});

  @override
  State<_KanaBtn> createState() => _KanaBtnState();
}

class _KanaBtnState extends State<_KanaBtn> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final done = widget.total > 0 && widget.learned == widget.total;

    return Expanded(
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: done ? KDesign.goldSoft : c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: done ? KDesign.gold : KDesign.line(c),
                width: done ? 2.0 : 1.0,
              ),
              boxShadow: KDesign.shadowSm(c),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (done)
                  const Icon(Icons.star_rounded, size: 14, color: KDesign.gold)
                else
                  const SizedBox(height: 14),
                Text(widget.label, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800,
                  color: done ? KDesign.gold : KDesign.ink(c),
                )),
                Text(
                  done ? 'Done' : '',
                  style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700,
                    color: done ? KDesign.gold : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
