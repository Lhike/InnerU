import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:selfcare_projects/src/services/api_client.dart';
import 'package:selfcare_projects/src/services/api_config.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';

/// HTTP surface consumed by Abundance data services.
///
/// The default implementation remains the InnerU API. [A12ApiTransport] is
/// only constructed for an authenticated ABU15DN user and uses an A12 mobile
/// session obtained through the InnerU bridge endpoint.
abstract interface class AbundanceApiTransport {
  Future<Map<String, dynamic>> getJson(String path, {String? token});

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  });

  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  });

  Future<Map<String, dynamic>> deleteJson(String path, {String? token});
}

class InnerUAbundanceApiTransport implements AbundanceApiTransport {
  InnerUAbundanceApiTransport([ApiClient? client])
      : _client = client ?? ApiClient.instance;

  final ApiClient _client;

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) =>
      _client.getJson(path, token: token);

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) =>
      _client.postJson(path, body, token: token);

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) =>
      _client.patchJson(path, body, token: token);

  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) =>
      _client.deleteJson(path, token: token);
}

/// A12 session and API transport for the Abundance company partition.
///
/// The InnerU bearer is exchanged server-to-server; it is never sent to A12.
class A12ApiTransport implements AbundanceApiTransport {
  A12ApiTransport({
    A12SessionService? sessions,
    AbundanceApiTransport? fallback,
  })  : _sessions = sessions ?? A12SessionService(),
        _inneruFallback = fallback ?? InnerUAbundanceApiTransport();

  final A12SessionService _sessions;
  final AbundanceApiTransport _inneruFallback;

  Future<Map<String, dynamic>> _request(
    String method,
    String path,
    Map<String, dynamic>? body,
    String? token,
  ) async {
    late final A12Session session;
    try {
      session = await _sessions.ensureSession();
    } on ApiException catch (error) {
      // Guild/council data is also available from InnerU's coach-group
      // tables. This keeps the mobile surface usable while the A12 bridge is
      // being configured, and for stale A12 sessions or temporary outages.
      if (_shouldFallback(path, error)) {
        return _fallbackRequest(method, path, body, token);
      }
      rethrow;
    } on Exception {
      if (_isCouncilPath(path)) {
        return _fallbackRequest(method, path, body, token);
      }
      rethrow;
    }
    final translated = _translatePath(path);
    final uri = Uri.parse('${ApiConfig.a12BaseUrl}${translated.path}');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${session.accessToken}',
    };
    late final http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers);
        case 'POST':
          response = await http.post(uri,
              headers: headers, body: jsonEncode(_translateBody(body ?? {})));
        case 'PATCH':
          response = await http.patch(uri,
              headers: headers, body: jsonEncode(body ?? {}));
        case 'DELETE':
          response = await http.delete(uri, headers: headers);
        default:
          throw ArgumentError.value(method, 'method');
      }
    } on Exception {
      if (_isCouncilPath(path)) {
        return _fallbackRequest(method, path, body, token);
      }
      rethrow;
    }
    final data = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode == 401) {
      await _sessions.clear();
      return _fallbackRequest(method, path, body, token);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (_isCouncilPath(path) &&
          (response.statusCode == 404 || response.statusCode >= 500)) {
        return _fallbackRequest(method, path, body, token);
      }
      throw ApiException(
        response.statusCode,
        data is Map
            ? data['message']?.toString() ?? 'A12 request failed.'
            : 'A12 request failed.',
      );
    }
    final translatedResponse = _translateResponse(path, data);
    if (_isCouncilPath(path) &&
        (path == '/councils' || path == '/guild') &&
        _hasNoCouncilData(translatedResponse)) {
      try {
        final fallback = await _fallbackRequest(method, path, body, token);
        if (!_hasNoCouncilData(fallback)) return fallback;
      } catch (_) {
        // Keep the A12 response (including an intentional empty state) when
        // the compatibility route is unavailable as well.
      }
    }
    return translatedResponse;
  }

  bool _hasNoCouncilData(Map<String, dynamic> response) {
    final councils = response['councils'];
    return councils is! List || councils.isEmpty;
  }

  bool _isCouncilPath(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return normalized == '/guild' ||
        normalized == '/councils' ||
        normalized == '/guild/join' ||
        normalized == '/guild/leave';
  }

  bool _shouldFallback(String path, ApiException error) {
    if (error.statusCode == 503 &&
        error.message.contains('missing the Abundance A12 bridge route')) {
      return true;
    }
    if (!_isCouncilPath(path)) return false;
    return error.statusCode == 401 ||
        error.statusCode == 404 ||
        error.statusCode >= 500;
  }

  Future<Map<String, dynamic>> _fallbackRequest(
    String method,
    String path,
    Map<String, dynamic>? body,
    String? token,
  ) {
    final fallbackPath = _fallbackPath(path);
    final fallbackToken = token ?? AuthService.instance.currentSession?.token;
    return switch (method) {
      'GET' => _inneruFallback.getJson(fallbackPath, token: fallbackToken),
      'POST' => _inneruFallback.postJson(fallbackPath, body ?? const {},
          token: fallbackToken),
      'PATCH' => _inneruFallback.patchJson(fallbackPath, body ?? const {},
          token: fallbackToken),
      'DELETE' =>
        _inneruFallback.deleteJson(fallbackPath, token: fallbackToken),
      _ => throw ArgumentError.value(method, 'method'),
    };
  }

  String _fallbackPath(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return switch (normalized) {
      '/councils' => '/api/abundance/councils',
      '/guild' => '/api/abundance/guild',
      '/guild/join' => '/api/abundance/guild/join',
      '/guild/leave' => '/api/abundance/guild/leave',
      _ => normalized,
    };
  }

  ({String path, bool plans, bool history}) _translatePath(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    if (normalized.startsWith('/api/goals')) {
      final rest = normalized.substring('/api/goals'.length);
      if (rest.endsWith('/tasks')) {
        return (
          path: '/goals${rest.substring(0, rest.length - 6)}',
          plans: true,
          history: false
        );
      }
      if (rest.endsWith('/updates')) {
        return (
          path: '/goals${rest.substring(0, rest.length - 8)}/history',
          plans: false,
          history: true
        );
      }
      return (path: '/goals$rest', plans: false, history: false);
    }
    return (path: normalized, plans: false, history: false);
  }

  Map<String, dynamic> _translateBody(Map<String, dynamic> body) {
    final translated = <String, dynamic>{...body};
    if (translated.containsKey('description')) {
      translated['how'] = translated.remove('description');
    }
    if (translated.containsKey('notes')) {
      translated['qualities'] = translated.remove('notes');
    }
    for (final key in const [
      'target_value',
      'current_value',
      'target_period',
      'target_date',
      'goal_type',
      'plan_titles'
    ]) {
      final value = translated.remove(key);
      if (value == null) continue;
      translated[{
        'target_value': 'targetValue',
        'current_value': 'currentValue',
        'target_period': 'targetPeriod',
        'target_date': 'targetDate',
        'goal_type': 'goalType',
        'plan_titles': 'plans',
      }[key]!] = value;
    }
    if (translated['title'] != null) {
      translated['statement'] = translated['title'];
    }
    translated.remove('status');
    return translated;
  }

  Map<String, dynamic> _translateResponse(String originalPath, dynamic data) {
    final translated = _translatePath(originalPath);
    // Non-goal A12 resources (guild, councils, profile, missions, etc.) are
    // already shaped for the mobile app and must pass through untouched.
    if (!originalPath.startsWith('/api/goals')) {
      return data is Map<String, dynamic>
          ? data
          : <String, dynamic>{'data': data};
    }
    if (translated.plans) {
      final goal =
          data is Map<String, dynamic> ? data : const <String, dynamic>{};
      return {'tasks': goal['plans'] is List ? goal['plans'] : const []};
    }
    if (translated.history) {
      return {'updates': data is List ? data : const []};
    }
    if (data is List) {
      return {'goals': data.map((item) => _goal(item)).toList(growable: false)};
    }
    if (data is Map<String, dynamic>) {
      return {'goal': _goal(data)};
    }
    return {'data': data};
  }

  Map<String, dynamic> _goal(dynamic raw) {
    final source =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final category = source['category'];
    return {
      'id': source['id'],
      'userId': source['userId'] ?? '',
      'companyId': '',
      'title': source['title'] ?? source['statement'] ?? '',
      'description': source['how'],
      'notes': source['qualities'],
      'status': source['status'],
      'progress': source['progress'],
      'category': category is Map ? category['key'] : category,
      'goalType': source['goalType'] ?? 'MERIT',
      'targetPeriod': source['targetPeriod'] ?? 'NONE',
      'direction': source['direction'],
      'targetValue': source['targetValue'],
      'currentValue': source['currentValue'],
      'dailyTarget': source['dailyTarget'],
      'weeklyTarget': source['weeklyTarget'],
      'unit': source['unit'],
      'startDate': source['startDate'] ?? DateTime.now().toIso8601String(),
      'targetDate': source['targetDate'] ?? DateTime.now().toIso8601String(),
      'completedAt': source['completedAt'],
    };
  }

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) =>
      _request('GET', path, null, token);

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) =>
      _request('POST', path, body, token);

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) =>
      _request('PATCH', path, body, token);

  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) =>
      _request('DELETE', path, null, token);
}

class A12Session {
  const A12Session({required this.accessToken, this.refreshToken});

  final String accessToken;
  final String? refreshToken;
}

class A12SessionService {
  A12SessionService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String get _keyPrefix =>
      'abundance_a12_${AuthService.instance.currentSession?.id ?? 'unknown'}';

  Future<A12Session> ensureSession() async {
    final access = await _storage.read(key: '$_keyPrefix.access');
    if (access != null && access.isNotEmpty) {
      return A12Session(accessToken: access);
    }
    final innerToken = AuthService.instance.currentSession?.token;
    if (innerToken == null || innerToken.isEmpty) {
      throw ApiException(401, 'An InnerU session is required for Abundance.');
    }
    late final Map<String, dynamic> response;
    try {
      response = await ApiClient.instance.postJson(
        '/api/abundance/a12/session',
        const <String, dynamic>{},
        token: innerToken,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        throw ApiException(
          503,
          'The InnerU server is missing the Abundance A12 bridge route. Deploy the updated InnerU backend.',
        );
      }
      rethrow;
    }
    final session = A12Session(
      accessToken: response['accessToken']?.toString() ?? '',
      refreshToken: response['refreshToken']?.toString(),
    );
    if (session.accessToken.isEmpty) {
      throw ApiException(502, 'The A12 session response was invalid.');
    }
    await _storage.write(key: '$_keyPrefix.access', value: session.accessToken);
    if (session.refreshToken != null && session.refreshToken!.isNotEmpty) {
      await _storage.write(
          key: '$_keyPrefix.refresh', value: session.refreshToken);
    }
    return session;
  }

  Future<void> clear() async {
    await _storage.delete(key: '$_keyPrefix.access');
    await _storage.delete(key: '$_keyPrefix.refresh');
  }
}
