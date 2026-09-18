import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:selfcare_projects/src/features/authentication/screen/dashboard/abundance_dashboard_section.dart';

void main() {
  test('home achievement shelf contains only unlocked achievements', () {
    final visible = unlockedAchievementsForDashboard([
      const AbundanceDashboardAchievement(
        title: 'First goal',
        subtitle: 'A goal is on the board.',
        icon: Icons.flag,
        unlocked: true,
      ),
      const AbundanceDashboardAchievement(
        title: 'Balanced',
        subtitle: 'All three life areas are covered.',
        icon: Icons.balance,
        unlocked: false,
      ),
    ]);

    expect(visible.map((achievement) => achievement.title), ['First goal']);
  });
}
