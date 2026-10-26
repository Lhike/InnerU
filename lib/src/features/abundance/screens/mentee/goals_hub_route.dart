import 'package:flutter/material.dart';
import 'package:selfcare_projects/src/features/abundance/domain/abundance_company.dart';
import 'package:selfcare_projects/src/features/abundance/screens/mentee/goals_hub_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/services/company_theme_service.dart';
import 'package:selfcare_projects/src/utils/theme/app_theme.dart';

Widget themedGoalsHubRoute(CompanyThemeData companyTheme, {String? uid}) {
  final isAbundance = AbundanceCompany.matches(
    companyTheme.companyCode,
    companyTheme.companyName,
  );

  return Theme(
    data: AppTheme.company(companyTheme),
    child: GoalsHubScreen(
      service: isAbundance ? GoalsService.abundance() : null,
      uid: uid,
    ),
  );
}

/// Adapter for the legacy Tasks/Quest entry point, which otherwise created a
/// default InnerU GoalsService and wrote Abundance quests to the wrong API.
Widget buildAbundanceGoalsHub(CompanyThemeData companyTheme, String uid) {
  return themedGoalsHubRoute(companyTheme, uid: uid);
}
