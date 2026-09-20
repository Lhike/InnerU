import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_missions_service.dart';
import 'package:selfcare_projects/src/features/authentication/screen/todo_list.dart';

class _Transport implements AbundanceApiTransport {
  final requests = <String>[];

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    requests.add('GET $path');
    return {
      'items': [
        {
          'taskId': 'mission-7',
          'name': 'Walk outside',
          'description': 'Take a short walk.',
          'completed': true,
          'completedAt': '2026-09-20T08:00:00Z',
          'category': 'EXERCISE',
          'history': [
            {'date': '2026-09-20', 'completed': true},
          ],
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    requests.add('POST $path ${body['completed'] ?? body['name']}');
    return {'taskId': 'mission-7'};
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async =>
      <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async {
    requests.add('DELETE $path');
    return <String, dynamic>{};
  }
}

void main() {
  test('A12 mission gateway reads and completes source records', () async {
    final transport = _Transport();
    final gateway = A12AbundanceMissionsGateway(transport: transport);

    final selectedDay = DateTime(2026, 9, 22);
    final tasks = await gateway.load(date: selectedDay);
    expect(tasks, hasLength(1));
    expect(tasks.single.title, 'Walk outside');
    expect(tasks.single.goalType.name, 'everyday');
    expect(tasks.single.isCompleted, isTrue);
    expect(tasks.single.completionDates, isNotEmpty);

    await gateway.update(tasks.single, day: selectedDay);
    expect(transport.requests,
        contains('GET /missions?date=2026-09-22&month=2026-09'));
    expect(transport.requests,
        contains('POST /missions/mission-7/completion true'));
  });

  test('A12 mission gateway deletes a source mission', () async {
    final transport = _Transport();
    final gateway = A12AbundanceMissionsGateway(transport: transport);

    await gateway.delete('mission-7');

    expect(transport.requests, contains('DELETE /missions/mission-7'));
  });
}
