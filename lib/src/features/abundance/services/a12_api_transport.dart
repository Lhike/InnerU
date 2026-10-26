import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:selfcare_projects/src/features/abundance/services/a12_session_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/services/api_client.dart';
import 'package:selfcare_projects/src/services/api_config.dart';

class A12ApiTransport implements AbundanceApiTransport {
  A12ApiTransport({
    http.Client? client,
    A12SessionService? session,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _session = session ?? A12SessionService(),
        _baseUrl =
            (baseUrl ?? ApiConfig.a12BaseUrl).replaceFirst(RegExp(r'/$'), '');

  final http.Client _client;
  final A12SessionService _session;
  final String _baseUrl;

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) =>
      _request('GET', path, token: token);

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) =>
      _request('POST', path, body: body, token: token);

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) =>
      _request('PATCH', path, body: body, token: token);

  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) =>
      _request('DELETE', path, token: token);

  Future<Map<String, dynamic>> _request(
    String method,
    String legacyPath, {
    Map<String, dynamic>? body,
    String? token,
    bool retried = false,
  }) async {
    final nested = _nestedGoalOperation(method, legacyPath, body, token);
    if (nested != null) return nested;
    final innerUToken = token ?? '';
    final a12Token = await _session.accessToken(
      innerUToken,
      forceRefresh: retried,
    );
    final request =
        http.Request(method, Uri.parse('$_baseUrl${_a12Path(legacyPath)}'))
          ..headers.addAll({
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $a12Token',
          });
    if (body != null) request.body = jsonEncode(_a12Body(legacyPath, body));

    final streamed =
        await _client.send(request).timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401 && !retried) {
      return _request(method, legacyPath,
          body: body, token: token, retried: true);
    }

    final raw = response.body.trim();
    final decoded = raw.isEmpty ? null : jsonDecode(raw);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map
          ? decoded['message']?.toString() ?? 'Request failed.'
          : 'Request failed.';
      throw ApiException(response.statusCode, message);
    }
    return _legacyResponse(method, legacyPath, decoded);
  }

  String _a12Path(String legacyPath) {
    final uri = Uri.parse(legacyPath);
    final path = uri.path;
    if (path == '/api/goals') return '/api/v1/goals';
    if (path == '/api/coach/goals') return '/api/v1/coach/roster';
    final match = RegExp(r'^/api/goals/([^/]+)$').firstMatch(path);
    if (match != null) return '/api/v1/goals/${match.group(1)}';
    throw UnsupportedError('Unsupported A12 path: $legacyPath');
  }

  Future<Map<String, dynamic>>? _nestedGoalOperation(
    String method,
    String path,
    Map<String, dynamic>? body,
    String? token,
  ) {
    final match = RegExp(
      r'^/api/goals/([^/]+)/(tasks|updates|comments|merits)(?:/([^/]+))?$',
    ).firstMatch(path);
    if (match == null) return null;
    final kind = match.group(2)!;
    if (kind != 'tasks') {
      return _readGoalCollection(
        goalId: match.group(1)!,
        kind: kind,
        token: token,
      );
    }
    return _mutatePlans(
      method: method,
      goalId: match.group(1)!,
      planId: match.group(3),
      body: body ?? const <String, dynamic>{},
      token: token,
    );
  }

  Future<Map<String, dynamic>> _readGoalCollection({
    required String goalId,
    required String kind,
    required String? token,
  }) async {
    final current = await _request('GET', '/api/goals/$goalId', token: token);
    final goal = Map<String, dynamic>.from(current['goal'] as Map);
    final history = goal['history'] is List ? goal['history'] as List : const [];
    if (kind == 'comments') return {'comments': <dynamic>[]};
    if (kind == 'merits') {
      return {'merits': history.where((item) => item is Map && item['amount'] != null).toList()};
    }
    return {'updates': history};
  }

  Future<Map<String, dynamic>> _mutatePlans({
    required String method,
    required String goalId,
    required String? planId,
    required Map<String, dynamic> body,
    required String? token,
  }) async {
    final current = await _request('GET', '/api/goals/$goalId', token: token);
    final goal = Map<String, dynamic>.from(current['goal'] as Map);
    final plans = (goal['plans'] is List ? goal['plans'] as List : const [])
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
    if (method == 'GET') {
      return {
        'tasks': plans.indexed
            .map((entry) => {
                  ...entry.$2,
                  'sortOrder': entry.$1,
                })
            .toList()
      };
    }
    Map<String, dynamic>? changed;
    if (method == 'POST') {
      changed = {
        'id': 'client-${DateTime.now().microsecondsSinceEpoch}',
        'title': body['title'],
        'status': 'NOT_STARTED'
      };
      plans.add(changed);
    } else {
      final index = plans.indexWhere((p) => p['id']?.toString() == planId);
      if (index < 0) throw ApiException(404, 'Task not found.');
      if (method == 'PATCH') {
        plans[index]['status'] = body['status'];
        changed = plans[index];
      }
      if (method == 'DELETE') {
        changed = plans[index];
        plans.removeAt(index);
      }
    }
    await _request('PATCH', '/api/goals/$goalId',
        body: {'plans': plans}, token: token);
    return {
      if (changed != null) 'task': changed,
      if (method == 'DELETE') 'deleted': true,
    };
  }

  Map<String, dynamic> _a12Body(
    String legacyPath,
    Map<String, dynamic> body,
  ) {
    if (legacyPath == '/api/goals') {
      return {
        'category': body['category'],
        'title': body['title'],
        'statement': body['description'],
        'qualities': body['notes'],
        'unit': body['unit'],
        'direction': body['direction'],
        'currentValue': body['current_value'],
        'targetValue': body['target_value'],
        'targetDate': body['target_date'],
        'targetPeriod': body['target_period'],
        'status': body['status'],
        'plans': body['plan_titles'] ?? const <String>[],
      }..removeWhere((_, value) => value == null);
    }

    return {
      if (body.containsKey('title')) 'title': body['title'],
      if (body.containsKey('description')) 'statement': body['description'],
      if (body.containsKey('notes')) 'qualities': body['notes'],
      if (body.containsKey('unit')) 'unit': body['unit'],
      if (body.containsKey('direction')) 'direction': body['direction'],
      if (body.containsKey('current_value'))
        'currentValue': body['current_value'],
      if (body.containsKey('target_value')) 'targetValue': body['target_value'],
      if (body.containsKey('target_date')) 'targetDate': body['target_date'],
      if (body.containsKey('target_period'))
        'targetPeriod': body['target_period'],
      if (body.containsKey('status')) 'status': body['status'],
      if (body.containsKey('plans')) 'plans': body['plans'],
    };
  }

  Map<String, dynamic> _legacyResponse(
    String method,
    String legacyPath,
    Object? decoded,
  ) {
    final path = Uri.parse(legacyPath).path;
    if (path == '/api/goals' && method == 'GET') {
      final goals = decoded is List
          ? decoded
              .whereType<Map>()
              .map((item) => _legacyGoal(Map<String, dynamic>.from(item)))
              .toList()
          : const <Map<String, dynamic>>[];
      return {'goals': goals};
    }
    if (path == '/api/coach/goals') {
      final rows = decoded is Map
          ? (decoded['students'] ?? decoded['items'] ?? decoded['roster'] ?? const [])
          : const [];
      return {'roster': rows is List ? rows : const []};
    }
    if (path.endsWith('/tasks') && method == 'GET') {
      final goal = decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
      final plans = goal['plans'] is List ? goal['plans'] as List : const [];
      return {
        'tasks': plans.indexed.map((entry) {
          final plan = Map<String, dynamic>.from(entry.$2 as Map);
          return {
            'id': plan['id'],
            'title': plan['title'],
            'status': plan['status'],
            'sortOrder': entry.$1,
          };
        }).toList(),
      };
    }
    if (decoded is Map) {
      final goal = _legacyGoal(Map<String, dynamic>.from(decoded));
      return {'goal': goal};
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _legacyGoal(Map<String, dynamic> goal) {
    final rawCategory = goal['category'];
    final category = rawCategory is Map ? rawCategory['key'] : rawCategory;
    final unit = goal['unit']?.toString() ?? '';
    return {
      ...goal,
      'category': category,
      'description': goal['statement'],
      'notes': goal['qualities'],
      'goalType': unit.toUpperCase() == 'MILESTONE' ? 'MILESTONE' : 'MERIT',
      'targetPeriod': goal['targetPeriod'] ?? 'NONE',
      'startDate': goal['startDate'] ?? DateTime.now().toIso8601String(),
      'targetDate': goal['targetDate'] ?? DateTime.now().toIso8601String(),
      'completedAt': goal['completedAt'],
    };
  }
}
