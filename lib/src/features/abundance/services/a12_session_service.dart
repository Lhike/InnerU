import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';

abstract interface class A12TokenStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureA12TokenStore implements A12TokenStore {
  SecureA12TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'inneru.secure.a12.session';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class A12SessionService {
  A12SessionService({
    AbundanceApiTransport? innerUApi,
    A12TokenStore? store,
  })  : _innerUApi = innerUApi ?? InnerUAbundanceApiTransport(),
        _store = store ?? SecureA12TokenStore();

  final AbundanceApiTransport _innerUApi;
  final A12TokenStore _store;
  _A12Session? _session;

  Future<String> accessToken(
    String innerUToken, {
    bool forceRefresh = false,
  }) async {
    if (innerUToken.trim().isEmpty) {
      throw StateError('Sign in before accessing Abundance data.');
    }

    if (forceRefresh) {
      _session = null;
      await _store.clear();
    }

    final tokenHash = sha256.convert(utf8.encode(innerUToken)).toString();
    final current = _session ?? await _restore();
    if (current != null &&
        current.innerUTokenHash == tokenHash &&
        current.expiresAt
            .isAfter(DateTime.now().add(const Duration(seconds: 30)))) {
      _session = current;
      return current.accessToken;
    }

    final response = await _innerUApi.postJson(
      '/api/abundance/session',
      const <String, dynamic>{},
      token: innerUToken,
    );
    final accessToken = response['accessToken']?.toString() ?? '';
    final expiresAt = DateTime.tryParse(
      response['accessTokenExpiresAt']?.toString() ?? '',
    );
    if (accessToken.isEmpty || expiresAt == null) {
      throw StateError('Abundance session response was invalid.');
    }

    final next = _A12Session(
      accessToken: accessToken,
      expiresAt: expiresAt,
      innerUTokenHash: tokenHash,
    );
    _session = next;
    await _store.write(jsonEncode(next.toJson()));
    return accessToken;
  }

  Future<_A12Session?> _restore() async {
    try {
      final encoded = await _store.read();
      if (encoded == null || encoded.isEmpty) return null;
      final value = jsonDecode(encoded);
      if (value is! Map<String, dynamic>) return null;
      return _A12Session.fromJson(value);
    } catch (_) {
      await _store.clear();
      return null;
    }
  }
}

class _A12Session {
  const _A12Session({
    required this.accessToken,
    required this.expiresAt,
    required this.innerUTokenHash,
  });

  factory _A12Session.fromJson(Map<String, dynamic> json) => _A12Session(
        accessToken: json['accessToken']?.toString() ?? '',
        expiresAt: DateTime.parse(json['expiresAt'].toString()),
        innerUTokenHash: json['innerUTokenHash']?.toString() ?? '',
      );

  final String accessToken;
  final DateTime expiresAt;
  final String innerUTokenHash;

  Map<String, dynamic> toJson() => {
        'accessToken': accessToken,
        'expiresAt': expiresAt.toIso8601String(),
        'innerUTokenHash': innerUTokenHash,
      };
}
