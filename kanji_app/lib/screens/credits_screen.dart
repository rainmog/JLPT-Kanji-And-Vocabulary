import 'package:flutter/material.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import 'kanji_data_license_screen.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('Credits', style: TextStyle(color: AppColors.fg)),
        iconTheme: IconThemeData(color: AppColors.fg),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // JLPT disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.pillBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'This app is not affiliated with or endorsed by the Japan Educational Exchanges and Services (JEES) or the Japan Foundation. "JLPT" is a registered trademark of JEES.',
              style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.5),
            ),
          ),
          const SizedBox(height: 32),

          // JMdict
          Text(
            'Vocabulary Data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg),
          ),
          const SizedBox(height: 12),
          Text('JMdict/EDICT', style: TextStyle(color: AppColors.fg)),
          const SizedBox(height: 4),
          Text(
            'License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 4),
          SelectableText(
            'https://www.edrdg.org/wiki/index.php/JMdict-EDICT_Dictionary_Project',
            style: TextStyle(color: AppColors.accent, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '© The Electronic Dictionary Research and Development Group',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            'Vocabulary data derived from JMdict, made available under CC BY-SA 4.0. Attribution to the EDRDG and its members is required as per the conditions set out in the Group\'s licence statement.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 32),

          // KANJIDIC2
          Text(
            'Kanji Data',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg),
          ),
          const SizedBox(height: 12),
          Text('KANJIDIC2', style: TextStyle(color: AppColors.fg)),
          const SizedBox(height: 4),
          Text(
            'License: Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 4),
          SelectableText(
            'https://www.edrdg.org/wiki/index.php/KANJIDIC_Project',
            style: TextStyle(color: AppColors.accent, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            '© James William Breen / Electronic Dictionary Research and Development Group',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            'Kanji readings, meanings, and stroke counts sourced from KANJIDIC2.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 32),

          // kanji-data (MIT)
          Text(
            'JLPT Level Classification',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(context, AppRoute.to(const KanjiDataLicenseScreen())),
            child: Text(
              'kanji-data by David Gouveia',
              style: TextStyle(
                color: AppColors.accent,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'License: MIT',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Used for modern JLPT level assignments (N1–N5) for kanji.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 32),

          // Sound Effects
          Text(
            'Sound Effects',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg),
          ),
          const SizedBox(height: 12),
          Text('Sourced from Pixabay.com', style: TextStyle(color: AppColors.fg)),
          const SizedBox(height: 4),
          SelectableText(
            'https://pixabay.com',
            style: TextStyle(color: AppColors.accent, fontSize: 13),
          ),
          const SizedBox(height: 32),

          // Development
          Text(
            'Development',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.fg),
          ),
          const SizedBox(height: 12),
          Text(
            'Designed and developed with Claude Code by Anthropic.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
