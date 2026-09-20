import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_quest_report_screen.dart';

void main() {
  final roster = <Map<String, dynamic>>[
    {
      'id': 'student-1',
      'firstName': 'Jamie',
      'lastName': 'Rivera',
      'council': 'Dawn Council',
      'goals': [
        {
          'status': 'IN_PROGRESS',
          'category': {'key': 'PERSONAL', 'name': 'Personal'},
          'title': 'Read every day',
          'targetValue': 10,
          'unit': 'days',
          'score': 75,
          'history': [
            {'date': '2026-09-20', 'amount': 4},
          ],
        },
      ],
    },
  ];

  testWidgets('denies the report to non-coaches', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachQuestReportScreen(
        isCoach: false,
        scope: AbundanceCoachReportScope.allStudents,
        rosterLoader: () async => roster,
      ),
    ));
    await tester.pump();

    expect(
        find.text('Coach access is required to view reports.'), findsOneWidget);
  });

  testWidgets('renders the all-students report sheet and filters',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachQuestReportScreen(
        isCoach: true,
        scope: AbundanceCoachReportScope.allStudents,
        rosterLoader: () async => roster,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('All students report'), findsOneWidget);
    expect(find.bySemanticsLabel('Choose report council'), findsOneWidget);
    expect(find.bySemanticsLabel('Choose report student'), findsOneWidget);
    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('End date'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('STUDENT'), findsOneWidget);
    expect(find.text('QUEST'), findsOneWidget);
    expect(find.text('Dawn Council'), findsOneWidget);
    expect(find.text('Read every day'), findsOneWidget);
  });

  testWidgets('renders assigned-student scope and a real empty state',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachQuestReportScreen(
        isCoach: true,
        scope: AbundanceCoachReportScope.assignedStudents,
        rosterLoader: () async => const [],
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('View quests report'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('No quests match these filters.'), findsOneWidget);
  });
}
