import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_steps.dart';

void main() {
  test('member catalog starts with welcome and keeps reference route order',
      () {
    final steps = abundanceTutorialStepsFor(
      const <AbundanceTutorialRole>{AbundanceTutorialRole.member},
    );

    expect(steps.first.title, 'Let’s look around');
    expect(steps.first.target, isNull);
    expect(
      steps.where((step) => step.target != null).map((step) => step.target),
      <String?>[
        'home-overview',
        'home-missions',
        'home-goal',
        'quests-overview',
        'quests-life-power',
        'quests-categories',
        'quests-list',
        'daily-overview',
        'daily-board',
        'daily-board',
        'allies-overview',
        'allies-controls',
        'allies-board',
        'allies-rank',
        'achievements-overview',
        'achievements-tally',
        'achievements-wall',
        'profile-character',
        'profile-stats',
        'profile-council',
        'profile-settings',
      ],
    );
    expect(steps.map((step) => step.route).toSet(), contains('/profile'));
    expect(steps.map((step) => step.title),
        isNot(contains('Review your council')));
  });

  test('coach catalog includes coaching steps and shared profile steps', () {
    final steps = abundanceTutorialStepsFor(
      const <AbundanceTutorialRole>{AbundanceTutorialRole.coach},
    );

    expect(
        steps.map((step) => step.title),
        containsAllInOrder(<String>[
          'Review your council',
          'Follow student progress',
          'See what you earned',
          'See your player card',
        ]));
    expect(steps.where((step) => step.target?.startsWith('coach-') ?? false),
        hasLength(2));
  });

  test('empty roles use the member catalog and returned list is immutable', () {
    final steps = abundanceTutorialStepsFor(const <AbundanceTutorialRole>{});

    expect(steps.length, 22);
    expect(
      () => steps.add(
        const AbundanceTutorialStep(
          eyebrow: 'Extra',
          title: 'Extra',
          description: 'Extra',
        ),
      ),
      throwsUnsupportedError,
    );
  });
}
