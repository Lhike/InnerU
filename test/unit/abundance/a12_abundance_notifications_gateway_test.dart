import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_notifications_service.dart';

class _RecordingTransport implements AbundanceApiTransport {
  final paths = <String>[];

  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async =>
      const {};

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    paths.add(path);
    return const {
      'items': [
        {
          'id': 'note-1',
          'type': 'COACHING_NOTE',
          'title': 'New coaching note',
          'body': 'Your coach sent a note.',
          'isRead': false,
          'createdAt': '2026-09-20T10:00:00.000Z',
          'metadata': {'coachingNoteId': 'note-1'},
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    paths.add(path);
    return const {};
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async =>
      const {};
}

void main() {
  test('A12 notifications retain coaching metadata and mark records read',
      () async {
    final transport = _RecordingTransport();
    final gateway = A12AbundanceNotificationsGateway(transport: transport);

    final notifications = await gateway.load();

    expect(transport.paths, ['/notifications']);
    expect(notifications.single.data, {'coachingNoteId': 'note-1'});

    await gateway.markRead('note-1');
    expect(transport.paths.last, '/notifications/note-1/read');

    await gateway.markAllRead();
    expect(
        transport.paths.where((path) => path.endsWith('/read')), hasLength(2));
  });
}
