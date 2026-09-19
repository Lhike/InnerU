import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/screens/coach/abundance_coach_management_screens.dart';
import 'package:selfcare_projects/src/features/abundance/screens/coach/coach_quests_roster_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';
import 'package:selfcare_projects/src/services/coach_directory_api_service.dart';

class AbundanceCoachDirectoryScreen extends StatefulWidget {
  const AbundanceCoachDirectoryScreen(
      {super.key, required this.service, required this.coachUid});

  final GoalsService service;
  final String coachUid;

  @override
  State<AbundanceCoachDirectoryScreen> createState() =>
      _AbundanceCoachDirectoryScreenState();
}

class _AbundanceCoachDirectoryScreenState
    extends State<AbundanceCoachDirectoryScreen> {
  late Future<List<CoachDirectoryApiCoach>> _future;

  @override
  void initState() {
    super.initState();
    _future = CoachDirectoryApiService.instance.fetchCoaches();
  }

  void _open(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      appBar: AppBar(
        backgroundColor: AbundanceColors.surfaceRaised,
        foregroundColor: AbundanceColors.foreground,
        title: Text('Coaches', style: AbundanceTypography.title),
      ),
      body: Stack(children: [
        Positioned.fill(
            child: Opacity(
                opacity: .1,
                child: Image.asset(abundanceBackdropAsset, fit: BoxFit.cover))),
        RefreshIndicator(
          onRefresh: () async => setState(
              () => _future = CoachDirectoryApiService.instance.fetchCoaches()),
          child: FutureBuilder<List<CoachDirectoryApiCoach>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AbundanceColors.primaryGold));
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Coaches could not be loaded.',
                        style: AbundanceTypography.body
                            .copyWith(color: AbundanceColors.muted)));
              }
              final coaches = snapshot.data ?? const <CoachDirectoryApiCoach>[];
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text('COACH DIRECTORY', style: AbundanceTypography.eyebrow),
                  const SizedBox(height: 6),
                  Text('Coaches', style: AbundanceTypography.display),
                  const SizedBox(height: 8),
                  Text('Meet the guides behind Abundance 12.',
                      style: AbundanceTypography.body
                          .copyWith(color: AbundanceColors.muted)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                        child: _ReportButton(
                            label: 'All students report',
                            onTap: () => _open(AbundanceCoachCoreTasksScreen(
                                service: widget.service)))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _ReportButton(
                            label: 'View quests report',
                            onTap: () => _open(CoachQuestsRosterScreen(
                                service: widget.service,
                                coachUid: widget.coachUid)))),
                  ]),
                  const SizedBox(height: 16),
                  if (coaches.isEmpty)
                    Text('No coaches are available yet.',
                        style: AbundanceTypography.body
                            .copyWith(color: AbundanceColors.muted))
                  else
                    for (final coach in coaches) _CoachCard(coach: coach),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _ReportButton extends StatelessWidget {
  const _ReportButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(64),
            side: const BorderSide(color: AbundanceColors.border)),
        child: Text(label, textAlign: TextAlign.center),
      );
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.coach});
  final CoachDirectoryApiCoach coach;

  @override
  Widget build(BuildContext context) => AbundanceCard(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: CircleAvatar(
              backgroundColor: AbundanceColors.surfaceSunken,
              child: Text(coach.name.isEmpty
                  ? 'C'
                  : coach.name.substring(0, 1).toUpperCase())),
          title: Text(coach.name.isEmpty ? 'Coach' : coach.name,
              style: AbundanceTypography.title),
          subtitle: Text(coach.email,
              style: AbundanceTypography.body
                  .copyWith(color: AbundanceColors.muted)),
          trailing: const Icon(Icons.chevron_right,
              color: AbundanceColors.primaryGold),
        ),
      );
}
