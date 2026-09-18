import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_math.dart';

void main() {
  group('tutorialRouteFor', () {
    test('returns no navigation for equivalent shell tab aliases', () {
      expect(tutorialRouteFor('/(tabs)', '/'), isNull);
      expect(tutorialRouteFor('/(tabs)', '/dashboard'), isNull);
      expect(tutorialRouteFor('/', '/(tabs)'), isNull);
      expect(tutorialRouteFor('/quests', '/goals'), isNull);
      expect(tutorialRouteFor('/guild', '/allies'), isNull);
    });

    test('returns the requested route when the current tab differs', () {
      expect(tutorialRouteFor('/missions', '/profile'), '/missions');
      expect(tutorialRouteFor('/(tabs)', '/profile'), '/(tabs)');
      expect(tutorialRouteFor(null, '/profile'), isNull);
    });
  });

  group('tutorialScrollOffset', () {
    test('keeps a target in the readable viewport without scrolling', () {
      expect(
        tutorialScrollOffset(
          targetTop: 230,
          targetHeight: 100,
          viewportTop: 100,
          currentOffset: 240,
          viewportHeight: 850,
        ),
        isNull,
      );
    });

    test('scrolls a lower target to the reading position', () {
      expect(
        tutorialScrollOffset(
          targetTop: 720,
          targetHeight: 120,
          viewportTop: 100,
          currentOffset: 250,
          viewportHeight: 850,
        ),
        630,
      );
    });

    test('scrolls an upper target without requesting a negative offset', () {
      expect(
        tutorialScrollOffset(
          targetTop: 60,
          targetHeight: 120,
          viewportTop: 100,
          currentOffset: 0,
          viewportHeight: 850,
        ),
        0,
      );
    });
  });

  group('tutorialSheetPlacement', () {
    test('defaults to the bottom when there is no target', () {
      expect(
        tutorialSheetPlacement(
          targetTop: null,
          targetBottom: null,
          sheetHeight: 220,
          safeTop: 70,
          safeBottom: 740,
          gap: 12,
        ),
        AbundanceTutorialSheetPlacement.bottom,
      );
    });

    test('uses the top when the top safe area has enough room', () {
      expect(
        tutorialSheetPlacement(
          targetTop: 340,
          targetBottom: 560,
          sheetHeight: 220,
          safeTop: 70,
          safeBottom: 740,
          gap: 12,
        ),
        AbundanceTutorialSheetPlacement.top,
      );
    });

    test('uses the bottom when the top would cover the target', () {
      expect(
        tutorialSheetPlacement(
          targetTop: 160,
          targetBottom: 300,
          sheetHeight: 220,
          safeTop: 70,
          safeBottom: 740,
          gap: 12,
        ),
        AbundanceTutorialSheetPlacement.bottom,
      );
    });

    test('chooses the side with more safe space when neither fits', () {
      expect(
        tutorialSheetPlacement(
          targetTop: 200,
          targetBottom: 580,
          sheetHeight: 250,
          safeTop: 70,
          safeBottom: 740,
          gap: 12,
        ),
        AbundanceTutorialSheetPlacement.bottom,
      );
    });
  });

  test('stores rectangle geometry as immutable value data', () {
    const rect = AbundanceTutorialRect(
      left: 12,
      top: 24,
      width: 180,
      height: 96,
    );

    expect(rect.left, 12);
    expect(rect.top, 24);
    expect(rect.width, 180);
    expect(rect.height, 96);
    expect(
      rect,
      const AbundanceTutorialRect(left: 12, top: 24, width: 180, height: 96),
    );
  });
}
