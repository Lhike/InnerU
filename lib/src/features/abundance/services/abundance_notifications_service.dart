import 'package:selfcare_projects/src/services/notification_api_service.dart';

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
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : null,
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
