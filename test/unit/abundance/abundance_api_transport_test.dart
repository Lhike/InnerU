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

class _RecordingFallback implements AbundanceApiTransport {
  String? token;
  String? path;

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    this.path = path;
    this.token = token;
    return const <String, dynamic>{'goals': <dynamic>[]};
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body,
      {String? token}) async {
    this.path = path;
    this.token = token;
    return const <String, dynamic>{'goal': <String, dynamic>{}};
  }

  @override
  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body,
      {String? token}) async {
    this.token = token;
    return const <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async {
    this.token = token;
    return const <String, dynamic>{};
  }
}

void main() {
  test('InnerU fallback preserves the caller bearer token', () async {
    final fallback = _RecordingFallback();
    final transport = A12ApiTransport(
      sessions: _MissingBridgeSession(),
      fallback: fallback,
    );

    await transport.postJson(
      '/api/goals',
      const <String, dynamic>{'title': 'A goal'},
      token: 'inneru-token',
    );

    expect(fallback.token, 'inneru-token');
  });

  test('council fallback uses the InnerU coach-group compatibility route',
      () async {
    final fallback = _RecordingFallback();
    final transport = A12ApiTransport(
      sessions: _MissingBridgeSession(),
      fallback: fallback,
    );

    await transport.getJson('/councils', token: 'inneru-token');

    expect(fallback.path, '/api/abundance/councils');
  });
}
