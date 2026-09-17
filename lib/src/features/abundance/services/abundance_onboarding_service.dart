import 'package:shared_preferences/shared_preferences.dart';

import 'package:selfcare_projects/src/features/abundance/domain/domain.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/authentication/screen/UsersData/user_service.dart';

class AbundanceOnboardingGoalDraft {
  const AbundanceOnboardingGoalDraft({
    required this.category,
    required this.declaration,
    required this.direction,
    required this.unit,
    required this.target,
    required this.increment,
    required this.plans,
    required this.qualities,
    this.targetDate,
  });

  final GoalCategory category;
  final String declaration;
  final GoalDirection direction;
  final String unit;
  final double target;
  final bool increment;
  final List<String> plans;
  final String qualities;
  final DateTime? targetDate;

  bool get isMilestone => unit.trim().toUpperCase() == 'MILESTONE';

  bool get isValid {
    if (declaration.trim().length < 3 || qualities.trim().isEmpty) return false;
    if (isMilestone) {
      return plans.any((plan) => plan.trim().isNotEmpty);
    }
    return target > 0;
  }
}

typedef AbundanceUserUpdater = Future<void> Function(
    Map<String, dynamic> fields);

class AbundanceOnboardingService {
  AbundanceOnboardingService({
    GoalsService? goals,
    AbundanceUserUpdater? updateUser,
  })  : _goals = goals ?? GoalsService(),
        _updateUser = updateUser ?? _defaultUpdateUser;

  final GoalsService _goals;
  final AbundanceUserUpdater _updateUser;

  static String completionKey(String uid) => 'abundance_onboarding_done_$uid';

  Future<bool> isComplete(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(completionKey(uid)) ?? false) return true;
    try {
      final goals = await _goals.watchGoals(uid).first.timeout(
            const Duration(seconds: 8),
          );
      final categories = goals
          .where((goal) => goal.status != GoalStatus.abandoned)
          .map((goal) => goal.category)
          .toSet();
      final complete = GoalCategory.values.every(categories.contains);
      if (complete) {
        await prefs.setBool(completionKey(uid), true);
      }
      return complete;
    } catch (_) {
      // A network outage must not lock an existing member out of the app.
      return true;
    }
  }

  Future<void> complete({
    required String uid,
    required String name,
    required String headline,
    required List<AbundanceOnboardingGoalDraft> goals,
  }) async {
    if (goals.length != GoalCategory.values.length ||
        goals.any((goal) => !goal.isValid)) {
      throw ArgumentError('Complete all three Abundance quests first.');
    }

    await _updateUser(<String, dynamic>{
      'name': name.trim(),
      'bio': headline.trim().isEmpty ? null : headline.trim(),
    });

    final existing = await _goals.watchGoals(uid).first;
    final existingCategories = existing
        .where((goal) => goal.status != GoalStatus.abandoned)
        .map((goal) => goal.category)
        .toSet();
    for (final draft in goals) {
      if (existingCategories.contains(draft.category)) continue;
      final targetDate =
          draft.targetDate ?? DateTime.now().add(const Duration(days: 90));
      await _goals.createGoal(
        uid: uid,
        category: draft.category,
        title: draft.declaration.trim(),
        description: draft.declaration.trim(),
        notes: draft.qualities.trim(),
        targetDate: targetDate,
        goalType: draft.isMilestone ? GoalType.milestone : GoalType.merit,
        direction: draft.direction,
        targetValue: draft.isMilestone ? 0 : draft.target,
        unit: draft.isMilestone ? 'MILESTONE' : draft.unit.trim(),
        targetPeriod: TargetPeriod.none,
        planTitles: draft.plans
            .map((plan) => plan.trim())
            .where((plan) => plan.isNotEmpty)
            .toList(growable: false),
      );
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(completionKey(uid), true);
  }

  static Future<void> _defaultUpdateUser(Map<String, dynamic> fields) async {
    await UserService.updateUserFields(fields);
  }
}
