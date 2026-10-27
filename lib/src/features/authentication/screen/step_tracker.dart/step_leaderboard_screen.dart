import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/walker_avatar.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_certificate_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_detail_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_list_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_theme.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';
import 'package:selfcare_projects/src/services/leaderboard_api_service.dart';
import 'package:selfcare_projects/src/services/marathon_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef StepLeaderboardLoader = Future<StepLeaderboardSnapshot> Function(
  StepLeaderboardPeriod period,
);

typedef WalkerLookSaver = Future<void> Function(Map<String, dynamic> look);

/// Company step race: the viewer walks through a scene chasing the
/// colleague just ahead of them, with a race bar of every member below and
/// their daily finishing places for the week on top. Overtakes since the
/// last visit are celebrated, and the walker is a customizable character
/// whose accessories unlock from placements.
class StepLeaderboardScreen extends StatefulWidget {
  const StepLeaderboardScreen({
    super.key,
    this.loader,
    this.currentUserId,
    this.clock,
    this.lookSaver,
    this.marathonApi,
    this.initialMarathonId,
  });

  /// Overridable for tests; defaults to the marathon API.
  final MarathonApiService? marathonApi;

  /// Opens straight onto this marathon's race instead of the company race.
  final String? initialMarathonId;

  /// Overridable for tests; defaults to the leaderboard API.
  final StepLeaderboardLoader? loader;

  /// Overridable for tests; defaults to saving through the API.
  final WalkerLookSaver? lookSaver;
  final String? currentUserId;

  /// Overridable for tests; drives the countdown and the sky.
  final DateTime Function()? clock;

  @override
  State<StepLeaderboardScreen> createState() => _StepLeaderboardScreenState();
}

class _RacePalette {
  static const background = Color(0xFF12122A);
  static const card = Color(0xFF1E1E3F);
  static const cardBorder = Color(0xFF2E2E5A);
  static const muted = Color(0xFF9A9AC8);
  static const accent = Color(0xFFFF8A3D);
  static const gold = Color(0xFFFFC93C);
  static const silver = Color(0xFFC9D3E0);
  static const bronze = Color(0xFFD98A4E);
  static const placed = Color(0xFF5B6CFF);
  static const go = Color(0xFF3DDC84);
  static const hurry = Color(0xFFFF5A5A);

  static Color forRank(int? rank) => switch (rank) {
        1 => gold,
        2 => silver,
        3 => bronze,
        null => cardBorder,
        _ => placed,
      };
}

TextStyle _display(double size, {Color color = Colors.white}) =>
    GoogleFonts.lilitaOne(fontSize: size, color: color, height: 1.1);

TextStyle _body(double size,
        {Color color = Colors.white, FontWeight weight = FontWeight.w600}) =>
    GoogleFonts.fredoka(fontSize: size, color: color, fontWeight: weight);

String _ordinal(int rank) {
  final mod100 = rank % 100;
  if (mod100 >= 11 && mod100 <= 13) return '${rank}th';
  return switch (rank % 10) {
    1 => '${rank}st',
    2 => '${rank}nd',
    3 => '${rank}rd',
    _ => '${rank}th',
  };
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Consecutive days with steps, ending today (or yesterday while today's
/// steps are still zero).
int _walkStreak(List<StepDayPlacement> placements, DateTime now) {
  final stepsByDay = {
    for (final p in placements) _dateOnly(p.date): p.steps,
  };
  var day = _dateOnly(now);
  if ((stepsByDay[day] ?? 0) <= 0) {
    day = day.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while ((stepsByDay[day] ?? 0) > 0) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Accessories earned in the race; everything else is free to pick.
class _AccessoryRule {
  const _AccessoryRule(this.requirement, this.isUnlocked);

  final String requirement;
  final bool Function(List<StepDayPlacement> week, int streak) isUnlocked;

  static final rules = <WalkerAccessory, _AccessoryRule>{
    WalkerAccessory.cap: _AccessoryRule(
      'Walk 2 days in a row',
      (_, streak) => streak >= 2,
    ),
    WalkerAccessory.headphones: _AccessoryRule(
      'Finish top 3 in a daily race',
      (week, _) => week.any((p) => (p.rank ?? 99) <= 3),
    ),
    WalkerAccessory.crown: _AccessoryRule(
      'Win a daily race',
      (week, _) => week.any((p) => p.rank == 1),
    ),
  };

  /// The requirement still to meet for [accessory], or null if available.
  static String? lockReason(
    WalkerAccessory accessory,
    List<StepDayPlacement> week,
    int streak,
  ) {
    final rule = rules[accessory];
    if (rule == null || rule.isUnlocked(week, streak)) return null;
    return rule.requirement;
  }
}

const _milestones = [
  2000,
  5000,
  8000,
  10000,
  12000,
  15000,
  20000,
  25000,
  30000
];

/// The next daily milestone above [steps] and the one before it.
(int previous, int next) _milestoneRange(int steps) {
  var previous = 0;
  for (final milestone in _milestones) {
    if (steps < milestone) return (previous, milestone);
    previous = milestone;
  }
  final next = (steps ~/ 5000 + 1) * 5000;
  return (next - 5000, next);
}

String _shortSteps(int steps) => steps % 1000 == 0
    ? '${steps ~/ 1000}K'
    : NumberFormat.compact().format(steps);

class _StepLeaderboardScreenState extends State<StepLeaderboardScreen>
    with TickerProviderStateMixin {
  static const Map<StepLeaderboardPeriod, String> _periodLabels = {
    StepLeaderboardPeriod.today: 'Today',
    StepLeaderboardPeriod.week: 'This Week',
    StepLeaderboardPeriod.month: 'This Month',
    StepLeaderboardPeriod.all: 'All Time',
  };
  static const _lookKey = 'step_race_look';
  static const _legacySkinKey = 'step_race_skin';

  final NumberFormat _stepsFormat = NumberFormat.decimalPattern();
  StepLeaderboardPeriod _period = StepLeaderboardPeriod.today;
  late Future<StepLeaderboardSnapshot> _future;
  Timer? _ticker;
  Timer? _bannerTimer;
  DateTime _now = DateTime.now();
  WalkerLook _look = const WalkerLook();
  String? _banner;

  /// One stride of the walking cycle.
  late final AnimationController _stride = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  /// Slow scroll of the hills behind the walker.
  late final AnimationController _scenery = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 16),
  )..repeat();

  late final AnimationController _confetti = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );

  String? get _currentUserId =>
      widget.currentUserId ??
      AuthService.instance.currentSession?.id.toString();

  DateTime _clock() => (widget.clock ?? DateTime.now)();

  /// Marathons that can be picked in the race menu.
  List<Marathon> _marathons = [];

  /// The marathon being shown, or null for the company steps race.
  String? _marathonId;
  Future<MarathonRace>? _raceFuture;
  StepLeaderboardSnapshot? _lastSnapshot;

  MarathonApiService get _marathonApi =>
      widget.marathonApi ?? MarathonApiService.instance;

  Future<void> _loadMarathons() async {
    try {
      final marathons = await _marathonApi.fetchMarathons();
      if (!mounted) return;
      setState(() => _marathons = marathons
          .where(
              (m) => m.phase != MarathonPhase.ended || m.myRegistration != null)
          .toList());
    } catch (error) {
      debugPrint('Could not load marathons: $error');
    }
  }

  void _selectMarathon(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      _marathonId = id;
      _raceFuture = _marathonApi.fetchRace(id);
    });
  }

  Future<void> _openMarathonPage(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (!mounted) return;
    // The user may have joined, paid or put on a marathon kit.
    unawaited(_restoreLook());
    unawaited(_loadMarathons());
    final id = _marathonId;
    if (id != null) setState(() => _raceFuture = _marathonApi.fetchRace(id));
  }

  @override
  void initState() {
    super.initState();
    _now = _clock();
    _future = _load();
    // Loaded in the background while a marathon is shown; its error state
    // only matters once the company race is on screen.
    _future.ignore();
    _marathonId = widget.initialMarathonId;
    if (_marathonId != null) _raceFuture = _marathonApi.fetchRace(_marathonId!);
    _loadMarathons();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = _clock());
    });
    _restoredLook = _restoreLook();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _bannerTimer?.cancel();
    _stride.dispose();
    _scenery.dispose();
    _confetti.dispose();
    super.dispose();
  }

  /// Whether this phone has a look the user designed (or an old outfit
  /// pick), as opposed to the default.
  bool _hasLocalLook = false;
  Future<void> _restoredLook = Future.value();
  bool _lookSyncedThisSession = false;

  Future<void> _restoreLook() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_lookKey);
      final legacy = prefs.getString(_legacySkinKey);
      final look = saved != null
          ? WalkerLook.fromJson(saved)
          : WalkerLook.fromLegacySkin(legacy);
      _hasLocalLook = saved != null || legacy != null;
      if (mounted) setState(() => _look = look);
    } catch (_) {
      // Keep the default look.
    }
  }

  Future<void> _storeLookLocally(WalkerLook look) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lookKey, look.toJson());
      _hasLocalLook = true;
    } catch (_) {
      // The look still applies for this session.
    }
  }

  Future<bool> _uploadLook(WalkerLook look) async {
    try {
      final saver =
          widget.lookSaver ?? LeaderboardApiService.instance.saveWalkerLook;
      await saver(look.toMap());
      return true;
    } catch (error) {
      debugPrint('Could not save walker look: $error');
      return false;
    }
  }

  Future<void> _saveLook(WalkerLook look) async {
    setState(() => _look = look);
    await _storeLookLocally(look);
    final uploaded = await _uploadLook(look);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(
        uploaded
            ? 'Walker saved. Your team will see it in the race.'
            : "Saved on this phone. We couldn't share it with your team yet.",
      ),
    ));
  }

  /// The server copy wins (so a new phone gets the user's walker); a look
  /// that only exists on this phone is uploaded once.
  Future<void> _syncLook(StepLeaderboardSnapshot data) async {
    if (_lookSyncedThisSession) return;
    final meId = _currentUserId;
    final me = data.entries.where((e) => e.userId == meId).firstOrNull;
    if (me == null) return;
    _lookSyncedThisSession = true;

    final remote = me.walkerLook;
    if (remote != null) {
      final look = WalkerLook.fromMap(remote);
      if (look != _look) {
        if (mounted) setState(() => _look = look);
        await _storeLookLocally(look);
      }
    } else if (_hasLocalLook) {
      await _uploadLook(_look);
    }
  }

  Future<StepLeaderboardSnapshot> _load() {
    final loader = widget.loader;
    final period = _period;
    final future = loader != null
        ? loader(period)
        : LeaderboardApiService.instance.fetchStepLeaderboard(period: period);
    return future.then((data) {
      _lastSnapshot = data;
      _celebrateProgress(data, period);
      unawaited(_restoredLook.then((_) => _syncLook(data)));
      return data;
    });
  }

  /// Compares the viewer's place with what they saw last time in this race
  /// and celebrates anyone they've overtaken since.
  Future<void> _celebrateProgress(
    StepLeaderboardSnapshot data,
    StepLeaderboardPeriod period,
  ) async {
    final meId = _currentUserId;
    final myIndex = data.entries.indexWhere((e) => e.userId == meId);
    if (myIndex < 0) return;
    final me = data.entries[myIndex];
    final ahead = data.entries.take(myIndex).map((e) => e.userId).toList();
    final start = data.startDate;
    final raceKey = start == null
        ? period.name
        : '${period.name}_${DateFormat('yyyy-MM-dd').format(start)}';

    List<String>? previousAhead;
    int? previousRank;
    try {
      final prefs = await SharedPreferences.getInstance();
      previousAhead = prefs.getStringList('step_race_ahead_$raceKey');
      previousRank = prefs.getInt('step_race_rank_$raceKey');
      await prefs.setStringList('step_race_ahead_$raceKey', ahead);
      await prefs.setInt('step_race_rank_$raceKey', me.rank);
    } catch (_) {
      return;
    }
    if (previousAhead == null || previousRank == null) return;
    if (me.rank >= previousRank || me.totalSteps <= 0) return;

    final passed = data.entries
        .where((e) =>
            previousAhead!.contains(e.userId) && !ahead.contains(e.userId))
        .map((e) => e.name.split(' ').first)
        .toList();
    final String message;
    if (me.rank == 1) {
      message = 'You took the lead! 👑';
    } else if (passed.length == 1) {
      message = 'You passed ${passed.first}! 🎉';
    } else if (passed.length == 2) {
      message = 'You passed ${passed[0]} & ${passed[1]}! 🎉';
    } else {
      message = 'You moved up to ${_ordinal(me.rank)}! 🎉';
    }
    _celebrate(message);
  }

  void _celebrate(String message) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _banner = message);
    _confetti.forward(from: 0);
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  Future<void> _refresh() async {
    final marathonId = _marathonId;
    if (marathonId != null) {
      final race = _marathonApi.fetchRace(marathonId);
      setState(() => _raceFuture = race);
      try {
        await race;
      } catch (_) {
        // Shown by the FutureBuilder.
      }
      return;
    }
    final future = _load();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // Error state is rendered by the FutureBuilder.
    }
  }

  void _selectPeriod(StepLeaderboardPeriod period) {
    if (period == _period && _marathonId == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      _marathonId = null;
      _raceFuture = null;
      _period = period;
      _future = _load();
    });
  }

  /// When the current race ends, or null for the all-time race.
  DateTime? _finishLine() {
    final today = _dateOnly(_now);
    return switch (_period) {
      StepLeaderboardPeriod.today => today.add(const Duration(days: 1)),
      StepLeaderboardPeriod.week =>
        today.add(Duration(days: 8 - today.weekday)),
      StepLeaderboardPeriod.month => DateTime(_now.year, _now.month + 1),
      StepLeaderboardPeriod.all => null,
    };
  }

  Duration? _timeLeft() {
    final finish = _finishLine();
    if (finish == null) return null;
    final left = finish.difference(_now);
    return left.isNegative ? Duration.zero : left;
  }

  String _countdown(Duration? left) {
    if (left == null) return 'All-time race';
    final days = left.inDays;
    final hh = (left.inHours % 24).toString().padLeft(2, '0');
    final mm = (left.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (left.inSeconds % 60).toString().padLeft(2, '0');
    return days > 0
        ? 'Finishes in ${days}d $hh:$mm:$ss'
        : 'Finishes in $hh:$mm:$ss';
  }

  /// The saved look, minus an accessory that is no longer earned this week.
  WalkerLook _effectiveLook(List<StepDayPlacement> week, int streak) {
    final locked = _AccessoryRule.lockReason(_look.accessory, week, streak);
    return locked == null
        ? _look
        : _look.copyWith(accessory: WalkerAccessory.none);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _RacePalette.background,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: _marathonId != null
                ? _buildMarathonMode()
                : FutureBuilder<StepLeaderboardSnapshot>(
                    future: _future,
                    builder: (context, snapshot) {
                      final loading =
                          snapshot.connectionState != ConnectionState.done;
                      final data = snapshot.data;
                      return Column(
                        children: [
                          _buildTopBar(data?.companyTotalSteps),
                          Expanded(
                            child: loading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                      color: _RacePalette.accent,
                                    ),
                                  )
                                : snapshot.hasError || data == null
                                    ? _buildError()
                                    : RefreshIndicator(
                                        color: _RacePalette.accent,
                                        onRefresh: _refresh,
                                        child: _buildRace(data),
                                      ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confetti,
                builder: (context, _) => _confetti.isAnimating
                    ? CustomPaint(
                        painter: _ConfettiPainter(progress: _confetti.value),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(int? teamSteps, {MarathonTheme? marathonTheme}) {
    final selectedMarathon =
        _marathons.where((m) => m.id == _marathonId).firstOrNull;
    final label = _marathonId == null
        ? _periodLabels[_period]!
        : '🏅 ${selectedMarathon?.title ?? 'Marathon'}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            tooltip: 'Back',
          ),
          Expanded(
            child: Center(
              child: PopupMenuButton<Object>(
                key: const ValueKey('race-menu'),
                color: _RacePalette.card,
                onSelected: (choice) {
                  if (choice is StepLeaderboardPeriod) {
                    _selectPeriod(choice);
                  } else if (choice is Marathon) {
                    _selectMarathon(choice.id);
                  } else if (choice == 'browse') {
                    _openMarathonPage(MarathonListScreen(
                      api: widget.marathonApi,
                      today: widget.clock?.call(),
                    ));
                  }
                },
                itemBuilder: (context) => [
                  for (final entry in _periodLabels.entries)
                    PopupMenuItem<Object>(
                      value: entry.key,
                      child: Text(entry.value, style: _body(15)),
                    ),
                  const PopupMenuDivider(),
                  for (final marathon in _marathons)
                    PopupMenuItem<Object>(
                      value: marathon,
                      child: Text(
                        '${MarathonTheme.of(marathon.theme).emoji} ${marathon.title}',
                        style: _body(15),
                      ),
                    ),
                  PopupMenuItem<Object>(
                    value: 'browse',
                    child: Text('🏅 Browse all marathons',
                        style: _body(15, color: _RacePalette.gold)),
                  ),
                ],
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: _RacePalette.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: marathonTheme?.accent ?? _RacePalette.cardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _body(15),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_marathonId == null)
            Tooltip(
              message: 'Team steps',
              child: Row(
                children: [
                  const Icon(Icons.directions_walk_rounded,
                      color: _RacePalette.gold, size: 20),
                  const SizedBox(width: 2),
                  Text(
                    teamSteps == null
                        ? '--'
                        : NumberFormat.compact().format(teamSteps),
                    style: _display(18),
                  ),
                ],
              ),
            )
          else
            Text(marathonTheme?.emoji ?? '🏅',
                style: const TextStyle(fontSize: 22)),
        ],
      ),
    );
  }

  Widget _buildError(
      [String message = 'Unable to load the steps leaderboard.']) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: _RacePalette.muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: _body(15, color: _RacePalette.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _RacePalette.accent,
              ),
              onPressed: _refresh,
              child: Text('Retry', style: _body(15)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarathonMode() {
    return FutureBuilder<MarathonRace>(
      future: _raceFuture,
      builder: (context, snapshot) {
        final race = snapshot.data;
        final theme =
            race == null ? null : MarathonTheme.of(race.marathon.theme);
        return Column(
          children: [
            _buildTopBar(null, marathonTheme: theme),
            Expanded(
              child: snapshot.connectionState != ConnectionState.done
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: _RacePalette.accent),
                    )
                  : snapshot.hasError || race == null
                      ? _buildError('Unable to load the marathon.')
                      : RefreshIndicator(
                          color: _RacePalette.accent,
                          onRefresh: _refresh,
                          child: _buildMarathonRace(race),
                        ),
            ),
          ],
        );
      },
    );
  }

  /// A marathon shown as a real race: runners walk the track by distance,
  /// the finish line is the marathon distance, and markers are in km.
  Widget _buildMarathonRace(MarathonRace race) {
    final marathon = race.marathon;
    final theme = MarathonTheme.of(marathon.theme);
    final kmById = {for (final r in race.runners) r.userId: r.km};
    final finishedIds = {
      for (final r in race.runners)
        if (r.finished) r.userId
    };
    final entries = [
      for (final r in race.runners)
        StepLeaderboardEntry(
          userId: r.userId,
          name: r.name,
          totalSteps: r.steps,
          daysTracked: 0,
          rank: r.rank,
          profilePic: r.profilePic,
          walkerLook: r.walkerLook,
        ),
    ];
    String km(double value) => '${value.toStringAsFixed(1)} km';
    final myIndex = entries.indexWhere((e) => e.userId == _currentUserId);
    final me = myIndex >= 0 ? entries[myIndex] : null;
    final ahead = myIndex > 0 ? entries[myIndex - 1] : null;
    final myKm = me == null ? 0.0 : kmById[me.userId] ?? 0;
    final distance = marathon.distanceKm <= 0 ? 1.0 : marathon.distanceKm;

    String? aheadLabel;
    if (ahead != null) {
      aheadLabel = finishedIds.contains(ahead.userId)
          ? '🏁 Finished'
          : 'in ${km(((kmById[ahead.userId] ?? 0) - myKm).clamp(0.1, distance))}';
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildMarathonHero(marathon, theme, myKm),
        const SizedBox(height: 8),
        _RaceScene(
          key: ValueKey('marathon-${marathon.id}'),
          entries: entries,
          me: me,
          ahead: ahead,
          aheadLabel: aheadLabel,
          leadLabel: myIndex == 0 && entries.length > 1
              ? '+${km(myKm - (kmById[entries[1].userId] ?? 0))} ahead'
              : null,
          shareOf: (entry) => (kmById[entry.userId] ?? 0) / distance,
          valueText: (entry) => finishedIds.contains(entry.userId)
              ? '🏁 ${km(distance)}'
              : km(kmById[entry.userId] ?? 0),
          valueUnit: '',
          markers: [
            for (final share in const [0.25, 0.5, 0.75])
              (share, '${formatKm(distance * share)} km'),
          ],
          stride: _stride,
          scenery: _scenery,
          sky: _SkyMode.at(_now),
          look: _look,
          banner: _banner,
          onCustomize: () => _openCustomizer(
            _lastSnapshot?.weekPlacements ?? const [],
            _walkStreak(_lastSnapshot?.weekPlacements ?? const [], _now),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Runners', style: _display(20)),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No runners yet. Be the first to join!',
                style: _body(15, color: _RacePalette.muted),
              ),
            ),
          )
        else
          for (final r in race.runners)
            _MarathonRunnerRow(
              runner: r,
              isMe: r.userId == _currentUserId,
              distanceKm: distance,
            ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            '🏅 Finishers receive a finisher shirt, medal and certificate, '
            'plus a virtual certificate.',
            textAlign: TextAlign.center,
            style: _body(13, color: _RacePalette.muted),
          ),
        ),
      ],
    );
  }

  Widget _buildMarathonHero(
    Marathon marathon,
    MarathonTheme theme,
    double myKm,
  ) {
    final registration = marathon.myRegistration;
    final dateFormat = DateFormat('EEE, MMM d');
    final today = DateTime(_now.year, _now.month, _now.day);
    final String timing;
    switch (marathon.phase) {
      case MarathonPhase.upcoming:
        final days = marathon.startsAt.difference(today).inDays;
        timing = 'Opens ${days <= 1 ? 'tomorrow' : 'in $days days'} · '
            '${dateFormat.format(marathon.startsAt)}';
      case MarathonPhase.ongoing:
        final end = marathon.endsAt.add(const Duration(days: 1));
        timing = _countdown(end.difference(_now).isNegative
            ? Duration.zero
            : end.difference(_now));
      case MarathonPhase.ended:
        timing = 'Race finished';
    }

    Widget action(String label, VoidCallback onTap) => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: theme.gradient.last,
          ),
          onPressed: onTap,
          child: Text(label, style: _body(14, color: theme.gradient.last)),
        );
    void openDetails() => _openMarathonPage(MarathonDetailScreen(
          marathonId: marathon.id,
          initial: marathon,
          api: widget.marathonApi,
          today: widget.clock?.call(),
        ));

    final confirmed = registration?.isConfirmed == true;
    final String status;
    Widget? primary;
    if (registration == null) {
      status = marathon.phase == MarathonPhase.ended
          ? 'This marathon has ended.'
          : '${formatKm(marathon.distanceKm)} km · ${formatPrice(marathon)} · '
              'finisher shirt, medal & certificate';
      if (marathon.phase != MarathonPhase.ended) {
        primary = action('Join this marathon', openDetails);
      }
    } else if (confirmed) {
      status = registration.isFinisher
          ? '🏅 You finished! Bib #${registration.bibNumber}'
          : 'Bib #${registration.bibNumber}';
      if (registration.isFinisher) {
        primary = action(
          'View certificate',
          () => _openMarathonPage(MarathonCertificateScreen(
            marathonId: marathon.id,
            api: widget.marathonApi,
          )),
        );
      }
    } else {
      status = myStatusLabel(registration) ?? '';
      if (registration.status != MarathonRegistrationStatus.paymentSubmitted) {
        primary = action('Complete payment', openDetails);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.gradient,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(theme.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(marathon.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _display(20)),
              ),
              TextButton(
                onPressed: openDetails,
                child: Text('Details', style: _body(13)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (confirmed)
            Text(
              '${myKm.toStringAsFixed(1)} / ${formatKm(marathon.distanceKm)} km',
              style: _display(40),
            ),
          Text(timing, style: _body(14)),
          const SizedBox(height: 4),
          Text(status, style: _body(13, color: Colors.white70)),
          if (primary != null) ...[
            const SizedBox(height: 10),
            primary,
          ],
        ],
      ),
    );
  }

  Widget _buildRace(StepLeaderboardSnapshot data) {
    final entries = data.entries;
    final myIndex =
        entries.indexWhere((entry) => entry.userId == _currentUserId);
    final me = myIndex >= 0 ? entries[myIndex] : null;
    final ahead = myIndex > 0 ? entries[myIndex - 1] : null;
    final streak = _walkStreak(data.weekPlacements, _now);
    final look = _effectiveLook(data.weekPlacements, streak);
    final leaderSteps = entries.isEmpty ? 0 : entries.first.totalSteps;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _WeekStrip(placements: data.weekPlacements, today: _now),
        const SizedBox(height: 14),
        _buildHero(data, me, streak),
        const SizedBox(height: 8),
        _RaceScene(
          // Re-centre on the viewer whenever the race changes.
          key: ValueKey('race-${_period.name}'),
          entries: entries,
          me: me,
          ahead: ahead,
          aheadLabel: ahead == null || me == null
              ? null
              : 'in ${_stepsFormat.format(ahead.totalSteps - me.totalSteps + 1)}',
          leadLabel: myIndex == 0 && entries.length > 1
              ? '+${_stepsFormat.format(me!.totalSteps - entries[1].totalSteps)} ahead'
              : null,
          // The leader walks nearest the finish.
          shareOf: (entry) =>
              leaderSteps <= 0 ? 0 : entry.totalSteps / leaderSteps,
          valueText: (entry) => _stepsFormat.format(entry.totalSteps),
          markers: [
            if (leaderSteps > 0)
              for (final share in const [0.25, 0.5, 0.75])
                (
                  share,
                  NumberFormat.compact().format((leaderSteps * share).round()),
                ),
          ],
          stride: _stride,
          scenery: _scenery,
          sky: _SkyMode.at(_now),
          look: look,
          banner: _banner,
          onCustomize: () => _openCustomizer(data.weekPlacements, streak),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _RaceBar(entries: entries, meId: _currentUserId),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Standings', style: _display(20)),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No steps yet. Be the first on the track!',
                style: _body(15, color: _RacePalette.muted),
              ),
            ),
          )
        else
          ...entries.map((entry) => _StandingRow(
                entry: entry,
                isMe: entry.userId == _currentUserId,
                steps: _stepsFormat.format(entry.totalSteps),
              )),
      ],
    );
  }

  Widget _buildHero(
    StepLeaderboardSnapshot data,
    StepLeaderboardEntry? me,
    int streak,
  ) {
    final steps = me?.totalSteps ?? 0;
    final company = data.companyName ?? 'your company';
    final left = _timeLeft();
    final hurry = left != null && left < const Duration(hours: 1);

    return Column(
      children: [
        TweenAnimationBuilder<double>(
          key: ValueKey('${_period.name}-$steps'),
          tween: Tween(begin: 0, end: steps.toDouble()),
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => Text(
            _stepsFormat.format(value.round()),
            style: _display(56),
          ),
        ),
        const SizedBox(height: 4),
        AnimatedBuilder(
          animation: _stride,
          builder: (context, child) => Transform.scale(
            scale: hurry ? 1 + 0.05 * math.sin(_stride.value * 2 * math.pi) : 1,
            child: child,
          ),
          child: Text(
            hurry ? '⏰ ${_countdown(left)}' : _countdown(left),
            style: _body(15, color: hurry ? _RacePalette.hurry : Colors.white),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (me != null)
              _Chip(
                text:
                    '${_ordinal(me.rank)} of ${data.entries.length} in $company',
              ),
            if (streak >= 2)
              _Chip(
                text: '🔥 $streak-day streak',
                color: _RacePalette.accent.withValues(alpha: 0.2),
                textColor: _RacePalette.accent,
              ),
          ],
        ),
        if (_period == StepLeaderboardPeriod.today) ...[
          const SizedBox(height: 12),
          _MilestoneBar(steps: steps, format: _stepsFormat),
        ],
      ],
    );
  }

  Future<void> _openCustomizer(List<StepDayPlacement> week, int streak) async {
    HapticFeedback.selectionClick();
    final look = await showModalBottomSheet<WalkerLook>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _RacePalette.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _WalkerCustomizer(
        initial: _effectiveLook(week, streak),
        lockReason: (accessory) =>
            _AccessoryRule.lockReason(accessory, week, streak),
      ),
    );
    if (look != null) await _saveLook(look);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    this.color = _RacePalette.card,
    this.textColor = _RacePalette.muted,
  });

  final String text;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text, style: _body(13, color: textColor)),
    );
  }
}

/// Progress toward the next daily step badge.
class _MilestoneBar extends StatelessWidget {
  const _MilestoneBar({required this.steps, required this.format});

  final int steps;
  final NumberFormat format;

  @override
  Widget build(BuildContext context) {
    final (previous, next) = _milestoneRange(steps);
    final progress = (steps - previous) / (next - previous);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Row(
            children: [
              const Text('🏅', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${format.format(next - steps)} steps to the '
                  '${_shortSteps(next)} badge',
                  style: _body(13, color: _RacePalette.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: _RacePalette.card,
                color: _RacePalette.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mon..Sun badges with the viewer's finishing place in each daily race.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.placements, required this.today});

  final List<StepDayPlacement> placements;
  final DateTime today;

  static const _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final todayDate = _dateOnly(today);
    final monday = todayDate.subtract(Duration(days: todayDate.weekday - 1));
    final byDay = {for (final p in placements) _dateOnly(p.date): p};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: List.generate(7, (i) {
          final day = monday.add(Duration(days: i));
          final isToday = day == todayDate;
          return Expanded(
            child: Column(
              children: [
                Text(
                  _letters[i],
                  style: _body(12,
                      color: isToday ? Colors.white : _RacePalette.muted),
                ),
                const SizedBox(height: 6),
                _DayBadge(
                  rank: byDay[day]?.rank,
                  isToday: isToday,
                  isFuture: day.isAfter(todayDate),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _DayBadge extends StatelessWidget {
  const _DayBadge({
    required this.rank,
    required this.isToday,
    required this.isFuture,
  });

  final int? rank;
  final bool isToday;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final rank = this.rank;
    final color = _RacePalette.forRank(rank);
    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isToday ? _RacePalette.go : Colors.transparent,
          width: 2.5,
        ),
      ),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: rank == null
              ? _RacePalette.card.withValues(alpha: isFuture ? 0.5 : 1)
              : color,
          gradient: rank == null
              ? null
              : RadialGradient(
                  colors: [Color.lerp(color, Colors.white, 0.35)!, color],
                ),
        ),
        child: rank == null
            ? null
            : Text(
                _ordinal(rank),
                style: _display(12, color: const Color(0xFF2A1A00)),
              ),
      ),
    );
  }
}

enum _SkyMode {
  day,
  dusk,
  night;

  static _SkyMode at(DateTime now) {
    final hour = now.hour;
    if (hour >= 6 && hour < 17) return _SkyMode.day;
    if (hour >= 17 && hour < 19) return _SkyMode.dusk;
    return _SkyMode.night;
  }
}

/// A side-scrolling race: every racer walks along the track at a spot set
/// by [shareOf] (0 at the start, 1 at the finish). Used for the company's
/// steps race and for marathons. Swipe to see everyone; it opens centred
/// on the viewer.
class _RaceScene extends StatefulWidget {
  const _RaceScene({
    super.key,
    required this.entries,
    required this.me,
    required this.ahead,
    required this.aheadLabel,
    required this.leadLabel,
    required this.shareOf,
    required this.valueText,
    required this.markers,
    this.valueUnit = ' steps',
    required this.stride,
    required this.scenery,
    required this.sky,
    required this.look,
    required this.banner,
    required this.onCustomize,
  });

  final List<StepLeaderboardEntry> entries;
  final StepLeaderboardEntry? me;
  final StepLeaderboardEntry? ahead;

  /// Shown above [ahead], e.g. "in 1,501".
  final String? aheadLabel;

  /// Shown under the viewer when they lead, e.g. "+4,000 ahead".
  final String? leadLabel;
  final double Function(StepLeaderboardEntry entry) shareOf;
  final String Function(StepLeaderboardEntry entry) valueText;

  /// Appended to [valueText] in a racer's tooltip.
  final String valueUnit;

  /// Signposts along the track as (share, label).
  final List<(double, String)> markers;
  final Animation<double> stride;
  final Animation<double> scenery;
  final _SkyMode sky;
  final WalkerLook look;
  final String? banner;
  final VoidCallback onCustomize;

  static const double sceneHeight = 330;

  @override
  State<_RaceScene> createState() => _RaceSceneState();
}

/// One walker's spot on the track. Lanes give depth: 0 is farthest back
/// (smaller, higher), 2 is the front.
class _TrackSpot {
  _TrackSpot(this.entry, this.x, this.lane);

  final StepLeaderboardEntry? entry;
  double x;
  int lane;
}

class _RaceSceneState extends State<_RaceScene> {
  final ScrollController _scroll = ScrollController();
  bool _hasPanned = false;
  bool _viewerOnScreen = true;
  double? _viewerX;

  static const _laneScale = [0.62, 0.78, 0.95];
  static const _laneFeet = [0.79, 0.845, 0.9];
  static const double _minGap = 64;
  static const double _baseHeight = 160;
  static const double _startX = 110;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _centreOnViewer(false));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final viewerX = _viewerX;
    if (!_scroll.hasClients || viewerX == null) return;
    final position = _scroll.position;
    final onScreen = viewerX > position.pixels &&
        viewerX < position.pixels + position.viewportDimension;
    final panned = _hasPanned || position.userScrollDirection.name != 'idle';
    if (onScreen != _viewerOnScreen || panned != _hasPanned) {
      setState(() {
        _viewerOnScreen = onScreen;
        _hasPanned = panned;
      });
    }
  }

  void _centreOnViewer(bool animate) {
    final viewerX = _viewerX;
    if (!mounted || !_scroll.hasClients || viewerX == null) return;
    final position = _scroll.position;
    final target = (viewerX - position.viewportDimension * 0.4)
        .clamp(0.0, position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic);
    } else {
      _scroll.jumpTo(target);
    }
  }

  static int _stableHash(String value) {
    var hash = 7;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }

  /// Other racers get a look generated from their id, so each person
  /// always looks the same; the leader wears the crown.
  /// Another racer's walker: the one they designed, or one generated from
  /// their id so they always look the same. Only the current leader wears
  /// the crown.
  WalkerLook _lookFor(StepLeaderboardEntry entry) {
    final saved = entry.walkerLook;
    final look = saved != null
        ? WalkerLook.fromMap(saved)
        : WalkerLook.random(
            math.Random(_stableHash(entry.userId)),
            allowedAccessories: const [
              WalkerAccessory.none,
              WalkerAccessory.backpack,
            ],
          );
    final isLeader = entry.rank == 1 && entry.totalSteps > 0;
    if (isLeader) return look.copyWith(accessory: WalkerAccessory.crown);
    return look.accessory == WalkerAccessory.crown
        ? look.copyWith(accessory: WalkerAccessory.none)
        : look;
  }

  /// Places everyone in step order, at least [_minGap] apart so close
  /// racers stay visible (the track stretches as needed), alternating the
  /// back lanes. The viewer always walks in the front lane.
  List<_TrackSpot> _layout(double trackLength) {
    final entries = widget.entries;
    final me = widget.me;
    double rawX(StepLeaderboardEntry entry) =>
        _startX + widget.shareOf(entry).clamp(0.0, 1.0) * trackLength;

    if (entries.isEmpty) {
      return [_TrackSpot(me, _startX, 2)];
    }

    // Furthest along last; ties keep the ranking order.
    final ordered = [...entries]..sort((a, b) => b.rank.compareTo(a.rank));
    final spots = <_TrackSpot>[];
    var previousX = double.negativeInfinity;
    var backLane = 1;
    for (final entry in ordered) {
      final x = math.max(rawX(entry), previousX + _minGap);
      final isViewer = entry.userId == me?.userId;
      int lane;
      if (isViewer) {
        lane = 2;
      } else {
        lane = backLane;
        backLane = backLane == 1 ? 0 : 1;
      }
      spots.add(_TrackSpot(entry, x, lane));
      previousX = x;
    }

    // Racers well clear of everyone can step up to the front lane.
    for (var i = 0; i < spots.length; i++) {
      final spot = spots[i];
      if (spot.lane == 2) continue;
      final clearBefore = i == 0 || spot.x - spots[i - 1].x > _minGap * 2;
      final clearAfter =
          i == spots.length - 1 || spots[i + 1].x - spot.x > _minGap * 2;
      if (clearBefore && clearAfter) spot.lane = 2;
    }

    final viewerIndex = spots.indexWhere((s) => s.entry?.userId == me?.userId);
    if (viewerIndex < 0) return [_TrackSpot(null, _startX, 2), ...spots];
    // The viewer goes first; build() relies on that.
    return [spots.removeAt(viewerIndex), ...spots];
  }

  @override
  Widget build(BuildContext context) {
    const h = _RaceScene.sceneHeight;
    final banner = widget.banner;

    return SizedBox(
      height: h,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.maxWidth;
          final trackLength =
              math.max(viewport * 1.6, widget.entries.length * 80.0);
          final spots = _layout(trackLength);
          _viewerX = spots.first.x;
          final furthest = spots.map((s) => s.x).fold<double>(0, math.max);
          final hideViewer =
              spots.first.entry == null && widget.entries.isNotEmpty;
          final ordered = [
            ...spots.skip(1),
            if (!hideViewer) spots.first,
          ]..sort((a, b) => a.lane != b.lane
              ? a.lane.compareTo(b.lane)
              : identical(a, spots.first)
                  ? 1
                  : identical(b, spots.first)
                      ? -1
                      : a.x.compareTo(b.x));

          final finishX = math.max(_startX + trackLength, furthest) + 80;
          final worldWidth = finishX + 110;

          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: Listenable.merge([widget.scenery, _scroll]),
                  builder: (context, _) => CustomPaint(
                    painter: _ScenePainter(
                      scroll: widget.scenery.value,
                      sky: widget.sky,
                      pan: _scroll.hasClients ? _scroll.offset : 0,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: SingleChildScrollView(
                  key: const ValueKey('race-track'),
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: SizedBox(
                    width: worldWidth,
                    height: h,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _trackMarker(_startX, 'START'),
                        for (final (share, label) in widget.markers)
                          _trackMarker(_startX + trackLength * share, label),
                        Positioned(
                          left: finishX - 9,
                          top: h * 0.5,
                          child: const _FinishPost(),
                        ),
                        for (final spot in ordered) ..._buildWalker(spot, h),
                      ],
                    ),
                  ),
                ),
              ),
              if (!_hasPanned && widget.entries.length > 1)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 58,
                  child: IgnorePointer(
                    child: Center(
                      child: _Pill(text: '⇠  Swipe to see everyone  ⇢'),
                    ),
                  ),
                ),
              if (!_viewerOnScreen)
                Positioned(
                  left: 12,
                  bottom: h * 0.1 + 6,
                  child: _OverlayButton(
                    label: '📍 Me',
                    onTap: () => _centreOnViewer(true),
                  ),
                ),
              Positioned(
                right: 12,
                bottom: h * 0.1 + 6,
                child: _OverlayButton(
                  label: '🎨 Style',
                  onTap: widget.onCustomize,
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                top: 10,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) => SlideTransition(
                    position: Tween(
                      begin: const Offset(0, -0.6),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: banner == null
                      ? const SizedBox.shrink()
                      : _CelebrationBanner(
                          key: ValueKey(banner), message: banner),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _trackMarker(double x, String label) {
    const h = _RaceScene.sceneHeight;
    return Positioned(
      left: x - 30,
      width: 60,
      top: h * 0.7,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(label, style: _body(10)),
          ),
          Container(width: 3, height: 26, color: Colors.white54),
        ],
      ),
    );
  }

  List<Widget> _buildWalker(_TrackSpot spot, double h) {
    final entry = spot.entry;
    final isMe = identical(entry, widget.me);
    final scale = _laneScale[spot.lane];
    final height = _baseHeight * scale;
    final width = height * 0.8;
    final feetY = h * _laneFeet[spot.lane];
    final look = isMe || entry == null ? widget.look : _lookFor(entry);
    // Offset each racer's stride so the crowd doesn't march in step.
    final phaseOffset =
        entry == null || isMe ? 0.0 : (_stableHash(entry.userId) % 100) / 100;

    final walker = AnimatedBuilder(
      animation: widget.stride,
      builder: (context, _) => WalkerAvatar(
        look: look,
        phase: (widget.stride.value + phaseOffset) % 1,
        blink: isMe && (widget.scenery.value * 16) % 4.0 < 0.12,
      ),
    );

    final body = isMe
        ? GestureDetector(onTap: widget.onCustomize, child: walker)
        : Tooltip(
            message: entry == null
                ? ''
                : '${_ordinal(entry.rank)} · ${entry.name} · '
                    '${widget.valueText(entry)}${widget.valueUnit}',
            triggerMode: TooltipTriggerMode.tap,
            child: walker,
          );

    return [
      Positioned(
        left: spot.x - width / 2,
        top: feetY - height,
        width: width,
        height: height,
        child: body,
      ),
      if (entry != null)
        Positioned(
          left: spot.x - 80,
          width: 160,
          // Anchored by the bottom so taller tags grow upwards.
          bottom: _RaceScene.sceneHeight - (feetY - height) + 2,
          child: Center(
            child: isMe
                ? _StepsTag(
                    steps: widget.valueText(entry),
                    rank: entry.rank,
                  )
                : _racerTag(entry, scale),
          ),
        ),
      if (isMe && entry != null)
        Positioned(
          left: spot.x - 80,
          width: 160,
          top: feetY + 4,
          child: Column(
            children: [
              _Pill(text: '${entry.name.split(' ').first} · You'),
              if (widget.leadLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _Pill(text: widget.leadLabel!),
                ),
            ],
          ),
        ),
    ];
  }

  Widget _racerTag(StepLeaderboardEntry entry, double scale) {
    final isAhead = identical(entry, widget.ahead);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isAhead && widget.aheadLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _RacePalette.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(widget.aheadLabel!, style: _body(11)),
            ),
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RankMedal(rank: entry.rank, size: 22 * scale + 6),
            const SizedBox(width: 4),
            Container(
              constraints: const BoxConstraints(maxWidth: 90),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.name.split(' ').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _body(11 * scale + 2, color: Colors.black),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.4),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(label, style: _body(13)),
        ),
      ),
    );
  }
}

/// Checkered finish post at the end of the track.
class _FinishPost extends StatelessWidget {
  const _FinishPost();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _RacePalette.go,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('FINISH', style: _body(10, color: Colors.black)),
        ),
        const SizedBox(height: 2),
        CustomPaint(size: const Size(18, 110), painter: _CheckerPainter()),
      ],
    );
  }
}

class _CheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const cell = 6.0;
    final paint = Paint();
    for (var row = 0; row * cell < size.height; row++) {
      for (var col = 0; col * cell < size.width; col++) {
        paint.color = (row + col).isEven ? Colors.white : Colors.black;
        canvas.drawRect(
            Rect.fromLTWH(col * cell, row * cell, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_CheckerPainter oldDelegate) => false;
}

class _CelebrationBanner extends StatelessWidget {
  const _CelebrationBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_RacePalette.accent, _RacePalette.gold],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Colors.black38, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: _display(18, color: const Color(0xFF2A1A00)),
      ),
    );
  }
}

class _StepsTag extends StatelessWidget {
  const _StepsTag({required this.steps, required this.rank});

  final String steps;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 14, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(steps, style: _display(15, color: Colors.black)),
        ),
        Positioned(
          right: -18,
          top: -16,
          child: _RankMedal(rank: rank, size: 30),
        ),
      ],
    );
  }
}

class _RankMedal extends StatelessWidget {
  const _RankMedal({required this.rank, required this.size});

  final int rank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = _RacePalette.forRank(rank);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color.lerp(color, Colors.white, 0.4)!, color],
        ),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        _ordinal(rank),
        style: _display(size * 0.32, color: const Color(0xFF2A1A00)),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _body(13, color: Colors.black),
      ),
    );
  }
}

class _WalkerCustomizer extends StatefulWidget {
  const _WalkerCustomizer({required this.initial, required this.lockReason});

  final WalkerLook initial;
  final String? Function(WalkerAccessory accessory) lockReason;

  @override
  State<_WalkerCustomizer> createState() => _WalkerCustomizerState();
}

class _WalkerCustomizerState extends State<_WalkerCustomizer>
    with SingleTickerProviderStateMixin {
  late WalkerLook _look = widget.initial;
  final _random = math.Random();

  late final AnimationController _stride = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _stride.dispose();
    super.dispose();
  }

  void _update(WalkerLook look) {
    HapticFeedback.selectionClick();
    final changedClothes = look.top != _look.top ||
        look.topColor != _look.topColor ||
        look.bottom != _look.bottom ||
        look.bottomColor != _look.bottomColor ||
        look.shoeColor != _look.shoeColor;
    // Changing clothes takes off the marathon kit.
    setState(() => _look = changedClothes && look.kit != null
        ? look.copyWith(takeOffKit: true)
        : look);
  }

  void _randomize() {
    _update(WalkerLook.random(
      _random,
      allowedAccessories: WalkerAccessory.values
          .where((accessory) => widget.lockReason(accessory) == null),
    ));
  }

  Widget _section(String title, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _body(13, color: _RacePalette.muted)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _swatches(
      List<Color> colors, Color selected, void Function(Color) onPick) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: colors.map((color) {
        final isSelected = color.toARGB32() == selected.toARGB32();
        return Semantics(
          button: true,
          selected: isSelected,
          child: GestureDetector(
            onTap: () => onPick(color),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _RacePalette.accent : Colors.white24,
                  width: isSelected ? 3 : 1.5,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _options<T>(
    List<T> values,
    T selected,
    String Function(T) label,
    void Function(T) onPick, {
    String? Function(T)? lockReason,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final locked = lockReason?.call(value);
        final isSelected = value == selected;
        return Tooltip(
          message: locked ?? '',
          triggerMode: locked == null
              ? TooltipTriggerMode.manual
              : TooltipTriggerMode.tap,
          child: ChoiceChip(
            label: Text(locked == null ? label(value) : '🔒 ${label(value)}'),
            selected: isSelected,
            selectedColor: _RacePalette.accent,
            backgroundColor: _RacePalette.background,
            labelStyle: _body(13,
                color: locked != null
                    ? _RacePalette.muted
                    : isSelected
                        ? Colors.white
                        : Colors.white70),
            onSelected: locked == null ? (_) => onPick(value) : null,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lockedAccessory = WalkerAccessory.values
        .map((a) => (a, widget.lockReason(a)))
        .where((entry) => entry.$2 != null)
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Make your walker', style: _display(22)),
              ),
              IconButton(
                tooltip: 'Surprise me',
                onPressed: _randomize,
                icon: const Icon(Icons.casino_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1B2A6B), Color(0xFF2B4CA8)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: AnimatedBuilder(
              animation: _stride,
              builder: (context, _) => WalkerAvatar(
                key: const ValueKey('walker-preview'),
                look: _look,
                phase: _stride.value,
              ),
            ),
          ),
          if (_look.kit != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${MarathonTheme.of(_look.kit).emoji} Wearing the '
                      '${MarathonTheme.of(_look.kit).name} marathon kit · '
                      'Bib #${_look.bib}',
                      style: _body(13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _update(_look.copyWith(takeOffKit: true)),
                    child: Text('Take off kit',
                        style: _body(13, color: _RacePalette.accent)),
                  ),
                ],
              ),
            ),
          _section(
            'Skin tone',
            _swatches(WalkerLook.skinTones, _look.skinTone,
                (c) => _update(_look.copyWith(skinTone: c))),
          ),
          _section(
            'Hair',
            _options(WalkerHairStyle.values, _look.hairStyle, (s) => s.label,
                (s) => _update(_look.copyWith(hairStyle: s))),
          ),
          _section(
            'Hair colour',
            _swatches(WalkerLook.hairColors, _look.hairColor,
                (c) => _update(_look.copyWith(hairColor: c))),
          ),
          _section(
            'Top',
            _options(WalkerTop.values, _look.top, (t) => t.label,
                (t) => _update(_look.copyWith(top: t))),
          ),
          _section(
            'Top colour',
            _swatches(WalkerLook.clothingColors, _look.topColor,
                (c) => _update(_look.copyWith(topColor: c))),
          ),
          _section(
            'Bottoms',
            _options(WalkerBottom.values, _look.bottom, (b) => b.label,
                (b) => _update(_look.copyWith(bottom: b))),
          ),
          _section(
            'Bottoms colour',
            _swatches(WalkerLook.clothingColors, _look.bottomColor,
                (c) => _update(_look.copyWith(bottomColor: c))),
          ),
          _section(
            'Shoes',
            _swatches(WalkerLook.clothingColors, _look.shoeColor,
                (c) => _update(_look.copyWith(shoeColor: c))),
          ),
          _section(
            'Accessory',
            _options(
              WalkerAccessory.values,
              _look.accessory,
              (a) => a.label,
              (a) => _update(_look.copyWith(accessory: a)),
              lockReason: widget.lockReason,
            ),
          ),
          if (lockedAccessory.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...lockedAccessory.map((entry) => Text(
                  '🔒 ${entry.$1.label}: ${entry.$2}',
                  style: _body(12,
                      color: _RacePalette.accent, weight: FontWeight.w500),
                )),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context, _look),
            style: FilledButton.styleFrom(
              backgroundColor: _RacePalette.accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text('Save my walker', style: _body(16)),
          ),
        ],
      ),
    );
  }
}

/// Horizontal track with every racer's avatar placed by their share of the
/// leader's steps. Racers bunched together are staggered above and below
/// the line so nobody hides behind anyone else.
class _RaceBar extends StatelessWidget {
  const _RaceBar({required this.entries, required this.meId});

  final List<StepLeaderboardEntry> entries;
  final String? meId;

  static const double _height = 76;
  static const double _avatar = 34;
  static const double _pad = 14;

  @override
  Widget build(BuildContext context) {
    final leader = entries.isEmpty ? 0 : entries.first.totalSteps;
    double share(StepLeaderboardEntry e) =>
        leader <= 0 ? 0 : (e.totalSteps / leader).clamp(0.0, 1.0);

    return Container(
      height: _height,
      decoration: BoxDecoration(
        color: _RacePalette.card,
        borderRadius: BorderRadius.circular(_height / 2),
        border: Border.all(color: _RacePalette.cardBorder, width: 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final runway = constraints.maxWidth - _pad * 2 - _avatar;
          final (xs, lanes) = _layout(
            entries.map((e) => share(e) * runway).toList(),
            runway,
          );
          // Paint the viewer last so they sit on top of anyone they touch.
          final order = List<int>.generate(entries.length, (i) => i)
            ..sort((a, b) {
              final aMe = entries[a].userId == meId ? 1 : 0;
              final bMe = entries[b].userId == meId ? 1 : 0;
              return aMe != bMe ? aMe - bMe : b - a;
            });
          const inner = _height - 4;
          const centerTop = (inner - _avatar) / 2;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              const Positioned(
                left: _pad,
                right: _pad,
                top: inner / 2 - 1,
                child: _DashedLine(),
              ),
              Positioned(
                right: _pad + _avatar / 2 - 1.5,
                top: 8,
                bottom: 8,
                child: Container(width: 3, color: _RacePalette.go),
              ),
              for (final i in order)
                TweenAnimationBuilder<double>(
                  key: ValueKey('${entries[i].userId}-$leader'),
                  tween: Tween(begin: 0, end: xs[i]),
                  duration: const Duration(milliseconds: 1400),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Positioned(
                    left: _pad + value,
                    top: centerTop + lanes[i] * (_avatar * 0.5),
                    child: child!,
                  ),
                  child: _RaceBarRacer(
                    entry: entries[i],
                    size: _avatar,
                    isMe: entries[i].userId == meId,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// Final x and lane (-1 up, 0 on the line, 1 down) for each racer.
  /// Racers within an avatar of each other alternate lanes, and racers
  /// sharing a lane are nudged apart so every face stays visible.
  static (List<double>, List<int>) _layout(List<double> xs, double runway) {
    final lanes = List<int>.filled(xs.length, 0);
    final placed = List<double>.of(xs);
    final order = List<int>.generate(xs.length, (i) => i)
      ..sort((a, b) => xs[a].compareTo(xs[b]));

    var clusterStart = 0;
    for (var k = 1; k <= order.length; k++) {
      final endOfCluster =
          k == order.length || xs[order[k]] - xs[order[k - 1]] > _avatar * 0.8;
      if (!endOfCluster) continue;
      if (k - clusterStart > 1) {
        for (var j = clusterStart; j < k; j++) {
          lanes[order[j]] = (j - clusterStart).isEven ? -1 : 1;
        }
      }
      clusterStart = k;
    }

    const gap = _avatar + 2;
    for (final lane in const [-1, 0, 1]) {
      final inLane = order.where((i) => lanes[i] == lane).toList();
      for (var k = 1; k < inLane.length; k++) {
        final min = placed[inLane[k - 1]] + gap;
        if (placed[inLane[k]] < min) placed[inLane[k]] = min;
      }
      // Anyone pushed past the finish slides back, pushing the rest left.
      for (var k = inLane.length - 1; k >= 0; k--) {
        final max =
            k == inLane.length - 1 ? runway : placed[inLane[k + 1]] - gap;
        if (placed[inLane[k]] > max) placed[inLane[k]] = math.max(0, max);
      }
    }
    return (placed, lanes);
  }
}

class _RaceBarRacer extends StatelessWidget {
  const _RaceBarRacer({
    required this.entry,
    required this.size,
    required this.isMe,
  });

  final StepLeaderboardEntry entry;
  final double size;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isMe ? _RacePalette.accent : _RacePalette.background,
              width: isMe ? 3 : 2,
            ),
          ),
          child: _Avatar(entry: entry, size: size - (isMe ? 6 : 4)),
        ),
        if (entry.rank == 1 && entry.totalSteps > 0)
          const Positioned(
            top: -14,
            left: 0,
            right: 0,
            child: Center(child: Text('👑', style: TextStyle(fontSize: 13))),
          ),
      ],
    );
  }
}

class _MarathonRunnerRow extends StatelessWidget {
  const _MarathonRunnerRow({
    required this.runner,
    required this.isMe,
    required this.distanceKm,
  });

  final MarathonRunner runner;
  final bool isMe;
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    final entry = StepLeaderboardEntry(
      userId: runner.userId,
      name: runner.name,
      totalSteps: runner.steps,
      daysTracked: 0,
      rank: runner.rank,
      profilePic: runner.profilePic,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _RacePalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? _RacePalette.accent : _RacePalette.cardBorder,
          width: isMe ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          _RankMedal(rank: runner.rank, size: 34),
          const SizedBox(width: 12),
          _Avatar(entry: entry, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${runner.name} (You)' : runner.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _body(15),
                ),
                if (runner.bibNumber != null)
                  Text('Bib #${runner.bibNumber}',
                      style: _body(12, color: _RacePalette.muted)),
              ],
            ),
          ),
          Text(
            runner.finished
                ? '🏁 ${formatKm(distanceKm)} km'
                : '${runner.km.toStringAsFixed(1)} km',
            style: _display(17),
          ),
        ],
      ),
    );
  }
}

class _StandingRow extends StatelessWidget {
  const _StandingRow({
    required this.entry,
    required this.isMe,
    required this.steps,
  });

  final StepLeaderboardEntry entry;
  final bool isMe;
  final String steps;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _RacePalette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isMe ? _RacePalette.accent : _RacePalette.cardBorder,
          width: isMe ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          _RankMedal(rank: entry.rank, size: 34),
          const SizedBox(width: 12),
          _Avatar(entry: entry, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isMe ? '${entry.name} (You)' : entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _body(15),
            ),
          ),
          Text(steps, style: _display(17)),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.entry, required this.size});

  final StepLeaderboardEntry entry;
  final double size;

  static const _colors = [
    Color(0xFFFF7043),
    Color(0xFF26C6DA),
    Color(0xFF9CCC65),
    Color(0xFFAB47BC),
    Color(0xFFFFCA28),
    Color(0xFF5C6BC0),
    Color(0xFFEC407A),
    Color(0xFF26A69A),
  ];

  @override
  Widget build(BuildContext context) {
    final url = entry.profilePic?.trim() ?? '';
    final hasImage = url.startsWith('http');
    final name = entry.name.trim();
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    final color = _colors[name.hashCode.abs() % _colors.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        image: hasImage
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      child: hasImage ? null : Text(initial, style: _display(size * 0.45)),
    );
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 2),
      painter: _DashPainter(),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _RacePalette.muted.withValues(alpha: 0.5);
    for (double x = 0; x < size.width; x += 12) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, 0, 6, 2), const Radius.circular(1)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashPainter oldDelegate) => false;
}

class _SceneColors {
  const _SceneColors({
    required this.sky,
    required this.farHills,
    required this.nearHills,
    required this.path,
    required this.pathEdge,
    required this.pebble,
    required this.sun,
    required this.stars,
    required this.clouds,
  });

  final List<Color> sky;
  final Color farHills;
  final Color nearHills;
  final Color path;
  final Color pathEdge;
  final Color pebble;
  final Color sun;
  final int stars;
  final double clouds;

  static const night = _SceneColors(
    sky: [Color(0xFF12122A), Color(0xFF1B2A6B), Color(0xFF2B4CA8)],
    farHills: Color(0xFF1A2456),
    nearHills: Color(0xFF16351F),
    path: Color(0xFF3E5C7A),
    pathEdge: Color(0xFF6E8CAA),
    pebble: Color(0xFF5A7896),
    sun: Color(0xFFFFF3C4),
    stars: 36,
    clouds: 0,
  );

  static const dusk = _SceneColors(
    sky: [Color(0xFF2B1B4A), Color(0xFFA8457A), Color(0xFFFF9E5E)],
    farHills: Color(0xFF5A2E5E),
    nearHills: Color(0xFF34244A),
    path: Color(0xFF7A5A7A),
    pathEdge: Color(0xFFA27A98),
    pebble: Color(0xFF946C8C),
    sun: Color(0xFFFFB74D),
    stars: 10,
    clouds: 0.35,
  );

  static const day = _SceneColors(
    sky: [Color(0xFF4FA8F0), Color(0xFF8ED0FF), Color(0xFFD8F1FF)],
    farHills: Color(0xFF7CC47F),
    nearHills: Color(0xFF4E9A51),
    path: Color(0xFFD8B98A),
    pathEdge: Color(0xFFEED6A8),
    pebble: Color(0xFFC09E6E),
    sun: Color(0xFFFFE066),
    stars: 0,
    clouds: 0.9,
  );

  static _SceneColors of(_SkyMode mode) => switch (mode) {
        _SkyMode.day => day,
        _SkyMode.dusk => dusk,
        _SkyMode.night => night,
      };
}

/// Sky (by time of day), sun or moon, clouds or stars, and two layers of
/// scrolling hills over the path.
class _ScenePainter extends CustomPainter {
  _ScenePainter({required this.scroll, required this.sky, this.pan = 0});

  final double scroll;
  final _SkyMode sky;

  /// How far the track has been swiped, in pixels; hills and the path
  /// shift with it for a parallax effect.
  final double pan;

  static final List<Offset> _stars = () {
    final random = math.Random(7);
    return List.generate(
      36,
      (_) => Offset(random.nextDouble(), random.nextDouble() * 0.55),
    );
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final colors = _SceneColors.of(sky);
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors.sky,
          stops: const [0, 0.55, 0.8],
        ).createShader(rect),
    );

    final star = Paint();
    for (var i = 0; i < colors.stars; i++) {
      final twinkle = 0.35 +
          0.65 * (0.5 + 0.5 * math.sin((scroll * 6 + i * 0.7) * math.pi));
      star.color = Colors.white.withValues(alpha: twinkle);
      canvas.drawCircle(
        Offset(_stars[i].dx * w, _stars[i].dy * h),
        i % 5 == 0 ? 1.6 : 1.0,
        star,
      );
    }

    final sunCenter =
        Offset(w * 0.14, h * (sky == _SkyMode.dusk ? 0.46 : 0.16));
    canvas.drawCircle(
      sunCenter,
      sky == _SkyMode.night ? 26 : 32,
      Paint()..color = colors.sun.withValues(alpha: 0.2),
    );
    canvas.drawCircle(
      sunCenter,
      sky == _SkyMode.night ? 16 : 20,
      Paint()..color = colors.sun,
    );

    if (colors.clouds > 0) {
      final cloud = Paint()
        ..color = Colors.white.withValues(alpha: colors.clouds);
      for (var i = 0; i < 3; i++) {
        final x = ((i / 3 + 0.2) - scroll * 0.5) % 1.0 * (w + 120) - 60;
        final y = h * (0.12 + 0.12 * i);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y), width: 70, height: 18),
            const Radius.circular(9),
          ),
          cloud,
        );
        canvas.drawCircle(Offset(x - 8, y - 8), 13, cloud);
        canvas.drawCircle(Offset(x + 12, y - 5), 10, cloud);
      }
    }

    _hills(canvas, size,
        baseline: h * 0.66,
        amplitude: h * 0.06,
        waves: 2,
        offset: scroll * 0.35 + pan * 0.15 / w,
        color: colors.farHills);
    _hills(canvas, size,
        baseline: h * 0.74,
        amplitude: h * 0.04,
        waves: 3,
        offset: scroll + pan * 0.4 / w,
        color: colors.nearHills);

    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.78, w, h * 0.12),
      Paint()..color = colors.path,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.78, w, 3),
      Paint()..color = colors.pathEdge,
    );
    final pebble = Paint()..color = colors.pebble;
    for (var i = 0; i < 10; i++) {
      final x = ((i / 10) - scroll - pan / w) % 1.0 * w;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, h * (i.isEven ? 0.83 : 0.87)),
          width: 10,
          height: 4,
        ),
        pebble,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.9, w, h * 0.1),
      Paint()..color = _RacePalette.background,
    );
  }

  /// A seamlessly wrapping band of hills; [offset] in 0..1 scrolls it left.
  void _hills(
    Canvas canvas,
    Size size, {
    required double baseline,
    required double amplitude,
    required int waves,
    required double offset,
    required Color color,
  }) {
    final w = size.width;
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= w; x += 4) {
      final t = (x / w + offset) * 2 * math.pi;
      final y = baseline -
          amplitude * math.sin(t * waves) -
          amplitude * 0.5 * math.sin(t * waves * 2 + 1);
      path.lineTo(x, y);
    }
    path
      ..lineTo(w, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ScenePainter oldDelegate) =>
      oldDelegate.scroll != scroll ||
      oldDelegate.sky != sky ||
      oldDelegate.pan != pan;
}

/// Falling confetti for a celebration; [progress] runs 0..1 once.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress});

  final double progress;

  static final List<_ConfettiPiece> _pieces = () {
    final random = math.Random(42);
    const colors = [
      _RacePalette.gold,
      _RacePalette.accent,
      _RacePalette.go,
      Color(0xFF29B6F6),
      Color(0xFFE040FB),
      Colors.white,
    ];
    return List.generate(
      90,
      (i) => _ConfettiPiece(
        x: random.nextDouble(),
        delay: random.nextDouble() * 0.3,
        speed: 0.8 + random.nextDouble() * 0.7,
        size: 5 + random.nextDouble() * 6,
        spin: (random.nextDouble() - 0.5) * 12,
        sway: random.nextDouble() * 2 * math.pi,
        color: colors[i % colors.length],
      ),
    );
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final piece in _pieces) {
      final t = ((progress - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final y = (-0.05 + t * piece.speed * 1.1) * size.height;
      final x = (piece.x + math.sin(t * 6 + piece.sway) * 0.03) * size.width;
      paint.color = piece.color.withValues(alpha: (1 - t * t).clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * piece.spin);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: piece.size, height: piece.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _ConfettiPiece {
  const _ConfettiPiece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.size,
    required this.spin,
    required this.sway,
    required this.color,
  });

  final double x;
  final double delay;
  final double speed;
  final double size;
  final double spin;
  final double sway;
  final Color color;
}
