import 'package:selfcare_projects/src/features/authentication/screen/step_tracker.dart/walker_avatar.dart';
import 'package:selfcare_projects/src/features/marathon/marathon_theme.dart';
import 'package:selfcare_projects/src/services/leaderboard_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads and saves the user's walker outside the race screen, so a
/// marathon can dress it in the theme kit.
class MarathonKit {
  const MarathonKit._();

  static const lookKey = 'step_race_look';

  static Future<WalkerLook> loadLook() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return WalkerLook.fromJson(prefs.getString(lookKey));
    } catch (_) {
      return const WalkerLook();
    }
  }

  /// Dresses the walker in [theme]'s kit with [bib] and shares it with the
  /// company. Returns the new look; throws if the server rejects it.
  static Future<WalkerLook> wear(
    MarathonTheme theme,
    int bib, {
    Future<void> Function(Map<String, dynamic> look)? saver,
  }) async {
    final look = theme.dress(await loadLook(), bib);
    await (saver ??
        LeaderboardApiService.instance.saveWalkerLook)(look.toMap());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(lookKey, look.toJson());
    return look;
  }
}
