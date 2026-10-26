import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/screens/coach/coach_quests_roster_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/mentee/abundance_mentee_dashboard_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/mentee/goals_hub_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_profile_menu.dart';
import 'package:selfcare_projects/src/features/authentication/screen/coach_dashboard/coach_dashboard_screen.dart';
import 'package:selfcare_projects/src/features/authentication/screen/leaderboard/leaderboard_screen.dart';
import 'package:selfcare_projects/src/features/authentication/screen/dashboard/daily_tracker.dart';
import 'package:selfcare_projects/src/features/authentication/screen/community/community_screen.dart';
import 'package:selfcare_projects/src/features/authentication/screen/profile/profile_settings.dart';
import 'package:selfcare_projects/src/features/authentication/screen/notifications/notifications_screen.dart';
import 'package:selfcare_projects/src/services/company_theme_service.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';
import 'package:selfcare_projects/src/services/session_cleanup_service.dart';

/// The custom app shell (header + six-tab bottom nav) A12-Tracker wraps every
/// screen in, built only for Abundance members. The Home tab uses the
/// reference A12 dashboard while Mission, Quests, Awards, Guild, and Profile
/// reuse InnerU functionality inside the isolated Abundance shell.
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
  // Tab order mirrors the reference: Home/Mission/Quests/Awards/Guild/Profile.
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
      List<Widget>.filled(6, const SizedBox.shrink());
  final Set<int> _visited = {};

  static const _tabLabels = [
    'Home',
    'Mission',
    'Quests',
    'Awards',
    'Guild',
    'Profile'
  ];
  static const _tabIcons = [
    Icons.home_outlined,
    Icons.calendar_month_outlined,
    Icons.military_tech_outlined,
    Icons.emoji_events_outlined,
    Icons.groups_outlined,
    Icons.person_outline,
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
        return const UserProgressPage();
      case 2:
        return _questsTabBody;
      case 3:
        return const Leaderboard();
      case 4:
        return const _AbundanceGuildTab();
      case 5:
        return const ProfileSettings();
      default:
        return const SizedBox.shrink();
    }
  }

  void _ensureBuilt(int index) {
    if (_visited.add(index)) {
      _builtTabs[index] = _tabBodyFor(index);
    }
  }

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 5);
    _ensureBuilt(_index);
  }

  void _onTabTapped(int newIndex) {
    setState(() {
      _index = newIndex;
      _ensureBuilt(newIndex);
    });
  }

  static const int _questsTabIndex = 2;

  PreferredSizeWidget _buildShellHeader(BuildContext context) {
    return AppBar(
      backgroundColor: AbundanceColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      titleSpacing: 18,
      title: Row(
        children: [
          Image.asset(
            'assets/images/abundance/brand/a12-logo.png',
            width: 42,
            height: 38,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ABUNDANCE 12',
                  style: TextStyle(
                    color: AbundanceColors.foreground,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1.6,
                  ),
                ),
                Text(
                  'THE GAME OF MY LIFE',
                  style: TextStyle(
                    color: AbundanceColors.primaryGold,
                    fontWeight: FontWeight.w800,
                    fontSize: 9,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AbundanceColors.borderStrong),
          ),
          child: const Icon(
            Icons.notifications_none,
            color: AbundanceColors.mutedStrong,
            size: 21,
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: AbundanceProfileMenuButton(
            displayName: AuthService.instance.currentSession?.name ?? '',
            email: AuthService.instance.currentSession?.email ?? '',
            roleLabel: widget.isCoach ? 'Coach' : 'Student',
            onNotifications: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(
                  userId:
                      AuthService.instance.currentSession?.id.toString() ?? '',
                ),
              ),
            ),
            onProfile: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileSettings()),
            ),
            onReplayTutorial: () {},
            onSignOut: () async {
              await SessionCleanupService.signOut();
              if (context.mounted) {
                Navigator.of(context)
                    .pushNamedAndRemoveUntil('/login', (_) => false);
              }
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      // Only the Quests tab gets the shell's own header. The other four tabs
      // embed InnerU screens that each bring their own root Scaffold+AppBar
      // (AbundanceMenteeDashboardScreen, CoachDashboardScreen, Leaderboard,
      // ProfileSettings), so rendering the shell's header there stacked two
      // headers on top of each other. This mirrors how Setuppage/
      // CoachSetuppage in lib/setup_navbar.dart already solve the same
      // problem (`appBar: index == 2 ? null : AppBar(...)`).
      //
      // Neither Quests-tab body has an AppBar of its own — GoalsHubScreen has
      // no Scaffold at all and CoachQuestsRosterScreen's Scaffold passes no
      // appBar — so this is the one tab that needs the shell to supply one.
      appBar: _index == _questsTabIndex ? _buildShellHeader(context) : null,
      body: IndexedStack(index: _index, children: _builtTabs),
      bottomNavigationBar: BottomNavigationBar(
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

/// Keeps the Guild tab's chrome inside the Abundance shell. The underlying
/// community feed remains the existing implementation; only the wrapper is
/// Abundance-specific, so other companies keep their original navigation.
class _AbundanceGuildTab extends StatelessWidget {
  const _AbundanceGuildTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      appBar: AppBar(
        backgroundColor: AbundanceColors.surfaceRaised,
        foregroundColor: AbundanceColors.foreground,
        surfaceTintColor: Colors.transparent,
        title: const Text('Guild'),
      ),
      body: const CommunityScreen(showStandaloneAppBar: false),
    );
  }
}
