import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:selfcare_projects/src/features/abundance/screens/abundance_post_auth_gate.dart';
import 'package:selfcare_projects/src/features/abundance/screens/abundance_shell_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_onboarding_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_header_profile_button.dart';
import 'package:selfcare_projects/src/services/company_theme_service.dart';

class _IncompleteCoachOnboardingService extends AbundanceOnboardingService {
  _IncompleteCoachOnboardingService() : super(updateUser: (_) async {});

  @override
  Future<bool> isComplete(String uid) async => false;
}

class _CompleteCoachOnboardingService extends AbundanceOnboardingService {
  _CompleteCoachOnboardingService() : super(updateUser: (_) async {});

  @override
  Future<bool> isComplete(String uid) async => true;
}

void main() {
  testWidgets('an Abundance Coach is shown the shared onboarding flow',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AbundancePostAuthGate(
          uid: 'coach-1',
          initialName: 'Coach One',
          companyTheme: CompanyThemeData.standard.copyWith(
            companyName: 'Abundance Company',
            companyCode: 'ABU15DN',
            isCompanyTheme: true,
          ),
          isCoach: true,
          service: _IncompleteCoachOnboardingService(),
          child: const Text('Coach home'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coach home'), findsNothing);
    expect(find.text('Begin'), findsOneWidget);
  });

  testWidgets('a Coach outside Abundance keeps the existing child',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AbundancePostAuthGate(
          uid: 'other-coach',
          initialName: 'Other Coach',
          companyTheme: CompanyThemeData.standard.copyWith(
            companyName: 'Other Company',
            companyCode: 'OTHER01',
            isCompanyTheme: true,
          ),
          isCoach: true,
          service: _IncompleteCoachOnboardingService(),
          child: const Text('Existing company coach home'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Existing company coach home'), findsOneWidget);
    expect(find.text('Begin'), findsNothing);
  });

  testWidgets('an existing Abundance Coach skips completed onboarding',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AbundancePostAuthGate(
          uid: 'existing-coach',
          initialName: 'Existing Coach',
          companyTheme: CompanyThemeData.standard.copyWith(
            companyName: 'Abundance Company',
            companyCode: 'ABU15DN',
            isCompanyTheme: true,
          ),
          isCoach: true,
          service: _CompleteCoachOnboardingService(),
          child: const Text('Existing Coach home'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Existing Coach home'), findsOneWidget);
    expect(find.text('Begin'), findsNothing);
  });

  testWidgets('the profile menu does not expose Coach tools', (tester) async {
    final selected = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              AbundanceHeaderProfileButton(
                initials: 'CO',
                profilePic: '',
                displayName: 'Coach One',
                email: 'coach@example.com',
                roleLabel: 'Coach',
                onSelected: selected.add,
              ),
            ],
          ),
        ),
      ),
    );

    await tester
        .tap(find.byKey(const ValueKey('abundance-header-profile-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Coaching'), findsNothing);
    expect(find.text('Students'), findsNothing);

    await tester.tap(find.text('Notifications'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(selected, contains('notifications'));
  });

  testWidgets('a normal Abundance user does not see Coaching destinations',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: [
              AbundanceHeaderProfileButton(
                initials: 'ST',
                profilePic: '',
                displayName: 'Student One',
                roleLabel: 'Student',
                onSelected: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    await tester
        .tap(find.byKey(const ValueKey('abundance-header-profile-menu')));
    await tester.pumpAndSettle();

    expect(find.text('Coaching'), findsNothing);
    expect(find.text('Students'), findsNothing);
  });

  testWidgets('only an Abundance Coach sees More in the bottom navigation',
      (tester) async {
    final service = GoalsService(FakeFirebaseFirestore());
    final company = CompanyThemeData.standard.copyWith(
      companyName: 'Abundance Company',
      companyCode: 'ABU15DN',
      isCompanyTheme: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AbundanceShellScreen(
          isCoach: true,
          service: service,
          uid: 'coach-1',
          companyTheme: company,
          initialIndex: 2,
          questsAccessResolverOverride: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coaching'), findsOneWidget);
    await tester.tap(find.text('Coaching'));
    await tester.pumpAndSettle();
    expect(find.text('COACHING'), findsOneWidget);
    expect(find.text('More'), findsNothing);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('Councils'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: AbundanceShellScreen(
          isCoach: false,
          service: service,
          uid: 'member-1',
          companyTheme: company,
          initialIndex: 2,
          questsAccessResolverOverride: (_) async => true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('More'), findsNothing);
  });
}
