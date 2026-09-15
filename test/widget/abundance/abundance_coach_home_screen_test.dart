import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_home_screen.dart';

void main() {
  testWidgets('coach home exposes distinct functional tool destinations',
      (tester) async {
    var selected = '';
    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachHomeScreen(onDestination: (key) => selected = key),
    ));

    expect(find.text('Coach tools'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Councils'), findsOneWidget);
    expect(find.text('Core Tasks'), findsOneWidget);
    await tester.tap(find.text('Councils'));
    expect(selected, 'coach_councils');
  });
}
