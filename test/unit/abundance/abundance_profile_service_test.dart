import 'package:flutter_test/flutter_test.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_profile_service.dart';

class _RecordingProfileTransport implements AbundanceApiTransport {
  final requests = <String>[];

  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    requests.add('GET $path');
    return {
      'profile': {
        'id': 'user-1',
        'email': 'member@example.com',
        'firstName': 'Member',
        'lastName': 'One',
        'headline': 'I MATTER',
        'bio': 'A short bio.',
        'timezone': 'Asia/Manila',
        'avatarUrl': null,
        'character': 'mage',
        'joinedAt': '2026-09-14T00:00:00Z',
        'progression': {
          'level': 2,
          'rank': 'Legend',
          'overallScore': 35,
          'currentStreak': 3,
          'longestStreak': 3,
        },
        'stats': {
          'goalsTotal': 3,
          'goalsCompleted': 1,
          'currentStreak': 3,
          'longestStreak': 3,
          'overallScore': 35,
        },
      },
      'achievements': [
        {
          'key': 'GIVEN_FREELY',
          'name': 'Given Freely',
          'description': 'Contribution goal completed.',
          'icon': 'gift',
          'art': 'given-freely.png',
          'tier': 'BRONZE',
          'unlockedAt': '2026-09-14T01:00:00Z',
          'metric': 'contributionGoalsCompleted',
          'progress': {'current': 1, 'target': 1},
        },
      ],
      'guild': {
        'councilName': 'Dawn',
        'coachName': 'Coach One',
        'memberCount': 2,
        'averageScore': 34,
      },
      'coach': {
        'id': 'coach-1',
        'firstName': 'Coach',
        'lastName': 'One',
        'name': 'Coach One',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> postJson(String path, Map<String, dynamic> body,
      {String? token}) async {
    requests.add('POST $path');
    return {
      'profile': {'id': 'user-1'}
    };
  }

  @override
  Future<Map<String, dynamic>> patchJson(String path, Map<String, dynamic> body,
      {String? token}) async {
    requests.add('PATCH $path');
    return {
      'profile': {'id': 'user-1'}
    };
  }

  @override
  Future<Map<String, dynamic>> deleteJson(String path, {String? token}) async {
    requests.add('DELETE $path');
    return const <String, dynamic>{};
  }
}

class _WrappedCoachNameProfileTransport extends _RecordingProfileTransport {
  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async =>
      const {
        'data': {
          'profile': {'id': 'user-1'},
          'coachName': 'Lilian Agnas',
        },
      };
}

void main() {
  test('loads profile, progression, council, and unlocked achievements',
      () async {
    final transport = _RecordingProfileTransport();
    final service = AbundanceProfileService(transport: transport);

    final snapshot = await service.fetchSnapshot();

    expect(snapshot.profile.displayName, 'Member One');
    expect(snapshot.profile.progression?.lifePower, 35);
    expect(snapshot.profile.progression?.stats['goalsTotal'], 3);
    expect(snapshot.council?.name, 'Dawn');
    expect(snapshot.assignedCoachName, 'Coach One');
    expect(snapshot.achievements.single.name, 'Given Freely');
    expect(snapshot.achievements.single.unlockedAt, isNotNull);
    expect(transport.requests, ['GET /profile']);
  });

  test('routes profile mutations through the A12 profile API', () async {
    final transport = _RecordingProfileTransport();
    final service = AbundanceProfileService(transport: transport);

    await service.updateProfile(
      firstName: 'New',
      lastName: 'Name',
      headline: 'New headline',
      bio: 'New bio',
      timezone: 'Asia/Manila',
      avatarUrl: null,
    );
    await service.changePassword(
      currentPassword: 'old',
      newPassword: 'new',
    );
    await service.deleteAccount(currentPassword: 'old');

    expect(transport.requests, [
      'PATCH /profile',
      'POST /profile/password',
      'DELETE /profile',
    ]);
  });

  test('reads earned badges nested in the profile payload', () async {
    final transport = _NestedAchievementsTransport();
    final service = AbundanceProfileService(transport: transport);

    final snapshot = await service.fetchSnapshot();

    expect(snapshot.achievements.single.name, 'Given Freely');
    expect(snapshot.achievements.single.unlockedAt,
        DateTime.parse('2026-09-14T01:00:00Z'));
  });

  test('reads the assigned coach from wrapped coachName responses', () async {
    final service = AbundanceProfileService(
      transport: _WrappedCoachNameProfileTransport(),
    );

    final snapshot = await service.fetchSnapshot();

    expect(snapshot.assignedCoachName, 'Lilian Agnas');
  });
}

class _NestedAchievementsTransport extends _RecordingProfileTransport {
  @override
  Future<Map<String, dynamic>> getJson(String path, {String? token}) async {
    return {
      'profile': {
        'id': 'user-1',
        'email': 'member@example.com',
        'firstName': 'Member',
        'lastName': 'One',
        'timezone': 'Asia/Manila',
        'achievements': [
          {
            'key': 'GIVEN_FREELY',
            'name': 'Given Freely',
            'description': 'Contribution goal completed.',
            'tier': 'BRONZE',
            'earned_at': '2026-09-14T01:00:00Z',
          },
        ],
      },
    };
  }
}
