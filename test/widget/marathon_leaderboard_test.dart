import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/step_leaderboard_screen.dart';
import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/walker_avatar.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_announcement.dart';
import 'package:selfcare_projects/src/services/leaderboard_api_service.dart';
import 'package:selfcare_projects/src/services/marathon_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Marathon _marathon({
  String id = '9',
  String title = 'Sunrise 10K',
  MarathonPhase phase = MarathonPhase.ongoing,
  MyMarathonRegistration? registration,
  DateTime? startsAt,
}) =>
    Marathon(
      id: id,
      title: title,
      theme: 'sunrise',
      distanceKm: 10,
      price: 499,
      currency: 'PHP',
      startsAt: startsAt ?? DateTime(2026, 10, 15),
      endsAt: DateTime(2026, 10, 31),
      phase: phase,
      myRegistration: registration,
    );

class _FakeMarathons extends MarathonApiService {
  _FakeMarathons(this.marathons, {this.race}) : super.forTesting();

  final List<Marathon> marathons;
  final MarathonRace? race;
  int raceLoads = 0;

  @override
  Future<List<Marathon>> fetchMarathons() async => marathons;

  @override
  Future<MarathonRace> fetchRace(String id) async {
    raceLoads++;
    return race!;
  }
}

StepLeaderboardSnapshot _companyRace(StepLeaderboardPeriod period) =>
    StepLeaderboardSnapshot(
      period: period,
      companyName: 'Acme',
      companyTotalSteps: 2500,
      entries: const [
        StepLeaderboardEntry(
            userId: '4',
            name: 'Dan Uy',
            totalSteps: 2500,
            daysTracked: 1,
            rank: 1),
      ],
    );

final _race = MarathonRace(
  marathon: _marathon(
    registration: const MyMarathonRegistration(
      status: MarathonRegistrationStatus.confirmed,
      bibNumber: 7,
      progress: MarathonProgress(km: 4.2, percent: 42),
    ),
  ),
  runners: const [
    MarathonRunner(
        userId: '1',
        name: 'Ana Reyes',
        km: 10,
        rank: 1,
        finished: true,
        bibNumber: 2),
    MarathonRunner(userId: '3', name: 'Cara Lim', km: 5, rank: 2, bibNumber: 5),
    MarathonRunner(
      userId: '4',
      name: 'Dan Uy',
      km: 4.2,
      rank: 3,
      bibNumber: 7,
    ),
  ],
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void usePhoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Widget leaderboard(_FakeMarathons api, {String? marathonId}) => MaterialApp(
        home: StepLeaderboardScreen(
          currentUserId: '4',
          clock: () => DateTime(2026, 10, 27, 9),
          loader: (period) async => _companyRace(period),
          lookSaver: (_) async {},
          marathonApi: api,
          initialMarathonId: marathonId,
        ),
      );

  testWidgets('a marathon is raced inside the steps leaderboard',
      (tester) async {
    usePhoneScreen(tester);
    final api = _FakeMarathons([_race.marathon], race: _race);
    await tester.pumpWidget(leaderboard(api, marathonId: '9'));
    await frames(tester);

    expect(find.text('🏅 Sunrise 10K'), findsOneWidget);
    expect(find.text('4.2 / 10 km'), findsOneWidget);
    expect(find.text('Bib #7'), findsWidgets);
    // Every runner walks the track; the finish line is the distance.
    expect(find.byType(WalkerAvatar), findsNWidgets(3));
    expect(find.text('2.5 km'), findsOneWidget);
    expect(find.text('in 0.8 km'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Cara Lim'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('🏁 10 km'), findsOneWidget);
    expect(find.text('Dan Uy (You)'), findsOneWidget);
  });

  testWidgets('the race menu switches between the company race and marathons',
      (tester) async {
    usePhoneScreen(tester);
    final api = _FakeMarathons([_race.marathon], race: _race);
    await tester.pumpWidget(leaderboard(api));
    await frames(tester);

    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('race-menu')));
    await frames(tester);
    expect(find.text('🏅 Browse all marathons'), findsOneWidget);
    await tester.tap(find.text('🌅 Sunrise 10K'));
    await frames(tester);

    expect(api.raceLoads, 1);
    expect(find.text('🏅 Sunrise 10K'), findsOneWidget);
    expect(find.text('4.2 / 10 km'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('race-menu')));
    await frames(tester);
    await tester.tap(find.text('This Week').last);
    await frames(tester);
    expect(find.text('This Week'), findsOneWidget);
    expect(find.text('4.2 / 10 km'), findsNothing);
  });

  testWidgets('people who have not joined are invited to join', (tester) async {
    usePhoneScreen(tester);
    final race = MarathonRace(
      marathon: _marathon(
        phase: MarathonPhase.upcoming,
        startsAt: DateTime(2026, 11, 1),
      ),
      runners: const [],
    );
    await tester.pumpWidget(leaderboard(
        _FakeMarathons([race.marathon], race: race),
        marathonId: '9'));
    await frames(tester);

    expect(find.text('Join this marathon'), findsOneWidget);
    expect(find.textContaining('Opens in 5 days'), findsOneWidget);
    expect(find.text('No runners yet. Be the first to join!'), findsOneWidget);
  });

  group('step page announcement', () {
    testWidgets('announces a new marathon once and opens its race',
        (tester) async {
      usePhoneScreen(tester);
      final api = _FakeMarathons([
        _marathon(id: '1', title: 'Old Run', phase: MarathonPhase.ended),
        _marathon(
            id: '2',
            title: 'Joined Run',
            registration: const MyMarathonRegistration(
                status: MarathonRegistrationStatus.confirmed)),
        _marathon(id: '9'),
      ], race: _race);

      late BuildContext pageContext;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          pageContext = context;
          return const Scaffold(body: Text('Step page'));
        }),
      ));

      unawaited(MarathonAnnouncement.maybeShow(pageContext,
          api: api, today: DateTime(2026, 10, 27)));
      await frames(tester);

      expect(find.text('We have a marathon!'), findsOneWidget);
      expect(find.text('Sunrise 10K'), findsOneWidget);
      expect(find.textContaining('finisher shirt, medal and certificate'),
          findsOneWidget);

      await tester.tap(find.text('See the race'));
      await frames(tester);
      expect(find.byType(StepLeaderboardScreen), findsOneWidget);
      expect(api.raceLoads, 1);

      // Already announced: no popup the next time.
      final prefs = await SharedPreferences.getInstance();
      expect(await MarathonAnnouncement.pick(api, prefs), isNull);
    });

    test('skips ended, joined and already announced marathons', () async {
      SharedPreferences.setMockInitialValues(
          {MarathonAnnouncement.seenKey('3'): true});
      final prefs = await SharedPreferences.getInstance();
      final api = _FakeMarathons([
        _marathon(id: '1', phase: MarathonPhase.ended),
        _marathon(
            id: '2',
            registration: const MyMarathonRegistration(
                status: MarathonRegistrationStatus.pendingPayment)),
        _marathon(id: '3'),
        _marathon(id: '4', phase: MarathonPhase.upcoming),
        _marathon(id: '5'),
      ]);

      // A running race before an upcoming one.
      expect((await MarathonAnnouncement.pick(api, prefs))?.id, '5');
    });
  });
}

void unawaited(Future<void> future) {}
