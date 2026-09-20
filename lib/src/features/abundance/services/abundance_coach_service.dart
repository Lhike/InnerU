import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';

/// Coach-scoped A12 operations. The A12 API verifies that the student belongs
/// to the authenticated Coach before returning or changing a record.
class AbundanceCoachService {
  AbundanceCoachService({AbundanceApiTransport? transport})
      : _transport = transport ?? A12ApiTransport();

  final AbundanceApiTransport _transport;

  Future<List<Map<String, dynamic>>> fetchStudentNotes(String studentId) async {
    final response =
        await _transport.getJson('/coach/students/$studentId/notes');
    return _records(response['notes']);
  }

  Future<List<Map<String, dynamic>>> fetchStudentActionItems(
      String studentId) async {
    final response =
        await _transport.getJson('/coach/students/$studentId/action-items');
    return _records(response['items']);
  }

  /// Student-facing coaching records also live in A12. These are deliberately
  /// separate from the Coach-scoped endpoints above: A12 verifies the current
  /// student identity before returning the record.
  Future<List<Map<String, dynamic>>> fetchMyCoachingNotes() async {
    final response = await _transport.getJson('/coaching-notes');
    return _records(response['notes']);
  }

  Future<List<Map<String, dynamic>>> fetchMyCoachingActionItems() async {
    final response = await _transport.getJson('/coaching-action-items');
    return _records(response['items']);
  }

  Future<Map<String, dynamic>> createStudentNote(
    String studentId,
    String body,
  ) =>
      _transport.postJson('/coach/students/$studentId/notes', {'body': body});

  Future<Map<String, dynamic>> createStudentActionItem(
    String studentId, {
    required String title,
    String? dueDate,
  }) =>
      _transport.postJson('/coach/students/$studentId/action-items', {
        'title': title,
        if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
      });

  List<Map<String, dynamic>> _records(Object? raw) => raw is List
      ? raw
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false)
      : const <Map<String, dynamic>>[];
}
