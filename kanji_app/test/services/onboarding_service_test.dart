// test/services/onboarding_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kanji_app/services/onboarding_service.dart';

void main() {
  group('OnboardingService.levelBounds', () {
    test('N5 level bounds: learned=none, targetAll=none, targetLevel=5', () {
      final b = OnboardingService.levelBoundsForReview(5);
      expect(b.learnedLevels, isEmpty);
      expect(b.targetAllLevels, isEmpty);
      expect(b.targetSampleLevel, 5);
    });

    test('N3 review: learned=[5], targetAll=[4], targetSample=3', () {
      final b = OnboardingService.levelBoundsForReview(3);
      expect(b.learnedLevels, [5]);
      expect(b.targetAllLevels, [4]);
      expect(b.targetSampleLevel, 3);
    });

    test('N2 review: learned=[5,4], targetAll=[3], targetSample=2', () {
      final b = OnboardingService.levelBoundsForReview(2);
      expect(b.learnedLevels, containsAll([5, 4]));
      expect(b.targetAllLevels, [3]);
      expect(b.targetSampleLevel, 2);
    });

    test('N1 review: learned=[5,4,3], targetAll=[2], targetSample=1', () {
      final b = OnboardingService.levelBoundsForReview(1);
      expect(b.learnedLevels, containsAll([5, 4, 3]));
      expect(b.targetAllLevels, [2]);
      expect(b.targetSampleLevel, 1);
    });

    test('N3 new-stuff: learned=[5,4], targetAll=[], targetSample=3', () {
      final b = OnboardingService.levelBoundsForNewStuff(3);
      expect(b.learnedLevels, containsAll([5, 4]));
      expect(b.targetAllLevels, isEmpty);
      expect(b.targetSampleLevel, 3);
    });

    test('N4 new-stuff: learned=[5], targetAll=[], targetSample=4', () {
      final b = OnboardingService.levelBoundsForNewStuff(4);
      expect(b.learnedLevels, [5]);
      expect(b.targetAllLevels, isEmpty);
      expect(b.targetSampleLevel, 4);
    });
  });
}
