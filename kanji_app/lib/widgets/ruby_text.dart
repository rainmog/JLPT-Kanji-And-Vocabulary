import 'package:flutter/material.dart';
import '../theme.dart';

/// Renders Japanese text with inline furigana.
///
/// Input format: plain text with `{kanji|reading}` segments mixed in.
/// Example: `{電車|でんしゃ}で {学校|がっこう}に {行きます|いきます}。`
class RubyText extends StatelessWidget {
  final String text;
  final double fontSize;
  final Color? color;
  final double? height;
  final bool showFurigana;
  final bool centered;
  /// Suppress furigana for compound segments where all kanji chars are in this set.
  final Set<String>? suppressedKanji;

  const RubyText(
    this.text, {
    super.key,
    this.fontSize = 16,
    this.color,
    this.height,
    this.showFurigana = true,
    this.centered = false,
    this.suppressedKanji,
  });

  static bool _isKanjiChar(String c) {
    final code = c.codeUnitAt(0);
    return (code >= 0x4E00 && code <= 0x9FFF) ||
        (code >= 0x3400 && code <= 0x4DBF) ||
        (code >= 0xF900 && code <= 0xFAFF);
  }

  bool _isSuppressed(String surface) {
    if (suppressedKanji == null) return false;
    final kanjiChars = surface.split('').where(_isKanjiChar).toList();
    if (kanjiChars.isEmpty) return false;
    return kanjiChars.every((c) => suppressedKanji!.contains(c));
  }

  @override
  Widget build(BuildContext context) {
    final segments = _parse(text);
    final fg = color ?? AppColors.fg;
    final baseStyle = TextStyle(
      fontSize: fontSize,
      color: fg,
      height: height,
      fontFamily: 'NotoSerifCJKjp',
    );
    final spans = segments.map<InlineSpan>((s) {
      if (s.reading == null || !showFurigana || _isSuppressed(s.text)) {
        return TextSpan(text: s.text, style: baseStyle);
      }
      return WidgetSpan(
        alignment: PlaceholderAlignment.bottom,
        child: _RubyPair(
          kanji: s.text,
          reading: s.reading!,
          fontSize: fontSize,
          color: fg,
        ),
      );
    }).toList();
    return RichText(
      textAlign: centered ? TextAlign.center : TextAlign.start,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  static List<_Segment> _parse(String input) {
    final segments = <_Segment>[];
    final re = RegExp(r'\{([^|]+)\|([^}]+)\}');
    int cursor = 0;
    for (final m in re.allMatches(input)) {
      if (m.start > cursor) {
        segments.add(_Segment(input.substring(cursor, m.start)));
      }
      segments.add(_Segment(m.group(1)!, reading: m.group(2)));
      cursor = m.end;
    }
    if (cursor < input.length) {
      segments.add(_Segment(input.substring(cursor)));
    }
    return segments;
  }
}

class _Segment {
  final String text;
  final String? reading;
  const _Segment(this.text, {this.reading});
}

class _RubyPair extends StatelessWidget {
  final String kanji;
  final String reading;
  final double fontSize;
  final Color color;

  const _RubyPair({
    required this.kanji,
    required this.reading,
    required this.fontSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final rubySize = (fontSize * 0.48).clamp(7.0, 11.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          reading,
          style: TextStyle(
            fontSize: rubySize,
            color: color.withAlpha(180),
            fontFamily: 'NotoSerifCJKjp',
            height: 1.2,
          ),
        ),
        Text(
          kanji,
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontFamily: 'NotoSerifCJKjp',
            height: 1.0,
          ),
        ),
      ],
    );
  }
}
