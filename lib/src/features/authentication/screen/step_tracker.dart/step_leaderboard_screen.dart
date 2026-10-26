import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/walker_avatar.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';
import 'package:selfcare_projects/src/services/leaderboard_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef StepLeaderboardLoader = Future<StepLeaderboardSnapshot> Function(
  StepLeaderboardPeriod period,
);

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
  });

  /// Overridable for tests; defaults to the leaderboard API.
  final StepLeaderboardLoader? loader;
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

  @override
  void initState() {
    super.initState();
    _now = _clock();
    _future = _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = _clock());
    });
    _restoreLook();
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

  Future<void> _restoreLook() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_lookKey);
      final look = saved != null
          ? WalkerLook.fromJson(saved)
          : WalkerLook.fromLegacySkin(prefs.getString(_legacySkinKey));
      if (mounted) setState(() => _look = look);
    } catch (_) {
      // Keep the default look.
    }
  }

  Future<void> _saveLook(WalkerLook look) async {
    setState(() => _look = look);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lookKey, look.toJson());
    } catch (_) {
      // The look still applies for this session.
    }
  }

  Future<StepLeaderboardSnapshot> _load() {
    final loader = widget.loader;
    final period = _period;
    final future = loader != null
        ? loader(period)
        : LeaderboardApiService.instance.fetchStepLeaderboard(period: period);
    return future.then((data) {
      _celebrateProgress(data, period);
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
    final future = _load();
    setState(() => _future = future);
    try {
      await future;
    } catch (_) {
      // Error state is rendered by the FutureBuilder.
    }
  }

  void _selectPeriod(StepLeaderboardPeriod period) {
    if (period == _period) return;
    HapticFeedback.selectionClick();
    setState(() {
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
            child: FutureBuilder<StepLeaderboardSnapshot>(
              future: _future,
              builder: (context, snapshot) {
                final loading =
                    snapshot.connectionState != ConnectionState.done;
                final data = snapshot.data;
                return Column(
                  children: [
                    _buildTopBar(data),
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

  Widget _buildTopBar(StepLeaderboardSnapshot? data) {
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
              child: PopupMenuButton<StepLeaderboardPeriod>(
                initialValue: _period,
                color: _RacePalette.card,
                onSelected: _selectPeriod,
                itemBuilder: (context) => _periodLabels.entries
                    .map((entry) => PopupMenuItem(
                          value: entry.key,
                          child: Text(entry.value, style: _body(15)),
                        ))
                    .toList(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: _RacePalette.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _RacePalette.cardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_periodLabels[_period]!, style: _body(15)),
                      const SizedBox(width: 6),
                      const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Tooltip(
            message: 'Team steps',
            child: Row(
              children: [
                const Icon(Icons.directions_walk_rounded,
                    color: _RacePalette.gold, size: 20),
                const SizedBox(width: 2),
                Text(
                  data == null
                      ? '--'
                      : NumberFormat.compact().format(data.companyTotalSteps),
                  style: _display(18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
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
              'Unable to load the steps leaderboard.',
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

  Widget _buildRace(StepLeaderboardSnapshot data) {
    final entries = data.entries;
    final myIndex =
        entries.indexWhere((entry) => entry.userId == _currentUserId);
    final me = myIndex >= 0 ? entries[myIndex] : null;
    final ahead = myIndex > 0 ? entries[myIndex - 1] : null;
    final streak = _walkStreak(data.weekPlacements, _now);
    final look = _effectiveLook(data.weekPlacements, streak);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _WeekStrip(placements: data.weekPlacements, today: _now),
        const SizedBox(height: 14),
        _buildHero(data, me, streak),
        const SizedBox(height: 8),
        _RaceScene(
          me: me,
          ahead: ahead,
          gapToAhead: ahead == null || me == null
              ? null
              : ahead.totalSteps - me.totalSteps + 1,
          leadOverNext: myIndex == 0 && entries.length > 1
              ? me!.totalSteps - entries[1].totalSteps
              : null,
          format: _stepsFormat,
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

/// Scene with the viewer walking and the next racer to catch.
class _RaceScene extends StatelessWidget {
  const _RaceScene({
    required this.me,
    required this.ahead,
    required this.gapToAhead,
    required this.leadOverNext,
    required this.format,
    required this.stride,
    required this.scenery,
    required this.sky,
    required this.look,
    required this.banner,
    required this.onCustomize,
  });

  final StepLeaderboardEntry? me;
  final StepLeaderboardEntry? ahead;
  final int? gapToAhead;
  final int? leadOverNext;
  final NumberFormat format;
  final Animation<double> stride;
  final Animation<double> scenery;
  final _SkyMode sky;
  final WalkerLook look;
  final String? banner;
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context) {
    final me = this.me;
    final ahead = this.ahead;
    final banner = this.banner;
    return SizedBox(
      height: 330,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          const h = 330.0;
          const walkerHeight = 170.0;
          final groundY = h * 0.84;
          final walkerX = w * 0.36;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: scenery,
                  builder: (context, _) => CustomPaint(
                    painter: _ScenePainter(scroll: scenery.value, sky: sky),
                  ),
                ),
              ),
              Positioned(
                left: walkerX - walkerHeight * 0.4,
                top: groundY - walkerHeight,
                width: walkerHeight * 0.8,
                height: walkerHeight,
                child: GestureDetector(
                  onTap: onCustomize,
                  child: AnimatedBuilder(
                    animation: stride,
                    builder: (context, _) => WalkerAvatar(
                      look: look,
                      phase: stride.value,
                      // A quick blink about every 4 seconds.
                      blink: (scenery.value * 16) % 4.0 < 0.12,
                    ),
                  ),
                ),
              ),
              if (me != null) ...[
                Positioned(
                  left: walkerX - 60,
                  width: 120,
                  top: groundY - walkerHeight - 44,
                  child: Center(
                    child: _StepsTag(
                      steps: format.format(me.totalSteps),
                      rank: me.rank,
                    ),
                  ),
                ),
                Positioned(
                  left: walkerX - 70,
                  width: 140,
                  top: groundY + 8,
                  child: Center(
                    child: _Pill(text: '${me.name.split(' ').first} · You'),
                  ),
                ),
              ],
              Positioned(
                right: 18,
                top: h * 0.2,
                child: ahead != null
                    ? _RivalBubble(
                        entry: ahead,
                        label: 'in ${format.format(gapToAhead ?? 0)}',
                      )
                    : _LeaderBubble(
                        label: leadOverNext == null
                            ? 'Leading!'
                            : '+${format.format(leadOverNext)} ahead',
                      ),
              ),
              Positioned(
                right: 12,
                top: groundY - 44,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: onCustomize,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      child: Text('🎨 Style', style: _body(13)),
                    ),
                  ),
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

class _RivalBubble extends StatelessWidget {
  const _RivalBubble({required this.entry, required this.label});

  final StepLeaderboardEntry entry;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: Column(
        children: [
          _Pill(text: label),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
            child: _Avatar(entry: entry, size: 58),
          ),
          const SizedBox(height: 4),
          Text(
            entry.name.split(' ').first,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _body(12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _LeaderBubble extends StatelessWidget {
  const _LeaderBubble({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      child: Column(
        children: [
          _Pill(text: label),
          const SizedBox(height: 6),
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _RacePalette.gold.withValues(alpha: 0.25),
              border: Border.all(color: _RacePalette.gold, width: 2),
            ),
            child: const Icon(Icons.emoji_events_rounded,
                color: _RacePalette.gold, size: 36),
          ),
        ],
      ),
    );
  }
}

/// Walker editor: skin, hair, clothes, shoes and accessory, with a live
/// walking preview. Locked accessories show what earns them.
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
    setState(() => _look = look);
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
  _ScenePainter({required this.scroll, required this.sky});

  final double scroll;
  final _SkyMode sky;

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
        offset: scroll * 0.35,
        color: colors.farHills);
    _hills(canvas, size,
        baseline: h * 0.74,
        amplitude: h * 0.04,
        waves: 3,
        offset: scroll,
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
      final x = ((i / 10) - scroll) % 1.0 * w;
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
      oldDelegate.scroll != scroll || oldDelegate.sky != sky;
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
