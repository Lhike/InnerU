import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';

class AbundanceProfile {
  const AbundanceProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.headline,
    required this.bio,
    required this.timezone,
    required this.avatarUrl,
    required this.character,
    required this.joinedAt,
    required this.progression,
    required this.stats,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? headline;
  final String? bio;
  final String timezone;
  final String? avatarUrl;
  final String? character;
  final DateTime? joinedAt;
  final AbundanceProgression? progression;
  final Map<String, num> stats;

  String get displayName =>
      [firstName, lastName].where((part) => part.trim().isNotEmpty).join(' ');
}

class AbundanceProgression {
  const AbundanceProgression({
    required this.level,
    required this.rank,
    required this.lifePower,
    required this.stats,
  });

  final int level;
  final String rank;
  final num lifePower;
  final Map<String, num> stats;
}

class AbundanceProfileAchievement {
  const AbundanceProfileAchievement({
    required this.key,
    required this.name,
    required this.description,
    required this.art,
    required this.tier,
    required this.unlockedAt,
  });

  final String key;
  final String name;
  final String description;
  final String? art;
  final String tier;
  final DateTime? unlockedAt;
}

class AbundanceProfileCouncil {
  const AbundanceProfileCouncil({
    required this.id,
    required this.name,
    required this.description,
    required this.coachName,
    required this.memberCount,
    required this.averageScore,
  });

  final String id;
  final String name;
  final String? description;
  final String coachName;
  final int memberCount;
  final num averageScore;
}

class AbundanceProfileSnapshot {
  const AbundanceProfileSnapshot({
    required this.profile,
    required this.achievements,
    required this.council,
    this.assignedCoachName,
  });

  final AbundanceProfile profile;
  final List<AbundanceProfileAchievement> achievements;
  final AbundanceProfileCouncil? council;
  final String? assignedCoachName;
}

class AbundanceProfileService {
  AbundanceProfileService({AbundanceApiTransport? transport})
      : _transport = transport ?? A12ApiTransport();

  final AbundanceApiTransport _transport;

  Future<AbundanceProfileSnapshot> fetchSnapshot() async {
    final response = await _transport.getJson('/profile');
    final payload = _map(response['data']) ?? response;
    final profileMap =
        _map(payload['profile']) ?? _map(payload['user']) ?? payload;
    final profile = _profile(profileMap);
    final achievements = _achievements(
      payload['achievements'] ??
          payload['earnedAchievements'] ??
          payload['unlockedAchievements'] ??
          payload['badges'] ??
          profileMap['achievements'] ??
          profileMap['earnedAchievements'] ??
          profileMap['unlockedAchievements'] ??
          profileMap['badges'],
    );
    final council = _council(
      payload['guild'] ??
          payload['council'] ??
          payload['currentCouncil'] ??
          payload['current_council'] ??
          profileMap['guild'] ??
          profileMap['council'] ??
          profileMap['currentCouncil'] ??
          profileMap['current_council'],
    );
    final assignedCoachName = _assignedCoachName(
      payload['coach'] ??
          payload['assignedCoach'] ??
          payload['assigned_coach'] ??
          payload['coachName'] ??
          payload['assignedCoachName'] ??
          payload['assigned_coach_name'] ??
          profileMap['coach'] ??
          profileMap['assignedCoach'] ??
          profileMap['assigned_coach'] ??
          profileMap['coachName'] ??
          profileMap['assignedCoachName'] ??
          profileMap['assigned_coach_name'],
    );
    return AbundanceProfileSnapshot(
      profile: profile,
      achievements: achievements,
      council: council,
      assignedCoachName: assignedCoachName,
    );
  }

  Future<void> updateCharacter(String character) async {
    await _transport.patchJson('/profile', {'character': character});
  }

  Future<void> updateProfile({
    required String firstName,
    required String lastName,
    required String headline,
    required String bio,
    required String timezone,
    required String? avatarUrl,
  }) async {
    await _transport.patchJson('/profile', {
      'firstName': firstName,
      'lastName': lastName,
      'headline': headline,
      'bio': bio,
      'timezone': timezone,
      'avatarUrl': avatarUrl,
    });
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _transport.postJson('/profile/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<void> deleteAccount({String? currentPassword}) async {
    await _transport.deleteJson('/profile');
  }

  AbundanceProfile _profile(Map<String, dynamic> json) {
    final progressionMap = _map(json['progression']);
    final stats = _numbers(_map(json['stats']) ?? const {});
    final progression = progressionMap == null
        ? null
        : AbundanceProgression(
            level: _int(progressionMap['level']),
            rank: _string(progressionMap['rank']),
            lifePower: _number(progressionMap['overallScore']) ??
                (stats['overallScore'] ?? 0),
            stats: stats,
          );
    return AbundanceProfile(
      id: _string(json['id']),
      email: _string(json['email']),
      firstName: _string(json['firstName'] ?? json['first_name']),
      lastName: _string(json['lastName'] ?? json['last_name']),
      headline: _nullableString(json['headline']),
      bio: _nullableString(json['bio']),
      timezone: _string(json['timezone']),
      avatarUrl: _nullableString(json['avatarUrl'] ?? json['avatar_url']),
      character: _nullableString(json['character']),
      joinedAt: _date(json['joinedAt'] ?? json['joined_at']),
      progression: progression,
      stats: stats,
    );
  }

  String? _assignedCoachName(dynamic raw) {
    if (raw is String) return _nullableString(raw);
    final json = _map(raw);
    if (json == null) return null;
    final direct = _nullableString(json['name']);
    if (direct != null) return direct;
    final coachName = _nullableString(
      json['coachName'] ??
          json['assignedCoachName'] ??
          json['assigned_coach_name'],
    );
    if (coachName != null) return coachName;
    final nested = _assignedCoachName(
      json['coach'] ?? json['assignedCoach'] ?? json['assigned_coach'],
    );
    if (nested != null) return nested;
    final first = json['firstName'] ?? json['first_name'] ?? '';
    final last = json['lastName'] ?? json['last_name'] ?? '';
    return _nullableString('$first $last');
  }

  List<AbundanceProfileAchievement> _achievements(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) {
          final json = Map<String, dynamic>.from(item);
          return AbundanceProfileAchievement(
            key: _string(json['key']),
            name: _string(json['name']),
            description: _string(json['description']),
            art: _nullableString(json['art']),
            tier: _string(json['tier']),
            unlockedAt: _date(
              json['unlockedAt'] ??
                  json['unlocked_at'] ??
                  json['earnedAt'] ??
                  json['earned_at'] ??
                  json['dateEarned'] ??
                  json['date_earned'],
            ),
          );
        })
        .where((item) => item.unlockedAt != null)
        .toList(growable: false);
  }

  AbundanceProfileCouncil? _council(dynamic raw) {
    if (raw is List) {
      final maps = raw.whereType<Map>();
      final current = maps.firstWhere(
        (item) => item['isCurrent'] == true || item['is_current'] == true,
        orElse: () => <String, dynamic>{},
      );
      return _council(current.isEmpty ? maps.firstOrNull : current);
    }
    final json = _map(raw);
    if (json == null) return null;
    return AbundanceProfileCouncil(
      id: _string(json['id']),
      name: _string(json['name'] ?? json['councilName']),
      description: _nullableString(json['description']),
      coachName: _string(json['coachName'] ?? json['coach_name']),
      memberCount: _int(json['memberCount'] ?? json['member_count']),
      averageScore: _number(json['averageScore'] ?? json['average_score']) ?? 0,
    );
  }

  static Map<String, dynamic>? _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;

  static Map<String, num> _numbers(Map<String, dynamic> json) => {
        for (final entry in json.entries)
          if (entry.value is num) entry.key: entry.value as num,
      };

  static String _string(dynamic value) => value?.toString() ?? '';

  static String? _nullableString(dynamic value) {
    final result = value?.toString().trim();
    return result == null || result.isEmpty ? null : result;
  }

  static num? _number(dynamic value) =>
      value is num ? value : num.tryParse(value?.toString() ?? '');

  static int _int(dynamic value) => _number(value)?.round() ?? 0;

  static DateTime? _date(dynamic value) =>
      DateTime.tryParse(value?.toString() ?? '');
}
