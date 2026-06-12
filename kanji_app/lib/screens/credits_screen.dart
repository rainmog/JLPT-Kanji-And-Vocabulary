import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../utils/app_route.dart';
import '../widgets/k_setup.dart';
import '../widgets/logo_widget.dart';
import 'kanji_data_license_screen.dart';
import 'study_resources_screen.dart';

const _fontCredits = [
  (name: 'Inter Variable',     license: 'SIL Open Font License 1.1', author: '© The Inter Project Authors'),
  (name: 'Nunito',             license: 'SIL Open Font License 1.1', author: '© Vernon Adams'),
  (name: 'VT323',              license: 'SIL Open Font License 1.1', author: '© Peter Hull'),
  (name: 'Crimson Pro',        license: 'SIL Open Font License 1.1', author: '© Jacques Le Bailly'),
  (name: 'Quicksand',          license: 'SIL Open Font License 1.1', author: '© Andrew Paglinawan'),
  (name: 'Space Grotesk',      license: 'SIL Open Font License 1.1', author: '© Florian Karsten'),
  (name: 'Noto Serif CJK JP',  license: 'SIL Open Font License 1.1', author: '© Google LLC'),
];

class _FontsDropdown extends StatefulWidget {
  final ThemeColors colors;
  const _FontsDropdown({required this.colors});

  @override
  State<_FontsDropdown> createState() => _FontsDropdownState();
}

class _FontsDropdownState extends State<_FontsDropdown> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KDesign.line(colors)),
        boxShadow: KDesign.shadowSm(colors),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: KDesign.tint(colors),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.text_fields_rounded, size: 19, color: colors.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text('Fonts (${_fontCredits.length})',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: KDesign.ink(colors))),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: KDesign.inkFaint(colors)),
                ),
              ]),
            ),
          ),
          if (_expanded)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: _fontCredits.asMap().entries.map((entry) {
                final font = entry.value;
                return Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: KDesign.line(colors).withValues(alpha: 0.6))),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(width: 52),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(font.name, style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: KDesign.ink(colors))),
                        const SizedBox(height: 2),
                        Text('${font.license}\n${font.author}', style: TextStyle(
                          fontSize: 12, color: KDesign.inkSoft(colors), height: 1.5)),
                      ]),
                    ),
                  ]),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class CreditsScreen extends ConsumerWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: KBackHeader(title: 'Credits', colors: colors),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // App logo header
                Center(
                  child: Column(children: [
                    LogoWidget(size: 140),
                    const SizedBox(height: 14),
                    Text('Version 1.0.1', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: KDesign.inkSoft(colors),
                    )),
                    const SizedBox(height: 4),
                    Text('developed by David Garwood-Bish', style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: KDesign.inkSoft(colors),
                    )),
                  ]),
                ),

                const SizedBox(height: 22),
                Text(
                  'This app is intended to be a forever free, completely offline resource for '
                  'studying Japanese — from total beginner all the way to advanced. '
                  'The full codebase and the kanji/vocabulary database are both available on GitHub '
                  'if you want to poke around, contribute, or build on top of it.\n\n'
                  'If you\'re looking for other tools to continue your Japanese journey, '
                  'the button below has a short list of resources I personally recommend. '
                  'None of them are affiliated with this app or its creator — I just like them.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: KDesign.inkSoft(colors),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.push(context, AppRoute.to(const StudyResourcesScreen())),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.accent.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.recommend_rounded, size: 18, color: colors.accent),
                        const SizedBox(width: 8),
                        Text(
                          'Recommended study resources',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: colors.accent,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.chevron_right_rounded, size: 18, color: colors.accent),
                      ],
                    ),
                  ),
                ),

                KSectionLabel(text: 'Data sources', colors: colors),
                KPanel(
                  colors: colors,
                  children: [
                    KSettingRow(
                      icon: Icons.menu_book_rounded,
                      label: 'JMdict / EDICT',
                      sub: 'Vocabulary data · CC BY-SA 4.0\n© The Electronic Dictionary Research and Development Group',
                      colors: colors,
                    ),
                    KSettingRow(
                      icon: Icons.translate_rounded,
                      label: 'KANJIDIC2',
                      sub: 'Kanji readings & meanings · CC BY-SA 4.0\n© James William Breen / EDRDG',
                      colors: colors,
                      separator: true,
                    ),
                    KSettingRow(
                      icon: Icons.format_list_numbered_rounded,
                      label: 'kanji-data by David Gouveia',
                      sub: 'JLPT level assignments (N1–N5) · MIT License',
                      colors: colors,
                      separator: true,
                      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: KDesign.inkFaint(colors)),
                      onTap: () => Navigator.push(context, AppRoute.to(const KanjiDataLicenseScreen())),
                    ),
                  ],
                ),

                KSectionLabel(text: 'Assets', colors: colors),
                KPanel(
                  colors: colors,
                  children: [
                    KSettingRow(
                      icon: Icons.music_note_rounded,
                      label: 'Sound Effects',
                      sub: 'Sourced from Pixabay.com',
                      colors: colors,
                    ),
                  ],
                ),

                KSectionLabel(text: 'Fonts', colors: colors),
                _FontsDropdown(colors: colors),

                // Disclaimer at bottom
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: KDesign.tint(colors),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: KDesign.soft(colors)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: colors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This app is not affiliated with or endorsed by JEES or the Japan Foundation. "JLPT" is a registered trademark of JEES.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KDesign.inkSoft(colors), height: 1.5),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
