import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:selfcare_projects/src/features/abundance/screens/abundance_shell_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_character_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_missions_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_tutorial_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/mentee/abundance_mentee_dashboard_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/mentee/goals_hub_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/services/company_theme_service.dart';
import 'package:selfcare_projects/src/services/app_session_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  testWidgets('direct non-Abundance construction never renders A12 chrome',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: GoalsService(FakeFirebaseFirestore()),
        uid: 'u1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'GEN01',
          companyName: 'General Company',
          isCompanyTheme: true,
        ),
      ),
    ));
    await tester.pump();

    expect(
        find.byKey(const ValueKey('abundance-access-denied')), findsOneWidget);
    expect(find.text('ABUNDANCE 12'), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('authenticated non-Abundance direct route cannot open tutorial',
      (tester) async {
    await AppSessionService.instance.setSession(const AppSession(
      id: 99,
      token: 'test-token',
      name: 'Standard User',
      email: 'standard@example.test',
      role: 'user',
      isCoach: false,
      companyCode: 'GEN01',
      companyName: 'General Company',
    ));
    addTearDown(() async => AppSessionService.instance.clear());
    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: GoalsService(FakeFirebaseFirestore()),
        uid: '99',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'GEN01',
          companyName: 'General Company',
          isCompanyTheme: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('abundance-access-denied')), findsOneWidget);
    expect(find.text('WELCOME TO ABUNDANCE 12'), findsNothing);
  });

  testWidgets('shows the header chrome and switches tabs on tap',
      (tester) async {
    final service = GoalsService(FakeFirebaseFirestore());

    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: service,
        uid: 'u1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
        // Test-only override: this test's GoalsService is backed by a
        // FakeFirebaseFirestore with no seeded `users/u1` doc, so
        // GoalsHubScreen's real access check would otherwise (correctly, for
        // that setup) deny access. See questsAccessResolverOverride's doc
        // comment on AbundanceShellScreen.
        questsAccessResolverOverride: (_) async => true,
      ),
    ));
    await tester.pumpAndSettle();

    // The shell's own header belongs to the Quests tab only — every other
    // tab embeds a screen that brings its own AppBar (see the appBar
    // suppression in AbundanceShellScreen.build).
    await tester.tap(find.text('Quests'));
    await tester.pumpAndSettle();

    expect(find.text('ABUNDANCE 12'), findsOneWidget);
    expect(find.text('THE GAME OF MY LIFE'), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none), findsOneWidget);
    expect(find.textContaining('Life Power'), findsWidgets);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(
        find.text('Home'), findsWidgets); // the tab label itself, still visible
  });

  testWidgets('coach shell keeps the member Quests tab', (tester) async {
    final service = GoalsService(FakeFirebaseFirestore());

    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: true,
        service: service,
        uid: 'coach1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
        // Source Coach accounts keep the member Quests tab; coach tools are
        // opened from the overflow menu instead.
        initialIndex: 2,
        questsAccessResolverOverride: (_) async => true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(GoalsHubScreen), findsOneWidget);
  });

  testWidgets(
      'defaults to the Home tab and shows the mentee dashboard when initialIndex is not supplied',
      (tester) async {
    final service = GoalsService(FakeFirebaseFirestore());

    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: service,
        uid: 'u1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
        // initialIndex deliberately omitted: this is the regression guard
        // that the shell's real default landing tab is Home (0), matching
        // every A12 reference screenshot — not Quests.
        //
        // questsAccessResolverOverride is supplied here purely so the
        // tab-switch assertion below (tapping into Quests) can observe real
        // GoalsHubScreen content — this test's GoalsService has no seeded
        // `users/u1` doc, so the real access check would otherwise deny
        // access. See questsAccessResolverOverride's doc comment for why
        // this is safe as a test-only bypass.
        questsAccessResolverOverride: (_) async => true,
      ),
    ));
    await tester.pumpAndSettle();

    // The bottom nav shows Home as selected and the Quests tab body
    // ("Life Power", GoalsHubScreen's own header text) has not been built.
    expect(find.textContaining('Life Power'), findsNothing);

    // AbundanceMenteeDashboardScreen (the mentee Home tab) is on screen. In
    // this test harness there's no authenticated session, so the dashboard
    // resolves to its own access-denied state — but that state's text is
    // unique to AbundanceMenteeDashboardScreen itself, so finding it proves
    // the Home tab body is genuinely that screen, not a placeholder or the
    // Quests tab.
    expect(find.text('A12 access only'), findsOneWidget);

    // Switching to Quests still works from this default landing point.
    await tester.tap(find.text('Quests'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Life Power'), findsWidgets);
  });

  testWidgets(
      'Abundance Home does not render the legacy InnerU dashboard sections',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: GoalsService(FakeFirebaseFirestore()),
        uid: 'u1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
        questsAccessResolverOverride: (_) async => true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Personal analytics'), findsNothing);
    expect(find.text('New goal'), findsNothing);
  });

  testWidgets(
      'Quests tab uses GoalsHubScreen\'s own real access check when no override is supplied',
      (tester) async {
    // Bare GoalsService(), no legacy Firestore — matches how production
    // constructs it. No questsAccessResolverOverride is supplied: this is
    // the regression guard that production code no longer force-bypasses
    // GoalsHubScreen's access gate.
    final service = GoalsService();

    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: service,
        uid: 'u1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
        initialIndex: 2, // land directly on Quests
      ),
    ));
    await tester.pumpAndSettle();

    // With no legacy Firestore, GoalsService.fetchActiveCompanyIdentity
    // returns null immediately, so GoalsHubScreen's real access chain falls
    // through to CompanyMembershipService.loadForUser('u1'). There's no
    // authenticated AuthService session in this test harness, so
    // UserService.getUserData() short-circuits to `{}` and that resolves to
    // an empty membership — correctly denying access. This proves the shell
    // is no longer forcing `accessResolver: (_) async => true` in
    // production: the real gate is reachable and can actually deny.
    expect(find.text('A12 only'), findsOneWidget);
    expect(find.textContaining('Life Power'), findsNothing);
  });

  testWidgets(
      'profile menu still exposes the overflow actions without changing the selected tab',
      (tester) async {
    final service = GoalsService(FakeFirebaseFirestore());

    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: service,
        uid: 'u1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
        // Test-only override: see the header-chrome test above for why this
        // test's GoalsService needs it to reach real Quests content.
        questsAccessResolverOverride: (_) async => true,
      ),
    ));
    await tester.pumpAndSettle();

    // Navigate to Quests first (the shell's real default landing tab is now
    // Home) and confirm its content is showing before More is tapped, so the
    // "still there after" check below is meaningful.
    await tester.tap(find.text('Quests'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Life Power'), findsWidgets);

    await tester.tap(find.byType(CircleAvatar));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();

    // The Abundance overflow keeps essential existing account actions.
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Activity Logs'), findsOneWidget);
    // The tab underneath is untouched: still Quests, not some 5th "More" body.
    expect(find.textContaining('Life Power'), findsWidgets);
  });

  // -------------------------------------------------------------------
  // Whole-branch review, Important 4: the shell's own Scaffold+AppBar wrapped
  // four placeholder screens that each have a root Scaffold+AppBar of their
  // own, so three of the five tabs rendered two headers stacked on top of
  // each other. The shell now suppresses its own header for those tabs, the
  // same way Setuppage/CoachSetuppage in lib/setup_navbar.dart already do.
  // -------------------------------------------------------------------

  testWidgets('the Guild tab renders exactly one AppBar, not two',
      (tester) async {
    final service = GoalsService(FakeFirebaseFirestore());

    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: service,
        uid: 'u1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guild'));
    await tester.pumpAndSettle();

    // Leaderboard brings its own AppBar; the shell must not add a second.
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('ABUNDANCE 12'), findsNothing);
  });

  testWidgets('the Profile tab renders exactly one AppBar, not two',
      (tester) async {
    final service = GoalsService(FakeFirebaseFirestore());

    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: service,
        uid: 'u1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    // ProfileSettings brings its own AppBar; the shell must not add a second.
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('ABUNDANCE 12'), findsNothing);
  });

  testWidgets(
      'the Quests tab renders exactly one AppBar — the shell\'s own, since '
      'neither Quests body has one', (tester) async {
    final service = GoalsService(FakeFirebaseFirestore());

    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: service,
        uid: 'u1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
        questsAccessResolverOverride: (_) async => true,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quests'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('ABUNDANCE 12'), findsOneWidget);
  });

  testWidgets('the Home tab never stacks the shell header over its own chrome',
      (tester) async {
    final service = GoalsService(FakeFirebaseFirestore());

    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: service,
        uid: 'u1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // There is no authenticated session in this harness, so
    // AbundanceMenteeDashboardScreen resolves to its own access-denied panel,
    // which has a Scaffold but no AppBar — hence "at most one" rather than
    // "exactly one" here. What this asserts either way is the actual fix: the
    // shell contributes no header of its own on this tab, so a real Abundance
    // session (whose dashboard does carry an "Abundance Dashboard" AppBar)
    // sees one header rather than two.
    expect(find.byType(AppBar).evaluate().length, lessThanOrEqualTo(1));
    expect(find.text('ABUNDANCE 12'), findsNothing);
  });

  testWidgets('initialIndex can land on the Guild tab', (tester) async {
    final service = GoalsService(FakeFirebaseFirestore());

    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: service,
        uid: 'u1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
        // 4 is the real Guild tab in the A12 six-item navigation.
        initialIndex: 4,
        questsAccessResolverOverride: (_) async => true,
        achievementsLoaderOverride: () async => const <String>{},
      ),
    ));
    await tester.pumpAndSettle();

    final nav = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(nav.currentIndex, 4);
  });

  testWidgets('profile menu sign out opens the logout confirmation',
      (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AbundanceTutorialScreen.completionKey('42'): true,
    });
    await AppSessionService.instance.setSession(const AppSession(
      id: 42,
      token: 'test-token',
      name: 'Cookie Milo',
      email: 'cookie@example.test',
      role: 'user',
      isCoach: false,
      companyCode: 'ABU15DN',
      companyName: 'Abundance',
    ));
    addTearDown(() async => AppSessionService.instance.clear());

    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: GoalsService(FakeFirebaseFirestore()),
        uid: '42',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
        initialIndex: 5,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AbundanceCharacterScreen), findsOneWidget);
    expect(find.text('ABUNDANCE 12'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('abundance-header-profile-menu')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure you want to log out?'), findsOneWidget);
  });

  testWidgets('home mission calendar keeps the A12 shell navigation visible',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: GoalsService(FakeFirebaseFirestore()),
        uid: 'u1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
        questsAccessResolverOverride: (_) async => true,
      ),
    ));
    await tester.pumpAndSettle();

    final dashboard = tester.widget<AbundanceMenteeDashboardScreen>(
      find.byType(AbundanceMenteeDashboardScreen),
    );
    expect(dashboard.onOpenMissions, isNotNull);

    dashboard.onOpenMissions!();
    await tester.pumpAndSettle();

    final navigation = tester.widget<BottomNavigationBar>(
      find.byType(BottomNavigationBar),
    );
    expect(navigation.currentIndex, 1);
    expect(find.text('ABUNDANCE 12'), findsOneWidget);
    expect(find.byType(AbundanceMissionsScreen), findsOneWidget);
  });

  testWidgets('revisiting Awards reloads progress earned in other tabs',
      (tester) async {
    var loads = 0;
    await tester.pumpWidget(MaterialApp(
      home: AbundanceShellScreen(
        isCoach: false,
        service: GoalsService(FakeFirebaseFirestore()),
        uid: 'u1',
        companyTheme: CompanyThemeData.standard.copyWith(
          companyCode: 'ABU15DN',
          companyName: 'Abundance',
          isCompanyTheme: true,
        ),
        initialIndex: 3,
        achievementsLoaderOverride: () async {
          loads++;
          return const <String>{};
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(loads, 1);

    final navigation = find.byKey(
      const ValueKey('abundance-primary-navigation'),
    );
    await tester.tap(find.descendant(
      of: navigation,
      matching: find.byIcon(Icons.home_outlined),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
      of: navigation,
      matching: find.byIcon(Icons.workspace_premium_outlined),
    ));
    await tester.pumpAndSettle();
    expect(loads, 2);
  });
}
