import 'package:flutter_test/flutter_test.dart';

import 'package:selfcare_projects/src/features/abundance/coach/coach_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the source coach catalog with its source ordering', () async {
    final coaches = await AbundanceCoachCatalog.load();

    expect(coaches, hasLength(25));
    expect(coaches.first.name, 'Charlie Gengos');
    expect(coaches[1].name, 'Migs Flores');
    expect(coaches[2].name, 'Russ Juson');
    expect(coaches[3].name, 'Gina Katigbak');
    expect(coaches.any((coach) => coach.name == 'Aryanne Gengos'), isTrue);
    expect(coaches.first.assetPath,
        'assets/images/abundance/coaches/level1-a-charlie.jpg');
  });

  test('retains source declarations and background details', () async {
    final coaches = await AbundanceCoachCatalog.load();
    final charlie =
        coaches.firstWhere((coach) => coach.name == 'Charlie Gengos');

    expect(charlie.declaration, 'I play the Game of Life, Abundantly');
    expect(charlie.background, contains('Chairman of GENCYS'));
  });

  test('provides a deterministic fallback asset for invalid artwork', () {
    expect(AbundanceCoachCatalog.fallbackAsset, 'assets/images/coachpic.png');
  });
}
