import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_council_service.dart';

class _RecordingCouncilTransport implements AbundanceApiTransport {
  _RecordingCouncilTransport({this.usesCoachName = false});

  final bool usesCoachName;
  final requests = <String>[];

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    requests.add('GET $path');
    if (path == '/guild') {
      if (usesCoachName) {
        return const {'coachName': 'Lilian Agnas'};
      }
      return {
        'members': const [],
        'coach': {
          'id': 'coach-1',
          'name': 'Arlene Mae',
        },
        'councils': [
          {
            'id': 'council-1',
            'name': 'Dawn',
            'description': 'Rise together.',
            'coachName': 'Arlene Mae',
            'memberCount': 2.0,
            'averageScore': 34.4,
            'isCurrent': true,
          },
        ],
      };
    }
    return {
      'councils': [
        {
          'id': 'council-1',
          'name': 'Dawn',
          'description': 'Rise together.',
          'coachName': 'Arlene Mae',
          'memberCount': 2,
          'averageScore': 34,
          'isCurrent': true,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body,
      {String? token}) async {
    requests.add('POST $path ${body['councilId'] ?? ''}');
    return const <String, dynamic>{'ok': true};
  }

  @override
  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body,
          {String? token}) async =>
      const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async =>
      const <String, dynamic>{};
}

void main() {
  test('reads A12 guild and coach_groups council payloads', () async {
    final transport = _RecordingCouncilTransport();
    final service = AbundanceCouncilService(transport: transport);

    final current = await service.fetchCurrent();
    final assignedCoach = await service.fetchAssignedCoachName();
    final available = await service.fetchAvailable();
    await service.join('council-1');
    await service.leave();

    expect(current?.name, 'Dawn');
    expect(current?.memberCount, 2);
    expect(current?.averageScore, 34);
    expect(assignedCoach, 'Arlene Mae');
    expect(available.single.description, 'Rise together.');
    expect(transport.requests, [
      'GET /guild',
      'GET /guild',
      'GET /councils',
      'POST /guild/join council-1',
      'POST /guild/leave ',
    ]);
  });

  test('reads coachName when the guild response does not include a coach map',
      () async {
    final service = AbundanceCouncilService(
      transport: _RecordingCouncilTransport(usesCoachName: true),
    );

    expect(await service.fetchAssignedCoachName(), 'Lilian Agnas');
  });
}
