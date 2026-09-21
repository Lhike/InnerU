import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_directory_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';

void main() {
  testWidgets('renders the source coach list and both report actions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AbundanceCoachDirectoryScreen(
          service: GoalsService(null, A12ApiTransport()),
          coachUid: 'coach-1',
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('Charlie Gengos'), findsOneWidget);
    expect(find.text('Migs Flores'), findsOneWidget);
    expect(find.text('All students report'), findsOneWidget);
    expect(find.text('View quests report'), findsOneWidget);

    final reportButtons = tester
        .widgetList<OutlinedButton>(
          find.byType(OutlinedButton),
        )
        .toList();
    expect(reportButtons, hasLength(2));
    for (final button in reportButtons) {
      expect(
        button.style?.backgroundColor?.resolve(<WidgetState>{}),
        AbundanceColors.surfaceRaised,
      );
      expect(
        button.style?.foregroundColor?.resolve(<WidgetState>{}),
        AbundanceColors.primaryGold,
      );
    }

    await tester.tap(find.text('Charlie Gengos'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('I play the Game of Life, Abundantly'), findsNWidgets(2));
    expect(find.textContaining('Chairman of GENCYS'), findsOneWidget);
    expect(find.text('Close coach details'), findsOneWidget);

    final images = tester.widgetList<Image>(find.byType(Image));
    expect(images.any((image) => image.fit == BoxFit.contain), isTrue);
  });
}
