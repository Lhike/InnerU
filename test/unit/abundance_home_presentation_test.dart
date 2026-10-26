import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/screens/mentee/abundance_home_presentation.dart';

void main() {
  test('exposes the six reference daily mission cards in order', () {
    expect(
      abundanceHomeMissionCatalog.map((mission) => mission.key),
      ['call', 'steps', 'exercise', 'meditation', 'learning', 'addValue'],
    );
    expect(
      abundanceHomeMissionCatalog.map((mission) => mission.title),
      ['Call', 'Steps', 'Exercise', 'Meditation', 'Learning', 'Add value'],
    );
  });

  test('maps the reference mission key to the tracker payload field', () {
    expect(abundanceHomeMissionByKey('addValue')?.payloadField, 'add_value');
    expect(abundanceHomeMissionByKey('steps')?.payloadField, 'steps');
    expect(abundanceHomeMissionByKey('unknown'), isNull);
  });

  test('derives the reference header initials from the display name', () {
    expect(abundanceHeaderInitials('Arlene Dacanay'), 'AD');
    expect(abundanceHeaderInitials('Arlene'), 'A');
    expect(abundanceHeaderInitials(''), 'AM');
  });
}
