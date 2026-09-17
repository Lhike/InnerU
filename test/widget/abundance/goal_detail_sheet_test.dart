import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/domain/domain.dart';
import 'package:selfcare_projects/src/features/abundance/screens/mentee/goal_detail_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/mentee/goal_detail_sheet.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';

void main() {
  testWidgets('goal cards use distinct daily and weekly schedule targets',
      (tester) async {
    final goal = GoalSummary(
      id: 'g1',
      userId: 'u1',
      companyId: 'A12',
      title: 'Build a habit',
      description: null,
      notes: null,
      status: GoalStatus.notStarted,
      progress: 0,
      category: GoalCategory.professional,
      goalType: GoalType.milestone,
      targetPeriod: TargetPeriod.none,
      direction: GoalDirection.gain,
      targetValue: 34,
      currentValue: 0,
      unit: 'KM',
      startDate: DateTime(2026, 9, 1),
      targetDate: DateTime(2026, 12, 15),
      completedAt: null,
      dailyTarget: .38,
      weeklyTarget: 2.66,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GoalDetailSheet(
          initialGoal: goal,
          service: GoalsService(FakeFirebaseFirestore()),
          uid: 'u1',
          onViewGoalPage: () async {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('0.38 KM'), findsOneWidget);
    expect(find.text('2.66 KM'), findsOneWidget);
  });

  testWidgets('goal preview opens in a sheet with a page escape hatch',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = GoalsService(firestore);
    await firestore.collection('users').doc('u1').set({'companyId': 'A12'});
    final goalId = await service.createGoal(
      uid: 'u1',
      category: GoalCategory.contribution,
      title: 'Build the community',
      targetDate: DateTime(2026, 9, 30),
      targetValue: 100,
      currentValue: 20,
      unit: 'KG',
      targetPeriod: TargetPeriod.weekly,
    );
    final goal = (await service.watchGoals('u1').first)
        .singleWhere((item) => item.id == goalId);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => showGoalDetailSheet(
                context,
                goal: goal,
                service: service,
                uid: 'u1',
              ),
              child: const Text('Open goal'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Open goal'));
    await tester.pumpAndSettle();

    expect(find.byType(GoalDetailSheet), findsOneWidget);
    expect(find.text('BUILD THE COMMUNITY'), findsOneWidget);
    expect(find.text('View goal page'), findsOneWidget);
    expect(find.byType(GoalDetailScreen), findsNothing);

    await tester.ensureVisible(find.text('View goal page'));
    await tester.tap(find.text('View goal page'));
    await tester.pumpAndSettle();
    expect(find.byType(GoalDetailSheet), findsNothing);
    expect(find.byType(GoalDetailScreen), findsOneWidget);
  });

  testWidgets('logging in the sheet updates the merit measure', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = GoalsService(firestore);
    await firestore.collection('users').doc('u1').set({'companyId': 'A12'});
    final goalId = await service.createGoal(
      uid: 'u1',
      category: GoalCategory.personal,
      title: 'Walk 100 km',
      targetDate: DateTime(2026, 9, 30),
      targetValue: 100,
      currentValue: 20,
      unit: 'KM',
    );
    final goal = (await service.watchGoals('u1').first)
        .singleWhere((item) => item.id == goalId);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => showGoalDetailSheet(
              context,
              goal: goal,
              service: service,
              uid: 'u1',
            ),
            child: const Text('Open goal'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Open goal'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('goal-preview-log-input')), '5');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Log today'));
    await tester.tap(find.widgetWithText(FilledButton, 'Log today'));
    await tester.pumpAndSettle();

    final data =
        (await firestore.collection('goals').doc(goalId).get()).data()!;
    expect((data['currentValue'] as num).toDouble(), 25);
  });

  testWidgets('editing the current value closes cleanly after saving',
      (tester) async {
    final firestore = FakeFirebaseFirestore();
    final service = GoalsService(firestore);
    await firestore.collection('users').doc('u1').set({'companyId': 'A12'});
    final goalId = await service.createGoal(
      uid: 'u1',
      category: GoalCategory.professional,
      title: 'Build a habit',
      targetDate: DateTime(2026, 12, 15),
      targetValue: 34,
      currentValue: 20,
      unit: 'KM',
    );
    final goal = (await service.watchGoals('u1').first)
        .singleWhere((item) => item.id == goalId);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: GoalDetailSheet(
          initialGoal: goal,
          service: service,
          uid: 'u1',
          onViewGoalPage: () async {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('You are at 20 KM — tap to change'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '25');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Change current value'), findsNothing);
    final data =
        (await firestore.collection('goals').doc(goalId).get()).data()!;
    expect((data['currentValue'] as num).toDouble(), 25);
  });
}
