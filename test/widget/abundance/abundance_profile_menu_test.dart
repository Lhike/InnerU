import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_profile_menu.dart';

void main() {
  testWidgets('opens the A12 profile dropdown and dispatches profile action',
      (tester) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AbundanceProfileMenuButton(
            displayName: 'Yina Mae',
            email: 'yina@example.com',
            onProfile: () => selected = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(AbundanceProfileMenuButton));
    await tester.pumpAndSettle();
    expect(find.text('Profile & settings'), findsOneWidget);
    expect(find.text('Yina Mae'), findsOneWidget);
    expect(find.text('yina@example.com'), findsOneWidget);

    await tester.ensureVisible(find.text('Profile & settings'));
    await tester.tap(find.text('Profile & settings'));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(find.text('Profile & settings'), findsNothing);
  });
}
