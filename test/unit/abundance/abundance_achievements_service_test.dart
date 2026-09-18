import 'package:flutter_test/flutter_test.dart';

import 'package:selfcare_projects/src/features/abundance/domain/domain.dart'
    as abundance;
import 'package:selfcare_projects/src/features/abundance/services/abundance_achievements_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_missions_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/authentication/screen/todo_list.dart';

class _FakeMissionsGateway implements AbundanceMissionsGateway {
  _FakeMissionsGateway(this.tasks);

  final List<Task> tasks;

  @override
  Future<List<Task>> load() async => tasks;

  @override
  Future<void> create(Task task) async {}

  @override
  Future<void> update(Task task) async {}

  @override
  Future<void> delete(String id) async {}
}

class _FakeGoalsService extends GoalsService {
  _FakeGoalsService() : super(null);

  @override
  Stream<List<GoalSummary>> watchGoals(String uid) =>
      Stream<List<GoalSummary>>.value(const <GoalSummary>[]);
}

GoalSummary _goal({
  required abundance.GoalCategory category,
  abundance.GoalStatus status = abundance.GoalStatus.completed,
}) {
  return GoalSummary(
    id: category.code,
    userId: 'member-1',
    companyId: 'company-1',
    title: category.label,
    description: null,
    notes: null,
    status: status,
    progress: status == abundance.GoalStatus.completed ? 100 : 40,
    category: category,
    goalType: abundance.GoalType.merit,
    targetPeriod: abundance.TargetPeriod.none,
    direction: abundance.GoalDirection.gain,
    targetValue: 100,
    currentValue: status == abundance.GoalStatus.completed ? 100 : 40,
    unit: '%',
    startDate: DateTime(2026, 1, 1),
    targetDate: DateTime(2026, 12, 31),
    completedAt:
        status == abundance.GoalStatus.completed ? DateTime(2026, 9, 1) : null,
  );
}

Task _mission(DateTime day, {bool completed = true}) => Task(
      id: day.toIso8601String(),
      title: 'Mission',
      goalType: GoalType.everyday,
      startDate: day,
      dueDate: day,
      isCompleted: completed,
      completionDates: completed ? <DateTime>[day] : const <DateTime>[],
    );

void main() {
  test('catalog contains the canonical Expo achievement keys', () {
    expect(
      abundanceAchievementDefinitions.map((definition) => definition.key),
      <String>[
        'STREAK_7',
        'STREAK_30',
        'STREAK_50',
        'PERSONAL_GOAL_DONE',
        'PROFESSIONAL_GOAL_DONE',
        'CONTRIBUTION_GOAL_DONE',
        'GOALS_COMPLETED_1',
        'GOALS_COMPLETED_5',
        'GOALS_COMPLETED_10',
        'OVERALL_SCORE_60',
        'OVERALL_SCORE_80',
        'OVERALL_SCORE_90',
        'TASK_RATE_80',
        'TASK_RATE_95',
        'CHECK_IN_RATE_80',
      ],
    );
  });

  test('every catalog entry has artwork and a positive target', () {
    for (final definition in abundanceAchievementDefinitions) {
      expect(abundanceAchievementAssets[definition.assetKey], isNotNull);
      expect(definition.target, greaterThan(0));
    }
  });

  test('record percent is complete when unlocked', () {
    final definition = abundanceAchievementDefinitions.first;

    expect(
      AbundanceAchievementRecord(
        definition: definition,
        current: 0,
        unlocked: true,
      ).percent,
      100,
    );
  });

  test('record percent calculates rounded current-to-target progress', () {
    final definition = abundanceAchievementDefinitions.first;

    expect(
      AbundanceAchievementRecord(
        definition: definition,
        current: 3.5,
        unlocked: false,
      ).percent,
      50,
    );
  });

  test('record percent clamps locked progress to zero through one hundred', () {
    final definition = abundanceAchievementDefinitions.first;

    expect(
      AbundanceAchievementRecord(
        definition: definition,
        current: -1,
        unlocked: false,
      ).percent,
      0,
    );
    expect(
      AbundanceAchievementRecord(
        definition: definition,
        current: definition.target * 2,
        unlocked: false,
      ).percent,
      100,
    );
  });

  test('record percent is zero for invalid target or current values', () {
    const definition = AbundanceAchievementDefinition(
      key: 'INVALID',
      name: 'Invalid',
      description: 'Invalid',
      tier: 'BRONZE',
      assetKey: 'first-flame',
      metric: 'invalid',
      target: 0,
    );

    expect(
      const AbundanceAchievementRecord(
        definition: definition,
        current: 1,
        unlocked: false,
      ).percent,
      0,
    );
    expect(
      AbundanceAchievementRecord(
        definition: abundanceAchievementDefinitions.first,
        current: double.nan,
        unlocked: false,
      ).percent,
      0,
    );
  });

  test('gateway unlocks First Flame for a completed first mission', () async {
    final gateway = InnerUAbundanceAchievementsGateway(
      uid: 'member-1',
      goals: _FakeGoalsService(),
      missions: _FakeMissionsGateway(<Task>[
        Task(
          id: 'mission-1',
          title: 'First mission',
          goalType: GoalType.everyday,
          startDate: DateTime(2026, 9, 1),
          dueDate: DateTime(2026, 9, 30),
          isCompleted: true,
        ),
      ]),
    );

    final records = await gateway.load();
    final firstFlame = records.firstWhere(
      (record) => record.definition.key == 'STREAK_7',
    );
    final untouched = records.firstWhere(
      (record) => record.definition.key == 'STREAK_30',
    );

    expect(firstFlame.unlocked, isTrue);
    expect(firstFlame.percent, 100);
    expect(untouched.unlocked, isFalse);
    expect(untouched.current, 0);
    expect(untouched.percent, 0);
  });

  test('evaluator reports boundary progress without unlocking later criteria',
      () {
    final asOf = DateTime(2026, 9, 20);
    final records = computeAbundanceAchievementRecords(
      tasks: <Task>[
        for (var i = 0; i < 7; i++) _mission(asOf.subtract(Duration(days: i)))
      ],
      quests: <GoalSummary>[_goal(category: abundance.GoalCategory.personal)],
      checkInDays: <DateTime>[asOf],
      asOf: asOf,
    );

    AbundanceAchievementRecord record(String key) => records.firstWhere(
          (item) => item.definition.key == key,
        );

    expect(record('STREAK_7').unlocked, isTrue);
    expect(record('STREAK_30').current, 7);
    expect(record('STREAK_30').unlocked, isFalse);
    expect(record('PERSONAL_GOAL_DONE').unlocked, isTrue);
    expect(record('PROFESSIONAL_GOAL_DONE').unlocked, isFalse);
    expect(record('GOALS_COMPLETED_1').unlocked, isTrue);
    expect(record('GOALS_COMPLETED_5').current, 1);
    expect(record('CHECK_IN_RATE_80').current, closeTo(3.33, 0.01));
  });

  test(
      'evaluator maps all streak, goal, score, mission, and check-in thresholds',
      () {
    final asOf = DateTime(2026, 9, 20);
    final records = computeAbundanceAchievementRecords(
      tasks: <Task>[
        for (var i = 0; i < 60; i++) _mission(asOf.subtract(Duration(days: i))),
      ],
      quests: <GoalSummary>[
        _goal(category: abundance.GoalCategory.personal),
        _goal(category: abundance.GoalCategory.professional),
        _goal(category: abundance.GoalCategory.contribution),
      ],
      checkInDays: <DateTime>[
        for (var i = 0; i < 24; i++) asOf.subtract(Duration(days: i))
      ],
      lifePower: 90,
      asOf: asOf,
    );

    expect(
      records
          .where((record) => record.unlocked)
          .map((record) => record.definition.key),
      containsAll(<String>[
        'STREAK_7',
        'STREAK_30',
        'STREAK_50',
        'TASK_RATE_80',
        'TASK_RATE_95',
        'PERSONAL_GOAL_DONE',
        'PROFESSIONAL_GOAL_DONE',
        'CONTRIBUTION_GOAL_DONE',
        'GOALS_COMPLETED_1',
        'GOALS_COMPLETED_5',
        'GOALS_COMPLETED_10',
        'OVERALL_SCORE_60',
        'OVERALL_SCORE_80',
        'OVERALL_SCORE_90',
        'CHECK_IN_RATE_80',
      ]),
    );
  });
}
