import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_leaderboard_service.dart';

class _GuildTransport implements AbundanceApiTransport {
  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    expect(path, '/guild');
    return {
      'company': 'ABU15DN',
      'users': [
        {
          'id': 'member-1',
          'firstName': 'Cookie',
          'lastName': 'Milo',
          'overallScore': 33,
          'profilePic': 'https://cdn.example.com/avatars/cookie-milo.png',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async => const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> patchJson(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async => const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async =>
      const <String, dynamic>{};
}

void main() {
  test('keeps profilePic from the Guild response for member entries', () async {
    final snapshot = await AbundanceLeaderboardService(
      transport: _GuildTransport(),
    ).fetchLeaderboard();

    expect(snapshot.entries.single.profilePic,
        'https://cdn.example.com/avatars/cookie-milo.png');
  });
}
