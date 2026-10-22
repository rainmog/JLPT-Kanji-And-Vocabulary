import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/utils/reading_guard.dart';

void main() {
  group('isPlausibleWordReading', () {
    test('accepts a full compound reading', () {
      expect(isPlausibleWordReading('会議', 'かいぎ'), isTrue);
      expect(isPlausibleWordReading('日記', 'にっき'), isTrue);
    });

    test('rejects a reading covering only one kanji of a compound', () {
      expect(isPlausibleWordReading('会議', 'ぎ'), isFalse);
      expect(isPlausibleWordReading('日記', 'き'), isFalse);
    });

    test('rejects an empty reading', () {
      expect(isPlausibleWordReading('会議', ''), isFalse);
    });

    test('counts only kanji, not okurigana, against the reading length', () {
      // 2 kanji + kana; a 2-mora reading is the floor, not the kana count.
      expect(isPlausibleWordReading('冷や汗', 'ひやあせ'), isTrue);
    });

    test('accepts single-kanji words with a one-kana reading', () {
      expect(isPlausibleWordReading('木', 'き'), isTrue);
    });

    test('counts 々 as a kanji', () {
      expect(isPlausibleWordReading('人々', 'ひとびと'), isTrue);
      expect(isPlausibleWordReading('人々', 'ひ'), isFalse);
    });
  });
}
