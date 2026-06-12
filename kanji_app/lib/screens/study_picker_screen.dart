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
import 'kana_practice_config_screen.dart';
import 'target_practice_config_screen.dart';
import 'vocab_practice_config_screen.dart';

final _pickerStatsProvider = FutureProvider.autoDispose<({
  int kanjiTargets, int kanjiLevel,
  int vocabTargets,
  int kanaHira, int kanaKata,
  bool allKanaLearned,
})>((ref) async {
  final kanjiTargets = await kanjiRepo.getTargetKanjiList().then((l) => l.length);
  final kanjiLevelData = await kanjiRepo.getActiveLevel();
  final kanjiLevel = kanjiLevelData?.level ?? 5;
  final vocabTargets = await vocabRepo.getTargetCount();
  final hira = await kanaRepo.getProgress(type: 'hiragana');
  final kata = await kanaRepo.getProgress(type: 'katakana');
  final bool allKanaLearned = await kanaRepo.allKanaLearned();
  return (
    kanjiTargets: kanjiTargets,
    kanjiLevel: kanjiLevel,
    vocabTargets: vocabTargets,
    kanaHira: hira.targeted,
    kanaKata: kata.targeted,
    allKanaLearned: allKanaLearned,
  );
});

class StudyPickerScreen extends ConsumerWidget {
  const StudyPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final stats = ref.watch(_pickerStatsProvider);

    final ink = KDesign.ink(colors);
    final inkSoft = KDesign.inkSoft(colors);
    final inkFaint = KDesign.inkFaint(colors);
    final line = KDesign.line(colors);
    final tint = KDesign.tint(colors);

    String kanjiSub = 'Compounds, sentences, readings';
    String kanjiCount = 'N5';
    String vocabSub = 'Words & phrases';
    String vocabCount = '0';
    String kanaSub = 'Hiragana & katakana';
    String kanaCount = '92';
    bool allKanaLearned = false;

    stats.whenData((s) {
      kanjiSub = '${s.kanjiTargets} target · practice mode';
      kanjiCount = 'N${s.kanjiLevel}';
      vocabSub = '${s.vocabTargets} target vocab';
      vocabCount = '${s.vocabTargets}';
      final total = s.kanaHira + s.kanaKata;
      kanaSub = '$total kana targeted';
      kanaCount = '${s.kanaHira + s.kanaKata}';
      allKanaLearned = s.allKanaLearned;
    });

    final modes = [
      if (!allKanaLearned)
        _StudyMode(
          id: 'kana',
          jp: 'あ',
          label: 'Kana',
          sub: kanaSub,
          count: kanaCount,
          primary: false,
        ),
      _StudyMode(
        id: 'kanji',
        jp: '字',
        label: 'Kanji',
        sub: kanjiSub,
        count: kanjiCount,
        primary: true,
      ),
      _StudyMode(
        id: 'vocab',
        jp: '語',
        label: 'Vocabulary',
        sub: vocabSub,
        count: vocabCount,
        primary: false,
      ),
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Row(children: [
                _BackBtn(colors: colors),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'What to study?',
                    style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w800,
                      color: ink, letterSpacing: -0.4,
                    ),
                  ),
                ),
                _AudioToggle(
                  icon: settings.sfxEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  active: settings.sfxEnabled,
                  colors: colors,
                  onTap: () {
                    final u = settings.copyWith(sfxEnabled: !settings.sfxEnabled);
                    settingsNotifier.update(u);
                    soundService.sfxEnabled = u.sfxEnabled;
                  },
                ),
                const SizedBox(width: 8),
                _AudioToggle(
                  icon: settings.ambientEnabled ? Icons.music_note_rounded : Icons.music_off_rounded,
                  active: settings.ambientEnabled,
                  colors: colors,
                  onTap: () {
                    final u = settings.copyWith(ambientEnabled: !settings.ambientEnabled);
                    settingsNotifier.update(u);
                    soundService.ambientEnabled = u.ambientEnabled;
                    if (!u.ambientEnabled) soundService.stopAmbient();
                    else if (settings.ambientSfx != 'none') soundService.setAmbient(settings.ambientSfx);
                  },
                ),
              ]),
            ),

            const SizedBox(height: 14),

            // Mode cards
            ...modes.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ModeCard(mode: m, colors: colors, onTap: () => _pick(context, m.id)),
            )),
          ]),
        ),
      ),
    );
  }

  void _pick(BuildContext context, String id) {
    soundService.playSelectButton();
    switch (id) {
      case 'kana':
        Navigator.push(context, AppRoute.to(const KanaPracticeConfigScreen(type: 'hiragana')));
      case 'kanji':
        Navigator.push(context, AppRoute.to(const TargetPracticeConfigScreen()));
      case 'vocab':
        Navigator.push(context, AppRoute.to(const VocabPracticeConfigScreen()));
    }
  }
}

class _StudyMode {
  final String id, jp, label, sub, count;
  final bool primary;
  const _StudyMode({
    required this.id, required this.jp, required this.label,
    required this.sub, required this.count, required this.primary,
  });
}

class _ModeCard extends StatefulWidget {
  final _StudyMode mode;
  final ThemeColors colors;
  final VoidCallback onTap;
  const _ModeCard({required this.mode, required this.colors, required this.onTap});

  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.mode;
    final c = widget.colors;
    final primary = m.primary;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          decoration: BoxDecoration(
            color: primary ? c.accent : c.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: primary ? c.accent : KDesign.line(c)),
            boxShadow: primary ? KDesign.shadowAccent(c) : KDesign.shadowSm(c),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            // JP badge
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: primary ? Colors.white.withValues(alpha: 0.18) : KDesign.tint(c),
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Text(
                m.jp,
                style: TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w600,
                  color: primary ? Colors.white : c.accent,
                  fontFamily: 'NotoSerifCJKjp',
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Text
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(m.label, style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: primary ? Colors.white : KDesign.ink(c),
                  letterSpacing: -0.2,
                )),
                const SizedBox(height: 2),
                Text(m.sub, style: TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600,
                  color: primary ? Colors.white.withValues(alpha: 0.85) : KDesign.inkSoft(c),
                )),
              ]),
            ),
            const SizedBox(width: 8),
            Text(m.count, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800,
              color: primary ? Colors.white.withValues(alpha: 0.92) : KDesign.inkFaint(c),
            )),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded, size: 20,
              color: primary ? Colors.white.withValues(alpha: 0.8) : KDesign.inkFaint(c),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BackBtn extends StatelessWidget {
  final ThemeColors colors;
  const _BackBtn({required this.colors});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: KDesign.chipRadius,
          border: Border.all(color: KDesign.line(colors)),
          boxShadow: KDesign.shadowSm(colors),
        ),
        child: Icon(Icons.arrow_back_rounded, size: 22, color: KDesign.ink(colors)),
      ),
    );
  }
}

class _AudioToggle extends StatelessWidget {
  final IconData icon;
  final bool active;
  final ThemeColors colors;
  final VoidCallback onTap;
  const _AudioToggle({required this.icon, required this.active, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: KDesign.chipRadius,
          border: Border.all(color: KDesign.line(colors)),
          boxShadow: KDesign.shadowSm(colors),
        ),
        child: Icon(icon, size: 20, color: active ? colors.accent : KDesign.inkFaint(colors)),
      ),
    );
  }
}
