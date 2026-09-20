import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_coach_service.dart';

class _RecordingTransport implements AbundanceApiTransport {
  String? path;
  Map<String, dynamic>? body;

  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async =>
      const {};

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    this.path = path;
    return const {
      'notes': [
        {'id': 'note-1', 'body': 'Keep going.'}
      ]
    };
  }

  @override
  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body,
          {String? token}) async =>
      const {};

  @override
  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body,
      {String? token}) async {
    this.path = path;
    this.body = body;
    return {'id': 'note-1', ...body};
  }
}

void main() {
  test('coach notes and action items use assigned-student A12 endpoints',
      () async {
    final transport = _RecordingTransport();
    final service = AbundanceCoachService(transport: transport);

    final notes = await service.fetchStudentNotes('student-1');
    expect(notes.single['body'], 'Keep going.');
    expect(transport.path, '/coach/students/student-1/notes');

    await service.createStudentNote('student-1', 'Follow up tomorrow.');
    expect(transport.path, '/coach/students/student-1/notes');
    expect(transport.body, {'body': 'Follow up tomorrow.'});

    await service.createStudentActionItem(
      'student-1',
      title: 'Complete the reflection',
      dueDate: '2026-09-30',
    );
    expect(transport.path, '/coach/students/student-1/action-items');
    expect(transport.body, {
      'title': 'Complete the reflection',
      'dueDate': '2026-09-30',
    });

    await service.fetchMyCoachingNotes();
    expect(transport.path, '/coaching-notes');

    await service.fetchMyCoachingActionItems();
    expect(transport.path, '/coaching-action-items');
  });

  test('student note details use the notification-linked A12 record', () async {
    final transport = _RecordingTransport();
    final service = AbundanceCoachService(transport: transport);

    await service.fetchMyCoachingNote('note-1');

    expect(transport.path, '/coaching-notes/note-1');
  });
}
