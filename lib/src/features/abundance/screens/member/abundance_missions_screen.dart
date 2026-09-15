import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_button.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';

class AbundanceMissionsScreen extends StatelessWidget {
  const AbundanceMissionsScreen({
    super.key,
    required this.onOpenDailyMission,
    required this.onOpenMissionPlan,
  });

  final VoidCallback onOpenDailyMission;
  final VoidCallback onOpenMissionPlan;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AbundanceColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 210,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(abundanceHomeSceneAsset, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xF2080C1C)],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EVERYDAY MISSIONS',
                            style: AbundanceTypography.eyebrow),
                        SizedBox(height: 8),
                        Text('Forge today.',
                            style: AbundanceTypography.display),
                        SizedBox(height: 6),
                        Text(
                          'Small disciplines become the kingdom you build.',
                          style: AbundanceTypography.body,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AbundanceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.bolt,
                    color: AbundanceColors.primaryGold, size: 30),
                const SizedBox(height: 12),
                const Text("TODAY'S MISSION", style: AbundanceTypography.title),
                const SizedBox(height: 6),
                Text(
                  'Track the core actions that move your Life Power today.',
                  style: AbundanceTypography.body
                      .copyWith(color: AbundanceColors.muted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: AbundanceButton(
                    label: 'Open daily mission',
                    icon: Icons.checklist,
                    onPressed: onOpenDailyMission,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AbundanceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.calendar_month_outlined,
                    color: AbundanceColors.accentCyan, size: 30),
                const SizedBox(height: 12),
                const Text('MISSION PLAN', style: AbundanceTypography.title),
                const SizedBox(height: 6),
                Text(
                  'Create, schedule, complete, and review your personal tasks.',
                  style: AbundanceTypography.body
                      .copyWith(color: AbundanceColors.muted),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: AbundanceButton(
                    label: 'Manage mission plan',
                    outlined: true,
                    icon: Icons.edit_calendar_outlined,
                    onPressed: onOpenMissionPlan,
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
