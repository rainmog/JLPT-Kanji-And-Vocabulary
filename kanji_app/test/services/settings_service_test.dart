// test/services/settings_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/services/settings_service.dart';

void main() {
  group('AppSettings serialization', () {
    test('toJson includes animationsEnabled and ambientVolume', () {
      const s = AppSettings(animationsEnabled: false, ambientVolume: 0.5);
      final j = s.toJson();
      expect(j['animationsEnabled'], false);
      expect(j['ambientVolume'], 0.5);
    });

    test('fromJson defaults animationsEnabled true, ambientVolume 1.0', () {
      final s = AppSettings.fromJson({});
      expect(s.animationsEnabled, true);
      expect(s.ambientVolume, 1.0);
    });

    test('fromJson roundtrips animationsEnabled false', () {
      const s = AppSettings(animationsEnabled: false, ambientVolume: 0.3);
      final s2 = AppSettings.fromJson(s.toJson());
      expect(s2.animationsEnabled, false);
      expect(s2.ambientVolume, closeTo(0.3, 0.001));
    });

    test('copyWith preserves new fields', () {
      const s = AppSettings(animationsEnabled: false, ambientVolume: 0.7);
      final s2 = s.copyWith(autoNextDelaySeconds: 5);
      expect(s2.animationsEnabled, false);
      expect(s2.ambientVolume, 0.7);
    });
  });
}
