import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_button.dart';

class AbundanceStatusView extends StatelessWidget {
  const AbundanceStatusView._({
    required this.message,
    required this.icon,
    this.onRetry,
    this.loading = false,
  });

  const AbundanceStatusView.loading({String message = 'Entering your kingdom…'})
      : this._(message: message, icon: Icons.auto_awesome, loading: true);

  const AbundanceStatusView.empty({
    required String message,
    IconData icon = Icons.explore_outlined,
  }) : this._(message: message, icon: icon);

  const AbundanceStatusView.error({
    required String message,
    required VoidCallback onRetry,
  }) : this._(
          message: message,
          icon: Icons.error_outline,
          onRetry: onRetry,
        );

  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AbundanceColors.background,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CircularProgressIndicator(
                  color: AbundanceColors.primaryGold,
                )
              else
                Icon(icon, color: AbundanceColors.primaryGold, size: 40),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AbundanceTypography.body.copyWith(
                  color: AbundanceColors.muted,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                AbundanceButton(
                  label: 'Try again',
                  outlined: true,
                  onPressed: onRetry,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
