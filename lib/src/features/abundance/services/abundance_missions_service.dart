import 'package:selfcare_projects/src/features/authentication/screen/todo_list.dart';
import 'package:flutter/material.dart';
import 'package:selfcare_projects/src/services/todo_task_api_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';

abstract interface class AbundanceMissionsGateway {
  Future<List<Task>> load({DateTime? date});
  Future<void> create(Task task);
  Future<void> update(Task task, {DateTime? day});
  Future<void> delete(String id);
}

class AbundanceMissionDaySummary {
  const AbundanceMissionDaySummary({
    required this.date,
    required this.completed,
    required this.total,
    required this.percent,
  });

  final DateTime date;
  final int completed;
  final int total;
  final int percent;
}

abstract interface class AbundanceMissionCalendarState {
  Map<DateTime, AbundanceMissionDaySummary> get daySummaries;
}

class InnerUAbundanceMissionsGateway implements AbundanceMissionsGateway {
  InnerUAbundanceMissionsGateway({TodoTaskApiService? api})
      : _api = api ?? TodoTaskApiService.instance;

  final TodoTaskApiService _api;

  @override
  Future<List<Task>> load({DateTime? date}) async =>
      (await _api.fetchTasks()).map(Task.fromJson).toList();

  @override
  Future<void> create(Task task) async {
    final saved = await _api.saveTask(_payload(task));
    task.id = saved['id']?.toString() ?? task.id;
  }

  @override
  Future<void> update(Task task, {DateTime? day}) async {
    await _api.updateTask(task.id, _payload(task));
  }

  @override
  Future<void> delete(String id) => _api.deleteTask(id);

  Map<String, dynamic> _payload(Task task) => <String, dynamic>{
        'title': task.title,
        'description': task.description,
        'goal_type': task.goalType.storageValue,
        'start_date': task.startDate.toIso8601String(),
        'due_date': task.dueDate.toIso8601String(),
        'tag': task.tag.name,
        'tag_index': task.tag.index,
        'is_completed': task.isCompleted,
        'completed_at': task.completedAt?.toIso8601String(),
        'scheduled_time': task.scheduledTime,
        'completion_dates':
            task.completionDates.map((date) => date.toIso8601String()).toList(),
        'sub_tasks': task.subTasks.map((item) => item.toJson()).toList(),
      };
}

/// A12-owned mission gateway. The mobile API owns the mission rows and their
/// completion history; this adapter only translates the server DTO to the
/// existing Flutter mission model used by the shared calendar widgets.
class A12AbundanceMissionsGateway
    implements AbundanceMissionsGateway, AbundanceMissionCalendarState {
  A12AbundanceMissionsGateway({AbundanceApiTransport? transport})
      : _transport = transport ?? A12ApiTransport();

  final AbundanceApiTransport _transport;
  Map<DateTime, AbundanceMissionDaySummary> _daySummaries =
      const <DateTime, AbundanceMissionDaySummary>{};
  String? _summaryMonth;

  @override
  Map<DateTime, AbundanceMissionDaySummary> get daySummaries => _daySummaries;

  String get _token => AuthService.instance.currentSession?.token ?? '';

  @override
  Future<List<Task>> load({DateTime? date}) async {
    final day = _day(date ?? DateTime.now());
    final month = day.substring(0, 7);
    if (_summaryMonth != month) {
      _summaryMonth = month;
      _daySummaries = const <DateTime, AbundanceMissionDaySummary>{};
    }
    final response = await _transport.getJson(
      '/missions?date=$day&month=$month',
      token: _token,
    );
    final rawDays = response['days'];
    if (rawDays is List) {
      final summaries = <DateTime, AbundanceMissionDaySummary>{
        ..._daySummaries,
      };
      for (final raw in rawDays.whereType<Map>()) {
        if (DateTime.tryParse(raw['date']?.toString() ?? '')
            case final parsed?) {
          final normalized = DateUtils.dateOnly(parsed);
          summaries[normalized] = AbundanceMissionDaySummary(
            date: normalized,
            completed: _integer(raw['completed']),
            total: _integer(raw['total']),
            percent: _integer(raw['percent']),
          );
        }
      }
      _daySummaries = summaries;
    }
    final raw = response['items'];
    if (raw is! List) return const <Task>[];
    return raw
        .whereType<Map>()
        .map((item) => _taskFromA12(Map<String, dynamic>.from(item), day))
        .toList(growable: false);
  }

  @override
  Future<void> create(Task task) async {
    final response = await _transport.postJson(
        '/missions',
        {
          'name': task.title,
          'description': task.description,
          'date': _day(task.startDate),
          'category': _category(task.tag),
          'scheduledTime': task.scheduledTime,
          'icon': 'book-open',
        },
        token: _token);
    task.id = (response['taskId'] ?? response['id'] ?? task.id).toString();
  }

  @override
  Future<void> update(Task task, {DateTime? day}) async {
    final selectedDay = _day(day ?? DateTime.now());
    await _transport.postJson(
        '/missions/${Uri.encodeComponent(task.id)}/completion',
        {
          'completed':
              task.completionDates.any((date) => _day(date) == selectedDay),
        },
        token: _token);
  }

  @override
  Future<void> delete(String id) async {
    await _transport.deleteJson(
      '/missions/${Uri.encodeComponent(id)}',
      token: _token,
    );
  }

  Task _taskFromA12(Map<String, dynamic> item, String day) {
    final completed = item['completed'] == true;
    final history = item['history'];
    final completionDates = <DateTime>[];
    if (completed) completionDates.add(DateTime.parse(day));
    if (history is List) {
      for (final entry in history.whereType<Map>()) {
        if (entry['completed'] == true && entry['date'] != null) {
          final parsed = DateTime.tryParse(entry['date'].toString());
          if (parsed != null) completionDates.add(DateUtils.dateOnly(parsed));
        }
      }
    }
    return Task(
      id: (item['taskId'] ?? item['id'] ?? '').toString(),
      title: (item['name'] ?? item['title'] ?? '').toString(),
      description: (item['description'] ?? '').toString(),
      goalType: GoalType.everyday,
      startDate: DateTime.parse(day),
      dueDate: DateTime.parse(day),
      isCompleted: completed,
      tag: _tag(item['category']),
      completedAt: item['completedAt'] == null
          ? null
          : DateTime.tryParse(item['completedAt'].toString()),
      scheduledTime: item['scheduledTime']?.toString(),
      completionDates: completionDates.toSet().toList(),
    );
  }

  TaskTag _tag(dynamic category) {
    switch (category?.toString().toUpperCase()) {
      case 'EXERCISE':
        return TaskTag.personal;
      case 'COACHING_CALL':
        return TaskTag.contribution;
      case 'MEDITATION':
      case 'LEARNING':
      default:
        return TaskTag.none;
    }
  }

  String _category(TaskTag tag) {
    switch (tag) {
      case TaskTag.personal:
        return 'EXERCISE';
      case TaskTag.contribution:
        return 'COACHING_CALL';
      case TaskTag.professional:
      case TaskTag.none:
        return 'LEARNING';
    }
  }

  String _day(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

int _integer(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
