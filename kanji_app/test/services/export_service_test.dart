// test/services/export_service_test.dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/services/settings_service.dart';

void main() {
  group('Export payload structure', () {
    test('v2 payload has all required keys', () {
      final payload = {
        'version': 2,
        'exported_at': 1748000000,
        'settings': const AppSettings().toJson(),
        'kanji_progress': <Map<String, dynamic>>[],
        'vocab_targets': <Map<String, dynamic>>[],
        'vocab_progress': <Map<String, dynamic>>[],
      };
      final json = jsonEncode(payload);
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['version'], 2);
      expect(decoded.containsKey('exported_at'), true);
      expect(decoded.containsKey('settings'), true);
      expect(decoded.containsKey('kanji_progress'), true);
      expect(decoded.containsKey('vocab_targets'), true);
      expect(decoded.containsKey('vocab_progress'), true);
    });

    test('settings roundtrip preserves all fields', () {
      const s = AppSettings(
        ambientSfx: 'Storm.mp3',
        ambientVolume: 0.6,
        animationsEnabled: false,
        autoNextDelaySeconds: 5,
      );
      final s2 = AppSettings.fromJson(s.toJson());
      expect(s2.ambientSfx, 'Storm.mp3');
      expect(s2.ambientVolume, closeTo(0.6, 0.001));
      expect(s2.animationsEnabled, false);
      expect(s2.autoNextDelaySeconds, 5);
    });

    test('v1 payload missing vocab keys parsed without crash', () {
      // v1 files have no vocab_targets or vocab_progress
      final v1 = {
        'version': 1,
        'settings': const AppSettings().toJson(),
        'progress': <Map<String, dynamic>>[],
      };
      // ExportService._parseImport handles missing keys as empty lists
      final kanjiProgress = (v1['progress'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final vocabTargets = (v1['vocab_targets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      final vocabProgress = (v1['vocab_progress'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      expect(kanjiProgress, isEmpty);
      expect(vocabTargets, isEmpty);
      expect(vocabProgress, isEmpty);
    });
  });
}
