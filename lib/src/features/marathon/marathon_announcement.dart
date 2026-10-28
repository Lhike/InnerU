import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/step_leaderboard_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_list_screen.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_theme.dart';
import 'package:selfcare_projects/src/services/marathon_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "We have a marathon!" popup on the step page. Each marathon is
/// announced once; "See the race" opens it in the steps leaderboard.
class MarathonAnnouncement {
  const MarathonAnnouncement._();

  static String seenKey(String marathonId) => 'marathon_announced_$marathonId';

  /// The marathon to announce: open or upcoming, not joined yet and not
  /// announced before.
  static Future<Marathon?> pick(
    MarathonApiService api,
    SharedPreferences prefs,
  ) async {
    final marathons = await api.fetchMarathons();
    final candidates = marathons
        .where((m) =>
            m.phase != MarathonPhase.ended &&
            m.myRegistration == null &&
            prefs.getBool(seenKey(m.id)) != true)
        .toList()
      // Running races first, then the soonest to open.
      ..sort((a, b) => a.phase != b.phase
          ? (a.phase == MarathonPhase.ongoing ? -1 : 1)
          : a.startsAt.compareTo(b.startsAt));
    return candidates.firstOrNull;
  }

  static Future<void> maybeShow(
    BuildContext context, {
    MarathonApiService? api,
    DateTime? today,
  }) async {
    final service = api ?? MarathonApiService.instance;
    final Marathon? marathon;
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      marathon = await pick(service, prefs);
    } catch (error) {
      debugPrint('Marathon announcement skipped: $error');
      return;
    }
    if (marathon == null || !context.mounted) return;
    await prefs.setBool(seenKey(marathon.id), true);
    if (!context.mounted) return;

    final seeRace = await showDialog<bool>(
      context: context,
      builder: (context) => _AnnouncementDialog(
        marathon: marathon!,
        today: today ?? DateTime.now(),
      ),
    );
    if (seeRace == true && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StepLeaderboardScreen(
            initialMarathonId: marathon!.id,
            marathonApi: api,
          ),
        ),
      );
    }
  }
}

class _AnnouncementDialog extends StatelessWidget {
  const _AnnouncementDialog({required this.marathon, required this.today});

  final Marathon marathon;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = marathon.look;
    final dates = DateFormat('MMM d');

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: theme.gradient,
              ),
            ),
            child: Column(
              children: [
                Text(theme.emoji, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 8),
                const Text(
                  'We have a marathon!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  marathon.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              children: [
                Text(
                  '${formatKm(marathon.distanceKm)} km · '
                  '${dates.format(marathon.startsAt)} – ${dates.format(marathon.endsAt)} · '
                  '${formatPrice(marathon)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  marathonStatusLabel(marathon, today),
                  style: TextStyle(color: theme.accent),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Walk it at your own pace. Finishers receive a finisher '
                  'shirt, medal and certificate.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Later'),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style:
                        FilledButton.styleFrom(backgroundColor: theme.accent),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('See the race'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
