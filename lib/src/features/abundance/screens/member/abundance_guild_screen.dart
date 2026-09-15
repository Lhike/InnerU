import 'package:flutter/widgets.dart';

import 'package:selfcare_projects/src/features/authentication/screen/leaderboard/leaderboard_screen.dart';

/// Abundance's Guild route intentionally delegates to the established
/// leaderboard implementation: that screen already has an explicit A12 data
/// model, rank labels, council/group boards, current-user emphasis, score
/// breakdowns, refresh behavior, and company-scoped API loading.
class AbundanceGuildScreen extends StatelessWidget {
  const AbundanceGuildScreen({super.key});

  Widget buildLeaderboard() => const Leaderboard();

  @override
  Widget build(BuildContext context) => buildLeaderboard();
}
