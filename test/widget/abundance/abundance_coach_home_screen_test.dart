import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_home_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_management_screens.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_student_file_screen.dart';

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

  testWidgets('council workspace exposes source-aligned creation controls',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachCouncilsScreen(
        loader: () async => <Map<String, dynamic>>[
          {'id': 'council-1', 'name': 'Dawn Council', 'memberCount': 2},
        ],
        onOpenMeetings: () {},
        createGroup: (_) async => 'council-2',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Create council'), findsOneWidget);
    await tester.tap(find.text('Create council'));
    await tester.pumpAndSettle();
    expect(find.text('Council name'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
  });

  testWidgets('student roster opens a server-backed student file',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachStudentFileScreen(
        student: const {'id': 'student-1', 'name': 'Aria Stone'},
        loader: (_) => SynchronousFuture<List<Map<String, dynamic>>>([
          {
            'title': 'Build a daily practice',
            'progress': 40,
            'status': 'active'
          },
        ]),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Aria Stone'), findsOneWidget);
    expect(find.text('Build a daily practice'), findsOneWidget);
  });
}
