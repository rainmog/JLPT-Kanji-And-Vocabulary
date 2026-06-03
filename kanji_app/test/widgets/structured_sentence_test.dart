import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/widgets/structured_sentence.dart';
import 'package:kanji_app/repositories/sentence_repository.dart';

void main() {
  testWidgets('renders hiragana for unknown kanji', (tester) async {
    final tokens = [
      const SentenceToken(surface: '私', reading: 'わたし', isKanji: true, kanjiChar: '私'),
      const SentenceToken(surface: 'は', reading: 'は', isKanji: false, kanjiChar: null),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StructuredSentence(
        tokens: tokens,
        targetKanjiChar: '食',
        knownChars: const {},
      )),
    ));
    expect(find.text('わたし'), findsOneWidget);
    expect(find.text('は'), findsOneWidget);
  });

  testWidgets('renders kanji for known kanji', (tester) async {
    final tokens = [
      const SentenceToken(surface: '私', reading: 'わたし', isKanji: true, kanjiChar: '私'),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: StructuredSentence(
        tokens: tokens,
        targetKanjiChar: '食',
        knownChars: const {'私'},
      )),
    ));
    expect(find.text('私'), findsOneWidget);
  });
}
