import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_coaching_note_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_coach_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_notifications_service.dart';

class _NoopTransport implements AbundanceApiTransport {
  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async =>
      const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async =>
      const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async =>
      const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async =>
      const <String, dynamic>{};
}

class _LinkedNoteService extends AbundanceCoachService {
  _LinkedNoteService() : super(transport: _NoopTransport());

  @override
  Future<Map<String, dynamic>> fetchMyCoachingNote(String noteId) async =>
      <String, dynamic>{
        'id': noteId,
        'body': 'Good job — keep going.',
        'createdAt': '2026-09-20T15:45:57.000Z',
      };

  @override
  Future<List<Map<String, dynamic>>> fetchMyCoachingNotes() async =>
      const <Map<String, dynamic>>[];

  @override
  Future<List<Map<String, dynamic>>> fetchMyCoachingActionItems() async =>
      const <Map<String, dynamic>>[];
}

void main() {
  testWidgets('opens the exact coaching note linked by the notification',
      (tester) async {
    final notification = AbundanceNotification(
      id: 'notification-1',
      title: 'New coaching note',
      body: 'Your coach sent you a coaching note.',
      createdAt: DateTime(2026, 9, 20),
      isRead: true,
      data: const <String, dynamic>{'coachingNoteId': 'note-1'},
    );

    await tester.pumpWidget(MaterialApp(
      home: AbundanceCoachingNoteScreen(
        notification: notification,
        coachService: _LinkedNoteService(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Good job — keep going.'), findsOneWidget);
    expect(find.text('This coaching update is no longer available.'),
        findsNothing);
  });
}
