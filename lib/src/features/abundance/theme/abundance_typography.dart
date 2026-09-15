import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';

abstract final class AbundanceTypography {
  static const String displayFamily = 'AbundanceCinzel';
  static const String bodyFamily = 'AbundanceInter';

  static const TextStyle display = TextStyle(
    fontFamily: displayFamily,
    color: AbundanceColors.foreground,
    fontSize: 30,
    fontWeight: FontWeight.w700,
    height: 1.1,
  );

  static const TextStyle title = TextStyle(
    fontFamily: displayFamily,
    color: AbundanceColors.foreground,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle body = TextStyle(
    fontFamily: bodyFamily,
    color: AbundanceColors.foreground,
    fontSize: 15,
    height: 1.45,
  );

  static const TextStyle eyebrow = TextStyle(
    fontFamily: bodyFamily,
    color: AbundanceColors.primaryGold,
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
  );
}
