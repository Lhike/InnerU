import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_onboarding_screen.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_button.dart';

void main() {
  testWidgets('onboarding mirrors the source welcome and quest controls',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AbundanceOnboardingScreen(uid: 'u1', initialName: 'cookie milo'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ABUNDANCE 12'), findsOneWidget);
    expect(find.text('THE GAME OF MY LIFE'), findsOneWidget);
    expect(find.text('Step 1 of 4'), findsOneWidget);
    expect(find.text('Welcome, cookie milo.'), findsOneWidget);
    expect(find.text('Begin'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    await tester.ensureVisible(find.text('Begin'));
    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 4'), findsOneWidget);
    expect(find.text('QUEST 1 OF 3'), findsOneWidget);
    expect(find.text('Start with AI declaration suggestions'), findsOneWidget);
    expect(find.text('✣ Get 5 AI suggestions'), findsOneWidget);
    expect(find.text('Choose a date'), findsOneWidget);
    expect(find.text('Only use whole numbers'), findsOneWidget);
    expect(find.text('Action plans'), findsOneWidget);
    expect(find.text('+ Add plan'), findsOneWidget);

    final measure = tester.widget<TextField>(find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Type or choose a measure',
    ));
    expect(measure.readOnly, isTrue);
  });

  testWidgets('long final action label fits a narrow footer cell',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 112,
              child: AbundanceButton(
                label: 'Enter Abundance 12',
                onPressed: null,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    } finally {
      FlutterError.onError = previousOnError;
    }

    expect(
      errors.where((error) => error.exceptionAsString().contains('overflowed')),
      isEmpty,
    );
  });

  testWidgets('dragging the AI suggestions sheet closed does not assert',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home:
              AbundanceOnboardingScreen(uid: 'u1', initialName: 'cookie milo'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Begin'));
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('✣ Get 5 AI suggestions'));
      await tester.tap(find.text('✣ Get 5 AI suggestions'));
      await tester.pumpAndSettle();

      expect(find.text('Create declaration suggestions'), findsOneWidget);
      await tester.dragFrom(const Offset(200, 300), const Offset(0, 500));
      await tester.pumpAndSettle();
    } finally {
      FlutterError.onError = previousOnError;
    }

    expect(
      errors.where(
          (error) => error.exceptionAsString().contains('_dependents.isEmpty')),
      isEmpty,
    );
  });
}
