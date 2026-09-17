import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/domain/domain.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_onboarding_service.dart';

void main() {
  test('draft validation mirrors the source onboarding rules', () {
    const merit = AbundanceOnboardingGoalDraft(
      category: GoalCategory.personal,
      declaration: 'I see myself stronger',
      direction: GoalDirection.gain,
      unit: 'KM',
      target: 0,
      increment: true,
      plans: <String>[],
      qualities: 'Discipline',
    );
    expect(merit.isValid, isFalse);

    const milestone = AbundanceOnboardingGoalDraft(
      category: GoalCategory.personal,
      declaration: 'I see myself stronger',
      direction: GoalDirection.gain,
      unit: 'MILESTONE',
      target: 0,
      increment: true,
      plans: <String>['Book an induction'],
      qualities: 'Discipline',
    );
    expect(milestone.isValid, isTrue);
  });
}
