import 'package:selfcare_projects/src/features/abundance/services/abundance_achievements_service.dart';

String abundanceAchievementHint(AbundanceAchievementRecord record) {
  final current = record.current.round();
  final target = record.definition.target;
  switch (record.definition.metric) {
    case 'everydayMissionStreak':
    case 'streak':
      return '$current/$target days';
    case 'overallScore':
      return '$current/$target Life Power';
    case 'checkInRate':
      return '$current/$target% of days';
    case 'taskCompletionRate':
      return '$current/$target% missions';
    default:
      return '$current/$target completed';
  }
}

class AbundanceAchievementCatalog {
  AbundanceAchievementCatalog._({
    required this.unlocked,
    required this.inProgress,
    required this.locked,
    required this.recent,
    required this.groups,
  });

  factory AbundanceAchievementCatalog.fromRecords(
    List<AbundanceAchievementRecord> records,
  ) {
    final unlocked = records.where((record) => record.unlocked).toList();
    final inProgress = records
        .where((record) => !record.unlocked && record.current > 0)
        .toList();
    final locked = records
        .where((record) => !record.unlocked && record.current <= 0)
        .toList();
    final grouped = <String, List<AbundanceAchievementRecord>>{};
    for (final entry in records) {
      final section = _sectionFor(entry.definition.key);
      (grouped[section] ??= <AbundanceAchievementRecord>[]).add(entry);
    }
    const sectionOrder = <String>[
      'Discipline',
      'The three realms',
      'Quests',
      'Life Power',
      'Daily Quests',
      'Reflection',
      'More',
    ];
    final groups = <String, List<AbundanceAchievementRecord>>{
      for (final section in sectionOrder)
        if (grouped[section]?.isNotEmpty == true)
          section: List<AbundanceAchievementRecord>.unmodifiable(
            grouped[section]!,
          ),
    };
    return AbundanceAchievementCatalog._(
      unlocked: List.unmodifiable(unlocked),
      inProgress: List.unmodifiable(inProgress),
      locked: List.unmodifiable(locked),
      recent: List.unmodifiable([...unlocked, ...inProgress]),
      groups: Map.unmodifiable(groups),
    );
  }

  final List<AbundanceAchievementRecord> unlocked;
  final List<AbundanceAchievementRecord> inProgress;
  final List<AbundanceAchievementRecord> locked;
  final List<AbundanceAchievementRecord> recent;
  final Map<String, List<AbundanceAchievementRecord>> groups;
}

String _sectionFor(String key) {
  if (key == 'TASK_RATE_80' || key == 'TASK_RATE_95') return 'Discipline';
  if (key == 'PERSONAL_GOAL_DONE' ||
      key == 'PROFESSIONAL_GOAL_DONE' ||
      key == 'CONTRIBUTION_GOAL_DONE') return 'The three realms';
  if (key.startsWith('GOALS_COMPLETED_')) return 'Quests';
  if (key.startsWith('OVERALL_SCORE_')) return 'Life Power';
  if (key == 'STREAK_7' || key == 'STREAK_30' || key == 'STREAK_50') {
    return 'Daily Quests';
  }
  if (key == 'CHECK_IN_RATE_80') return 'Reflection';
  return 'More';
}
