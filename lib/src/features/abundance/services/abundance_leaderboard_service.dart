import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/services/leaderboard_api_service.dart';
import 'package:selfcare_projects/src/services/auth_service.dart';
import 'package:selfcare_projects/src/services/profile_picture_bus.dart';

/// Adapts the a12_mobile Guild response to the shared Flutter leaderboard
/// model. This service is used only by the Abundance company route.
class AbundanceLeaderboardService {
  AbundanceLeaderboardService({AbundanceApiTransport? transport})
      : _transport = transport ?? A12ApiTransport();

  final AbundanceApiTransport _transport;

  Future<LeaderboardApiSnapshot> fetchLeaderboard() async {
    final response = await _transport.getJson('/guild');
    List<LeaderboardApiCompanyEntry> parseEntries(dynamic rawEntries) {
      final rawList = rawEntries is List ? rawEntries : const <dynamic>[];
      final entries = rawList
          .whereType<Map>()
          .map((raw) {
            final member = Map<String, dynamic>.from(raw);
            final currentSession = AuthService.instance.currentSession;
            final currentUserId = currentSession?.id.toString();
            final currentUserName = currentSession?.name.trim().toLowerCase();
            final liveProfilePic =
                ProfilePictureBus.latestUrl.value ?? currentSession?.profilePic;
            final legacyName = member['name']?.toString().trim() ?? '';
            final memberId = member['id']?.toString();
            final memberName = [
              member['firstName']?.toString().trim() ?? '',
              member['lastName']?.toString().trim() ?? '',
            ].where((part) => part.isNotEmpty).join(' ').toLowerCase();
            final isCurrentUser = memberId == currentUserId ||
                (currentUserName != null &&
                    currentUserName.isNotEmpty &&
                    (memberName.isNotEmpty
                            ? memberName
                            : legacyName.toLowerCase()) ==
                        currentUserName);
            final firstName = member['firstName']?.toString().trim() ?? '';
            final lastName = member['lastName']?.toString().trim() ?? '';
            final name = [firstName, lastName]
                .where((part) => part.isNotEmpty)
                .join(' ');
            final overall = _number(
              member['overallScore'],
              fallback: _number(member['score']),
            );
            final goalScores = member['goalScores'] is Map
                ? Map<String, dynamic>.from(member['goalScores'] as Map)
                : const <String, dynamic>{};

            return LeaderboardApiCompanyEntry(
              userId: member['id']?.toString() ?? '',
              name: name.isEmpty
                  ? (legacyName.isEmpty ? 'User' : legacyName)
                  : name,
              score: overall,
              goalScore: _number(goalScores['total'], fallback: overall),
              coreTaskScore: 0,
              overallScore: overall,
              rank: 0,
              profilePic: isCurrentUser &&
                      liveProfilePic != null &&
                      liveProfilePic.isNotEmpty
                  ? liveProfilePic
                  : member['avatarUrl']?.toString(),
              teamName: member['teamName']?.toString(),
              firstCompletedTrackerAt: member['joinedAt']?.toString(),
              personalScore: _optionalNumber(goalScores['personal']),
              professionalScore: _optionalNumber(goalScores['professional']),
              contributionScore: _optionalNumber(goalScores['contribution']),
            );
          })
          .where((entry) => entry.userId.isNotEmpty)
          .toList();
      return entries;
    }

    List<LeaderboardApiCompanyEntry> rankEntries(
      List<LeaderboardApiCompanyEntry> entries,
    ) {
      entries.sort(
          (left, right) => right.overallScore.compareTo(left.overallScore));
      return [
        for (var index = 0; index < entries.length; index++)
          LeaderboardApiCompanyEntry(
            userId: entries[index].userId,
            name: entries[index].name,
            score: entries[index].score,
            goalScore: entries[index].goalScore,
            coreTaskScore: entries[index].coreTaskScore,
            overallScore: entries[index].overallScore,
            rank: index + 1,
            profilePic: entries[index].profilePic,
            teamName: entries[index].teamName,
            firstCompletedTrackerAt: entries[index].firstCompletedTrackerAt,
            personalScore: entries[index].personalScore,
            professionalScore: entries[index].professionalScore,
            contributionScore: entries[index].contributionScore,
          )
      ];
    }

    final legacyMembers = parseEntries(response['members']);
    final users =
        rankEntries(parseEntries(response['users'] ?? response['members']));
    final coaches = rankEntries(parseEntries(response['coaches']));

    return LeaderboardApiSnapshot(
      companyCode: 'ABU15DN',
      companyName: 'Abundance 12',
      leaderboardPeriodStart: null,
      leaderboardPeriodEnd: null,
      entries: users.isNotEmpty ? users : rankEntries(legacyMembers),
      groups: const <LeaderboardApiGroup>[],
      menteeEntries: const <LeaderboardApiGroupMember>[],
      coachEntries: coaches,
    );
  }
}

num _number(dynamic value, {num fallback = 0}) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '') ?? fallback;
}

num? _optionalNumber(dynamic value) {
  if (value is num) return value;
  final raw = value?.toString().trim() ?? '';
  return raw.isEmpty ? null : num.tryParse(raw);
}
