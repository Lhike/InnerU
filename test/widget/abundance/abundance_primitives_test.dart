import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_button.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_status_view.dart';

void main() {
  test('typography uses namespaced Abundance font families', () {
    expect(AbundanceTypography.displayFamily, 'AbundanceCinzel');
    expect(AbundanceTypography.bodyFamily, 'AbundanceInter');
  });

  testWidgets('button and card expose content and button semantics',
      (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AbundanceCard(
          child: AbundanceButton(
            label: 'Continue quest',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    ));

    expect(find.bySemanticsLabel('Continue quest'), findsOneWidget);
    await tester.tap(find.text('Continue quest'));
    expect(pressed, isTrue);
  });

  testWidgets('status error exposes its retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      home: AbundanceStatusView.error(
        message: 'Could not load.',
        onRetry: () => retried = true,
      ),
    ));

    expect(find.text('Could not load.'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });
}
