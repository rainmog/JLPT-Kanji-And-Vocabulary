import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../theme_provider.dart';
import '../widgets/k_setup.dart';

class StudyResourcesScreen extends ConsumerWidget {
  const StudyResourcesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(themeColorsProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
            child: KBackHeader(title: 'Study Resources', colors: colors),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                Padding(
                  padding: const EdgeInsets.only(bottom: 20, top: 4),
                  child: Text(
                    'None of these are affiliated with this app or its creator — I just genuinely use and like them. '
                    'Hopefully they\'re as useful to you as they\'ve been to me.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: KDesign.inkSoft(colors),
                      height: 1.55,
                    ),
                  ),
                ),

                _ResourceCard(
                  colors: colors,
                  icon: Icons.auto_awesome_rounded,
                  title: 'jpdb.io',
                  tag: 'Web — Free / Paid tier',
                  body: 'A vocabulary study tool built almost entirely by one developer, and it shows — '
                      'the level of customization is genuinely impressive. You can study from basically '
                      'any anime, manga, light novel, or game you want, and it builds a custom deck '
                      'around content you actually care about. The solo-dev aspect is worth mentioning '
                      'because the quality is way higher than you\'d expect. Definitely worth a look '
                      'if you want your vocabulary to actually match what you\'re consuming.',
                ),
                const SizedBox(height: 14),

                _ResourceCard(
                  colors: colors,
                  icon: Icons.menu_book_rounded,
                  title: 'New Japanese 500 Questions',
                  tag: 'Books — Amazon',
                  body: 'A series of JLPT workbooks covering grammar, reading, and vocabulary for '
                      'each level. Affordable and no-frills — great if you prefer working through '
                      'something on paper instead of staring at a screen. I\'ve found them really '
                      'useful for structured test prep, and they\'re easy enough to carry around '
                      'and use during a commute. If traditional study methods click better for you, '
                      'these are probably the best value books out there for JLPT.',
                ),
                const SizedBox(height: 14),

                _ResourceCard(
                  colors: colors,
                  icon: Icons.school_rounded,
                  title: 'Renshuu',
                  tag: 'App — Free / Optional paid',
                  body: 'An all-in-one study app covering vocabulary, kanji, grammar, and reading '
                      'from N5 all the way up to N1. Unlike a lot of other apps in this space, '
                      'it doesn\'t gate the useful stuff behind a subscription — you can actually '
                      'study everything without paying. It\'s a solid companion to use alongside '
                      'this app if you want broader grammar coverage or a different angle on the '
                      'same vocabulary.',
                ),

              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  final ThemeColors colors;
  final IconData icon;
  final String title;
  final String tag;
  final String body;

  const _ResourceCard({
    required this.colors,
    required this.icon,
    required this.title,
    required this.tag,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: KDesign.line(colors)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: colors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: colors.fg,
                letterSpacing: -0.2,
              )),
              Text(tag, style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: KDesign.inkFaint(colors),
              )),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text(body, style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w500,
          color: KDesign.inkSoft(colors),
          height: 1.6,
        )),
      ]),
    );
  }
}
