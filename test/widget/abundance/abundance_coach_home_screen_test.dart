import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_home_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_management_screens.dart';

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

  testWidgets('coach management routes render the matching InnerU data',
      (tester) async {
    Future<List<Map<String, dynamic>>> load() async => <Map<String, dynamic>>[
          {'name': 'Dawn Council', 'memberCount': 4},
        ];

    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachCouncilsScreen(
        loader: load,
        onOpenMeetings: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Dawn Council'), findsOneWidget);
    expect(find.text('4 members'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachStudentsScreen(
        loader: () async => <Map<String, dynamic>>[
          {'name': 'Aria Stone', 'groupName': 'Dawn Council'},
        ],
        onOpenManagement: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Aria Stone'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachCoreTasksScreen(
        loader: () async => <Map<String, dynamic>>[
          {'title': 'Morning focus', 'studentName': 'Aria Stone'},
        ],
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Morning focus'), findsOneWidget);
  });
}
