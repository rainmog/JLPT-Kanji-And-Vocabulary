// ═══════════════════════════════════════════════════════════════
// sakura_theme_v2.dart — Sakura Theme v2
// Drop into lib/theme/ and wire to MaterialApp(theme: SakuraThemeV2.light)
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Color constants ────────────────────────────────────────────
// Reference these directly in widgets for custom styling.
abstract class SakuraColors {
  SakuraColors._();

  // Scaffold & surfaces
  // KEY CHANGE: bg is now warm cream, not cold blue-grey (#e8f2f8)
  static const Color bg           = Color(0xFFFAF4F0); // warm cream scaffold
  static const Color surface      = Color(0xFFFFFFFF); // card / elevated surface
  static const Color surfaceHover = Color(0xFFF8F0F2); // pressed/hover surface

  // Text
  static const Color fg           = Color(0xFF3D1A26); // primary text & icons
  static const Color muted        = Color(0xFF9E7585); // secondary / hint text
  static const Color kanjiColor   = Color(0xFF3D1A26); // kanji display (same as fg)

  // Accent (sakura pink)
  // KEY CHANGE: accent is now a real visible pink (#d4677e), not near-invisible blush
  static const Color accent       = Color(0xFFD4677E); // sakura pink — fills, active, links
  static const Color accentLight  = Color(0xFFFDEDF0); // very light blush — hover bg, sub-items
  static const Color accentEnd    = Color(0xFFE8899A); // progress gradient end

  // Semantic feedback
  static const Color correct      = Color(0xFF2F7A50);
  static const Color correctBg    = Color(0xFFEDF7F2);
  static const Color incorrect    = Color(0xFFC93350);
  static const Color incorrectBg  = Color(0xFFFCE8ED);

  // Progress bar
  // KEY CHANGE: track and fill are now visible and properly contrasted
  static const Color progressTrack = Color(0xFFF5DDE4);
  static const Color progressFill  = Color(0xFFD4677E); // use with gradient to accentEnd

  // Structure
  static const Color border       = Color(0x123D1A26); // rgba(61,26,38,0.07)
  static const Color divider      = Color(0x123D1A26);
}

// ─── Shape constants ─────────────────────────────────────────────
abstract class SakuraShapes {
  SakuraShapes._();

  static const double buttonRadius    = 12.0;
  static const double containerRadius = 10.0;
  static const double heroCircleSize  = 140.0; // hero kanji circle diameter
  static const double screenPaddingH  = 18.0;
  static const double buttonPaddingV  = 15.0;
  static const double buttonPaddingH  = 18.0;
  static const double itemGap         = 8.0;

  static const BorderRadius btnBorderRadius =
      BorderRadius.all(Radius.circular(buttonRadius));
  static const BorderRadius containerBorderRadius =
      BorderRadius.all(Radius.circular(containerRadius));
}

// ─── Elevation / shadow ──────────────────────────────────────────
abstract class SakuraShadows {
  SakuraShadows._();

  // Standard card / button shadow
  // KEY CHANGE: cards now have subtle elevation (were flat)
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x1A3D1A26), // rgba(61,26,38,0.10)
      blurRadius: 6,
      offset: Offset(0, 1),
    ),
  ];

  // Slightly elevated (hover/active)
  static const List<BoxShadow> cardMd = [
    BoxShadow(
      color: Color(0x1F3D1A26), // rgba(61,26,38,0.12)
      blurRadius: 14,
      offset: Offset(0, 2),
    ),
  ];
}

// ─── Typography ─────────────────────────────────────────────────
// Font families: "Noto Sans JP" (UI) + "Noto Serif JP" (kanji display)
// Ensure both are in pubspec.yaml under google_fonts or as assets.
abstract class SakuraTextStyles {
  SakuraTextStyles._();

  // AppBar title
  static const TextStyle appBarTitle = TextStyle(
    color: SakuraColors.fg,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    fontFamily: 'Inter',
  );

  // AppBar subtitle (e.g. "89 learned · 4 targeted")
  static const TextStyle appBarSubtitle = TextStyle(
    color: SakuraColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    fontFamily: 'Inter',
  );

  // Hero kanji display (home screen circle + test screen)
  static const TextStyle kanjiHero = TextStyle(
    color: SakuraColors.fg,
    fontSize: 72,
    fontWeight: FontWeight.w700,
    fontFamily: 'NotoSerifCJKjp',
    height: 1.0,
  );

  // Test screen kanji (slightly larger, compound kanji)
  static const TextStyle kanjiTest = TextStyle(
    color: SakuraColors.fg,
    fontSize: 90,
    fontWeight: FontWeight.w700,
    fontFamily: 'NotoSerifCJKjp',
    height: 1.0,
    letterSpacing: -1.5,
  );

  // Kanji reading (readings in accent color on home)
  static const TextStyle kanjiReading = TextStyle(
    color: SakuraColors.accent, // KEY CHANGE: readings now in accent (was muted)
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontFamily: 'NotoSerifCJKjp',
    letterSpacing: 1.0,
  );

  // Kanji meaning
  static const TextStyle kanjiMeaning = TextStyle(
    color: SakuraColors.muted,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    fontFamily: 'Inter',
  );

  // Button label (accordion/flat nav)
  static const TextStyle buttonLabel = TextStyle(
    color: SakuraColors.fg,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    fontFamily: 'Inter',
  );

  // Section button label (accordion header, bolder)
  static const TextStyle sectionLabel = TextStyle(
    color: SakuraColors.fg,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    fontFamily: 'Inter',
  );

  // Test option text (Japanese)
  static const TextStyle optionText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    fontFamily: 'NotoSerifCJKjp',
  );

  // Progress label
  static const TextStyle progressLabel = TextStyle(
    color: SakuraColors.muted,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    fontFamily: 'Inter',
  );

  // Progress count
  static const TextStyle progressCount = TextStyle(
    color: SakuraColors.fg,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    fontFamily: 'Inter',
  );

  // Muted link (Already know this)
  static const TextStyle mutedLink = TextStyle(
    color: SakuraColors.accent,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    fontFamily: 'Inter',
  );

  // Grid kanji cell
  static const TextStyle gridKanji = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w400,
    fontFamily: 'NotoSerifCJKjp',
  );
}

// ─── Component decoration helpers ────────────────────────────────
abstract class SakuraDecorations {
  SakuraDecorations._();

  // Standard elevated button/card
  static BoxDecoration get card => const BoxDecoration(
    color: SakuraColors.surface,
    borderRadius: SakuraShapes.btnBorderRadius,
    boxShadow: SakuraShadows.card,
  );

  // Card with container radius (slightly less rounded)
  static BoxDecoration get container => const BoxDecoration(
    color: SakuraColors.surface,
    borderRadius: SakuraShapes.containerBorderRadius,
    boxShadow: SakuraShadows.card,
  );

  // Option button — idle
  static BoxDecoration get optionIdle => const BoxDecoration(
    color: SakuraColors.surface,
    borderRadius: SakuraShapes.btnBorderRadius,
    boxShadow: SakuraShadows.card,
  );

  // Option button — correct
  static BoxDecoration get optionCorrect => BoxDecoration(
    color: SakuraColors.correctBg,
    borderRadius: SakuraShapes.btnBorderRadius,
    border: Border.all(color: SakuraColors.correct.withOpacity(0.33), width: 1.5),
  );

  // Option button — wrong
  static BoxDecoration get optionWrong => BoxDecoration(
    color: SakuraColors.incorrectBg,
    borderRadius: SakuraShapes.btnBorderRadius,
    border: Border.all(color: SakuraColors.incorrect.withOpacity(0.33), width: 1.5),
  );

  // Option button — dimmed (other options when answered)
  static BoxDecoration get optionDim => const BoxDecoration(
    color: SakuraColors.surface,
    borderRadius: SakuraShapes.btnBorderRadius,
  );

  // Hero kanji circle
  static BoxDecoration get heroCircle => BoxDecoration(
    shape: BoxShape.circle,
    color: SakuraColors.accent.withOpacity(0.07),
    border: Border.all(
      color: SakuraColors.accent.withOpacity(0.18),
      width: 1.5,
    ),
  );

  // Kanji grid cell — unlearned
  static BoxDecoration get gridUnlearned => const BoxDecoration(
    color: SakuraColors.surface,
    borderRadius: BorderRadius.all(Radius.circular(10)),
    boxShadow: [
      BoxShadow(color: Color(0x123D1A26), blurRadius: 4, offset: Offset(0, 1)),
    ],
  );

  // Kanji grid cell — targeted
  static BoxDecoration get gridTargeted => BoxDecoration(
    color: SakuraColors.accentLight,
    borderRadius: const BorderRadius.all(Radius.circular(10)),
    border: Border.all(color: SakuraColors.accent.withOpacity(0.33), width: 1),
  );

  // Kanji grid cell — learned
  static BoxDecoration get gridLearned => BoxDecoration(
    color: SakuraColors.correctBg,
    borderRadius: const BorderRadius.all(Radius.circular(10)),
    border: Border.all(color: SakuraColors.correct.withOpacity(0.27), width: 1),
  );

  // Accordion sub-item N-level badge — active (N5, N4)
  static BoxDecoration get nBadgeActive => BoxDecoration(
    color: SakuraColors.accentLight,
    borderRadius: const BorderRadius.all(Radius.circular(7)),
    border: Border.all(color: SakuraColors.accent.withOpacity(0.28), width: 1.5),
  );

  // Accordion sub-item N-level badge — inactive
  static BoxDecoration get nBadgeInactive => BoxDecoration(
    borderRadius: const BorderRadius.all(Radius.circular(7)),
    border: Border.all(color: SakuraColors.border, width: 1.5),
  );
}

// ─── Gradient progress bar ───────────────────────────────────────
// Flutter's LinearProgressIndicator doesn't support gradients natively.
// Use this widget wherever a progress bar is needed.
//
// Usage:
//   SakuraProgressBar(value: 89 / 2230)
//   SakuraProgressBar(value: (current + 1) / 20, height: 5)
class SakuraProgressBar extends StatelessWidget {
  final double value;   // 0.0 – 1.0
  final double height;

  const SakuraProgressBar({
    super.key,
    required this.value,
    this.height = 5,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            // Track
            Container(color: SakuraColors.progressTrack),
            // Fill (gradient)
            FractionallySizedBox(
              widthFactor: value.clamp(0.015, 1.0),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [SakuraColors.progressFill, SakuraColors.accentEnd],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Button styles ───────────────────────────────────────────────
abstract class SakuraButtonStyles {
  SakuraButtonStyles._();

  // Default nav / accordion button (white card with shadow)
  static ButtonStyle get card => ElevatedButton.styleFrom(
    backgroundColor: SakuraColors.surface,
    foregroundColor: SakuraColors.fg,
    disabledBackgroundColor: SakuraColors.surface,
    elevation: 0, // use BoxDecoration shadow instead via InkWell
    shadowColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: SakuraShapes.btnBorderRadius,
    ),
    padding: const EdgeInsets.symmetric(
      vertical: SakuraShapes.buttonPaddingV,
      horizontal: SakuraShapes.buttonPaddingH,
    ),
  );

  // Primary accent button (Next →, confirm actions)
  static ButtonStyle get accent => ElevatedButton.styleFrom(
    backgroundColor: SakuraColors.accent,
    foregroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: SakuraShapes.btnBorderRadius,
    ),
    padding: const EdgeInsets.symmetric(
      vertical: 14,
      horizontal: SakuraShapes.buttonPaddingH,
    ),
    textStyle: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
    ),
  );
}

// ─── Full ThemeData ──────────────────────────────────────────────
class SakuraThemeV2 {
  SakuraThemeV2._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Scaffold background — warm cream
    scaffoldBackgroundColor: SakuraColors.bg,

    // Color scheme
    colorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: SakuraColors.accent,
      onPrimary: Colors.white,
      primaryContainer: SakuraColors.accentLight,
      onPrimaryContainer: SakuraColors.fg,
      secondary: SakuraColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: SakuraColors.accentLight,
      onSecondaryContainer: SakuraColors.fg,
      surface: SakuraColors.surface,
      onSurface: SakuraColors.fg,
      surfaceContainerHighest: SakuraColors.accentLight,
      error: SakuraColors.incorrect,
      onError: Colors.white,
      errorContainer: SakuraColors.incorrectBg,
      onErrorContainer: SakuraColors.incorrect,
      outline: SakuraColors.border,
      outlineVariant: SakuraColors.border,
    ),

    // AppBar — no elevation, cream background
    appBarTheme: const AppBarTheme(
      backgroundColor: SakuraColors.bg,
      foregroundColor: SakuraColors.fg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        color: SakuraColors.fg,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
      ),
      iconTheme: IconThemeData(color: SakuraColors.fg, size: 22),
      actionsIconTheme: IconThemeData(color: SakuraColors.muted, size: 22),
    ),

    // Elevated button (default card-style buttons)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: SakuraColors.surface,
        foregroundColor: SakuraColors.fg,
        disabledBackgroundColor: SakuraColors.surface,
        disabledForegroundColor: SakuraColors.muted,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: const Color(0x1A3D1A26),
        shape: const RoundedRectangleBorder(
          borderRadius: SakuraShapes.btnBorderRadius,
        ),
        padding: const EdgeInsets.symmetric(
          vertical: SakuraShapes.buttonPaddingV,
          horizontal: SakuraShapes.buttonPaddingH,
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
      ),
    ),

    // Text button (links like "Already know this")
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: SakuraColors.accent,
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        ),
      ),
    ),

    // Card
    cardTheme: CardThemeData(
      color: SakuraColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SakuraShapes.containerRadius),
      ),
      margin: EdgeInsets.zero,
    ),

    // ListTile (used for nav items)
    listTileTheme: const ListTileThemeData(
      tileColor: SakuraColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: SakuraShapes.btnBorderRadius,
      ),
      contentPadding: EdgeInsets.symmetric(
        horizontal: SakuraShapes.buttonPaddingH,
        vertical: 4,
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: SakuraColors.divider,
      thickness: 1,
      space: 0,
    ),

    // Progress indicator (for simple non-gradient bars)
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: SakuraColors.accent,
      linearTrackColor: SakuraColors.progressTrack,
      linearMinHeight: 5,
      borderRadius: const BorderRadius.all(Radius.circular(99)),
    ),

    // Icon
    iconTheme: const IconThemeData(color: SakuraColors.fg, size: 22),

    // Checkbox (used in select-all / grid targets)
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return SakuraColors.accent;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.white),
      side: const BorderSide(color: SakuraColors.accent, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: SakuraColors.fg,
      contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'Inter'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),

    // Text theme
    textTheme: const TextTheme(
      // Used for AppBar titles, screen headings
      titleLarge: TextStyle(color: SakuraColors.fg, fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
      titleMedium: TextStyle(color: SakuraColors.fg, fontSize: 16, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
      titleSmall: TextStyle(color: SakuraColors.fg, fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
      // Body
      bodyLarge: TextStyle(color: SakuraColors.fg, fontSize: 15, fontWeight: FontWeight.w400, fontFamily: 'Inter'),
      bodyMedium: TextStyle(color: SakuraColors.fg, fontSize: 14, fontWeight: FontWeight.w400, fontFamily: 'Inter'),
      bodySmall: TextStyle(color: SakuraColors.muted, fontSize: 12, fontWeight: FontWeight.w400, fontFamily: 'Inter'),
      // Labels
      labelLarge: TextStyle(color: SakuraColors.fg, fontSize: 15, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
      labelMedium: TextStyle(color: SakuraColors.muted, fontSize: 12, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
      labelSmall: TextStyle(color: SakuraColors.muted, fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.7, fontFamily: 'Inter'),
    ),
  );
}
