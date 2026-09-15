import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_notifications_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_notifications_service.dart';

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
}
