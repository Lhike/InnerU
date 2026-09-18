import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_missions_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_missions_service.dart';
import 'package:selfcare_projects/src/features/authentication/screen/todo_list.dart';

class _SetupGateway implements AbundanceMissionsGateway {
  _SetupGateway()
      : tasks = <Task>[
          Task(
            id: 'daily-1',
            title: 'Read 10 pages',
            description: 'Build the habit.',
            goalType: GoalType.everyday,
            startDate: DateTime(2026, 9, 1),
            dueDate: DateTime(2026, 9, 30),
          ),
        ];

  final List<Task> tasks;

  @override
  Future<List<Task>> load() async => tasks;

  @override
  Future<void> create(Task task) async {
    task.id = 'daily-${tasks.length + 1}';
    tasks.add(task);
  }

  @override
  Future<void> update(Task task) async {
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index >= 0) tasks[index] = task;
  }

  @override
  Future<void> delete(String id) async {
    tasks.removeWhere((task) => task.id == id);
  }
}

void main() {
  testWidgets('daily mission setup can add, edit, and remove missions',
      (tester) async {
    final gateway = _SetupGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: AbundanceMissionsScreen(
          gateway: gateway,
          initialDate: DateTime(2026, 9, 15),
          today: DateTime(2026, 9, 15),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Set up your daily mission'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Set up your daily mission'));
    await tester.pumpAndSettle();
    expect(find.text('Set up your daily mission'), findsNWidgets(2));
    expect(find.text('Read 10 pages'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Edit Read 10 pages'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('mission-title-field')), 'Read 20 pages');
    await tester.tap(find.text('Save mission'));
    await tester.pumpAndSettle();
    expect(gateway.tasks.single.title, 'Read 20 pages');

    await tester.tap(find.text('Add a daily mission'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('mission-title-field')),
        'Stretch for 5 minutes');
    await tester.tap(find.text('Create mission'));
    await tester.pumpAndSettle();
    expect(gateway.tasks.map((task) => task.title),
        contains('Stretch for 5 minutes'));

    await tester.tap(find.byTooltip('Remove Read 20 pages'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(gateway.tasks.map((task) => task.title),
        isNot(contains('Read 20 pages')));
  });
}
