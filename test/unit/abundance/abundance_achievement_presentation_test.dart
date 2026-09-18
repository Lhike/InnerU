import 'package:flutter_test/flutter_test.dart';

import 'package:selfcare_projects/src/features/abundance/services/abundance_achievement_presentation.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_achievements_service.dart';

void main() {
  AbundanceAchievementRecord record(String key, num current, bool unlocked) {
    final definition = abundanceAchievementDefinitions.firstWhere(
      (item) => item.key == key,
    );
    return AbundanceAchievementRecord(
      definition: definition,
      current: current,
      unlocked: unlocked,
    );
  }

  test('catalog separates unlocked, in-progress, locked, and recent records',
      () {
    final catalog =
        AbundanceAchievementCatalog.fromRecords(<AbundanceAchievementRecord>[
      record('STREAK_7', 7, true),
      record('STREAK_30', 12, false),
      record('STREAK_50', 0, false),
    ]);

    expect(catalog.unlocked.map((item) => item.definition.key), ['STREAK_7']);
    expect(
        catalog.inProgress.map((item) => item.definition.key), ['STREAK_30']);
    expect(catalog.locked.map((item) => item.definition.key), ['STREAK_50']);
    expect(catalog.recent.map((item) => item.definition.key),
        ['STREAK_7', 'STREAK_30']);
  });

  test('catalog groups records into the seven presentation sections', () {
    final catalog = AbundanceAchievementCatalog.fromRecords(
      abundanceAchievementDefinitions
          .map((definition) => AbundanceAchievementRecord(
                definition: definition,
                current: 0,
                unlocked: false,
              ))
          .toList(),
    );

    expect(catalog.groups.keys, <String>[
      'Discipline',
      'The three realms',
      'Quests',
      'Life Power',
      'Daily Quests',
      'Reflection',
    ]);
    expect(catalog.groups['Discipline']!.map((item) => item.definition.key),
        containsAll(<String>['TASK_RATE_80', 'TASK_RATE_95']));
    expect(catalog.groups['The three realms']!.length, 3);
    expect(catalog.groups['Quests']!.length, 3);
    expect(catalog.groups['Life Power']!.length, 3);
    expect(catalog.groups['Daily Quests']!.length, 3);
    expect(catalog.groups['Reflection']!.length, 1);
    expect(catalog.groups['More'], isNull);
  });

  test('hint describes the current criterion progress', () {
    expect(
      abundanceAchievementHint(record('STREAK_30', 12, false)),
      '12/30 days',
    );
    expect(
      abundanceAchievementHint(record('OVERALL_SCORE_90', 72, false)),
      '72/90 Life Power',
    );
    expect(
      abundanceAchievementHint(record('CHECK_IN_RATE_80', 64, false)),
      '64/80% of days',
    );
  });
}
