import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/utils/romaji_converter.dart';

void main() {
  group('RomajiConverter.convert', () {
    test('basic vowels', () {
      expect(RomajiConverter.convert('aiueo'), 'あいうえお');
    });
    test('ka row', () {
      expect(RomajiConverter.convert('kakikukeko'), 'かきくけこ');
    });
    test('shi', () {
      expect(RomajiConverter.convert('shi'), 'し');
    });
    test('chi', () {
      expect(RomajiConverter.convert('chi'), 'ち');
    });
    test('tsu', () {
      expect(RomajiConverter.convert('tsu'), 'つ');
    });
    test('double consonant', () {
      expect(RomajiConverter.convert('kitte'), 'きって');
      expect(RomajiConverter.convert('kekkon'), 'けっこん');
    });
    test('n before consonant', () {
      expect(RomajiConverter.convert('anzen'), 'あんぜん');
    });
    test('full word', () {
      expect(RomajiConverter.convert('taberu'), 'たべる');
      expect(RomajiConverter.convert('watashi'), 'わたし');
      expect(RomajiConverter.convert('nihongo'), 'にほんご');
    });
  });
}
