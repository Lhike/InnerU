# Abundance Company Experience Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete a reference-faithful Abundance mobile experience inside InnerU that is selected only for authenticated users whose active company is `ABU15DN` or `Abundance`.

**Architecture:** Keep InnerU authentication, company validation, persistence, and non-Abundance routing unchanged. Extend the existing `lib/src/features/abundance/` parallel feature with company-scoped presentation adapters, screens, widgets, assets, and a role-aware shell that delegates all writes to existing InnerU services.

**Tech Stack:** Flutter/Dart, Material, Provider, existing InnerU Laravel API services, `fl_chart`, `google_fonts`, Flutter unit/widget tests, Laravel/PHPUnit only if an additive endpoint proves necessary.

**Spec:** `docs/superpowers/specs/2026-09-15-abundance-company-experience-design.md`

## Global Constraints

- InnerU login and sign-up UI remain unchanged.
- Existing company-code validation remains unchanged.
- The Abundance branch is selected only through `AbundanceCompany.matches(code, name)` after authentication.
- `ABU15DN` and normalized company name `ABUNDANCE` are the only approved Abundance identities.
- Non-Abundance companies and company-less users retain their current pages, themes, navigation, and behavior.
- Abundance assets remain below `assets/images/abundance/`; no launcher, splash, login, or global asset is replaced.
- Existing InnerU services and APIs remain the source of truth for authentication, membership, goals, missions/tasks, leaderboard, profile, notifications, and coaching data.
- Every behavior change follows a red-green-refactor cycle.

---

### Task 1: Lock the company boundary and shared Abundance design system

**Files:**
- Modify: `lib/src/features/abundance/theme/abundance_theme.dart`
- Modify: `lib/src/features/abundance/theme/abundance_assets.dart`
- Create: `lib/src/features/abundance/theme/abundance_typography.dart`
- Create: `lib/src/features/abundance/widgets/abundance_card.dart`
- Create: `lib/src/features/abundance/widgets/abundance_button.dart`
- Create: `lib/src/features/abundance/widgets/abundance_status_view.dart`
- Modify: `pubspec.yaml`
- Copy: selected files from `../abundance-inneru-tracker-mobile/assets/web/public/` into `assets/images/abundance/brand/`, `characters/`, `achievements/`, and `scenes/`
- Test: `test/unit/abundance/abundance_assets_test.dart`
- Test: `test/unit/abundance/abundance_theme_test.dart`
- Create: `test/widget/abundance/abundance_primitives_test.dart`

**Interfaces:**
- Consumes: existing `AbundanceCompany.matches(String? code, String? name)`.
- Produces: `AbundanceTypography`, `AbundanceCard`, `AbundanceButton`, `AbundanceStatusView`, and asset lookup functions used by every later screen.

- [ ] **Step 1: Write failing design-system tests**

  Add literal expectations for the reference palette, font families, button semantics, retry callback, and asset paths. The mutation caught is an accidental global/default token, missing action semantics, or a path outside the Abundance namespace.

  ```dart
  test('all experience assets remain in the Abundance namespace', () {
    for (final path in abundanceExperienceAssets) {
      expect(path, startsWith('assets/images/abundance/'));
    }
  });

  testWidgets('status error exposes its retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(home: AbundanceStatusView.error(
      message: 'Could not load.',
      onRetry: () => retried = true,
    )));
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });
  ```

- [ ] **Step 2: Run the focused tests and verify RED**

  Run: `flutter test test/unit/abundance/abundance_assets_test.dart test/unit/abundance/abundance_theme_test.dart test/widget/abundance/abundance_primitives_test.dart`

  Expected: FAIL because the new asset collection, typography, and widgets do not exist.

- [ ] **Step 3: Implement the minimal shared design system**

  Add immutable constants and small stateless widgets. Register `Cinzel` and `Inter` font files in `pubspec.yaml` under distinct Abundance family names. Keep every widget's colors explicit to `AbundanceColors`; do not change `AppTheme.light`, `AppTheme.dark`, or shared `AppColors`.

  ```dart
  abstract final class AbundanceTypography {
    static const displayFamily = 'AbundanceCinzel';
    static const bodyFamily = 'AbundanceInter';
    static const TextStyle eyebrow = TextStyle(
      fontFamily: bodyFamily,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
      color: AbundanceColors.primaryGold,
    );
  }
  ```

- [ ] **Step 4: Copy only referenced assets and update the asset map**

  Copy the A12 logo, `bg2.webp`, WebP character art, and achievement PNGs used by the planned screens. Reuse the existing quest scenes and rank assets. Do not copy the public-site video, duplicate `*-png.png` character files, unused coach photos, or web placeholder SVGs.

- [ ] **Step 5: Run focused tests and verify GREEN**

  Run the same command from Step 2. Expected: PASS with zero failures.

- [ ] **Step 6: Commit Task 1**

  ```bash
  git add pubspec.yaml assets/images/abundance lib/src/features/abundance/theme lib/src/features/abundance/widgets test/unit/abundance test/widget/abundance/abundance_primitives_test.dart
  git commit -m "feat(abundance): add isolated experience design system"
  ```

### Task 2: Define role-aware navigation without touching standard InnerU navigation

**Files:**
- Create: `lib/src/features/abundance/domain/abundance_navigation.dart`
- Modify: `lib/src/features/abundance/screens/abundance_shell_screen.dart`
- Modify: `test/widget/abundance/abundance_shell_screen_test.dart`
- Create: `test/unit/abundance/abundance_navigation_test.dart`

**Interfaces:**
- Consumes: authenticated `isCoach`, `uid`, and `CompanyThemeData` already passed to `AbundanceShellScreen`.
- Produces: `AbundanceDestination`, `abundanceNavigationFor({required bool isCoach})`, retained/lazy tab bodies, and an Abundance-only More surface callback.

- [ ] **Step 1: Write failing navigation tests**

  ```dart
  test('member navigation contains reference destinations in order', () {
    expect(
      abundanceNavigationFor(isCoach: false).map((item) => item.key),
      ['home', 'missions', 'quests', 'achievements', 'guild', 'profile', 'notifications'],
    );
  });

  test('coach navigation adds coaching tools without removing member pages', () {
    final items = abundanceNavigationFor(isCoach: true);
    expect(items.any((item) => item.key == 'coach_students'), isTrue);
    expect(items.any((item) => item.key == 'home'), isTrue);
  });
  ```

  Extend the shell widget test to prove a non-Abundance caller cannot construct the shell through `Setuppage`, and that tab switches retain a stateful child's value.

- [ ] **Step 2: Run tests and verify RED**

  Run: `flutter test test/unit/abundance/abundance_navigation_test.dart test/widget/abundance/abundance_shell_screen_test.dart test/widget/setup_navbar_test.dart`

  Expected: FAIL because the navigation model and full destination set do not exist.

- [ ] **Step 3: Add the pure navigation model**

  ```dart
  enum AbundanceDestinationKind { tab, overflow }

  class AbundanceDestination {
    const AbundanceDestination({
      required this.key,
      required this.label,
      required this.icon,
      required this.kind,
      this.coachOnly = false,
    });
    final String key;
    final String label;
    final IconData icon;
    final AbundanceDestinationKind kind;
    final bool coachOnly;
  }
  ```

- [ ] **Step 4: Refactor only `AbundanceShellScreen` to consume the model**

  Keep standard `Setuppage`, `CoachSetuppage`, and `BottomSheetWidget` behavior unchanged. Use five accessible bottom items on narrow screens (Home, Mission, Quests, Awards, More); expose Guild, Profile, Notifications, and coach tools in an Abundance-only More sheet. Preserve lazy construction and selected-tab state.

- [ ] **Step 5: Run tests and verify GREEN**

  Run the Step 2 command. Expected: PASS.

- [ ] **Step 6: Commit Task 2**

  ```bash
  git add lib/src/features/abundance/domain/abundance_navigation.dart lib/src/features/abundance/screens/abundance_shell_screen.dart test/unit/abundance/abundance_navigation_test.dart test/widget/abundance/abundance_shell_screen_test.dart
  git commit -m "feat(abundance): add isolated role-aware navigation"
  ```

### Task 3: Build the Everyday Missions screen on existing task APIs

**Files:**
- Create: `lib/src/features/abundance/services/abundance_missions_service.dart`
- Create: `lib/src/features/abundance/screens/member/abundance_missions_screen.dart`
- Create: `lib/src/features/abundance/screens/member/abundance_mission_editor.dart`
- Create: `test/unit/abundance/abundance_missions_service_test.dart`
- Create: `test/widget/abundance/abundance_missions_screen_test.dart`

**Interfaces:**
- Consumes: `TodoTaskApiService.fetchTasks/saveTask/updateTask/deleteTask` and `DailyTrackerApiService.fetch/upsert`.
- Produces: `AbundanceMission`, `AbundanceMissionDay`, `AbundanceMissionsGateway`, and `AbundanceMissionsScreen(gateway:, initialDate:)`.

- [ ] **Step 1: Write failing model and widget tests**

  Hand-build task fixtures and assert date filtering, completion rollback, calendar selection, empty state, editor validation, and retry. The production break caught is losing the active date/company context or leaving an optimistic checkbox checked after a failed write.

  ```dart
  testWidgets('failed completion restores the previous checkbox state', (tester) async {
    final gateway = FakeMissionsGateway(failCompletion: true);
    await tester.pumpWidget(MaterialApp(home: AbundanceMissionsScreen(gateway: gateway)));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Complete Read 10 pages'));
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
    expect(find.text('We could not update that mission.'), findsOneWidget);
  });
  ```

- [ ] **Step 2: Run tests and verify RED**

  Run: `flutter test test/unit/abundance/abundance_missions_service_test.dart test/widget/abundance/abundance_missions_screen_test.dart`

  Expected: FAIL because the gateway and screens do not exist.

- [ ] **Step 3: Implement the service adapter**

  Normalize existing todo/daily tracker maps into immutable view models. The default gateway delegates writes to current API services and never writes company identity supplied by UI input; authenticated services retain that authority.

  ```dart
  abstract interface class AbundanceMissionsGateway {
    Future<AbundanceMissionDay> load(DateTime date);
    Future<void> setCompleted(AbundanceMission mission, bool completed);
    Future<AbundanceMission> save(AbundanceMissionDraft draft);
    Future<void> delete(String missionId);
  }
  ```

- [ ] **Step 4: Implement screen and modal editor**

  Match the reference's calendar, category icons, XP labels, completion state, modal editor, loading/error/empty states, and safe date selection. Use shared Abundance primitives only.

- [ ] **Step 5: Run tests and verify GREEN**

  Run the Step 2 command. Expected: PASS.

- [ ] **Step 6: Commit Task 3**

  ```bash
  git add lib/src/features/abundance/services/abundance_missions_service.dart lib/src/features/abundance/screens/member test/unit/abundance/abundance_missions_service_test.dart test/widget/abundance/abundance_missions_screen_test.dart
  git commit -m "feat(abundance): add everyday missions experience"
  ```

### Task 4: Complete the Abundance Home dashboard

**Files:**
- Modify: `lib/src/features/abundance/screens/mentee/abundance_mentee_dashboard_screen.dart`
- Create: `lib/src/features/abundance/widgets/abundance_level_up_overlay.dart`
- Create: `lib/src/features/abundance/domain/abundance_achievements.dart`
- Modify: `test/widget/abundance/abundance_shell_screen_test.dart`
- Create: `test/widget/abundance/abundance_dashboard_screen_test.dart`
- Create: `test/unit/abundance/abundance_achievements_test.dart`

**Interfaces:**
- Consumes: existing dashboard loads, `GoalsService`, mission gateway, scoring/rank functions, profile data, and namespaced assets.
- Produces: a reference-ordered Home page and `AbundanceLevelUpOverlay(previousLevel:, currentLevel:)`.

- [ ] **Step 1: Write failing dashboard presentation tests**

  Test a fully populated fixture, empty missions/goals, failed load/retry, goal progress navigation, achievement shelf navigation, and a level increase. Assert semantics and callbacks rather than private widget structure.

- [ ] **Step 2: Run tests and verify RED**

  Run: `flutter test test/widget/abundance/abundance_dashboard_screen_test.dart test/unit/abundance/abundance_achievements_test.dart`

  Expected: FAIL because the injectable dashboard seam, reference ordering, catalog, and overlay do not exist.

- [ ] **Step 3: Add a testable dashboard loader boundary**

  Preserve the current production loader as the default while allowing a complete `AbundanceDashboardData` fixture in widget tests.

  ```dart
  typedef AbundanceDashboardLoader = Future<AbundanceDashboardData> Function();

  const AbundanceMenteeDashboardScreen({
    super.key,
    this.initialCompanyTheme,
    this.service,
    this.loader,
    this.missionsGateway,
  });
  ```

- [ ] **Step 4: Compose the reference Home hierarchy**

  Render scene hero, greeting, rank/level, Life Power, today's missions with optimistic completion, goal cards, achievement shelf, and closing quote. Keep current data calculations unless a test demonstrates a reference mismatch.

- [ ] **Step 5: Add level/achievement feedback**

  Use animation controller transitions that respect `MediaQuery.disableAnimations`. Never update persistence from the overlay.

- [ ] **Step 6: Run tests and verify GREEN**

  Run the Step 2 command plus `flutter test test/unit/abundance/scoring_test.dart`. Expected: PASS.

- [ ] **Step 7: Commit Task 4**

  ```bash
  git add lib/src/features/abundance/screens/mentee/abundance_mentee_dashboard_screen.dart lib/src/features/abundance/widgets/abundance_level_up_overlay.dart lib/src/features/abundance/domain/abundance_achievements.dart test/widget/abundance/abundance_dashboard_screen_test.dart test/unit/abundance/abundance_achievements_test.dart test/widget/abundance/abundance_shell_screen_test.dart
  git commit -m "feat(abundance): complete reference home dashboard"
  ```

### Task 5: Audit and close Quests parity gaps

**Files:**
- Modify: `lib/src/features/abundance/screens/mentee/goals_hub_screen.dart`
- Modify: `lib/src/features/abundance/screens/mentee/goal_form_screen.dart`
- Modify: `lib/src/features/abundance/screens/mentee/goal_detail_screen.dart`
- Modify: `lib/src/features/abundance/services/goals_service.dart`
- Extend: `test/widget/abundance/goals_hub_screen_test.dart`
- Extend: `test/widget/abundance/goal_form_screen_test.dart`
- Extend: `test/widget/abundance/goal_detail_screen_test.dart`
- Extend: `test/unit/abundance/goals_service_test.dart`

**Interfaces:**
- Consumes/produces: existing public `GoalsService` interface and goal screens; no second schema or duplicate service.

- [ ] **Step 1: Write failing tests for verified reference gaps only**

  Cover realm filtering, progress modal behavior, status menu, action-plan cycles, history, comments, delete confirmation, failure visibility, and navigation return. Do not rewrite behavior already proven by current tests.

- [ ] **Step 2: Run the complete current Abundance goal suite and record RED gaps**

  Run: `flutter test test/unit/abundance/goals_service_test.dart test/unit/abundance/goals_service_writes_test.dart test/unit/abundance/goals_service_merit_test.dart test/widget/abundance/goals_hub_screen_test.dart test/widget/abundance/goal_form_screen_test.dart test/widget/abundance/goal_detail_screen_test.dart`

  Expected: newly added parity assertions FAIL for the missing behavior while existing tests remain green.

- [ ] **Step 3: Implement only missing behavior**

  Reuse `AbundanceButton`, `AbundanceCard`, typography, scene assets, and existing service mutations. Preserve API payload names and legacy Firestore test compatibility.

- [ ] **Step 4: Run tests and verify GREEN**

  Run the Step 2 command. Expected: PASS.

- [ ] **Step 5: Commit Task 5**

  ```bash
  git add lib/src/features/abundance/screens/mentee lib/src/features/abundance/services/goals_service.dart test/widget/abundance test/unit/abundance
  git commit -m "feat(abundance): close quests reference parity gaps"
  ```

### Task 6: Add Achievements, Guild, and Notifications pages

**Files:**
- Create: `lib/src/features/abundance/services/abundance_guild_service.dart`
- Create: `lib/src/features/abundance/services/abundance_notifications_service.dart`
- Create: `lib/src/features/abundance/screens/member/abundance_achievements_screen.dart`
- Create: `lib/src/features/abundance/screens/member/abundance_guild_screen.dart`
- Create: `lib/src/features/abundance/screens/member/abundance_notifications_screen.dart`
- Create: `test/unit/abundance/abundance_guild_service_test.dart`
- Create: `test/widget/abundance/abundance_achievements_screen_test.dart`
- Create: `test/widget/abundance/abundance_guild_screen_test.dart`
- Create: `test/widget/abundance/abundance_notifications_screen_test.dart`

**Interfaces:**
- Consumes: `LeaderboardApiService.fetchLeaderboard`, `CoachApiService.fetchGroups/fetchMyCoaches/fetchRequests`, and `NotificationApiService`.
- Produces: testable gateways and three isolated screens.

- [ ] **Step 1: Write failing gateway and page tests**

  Assert literal leaderboard ordering, current-member/council emphasis, invite callbacks where supported, grouped locked/unlocked achievements, mark-read behavior, mark-all-read behavior, and load/error/empty/retry states.

- [ ] **Step 2: Run tests and verify RED**

  Run: `flutter test test/unit/abundance/abundance_guild_service_test.dart test/widget/abundance/abundance_achievements_screen_test.dart test/widget/abundance/abundance_guild_screen_test.dart test/widget/abundance/abundance_notifications_screen_test.dart`

  Expected: FAIL because the adapters and pages do not exist.

- [ ] **Step 3: Implement additive adapters**

  ```dart
  abstract interface class AbundanceGuildGateway {
    Future<AbundanceGuildData> load();
    Future<void> respondToInvitation(String invitationId, bool accept);
  }

  abstract interface class AbundanceNotificationsGateway {
    Future<List<AbundanceNotification>> load();
    Future<void> markRead(String id);
    Future<void> markAllRead();
  }
  ```

  InnerU's coach requests are not the reference application's council
  invitations, so this slice renders council membership and pending request
  information read-only. It does not expose an accept action that the existing
  member API cannot perform.

- [ ] **Step 4: Implement the pages**

  Match the reference card hierarchy, rank art, member/council distinctions,
  achievement catalog grouping, and notification actions. Use only Abundance
  primitives and existing services.

- [ ] **Step 5: Run tests and verify GREEN**

  Run the Step 2 command. Expected: PASS.

- [ ] **Step 6: Commit Task 6**

  ```bash
  git add lib/src/features/abundance/services/abundance_guild_service.dart lib/src/features/abundance/services/abundance_notifications_service.dart lib/src/features/abundance/screens/member test/unit/abundance/abundance_guild_service_test.dart test/widget/abundance
  git commit -m "feat(abundance): add awards guild and notifications"
  ```

### Task 7: Add Character/Profile, More, tutorial replay, and coach destinations

**Files:**
- Create: `lib/src/features/abundance/services/abundance_profile_service.dart`
- Create: `lib/src/features/abundance/screens/member/abundance_profile_screen.dart`
- Create: `lib/src/features/abundance/screens/member/abundance_more_sheet.dart`
- Create: `lib/src/features/abundance/screens/member/abundance_tutorial_overlay.dart`
- Modify: `lib/src/features/abundance/screens/coach/coach_quests_roster_screen.dart`
- Modify: `lib/src/features/abundance/screens/abundance_shell_screen.dart`
- Create: `test/widget/abundance/abundance_profile_screen_test.dart`
- Create: `test/widget/abundance/abundance_more_sheet_test.dart`
- Create: `test/widget/abundance/abundance_tutorial_overlay_test.dart`
- Extend: `test/widget/abundance/coach_quests_roster_screen_test.dart`
- Extend: `test/widget/abundance/abundance_shell_screen_test.dart`

**Interfaces:**
- Consumes: `UserService`, current profile/settings routes, `AuthService`, coach services, and namespaced character assets.
- Produces: `AbundanceProfileGateway`, Character Sheet, More sheet, replayable tutorial, and coach-only overflow routes.

- [ ] **Step 1: Write failing profile, More, tutorial, and coach-role tests**

  Assert character selection persistence, profile edit delegation, sign-out,
  notification/tutorial navigation, tutorial skip/replay, and coach-only route
  visibility. Assert ordinary members cannot see coach tools.

- [ ] **Step 2: Run tests and verify RED**

  Run: `flutter test test/widget/abundance/abundance_profile_screen_test.dart test/widget/abundance/abundance_more_sheet_test.dart test/widget/abundance/abundance_tutorial_overlay_test.dart test/widget/abundance/coach_quests_roster_screen_test.dart test/widget/abundance/abundance_shell_screen_test.dart`

  Expected: FAIL because the new pages/actions do not exist.

- [ ] **Step 3: Implement profile adapter and Character Sheet**

  ```dart
  abstract interface class AbundanceProfileGateway {
    Future<AbundanceProfileData> load();
    Future<void> saveCharacter(String characterKey);
    Future<void> updateFields(Map<String, dynamic> fields);
    Future<void> signOut();
  }
  ```

  Store an Abundance character key only for an authenticated Abundance user;
  continue delegating shared profile fields/avatar/password operations to
  established InnerU behavior.

- [ ] **Step 4: Implement More and tutorial behavior**

  The More sheet routes to Guild, Profile, Notifications, tutorial replay, and
  coach tools. Tutorial completion is stored per authenticated user, not as a
  global company/device flag.

- [ ] **Step 5: Complete coach presentation**

  Retain the existing read/write permissions and APIs. Apply reference
  presentation to quest roster and link existing coach groups/students/core
  tasks screens from coach-only More items without changing non-Abundance coach
  navigation.

- [ ] **Step 6: Run tests and verify GREEN**

  Run the Step 2 command. Expected: PASS.

- [ ] **Step 7: Commit Task 7**

  ```bash
  git add lib/src/features/abundance test/widget/abundance
  git commit -m "feat(abundance): add character more tutorial and coach tools"
  ```

### Task 8: Wire all destinations and prove the three safety scenarios

**Files:**
- Modify: `lib/src/features/abundance/screens/abundance_shell_screen.dart`
- Extend: `test/widget/setup_navbar_test.dart`
- Extend: `test/widget/abundance/abundance_shell_screen_test.dart`
- Create: `test/widget/abundance/abundance_company_experience_test.dart`

**Interfaces:**
- Consumes: every screen/gateway from Tasks 1–7 and the existing post-authenticated company resolution flow.
- Produces: the complete conditional experience with no route placeholders.

- [ ] **Step 1: Write failing end-to-end widget composition tests**

  ```dart
  testWidgets('ABU15DN builds the complete Abundance shell', (tester) async {
    await pumpAuthenticatedCompany(tester, code: 'ABU15DN');
    expect(find.bySemanticsLabel('Abundance primary navigation'), findsOneWidget);
    expect(find.text('Mission'), findsOneWidget);
    expect(find.text('Quests'), findsOneWidget);
  });

  testWidgets('another company retains the standard InnerU shell', (tester) async {
    await pumpAuthenticatedCompany(tester, code: 'GEN01');
    expect(find.bySemanticsLabel('Abundance primary navigation'), findsNothing);
    expect(find.byType(Setuppage), findsOneWidget);
  });

  testWidgets('company-less user retains the standard InnerU shell', (tester) async {
    await pumpAuthenticatedCompany(tester, code: '');
    expect(find.bySemanticsLabel('Abundance primary navigation'), findsNothing);
    expect(find.byType(Setuppage), findsOneWidget);
  });
  ```

- [ ] **Step 2: Run safety tests and verify RED**

  Run: `flutter test test/widget/abundance/abundance_company_experience_test.dart test/widget/abundance/abundance_shell_screen_test.dart test/widget/setup_navbar_test.dart`

  Expected: FAIL until every destination is wired and the test seam can supply resolved company themes.

- [ ] **Step 3: Wire real shell destinations**

  Replace every Abundance placeholder with its completed page. Keep
  `Setuppage` and `CoachSetuppage`'s existing single conditional branch; do not
  add route-specific company heuristics.

- [ ] **Step 4: Run safety tests and verify GREEN**

  Run the Step 2 command. Expected: PASS.

- [ ] **Step 5: Run authentication and company regression tests**

  Run: `flutter test test/widget/login_screen_test.dart test/widget/signup_screen_test.dart test/widget/role_selection_screen_test.dart test/unit/company_membership_service_test.dart test/unit/company_theme_service_test.dart test/unit/abundance/abundance_company_test.dart test/unit/abundance/abundance_gating_sites_test.dart test/unit/default_landing_screen_test.dart`

  Expected: PASS with no changed login/sign-up expectations.

- [ ] **Step 6: Run full verification**

  Run: `dart format --output=none --set-exit-if-changed lib test`

  Run: `flutter analyze`

  Run: `flutter test`

  Expected: all commands exit 0. If an API was changed, also run
  `cd backend && php artisan test` and require exit 0.

- [ ] **Step 7: Perform manual layout and interaction checks**

  Exercise phone and tablet sizes for an Abundance member, another-company
  member, and company-less member. Verify no Abundance splash/login branding,
  no standard-shell flash after company resolution, functional navigation and
  modals, and unchanged standard pages.

- [ ] **Step 8: Commit Task 8**

  ```bash
  git add lib/src/features/abundance test/widget/setup_navbar_test.dart test/widget/abundance
  git commit -m "feat(abundance): complete conditional company experience"
  ```
