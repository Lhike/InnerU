import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/domain/abundance_navigation.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';

class AbundanceMoreSheet extends StatelessWidget {
  const AbundanceMoreSheet({
    super.key,
    required this.isCoach,
    required this.onDestination,
    this.displayName = '',
    this.email = '',
    this.roleLabel = 'Coach',
    this.appearance = 'dark',
    this.onAppearanceChanged,
  });

  final bool isCoach;
  final ValueChanged<String> onDestination;
  final String displayName;
  final String email;
  final String roleLabel;
  final String appearance;
  final ValueChanged<String>? onAppearanceChanged;

  @override
  Widget build(BuildContext context) {
    final items = abundanceNavigationFor(isCoach: isCoach).where((item) =>
        item.key == 'notifications' || (item.coachOnly && item.key != 'more'));
    // ListTile paints ink/background on its nearest Material ancestor. Using
    // Material here keeps the sheet's surface while avoiding Flutter's
    // invisible-ink assertion when this menu is opened in tests or on device.
    return Material(
      color: AbundanceColors.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AbundanceColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close ×', style: TextStyle(fontSize: 18)),
                ),
              ),
              const Text('COACHING', style: AbundanceTypography.title),
              const SizedBox(height: 8),
              for (final item in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(item.icon, color: AbundanceColors.foreground),
                  title: Text(item.label, style: AbundanceTypography.body),
                  onTap: () => onDestination(item.key),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
