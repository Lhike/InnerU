import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/domain/abundance_navigation.dart';

void main() {
  test('member navigation contains no Coach-only More destination', () {
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
      ],
    );
  });

  test('members keep the six primary destinations without More', () {
    expect(
      abundanceNavigationFor(isCoach: false)
          .where((item) => item.kind == AbundanceDestinationKind.tab)
          .map((item) => item.key),
      ['home', 'missions', 'quests', 'achievements'],
    );
  });

  test('Coach navigation adds a More destination and Coach tools', () {
    final items = abundanceNavigationFor(isCoach: true);
    expect(items.any((item) => item.key == 'more'), isTrue);
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
