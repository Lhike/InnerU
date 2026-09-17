import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/domain/abundance_navigation.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';

class AbundanceMoreSheet extends StatelessWidget {
  const AbundanceMoreSheet({
    super.key,
    required this.isCoach,
    required this.onDestination,
  });

  final bool isCoach;
  final ValueChanged<String> onDestination;

  @override
  Widget build(BuildContext context) {
    final items = abundanceNavigationFor(isCoach: isCoach)
        .where((item) => item.kind == AbundanceDestinationKind.overflow);
    return ColoredBox(
      color: AbundanceColors.surfaceRaised,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AbundanceColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('EXPLORE', style: AbundanceTypography.eyebrow),
              const SizedBox(height: 8),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(item.icon, color: AbundanceColors.primaryGold),
                  title: Text(item.label, style: AbundanceTypography.body),
                  trailing: const Icon(Icons.chevron_right,
                      color: AbundanceColors.muted),
                  onTap: () => onDestination(item.key),
                ),
              const Divider(color: AbundanceColors.border),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.receipt_long_outlined,
                    color: AbundanceColors.primaryGold),
                title: const Text('Activity Logs',
                    style: AbundanceTypography.body),
                trailing: const Icon(Icons.chevron_right,
                    color: AbundanceColors.muted),
                onTap: () => onDestination('activity_logs'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_awesome_outlined,
                    color: AbundanceColors.primaryGold),
                title: const Text('Replay tutorial',
                    style: AbundanceTypography.body),
                trailing: const Icon(Icons.chevron_right,
                    color: AbundanceColors.muted),
                onTap: () => onDestination('tutorial'),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded,
                    color: AbundanceColors.scoreCritical),
                title: const Text('Log out', style: AbundanceTypography.body),
                onTap: () => onDestination('sign_out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
