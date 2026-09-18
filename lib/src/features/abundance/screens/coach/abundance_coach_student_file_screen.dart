import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_status_view.dart';
import 'package:selfcare_projects/src/services/coach_api_service.dart';

/// The student file opened from the Coach Students roster.
///
/// This uses the existing authenticated Coach API rather than duplicating
/// student data locally. It intentionally keeps the same read-only boundary
/// as the source student file for the data currently exposed by InnerU:
/// quests are read from the student's server-backed goals and are never
/// silently edited as the coach browses the file.
class AbundanceCoachStudentFileScreen extends StatefulWidget {
  const AbundanceCoachStudentFileScreen({
    super.key,
    required this.student,
    this.loader,
  });

  final Map<String, dynamic> student;
  final Future<List<Map<String, dynamic>>> Function(String studentId)? loader;

  @override
  State<AbundanceCoachStudentFileScreen> createState() =>
      _AbundanceCoachStudentFileScreenState();
}

class _AbundanceCoachStudentFileScreenState
    extends State<AbundanceCoachStudentFileScreen> {
  late Future<List<Map<String, dynamic>>> _future;

  String get _studentId =>
      (widget.student['id'] ?? widget.student['userId'] ?? '').toString();

  String get _name => _value(
        widget.student,
        const ['name', 'fullName', 'username'],
        fallback: 'Student',
      );

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    final loader = widget.loader ?? CoachApiService.instance.fetchMenteeGoals;
    return loader(_studentId);
  }

  void _retry() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      appBar: AppBar(
        backgroundColor: AbundanceColors.surfaceRaised,
        foregroundColor: AbundanceColors.foreground,
        title: Text('Student file', style: AbundanceTypography.title),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: .1,
              child: Image.asset(abundanceBackdropAsset, fit: BoxFit.cover),
            ),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AbundanceStatusView.loading();
              }
              if (snapshot.hasError) {
                return AbundanceStatusView.error(
                  message: 'This student file could not be loaded.',
                  onRetry: _retry,
                );
              }
              final goals = snapshot.data ?? const <Map<String, dynamic>>[];
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('COACHING · STUDENT FILE',
                      style: AbundanceTypography.eyebrow),
                  const SizedBox(height: 6),
                  Text(_name, style: AbundanceTypography.display),
                  const SizedBox(height: 8),
                  Text(
                    _value(widget.student, const ['groupName', 'group_name'],
                        fallback: 'Abundance student'),
                    style: AbundanceTypography.body
                        .copyWith(color: AbundanceColors.muted),
                  ),
                  const SizedBox(height: 18),
                  Text('Quest progress', style: AbundanceTypography.title),
                  const SizedBox(height: 10),
                  if (goals.isEmpty)
                    const Text('No quests added yet.',
                        style: AbundanceTypography.body)
                  else
                    for (final goal in goals)
                      AbundanceCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.flag_outlined,
                              color: AbundanceColors.primaryGold),
                          title: Text(
                            _value(goal, const ['title', 'name'],
                                fallback: 'Quest'),
                            style: AbundanceTypography.title,
                          ),
                          subtitle: Text(
                            '${goal['progress'] ?? 0}% · ${_value(goal, const [
                                  'status'
                                ], fallback: 'In progress')}',
                            style: AbundanceTypography.body
                                .copyWith(color: AbundanceColors.muted),
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _value(Map<String, dynamic> item, List<String> keys,
    {required String fallback}) {
  for (final key in keys) {
    final value = item[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return fallback;
}
