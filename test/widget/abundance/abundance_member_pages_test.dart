import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_achievements_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_character_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_missions_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_more_sheet.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_tutorial_screen.dart';
import 'package:selfcare_projects/src/features/abundance/domain/domain.dart'
    as a12;
import 'package:selfcare_projects/src/features/abundance/services/abundance_achievements_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_missions_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/authentication/screen/todo_list.dart';

class _FakeMissionsGateway implements AbundanceMissionsGateway {
  _FakeMissionsGateway({this.failCompletion = false, List<Task>? seed}) {
    if (seed != null) {
      tasks
        ..clear()
        ..addAll(seed);
    }
  }
  final bool failCompletion;
  Task? updatedTask;
  final tasks = <Task>[
    Task(
      id: 'm1',
      title: 'Read 10 pages',
      goalType: GoalType.everyday,
      startDate: DateTime(2026, 9, 1),
      dueDate: DateTime(2026, 9, 30),
    ),
  ];

  @override
  Future<List<Task>> load() async => tasks;

  @override
  Future<void> create(Task task) async => tasks.add(task);

  @override
  Future<void> delete(String id) async => tasks.removeWhere((t) => t.id == id);

  @override
  Future<void> update(Task task) async {
    if (failCompletion) throw Exception('offline');
    updatedTask = task;
  }
}

class _FakeGoalsService extends GoalsService {
  _FakeGoalsService(this.goals) : super(null);

  final List<GoalSummary> goals;

  @override
  Stream<List<GoalSummary>> watchGoals(String uid) => Stream.value(goals);
}

void main() {
  testWidgets('missions page loads tasks and rolls back failed completion',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final gateway = _FakeMissionsGateway(failCompletion: true);
    await tester.pumpWidget(MaterialApp(
      home: AbundanceMissionsScreen(
        gateway: gateway,
        initialDate: DateTime(2026, 9, 15),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('EVERYDAY MISSIONS'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    expect(find.text('Read 10 pages'), findsOneWidget);
    await tester.tap(find.text('Read 10 pages'));
    await tester.pumpAndSettle();
    expect(find.text('We could not update that mission.'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('missions exclude long-term goals and disable future completion',
      (tester) async {
    final gateway = _FakeMissionsGateway(seed: <Task>[
      Task(
        id: 'daily',
        title: 'Daily practice',
        goalType: GoalType.everyday,
        startDate: DateTime(2026, 9, 1),
        dueDate: DateTime(2026, 9, 30),
      ),
      Task(
        id: 'quest',
        title: 'Long-term quest',
        goalType: GoalType.longTerm,
        startDate: DateTime(2026, 9, 1),
        dueDate: DateTime(2026, 9, 30),
      ),
    ]);
    await tester.pumpWidget(MaterialApp(
      home: AbundanceMissionsScreen(
        gateway: gateway,
        initialDate: DateTime(2026, 9, 16),
        today: DateTime(2026, 9, 15),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('16').last);
    await tester.pumpAndSettle();
    expect(find.text('Daily practice'), findsOneWidget);
    expect(find.text('Long-term quest'), findsNothing);
  });

  testWidgets('selected day can add a mission through the source dialog',
      (tester) async {
    final gateway = _FakeMissionsGateway();
    await tester.pumpWidget(MaterialApp(
      home: AbundanceMissionsScreen(
        gateway: gateway,
        initialDate: DateTime(2026, 9, 15),
        today: DateTime(2026, 9, 15),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a mission'));
    await tester.pumpAndSettle();
    final titleField = find.byType(TextField).first;
    await tester.enterText(titleField, 'Read 20 pages');
    await tester.tap(find.text('Add mission'));
    await tester.pumpAndSettle();
    expect(find.text('Read 20 pages'), findsOneWidget);
    expect(gateway.tasks.any((task) => task.title == 'Read 20 pages'), isTrue);
  });

  testWidgets('mission selector keeps its icon in sync with the chosen type',
      (tester) async {
    final gateway = _FakeMissionsGateway();
    await tester.pumpWidget(MaterialApp(
      home: AbundanceMissionsScreen(
        gateway: gateway,
        initialDate: DateTime(2026, 9, 15),
        today: DateTime(2026, 9, 15),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a mission'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.self_improvement), findsWidgets);

    await tester.tap(find.byType(DropdownButtonFormField<TaskTag>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercise / movements').last);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.directions_run), findsWidgets);
  });

  testWidgets('creating a mission notifies the shell to refresh Home',
      (tester) async {
    final gateway = _FakeMissionsGateway();
    var changed = false;
    await tester.pumpWidget(MaterialApp(
      home: AbundanceMissionsScreen(
        gateway: gateway,
        initialDate: DateTime(2026, 9, 15),
        today: DateTime(2026, 9, 15),
        onMissionChanged: () => changed = true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a mission'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).first, 'Meditate for 10 minutes');
    await tester.tap(find.text('Add mission'));
    await tester.pumpAndSettle();

    expect(changed, isTrue);
  });

  testWidgets('achievements distinguish earned and locked awards',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AbundanceAchievementsScreen(unlockedKeys: {'first-flame'}),
    ));

    expect(find.text('THE HALL OF RECORDS'), findsOneWidget);
    expect(find.text('RECENTLY UNLOCKED'), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
    expect(find.text('First Flame'), findsOneWidget);
  });

  testWidgets('achievements load earned state instead of defaulting to zero',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AbundanceAchievementsScreen(
        loader: () async => {'first-flame', 'finished-first'},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsWidgets);
  });

  test('live achievements derive awards from missions and quests', () async {
    final missions = _FakeMissionsGateway();
    missions.tasks[0] = Task(
      id: 'm1',
      title: 'Read 10 pages',
      goalType: GoalType.everyday,
      startDate: DateTime(2026, 9, 1),
      dueDate: DateTime(2026, 9, 30),
      completionDates: <DateTime>[
        DateTime(2026, 9, 13),
        DateTime(2026, 9, 14),
        DateTime(2026, 9, 15),
      ],
    );
    final goals = _FakeGoalsService(<GoalSummary>[
      GoalSummary(
        id: 'g1',
        userId: 'member-1',
        companyId: 'ABU15DN',
        title: 'Launch the project',
        description: null,
        notes: null,
        status: a12.GoalStatus.completed,
        progress: 100,
        category: a12.GoalCategory.personal,
        goalType: a12.GoalType.milestone,
        targetPeriod: a12.TargetPeriod.none,
        direction: a12.GoalDirection.gain,
        targetValue: 1,
        currentValue: 1,
        unit: 'project',
        startDate: DateTime(2026, 9, 1),
        targetDate: DateTime(2026, 9, 15),
        completedAt: DateTime(2026, 9, 15),
      ),
    ]);
    final gateway = InnerUAbundanceAchievementsGateway(
      uid: 'member-1',
      goals: goals,
      missions: missions,
    );

    final unlocked = await gateway.load();

    expect(
      unlocked,
      containsAll(<String>{
        'first-flame',
        'finding-rythm',
        'finished-first',
        'quest-architect',
        'high-performer',
      }),
    );
  });

  testWidgets('More shows coach tools only for coaches', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AbundanceMoreSheet(
          isCoach: false,
          onDestination: (_) {},
        ),
      ),
    ));
    expect(find.text('Students'), findsNothing);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AbundanceMoreSheet(
          isCoach: true,
          onDestination: (_) {},
        ),
      ),
    ));
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Core Tasks'), findsOneWidget);
    expect(find.text('Replay tutorial'), findsOneWidget);
  });

  testWidgets('More remains usable on a compact screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(640, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AbundanceMoreSheet(
          isCoach: true,
          onDestination: (_) {},
        ),
      ),
    ));

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.drag(
        find.byType(SingleChildScrollView), const Offset(0, -250));
    await tester.pump();
    expect(find.text('Log out'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Character selection persists through the provided repository',
      (tester) async {
    var selected = 'warrior';
    await tester.pumpWidget(MaterialApp(
      home: AbundanceCharacterScreen(
        uid: 'member-1',
        loadCharacter: (_) async => selected,
        saveCharacter: (_, value) async => selected = value,
        onOpenAccountSettings: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('YOUR CHARACTER'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('character-mage')));
    await tester.pumpAndSettle();
    expect(selected, 'mage');
  });

  testWidgets('failed character persistence rolls selection back',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AbundanceCharacterScreen(
        uid: 'member-1',
        loadCharacter: (_) async => 'warrior',
        saveCharacter: (_, __) async => throw Exception('offline'),
        onOpenAccountSettings: () {},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('character-mage')));
    await tester.pumpAndSettle();

    final warrior = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey('character-warrior')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect((warrior.decoration! as BoxDecoration).border,
        isA<Border>().having((b) => b.top.width, 'selected width', 2));
    expect(find.text('We could not save your character.'), findsOneWidget);
  });

  testWidgets('tutorial advances and records completion', (tester) async {
    var completedFor = '';
    await tester.pumpWidget(MaterialApp(
      home: AbundanceTutorialScreen(
        uid: 'member-1',
        saveCompletion: (uid) async => completedFor = uid,
      ),
    ));

    expect(find.text('WELCOME TO ABUNDANCE 12'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter the game'));
    await tester.pumpAndSettle();
    expect(completedFor, 'member-1');
  });
}
