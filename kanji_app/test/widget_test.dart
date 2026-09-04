// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kanji_app/main.dart';

void main() {
  setUp(() {
    // Empty prefs → onboarding not complete, routing past the splash to the
    // onboarding screen (no repeating animations to leak timers).
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Kanji app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KanjiApp()));
    expect(find.byType(MaterialApp), findsOneWidget);

    // Advance past the 2400ms splash delay so the delayed timer fires and is
    // not left pending at teardown. No pumpAndSettle: the onboarding screen's
    // sakura overlay animates continuously (ticker-driven) and never settles.
    await tester.pump(const Duration(seconds: 3));
  });
}
