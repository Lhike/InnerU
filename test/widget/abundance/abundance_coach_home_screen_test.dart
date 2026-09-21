import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_home_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_management_screens.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_student_file_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_coach_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';

class _HistoryTransport implements AbundanceApiTransport {
  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async =>
      const {};

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    if (path == '/coach/roster') {
      return const {
        'students': [
          {
            'id': 'a12-student-1',
            'firstName': 'Aria',
            'lastName': 'Stone',
            'email': 'aria@example.test',
          }
        ],
      };
    }
    if (path == '/coach/students/a12-student-1') {
      return const {
        'student': {
          'id': 'a12-student-1',
          'firstName': 'Aria',
          'lastName': 'Stone',
          'email': 'aria@example.test',
          'council': 'Dawn Council',
        },
        'goals': [],
        'missions': [],
        'missionCalendar': [],
      };
    }
    if (path == '/coach/students/a12-student-1/notes') {
      return const {
        'notes': [
          {
            'id': 'note-1',
            'body': 'Nice one',
            'createdAt': '2026-09-20T10:00:00Z'
          }
        ],
      };
    }
    return const {
      'items': [
        {
          'id': 'action-1',
          'title': 'Review your mission',
          'dueDate': '2026-09-29',
          'status': 'OPEN',
        }
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body,
          {String? token}) async =>
      const {};

  @override
  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body,
          {String? token}) async =>
      const {};
}

void main() {
  testWidgets('coach home exposes distinct functional tool destinations',
      (tester) async {
    var selected = '';
    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachHomeScreen(onDestination: (key) => selected = key),
    ));

    expect(find.text('Coach tools'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Councils'), findsNothing);
    expect(find.text('Core Tasks'), findsOneWidget);
    await tester.tap(find.text('Students'));
    expect(selected, 'coach_students');
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

  testWidgets('Abundance students render the assigned A12 roster shape',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachStudentsScreen(
        loader: () async => <Map<String, dynamic>>[
          {
            'id': 'a12-student-1',
            'firstName': 'Cookie',
            'lastName': 'Milo',
            'email': 'cookie@example.test',
            'council': 'Dawn Council',
          },
        ],
        onOpenManagement: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Cookie Milo'), findsOneWidget);
    expect(find.text('Dawn Council'), findsOneWidget);
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
    final navigation = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(navigation.currentIndex, 6);
    expect(find.text('Coaching'), findsOneWidget);
  });

  testWidgets('student file uses a calendar picker for optional due dates',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachStudentFileScreen(
        student: const {'id': 'student-1', 'name': 'Aria Stone'},
        loader: (_) => SynchronousFuture<List<Map<String, dynamic>>>(const []),
      ),
    ));
    await tester.pumpAndSettle();
    for (var index = 0; index < 4; index += 1) {
      await tester.fling(
          find.byType(ListView).first, const Offset(0, -500), 1000);
      await tester.pumpAndSettle();
    }

    expect(find.byType(TextField), findsNWidgets(3));
    expect(find.text('ACTION ITEM'), findsOneWidget);
    expect(find.text('DUE DATE (OPTIONAL)'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsWidgets);

    await tester.tap(find.byType(TextField).last);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);
  });

  testWidgets('student file can hide and reveal coaching history',
      (tester) async {
    final transport = _HistoryTransport();
    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachStudentFileScreen(
        student: const {'id': 'a12-student-1', 'name': 'Aria Stone'},
        goalsService: GoalsService(null, transport),
        coachService: AbundanceCoachService(transport: transport),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Nice one'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nice one'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Hide history'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Hide history'));
    await tester.pumpAndSettle();
    expect(find.text('Nice one'), findsNothing);
    expect(find.text('Review your mission'), findsNothing);

    await tester.tap(find.text('Show history'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Nice one'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Nice one'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Review your mission'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Review your mission'), findsOneWidget);
  });
}
