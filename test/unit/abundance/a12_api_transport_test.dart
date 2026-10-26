import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:selfcare_projects/src/features/abundance/services/a12_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/a12_session_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/abundance/domain/domain.dart';
import 'package:selfcare_projects/src/services/api_config.dart';

void main() {
  test('A12 API defaults to the a12_mobile-backed production service', () {
    expect(ApiConfig.a12BaseUrl, 'https://a14-api.valenin.com');
  });

  test('session exchange is cached and persisted for the InnerU token',
      () async {
    final innerU = _FakeTransport((path, body, token) async {
      expect(path, '/api/abundance/session');
      expect(token, 'inneru-token');
      return {
        'accessToken': 'a12-token',
        'accessTokenExpiresAt': '2099-01-01T00:00:00Z',
      };
    });
    final store = _MemoryTokenStore();
    final service = A12SessionService(innerUApi: innerU, store: store);

    expect(await service.accessToken('inneru-token'), 'a12-token');
    expect(await service.accessToken('inneru-token'), 'a12-token');
    expect(innerU.posts, 1);
    expect(store.value, contains('a12-token'));
  });

  test('goal creation translates InnerU fields and normalizes the A12 response',
      () async {
    late http.Request request;
    final client = MockClient((incoming) async {
      request = incoming;
      return http.Response(
          jsonEncode({
            'id': 'goal-1',
            'title': 'Save to A12',
            'statement': 'I see myself saving to A12.',
            'qualities': 'Integrity',
            'category': {'key': 'PERSONAL', 'name': 'Personal'},
            'status': 'NOT_STARTED',
            'progress': 0,
            'currentValue': 0,
            'targetValue': 1,
            'unit': 'PROJECT',
            'direction': 'GAIN',
            'targetDate': '2026-12-31',
            'targetPeriod': 'NONE',
            'plans': [],
          }),
          201);
    });
    final session = A12SessionService(
      innerUApi: _FakeTransport((_, __, ___) async => {
            'accessToken': 'a12-token',
            'accessTokenExpiresAt': '2099-01-01T00:00:00Z',
          }),
      store: _MemoryTokenStore(),
    );
    final transport = A12ApiTransport(client: client, session: session);

    final result = await transport.postJson(
        '/api/goals',
        {
          'category': 'PERSONAL',
          'title': 'Save to A12',
          'description': 'I see myself saving to A12.',
          'notes': 'Integrity',
          'status': 'NOT_STARTED',
          'goal_type': 'MERIT',
          'direction': 'GAIN',
          'target_value': 1,
          'current_value': 0,
          'unit': 'PROJECT',
          'target_period': 'NONE',
          'target_date': '2026-12-31',
          'plan_titles': <String>[],
        },
        token: 'inneru-token');

    expect(request.url.toString(), 'https://a14-api.valenin.com/api/v1/goals');
    expect(request.headers['authorization'], 'Bearer a12-token');
    expect(jsonDecode(request.body), containsPair('targetValue', 1));
    expect(jsonDecode(request.body),
        containsPair('statement', 'I see myself saving to A12.'));
    expect(result['goal']['category'], 'PERSONAL');
    expect(result['goal']['description'], 'I see myself saving to A12.');
    expect(result['goal']['notes'], 'Integrity');
  });

  test('an A12 401 forces one fresh exchange and retries the request',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      if (calls == 1) {
        return http.Response('{"message":"Unauthenticated."}', 401);
      }
      expect(request.headers['authorization'], 'Bearer fresh-a12-token');
      return http.Response('[]', 200);
    });
    var exchanges = 0;
    final session = A12SessionService(
      innerUApi: _FakeTransport((_, __, ___) async {
        exchanges += 1;
        return {
          'accessToken': exchanges == 1 ? 'stale-a12-token' : 'fresh-a12-token',
          'accessTokenExpiresAt': '2099-01-01T00:00:00Z',
        };
      }),
      store: _MemoryTokenStore(),
    );
    final transport = A12ApiTransport(client: client, session: session);

    expect(await transport.getJson('/api/goals', token: 'inneru-token'),
        {'goals': []});
    expect(calls, 2);
    expect(exchanges, 2);
  });

  test('Abundance GoalsService writes through its injected A12 transport',
      () async {
    final transport = _FakeTransport((path, body, token) async {
      expect(path, '/api/goals');
      expect(body['title'], 'Persist in a12_mobile');
      return {
        'goal': {
          'id': 'a12-goal-id',
          'category': 'PERSONAL',
          'title': 'Persist in a12_mobile',
          'status': 'NOT_STARTED',
          'progress': 0,
          'goalType': 'MERIT',
          'targetPeriod': 'NONE',
          'direction': 'GAIN',
          'targetValue': 1,
          'currentValue': 0,
          'unit': 'PROJECT',
          'startDate': '2026-09-17',
          'targetDate': '2026-12-31',
        },
      };
    });
    final service = GoalsService.abundance(transport: transport);

    final id = await service.createGoal(
      uid: '42',
      category: GoalCategory.personal,
      title: 'Persist in a12_mobile',
      targetDate: DateTime(2026, 12, 31),
      targetValue: 1,
      unit: 'PROJECT',
    );

    expect(id, 'a12-goal-id');
    expect(transport.posts, 1);
  });
}

class _FakeTransport implements AbundanceApiTransport {
  _FakeTransport(this.onPost);

  final Future<Map<String, dynamic>> Function(
    String path,
    Map<String, dynamic> body,
    String? token,
  ) onPost;
  int posts = 0;

  @override
  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body,
      {String? token}) {
    posts += 1;
    return onPost(path, body, token);
  }

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body,
          {String? token}) =>
      throw UnimplementedError();
  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) =>
      throw UnimplementedError();
}

class _MemoryTokenStore implements A12TokenStore {
  String? value;

  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async => this.value = value;
  @override
  Future<void> clear() async => value = null;
}
