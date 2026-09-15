import 'package:selfcare_projects/src/features/authentication/screen/todo_list.dart';
import 'package:selfcare_projects/src/services/todo_task_api_service.dart';

abstract interface class AbundanceMissionsGateway {
  Future<List<Task>> load();
  Future<void> create(Task task);
  Future<void> update(Task task);
  Future<void> delete(String id);
}

class InnerUAbundanceMissionsGateway implements AbundanceMissionsGateway {
  InnerUAbundanceMissionsGateway({TodoTaskApiService? api})
      : _api = api ?? TodoTaskApiService.instance;

  final TodoTaskApiService _api;

  @override
  Future<List<Task>> load() async =>
      (await _api.fetchTasks()).map(Task.fromJson).toList();

  @override
  Future<void> create(Task task) async {
    final saved = await _api.saveTask(_payload(task));
    task.id = saved['id']?.toString() ?? task.id;
  }

  @override
  Future<void> update(Task task) async {
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
