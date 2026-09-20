import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_notifications_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_notifications_service.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_header_profile_button.dart';

class _FakeNotificationsGateway implements AbundanceNotificationsGateway {
  var marked = <String>[];
  var markedAll = false;

  @override
  Future<List<AbundanceNotification>> load() async => <AbundanceNotification>[
        AbundanceNotification(
          id: 'n1',
          title: 'Quest updated',
          body: 'Your coach left feedback.',
          createdAt: DateTime(2026, 9, 15),
          isRead: false,
        ),
      ];

  @override
  Future<void> markAllRead() async => markedAll = true;

  @override
  Future<void> markRead(String id) async => marked.add(id);
}

class _UnreadNotificationsGateway implements AbundanceNotificationsGateway {
  @override
  Future<List<AbundanceNotification>> load() async => <AbundanceNotification>[
        AbundanceNotification(
          id: 'n1',
          title: 'New coaching note',
          body: 'Your coach sent a note.',
          createdAt: DateTime(2026, 9, 20),
          isRead: false,
          data: const <String, dynamic>{'coachingNoteId': 'note-1'},
        ),
      ];

  @override
  Future<void> markAllRead() async {}

  @override
  Future<void> markRead(String id) async {}
}

void main() {
  testWidgets('notification actions update the branded feed', (tester) async {
    final gateway = _FakeNotificationsGateway();
    await tester.pumpWidget(MaterialApp(
      home: AbundanceNotificationsScreen(gateway: gateway),
    ));
    await tester.pumpAndSettle();

    expect(find.text('NOTIFICATIONS'), findsOneWidget);
    expect(find.text('Quest updated'), findsOneWidget);
    await tester.tap(find.text('Quest updated'));
    await tester.pumpAndSettle();
    expect(gateway.marked, <String>['n1']);

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();
    expect(gateway.markedAll, isTrue);
  });

  testWidgets('notification tap forwards the selected update', (tester) async {
    final gateway = _FakeNotificationsGateway();
    AbundanceNotification? selected;
    await tester.pumpWidget(MaterialApp(
      home: AbundanceNotificationsScreen(
        gateway: gateway,
        onNotificationTap: (notification) => selected = notification,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quest updated'));
    await tester.pumpAndSettle();

    expect(selected?.id, 'n1');
  });

  testWidgets('unread notifications expose a visible indicator',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AbundanceNotificationBell(
          gateway: _UnreadNotificationsGateway(),
          onTap: () async {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('abundance-notification-badge')),
        findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
