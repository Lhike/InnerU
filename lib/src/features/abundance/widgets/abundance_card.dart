import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';

class AbundanceCard extends StatelessWidget {
  const AbundanceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: AbundanceColors.surfaceRaised,
        border: Border.all(color: AbundanceColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: content,
      ),
    );
  }
}
