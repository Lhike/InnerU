import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';

class AbundanceCouncil {
  const AbundanceCouncil({
    required this.id,
    required this.name,
    required this.description,
    required this.coachName,
    required this.memberCount,
    required this.averageScore,
    required this.isCurrent,
  });

  final String id;
  final String name;
  final String? description;
  final String coachName;
  final int memberCount;
  final int averageScore;
  final bool isCurrent;

  factory AbundanceCouncil.fromJson(Map<String, dynamic> json) {
    return AbundanceCouncil(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      coachName: json['coachName']?.toString() ?? '',
      memberCount: _intValue(json['memberCount']),
      averageScore: _intValue(json['averageScore']),
      isCurrent: json['isCurrent'] == true,
    );
  }

  static int _intValue(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

/// Typed client for the A12 council tables. This deliberately uses the A12
/// session transport rather than InnerU's legacy coach-group endpoints.
class AbundanceCouncilService {
  AbundanceCouncilService({AbundanceApiTransport? transport})
      : _transport = transport ?? A12ApiTransport();

  final AbundanceApiTransport _transport;

  Future<List<AbundanceCouncil>> fetchAvailable() async {
    final response = await _transport.getJson('/councils');
    final raw = response['councils'];
    if (raw is! List) return const <AbundanceCouncil>[];
    return raw
        .whereType<Map>()
        .map((item) =>
            AbundanceCouncil.fromJson(Map<String, dynamic>.from(item)))
        .where((council) => council.id.isNotEmpty && council.name.isNotEmpty)
        .toList(growable: false);
  }

  Future<AbundanceCouncil?> fetchCurrent() async {
    final response = await _transport.getJson('/guild');
    final raw = response['councils'];
    if (raw is! List) return null;
    for (final item in raw.whereType<Map>()) {
      final council =
          AbundanceCouncil.fromJson(Map<String, dynamic>.from(item));
      if (council.isCurrent || council.id.isNotEmpty) return council;
    }
    return null;
  }

  Future<void> join(String councilId) async {
    await _transport.postJson('/guild/join', {'councilId': councilId});
  }

  Future<void> leave() async {
    await _transport.postJson('/guild/leave', const <String, dynamic>{});
  }
}
