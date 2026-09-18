import 'package:selfcare_projects/src/features/abundance/domain/domain.dart'
    as abundance;
import 'package:selfcare_projects/src/features/abundance/domain/day_keys.dart';
import 'package:selfcare_projects/src/features/abundance/domain/scoring.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_missions_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/services/daily_check_in_api_service.dart';
import 'package:selfcare_projects/src/features/authentication/screen/todo_list.dart'
    as todo;

class AbundanceAchievementDefinition {
  const AbundanceAchievementDefinition({
    required this.key,
    required this.name,
    required this.description,
    required this.tier,
    required this.assetKey,
    required this.metric,
    required this.target,
  });

  final String key;
  final String name;
  final String description;
  final String tier;
  final String assetKey;
  final String metric;
  final int target;
}

class AbundanceAchievementRecord {
  const AbundanceAchievementRecord({
    required this.definition,
    required this.current,
    required this.unlocked,
  });

  final AbundanceAchievementDefinition definition;
  final num current;
  final bool unlocked;

  int get percent {
    if (unlocked) return 100;
    if (!current.isFinite || definition.target <= 0) return 0;
    return ((current / definition.target) * 100).round().clamp(0, 100);
  }
}

const List<AbundanceAchievementDefinition> abundanceAchievementDefinitions =
    <AbundanceAchievementDefinition>[
  AbundanceAchievementDefinition(
    key: 'STREAK_7',
    name: 'First Flame',
    description:
        'For 7 days, showed up and had a Personal, Professional, and Contribution goal.',
    tier: 'BRONZE',
    assetKey: 'first-flame',
    metric: 'everydayMissionStreak',
    target: 7,
  ),
  AbundanceAchievementDefinition(
    key: 'STREAK_30',
    name: 'Thirty Days Strong',
    description: 'Kept a 30-day streak. A full month without a gap.',
    tier: 'SILVER',
    assetKey: '30-days-strong',
    metric: 'streak',
    target: 30,
  ),
  AbundanceAchievementDefinition(
    key: 'STREAK_50',
    name: 'Unbroken',
    description: 'Finished every Everyday Mission for 60 days without a skip.',
    tier: 'PLATINUM',
    assetKey: 'unbroken',
    metric: 'everydayMissionStreak',
    target: 60,
  ),
  AbundanceAchievementDefinition(
    key: 'PERSONAL_GOAL_DONE',
    name: 'Tended Ground',
    description:
        'Completed a personal quest. The life you live when nobody is watching.',
    tier: 'BRONZE',
    assetKey: 'tended-ground',
    metric: 'personalGoalsCompleted',
    target: 1,
  ),
  AbundanceAchievementDefinition(
    key: 'PROFESSIONAL_GOAL_DONE',
    name: 'Forged Craft',
    description:
        'Completed a professional quest. The work you put your name to.',
    tier: 'BRONZE',
    assetKey: 'forged-craft',
    metric: 'professionalGoalsCompleted',
    target: 1,
  ),
  AbundanceAchievementDefinition(
    key: 'CONTRIBUTION_GOAL_DONE',
    name: 'Given Freely',
    description:
        'Completed a contribution quest. What you left behind for someone else.',
    tier: 'BRONZE',
    assetKey: 'given-freely',
    metric: 'contributionGoalsCompleted',
    target: 1,
  ),
  AbundanceAchievementDefinition(
    key: 'GOALS_COMPLETED_1',
    name: 'First Finish',
    description: 'Finished your first goal.',
    tier: 'BRONZE',
    assetKey: 'finished-first',
    metric: 'goalsCompleted',
    target: 1,
  ),
  AbundanceAchievementDefinition(
    key: 'GOALS_COMPLETED_5',
    name: 'Closer',
    description: 'Finished 2 goals.',
    tier: 'SILVER',
    assetKey: 'closer',
    metric: 'goalsCompleted',
    target: 2,
  ),
  AbundanceAchievementDefinition(
    key: 'GOALS_COMPLETED_10',
    name: 'Quest Architect',
    description: 'Finished 3 goals.',
    tier: 'GOLD',
    assetKey: 'quest-architect',
    metric: 'goalsCompleted',
    target: 3,
  ),
  AbundanceAchievementDefinition(
    key: 'OVERALL_SCORE_60',
    name: 'Finding Rhythm',
    description: 'Finished every Everyday Mission for 30 days without a skip.',
    tier: 'BRONZE',
    assetKey: 'finding-rythm',
    metric: 'everydayMissionStreak',
    target: 30,
  ),
  AbundanceAchievementDefinition(
    key: 'OVERALL_SCORE_80',
    name: 'High Performer',
    description:
        'Finished every Everyday Mission over the last 30 days. No skips.',
    tier: 'GOLD',
    assetKey: 'high-performer',
    metric: 'taskCompletionRate',
    target: 100,
  ),
  AbundanceAchievementDefinition(
    key: 'OVERALL_SCORE_90',
    name: 'Abundance Elite',
    description:
        'Reached a Life Power of 90, finished 3 goals, and did not skip an Everyday Mission over the last 90 days.',
    tier: 'PLATINUM',
    assetKey: 'abundance-elite',
    metric: 'overallScore',
    target: 90,
  ),
  AbundanceAchievementDefinition(
    key: 'TASK_RATE_80',
    name: 'Disciplined',
    description: 'Finished every Everyday Mission for 50 days without a skip.',
    tier: 'SILVER',
    assetKey: 'discipline',
    metric: 'everydayMissionStreak',
    target: 50,
  ),
  AbundanceAchievementDefinition(
    key: 'TASK_RATE_95',
    name: 'Immovable',
    description: 'Finished every Everyday Mission for 20 days without a skip.',
    tier: 'GOLD',
    assetKey: 'immovable',
    metric: 'everydayMissionStreak',
    target: 20,
  ),
  AbundanceAchievementDefinition(
    key: 'CHECK_IN_RATE_80',
    name: 'Examined Life',
    description: 'Reflected on at least 80% of days.',
    tier: 'SILVER',
    assetKey: 'examine-life',
    metric: 'checkInRate',
    target: 80,
  ),
];

abstract interface class AbundanceAchievementsGateway {
  Future<List<AbundanceAchievementRecord>> load();
}

abstract interface class AbundanceCheckInsGateway {
  Future<List<DateTime>> load();
}

class InnerUAbundanceCheckInsGateway implements AbundanceCheckInsGateway {
  InnerUAbundanceCheckInsGateway({DailyCheckInApiService? api})
      : api = api ?? DailyCheckInApiService.instance;

  final DailyCheckInApiService api;

  @override
  Future<List<DateTime>> load() async {
    try {
      final history = await api.fetchHistory();
      return history
          .map((entry) => entry['date'] ?? entry['checkInDate'] ?? entry['day'])
          .map((value) => DateTime.tryParse(value?.toString() ?? ''))
          .whereType<DateTime>()
          .toList(growable: false);
    } catch (_) {
      return const <DateTime>[];
    }
  }
}

List<AbundanceAchievementRecord> computeAbundanceAchievementRecords({
  required List<todo.Task> tasks,
  required List<GoalSummary> quests,
  List<DateTime> checkInDays = const <DateTime>[],
  num? lifePower,
  DateTime? asOf,
}) {
  final end = _day(asOf ?? DateTime.now());
  final everydayTasks = tasks
      .where((task) => task.goalType == todo.GoalType.everyday)
      .toList(growable: false);
  final completionDays =
      everydayTasks.expand((task) => task.completionDates).map(_day).toSet();
  final completedMissions = everydayTasks
      .where((task) => task.isCompleted || task.completionDates.isNotEmpty)
      .length;
  final completedQuests = quests
      .where((quest) => quest.status == abundance.GoalStatus.completed)
      .length;
  final longestStreak = _longestConsecutiveRun(completionDays);
  final windowStart = addDays(end, -29);
  final completedDaysInWindow = completionDays
      .where((day) => !day.isBefore(windowStart) && !day.isAfter(end))
      .length;
  final missionRate = completedDaysInWindow / 30 * 100;
  final checkInRate = checkInDays
          .map(_day)
          .toSet()
          .where((day) => !day.isBefore(windowStart) && !day.isAfter(end))
          .length /
      30 *
      100;
  final categories = <abundance.GoalCategory, int>{
    for (final category in abundance.GoalCategory.values)
      category: quests
          .where((quest) =>
              quest.category == category &&
              quest.status == abundance.GoalStatus.completed)
          .length,
  };
  final metrics = <String, num>{
    'everydayMissionStreak': longestStreak,
    'streak': longestStreak,
    'personalGoalsCompleted': categories[abundance.GoalCategory.personal]!,
    'professionalGoalsCompleted':
        categories[abundance.GoalCategory.professional]!,
    'contributionGoalsCompleted':
        categories[abundance.GoalCategory.contribution]!,
    'goalsCompleted': completedQuests,
    'taskCompletionRate': missionRate,
    'overallScore': lifePower ?? _lifePower(quests),
    'checkInRate': checkInRate,
  };
  return abundanceAchievementDefinitions.map((definition) {
    final current = definition.key == 'STREAK_7'
        ? completedMissions
        : metrics[definition.metric] ?? 0;
    return AbundanceAchievementRecord(
      definition: definition,
      current: current,
      unlocked: definition.key == 'STREAK_7'
          ? completedMissions > 0
          : current >= definition.target,
    );
  }).toList(growable: false);
}

Set<String> computeAbundanceAchievementKeys({
  required List<todo.Task> tasks,
  required List<GoalSummary> quests,
}) {
  return computeAbundanceAchievementRecords(tasks: tasks, quests: quests)
      .where((record) => record.unlocked)
      .map((record) => record.definition.assetKey)
      .toSet();
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

num _lifePower(List<GoalSummary> quests) {
  final goals = quests
      .map((quest) => ScorableGoal(
            status: quest.status,
            progress: quest.progress,
            category: quest.category,
            goalType: quest.goalType,
            targetValue: quest.targetValue,
            currentValue: quest.currentValue,
          ))
      .toList(growable: false);
  return weightGoalScore(scoreCategories(goals));
}

int _longestConsecutiveRun(Set<DateTime> days) {
  if (days.isEmpty) return 0;
  final sorted = days.toList()..sort();
  var longest = 1;
  var current = 1;
  for (var index = 1; index < sorted.length; index++) {
    if (sorted[index].difference(sorted[index - 1]).inDays == 1) {
      current++;
      if (current > longest) longest = current;
    } else {
      current = 1;
    }
  }
  return longest;
}

class InnerUAbundanceAchievementsGateway
    implements AbundanceAchievementsGateway {
  InnerUAbundanceAchievementsGateway({
    required this.uid,
    required this.goals,
    AbundanceMissionsGateway? missions,
    AbundanceCheckInsGateway? checkIns,
  })  : missions = missions ?? InnerUAbundanceMissionsGateway(),
        checkIns = checkIns ?? InnerUAbundanceCheckInsGateway();

  final String uid;
  final GoalsService goals;
  final AbundanceMissionsGateway missions;
  final AbundanceCheckInsGateway checkIns;

  @override
  Future<List<AbundanceAchievementRecord>> load() async {
    final values = await Future.wait<Object>([
      missions.load(),
      goals.watchGoals(uid).first,
      checkIns.load(),
    ]);
    final tasks = values[0] as List<todo.Task>;
    final quests = values[1] as List<GoalSummary>;
    final records = computeAbundanceAchievementRecords(
      tasks: tasks,
      quests: quests,
      checkInDays: values[2] as List<DateTime>,
    );
    return records;
  }
}
