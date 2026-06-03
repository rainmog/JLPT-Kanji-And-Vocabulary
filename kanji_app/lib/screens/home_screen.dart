import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/kanji_repository.dart';
import '../repositories/kana_repository.dart';
import '../repositories/vocab_repository.dart';
import '../services/settings_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../theme/sakura_theme_v2.dart';
import '../utils/app_route.dart';
import '../theme/app_theme_backgrounds.dart';
import '../widgets/sakura_overlay.dart';
import '../widgets/scale_on_press.dart';
import 'review_screen.dart';
import 'select_target_kanji_screen.dart';
import 'select_vocab_screen.dart';
import 'about_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'target_practice_config_screen.dart';
import 'test_intro_screen.dart';
import 'untargeted_practice_screen.dart';
import 'vocab_practice_config_screen.dart';
import 'jlpt_test_intro_screen.dart';
import 'kana_practice_config_screen.dart';
import 'select_target_kana_screen.dart';
import 'vocab_test_intro_screen.dart';
import 'test_history_screen.dart';

final _heroKanjiProvider = FutureProvider.autoDispose((ref) async {
  final target = await kanjiRepo.getRandomTarget();
  if (target != null) return target;
  final learned = await kanjiRepo.getRandomLearned();
  if (learned != null) return learned;
  return kanjiRepo.getRandomAny();
});

final _kanjiProgressProvider = FutureProvider.autoDispose<({int learned, int total, String label})>((ref) async {
  final target = ref.watch(settingsProvider).homeKanjiProgress;
  final progress = await kanjiRepo.getProgressByLevel();
  if (target != 'total') {
    final level = int.tryParse(target.replaceAll('N', ''));
    if (level != null) {
      final p = progress[level];
      if (p != null) return (learned: p.learned, total: p.total, label: 'N$level Kanji Progress');
    }
  }
  int learned = 0, total = 0;
  for (final e in progress.values) { learned += e.learned; total += e.total; }
  return (learned: learned, total: total, label: 'Total Kanji Progress');
});

final _kanaProgressProvider = FutureProvider.autoDispose<({int learned, int total})>((ref) async {
  final h = await kanaRepo.getProgress(type: 'hiragana');
  final k = await kanaRepo.getProgress(type: 'katakana');
  return (learned: h.learned + k.learned, total: h.total + k.total);
});

final _vocabProgressProvider = FutureProvider.autoDispose<({int learned, int total, String label})>((ref) async {
  final target = ref.watch(settingsProvider).homeVocabProgress;
  final progress = await vocabRepo.getProgressByLevel();
  if (target != 'total') {
    final level = int.tryParse(target.replaceAll('N', ''));
    if (level != null) {
      final p = progress[level];
      if (p != null) return (learned: p.learned, total: p.total, label: 'N$level Vocabulary Progress');
    }
  }
  int learned = 0, total = 0;
  for (final e in progress.values) { learned += e.learned; total += e.total; }
  return (learned: learned, total: total, label: 'Total Vocabulary Progress');
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _kanjiOpen = false;
  bool _vocabOpen = false;
  bool _kanaOpen = false;
  bool _jlptOpen = false;

  void _toggleKanji() => setState(() {
    _kanjiOpen = !_kanjiOpen;
    if (_kanjiOpen) { _vocabOpen = false; _kanaOpen = false; _jlptOpen = false; }
  });

  void _toggleVocab() => setState(() {
    _vocabOpen = !_vocabOpen;
    if (_vocabOpen) { _kanjiOpen = false; _kanaOpen = false; _jlptOpen = false; }
  });

  void _toggleKana() => setState(() {
    _kanaOpen = !_kanaOpen;
    if (_kanaOpen) { _kanjiOpen = false; _vocabOpen = false; _jlptOpen = false; }
  });

  void _toggleJlpt() => setState(() {
    _jlptOpen = !_jlptOpen;
    if (_jlptOpen) { _kanjiOpen = false; _vocabOpen = false; _kanaOpen = false; }
  });

  @override
  Widget build(BuildContext context) {
    ref.watch(themeColorsProvider);
    final hero = ref.watch(_heroKanjiProvider);
    final totalProgress = ref.watch(_kanjiProgressProvider);
    final vocabProgress = ref.watch(_vocabProgressProvider);
    final kanaProgress = ref.watch(_kanaProgressProvider);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final anim = settings.animationsEnabled;

    return Scaffold(
      body: Stack(children: [
        const HomeBgLayer(),
        const SakuraPetalsOverlay(),
        SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SingleChildScrollView(child: Column(
            children: [
              // Hero kanji
              GestureDetector(
                onTap: () => ref.invalidate(_heroKanjiProvider),
                child: AnimatedSwitcher(
                  duration: anim ? const Duration(milliseconds: 200) : Duration.zero,
                  child: hero.when(
                    data: (k) {
                      if (k == null) {
                        return Text('漢', key: const ValueKey('fallback'),
                          style: TextStyle(fontSize: 80, color: AppColors.kanjiColor));
                      }
                      return Column(key: ValueKey(k.character), children: [
                        Text(k.character, style: TextStyle(fontSize: 80, color: AppColors.kanjiColor)),
                        const SizedBox(height: 4),
                        Text('${k.onReading} / ${k.kunReading}',
                            style: TextStyle(fontSize: 14, color: AppColors.muted)),
                        const SizedBox(height: 2),
                        Text(k.meaning, style: TextStyle(fontSize: 14, color: AppColors.muted)),
                      ]);
                    },
                    loading: () => Text('漢', key: const ValueKey('loading'),
                      style: TextStyle(fontSize: 80, color: AppColors.kanjiColor)),
                    error: (_, __) => Text('漢', key: const ValueKey('error'),
                      style: TextStyle(fontSize: 80, color: AppColors.kanjiColor)),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Progress bars
              const SizedBox(height: 8),
              totalProgress.when(
                data: (p) => _ProgressBar(label: p.label, learned: p.learned, total: p.total),
                loading: () => const SizedBox(height: 20),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 10),
              vocabProgress.when(
                data: (p) => _ProgressBar(label: p.label, learned: p.learned, total: p.total),
                loading: () => const SizedBox(height: 20),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 20),

              // ── Kanji accordion ───────────────────────────────────────
              _AccordionSection(
                label: 'Kanji',
                isOpen: _kanjiOpen,
                onTap: _toggleKanji,
                children: [
                  _SubNavButton(label: 'Practice', onTap: () =>
                    Navigator.push(context, AppRoute.to(const TargetPracticeConfigScreen()))),
                  _SubNavRow(buttons: [
                    (label: 'Select Targets', onTap: () =>
                      Navigator.push(context, AppRoute.to(const SelectTargetKanjiScreen()))),
                    (label: 'Test', onTap: () =>
                      Navigator.push(context, AppRoute.to(const TestIntroScreen()))),
                  ]),
                ],
              ),
              const SizedBox(height: 8),

              // ── Vocabulary accordion ──────────────────────────────────
              _AccordionSection(
                label: 'Vocabulary',
                isOpen: _vocabOpen,
                onTap: _toggleVocab,
                children: [
                  _SubNavButton(label: 'Practice', onTap: () =>
                    Navigator.push(context, AppRoute.to(const VocabPracticeConfigScreen()))),
                  _SubNavRow(buttons: [
                    (label: 'Select Targets', onTap: () =>
                      Navigator.push(context, AppRoute.to(const SelectVocabScreen()))),
                    (label: 'Test', onTap: () =>
                      Navigator.push(context, AppRoute.to(const VocabTestIntroScreen()))),
                  ]),
                ],
              ),
              const SizedBox(height: 8),

              const SizedBox(height: 8),

              // ── Hiragana & Katakana accordion ─────────────────────────
              if (!settings.hideKanaPractice) ...[
                _AccordionSection(
                  label: 'Hiragana & Katakana',
                  isOpen: _kanaOpen,
                  onTap: _toggleKana,
                  children: [
                    _SubNavRow(buttons: [
                      (label: 'Hiragana', onTap: () =>
                        Navigator.push(context, AppRoute.to(const KanaPracticeConfigScreen(type: 'hiragana')))
                          .then((_) => ref.invalidate(_kanaProgressProvider))),
                      (label: 'Katakana', onTap: () =>
                        Navigator.push(context, AppRoute.to(const KanaPracticeConfigScreen(type: 'katakana')))
                          .then((_) => ref.invalidate(_kanaProgressProvider))),
                    ]),
                    _SubNavRow(buttons: [
                      (label: 'Targets (H)', onTap: () =>
                        Navigator.push(context, AppRoute.to(const SelectTargetKanaScreen(type: 'hiragana')))
                          .then((_) => ref.invalidate(_kanaProgressProvider))),
                      (label: 'Targets (K)', onTap: () =>
                        Navigator.push(context, AppRoute.to(const SelectTargetKanaScreen(type: 'katakana')))
                          .then((_) => ref.invalidate(_kanaProgressProvider))),
                    ]),
                    kanaProgress.when(
                      data: (p) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: _ProgressBar(
                          label: 'Kana Learned',
                          learned: p.learned,
                          total: p.total,
                        ),
                      ),
                      loading: () => const SizedBox(height: 20),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // ── JLPT Practice Tests accordion ─────────────────────────
              _AccordionSection(
                label: 'JLPT Practice Tests',
                isOpen: _jlptOpen,
                onTap: _toggleJlpt,
                children: [
                  _JlptLevelRow(
                    levels: const [5, 4, 3, 2, 1],
                    onTap: (level) => Navigator.push(
                      context,
                      AppRoute.to(JlptTestIntroScreen(level: level)),
                    ),
                  ),
                  _SubNavButton(label: 'Test History',
                      onTap: () => Navigator.push(context, AppRoute.to(const TestHistoryScreen()))),
                ],
              ),

              // ── Divider ───────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Divider(color: AppColors.pillBg, thickness: 1),
              ),

              // ── General buttons ───────────────────────────────────────
              _NavButton(label: 'Dictionary', onTap: () =>
                Navigator.push(context, AppRoute.to(const StatsScreen()))),
              const SizedBox(height: 8),
              _NavButton(label: 'Untargeted Practice', onTap: () =>
                Navigator.push(context, AppRoute.to(const UntargetedPracticeScreen()))),
              const SizedBox(height: 8),
              _NavButton(label: 'Review', onTap: () =>
                Navigator.push(context, AppRoute.to(const ReviewScreen()))),
              const SizedBox(height: 8),
              _NavButton(label: 'Settings', onTap: () =>
                Navigator.push(context, AppRoute.to(const SettingsScreen()))),
              const SizedBox(height: 8),
              _NavButton(label: 'About', onTap: () => Navigator.push(context, AppRoute.to(const AboutScreen()))),
              const SizedBox(height: 16),
            ],
          )),
        ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 12),
              child: Row(children: [
                _AudioToggle(
                  icon: settings.sfxEnabled ? Icons.volume_up : Icons.volume_off,
                  active: settings.sfxEnabled,
                  tooltip: settings.sfxEnabled ? 'SFX on' : 'SFX off',
                  onTap: () {
                    final updated = settings.copyWith(sfxEnabled: !settings.sfxEnabled);
                    settingsNotifier.update(updated);
                    soundService.sfxEnabled = updated.sfxEnabled;
                  },
                ),
                const SizedBox(width: 2),
                _AudioToggle(
                  icon: settings.ambientEnabled ? Icons.music_note : Icons.music_off,
                  active: settings.ambientEnabled,
                  tooltip: settings.ambientEnabled ? 'Ambient on' : 'Ambient off',
                  onTap: () {
                    final updated = settings.copyWith(ambientEnabled: !settings.ambientEnabled);
                    settingsNotifier.update(updated);
                    soundService.ambientEnabled = updated.ambientEnabled;
                    if (!updated.ambientEnabled) {
                      soundService.stopAmbient();
                    } else if (settings.ambientSfx != 'none') {
                      soundService.setAmbient(settings.ambientSfx);
                    }
                  },
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _AudioToggle extends StatelessWidget {
  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _AudioToggle({
    required this.icon,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 20, color: active ? AppColors.accent : AppColors.muted),
        ),
      ),
    );
  }
}

class _AccordionSection extends StatelessWidget {
  final String label;
  final bool isOpen;
  final VoidCallback onTap;
  final List<Widget> children;

  const _AccordionSection({
    required this.label,
    required this.isOpen,
    required this.onTap,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      ScaleOnPress(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isOpen ? AppColors.accent : AppColors.btnBg,
              foregroundColor: isOpen
                ? (AppColors.accent.computeLuminance() > 0.6 ? AppColors.fg : AppColors.bg)
                : AppColors.kanjiColor,
            ),
            onPressed: onTap,
            child: Row(
              children: [
                const SizedBox(width: 20),
                Expanded(child: Text(label, textAlign: TextAlign.center)),
                Icon(isOpen ? Icons.expand_less : Icons.expand_more, size: 20),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: isOpen
          ? Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: children.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: c,
                )).toList(),
              ),
            )
          : const SizedBox.shrink(),
      ),
    ]);
  }
}

class _SubNavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SubNavButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: ScaleOnPress(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            onPressed: () { soundService.playSelectButton(); onTap(); },
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _NavButton({required this.label, required this.onTap});

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

class _SubNavRow extends StatelessWidget {
  final List<({String label, VoidCallback onTap})> buttons;
  const _SubNavRow({required this.buttons});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          for (int i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: ScaleOnPress(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () { soundService.playSelectButton(); buttons[i].onTap(); },
                  child: Text(buttons[i].label),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _JlptLevelRow extends StatelessWidget {
  final List<int> levels;
  final void Function(int level) onTap;
  const _JlptLevelRow({required this.levels, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          for (int i = 0; i < levels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: ScaleOnPress(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () { soundService.playSelectButton(); onTap(levels[i]); },
                  child: Text('${levels[i]}'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressBar extends ConsumerWidget {
  final String label;
  final int learned, total;
  const _ProgressBar({required this.label, required this.learned, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anim = ref.watch(settingsProvider).animationsEnabled;
    final isSakura = ref.watch(themeNotifier) == AppTheme.sakura;
    final target = total == 0 ? 0.0 : learned / total;
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 16, color: AppColors.muted)),
        Text('$learned / $total', style: TextStyle(fontSize: 16, color: AppColors.accentBright)),
      ]),
      const SizedBox(height: 4),
      TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: target),
        duration: anim ? const Duration(milliseconds: 900) : Duration.zero,
        curve: Curves.easeOut,
        builder: (_, value, __) {
          if (isSakura) return SakuraProgressBar(value: value, height: 8);
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.containerRadius),
            child: LinearProgressIndicator(
              value: value, minHeight: 8,
              backgroundColor: AppColors.pillBg,
              valueColor: AlwaysStoppedAnimation(AppColors.accentBright),
            ),
          );
        },
      ),
    ]);
  }
}
