import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../widgets/k_setup.dart';
import 'onboarding_welcome_screen.dart';

void _showLearningStyleInfo(BuildContext context, ThemeColors colors) {
  Widget styleBlock(IconData icon, String title, String body) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: colors.accent),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w800, color: colors.fg)),
          ]),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(
            fontSize: 14, color: KDesign.inkSoft(colors), height: 1.55)),
        ],
      );

  showModalBottomSheet(
    context: context,
    backgroundColor: colors.bg,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Learning styles', style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: colors.fg)),
          const SizedBox(height: 6),
          Text(
            'How an item becomes "learned". Switch any time — your progress is kept.',
            style: TextStyle(fontSize: 13.5, color: colors.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          styleBlock(Icons.quiz_outlined, 'By Testing',
            'Take tests to prove what you know. Answer an item correctly in a test '
            'and it becomes learned. Practice stays low-pressure — it never changes '
            'your learned status.'),
          const SizedBox(height: 20),
          styleBlock(Icons.school_outlined, 'By Practicing',
            'No separate tests — the Test button is hidden. Items become learned as '
            'you answer them correctly in practice. Each correct answer moves an item '
            'closer; a wrong answer nudges it back one step, so steady accuracy is '
            'what counts.'),
          const SizedBox(height: 20),
          Text(
            'In both styles you can still mark an item as known instantly with the '
            '"Mark as known" button.',
            style: TextStyle(fontSize: 13, color: colors.muted, height: 1.5),
          ),
        ]),
      ),
    ),
  );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      soundService.setAmbientVolume(s.ambientVolume);
      soundService.setSfxVolume(s.sfxVolume);
      soundService.sfxEnabled = s.sfxEnabled;
      soundService.ambientEnabled = s.ambientEnabled;
      if (!s.ambientEnabled) soundService.stopAmbient();
    });

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: KBackHeader(title: 'Settings', colors: colors),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Audio ──────────────────────────────────────────────
                KSectionLabel(text: 'Audio', colors: colors),
                KPanel(
                  colors: colors,
                  children: [
                    KSettingRow(
                      icon: Icons.music_note_rounded,
                      label: 'Ambient sound',
                      sub: 'Plays in the background',
                      colors: colors,
                      trailing: KToggle(
                        value: s.ambientEnabled,
                        colors: colors,
                        onChanged: (v) {
                          final u = s.copyWith(ambientEnabled: v);
                          notifier.update(u);
                          soundService.ambientEnabled = v;
                          if (!v) soundService.stopAmbient();
                          else if (s.ambientSfx != 'none') soundService.setAmbient(s.ambientSfx);
                        },
                      ),
                    ),
                    KSettingRow(
                      icon: Icons.volume_up_rounded,
                      label: 'Sound effects',
                      colors: colors,
                      separator: true,
                      trailing: KToggle(
                        value: s.sfxEnabled,
                        colors: colors,
                        onChanged: (v) {
                          final u = s.copyWith(sfxEnabled: v);
                          notifier.update(u);
                          soundService.sfxEnabled = v;
                        },
                      ),
                    ),
                    _SliderRow(
                      icon: Icons.surround_sound_rounded,
                      label: 'Ambient volume',
                      value: s.ambientVolume,
                      colors: colors,
                      onChanged: (v) {
                        notifier.update(s.copyWith(ambientVolume: v));
                        soundService.setAmbientVolume(v);
                      },
                    ),
                    _SliderRow(
                      icon: Icons.graphic_eq_rounded,
                      label: 'SFX volume',
                      value: s.sfxVolume,
                      colors: colors,
                      onChanged: (v) {
                        notifier.update(s.copyWith(sfxVolume: v));
                        soundService.setSfxVolume(v);
                      },
                    ),
                    _DropdownRow(
                      icon: Icons.forest_rounded,
                      label: 'Ambient track',
                      value: s.ambientSfx,
                      items: ambientTracks,
                      colors: colors,
                      onChanged: (v) {
                        if (v == null) return;
                        notifier.update(s.copyWith(ambientSfx: v));
                        soundService.setAmbient(v);
                      },
                    ),
                  ],
                ),

                // ── Appearance ─────────────────────────────────────────
                KSectionLabel(text: 'Appearance', colors: colors),
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: KDesign.line(colors)),
                    boxShadow: KDesign.shadowSm(colors),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SingleChildScrollView(
                      child: _ThemePanel(colors: colors, inScroll: true),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                KPanel(
                  colors: colors,
                  children: [
                    KSettingRow(
                      icon: Icons.animation_rounded,
                      label: 'Animations',
                      colors: colors,
                      trailing: KToggle(
                        value: s.animationsEnabled,
                        colors: colors,
                        onChanged: (v) {
                          notifier.update(s.copyWith(animationsEnabled: v));
                        },
                      ),
                    ),
                    _DropdownRow(
                      icon: Icons.text_fields_rounded,
                      label: 'English font',
                      value: s.englishFont,
                      items: englishFonts,
                      colors: colors,
                      onChanged: (v) { if (v != null) notifier.update(s.copyWith(englishFont: v)); },
                    ),
                  ],
                ),

                // ── Main Page ──────────────────────────────────────────
                KSectionLabel(text: 'Main Page', colors: colors),
                KPanel(
                  colors: colors,
                  children: [
                    KSettingRow(
                      icon: Icons.bar_chart_rounded,
                      label: 'Show JLPT goal card',
                      sub: 'Shows goal progress card on home screen',
                      colors: colors,
                      trailing: KToggle(
                        value: s.showTrackerPicker,
                        colors: colors,
                        onChanged: (v) => notifier.update(s.copyWith(showTrackerPicker: v)),
                      ),
                    ),
                    _DropdownRow(
                      icon: Icons.flag_rounded,
                      label: 'JLPT goal',
                      value: s.jlptGoal == 0 ? 'none' : 'N${s.jlptGoal}',
                      items: const {'Not set': 'none', 'N5': 'N5', 'N4': 'N4', 'N3': 'N3', 'N2': 'N2', 'N1': 'N1'},
                      colors: colors,
                      onChanged: (v) {
                        if (v == null) return;
                        final goal = v == 'none' ? 0 : int.parse(v.substring(1));
                        notifier.update(s.copyWith(jlptGoal: goal));
                      },
                    ),
                  ],
                ),

                // ── Study ──────────────────────────────────────────────
                KSectionLabel(text: 'Study', colors: colors),
                KPanel(
                  colors: colors,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(
                            child: Text(
                              'LEARNING STYLE',
                              style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0,
                                color: Color(0xFF9A7E86),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showLearningStyleInfo(context, colors),
                            child: Row(children: [
                              Icon(Icons.help_outline_rounded, size: 15, color: colors.accent),
                              const SizedBox(width: 4),
                              Text(
                                'What is this?',
                                style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700, color: colors.accent,
                                ),
                              ),
                            ]),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        KSeg(
                          options: const [
                            KSegOption(id: 'test', label: 'By Testing'),
                            KSegOption(id: 'practice', label: 'By Practicing'),
                          ],
                          value: s.learnedVia,
                          onChanged: (v) => notifier.update(s.copyWith(learnedVia: v)),
                          colors: colors,
                        ),
                      ]),
                    ),
                    KSettingRow(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Automatic progression',
                      sub: 'Automatically fills your targets as you learn',
                      colors: colors,
                      trailing: KToggle(
                        value: s.autoProgressionEnabled,
                        colors: colors,
                        onChanged: (v) => notifier.update(s.copyWith(autoProgressionEnabled: v)),
                      ),
                    ),
                    if (s.autoProgressionEnabled) ...[
                      _CounterRow(
                        icon: Icons.translate_rounded,
                        label: 'Kanji quota',
                        sub: 'Target kanji to maintain',
                        value: s.autoProgressionKanjiQuota,
                        min: 5,
                        max: 50,
                        step: 5,
                        colors: colors,
                        onChanged: (v) => notifier.update(s.copyWith(autoProgressionKanjiQuota: v)),
                      ),
                      _CounterRow(
                        icon: Icons.menu_book_rounded,
                        label: 'Vocabulary quota',
                        sub: 'Target vocab to maintain',
                        value: s.autoProgressionVocabQuota,
                        min: 10,
                        max: 100,
                        step: 10,
                        colors: colors,
                        onChanged: (v) => notifier.update(s.copyWith(autoProgressionVocabQuota: v)),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          'SENTENCE DIFFICULTY  ·  ${s.difficultyMin}–${s.difficultyMax}',
                          style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0,
                            color: Color(0xFF9A7E86),
                          ),
                        ),
                        const SizedBox(height: 10),
                        KDualRange(
                          lo: s.difficultyMin,
                          hi: s.difficultyMax,
                          onChanged: (a, b) => notifier.update(s.copyWith(difficultyMin: a, difficultyMax: b)),
                          colors: colors,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Applies to kanji and vocabulary sentence practice.',
                          style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600,
                            color: Color(0xFFC7B4BA),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // ── Data ───────────────────────────────────────────────
                KSectionLabel(text: 'Data', colors: colors),
                KPanel(
                  colors: colors,
                  children: [
                    KSettingRow(
                      icon: Icons.upload_rounded,
                      label: 'Export progress',
                      sub: 'Save a backup file',
                      colors: colors,
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: KDesign.inkFaint(colors)),
                      onTap: () async {
                        final path = await exportService.exportProgress(
                          ref.read(settingsProvider),
                          context: context,
                        );
                        if (context.mounted && path != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Saved to $path'), backgroundColor: colors.correct),
                          );
                        }
                      },
                    ),
                    KSettingRow(
                      icon: Icons.download_rounded,
                      label: 'Import progress',
                      sub: 'Restore from a backup file',
                      colors: colors,
                      separator: true,
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: KDesign.inkFaint(colors)),
                      onTap: () async {
                        try {
                          final ok = await exportService.importProgress(
                            context,
                            ref.read(settingsProvider),
                            (s) => ref.read(settingsProvider.notifier).update(s),
                          );
                          if (context.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: const Text('Progress imported successfully'), backgroundColor: colors.correct),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Import failed: $e'), backgroundColor: colors.incorrect),
                            );
                          }
                        }
                      },
                    ),
                    KSettingRow(
                      icon: Icons.delete_forever_rounded,
                      label: 'Clear all user data',
                      sub: 'Resets all progress and settings',
                      colors: colors,
                      separator: true,
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: colors.incorrect.withValues(alpha: 0.7)),
                      onTap: () => _confirmClearUserData(context, ref, colors),
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  void _confirmClearUserData(BuildContext context, WidgetRef ref, ThemeColors colors) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text('Clear all user data?', style: TextStyle(color: KDesign.ink(colors))),
        content: Text(
          'This resets ALL progress — kanji, vocabulary, test history, and settings. '
          'You will return to the onboarding screen. This cannot be undone.',
          style: TextStyle(color: KDesign.inkSoft(colors)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: KDesign.inkSoft(colors))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _doBackupAndClear(context, ref, colors, backup: true);
            },
            child: Text('Backup & Clear', style: TextStyle(color: colors.accent)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _doBackupAndClear(context, ref, colors, backup: false);
            },
            child: Text('Clear Without Backup', style: TextStyle(color: colors.incorrect)),
          ),
        ],
      ),
    );
  }

  Future<void> _doBackupAndClear(BuildContext context, WidgetRef ref, ThemeColors colors, {required bool backup}) async {
    if (backup) {
      final now = DateTime.now();
      final date = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final path = await exportService.exportProgress(
        ref.read(settingsProvider),
        filename: 'kanji_backup_$date.json',
        context: context,
      );
      if (context.mounted) {
        final msg = path != null ? 'Backup saved to $path' : 'Backup shared — proceeding with clear';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: colors.correct),
        );
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    await dbService.execute("DELETE FROM user_progress");
    await dbService.execute("DELETE FROM vocabulary_targets");
    await dbService.execute("DELETE FROM vocabulary_progress");
    try { await dbService.execute("DELETE FROM test_history"); } catch (_) {}
    try { await dbService.execute("DELETE FROM session_log"); } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (context.mounted) {
      await ref.read(settingsProvider.notifier).update(const AppSettings());
    }

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingWelcomeScreen()),
        (_) => false,
      );
    }
  }
}

// ── Theme panel ───────────────────────────────────────────────────────────────

const _themeLabels = {
  AppTheme.simpleLight:  'Simple Light',
  AppTheme.simpleDark:   'Simple Black',
  AppTheme.sakura:       'Spring Sakura',
  AppTheme.galaxy:       'Starman',
  AppTheme.loveLetter:   'Love Letter',
  AppTheme.lily:         'Chou-chou Green',
  AppTheme.totoro:       'Big Rabbit Green',
  AppTheme.midnightCity: 'Midnight City',
};

const _themeTaglines = {
  AppTheme.simpleLight:  'Simple, clean, default.',
  AppTheme.simpleDark:   'Simple, clean, easy on the eyes.',
  AppTheme.sakura:       'Pastel pinks. Comes too quickly every year.',
  AppTheme.galaxy:       'Cosmic blues. There\'s a cowboy out there somewhere.',
  AppTheme.loveLetter:   'Snow whites, pale blues.',
  AppTheme.lily:         'Forever Ashikaga.',
  AppTheme.totoro:       'It\'s pronounced Jiburi. Ignore Miyazaki.',
  AppTheme.midnightCity: 'Turn up the music Miss Takeuchi.',
};

class _ThemePanel extends ConsumerWidget {
  final ThemeColors colors;
  final bool inScroll;
  const _ThemePanel({required this.colors, this.inScroll = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeNotifier);
    final notifier = ref.read(themeNotifier.notifier);

    final items = AppTheme.values.asMap().entries.map((entry) {
      final i = entry.key;
      final theme = entry.value;
      final on = current == theme;
      return GestureDetector(
        onTap: () => notifier.setTheme(theme),
        child: Container(
          decoration: BoxDecoration(
            border: i > 0 ? Border(top: BorderSide(color: KDesign.line(colors).withValues(alpha: 0.6))) : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                color: on ? colors.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: on ? null : Border.all(color: KDesign.line(colors), width: 2),
              ),
              child: on ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_themeLabels[theme] ?? theme.name, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: KDesign.ink(colors),
                )),
                if (on)
                  Text(_themeTaglines[theme] ?? '', style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w600,
                    color: KDesign.inkSoft(colors), fontStyle: FontStyle.italic,
                  )),
              ]),
            ),
          ]),
        ),
      );
    }).toList();

    if (inScroll) {
      return Column(mainAxisSize: MainAxisSize.min, children: items);
    }
    return KPanel(colors: colors, children: items);
  }
}

// ── Slider row ────────────────────────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final ThemeColors colors;
  final void Function(double) onChanged;
  const _SliderRow({required this.icon, required this.label, required this.value, required this.colors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: KDesign.line(colors).withValues(alpha: 0.6))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: KDesign.tint(colors),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: colors.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: KDesign.ink(colors))),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                overlayShape: SliderComponentShape.noOverlay,
                trackHeight: 4,
                activeTrackColor: colors.accent,
                inactiveTrackColor: KDesign.soft(colors),
                thumbColor: Colors.white,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              ),
              child: Slider(
                value: value, min: 0, max: 1, divisions: 10,
                onChanged: onChanged,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Counter row ───────────────────────────────────────────────────────────────

class _CounterRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final int value;
  final int min;
  final int max;
  final int step;
  final ThemeColors colors;
  final ValueChanged<int> onChanged;

  const _CounterRow({
    required this.icon, required this.label, required this.sub,
    required this.value, required this.min, required this.max,
    required this.step, required this.colors, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: KDesign.line(colors).withValues(alpha: 0.6))),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Icon(icon, size: 20, color: KDesign.inkSoft(colors)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: KDesign.ink(colors),
              )),
              Text(sub, style: TextStyle(fontSize: 12, color: KDesign.inkSoft(colors))),
            ]),
          ),
          Row(children: [
            GestureDetector(
              onTap: value > min ? () => onChanged(value - step) : null,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: KDesign.tint(colors),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.remove_rounded, size: 18, color:
                  value > min ? KDesign.ink(colors) : KDesign.inkFaint(colors)),
              ),
            ),
            SizedBox(
              width: 42,
              child: Text('$value',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KDesign.ink(colors)),
              ),
            ),
            GestureDetector(
              onTap: value < max ? () => onChanged(value + step) : null,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: KDesign.tint(colors),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.add_rounded, size: 18, color:
                  value < max ? KDesign.ink(colors) : KDesign.inkFaint(colors)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

// ── Dropdown row ──────────────────────────────────────────────────────────────

class _DropdownRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Map<String, String> items;
  final ThemeColors colors;
  final void Function(String?) onChanged;
  const _DropdownRow({required this.icon, required this.label, required this.value, required this.items, required this.colors, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: KDesign.line(colors).withValues(alpha: 0.6))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: KDesign.tint(colors),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 19, color: colors.accent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: KDesign.ink(colors))),
            const SizedBox(height: 4),
            DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: colors.surface,
              style: TextStyle(color: KDesign.ink(colors), fontSize: 14, fontWeight: FontWeight.w600),
              underline: Container(height: 1, color: KDesign.line(colors)),
              icon: Icon(Icons.unfold_more_rounded, size: 18, color: KDesign.inkFaint(colors)),
              onChanged: onChanged,
              items: items.entries.map((e) => DropdownMenuItem<String>(
                value: e.value,
                child: Text(e.key, style: TextStyle(color: KDesign.ink(colors), fontSize: 14)),
              )).toList(),
            ),
          ]),
        ),
      ]),
    );
  }
}
