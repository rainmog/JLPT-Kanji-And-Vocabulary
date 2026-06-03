import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';
import '../services/export_service.dart';
import '../services/sound_service.dart';
import '../theme.dart';
import '../theme_provider.dart';
import 'onboarding_welcome_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeColorsProvider);
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    // Sync audio state on settings load/change.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      soundService.setAmbientVolume(s.ambientVolume);
      soundService.setSfxVolume(s.sfxVolume);
      soundService.sfxEnabled = s.sfxEnabled;
      soundService.ambientEnabled = s.ambientEnabled;
      if (!s.ambientEnabled) soundService.stopAmbient();
    });
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('Settings', style: TextStyle(color: AppColors.fg)),
        iconTheme: IconThemeData(color: AppColors.fg),
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('AUDIO', style: TextStyle(fontSize: 13, color: AppColors.muted, letterSpacing: 1)),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Ambient SFX', style: TextStyle(color: AppColors.fg)),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButton<String>(
              value: s.ambientSfx,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: TextStyle(color: AppColors.fg),
              underline: Container(height: 1, color: AppColors.pillBg),
              onChanged: (value) {
                if (value == null) return;
                notifier.update(s.copyWith(ambientSfx: value));
                soundService.setAmbient(value);
              },
              items: ambientTracks.entries.map((e) =>
                DropdownMenuItem<String>(
                  value: e.key,
                  child: Text(e.value, style: TextStyle(color: AppColors.fg, fontSize: 14)),
                ),
              ).toList(),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Plays in the background. Mixes with other audio (music, podcasts).',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text('Ambient Volume', style: TextStyle(color: AppColors.fg)),
          Expanded(
            child: Slider(
              value: s.ambientVolume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              activeColor: AppColors.accent,
              inactiveColor: AppColors.pillBg,
              onChanged: (v) {
                notifier.update(s.copyWith(ambientVolume: v));
                soundService.setAmbientVolume(v);
              },
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Text('SFX Volume', style: TextStyle(color: AppColors.fg)),
          Expanded(
            child: Slider(
              value: s.sfxVolume,
              min: 0.0,
              max: 1.0,
              divisions: 10,
              activeColor: AppColors.accent,
              inactiveColor: AppColors.pillBg,
              onChanged: (v) {
                notifier.update(s.copyWith(sfxVolume: v));
                soundService.setSfxVolume(v);
              },
            ),
          ),
        ]),
        const SizedBox(height: 32),
        Text('APPEARANCE', style: TextStyle(fontSize: 13, color: AppColors.muted, letterSpacing: 1)),
        const SizedBox(height: 12),
        const _ThemeSelector(),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Animations', style: TextStyle(color: AppColors.fg)),
          Switch(
            value: s.animationsEnabled,
            activeColor: AppColors.accent,
            onChanged: (v) => notifier.update(s.copyWith(animationsEnabled: v)),
          ),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text('Hide hiragana/katakana practice from main page',
            style: TextStyle(color: AppColors.fg))),
          Switch(
            value: s.hideKanaPractice,
            activeColor: AppColors.accent,
            onChanged: (v) => notifier.update(s.copyWith(hideKanaPractice: v)),
          ),
        ]),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('English Font', style: TextStyle(color: AppColors.fg)),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButton<String>(
              value: s.englishFont,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: TextStyle(color: AppColors.fg),
              underline: Container(height: 1, color: AppColors.pillBg),
              onChanged: (v) { if (v != null) notifier.update(s.copyWith(englishFont: v)); },
              items: englishFonts.entries.map((e) => DropdownMenuItem(
                value: e.value,
                child: Text(e.key, style: TextStyle(color: AppColors.fg, fontSize: 14)),
              )).toList(),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Japanese Font', style: TextStyle(color: AppColors.fg)),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButton<String>(
              value: s.japaneseFont,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              style: TextStyle(color: AppColors.fg),
              underline: Container(height: 1, color: AppColors.pillBg),
              onChanged: (v) { if (v != null) notifier.update(s.copyWith(japaneseFont: v)); },
              items: japaneseFonts.entries.map((e) => DropdownMenuItem(
                value: e.value,
                child: Text(e.key, style: TextStyle(color: AppColors.fg, fontSize: 14)),
              )).toList(),
            ),
          ),
        ]),
        const SizedBox(height: 32),
        Text('DATA', style: TextStyle(fontSize: 13, color: AppColors.muted, letterSpacing: 1)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () async {
            final path = await exportService.exportProgress(ref.read(settingsProvider));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Saved to $path'), backgroundColor: AppColors.correctBg));
            }
          },
          child: Text('Export Progress'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: () async {
            try {
              final ok = await exportService.importProgress(
                context,
                ref.read(settingsProvider),
                (s) => ref.read(settingsProvider.notifier).update(s),
              );
              if (context.mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Progress imported successfully'),
                    backgroundColor: AppColors.correctBg,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Import failed: $e'),
                    backgroundColor: AppColors.incorrectBg,
                  ),
                );
              }
            }
          },
          child: const Text('Import Progress'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2a0808), foregroundColor: AppColors.incorrect),
          onPressed: () => _confirmClearUserData(context, ref),
          child: const Text('Clear User Data'),
        ),
        SizedBox(height: MediaQuery.of(context).viewPadding.bottom + 20),
      ]),
    );
  }

  void _confirmClearUserData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Clear all user data?', style: TextStyle(color: AppColors.fg)),
        content: Text(
          'This resets ALL progress — kanji, vocabulary, test history, and settings. '
          'You will return to the onboarding screen. This cannot be undone.',
          style: TextStyle(color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _doBackupAndClear(context, ref, backup: true);
            },
            child: Text('Backup & Clear', style: TextStyle(color: AppColors.accent)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _doBackupAndClear(context, ref, backup: false);
            },
            child: Text('Clear Without Backup', style: TextStyle(color: AppColors.incorrect)),
          ),
        ],
      ),
    );
  }

  Future<void> _doBackupAndClear(BuildContext context, WidgetRef ref, {required bool backup}) async {
    if (backup) {
      final now = DateTime.now();
      final date = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final filename = 'kanji_backup_$date.json';
      final path = await exportService.exportProgress(ref.read(settingsProvider), filename: filename);
      if (context.mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup saved to $path'), backgroundColor: AppColors.correctBg),
        );
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    // Clear all user tables
    await dbService.execute("DELETE FROM user_progress");
    await dbService.execute("DELETE FROM vocabulary_targets");
    await dbService.execute("DELETE FROM vocabulary_progress");
    try { await dbService.execute("DELETE FROM test_history"); } catch (_) {}
    try { await dbService.execute("DELETE FROM session_log"); } catch (_) {}

    // Clear all SharedPreferences (onboarding flag, JLPT progress, settings)
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingWelcomeScreen()),
        (_) => false,
      );
    }
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text('Reset progress?', style: TextStyle(color: AppColors.fg)),
      content: Text('All learned kanji will be reset to unlearned. This cannot be undone.',
        style: TextStyle(color: AppColors.muted)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: AppColors.muted))),
        TextButton(
          onPressed: () async {
            await dbService.execute("UPDATE user_progress SET status='unlearned', consecutive_correct=0");
            if (context.mounted) Navigator.pop(context);
          },
          child: Text('Reset', style: TextStyle(color: AppColors.incorrect)),
        ),
      ],
    ));
  }
}

const _themeTaglines = {
  AppTheme.simpleLight:  'Simple, clean, default.',
  AppTheme.simpleDark:   'Simple, clean, easy on the eyes.',
  AppTheme.sakura:       'Pastel pinks. Comes too quickly every year.',
  AppTheme.galaxy:       'Cosmic blues. There\'s a cowboy out there somewhere.',
  AppTheme.tetris:       'Colorful bricks on a dark background.',
  AppTheme.loveLetter:   'Snow whites, pale blues.',
  AppTheme.lily:         'Forever Ashikaga.',
  AppTheme.totoro:       'It\'s pronounced Jiburi. Ignore Miyazaki.',
  AppTheme.midnightCity: 'Turn up the music Miss Takeuchi.',
};

const _themeLabels = {
  AppTheme.simpleLight:  'Simple Light',
  AppTheme.simpleDark:   'Simple Black',
  AppTheme.sakura:       'Spring Sakura',
  AppTheme.galaxy:       'Starman',
  AppTheme.tetris:       'Colorful Bricks',
  AppTheme.loveLetter:   'Love Letter',
  AppTheme.lily:         'Chou-chou Green',
  AppTheme.totoro:       'Big Rabbit Green',
  AppTheme.midnightCity: 'Midnight City',
};

class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeNotifier);
    final notifier = ref.read(themeNotifier.notifier);

    return Column(
      children: AppTheme.values.expand((theme) => [
        _ThemeRadio(
          label: _themeLabels[theme] ?? theme.name,
          tagline: _themeTaglines[theme] ?? '',
          theme: theme,
          isSelected: currentTheme == theme,
          onSelected: () => notifier.setTheme(theme),
        ),
        const SizedBox(height: 8),
      ]).toList(),
    );
  }
}

class _ThemeRadio extends StatelessWidget {
  final String label;
  final String tagline;
  final AppTheme theme;
  final bool isSelected;
  final VoidCallback onSelected;

  const _ThemeRadio({
    required this.label,
    required this.tagline,
    required this.theme,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSelected,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Radio<bool>(
            value: true,
            groupValue: isSelected,
            onChanged: (_) => onSelected(),
            activeColor: AppColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: TextStyle(color: AppColors.fg)),
                if (isSelected && tagline.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(tagline,
                      style: TextStyle(fontSize: 12, color: AppColors.muted,
                          fontStyle: FontStyle.italic)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FontSizeSelector extends ConsumerWidget {
  const _FontSizeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearanceSettings = ref.watch(appearanceSettingsProvider);

    if (appearanceSettings == null) {
      return const SizedBox.shrink();
    }

    final currentSize = appearanceSettings.getFontSize();
    const sizes = [0.8, 1.0, 1.2, 1.5];
    const labels = ['Small', 'Normal', 'Large', 'Extra Large'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Font Size', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...List.generate(sizes.length, (i) {
          final size = sizes[i];
          final label = labels[i];
          final isSelected = (currentSize - size).abs() < 0.01;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SettingTile(
              label: label,
              isSelected: isSelected,
              onTap: () async {
                await appearanceSettings.setFontSize(size);
                // ignore: avoid_types_on_closure_parameters
                ref.invalidate(appearanceSettingsProvider);
              },
            ),
          );
        }),
      ],
    );
  }
}

class _ContrastSelector extends ConsumerWidget {
  const _ContrastSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearanceSettings = ref.watch(appearanceSettingsProvider);

    if (appearanceSettings == null) {
      return const SizedBox.shrink();
    }

    final currentContrast = appearanceSettings.getContrast();
    const contrasts = ['normal', 'high', 'ultra'];
    const labels = ['Normal', 'High', 'Ultra'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contrast', style: TextStyle(color: AppColors.fg, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...List.generate(contrasts.length, (i) {
          final contrast = contrasts[i];
          final label = labels[i];
          final isSelected = currentContrast == contrast;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SettingTile(
              label: label,
              isSelected: isSelected,
              onTap: () async {
                await appearanceSettings.setContrast(contrast);
                // ignore: avoid_types_on_closure_parameters
                ref.invalidate(appearanceSettingsProvider);
              },
            ),
          );
        }),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SettingTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.2) : AppColors.pillBg,
          borderRadius: BorderRadius.circular(AppColors.containerRadius),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: AppColors.fg)),
            if (isSelected) Icon(Icons.check, color: AppColors.accent, size: 18),
          ],
        ),
      ),
    );
  }
}
