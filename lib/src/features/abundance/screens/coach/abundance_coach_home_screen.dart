import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';

class AbundanceCoachHomeScreen extends StatelessWidget {
  const AbundanceCoachHomeScreen({
    super.key,
    required this.onDestination,
  });

  final ValueChanged<String> onDestination;

  static const _tools = <({String key, String label, IconData icon})>[
    (key: 'coach_students', label: 'Students', icon: Icons.school_outlined),
    (key: 'coach_councils', label: 'Councils', icon: Icons.groups_outlined),
    (key: 'coach_core_tasks', label: 'Core Tasks', icon: Icons.checklist),
    (key: 'coach_quests', label: 'Quest List', icon: Icons.flag_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: .16,
              child: Image.asset(abundanceBackdropAsset, fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('ABUNDANCE 12', style: AbundanceTypography.eyebrow),
                const SizedBox(height: 8),
                const Text('Coach tools', style: AbundanceTypography.display),
                const SizedBox(height: 8),
                Text(
                  'Guide your councils through the same missions, quests, and progress they see.',
                  style: AbundanceTypography.body.copyWith(
                    color: AbundanceColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                for (final tool in _tools)
                  AbundanceCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => onDestination(tool.key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(tool.icon, color: AbundanceColors.primaryGold),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                tool.label,
                                style: AbundanceTypography.title,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              color: AbundanceColors.primaryGold,
                            ),
                          ],
                        ),
                      ),
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
