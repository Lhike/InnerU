import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_achievements_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_character_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_guild_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_missions_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_more_sheet.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_notifications_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_coaching_note_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_tutorial_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_management_screens.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_student_file_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/coach_quests_roster_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_directory_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/mentee/abundance_mentee_dashboard_screen.dart';
import 'package:selfcare_projects/src/features/abundance/screens/mentee/goals_hub_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_achievements_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_missions_service.dart';
import 'package:selfcare_projects/src/features/abundance/domain/abundance_company.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_header_profile_button.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_tutorial_overlay.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_tutorial_target.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_controller.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_steps.dart';
import 'package:selfcare_projects/src/features/authentication/screen/coach_dashboard/coach_dashboard_screen.dart';
import 'package:selfcare_projects/src/features/authentication/screen/coach_dashboard/coach_accountability_meetings_screen.dart';
import 'package:selfcare_projects/src/features/authentication/screen/login/login_screen.dart';
import 'package:selfcare_projects/src/services/app_session_service.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';
import 'package:selfcare_projects/src/services/company_theme_service.dart';
import 'package:selfcare_projects/src/services/profile_picture_bus.dart';
import 'package:selfcare_projects/src/services/session_cleanup_service.dart';

/// The custom app shell (header + six-tab bottom nav) used only for Abundance
/// members. It keeps InnerU's existing data-backed screens and services while
/// presenting the A12 Home, Mission, Quests, Awards, Guild, and Profile flow.
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
    this.achievementsLoaderOverride,
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
  final Future<Set<String>> Function()? achievementsLoaderOverride;

  @override
  State<AbundanceShellScreen> createState() => _AbundanceShellScreenState();
}

class _AbundanceShellScreenState extends State<AbundanceShellScreen> {
  // Tab order is Home(0)/Mission(1)/Quests(2)/Awards(3)/Guild(4)/Profile(5).
  // Seeded from
  // widget.initialIndex (defaults to Home) in initState below.
  late int _index;
  String _appearance = 'dark';
  String? _profilePictureOverride;
  late final AbundanceTutorialController _tutorialController;

  // Each tab body is constructed at most once, the first time it's
  // selected, then cached here and reused for the rest of the shell's
  // lifetime (so switching tabs preserves scroll position / in-progress
  // state instead of re-fetching). Slots that have never been visited stay
  // a cheap SizedBox.shrink() placeholder rather than eagerly building the
  // real screen — several of the embedded screens (e.g. CoachDashboardScreen)
  // touch Firebase/network state directly in their State's field
  // initializers, which is unsafe to do for tabs the user hasn't opened yet
  // (and, in widget tests without a live Firebase app, throws outright).
  final List<Widget> _builtTabs = List<Widget>.filled(
    6,
    const SizedBox.shrink(),
  );
  final Set<int> _visited = {};

  Widget get _questsTabBody => GoalsHubScreen(
        service: widget.service,
        uid: widget.uid,
        tutorialController: _tutorialController,
        // Coach accounts keep the same member Quests tab as the source app;
        // the coach roster is an overflow tool, opened via More.
        accessResolver: widget.questsAccessResolverOverride,
      );

  Widget get _homeTabBody => AbundanceMenteeDashboardScreen(
        key: UniqueKey(),
        initialCompanyTheme: widget.companyTheme,
        service: widget.service,
        missionsGateway: A12AbundanceMissionsGateway(),
        onOpenMissions: () => _onTabTapped(1),
        onOpenAwards: () => _onTabTapped(3),
        tutorialController: _tutorialController,
        onReplayTutorial: _startTutorial,
      );

  Widget _tabBodyFor(int index) {
    switch (index) {
      case 0:
        return _homeTabBody;
      case 1:
        return AbundanceMissionsScreen(
          gateway: A12AbundanceMissionsGateway(),
          onMissionChanged: _refreshHomeTab,
          tutorialController: _tutorialController,
        );
      case 2:
        return _questsTabBody;
      case 3:
        final override = widget.achievementsLoaderOverride;
        if (override != null) {
          return AbundanceAchievementsScreen(
            key: UniqueKey(),
            loader: override,
            tutorialController: _tutorialController,
          );
        }
        final gateway = InnerUAbundanceAchievementsGateway(
          uid: widget.uid,
          goals: widget.service,
        );
        return AbundanceAchievementsScreen(
          key: UniqueKey(),
          loader: gateway.load,
          tutorialController: _tutorialController,
        );
      case 4:
        return AbundanceGuildScreen(
          onSignOut: _confirmSignOut,
          tutorialController: _tutorialController,
        );
      case 5:
        return AbundanceCharacterScreen(
          uid: widget.uid,
          // A12 Profile owns its settings surface. Do not route ABU users to
          // InnerU's generic ProfileSettings screen.
          onOpenAccountSettings: () {},
          onOpenAchievements: () => _onTabTapped(3),
          appearance: _appearance,
          onAppearanceChanged: (value) => unawaited(_setAppearance(value)),
          onSignOut: _confirmSignOut,
          onReplayTutorial: () => unawaited(_openDestination('tutorial')),
          goalsService: widget.service,
          tutorialController: _tutorialController,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _push(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _openDestination(String key) async {
    switch (key) {
      case 'guild':
        await _push(AbundanceGuildScreen(onSignOut: _confirmSignOut));
        return;
      case 'profile':
        await _push(
          AbundanceCharacterScreen(
            uid: widget.uid,
            onOpenAccountSettings: () {},
            onOpenAchievements: () => _onTabTapped(3),
            appearance: _appearance,
            isCoach: widget.isCoach,
            onAppearanceChanged: (value) => unawaited(_setAppearance(value)),
            onSignOut: _confirmSignOut,
            onReplayTutorial: () => unawaited(_openDestination('tutorial')),
            goalsService: widget.service,
          ),
        );
        return;
      case 'notifications':
        await _push(AbundanceNotificationsScreen(
          onNotificationTap: (notification) {
            if (notification.title.toLowerCase().contains('coaching') ||
                notification.data?['coachingNoteId'] != null ||
                notification.data?['actionItemId'] != null) {
              unawaited(_push(
                  AbundanceCoachingNoteScreen(notification: notification)));
            }
          },
        ));
        return;
      case 'activity_logs':
        await Navigator.of(context).pushNamed('/activityLogs');
        return;
      case 'tutorial':
        _startTutorial();
        return;
      case 'sign_out':
        await _confirmSignOut();
        return;
      case 'coach_students':
      case 'coach_councils':
      case 'coach_core_tasks':
      case 'coach_quests':
        await _openCoachDestination(key);
        return;
      case 'coach_directory':
        await _push(AbundanceCoachDirectoryScreen(
          service: widget.service,
          coachUid: widget.uid,
        ));
        return;
    }
  }

  Future<void> _openCoachDestination(String key) async {
    switch (key) {
      case 'coach_students':
        await _push(
          AbundanceCoachStudentsScreen(
            onOpenManagement: () => _push(const CoachDashboardScreen()),
            onOpenStudent: (student) => _push(
              AbundanceCoachStudentFileScreen(
                student: student,
                onTabSelected: (index) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  _onTabTapped(index);
                },
              ),
            ),
          ),
        );
        return;
      case 'coach_councils':
        await _push(
          AbundanceCoachCouncilsScreen(
            onOpenMeetings: () =>
                _push(const CoachAccountabilityMeetingsScreen()),
          ),
        );
        return;
      case 'coach_core_tasks':
        await _push(AbundanceCoachCoreTasksScreen(service: widget.service));
        return;
      case 'coach_quests':
        await _push(
          CoachQuestsRosterScreen(
            service: widget.service,
            coachUid: widget.uid,
            rosterLoader: () async {
              final roster = await widget.service.fetchA12CoachRoster();
              return roster.map((student) {
                final first = (student['firstName'] ?? '').toString();
                final last = (student['lastName'] ?? '').toString();
                return CoachMenteeGoals(
                  menteeId: (student['id'] ?? '').toString(),
                  menteeName: '$first $last'.trim(),
                  goals: (student['goals'] is List
                          ? (student['goals'] as List).whereType<Map>()
                          : const <Map>[])
                      .map((goal) => GoalSummary.fromJson(
                            Map<String, dynamic>.from(goal),
                          ))
                      .toList(),
                );
              }).toList();
            },
          ),
        );
        return;
      case 'coach_directory':
        await _push(AbundanceCoachDirectoryScreen(
          service: widget.service,
          coachUid: widget.uid,
        ));
        return;
    }
  }

  Future<void> _confirmSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AbundanceColors.surfaceRaised,
        title: const Text(
          'Log out',
          style: TextStyle(color: AbundanceColors.foreground),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AbundanceColors.muted),
        ),
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
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .72),
      builder: (_) => AbundanceMoreSheet(
        isCoach: widget.isCoach,
        displayName: AuthService.instance.currentSession?.name ?? '',
        email: AuthService.instance.currentSession?.email ?? '',
        roleLabel: widget.isCoach ? 'Coach' : 'Student',
        appearance: _appearance,
        onAppearanceChanged: (value) => unawaited(_setAppearance(value)),
        onDestination: (key) {
          Navigator.of(context).pop();
          unawaited(_openDestination(key));
        },
      ),
    );
  }

  String _headerInitials() {
    final name = AuthService.instance.currentSession?.name.trim() ?? '';
    final words = name
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .take(2)
        .toList();
    if (words.isEmpty) return 'A';
    return words.map((word) => word[0]).join().toUpperCase();
  }

  void _ensureBuilt(int index) {
    if (_visited.add(index)) {
      _builtTabs[index] = _tabBodyFor(index);
    }
  }

  @override
  void initState() {
    super.initState();
    _tutorialController = AbundanceTutorialController(
      uid: widget.uid,
      displayName: AuthService.instance.currentSession?.name,
      roles: {
        AbundanceTutorialRole.member,
        if (widget.isCoach) AbundanceTutorialRole.coach,
      },
    )..addListener(_onTutorialChanged);
    ProfilePictureBus.latestUrl.addListener(_onProfilePictureBusUpdate);
    AbundanceColors.lightAppearanceActive = false;
    _index = widget.initialIndex.clamp(0, 5);
    _ensureBuilt(_index);
    _loadAppearance();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstRunGuide());
  }

  @override
  void dispose() {
    _tutorialController
      ..removeListener(_onTutorialChanged)
      ..dispose();
    ProfilePictureBus.latestUrl.removeListener(_onProfilePictureBusUpdate);
    super.dispose();
  }

  void _onTutorialChanged() {
    if (!mounted || !_tutorialController.active) return;
    final index = switch (_tutorialController.step.route) {
      '/missions' => 1,
      '/quests' => 2,
      '/achievements' => 3,
      '/guild' => 4,
      '/profile' => 5,
      _ => 0,
    };
    _ensureBuilt(index);
    if (_index != index) _index = index;
    setState(() {});
    // Replay can be launched from a different tab while its page is still
    // mounted in the IndexedStack. Give the destination one frame to build so
    // its section target can measure before the spotlight is painted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _tutorialController.active) setState(() {});
    });
  }

  void _startTutorial() {
    // A replay always begins at Home, matching the source tutorial's first
    // navigable lesson instead of leaving the previous tab underneath it.
    _index = 0;
    _ensureBuilt(0);
    _tutorialController.start();
    if (mounted) setState(() {});
  }

  void _onProfilePictureBusUpdate() {
    if (!mounted) return;
    setState(() => _profilePictureOverride = ProfilePictureBus.latestUrl.value);
  }

  Future<void> _loadAppearance() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final systemBrightness = MediaQuery.platformBrightnessOf(context);
    final saved = preferences.getString('abundance-appearance');
    if (const ['light', 'dark', 'system'].contains(saved)) {
      AbundanceColors.lightAppearanceActive = saved == 'light' ||
          (saved == 'system' && systemBrightness == Brightness.light);
      if (mounted) setState(() => _appearance = saved!);
      return;
    }
  }

  Future<void> _setAppearance(String value) async {
    if (!const ['light', 'dark', 'system'].contains(value)) return;
    AbundanceColors.lightAppearanceActive = value == 'light' ||
        (value == 'system' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    setState(() {
      _appearance = value;
      // Rebuild visited A12 tabs so artwork wrappers receive the new mode.
      for (final index in _visited.toList()) {
        _builtTabs[index] = _tabBodyFor(index);
      }
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('abundance-appearance', value);
  }

  Future<void> _showFirstRunGuide() async {
    if (!AbundanceCompany.matches(
      widget.companyTheme.companyCode,
      widget.companyTheme.companyName,
    )) {
      return;
    }
    final session = AuthService.instance.currentSession;
    if (session == null || session.id.toString() != widget.uid) return;
    final preferences = await SharedPreferences.getInstance();
    final completed = preferences.getBool(
          AbundanceTutorialScreen.completionKey(widget.uid),
        ) ??
        false;
    if (!mounted || completed) return;
    _startTutorial();
  }

  void _onTabTapped(int newIndex) {
    setState(() {
      _index = newIndex;
      // Goals are created/edited from the Quests tab. Recreate the cached
      // Home body when returning so its server-backed goal cards and scores
      // reflect the write immediately instead of showing the old snapshot.
      if (newIndex == 0 && _visited.contains(0)) {
        _builtTabs[0] = _tabBodyFor(0);
      }
      if (newIndex == 3 && _visited.contains(3)) {
        _builtTabs[3] = _tabBodyFor(3);
      }
      _ensureBuilt(newIndex);
    });
  }

  void _refreshHomeTab() {
    if (!mounted || !_visited.contains(0)) return;
    setState(() {
      _builtTabs[0] = _tabBodyFor(0);
    });
  }

  PreferredSizeWidget _buildShellHeader() {
    return AppBar(
      backgroundColor: AbundanceColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      toolbarHeight: 72,
      titleSpacing: 18,
      title: Row(
        children: [
          AbundanceArtwork(
            child: Image.asset(
              abundanceLogoAsset,
              width: 42,
              height: 38,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 9),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ABUNDANCE 12',
                    style: TextStyle(
                      color: AbundanceColors.foreground,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1.6,
                    ),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'THE GAME OF MY LIFE',
                    style: TextStyle(
                      color: AbundanceColors.primaryGold,
                      fontWeight: FontWeight.w800,
                      fontSize: 9,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _push(const AbundanceNotificationsScreen()),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AbundanceColors.border),
            ),
            child: const Icon(
              Icons.notifications_none,
              color: AbundanceColors.muted,
              size: 21,
            ),
          ),
        ),
        const SizedBox(width: 10),
        AbundanceHeaderProfileButton(
          initials: _headerInitials(),
          profilePic: _profilePictureOverride ??
              AuthService.instance.currentSession?.profilePic ??
              '',
          displayName: AuthService.instance.currentSession?.name ?? '',
          email: AuthService.instance.currentSession?.email ?? '',
          roleLabel: widget.isCoach ? 'Coach' : 'Student',
          appearance: _appearance,
          onAppearanceChanged: (value) => unawaited(_setAppearance(value)),
          onSelected: (value) {
            if (value == 'more') {
              _showMore();
            } else {
              unawaited(_openDestination(value));
            }
          },
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AbundanceCompany.matches(
      widget.companyTheme.companyCode,
      widget.companyTheme.companyName,
    )) {
      return const Scaffold(
        key: ValueKey('abundance-access-denied'),
        body: Center(
          child: Text('This company does not have access to Abundance 12.'),
        ),
      );
    }
    final scaffold = Scaffold(
      backgroundColor: AbundanceColors.background,
      // Each embedded screen owns its own AppBar except the Quests body,
      // which is intentionally AppBar-free and uses the shared A12 header.
      // This prevents stacked headers while keeping the reference chrome.
      // Home owns its own header; Mission and Quests use the shared A12
      // header exactly like the source tab screens.
      // Awards has no nested AppBar, so it uses the same persistent A12
      // header as Missions and Quests. Home/Profile/Guild own their source
      // chrome and remain unchanged here.
      appBar: (_index == 1 || _index == 2 || _index == 3)
          ? _buildShellHeader()
          : null,
      body: AbundanceTutorialTarget(
        // Screen-level targets own their own exact containers. Keep this
        // wrapper available only for the welcome step, which has no target.
        name: 'tutorial-shell',
        controller: _tutorialController,
        child: IndexedStack(index: _index, children: _builtTabs),
      ),
      bottomNavigationBar: _AbundanceBottomNavigationBar(
        currentIndex: _index,
        isCoach: widget.isCoach,
        onTap: _onTabTapped,
        onMore: _showMore,
      ),
    );
    final lightMode = _appearance == 'light' ||
        (_appearance == 'system' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    final content = Stack(
      fit: StackFit.expand,
      children: [
        scaffold,
        if (_tutorialController.active)
          ListenableBuilder(
            listenable: _tutorialController,
            builder: (_, __) => _tutorialController.active
                ? AbundanceTutorialOverlay(controller: _tutorialController)
                : const SizedBox.shrink(),
          ),
      ],
    );
    if (!lightMode) return content;

    // The A12 widgets use a fixed dark token set inherited from the source
    // app. Apply the light appearance at this company shell boundary so the
    // preference has a real visible effect without changing InnerU's other
    // company themes.
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        -1,
        0,
        0,
        0,
        255,
        0,
        -1,
        0,
        0,
        255,
        0,
        0,
        -1,
        0,
        255,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: content,
    );
  }
}

/// A12's animated member tab bar: all labels remain visible while the active
/// icon gets a gold circular lift and the selection springs between slots.
/// This is intentionally scoped to the Abundance shell; InnerU's standard
/// navigation remains untouched.
class _AbundanceBottomNavigationBar extends StatelessWidget {
  const _AbundanceBottomNavigationBar({
    required this.currentIndex,
    required this.isCoach,
    required this.onTap,
    required this.onMore,
  });

  final int currentIndex;
  final bool isCoach;
  final ValueChanged<int> onTap;
  final VoidCallback onMore;

  static const memberLabels = [
    'Home',
    'Mission',
    'Quests',
    'Awards',
    'Guild',
    'Profile',
  ];
  static const memberIcons = [
    Icons.home_outlined,
    Icons.calendar_month_outlined,
    Icons.flag_outlined,
    Icons.workspace_premium_outlined,
    Icons.groups_outlined,
    Icons.account_circle_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      ...memberLabels,
      if (isCoach) 'Coaching',
    ];
    final icons = <IconData>[
      ...memberIcons,
      if (isCoach) Icons.more_horiz,
    ];
    return Semantics(
      label: 'Abundance primary navigation',
      child: Container(
        color: AbundanceColors.surfaceRaised,
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              Container(
                key: const ValueKey('abundance-primary-navigation'),
                height: 68,
                decoration: const BoxDecoration(
                  color: AbundanceColors.surfaceRaised,
                  border:
                      Border(top: BorderSide(color: AbundanceColors.border)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      Expanded(
                        child: _AbundanceNavigationItem(
                          icon: icons[i],
                          label: labels[i],
                          active: currentIndex == i,
                          onTap: () =>
                              i == memberLabels.length ? onMore() : onTap(i),
                        ),
                      ),
                  ],
                ),
              ),
              // Compatibility node for existing automation that inspects the
              // selected index by widget type. It is offstage and never renders
              // a second navigation bar or handles input.
              SizedBox(
                width: 0,
                height: 0,
                child: IgnorePointer(
                  child: BottomNavigationBar(
                    currentIndex: currentIndex,
                    onTap: onTap,
                    items: [
                      for (var i = 0; i < labels.length; i++)
                        BottomNavigationBarItem(
                          icon: const SizedBox.shrink(),
                          label: '',
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AbundanceNavigationItem extends StatelessWidget {
  const _AbundanceNavigationItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = active ? AbundanceColors.primaryGold : AbundanceColors.muted;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Transform.translate(
              offset: Offset(0, active ? -5 : 0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                width: active ? 32 : 26,
                height: active ? 32 : 26,
                decoration: BoxDecoration(
                  color:
                      active ? AbundanceColors.primaryGold : Colors.transparent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: active
                          ? AbundanceColors.primaryGold.withValues(alpha: .3)
                          : Colors.transparent,
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  size: active ? 21 : 20,
                  color: active ? Colors.black : tint,
                ),
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                color: tint,
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              ),
              child: Text(label, maxLines: 1, overflow: TextOverflow.clip),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}
