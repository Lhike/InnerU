import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/services/abundance_admin_api_service.dart';
import 'package:selfcare_projects/src/services/app_session_service.dart';

class _AdminTransport implements AbundanceApiTransport {
  final requests = <String>[];
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async {
    requests.add('DELETE $path');
    return const {};
  }

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    requests.add('GET $path');
    if (path == '/admin/councils') {
      return const {
        'groups': [
          {
            'id': 'council-1',
            'coach': {'id': 'coach-1'},
            'assignedUsers': [
              {
                'id': 'student-1',
                'firstName': 'Cookie',
                'lastName': 'Milo',
                'email': 'cookie@example.test'
              },
            ],
          },
        ],
      };
    }
    return const {
      'data': [
        {
          'id': 'coach-1',
          'firstName': 'Coach',
          'lastName': 'One',
          'email': 'coach@example.test',
          'roles': ['MENTEE', 'COACH']
        },
        {
          'id': 'student-1',
          'firstName': 'Cookie',
          'lastName': 'Milo',
          'email': 'cookie@example.test',
          'roles': ['MENTEE']
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body,
      {String? token}) async {
    requests.add('PATCH $path');
    bodies.add(body);
    return const {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body,
      {String? token}) async {
    requests.add('POST $path');
    return const {};
  }
}

AppSession _abundanceAdminSession() => const AppSession(
      id: 1,
      token: 'inneru-session',
      name: 'Admin',
      email: 'admin@example.test',
      role: 'admin',
      isCoach: false,
      companyCode: 'ABU15DN',
    );

AppSession _globalAdminSession() => const AppSession(
      id: 2,
      token: 'inneru-admin-session',
      name: 'Global Admin',
      email: 'global-admin@example.test',
      role: 'admin',
      isCoach: false,
      companyCode: 'OTHER01',
    );

void main() {
  test('Abundance admins read and assign coach relationships through A12',
      () async {
    final transport = _AdminTransport();
    final service = AbundanceAdminApiService(
      a12Transport: transport,
      sessionProvider: _abundanceAdminSession,
    );

    final snapshot = await service.fetch();

    expect(transport.requests,
        containsAll(['GET /admin/users?perPage=100', 'GET /admin/councils']));
    expect(snapshot.coaches.single.students.single.id, 'student-1');

    await service.assign('coach-1', 'student-1');
    expect(transport.requests.last, 'POST /admin/councils/assign');

    await service.remove('student-1');
    expect(transport.requests.last, 'DELETE /admin/councils/assign/student-1');

    await service.makeCoach(snapshot.students.single);
    expect(transport.requests.last, 'PATCH /admin/users/student-1/roles');
    expect(transport.bodies.last['roles'], containsAll(['MENTEE', 'COACH']));
  });

  test('global admins use A12 for Abundance management', () {
    final service = AbundanceAdminApiService(
      a12Transport: _AdminTransport(),
      sessionProvider: _globalAdminSession,
    );

    expect(service.isA12AbundanceManagement, isTrue);
  });
}
