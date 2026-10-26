import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/step_leaderboard_screen.dart';
import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/walker_avatar.dart';
import 'package:selfcare_projects/src/services/leaderboard_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _defaultWeek = [
  StepDayPlacement(date: DateTime(2026, 10, 19), steps: 9000, rank: 1),
  StepDayPlacement(date: DateTime(2026, 10, 20), steps: 3000, rank: 2),
  StepDayPlacement(date: DateTime(2026, 10, 21), steps: 0),
];

StepLeaderboardSnapshot _snapshot(
  StepLeaderboardPeriod period, {
  List<StepDayPlacement>? week,
}) {
  return StepLeaderboardSnapshot(
    period: period,
    companyName: 'Acme',
    companyTotalSteps: 26500,
    startDate: DateTime(2026, 10, 21),
    endDate: DateTime(2026, 10, 21),
    weekPlacements: week ?? _defaultWeek,
    entries: const [
      StepLeaderboardEntry(
          userId: '1',
          name: 'Ben Cruz',
          totalSteps: 12000,
          daysTracked: 3,
          rank: 1),
      StepLeaderboardEntry(
          userId: '2',
          name: 'Ana Reyes',
          totalSteps: 8000,
          daysTracked: 2,
          rank: 2),
      StepLeaderboardEntry(
          userId: '3',
          name: 'Cara Lim',
          totalSteps: 4000,
          daysTracked: 1,
          rank: 3),
      StepLeaderboardEntry(
          userId: '4',
          name: 'Dan Uy',
          totalSteps: 2500,
          daysTracked: 1,
          rank: 4),
    ],
  );
}

Widget _app({
  required String me,
  required StepLeaderboardLoader loader,
  DateTime? now,
}) {
  // Wednesday 21:10:06 by default, so today's race finishes in 02:49:54.
  final clock = now ?? DateTime(2026, 10, 21, 21, 10, 6);
  return MaterialApp(
    home: StepLeaderboardScreen(
      currentUserId: me,
      loader: loader,
      clock: () => clock,
    ),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The walking animation repeats forever, so pump fixed durations instead
  // of pumpAndSettle.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
  }

  void usePhoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows my steps, countdown, streak, milestone and rival',
      (tester) async {
    usePhoneScreen(tester);
    final requested = <StepLeaderboardPeriod>[];
    await tester.pumpWidget(_app(
      me: '4',
      loader: (period) async {
        requested.add(period);
        return _snapshot(period);
      },
    ));
    await settle(tester);

    expect(find.text('2,500'), findsWidgets);
    expect(find.text('Finishes in 02:49:54'), findsOneWidget);
    expect(find.text('4th of 4 in Acme'), findsOneWidget);
    expect(find.text('🔥 2-day streak'), findsOneWidget);
    expect(find.text('2,500 steps to the 5K badge'), findsOneWidget);
    expect(find.text('Dan · You'), findsOneWidget);
    expect(find.text('in 1,501'), findsOneWidget);
    expect(find.text('Cara'), findsOneWidget);
    expect(find.text('1st'), findsWidgets);
    expect(find.text('2nd'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Dan Uy (You)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Dan Uy (You)'), findsOneWidget);
    expect(requested, [StepLeaderboardPeriod.today]);

    await tester.tap(find.text('Today'));
    await settle(tester);
    await tester.tap(find.text('This Week').last);
    await settle(tester);
    expect(requested.last, StepLeaderboardPeriod.week);
    expect(find.text('Finishes in 4d 02:49:54'), findsOneWidget);
    expect(find.textContaining('badge'), findsNothing);
  });

  testWidgets('the countdown turns urgent in the last hour', (tester) async {
    await tester.pumpWidget(_app(
      me: '4',
      now: DateTime(2026, 10, 21, 23, 30),
      loader: (period) async => _snapshot(period),
    ));
    await settle(tester);

    expect(find.text('⏰ Finishes in 00:30:00'), findsOneWidget);
  });

  testWidgets('celebrates racers passed since the last visit', (tester) async {
    SharedPreferences.setMockInitialValues({
      'step_race_ahead_today_2026-10-21': ['1', '2', '4'],
      'step_race_rank_today_2026-10-21': 4,
    });
    await tester.pumpWidget(_app(
      me: '3',
      loader: (period) async => _snapshot(period),
    ));
    await settle(tester);

    expect(find.text('You passed Dan! 🎉'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));
    // Let the banner's exit transition finish.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('You passed Dan! 🎉'), findsNothing);
  });

  testWidgets('no celebration on the first visit to a race', (tester) async {
    await tester.pumpWidget(_app(
      me: '3',
      loader: (period) async => _snapshot(period),
    ));
    await settle(tester);

    expect(find.textContaining('You passed'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('step_race_rank_today_2026-10-21'), 3);
  });

  testWidgets('the walker can be customized and locked items say why',
      (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(_app(
      me: '4',
      loader: (period) async =>
          _snapshot(period, week: const <StepDayPlacement>[]),
    ));
    await settle(tester);

    await tester.tap(find.text('🎨 Style'));
    await settle(tester);

    expect(find.text('Make your walker'), findsOneWidget);
    expect(find.byKey(const ValueKey('walker-preview')), findsOneWidget);

    Future<void> reveal(Finder finder) => tester.scrollUntilVisible(
          finder,
          150,
          scrollable: find.byType(Scrollable).last,
        );
    Future<void> tapText(String text) async {
      await reveal(find.text(text));
      await tester.tap(find.text(text), warnIfMissed: false);
      await tester.pump();
    }

    await tapText('Ponytail');
    await tapText('Hoodie');
    await tapText('Shorts');
    // Locked accessories can't be chosen, and say what earns them.
    await tapText('🔒 Crown');
    await reveal(find.text('🔒 Crown: Win a daily race'));
    expect(find.text('🔒 Cap: Walk 2 days in a row'), findsOneWidget);

    await tapText('Save my walker');
    await settle(tester);

    final prefs = await SharedPreferences.getInstance();
    final saved = WalkerLook.fromJson(prefs.getString('step_race_look'));
    expect(saved.hairStyle, WalkerHairStyle.ponytail);
    expect(saved.top, WalkerTop.hoodie);
    expect(saved.bottom, WalkerBottom.shorts);
    expect(saved.accessory, isNot(WalkerAccessory.crown));
  });

  testWidgets('an old outfit choice carries over to the new walker',
      (tester) async {
    SharedPreferences.setMockInitialValues({'step_race_skin': 'dj'});
    usePhoneScreen(tester);
    await tester.pumpWidget(_app(
      me: '1',
      loader: (period) async => _snapshot(period),
    ));
    await settle(tester);

    await tester.tap(find.text('🎨 Style'));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text('Save my walker'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Save my walker'));
    await settle(tester);

    final prefs = await SharedPreferences.getInstance();
    final saved = WalkerLook.fromJson(prefs.getString('step_race_look'));
    expect(saved.accessory, WalkerAccessory.headphones);
    expect(saved.top, WalkerTop.hoodie);
  });

  testWidgets('the race scrolls sideways to show every runner as a walker',
      (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(_app(
      me: '4',
      loader: (period) async => _snapshot(period),
    ));
    await settle(tester);

    // One walker per runner, all on the track.
    expect(find.byType(WalkerAvatar), findsNWidgets(4));
    expect(find.text('Ben'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('⇠  Swipe to see everyone  ⇢'), findsOneWidget);
    expect(find.text('📍 Me'), findsNothing);

    final track = find.byKey(const ValueKey('race-track'));
    Future<void> frames() async {
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.drag(track, const Offset(-900, 0));
    await frames();

    expect(find.text('⇠  Swipe to see everyone  ⇢'), findsNothing);
    expect(find.text('📍 Me'), findsOneWidget);

    await tester.tap(find.text('📍 Me'));
    await frames();
    expect(find.text('📍 Me'), findsNothing);
  });

  group('shared walkers', () {
    Map<String, dynamic> curlyLook({String accessory = 'none'}) => {
          'skin': 0xFF8D5524,
          'hairStyle': 'curly',
          'hair': 0xFF1B1B1B,
          'top': 'tank',
          'topColor': 0xFF26A69A,
          'bottom': 'shorts',
          'bottomColor': 0xFF37474F,
          'shoes': 0xFFEF5350,
          'accessory': accessory,
        };

    StepLeaderboardSnapshot withLooks(
      StepLeaderboardPeriod period,
      Map<String, Map<String, dynamic>> looks,
    ) {
      final base = _snapshot(period);
      return StepLeaderboardSnapshot(
        period: period,
        companyName: base.companyName,
        companyTotalSteps: base.companyTotalSteps,
        startDate: base.startDate,
        endDate: base.endDate,
        weekPlacements: base.weekPlacements,
        entries: [
          for (final e in base.entries)
            StepLeaderboardEntry(
              userId: e.userId,
              name: e.name,
              totalSteps: e.totalSteps,
              daysTracked: e.daysTracked,
              rank: e.rank,
              walkerLook: looks[e.userId],
            ),
        ],
      );
    }

    List<WalkerLook> walkerLooks(WidgetTester tester) => tester
        .widgetList<WalkerAvatar>(find.byType(WalkerAvatar))
        .map((w) => w.look)
        .toList();

    testWidgets('other runners walk in the look they saved', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(MaterialApp(
        home: StepLeaderboardScreen(
          currentUserId: '4',
          clock: () => DateTime(2026, 10, 21, 21, 10, 6),
          lookSaver: (_) async {},
          // Cara (3rd) saved a crown, which only the leader may wear.
          loader: (period) async => withLooks(period, {
            '3': curlyLook(accessory: 'crown'),
          }),
        ),
      ));
      await settle(tester);

      // Cara's own design, minus the crown she hasn't earned today.
      final caraLook = WalkerLook.fromMap(curlyLook());
      expect(
          walkerLooks(tester).where((look) => look == caraLook), hasLength(1));
      expect(
        walkerLooks(tester)
            .where((look) => look.accessory == WalkerAccessory.crown),
        hasLength(1),
        reason: 'only the leader wears the crown',
      );
    });

    testWidgets('saving a walker shares it through the API', (tester) async {
      usePhoneScreen(tester);
      final uploads = <Map<String, dynamic>>[];
      await tester.pumpWidget(MaterialApp(
        home: StepLeaderboardScreen(
          currentUserId: '4',
          clock: () => DateTime(2026, 10, 21, 21, 10, 6),
          lookSaver: (look) async => uploads.add(look),
          loader: (period) async => _snapshot(period),
        ),
      ));
      await settle(tester);
      expect(uploads, isEmpty, reason: 'nothing designed yet');

      await tester.tap(find.text('🎨 Style'));
      await settle(tester);
      Future<void> tapText(String text) async {
        await tester.scrollUntilVisible(find.text(text), 150,
            scrollable: find.byType(Scrollable).last);
        await tester.tap(find.text(text));
        await tester.pump();
      }

      await tapText('Bun');
      await tapText('Save my walker');
      await settle(tester);

      expect(uploads, hasLength(1));
      expect(uploads.single['hairStyle'], 'bun');
      expect(find.text('Walker saved. Your team will see it in the race.'),
          findsOneWidget);
    });

    testWidgets('a walker saved on the server follows the user to a new phone',
        (tester) async {
      usePhoneScreen(tester);
      final uploads = <Map<String, dynamic>>[];
      await tester.pumpWidget(MaterialApp(
        home: StepLeaderboardScreen(
          currentUserId: '4',
          clock: () => DateTime(2026, 10, 21, 21, 10, 6),
          lookSaver: (look) async => uploads.add(look),
          loader: (period) async => withLooks(period, {'4': curlyLook()}),
        ),
      ));
      await settle(tester);

      final prefs = await SharedPreferences.getInstance();
      expect(
        WalkerLook.fromJson(prefs.getString('step_race_look')).hairStyle,
        WalkerHairStyle.curly,
      );
      expect(uploads, isEmpty);
    });

    testWidgets('a walker only on this phone is uploaded once', (tester) async {
      SharedPreferences.setMockInitialValues({'step_race_skin': 'champion'});
      usePhoneScreen(tester);
      final uploads = <Map<String, dynamic>>[];
      await tester.pumpWidget(MaterialApp(
        home: StepLeaderboardScreen(
          currentUserId: '4',
          clock: () => DateTime(2026, 10, 21, 21, 10, 6),
          lookSaver: (look) async => uploads.add(look),
          loader: (period) async => _snapshot(period),
        ),
      ));
      await settle(tester);

      await tester.tap(find.text('Today'));
      await settle(tester);
      await tester.tap(find.text('This Week').last);
      await settle(tester);

      expect(uploads, hasLength(1));
      expect(uploads.single['accessory'], 'crown');
    });
  });

  testWidgets('the leader sees how far ahead they are', (tester) async {
    await tester.pumpWidget(_app(
      me: '1',
      loader: (period) async => _snapshot(period),
    ));
    await settle(tester);

    expect(find.text('+4,000 ahead'), findsOneWidget);
  });

  testWidgets('shows a retry button when loading fails', (tester) async {
    await tester.pumpWidget(_app(
      me: '1',
      loader: (_) async => throw Exception('offline'),
    ));
    await settle(tester);

    expect(find.text('Retry'), findsOneWidget);
  });

  test('parses the API payload', () {
    final snapshot = StepLeaderboardSnapshot.fromJson({
      'period': 'today',
      'startDate': '2026-10-19',
      'endDate': '2026-10-19',
      'company': {'name': 'Acme'},
      'companyTotalSteps': '1500',
      'entries': [
        {'userId': 7, 'name': 'Ana', 'totalSteps': 1500, 'rank': 1},
      ],
      'weekPlacements': [
        {'date': '2026-10-19', 'steps': 1500, 'rank': 1},
        {'date': '2026-10-20', 'steps': 0, 'rank': null},
      ],
    });

    expect(snapshot.period, StepLeaderboardPeriod.today);
    expect(snapshot.companyTotalSteps, 1500);
    expect(snapshot.entries.single.userId, '7');
    expect(snapshot.startDate, DateTime(2026, 10, 19));
    expect(snapshot.weekPlacements.first.rank, 1);
    expect(snapshot.weekPlacements.last.rank, isNull);
  });
}
