import 'package:selfcare_projects/src/services/api_client.dart';

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
