import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/coach/coach_catalog.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_quest_report_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';

class AbundanceCoachDirectoryScreen extends StatefulWidget {
  const AbundanceCoachDirectoryScreen({
    super.key,
    required this.service,
    required this.coachUid,
  });

  final GoalsService service;
  final String coachUid;

  @override
  State<AbundanceCoachDirectoryScreen> createState() =>
      _AbundanceCoachDirectoryScreenState();
}

class _AbundanceCoachDirectoryScreenState
    extends State<AbundanceCoachDirectoryScreen> {
  late Future<List<AbundanceCoachCatalogEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = AbundanceCoachCatalog.load();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      appBar: AppBar(
        backgroundColor: AbundanceColors.surfaceRaised,
        foregroundColor: AbundanceColors.foreground,
        title: Text('Coaches', style: AbundanceTypography.title),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: .1,
              child: Image.asset(abundanceBackdropAsset, fit: BoxFit.cover),
            ),
          ),
          RefreshIndicator(
            onRefresh: () async => setState(
              () => _future = AbundanceCoachCatalog.load(),
            ),
            child: FutureBuilder<List<AbundanceCoachCatalogEntry>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AbundanceColors.primaryGold,
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Coaches could not be loaded.',
                      style: AbundanceTypography.body.copyWith(
                        color: AbundanceColors.muted,
                      ),
                    ),
                  );
                }
                final coaches =
                    snapshot.data ?? const <AbundanceCoachCatalogEntry>[];
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('COACH DIRECTORY', style: AbundanceTypography.eyebrow),
                    const SizedBox(height: 6),
                    Text('Coaches', style: AbundanceTypography.display),
                    const SizedBox(height: 8),
                    Text(
                      'Meet the guides behind Abundance 12.',
                      style: AbundanceTypography.body.copyWith(
                        color: AbundanceColors.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ReportButton(
                            label: 'All students report',
                            hint: 'Across all councils',
                            icon: '▦',
                            onTap: () => _open(
                              AbundanceCoachQuestReportScreen(
                                isCoach: true,
                                scope: AbundanceCoachReportScope.allStudents,
                                rosterLoader:
                                    widget.service.fetchA12CoachRoster,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ReportButton(
                            label: 'View quests report',
                            hint: 'Council rating sheet',
                            icon: '↗',
                            onTap: () => _open(
                              AbundanceCoachQuestReportScreen(
                                isCoach: true,
                                scope:
                                    AbundanceCoachReportScope.assignedStudents,
                                rosterLoader:
                                    widget.service.fetchA12CoachRoster,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (coaches.isEmpty)
                      Text(
                        'No coaches are available yet.',
                        style: AbundanceTypography.body.copyWith(
                          color: AbundanceColors.muted,
                        ),
                      )
                    else
                      for (final coach in coaches)
                        _CoachCard(
                          coach: coach,
                          onTap: () => _showDetails(coach),
                        ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDetails(AbundanceCoachCatalogEntry coach) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AbundanceColors.surfaceRaised,
        contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        title: Column(
          children: [
            _CoachImage(
              assetPath: coach.assetPath,
              width: 180,
              height: 220,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 12),
            Text(
              coach.name,
              textAlign: TextAlign.center,
              style: AbundanceTypography.title,
            ),
            if (coach.declaration.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                coach.declaration,
                textAlign: TextAlign.center,
                style: AbundanceTypography.body.copyWith(
                  color: AbundanceColors.primaryGold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in coach.background)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      '• $line',
                      style: AbundanceTypography.body.copyWith(
                        color: AbundanceColors.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close coach details'),
          ),
        ],
      ),
    );
  }
}

class _ReportButton extends StatelessWidget {
  const _ReportButton({
    required this.label,
    required this.hint,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String hint;
  final String icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: OutlinedButton(
          onPressed: onTap,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(66)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            ),
            backgroundColor: const WidgetStatePropertyAll(
              AbundanceColors.surfaceRaised,
            ),
            foregroundColor: const WidgetStatePropertyAll(
              AbundanceColors.primaryGold,
            ),
            side: const WidgetStatePropertyAll(
              BorderSide(color: AbundanceColors.border),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(icon),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AbundanceColors.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      );
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.coach, required this.onTap});

  final AbundanceCoachCatalogEntry coach;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AbundanceCard(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: ListTile(
            leading: _CoachImage(
              assetPath: coach.assetPath,
              width: 52,
              height: 56,
            ),
            title: Text(coach.name, style: AbundanceTypography.title),
            subtitle: Text(
              coach.declaration.isEmpty ? 'A12 Coach' : coach.declaration,
              style: AbundanceTypography.body.copyWith(
                color: AbundanceColors.muted,
              ),
            ),
            trailing: const Icon(
              Icons.chevron_right,
              color: AbundanceColors.primaryGold,
            ),
          ),
        ),
      );
}

class _CoachImage extends StatelessWidget {
  const _CoachImage({
    required this.assetPath,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  final String assetPath;
  final double width;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          assetPath,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => Image.asset(
            AbundanceCoachCatalog.fallbackAsset,
            width: width,
            height: height,
            fit: fit,
          ),
        ),
      );
}
