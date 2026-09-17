import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/domain/abundance_company.dart';
import 'package:selfcare_projects/src/features/abundance/screens/member/abundance_onboarding_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_onboarding_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/services/company_membership_service.dart';
import 'package:selfcare_projects/src/services/company_theme_service.dart';

/// Resolves the first-run state only after [CompanyLoadingGate] has resolved
/// the active company. Non-Abundance users return the existing shell child
/// synchronously and never query Abundance data.
class AbundancePostAuthGate extends StatefulWidget {
  const AbundancePostAuthGate({
    super.key,
    required this.uid,
    required this.initialName,
    required this.companyTheme,
    required this.isCoach,
    required this.child,
    this.service,
  });

  final String uid;
  final String initialName;
  final CompanyThemeData? companyTheme;
  final bool isCoach;
  final Widget child;
  final AbundanceOnboardingService? service;

  @override
  State<AbundancePostAuthGate> createState() => _AbundancePostAuthGateState();
}

class _AbundancePostAuthGateState extends State<AbundancePostAuthGate> {
  late final AbundanceOnboardingService _service =
      widget.service ??
      AbundanceOnboardingService(
        goals: GoalsService(null, A12ApiTransport()),
      );
  late Future<bool> _complete = _resolve();

  bool get _isAbundance =>
      widget.companyTheme != null &&
      AbundanceCompany.matches(
        widget.companyTheme!.companyCode,
        widget.companyTheme!.companyName,
      );

  bool get _needsCompanyResolution =>
      !widget.isCoach && (widget.companyTheme == null || _isAbundance);

  Future<bool> _resolve() async {
    if (widget.isCoach) return true;
    if (widget.companyTheme != null && !_isAbundance) return true;

    // A restored session may not have a persisted theme yet. Resolve the
    // active membership before deciding whether to ask for Abundance setup;
    // otherwise a first launch after reinstall could skip onboarding.
    if (widget.companyTheme == null) {
      try {
        final membership =
            await CompanyMembershipService.loadForUser(widget.uid)
                .timeout(const Duration(seconds: 8));
        if (!AbundanceCompany.matches(
          membership.activeMembership?.code,
          membership.activeMembership?.name,
        )) {
          return true;
        }
      } catch (_) {
        // Preserve the existing shell if company resolution is unavailable.
        return true;
      }
    }
    return _service.isComplete(widget.uid);
  }

  @override
  void didUpdateWidget(covariant AbundancePostAuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid ||
        oldWidget.companyTheme?.companyCode !=
            widget.companyTheme?.companyCode ||
        oldWidget.isCoach != widget.isCoach) {
      _complete = _resolve();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsCompanyResolution) return widget.child;
    return FutureBuilder<bool>(
      future: _complete,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AbundanceColors.background,
            body: Center(
              child: CircularProgressIndicator(
                color: AbundanceColors.primaryGold,
              ),
            ),
          );
        }
        if (snapshot.data == true) return widget.child;
        return AbundanceOnboardingScreen(
          uid: widget.uid,
          initialName: widget.initialName,
          service: _service,
          onCompleted: () {
            setState(() {
              _complete = Future<bool>.value(true);
            });
          },
        );
      },
    );
  }
}
