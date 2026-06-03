import 'package:flutter/material.dart';
import '../repositories/sentence_repository.dart';
import '../theme.dart';

class StructuredSentence extends StatelessWidget {
  final List<SentenceToken> tokens;
  final String targetKanjiChar;
  final Set<String> knownChars;
  final bool showTargetHighlight;

  const StructuredSentence({
    super.key,
    required this.tokens,
    required this.targetKanjiChar,
    required this.knownChars,
    this.showTargetHighlight = true,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: tokens.map((t) => _buildToken(context, t)).toList(),
    );
  }

  Widget _buildToken(BuildContext context, SentenceToken token) {
    if (!token.isKanji) {
      return Text(token.surface,
        style: TextStyle(color: AppColors.fg, fontSize: 19, height: 1.8));
    }

    final isTarget = token.kanjiChar == targetKanjiChar;
    final isKnown = knownChars.contains(token.kanjiChar);
    final display = isTarget
        ? token.surface
        : isKnown
            ? token.surface
            : token.reading;

    if (isTarget && showTargetHighlight) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.btnBg,
          border: Border.all(color: AppColors.accent),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Text(display,
          style: TextStyle(color: AppColors.accentBright, fontSize: 19, height: 1.8)),
      );
    }

    return Text(display,
      style: TextStyle(
        color: isKnown ? AppColors.accentBright : AppColors.fg,
        fontSize: 19, height: 1.8,
      ));
  }
}
