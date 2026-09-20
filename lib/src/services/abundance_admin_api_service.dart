import 'package:selfcare_projects/src/services/api_client.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';
import 'package:selfcare_projects/src/services/app_session_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';

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
      this.roles = const [],
      this.goals = const []});
  final String id, name, email;
  final String? username, coachId;
  final List<String> roles;
  final List<Map<String, dynamic>> goals;
  factory AbundanceAdminStudent.fromJson(Map<String, dynamic> json) =>
      AbundanceAdminStudent(
          id: '${json['id'] ?? ''}',
          name: _displayName(json),
          email: '${json['email'] ?? ''}',
          username: json['username']?.toString(),
          coachId: json['coachId']?.toString(),
          roles: (json['roles'] as List? ?? const [])
              .map((role) => role.toString())
              .toList(growable: false),
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
      super.roles,
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
  AbundanceAdminApiService({
    ApiClient? api,
    AbundanceApiTransport? a12Transport,
    AppSession? Function()? sessionProvider,
  })  : _api = api ?? ApiClient.instance,
        _a12Transport = a12Transport ?? A12ApiTransport(),
        _sessionProvider =
            sessionProvider ?? (() => AuthService.instance.currentSession);

  static final instance = AbundanceAdminApiService();

  final ApiClient _api;
  final AbundanceApiTransport _a12Transport;
  final AppSession? Function() _sessionProvider;
  final Map<String, String> _a12CouncilByCoach = {};
  final Map<String, String> _a12CoachNames = {};

  String? get _token => AuthService.instance.currentSession?.token;
  bool get _usesA12 =>
      _sessionProvider()?.companyCode?.trim().toUpperCase() == 'ABU15DN' ||
      _sessionProvider()?.role.trim().toLowerCase() == 'admin';

  bool get isA12AbundanceManagement => _usesA12;

  Future<AbundanceAdminSnapshot> fetch() async {
    if (!_usesA12) {
      return AbundanceAdminSnapshot.fromJson(
          await _api.getJson('/api/admin/abundance', token: _token));
    }
    final responses = await Future.wait([
      _a12Transport.getJson('/admin/users?perPage=100'),
      _a12Transport.getJson('/admin/councils'),
    ]);
    final rawUsers = _records(responses[0]['data']);
    final groups = _records(responses[1]['groups']);
    final usersById = {
      for (final user in rawUsers) '${user['id'] ?? ''}': user
    };
    _a12CouncilByCoach.clear();
    _a12CoachNames.clear();
    final assignedCoachByStudent = <String, String>{};
    for (final group in groups) {
      final coach = _map(group['coach']);
      final coachId = '${coach['id'] ?? ''}';
      if (coachId.isEmpty) continue;
      _a12CouncilByCoach[coachId] = '${group['id'] ?? ''}';
      for (final assigned in _records(group['assignedUsers'])) {
        assignedCoachByStudent['${assigned['id'] ?? ''}'] = coachId;
      }
    }
    final coaches = rawUsers.where(_hasCoachRole).map((raw) {
      final id = '${raw['id'] ?? ''}';
      final students = assignedCoachByStudent.entries
          .where((assignment) => assignment.value == id)
          .map((assignment) => AbundanceAdminStudent.fromJson(
                {...?usersById[assignment.key], 'coachId': id},
              ))
          .toList(growable: false);
      final coach = AbundanceAdminCoach(
        id: id,
        name: _displayName(raw),
        email: '${raw['email'] ?? ''}',
        username: raw['username']?.toString(),
        roles: _roles(raw),
        students: students,
      );
      _a12CoachNames[id] = coach.name;
      return coach;
    }).toList(growable: false);
    final students = rawUsers
        .where((raw) => !_hasCoachRole(raw) && !_roles(raw).contains('ADMIN'))
        .map((raw) => AbundanceAdminStudent.fromJson({
              ...raw,
              'coachId': assignedCoachByStudent['${raw['id'] ?? ''}'],
            }))
        .toList(growable: false);
    return AbundanceAdminSnapshot(coaches: coaches, students: students);
  }

  Future<void> assign(String coachId, String studentId) async {
    if (!_usesA12) {
      await _api.postJson(
          '/api/admin/abundance/assignments',
          {
            'coach_id': int.tryParse(coachId) ?? coachId,
            'student_id': int.tryParse(studentId) ?? studentId,
          },
          token: _token);
      return;
    }
    var councilId = _a12CouncilByCoach[coachId];
    if (councilId == null || councilId.isEmpty) {
      final created = await _a12Transport.postJson('/admin/councils', {
        'coachId': coachId,
        'name': '${_a12CoachNames[coachId] ?? 'Coach'} Council',
      });
      councilId = created['id']?.toString();
      if (councilId == null || councilId.isEmpty) {
        throw StateError('A12 did not return the coach council.');
      }
      _a12CouncilByCoach[coachId] = councilId;
    }
    await _a12Transport.postJson('/admin/councils/assign', {
      'studentId': studentId,
      'councilId': councilId,
    });
  }

  Future<void> remove(String studentId) async {
    if (_usesA12) {
      await _a12Transport.deleteJson('/admin/councils/assign/$studentId');
      return;
    }
    await _api.deleteJson('/api/admin/abundance/assignments/$studentId',
        token: _token);
  }

  /// The Administrator is the only actor who can grant a Coach role. A12
  /// keeps the role relationship, so InnerU never promotes a local account.
  Future<void> makeCoach(AbundanceAdminStudent student) async {
    if (!_usesA12) {
      throw StateError('Coach roles are managed by the current company.');
    }
    final roles = {...student.roles, 'MENTEE', 'COACH'};
    await _a12Transport.patchJson('/admin/users/${student.id}/roles', {
      'roles': roles.toList(growable: false),
    });
  }

  Future<void> updateGoal(String goalId, Map<String, dynamic> body) async =>
      _api.patchJson('/api/admin/abundance/goals/$goalId', body, token: _token);
  Future<void> addQuest(String goalId, String title) async => _api.postJson(
      '/api/admin/abundance/goals/$goalId/tasks', {'title': title},
      token: _token);
}

List<Map<String, dynamic>> _records(Object? raw) => raw is List
    ? raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
    : const [];

Map<String, dynamic> _map(Object? raw) =>
    raw is Map ? Map<String, dynamic>.from(raw) : const {};

List<String> _roles(Map<String, dynamic> raw) =>
    (raw['roles'] as List? ?? const [])
        .map((role) => role.toString().toUpperCase())
        .toList(growable: false);

bool _hasCoachRole(Map<String, dynamic> raw) => _roles(raw).contains('COACH');

String _displayName(Map<String, dynamic> json) {
  final fullName = json['name']?.toString().trim() ?? '';
  if (fullName.isNotEmpty) return fullName;
  return '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim();
}
