import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/screens/abundance_post_auth_gate.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_onboarding_service.dart';
import 'package:selfcare_projects/src/services/company_theme_service.dart';

class _IncompleteOnboardingService extends AbundanceOnboardingService {
  _IncompleteOnboardingService() : super(updateUser: (_) async {});

  @override
  Future<bool> isComplete(String uid) async => false;

  @override
  Future<void> complete({
    required String uid,
    required String name,
    required String headline,
    required List<AbundanceOnboardingGoalDraft> goals,
  }) async {}
}

void main() {
  testWidgets(
      'completing onboarding through the gate does not return a Future from setState',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: AbundancePostAuthGate(
            uid: 'u1',
            initialName: 'cookie milo',
            companyTheme: CompanyThemeData.standard.copyWith(
              companyName: 'Abundance Company',
              companyCode: 'ABU15DN',
              isCompanyTheme: true,
            ),
            isCoach: false,
            service: _IncompleteOnboardingService(),
            child: const Text('InnerU home'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Begin'));
      await tester.tap(find.text('Begin'));
      await tester.pumpAndSettle();

      for (var index = 0; index < 3; index++) {
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.hintText == 'I see myself…',
          ),
          'I see myself making steady progress.',
        );
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField && widget.decoration?.hintText == '15',
          ),
          '1',
        );
        await tester.enterText(
          find.byWidgetPredicate(
            (widget) =>
                widget is TextField &&
                widget.decoration?.hintText ==
                    'Love, Compassion, Integrity, Excellence, Awareness',
          ),
          'Integrity',
        );

        final action = index == 2
            ? find.text('Enter Abundance 12')
            : find.text('Continue');
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
      }

      expect(find.text('InnerU home'), findsOneWidget);
    } finally {
      FlutterError.onError = previousOnError;
    }

    expect(
      errors.where((error) => error
          .exceptionAsString()
          .contains('callback argument returned a Future')),
      isEmpty,
    );
  });
}
