import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/services/api_client.dart';

class _MissingBridgeSession extends A12SessionService {
  @override
  Future<A12Session> ensureSession() async => throw ApiException(
        503,
        'The InnerU server is missing the Abundance A12 bridge route.',
      );
}

void main() {
  test('A12 session failure never falls back to InnerU goal storage', () async {
    final transport = A12ApiTransport(
      sessions: _MissingBridgeSession(),
    );

    await expectLater(
      transport.postJson(
        '/api/goals',
        const <String, dynamic>{'title': 'A goal'},
        token: 'inneru-token',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.statusCode,
          'statusCode',
          503,
        ),
      ),
    );
  });

  test('A12 session failure never falls back to InnerU council storage',
      () async {
    final transport = A12ApiTransport(
      sessions: _MissingBridgeSession(),
    );

    await expectLater(
      transport.getJson('/councils', token: 'inneru-token'),
      throwsA(isA<ApiException>()),
    );
  });
}
