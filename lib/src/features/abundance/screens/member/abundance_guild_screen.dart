import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/services/abundance_leaderboard_service.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_controller.dart';
import 'package:selfcare_projects/src/features/authentication/screen/leaderboard/leaderboard_screen.dart';

/// Abundance's Guild is a company-wide leaderboard/directory.
///
/// Council membership is intentionally not consulted here. The API returns
/// all Abundance users, and returns a separate coach board only when the
/// authenticated account has the Coach role.
class AbundanceGuildScreen extends StatelessWidget {
  const AbundanceGuildScreen({
    super.key,
    this.onSignOut,
    this.tutorialController,
  });

  final VoidCallback? onSignOut;
  final AbundanceTutorialController? tutorialController;

  Widget buildLeaderboard() => Leaderboard(
        appBarTitle: 'Allies',
        apiLoader: AbundanceLeaderboardService().fetchLeaderboard,
      );

  @override
  Widget build(BuildContext context) {
    return Leaderboard(
      appBarTitle: 'Allies',
      apiLoader: AbundanceLeaderboardService().fetchLeaderboard,
      onSignOut: onSignOut,
      tutorialController: tutorialController,
    );
  }
}
