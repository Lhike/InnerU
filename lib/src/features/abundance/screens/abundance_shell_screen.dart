import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_achievements_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_character_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_missions_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_more_sheet.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/coach_quests_roster_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/mentee/abundance_mentee_dashboard_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/mentee/goals_hub_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/authentication/screen/coach_dashboard/coach_dashboard_screen.dart';
import 'package:selfcare_projects/src/features/authentication/screen/leaderboard/leaderboard_screen.dart';
import 'package:selfcare_projects/src/features/authentication/screen/dashboard/daily_tracker.dart';
import 'package:selfcare_projects/src/features/authentication/screen/notifications/notifications_screen.dart';
import 'package:selfcare_projects/src/features/authentication/screen/profile/profile_settings.dart';
import 'package:selfcare_projects/src/features/authentication/screen/todo_list.dart';
import 'package:selfcare_projects/src/features/authentication/screen/login/login_screen.dart';
import 'package:selfcare_projects/src/services/app_session_service.dart';
import 'package:selfcare_projects/src/services/company_theme_service.dart';
import 'package:selfcare_projects/src/services/session_cleanup_service.dart';

/// The custom app shell (header + 5-tab bottom nav) used only for Abundance
/// members. It keeps InnerU's existing data-backed screens and services while
/// presenting the A12 Home, Mission, Quests, Awards, and overflow navigation.
///
/// The "ABUNDANCE 12" / "THE GAME OF MY LIFE" header copy is static ported
/// brand text, not derived from [companyTheme]'s company name — A12 is
/// single-tenant, so its own wordmark is fixed, not tenant-derived.
class AbundanceShellScreen extends StatefulWidget {
  const AbundanceShellScreen({
    super.key,
    required this.isCoach,
    required this.service,
    required this.uid,
    required this.companyTheme,
    this.initialIndex = 0,
    this.questsAccessResolverOverride,
  });

  final bool isCoach;
  final GoalsService service;
  final String uid;
  final CompanyThemeData companyTheme;

  /// Which tab the shell lands on. Defaults to Home (0), matching every A12
  /// reference screenshot — real callers should not need to override this.
  /// Exposed (mirroring the established `Setuppage`/`CoachSetuppage` pattern
  /// in `lib/setup_navbar.dart`) so tests/callers can start on a different
  /// tab without changing the real default — e.g. this shell's own coach
  /// test starts on Quests to avoid building `CoachDashboardScreen`, which
  /// touches `FirebaseFirestore.instance` synchronously and crashes without
  /// a live Firebase app.
  final int initialIndex;

  /// Forwarded verbatim to `GoalsHubScreen.accessResolver` on the mentee
  /// Quests tab. Left `null` in production so `GoalsHubScreen` falls through
  /// to its own real access resolution
  /// (`GoalsService.fetchActiveCompanyIdentity` ->
  /// `CompanyMembershipService.loadForUser`) — exactly the same
  /// production-real-default-with-test-override shape as [initialIndex].
  /// This shell's own widget test supplies a value here because it
  /// constructs `GoalsService(FakeFirebaseFirestore())` with no seeded
  /// `users/{uid}` doc, which would otherwise make the real check correctly
  /// (but inconveniently, for that test) deny access.
  final Future<bool> Function(String uid)? questsAccessResolverOverride;

  @override
  State<AbundanceShellScreen> createState() => _AbundanceShellScreenState();
}

class _AbundanceShellScreenState extends State<AbundanceShellScreen> {
  // Tab order is Home(0)/Mission(1)/Quests(2)/Awards(3)/More(4). Seeded from
  // widget.initialIndex (defaults to Home) in initState below.
  late int _index;

  // Each tab body is constructed at most once, the first time it's
  // selected, then cached here and reused for the rest of the shell's
  // lifetime (so switching tabs preserves scroll position / in-progress
  // state instead of re-fetching). Slots that have never been visited stay
  // a cheap SizedBox.shrink() placeholder rather than eagerly building the
  // real screen — several of the embedded screens (e.g. CoachDashboardScreen)
  // touch Firebase/network state directly in their State's field
  // initializers, which is unsafe to do for tabs the user hasn't opened yet
  // (and, in widget tests without a live Firebase app, throws outright).
  final List<Widget> _builtTabs =
      List<Widget>.filled(5, const SizedBox.shrink());
  final Set<int> _visited = {};

  static const _tabLabels = ['Home', 'Mission', 'Quests', 'Awards', 'More'];
  static const _tabIcons = [
    Icons.home_outlined,
    Icons.calendar_month_outlined,
    Icons.flag_outlined,
    Icons.workspace_premium_outlined,
    Icons.more_horiz,
  ];

  Widget get _questsTabBody => widget.isCoach
      ? CoachQuestsRosterScreen(service: widget.service, coachUid: widget.uid)
      : GoalsHubScreen(
          service: widget.service,
          uid: widget.uid,
          // No hardcoded bypass here: in production this is null, so
          // GoalsHubScreen runs its own real access check
          // (GoalsService.fetchActiveCompanyIdentity ->
          // CompanyMembershipService.loadForUser), the same check every
          // other GoalsHubScreen caller relies on. Only this shell's own
          // widget test supplies a non-null override, via
          // widget.questsAccessResolverOverride, to bypass the check in its
          // specific test setup (see that field's doc comment).
          accessResolver: widget.questsAccessResolverOverride,
        );

  Widget get _homeTabBody => widget.isCoach
      ? const CoachDashboardScreen()
      : AbundanceMenteeDashboardScreen(
          initialCompanyTheme: widget.companyTheme,
          service: widget.service,
        );

  Widget _tabBodyFor(int index) {
    switch (index) {
      case 0:
        return _homeTabBody;
      case 1:
        return AbundanceMissionsScreen(
          onOpenDailyMission: () => _push(const UserProgressPage()),
          onOpenMissionPlan: () => _push(const TodoList()),
        );
      case 2:
        return _questsTabBody;
      case 3:
        return const AbundanceAchievementsScreen();
      default:
        return const SizedBox.shrink(); // "More" never actually renders.
    }
  }

  Future<void> _push(Widget page) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => page),
      );

  Future<void> _openDestination(String key) async {
    Navigator.of(context).pop();
    switch (key) {
      case 'guild':
        await _push(const Leaderboard());
        return;
      case 'profile':
        await _push(AbundanceCharacterScreen(
          uid: widget.uid,
          onOpenAccountSettings: () => _push(const ProfileSettings()),
        ));
        return;
      case 'notifications':
        await _push(NotificationsScreen(userId: widget.uid));
        return;
      case 'activity_logs':
        await Navigator.of(context).pushNamed('/activityLogs');
        return;
      case 'sign_out':
        await _confirmSignOut();
        return;
      case 'coach_students':
      case 'coach_councils':
      case 'coach_core_tasks':
        await _push(const CoachDashboardScreen());
        return;
    }
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AbundanceColors.surfaceRaised,
        title: const Text('Log out',
            style: TextStyle(color: AbundanceColors.foreground)),
        content: const Text('Are you sure you want to log out?',
            style: TextStyle(color: AbundanceColors.muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true) return;
    await SessionCleanupService.signOut();
    await AppSessionService.instance.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AbundanceMoreSheet(
        isCoach: widget.isCoach,
        onDestination: (key) => _openDestination(key),
      ),
    );
  }

  void _ensureBuilt(int index) {
    if (_visited.add(index)) {
      _builtTabs[index] = _tabBodyFor(index);
    }
  }

  @override
  void initState() {
    super.initState();
    // Clamped to 0-3, not 0-4: index 4 ("More") is a bottom-sheet trigger,
    // not a tab body, so landing on it would show an empty SizedBox.shrink().
    _index = widget.initialIndex.clamp(0, 3);
    _ensureBuilt(_index);
  }

  void _onTabTapped(int newIndex) {
    if (newIndex == 4) {
      _showMore();
      return; // stay on the current tab; More is a trigger, not a screen.
    }
    setState(() {
      _index = newIndex;
      _ensureBuilt(newIndex);
    });
  }

  PreferredSizeWidget _buildShellHeader() {
    return AppBar(
      backgroundColor: AbundanceColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('ABUNDANCE 12',
              style: TextStyle(
                  color: AbundanceColors.foreground,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          Text('THE GAME OF MY LIFE',
              style:
                  TextStyle(color: AbundanceColors.primaryGold, fontSize: 10)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none,
              color: AbundanceColors.foreground),
          onPressed: () => _push(NotificationsScreen(userId: widget.uid)),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      // The dashboard owns its AppBar. All other in-shell pages use the
      // shared branded header, avoiding stacked headers.
      appBar: _index == 0 ? null : _buildShellHeader(),
      body: IndexedStack(index: _index, children: _builtTabs),
      bottomNavigationBar: BottomNavigationBar(
        key: const ValueKey('abundance-primary-navigation'),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AbundanceColors.surfaceRaised,
        selectedItemColor: AbundanceColors.primaryGold,
        unselectedItemColor: AbundanceColors.muted,
        currentIndex: _index,
        onTap: _onTabTapped,
        items: [
          for (var i = 0; i < _tabLabels.length; i++)
            BottomNavigationBarItem(
              icon: Icon(_tabIcons[i]),
              label: _tabLabels[i],
            ),
        ],
      ),
    );
  }
}
