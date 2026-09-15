import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_achievements_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_character_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_missions_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_more_sheet.dart';

void main() {
  testWidgets('missions page delegates to existing tracking flows',
      (tester) async {
    var dailyOpened = false;
    var planOpened = false;
    await tester.pumpWidget(MaterialApp(
      home: AbundanceMissionsScreen(
        onOpenDailyMission: () => dailyOpened = true,
        onOpenMissionPlan: () => planOpened = true,
      ),
    ));

    expect(find.text('EVERYDAY MISSIONS'), findsOneWidget);
    await tester.tap(find.text('Open daily mission'));
    await tester.ensureVisible(find.text('Manage mission plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manage mission plan'));
    expect(dailyOpened, isTrue);
    expect(planOpened, isTrue);
  });

  testWidgets('achievements distinguish earned and locked awards',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AbundanceAchievementsScreen(unlockedKeys: {'first-flame'}),
    ));

    expect(find.text('ACHIEVEMENTS'), findsOneWidget);
    expect(find.text('EARNED'), findsOneWidget);
    expect(find.text('LOCKED'), findsOneWidget);
    expect(find.text('First Flame'), findsOneWidget);
  });

  testWidgets('More shows coach tools only for coaches', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AbundanceMoreSheet(
          isCoach: false,
          onDestination: (_) {},
        ),
      ),
    ));
    expect(find.text('Students'), findsNothing);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AbundanceMoreSheet(
          isCoach: true,
          onDestination: (_) {},
        ),
      ),
    ));
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Core Tasks'), findsOneWidget);
  });

  testWidgets('Character selection persists through the provided repository',
      (tester) async {
    var selected = 'warrior';
    await tester.pumpWidget(MaterialApp(
      home: AbundanceCharacterScreen(
        uid: 'member-1',
        loadCharacter: (_) async => selected,
        saveCharacter: (_, value) async => selected = value,
        onOpenAccountSettings: () {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('YOUR CHARACTER'), findsOneWidget);
    await tester.drag(find.byType(GridView), const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('character-mage')));
    await tester.pumpAndSettle();
    expect(selected, 'mage');
  });
}
