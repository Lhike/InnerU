import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/domain/abundance_navigation.dart';

void main() {
  test('member navigation contains the reference destinations in order', () {
    expect(
      abundanceNavigationFor(isCoach: false).map((item) => item.key),
      [
        'home',
        'missions',
        'quests',
        'achievements',
        'guild',
        'profile',
        'notifications',
        'more',
      ],
    );
  });

  test('five destinations remain in the accessible bottom bar', () {
    expect(
      abundanceNavigationFor(isCoach: false)
          .where((item) => item.kind == AbundanceDestinationKind.tab)
          .map((item) => item.key),
      ['home', 'missions', 'quests', 'achievements', 'more'],
    );
  });

  test('coach navigation adds tools without removing member pages', () {
    final items = abundanceNavigationFor(isCoach: true);
    expect(items.any((item) => item.key == 'coach_students'), isTrue);
    expect(items.any((item) => item.key == 'coach_core_tasks'), isTrue);
    expect(items.any((item) => item.key == 'home'), isTrue);
  });

  test('ordinary members never receive coach destinations', () {
    expect(
      abundanceNavigationFor(isCoach: false).any((item) => item.coachOnly),
      isFalse,
    );
  });
}
