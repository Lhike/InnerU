import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/walker_avatar.dart';
import 'package:selfcare_projects/src/features/marathon/admin_marathons_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_detail_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_list_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_payment_screen.dart';
import 'package:selfcare_projects/src/services/marathon_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _today = DateTime(2026, 10, 27);

Marathon _marathon({
  String id = '1',
  MarathonPhase phase = MarathonPhase.upcoming,
  double price = 499,
  MyMarathonRegistration? registration,
}) =>
    Marathon(
      id: id,
      title: 'Sunrise 10K',
      description: 'Greet the morning, one step at a time.',
      theme: 'sunrise',
      distanceKm: 10,
      price: price,
      currency: 'PHP',
      startsAt: DateTime(2026, 11, 1),
      endsAt: DateTime(2026, 11, 30),
      phase: phase,
      paymentInstructions: 'GCash 0917 000 0000 · Juan Dela Cruz',
      myRegistration: registration,
    );

class _FakeApi extends MarathonApiService {
  _FakeApi(this.current) : super.forTesting();

  Marathon current;
  MarathonRegistrationForm? registeredWith;
  String? paidReference;
  String? paidProof;
  final reviews = <String>[];

  Marathon _withStatus(MarathonRegistrationStatus status) => _marathon(
        price: current.price,
        phase: current.phase,
        registration: MyMarathonRegistration(status: status),
      );

  @override
  Future<List<Marathon>> fetchMarathons() async => [current];

  @override
  Future<Marathon> fetchMarathon(String id) async => current;

  @override
  Future<Marathon> register(String id, MarathonRegistrationForm form) async {
    registeredWith = form;
    return current = _withStatus(MarathonRegistrationStatus.pendingPayment);
  }

  @override
  Future<Marathon> submitPayment(
    String id, {
    required String reference,
    required String proofUrl,
  }) async {
    paidReference = reference;
    paidProof = proofUrl;
    return current = _withStatus(MarathonRegistrationStatus.paymentSubmitted);
  }

  @override
  Future<MarathonCertificate> fetchCertificate(String id) async =>
      const MarathonCertificate(
        number: 'IU-0001-00007',
        runnerName: 'Ana Reyes',
        marathonTitle: 'Sunrise 10K',
        theme: 'sunrise',
        distanceKm: 10,
        bibNumber: 7,
      );

  @override
  Future<List<Marathon>> adminFetchMarathons() async => [current];

  @override
  Future<List<AdminMarathonRegistration>> adminFetchRegistrations(
          String marathonId) async =>
      const [
        AdminMarathonRegistration(
          id: '55',
          fullName: 'Ana Reyes',
          email: 'ana@example.com',
          phone: '0917',
          shirtSize: 'M',
          shippingAddress: '1 Rizal St',
          status: MarathonRegistrationStatus.paymentSubmitted,
          paymentReference: 'GC-123',
        ),
      ];

  @override
  Future<void> adminReview(String registrationId, String action,
      {String? reason}) async {
    reviews.add('$registrationId:$action${reason == null ? '' : ':$reason'}');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  void usePhoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  // The walker animation never settles, so pump frames instead.
  Future<void> frames(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(finder, 200,
          scrollable: find.byType(Scrollable).first);

  testWidgets('the list shows each marathon with its status', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(MaterialApp(
      home: MarathonListScreen(api: _FakeApi(_marathon()), today: _today),
    ));
    await frames(tester);

    expect(find.text('Sunrise 10K'), findsOneWidget);
    expect(find.text('10 km'), findsOneWidget);
    expect(find.text('₱499'), findsOneWidget);
    expect(find.text('Opens in 5 days'), findsOneWidget);
  });

  testWidgets('joining: register, then pay with a receipt', (tester) async {
    usePhoneScreen(tester);
    final api = _FakeApi(_marathon());
    await tester.pumpWidget(MaterialApp(
      home: MarathonDetailScreen(marathonId: '1', api: api, today: _today),
    ));
    await frames(tester);

    await scrollTo(tester, find.text('When you finish your marathon'));
    expect(find.textContaining('finisher shirt, medal and certificate'),
        findsWidgets);
    expect(find.text('Virtual certificate'), findsOneWidget);
    await scrollTo(tester, find.text('Join this marathon'));
    await tester.tap(find.text('Join this marathon'));
    await frames(tester);

    // Submitting an empty form shows what's missing.
    await tester.tap(find.text('Register and continue to payment'));
    await tester.pump();
    expect(find.text('Enter your mobile number.'), findsOneWidget);

    Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label);
    await tester.enterText(field('Full name'), 'Ana Reyes');
    await tester.enterText(field('Email'), 'ana@example.com');
    await tester.enterText(field('Mobile number'), '09170000000');
    await tester.tap(find.text('M'));
    await tester.enterText(field('Shipping address'), '1 Rizal St, Manila');
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('Register and continue to payment'));
    await frames(tester);

    expect(api.registeredWith?.shirtSize, 'M');
    expect(api.registeredWith?.fullName, 'Ana Reyes');
    // Straight on to payment.
    expect(find.text('Amount to pay: ₱499'), findsOneWidget);
    expect(find.text('GCash 0917 000 0000 · Juan Dela Cruz'), findsOneWidget);
  });

  testWidgets('payment needs a receipt and reference, then goes to review',
      (tester) async {
    usePhoneScreen(tester);
    final api = _FakeApi(_marathon(
      registration: const MyMarathonRegistration(
          status: MarathonRegistrationStatus.pendingPayment),
    ));
    await tester.pumpWidget(MaterialApp(
      home: MarathonPaymentScreen(
        marathon: api.current,
        api: api,
        pickReceipt: () async => Uint8List.fromList(
            // 1x1 transparent PNG.
            [
              137,
              80,
              78,
              71,
              13,
              10,
              26,
              10,
              0,
              0,
              0,
              13,
              73,
              72,
              68,
              82,
              0,
              0,
              0,
              1,
              0,
              0,
              0,
              1,
              8,
              6,
              0,
              0,
              0,
              31,
              21,
              196,
              137,
              0,
              0,
              0,
              13,
              73,
              68,
              65,
              84,
              120,
              156,
              99,
              0,
              1,
              0,
              0,
              5,
              0,
              1,
              13,
              10,
              45,
              180,
              0,
              0,
              0,
              0,
              73,
              69,
              78,
              68,
              174,
              66,
              96,
              130
            ]),
        uploadReceipt: (_) async => 'https://cdn.example.com/receipt.png',
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('Submit payment'));
    await tester.pump();
    expect(find.text('Attach a screenshot of your payment.'), findsOneWidget);

    await tester.tap(find.text('Tap to attach a screenshot'));
    await tester.pump();
    await tester.tap(find.text('Submit payment'));
    await tester.pump();
    expect(find.text('Enter the reference number from your receipt.'),
        findsOneWidget);

    await tester.enterText(find.byType(TextField), 'GC-123');
    await tester.tap(find.text('Submit payment'));
    await tester.pump();
    await tester.pump();

    expect(api.paidReference, 'GC-123');
    expect(api.paidProof, 'https://cdn.example.com/receipt.png');
  });

  testWidgets('confirmed runners see when it opens and can wear the kit',
      (tester) async {
    usePhoneScreen(tester);
    final saved = <Map<String, dynamic>>[];
    final api = _FakeApi(_marathon(
      registration: const MyMarathonRegistration(
        status: MarathonRegistrationStatus.confirmed,
        bibNumber: 7,
      ),
    ));
    await tester.pumpWidget(MaterialApp(
      home: MarathonDetailScreen(
        marathonId: '1',
        api: api,
        today: _today,
        kitSaver: (look) async => saved.add(look),
      ),
    ));
    await frames(tester);

    expect(find.text("✓ You're in!"), findsOneWidget);
    expect(find.text('BIB #7'), findsOneWidget);
    expect(find.textContaining('The race opens on Sun, Nov 1, 2026'),
        findsOneWidget);

    await scrollTo(tester, find.text('Wear the Sunrise kit in the steps race'));
    await tester.tap(find.text('Wear the Sunrise kit in the steps race'));
    await frames(tester);

    expect(saved.single['kit'], 'sunrise');
    expect(saved.single['bib'], 7);
    final prefs = await SharedPreferences.getInstance();
    expect(WalkerLook.fromJson(prefs.getString('step_race_look')).bib, 7);
    expect(find.text('Your walker is wearing the Sunrise kit'), findsOneWidget);
  });

  testWidgets('progress shows during the race and finishers get a certificate',
      (tester) async {
    usePhoneScreen(tester);
    final api = _FakeApi(_marathon(
      phase: MarathonPhase.ongoing,
      registration: const MyMarathonRegistration(
        status: MarathonRegistrationStatus.confirmed,
        bibNumber: 7,
        certificateNumber: 'IU-0001-00007',
        progress: MarathonProgress(
            steps: 15000, km: 10.05, percent: 100, finished: true),
      ),
    ));
    await tester.pumpWidget(MaterialApp(
      home: MarathonDetailScreen(marathonId: '1', api: api, today: _today),
    ));
    await frames(tester);

    expect(find.text('🏅 You finished!'), findsOneWidget);
    expect(find.text('10.05 of 10 km'), findsOneWidget);

    await scrollTo(tester, find.text('View virtual certificate'));
    await tester.tap(find.text('View virtual certificate'));
    await frames(tester);

    expect(find.text('CERTIFICATE OF COMPLETION'), findsOneWidget);
    expect(find.text('Ana Reyes'), findsOneWidget);
    expect(find.text('IU-0001-00007'), findsOneWidget);
  });

  testWidgets('admins approve and reject payments', (tester) async {
    usePhoneScreen(tester);
    final api = _FakeApi(_marathon());
    await tester.pumpWidget(MaterialApp(
      home: AdminMarathonsScreen(api: api),
    ));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Sunrise 10K'));
    await tester.pumpAndSettle();
    expect(find.text('Reference: GC-123'), findsOneWidget);

    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    expect(api.reviews, ['55:approve']);

    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Amount does not match');
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    expect(api.reviews.last, '55:reject:Amount does not match');
  });
}
