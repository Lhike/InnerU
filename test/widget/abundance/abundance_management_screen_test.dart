import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/authentication/screen/adminscreen/abundance_management.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/services/abundance_admin_api_service.dart';
import 'package:selfcare_projects/src/services/app_session_service.dart';

class _ManagementTransport implements AbundanceApiTransport {
  final requests = <String>[];

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    requests.add('GET $path');
    if (path == '/admin/councils') {
      return const {'groups': <Map<String, dynamic>>[]};
    }
    return const {
      'data': [
        {
          'id': 'student-1',
          'firstName': 'Cookie',
          'lastName': 'Milo',
          'email': 'cookie@example.test',
          'roles': ['MENTEE'],
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    requests.add('PATCH $path');
    return const {'ok': true};
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    requests.add('POST $path');
    return const {};
  }

  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async {
    requests.add('DELETE $path');
    return const {};
  }
}

AppSession _adminSession() => const AppSession(
      id: 1,
      token: 'inneru-session',
      name: 'Admin',
      email: 'admin@example.test',
      role: 'admin',
      isCoach: false,
      companyCode: 'ABU15DN',
    );

void main() {
  testWidgets('admin confirms before making an Abundance user a coach',
      (tester) async {
    final transport = _ManagementTransport();
    final service = AbundanceAdminApiService(
      a12Transport: transport,
      sessionProvider: _adminSession,
    );

    await tester.pumpWidget(
      MaterialApp(home: AbundanceManagementScreen(service: service)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cookie Milo'), findsOneWidget);
    expect(find.text('Make coach'), findsOneWidget);

    await tester.tap(find.text('Make coach'));
    await tester.pumpAndSettle();

    expect(find.text('Make Cookie Milo a coach?'), findsOneWidget);
    expect(find.text('This gives the user Abundance Coach access.'),
        findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(transport.requests,
        isNot(contains('PATCH /admin/users/student-1/roles')));

    await tester.tap(find.text('Make coach'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make coach').last);
    await tester.pumpAndSettle();

    expect(transport.requests, contains('PATCH /admin/users/student-1/roles'));
    expect(find.text('Cookie Milo is now an Abundance coach.'), findsOneWidget);
  });
}
