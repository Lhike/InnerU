import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_status_view.dart';
import 'package:selfcare_projects/src/services/coach_api_service.dart';

typedef AbundanceCoachCollectionLoader = Future<List<Map<String, dynamic>>>
    Function();

class AbundanceCoachStudentsScreen extends StatelessWidget {
  const AbundanceCoachStudentsScreen({
    super.key,
    this.loader,
    required this.onOpenManagement,
  });

  final AbundanceCoachCollectionLoader? loader;
  final VoidCallback onOpenManagement;

  @override
  Widget build(BuildContext context) => _AbundanceCoachCollectionScreen(
        title: 'Students',
        copy: 'Your Abundance students and their current council placement.',
        emptyMessage: 'No students are assigned to you yet.',
        loader: loader ?? CoachApiService.instance.fetchMentees,
        label: (item) => _value(item, const ['name', 'fullName', 'username'],
            fallback: 'Student'),
        subtitle: (item) => _value(
          item,
          const ['groupName', 'group_name', 'email'],
          fallback: 'Abundance member',
        ),
        actionLabel: 'Manage students',
        onAction: onOpenManagement,
      );
}

class AbundanceCoachCouncilsScreen extends StatelessWidget {
  const AbundanceCoachCouncilsScreen({
    super.key,
    this.loader,
    required this.onOpenMeetings,
  });

  final AbundanceCoachCollectionLoader? loader;
  final VoidCallback onOpenMeetings;

  @override
  Widget build(BuildContext context) => _AbundanceCoachCollectionScreen(
        title: 'Councils',
        copy: 'The groups you guide inside Abundance 12.',
        emptyMessage: 'No councils are assigned to you yet.',
        loader: loader ?? CoachApiService.instance.fetchGroups,
        label: (item) => _value(item, const ['name'], fallback: 'Council'),
        subtitle: (item) {
          final count = item['memberCount'] ?? item['member_count'];
          return count == null ? 'Your council' : '$count members';
        },
        actionLabel: 'Council meetings',
        onAction: onOpenMeetings,
      );
}

class AbundanceCoachCoreTasksScreen extends StatelessWidget {
  const AbundanceCoachCoreTasksScreen({super.key, this.loader});

  final AbundanceCoachCollectionLoader? loader;

  static Future<List<Map<String, dynamic>>> loadFromInnerU() async {
    final api = CoachApiService.instance;
    final mentees = await api.fetchMentees();
    final rows = <Map<String, dynamic>>[];
    for (final mentee in mentees) {
      final id = (mentee['id'] ?? mentee['userId'] ?? '').toString();
      if (id.isEmpty) continue;
      final name = _value(
        mentee,
        const ['name', 'fullName', 'username'],
        fallback: 'Student',
      );
      final tasks = await api.fetchMenteeTodoTasks(id);
      for (final task in tasks) {
        final type = (task['goalType'] ?? task['goal_type'] ?? '')
            .toString()
            .toUpperCase();
        if (type != 'EVERYDAY' && type != 'DAILY') continue;
        rows.add(<String, dynamic>{...task, 'studentName': name});
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) => _AbundanceCoachCollectionScreen(
        title: 'Core Tasks',
        copy: 'Everyday missions assigned to the students you coach.',
        emptyMessage: 'No everyday core tasks are available yet.',
        loader: loader ?? loadFromInnerU,
        label: (item) =>
            _value(item, const ['title', 'name'], fallback: 'Everyday mission'),
        subtitle: (item) =>
            _value(item, const ['studentName'], fallback: 'Abundance student'),
      );
}

class _AbundanceCoachCollectionScreen extends StatefulWidget {
  const _AbundanceCoachCollectionScreen({
    required this.title,
    required this.copy,
    required this.emptyMessage,
    required this.loader,
    required this.label,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String copy;
  final String emptyMessage;
  final AbundanceCoachCollectionLoader loader;
  final String Function(Map<String, dynamic>) label;
  final String Function(Map<String, dynamic>) subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_AbundanceCoachCollectionScreen> createState() =>
      _AbundanceCoachCollectionScreenState();
}

class _AbundanceCoachCollectionScreenState
    extends State<_AbundanceCoachCollectionScreen> {
  late Future<List<Map<String, dynamic>>> _future = widget.loader();

  Future<void> _reload() async {
    final future = widget.loader();
    setState(() => _future = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      appBar: AppBar(
        backgroundColor: AbundanceColors.surfaceRaised,
        foregroundColor: AbundanceColors.foreground,
        title: Text(widget.title, style: AbundanceTypography.title),
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
                  message: '${widget.title} could not be loaded.',
                  onRetry: _reload,
                );
              }
              final items = snapshot.data ?? const <Map<String, dynamic>>[];
              if (items.isEmpty) {
                return AbundanceStatusView.empty(
                  message: widget.emptyMessage,
                  actionLabel: widget.actionLabel,
                  onAction: widget.onAction,
                );
              }
              return RefreshIndicator(
                onRefresh: _reload,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('COACHING', style: AbundanceTypography.eyebrow),
                    const SizedBox(height: 6),
                    Text(widget.title, style: AbundanceTypography.display),
                    const SizedBox(height: 8),
                    Text(
                      widget.copy,
                      style: AbundanceTypography.body
                          .copyWith(color: AbundanceColors.muted),
                    ),
                    const SizedBox(height: 18),
                    for (final item in items)
                      AbundanceCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.shield_outlined,
                            color: AbundanceColors.primaryGold,
                          ),
                          title: Text(
                            widget.label(item),
                            style: AbundanceTypography.title,
                          ),
                          subtitle: Text(
                            widget.subtitle(item),
                            style: AbundanceTypography.body
                                .copyWith(color: AbundanceColors.muted),
                          ),
                        ),
                      ),
                    if (widget.onAction != null)
                      OutlinedButton(
                        onPressed: widget.onAction,
                        child: Text(widget.actionLabel!),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _value(
  Map<String, dynamic> item,
  List<String> keys, {
  required String fallback,
}) {
  for (final key in keys) {
    final value = item[key]?.toString().trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return fallback;
}
