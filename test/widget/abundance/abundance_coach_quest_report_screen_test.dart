import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_quest_report_screen.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';

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

    final councilButton = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.text('All councils'),
        matching: find.byType(OutlinedButton),
      ),
    );
    expect(
      councilButton.style?.backgroundColor?.resolve(<WidgetState>{})?.a,
      greaterThan(.9),
    );
    expect(
      councilButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      isNot(AbundanceColors.foreground),
    );

    await tester.tap(find.bySemanticsLabel('Choose report council'));
    await tester.pumpAndSettle();
    expect(find.text('Choose report council'), findsOneWidget);
    final councilOption = tester.widget<Text>(find.text('Dawn Council'));
    expect(councilOption.style?.color, AbundanceColors.foreground);
    await tester.tap(find.text('Dawn Council'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(find.text('STUDENT'), findsOneWidget);
    expect(find.text('QUEST'), findsOneWidget);
    expect(find.textContaining('Dawn Council'), findsAtLeastNWidgets(1));
    expect(find.text('Read every day'), findsOneWidget);

    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.dataTextStyle?.color, AbundanceColors.foreground);
    expect(table.headingTextStyle?.color, AbundanceColors.muted);
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
