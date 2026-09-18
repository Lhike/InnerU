import 'package:selfcare_projects/src/services/api_client.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';

class AbundanceAdminSnapshot {
  const AbundanceAdminSnapshot({required this.coaches, required this.students});
  final List<AbundanceAdminCoach> coaches;
  final List<AbundanceAdminStudent> students;
  factory AbundanceAdminSnapshot.fromJson(Map<String, dynamic> json) =>
      AbundanceAdminSnapshot(
        coaches: (json['coaches'] as List? ?? [])
            .whereType<Map>()
            .map((e) =>
                AbundanceAdminCoach.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        students: (json['students'] as List? ?? [])
            .whereType<Map>()
            .map((e) =>
                AbundanceAdminStudent.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class AbundanceAdminStudent {
  const AbundanceAdminStudent(
      {required this.id,
      required this.name,
      required this.email,
      this.username,
      this.coachId,
      this.goals = const []});
  final String id, name, email;
  final String? username, coachId;
  final List<Map<String, dynamic>> goals;
  factory AbundanceAdminStudent.fromJson(Map<String, dynamic> json) =>
      AbundanceAdminStudent(
          id: '${json['id'] ?? ''}',
          name: '${json['name'] ?? ''}',
          email: '${json['email'] ?? ''}',
          username: json['username']?.toString(),
          coachId: json['coachId']?.toString(),
          goals: (json['goals'] as List? ?? [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList());
}

class AbundanceAdminCoach extends AbundanceAdminStudent {
  const AbundanceAdminCoach(
      {required super.id,
      required super.name,
      required super.email,
      super.username,
      super.coachId,
      required this.students});
  final List<AbundanceAdminStudent> students;
  factory AbundanceAdminCoach.fromJson(Map<String, dynamic> json) =>
      AbundanceAdminCoach(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}',
        email: '${json['email'] ?? ''}',
        username: json['username']?.toString(),
        students: (json['students'] as List? ?? [])
            .whereType<Map>()
            .map((e) =>
                AbundanceAdminStudent.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class AbundanceAdminApiService {
  AbundanceAdminApiService._();
  static final instance = AbundanceAdminApiService._();
  final _api = ApiClient.instance;
  String? get _token => AuthService.instance.currentSession?.token;
  Future<AbundanceAdminSnapshot> fetch() async =>
      AbundanceAdminSnapshot.fromJson(
          await _api.getJson('/api/admin/abundance', token: _token));
  Future<void> assign(String coachId, String studentId) async => _api.postJson(
      '/api/admin/abundance/assignments',
      {
        'coach_id': int.tryParse(coachId) ?? coachId,
        'student_id': int.tryParse(studentId) ?? studentId
      },
      token: _token);
  Future<void> remove(String studentId) async => _api
      .deleteJson('/api/admin/abundance/assignments/$studentId', token: _token);
  Future<void> updateGoal(String goalId, Map<String, dynamic> body) async =>
      _api.patchJson('/api/admin/abundance/goals/$goalId', body, token: _token);
  Future<void> addQuest(String goalId, String title) async => _api.postJson(
      '/api/admin/abundance/goals/$goalId/tasks', {'title': title},
      token: _token);
}
