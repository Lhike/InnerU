import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';

class AbundanceButton extends StatelessWidget {
  const AbundanceButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outlined;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Text(label),
      ],
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(44, 48)),
      foregroundColor: WidgetStatePropertyAll(
        outlined ? AbundanceColors.primaryGold : AbundanceColors.surfaceSunken,
      ),
      backgroundColor: WidgetStatePropertyAll(
        outlined ? Colors.transparent : AbundanceColors.primaryGold,
      ),
      side: const WidgetStatePropertyAll(
        BorderSide(color: AbundanceColors.primaryGold),
      ),
      textStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontFamily: AbundanceTypography.bodyFamily,
          fontWeight: FontWeight.w800,
          letterSpacing: .4,
        ),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: outlined
            ? OutlinedButton(onPressed: onPressed, style: style, child: child)
            : FilledButton(onPressed: onPressed, style: style, child: child),
      ),
    );
  }
}
