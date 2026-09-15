import 'package:selfcare_projects/src/features/abundance/domain/domain.dart'
    as abundance;
import 'package:selfcare_projects/src/features/abundance/services/abundance_missions_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/authentication/screen/todo_list.dart'
    as todo;

abstract interface class AbundanceAchievementsGateway {
  Future<Set<String>> load();
}

class InnerUAbundanceAchievementsGateway
    implements AbundanceAchievementsGateway {
  InnerUAbundanceAchievementsGateway({
    required this.uid,
    required this.goals,
    AbundanceMissionsGateway? missions,
  }) : missions = missions ?? InnerUAbundanceMissionsGateway();

  final String uid;
  final GoalsService goals;
  final AbundanceMissionsGateway missions;

  @override
  Future<Set<String>> load() async {
    final values = await Future.wait<Object>([
      missions.load(),
      goals.watchGoals(uid).first,
    ]);
    final tasks = values[0] as List<todo.Task>;
    final quests = values[1] as List<GoalSummary>;
    final everydayTasks = tasks
        .where((task) => task.goalType == todo.GoalType.everyday)
        .toList(growable: false);
    final completionDays = everydayTasks
        .expand((task) => task.completionDates)
        .map((date) => DateTime(date.year, date.month, date.day))
        .toSet();
    final completedMissions = everydayTasks
        .where((task) => task.isCompleted || task.completionDates.isNotEmpty);
    final completedQuests = quests
        .where((quest) => quest.status == abundance.GoalStatus.completed)
        .length;
    final unlocked = <String>{};
    if (completedMissions.isNotEmpty) unlocked.add('first-flame');
    final longestStreak = _longestConsecutiveRun(completionDays);
    if (longestStreak >= 3) unlocked.add('finding-rythm');
    if (completionDays.length >= 30) unlocked.add('30-days-strong');
    if (longestStreak >= 14) unlocked.add('unbroken');
    if (everydayTasks.length >= 3 &&
        completedMissions.length == everydayTasks.length) {
      unlocked.add('discipline');
    }
    if (completedQuests >= 1) unlocked.add('finished-first');
    if (completedQuests >= 3) unlocked.add('closer');
    if (quests.any((quest) => quest.goalType == abundance.GoalType.milestone)) {
      unlocked.add('quest-architect');
    }
    if (quests.any((quest) => quest.progress >= 80)) {
      unlocked.add('high-performer');
    }
    if (completedQuests >= 10 && completionDays.length >= 30) {
      unlocked.add('abundance-elite');
    }
    return unlocked;
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
}
