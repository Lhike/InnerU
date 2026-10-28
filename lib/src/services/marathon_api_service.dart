import 'package:flutter/foundation.dart';
import 'package:selfcare_projects/src/services/api_client.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';

enum MarathonPhase { upcoming, ongoing, ended }

/// Whether people can join yet.
enum MarathonRegistrationWindow { notYet, open, closed }

Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;

/// Where a runner's registration stands.
enum MarathonRegistrationStatus {
  pendingPayment('pending_payment'),
  paymentSubmitted('payment_submitted'),
  confirmed('confirmed'),
  rejected('rejected');

  const MarathonRegistrationStatus(this.apiValue);
  final String apiValue;

  static MarathonRegistrationStatus fromApi(String? value) =>
      values.firstWhere((s) => s.apiValue == value,
          orElse: () => MarathonRegistrationStatus.pendingPayment);
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

double _double(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

String? _text(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

int? _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}');

class MarathonProgress {
  const MarathonProgress({
    this.steps = 0,
    this.km = 0,
    this.percent = 0,
    this.finished = false,
  });

  final int steps;
  final double km;
  final double percent;
  final bool finished;

  factory MarathonProgress.fromJson(Map<String, dynamic> json) =>
      MarathonProgress(
        steps: _int(json['steps']) ?? 0,
        km: _double(json['km']),
        percent: _double(json['percent']),
        finished: json['finished'] == true,
      );
}

class MyMarathonRegistration {
  const MyMarathonRegistration({
    required this.status,
    this.fullName,
    this.shirtSize,
    this.bibNumber,
    this.rejectionReason,
    this.paymentReference,
    this.finishedAt,
    this.certificateNumber,
    this.rewardsShippedAt,
    this.progress = const MarathonProgress(),
  });

  final MarathonRegistrationStatus status;
  final String? fullName;
  final String? shirtSize;
  final int? bibNumber;
  final String? rejectionReason;
  final String? paymentReference;
  final DateTime? finishedAt;
  final String? certificateNumber;
  final DateTime? rewardsShippedAt;
  final MarathonProgress progress;

  bool get isConfirmed => status == MarathonRegistrationStatus.confirmed;
  bool get isFinisher => certificateNumber != null || progress.finished;

  factory MyMarathonRegistration.fromJson(Map<String, dynamic> json) =>
      MyMarathonRegistration(
        status: MarathonRegistrationStatus.fromApi(json['status']?.toString()),
        fullName: json['fullName']?.toString(),
        shirtSize: json['shirtSize']?.toString(),
        bibNumber: _int(json['bibNumber']),
        rejectionReason: json['rejectionReason']?.toString(),
        paymentReference: json['paymentReference']?.toString(),
        finishedAt: _date(json['finishedAt']),
        certificateNumber: json['certificateNumber']?.toString(),
        rewardsShippedAt: _date(json['rewardsShippedAt']),
        progress: json['progress'] is Map
            ? MarathonProgress.fromJson(
                Map<String, dynamic>.from(json['progress'] as Map))
            : const MarathonProgress(),
      );
}

class Marathon {
  const Marathon({
    required this.id,
    required this.title,
    required this.theme,
    required this.distanceKm,
    required this.price,
    required this.currency,
    required this.startsAt,
    required this.endsAt,
    required this.phase,
    this.description,
    this.themeData,
    this.kitImageUrl,
    this.registrationOpensAt,
    this.registrationClosesAt,
    this.registrationWindow = MarathonRegistrationWindow.open,
    this.paymentInstructions,
    this.paymentQrUrl,
    this.isPublished = true,
    this.myRegistration,
    this.registrationCount = 0,
    this.pendingReviewCount = 0,
  });

  final String id;
  final String title;
  final String? description;
  final String theme;

  /// Colours and kit of an AI-made ('custom') theme.
  final Map<String, dynamic>? themeData;

  /// A picture of the kit, when the AI drew one.
  final String? kitImageUrl;
  final double distanceKm;
  final double price;
  final String currency;
  final DateTime startsAt;
  final DateTime endsAt;
  final MarathonPhase phase;

  /// Null opens right away.
  final DateTime? registrationOpensAt;

  /// Last day to join; the race's end unless the organizer set one.
  final DateTime? registrationClosesAt;
  final MarathonRegistrationWindow registrationWindow;
  final String? paymentInstructions;

  /// QR code runners scan to pay.
  final String? paymentQrUrl;
  final bool isPublished;
  final MyMarathonRegistration? myRegistration;

  /// Admin listing only.
  final int registrationCount;
  final int pendingReviewCount;

  bool get isFree => price <= 0;

  factory Marathon.fromJson(Map<String, dynamic> json) => Marathon(
        id: json['id'].toString(),
        title: json['title']?.toString() ?? 'Marathon',
        description: json['description']?.toString(),
        theme: json['theme']?.toString() ?? 'sunrise',
        themeData: _map(json['themeData']),
        kitImageUrl: _text(json['kitImageUrl']),
        distanceKm: _double(json['distanceKm']),
        price: _double(json['price']),
        currency: json['currency']?.toString() ?? 'PHP',
        startsAt: _date(json['startsAt']) ?? DateTime.now(),
        endsAt: _date(json['endsAt']) ?? DateTime.now(),
        phase: MarathonPhase.values.firstWhere(
          (p) => p.name == json['phase'],
          orElse: () => MarathonPhase.upcoming,
        ),
        registrationOpensAt: _date(json['registrationOpensAt']),
        registrationClosesAt: _date(json['registrationClosesAt']),
        registrationWindow: switch (json['registrationStatus']) {
          'not_yet' => MarathonRegistrationWindow.notYet,
          'closed' => MarathonRegistrationWindow.closed,
          _ => MarathonRegistrationWindow.open,
        },
        paymentInstructions: json['paymentInstructions']?.toString(),
        paymentQrUrl: _text(json['paymentQrUrl']),
        isPublished: json['isPublished'] != false,
        myRegistration: json['myRegistration'] is Map
            ? MyMarathonRegistration.fromJson(
                Map<String, dynamic>.from(json['myRegistration'] as Map))
            : null,
        registrationCount: _int(json['registrationCount']) ?? 0,
        pendingReviewCount: _int(json['pendingReviewCount']) ?? 0,
      );
}

class MarathonCertificate {
  const MarathonCertificate({
    required this.number,
    required this.runnerName,
    required this.marathonTitle,
    required this.theme,
    required this.distanceKm,
    this.themeData,
    this.bibNumber,
    this.finishedAt,
  });

  final String number;
  final String runnerName;
  final String marathonTitle;
  final String theme;
  final Map<String, dynamic>? themeData;
  final double distanceKm;
  final int? bibNumber;
  final DateTime? finishedAt;

  factory MarathonCertificate.fromJson(Map<String, dynamic> json) =>
      MarathonCertificate(
        number: json['number'].toString(),
        runnerName: json['runnerName']?.toString() ?? '',
        marathonTitle: json['marathonTitle']?.toString() ?? '',
        theme: json['theme']?.toString() ?? 'sunrise',
        themeData: _map(json['themeData']),
        distanceKm: _double(json['distanceKm']),
        bibNumber: _int(json['bibNumber']),
        finishedAt: _date(json['finishedAt']),
      );
}

/// A runner's registration as admins review it.
class AdminMarathonRegistration {
  const AdminMarathonRegistration({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.shirtSize,
    required this.shippingAddress,
    required this.status,
    this.paymentReference,
    this.paymentProofUrl,
    this.rejectionReason,
    this.bibNumber,
    this.finishedAt,
    this.rewardsShippedAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String shirtSize;
  final String shippingAddress;
  final MarathonRegistrationStatus status;
  final String? paymentReference;
  final String? paymentProofUrl;
  final String? rejectionReason;
  final int? bibNumber;
  final DateTime? finishedAt;
  final DateTime? rewardsShippedAt;

  factory AdminMarathonRegistration.fromJson(Map<String, dynamic> json) =>
      AdminMarathonRegistration(
        id: json['id'].toString(),
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        shirtSize: json['shirtSize']?.toString() ?? '',
        shippingAddress: json['shippingAddress']?.toString() ?? '',
        status: MarathonRegistrationStatus.fromApi(json['status']?.toString()),
        paymentReference: json['paymentReference']?.toString(),
        paymentProofUrl: json['paymentProofUrl']?.toString(),
        rejectionReason: json['rejectionReason']?.toString(),
        bibNumber: _int(json['bibNumber']),
        finishedAt: _date(json['finishedAt']),
        rewardsShippedAt: _date(json['rewardsShippedAt']),
      );
}

/// One runner on a marathon's race track.
class MarathonRunner {
  const MarathonRunner({
    required this.userId,
    required this.name,
    required this.km,
    required this.rank,
    this.steps = 0,
    this.percent = 0,
    this.finished = false,
    this.profilePic,
    this.walkerLook,
    this.bibNumber,
  });

  final String userId;
  final String name;
  final double km;
  final int rank;
  final int steps;
  final double percent;
  final bool finished;
  final String? profilePic;
  final Map<String, dynamic>? walkerLook;
  final int? bibNumber;

  factory MarathonRunner.fromJson(Map<String, dynamic> json) => MarathonRunner(
        userId: json['userId'].toString(),
        name: json['name']?.toString() ?? 'Runner',
        km: _double(json['km']),
        rank: _int(json['rank']) ?? 0,
        steps: _int(json['steps']) ?? 0,
        percent: _double(json['percent']),
        finished: json['finished'] == true,
        profilePic: json['profilePic']?.toString(),
        walkerLook: json['walkerLook'] is Map
            ? Map<String, dynamic>.from(json['walkerLook'] as Map)
            : null,
        bibNumber: _int(json['bibNumber']),
      );
}

/// A marathon with everyone racing in it.
class MarathonRace {
  const MarathonRace({required this.marathon, required this.runners});

  final Marathon marathon;
  final List<MarathonRunner> runners;
}

class MarathonRegistrationForm {
  const MarathonRegistrationForm({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.shirtSize,
    required this.shippingAddress,
  });

  final String fullName;
  final String email;
  final String phone;
  final String shirtSize;
  final String shippingAddress;

  static const shirtSizes = ['XS', 'S', 'M', 'L', 'XL', '2XL', '3XL'];

  Map<String, dynamic> toJson() => {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'shirt_size': shirtSize,
        'shipping_address': shippingAddress,
      };
}

class MarathonApiService {
  MarathonApiService._();

  /// For test fakes that override the calls.
  @visibleForTesting
  MarathonApiService.forTesting();

  static final MarathonApiService instance = MarathonApiService._();

  final ApiClient _api = ApiClient.instance;
  String? get _token => AuthService.instance.currentSession?.token;

  List<Marathon> _list(Map<String, dynamic> response) =>
      (response['marathons'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => Marathon.fromJson(Map<String, dynamic>.from(m)))
          .toList();

  Marathon _one(Map<String, dynamic> response) =>
      Marathon.fromJson(Map<String, dynamic>.from(response['marathon'] as Map));

  Future<List<Marathon>> fetchMarathons() async =>
      _list(await _api.getJson('/api/marathons', token: _token));

  Future<Marathon> fetchMarathon(String id) async =>
      _one(await _api.getJson('/api/marathons/$id', token: _token));

  Future<Marathon> register(String id, MarathonRegistrationForm form) async =>
      _one(await _api.postJson('/api/marathons/$id/register', form.toJson(),
          token: _token));

  Future<Marathon> submitPayment(
    String id, {
    required String reference,
    required String proofUrl,
  }) async =>
      _one(await _api.postJson(
        '/api/marathons/$id/payment',
        {'payment_reference': reference, 'payment_proof_url': proofUrl},
        token: _token,
      ));

  Future<MarathonRace> fetchRace(String id) async {
    final response =
        await _api.getJson('/api/marathons/$id/leaderboard', token: _token);
    return MarathonRace(
      marathon: _one(response),
      runners: (response['runners'] as List? ?? const [])
          .whereType<Map>()
          .map((r) => MarathonRunner.fromJson(Map<String, dynamic>.from(r)))
          .toList(),
    );
  }

  Future<MarathonCertificate> fetchCertificate(String id) async {
    final response =
        await _api.getJson('/api/marathons/$id/certificate', token: _token);
    return MarathonCertificate.fromJson(
        Map<String, dynamic>.from(response['certificate'] as Map));
  }

  // Admin

  Future<List<Marathon>> adminFetchMarathons() async =>
      _list(await _api.getJson('/api/admin/marathons', token: _token));

  Future<Marathon> adminSaveMarathon(
    Map<String, dynamic> fields, {
    String? id,
  }) async =>
      _one(id == null
          ? await _api.postJson('/api/admin/marathons', fields, token: _token)
          : await _api.patchJson('/api/admin/marathons/$id', fields,
              token: _token));

  /// Asks the AI for a theme from [prompt]; returns theme data for a
  /// 'custom' marathon. Throws [ApiException] with a readable message.
  Future<Map<String, dynamic>> adminSuggestTheme(String prompt) async {
    final response = await _api.postJson(
      '/api/admin/marathons/ai/theme',
      {'prompt': prompt},
      token: _token,
      timeout: const Duration(seconds: 60),
    );
    return Map<String, dynamic>.from(response['theme'] as Map);
  }

  /// Asks the AI to draw [themeData]'s kit; returns the picture's URL.
  Future<String> adminDrawKit(
      String prompt, Map<String, dynamic> themeData) async {
    final response = await _api.postJson(
      '/api/admin/marathons/ai/kit-image',
      {'prompt': prompt, 'theme_data': themeData},
      token: _token,
      timeout: const Duration(seconds: 170),
    );
    return response['kitImageUrl'].toString();
  }

  /// Deletes the marathon and everyone's registration for it.
  Future<void> adminDeleteMarathon(String id) async {
    await _api.deleteJson('/api/admin/marathons/$id', token: _token);
  }

  Future<List<AdminMarathonRegistration>> adminFetchRegistrations(
      String marathonId) async {
    final response = await _api.getJson(
        '/api/admin/marathons/$marathonId/registrations',
        token: _token);
    return (response['registrations'] as List? ?? const [])
        .whereType<Map>()
        .map((r) =>
            AdminMarathonRegistration.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// [action] is approve, reject or mark_shipped.
  Future<void> adminReview(
    String registrationId,
    String action, {
    String? reason,
  }) async {
    await _api.postJson(
      '/api/admin/marathon-registrations/$registrationId/review',
      {'action': action, if (reason != null) 'reason': reason},
      token: _token,
    );
  }
}
