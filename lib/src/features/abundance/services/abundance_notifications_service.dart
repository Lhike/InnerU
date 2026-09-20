import 'package:selfcare_projects/src/services/notification_api_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';

class AbundanceNotification {
  const AbundanceNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.data,
  });

  factory AbundanceNotification.fromJson(Map<String, dynamic> json) {
    final readValue = json['isRead'] ?? json['is_read'];
    final readAt = json['readAt'] ?? json['read_at'];
    return AbundanceNotification(
      id: json['id']?.toString() ?? '',
      title: (json['title'] ?? json['type'] ?? 'InnerU update').toString(),
      body: (json['body'] ?? json['message'] ?? '').toString(),
      createdAt: DateTime.tryParse(
        (json['createdAt'] ?? json['created_at'] ?? '').toString(),
      ),
      isRead: readValue == true || readValue == 1 || readAt != null,
      data: _notificationData(json),
    );
  }

  final String id;
  final String title;
  final String body;
  final DateTime? createdAt;
  final bool isRead;
  final Map<String, dynamic>? data;

  AbundanceNotification copyWith({bool? isRead}) => AbundanceNotification(
        id: id,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
        data: data,
      );
}

Map<String, dynamic>? _notificationData(Map<String, dynamic> json) {
  final raw = json['metadata'] ?? json['data'];
  if (raw is Map) return Map<String, dynamic>.from(raw);
  return null;
}

abstract interface class AbundanceNotificationsGateway {
  Future<List<AbundanceNotification>> load();
  Future<void> markRead(String id);
  Future<void> markAllRead();
}

class InnerUAbundanceNotificationsGateway
    implements AbundanceNotificationsGateway {
  InnerUAbundanceNotificationsGateway({NotificationApiService? api})
      : _api = api ?? NotificationApiService.instance;

  final NotificationApiService _api;

  @override
  Future<List<AbundanceNotification>> load() async {
    final response = await _api.fetchNotifications();
    final raw = response['notifications'];
    if (raw is! List) return const <AbundanceNotification>[];
    return raw
        .whereType<Map>()
        .map((item) => AbundanceNotification.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .toList(growable: false);
  }

  @override
  Future<void> markAllRead() => _api.markAllRead();

  @override
  Future<void> markRead(String id) => _api.markRead(id);
}

/// A12-owned notification feed for the ABU15DN Abundance experience.
///
/// Notifications, their read state, and coaching-note metadata stay in the
/// shared A12 service so a student sees exactly the same updates in every
/// authorized Abundance client.
class A12AbundanceNotificationsGateway
    implements AbundanceNotificationsGateway {
  A12AbundanceNotificationsGateway({AbundanceApiTransport? transport})
      : _transport = transport ?? A12ApiTransport();

  final AbundanceApiTransport _transport;
  List<AbundanceNotification> _lastLoaded = const [];

  @override
  Future<List<AbundanceNotification>> load() async {
    final response = await _transport.getJson('/notifications');
    final raw = response['items'];
    _lastLoaded = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => AbundanceNotification.fromJson(
                  Map<String, dynamic>.from(item),
                ))
            .toList(growable: false)
        : const [];
    return _lastLoaded;
  }

  @override
  Future<void> markRead(String id) =>
      _transport.patchJson('/notifications/$id/read', const {});

  @override
  Future<void> markAllRead() async {
    final unreadIds = _lastLoaded
        .where((notification) =>
            !notification.isRead && notification.id.isNotEmpty)
        .map((notification) => notification.id);
    await Future.wait(unreadIds.map(markRead));
  }
}
