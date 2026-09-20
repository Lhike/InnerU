import 'dart:async';

import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_status_view.dart';
import 'package:selfcare_projects/src/services/coach_api_service.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_api_transport.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';

typedef AbundanceCoachCollectionLoader = Future<List<Map<String, dynamic>>>
    Function();

class AbundanceCoachStudentsScreen extends StatelessWidget {
  const AbundanceCoachStudentsScreen({
    super.key,
    this.loader,
    required this.onOpenManagement,
    this.onOpenStudent,
  });

  final AbundanceCoachCollectionLoader? loader;
  final VoidCallback onOpenManagement;
  final ValueChanged<Map<String, dynamic>>? onOpenStudent;

  @override
  Widget build(BuildContext context) => _AbundanceCoachCollectionScreen(
        title: 'Students',
        copy: 'Your Abundance students and their current council placement.',
        emptyMessage: 'No students are assigned to you yet.',
        loader: loader ??
            GoalsService(null, A12ApiTransport()).fetchA12CoachRoster,
        label: _abundanceStudentName,
        subtitle: (item) => _value(
          item,
          const ['council', 'groupName', 'group_name', 'menteeEmail', 'email'],
          fallback: 'Abundance member',
        ),
        itemActionLabel: 'Open student file',
        onItemTap: onOpenStudent,
      );
}

String _abundanceStudentName(Map<String, dynamic> item) {
  final first = item['firstName']?.toString().trim() ?? '';
  final last = item['lastName']?.toString().trim() ?? '';
  final fullName = '$first $last'.trim();
  if (fullName.isNotEmpty) return fullName;
  return _value(
    item,
    const ['menteeName', 'name', 'fullName', 'username'],
    fallback: 'Student',
  );
}

class AbundanceCoachCouncilsScreen extends StatelessWidget {
  const AbundanceCoachCouncilsScreen({
    super.key,
    this.loader,
    required this.onOpenMeetings,
    this.createGroup,
  });

  final AbundanceCoachCollectionLoader? loader;
  final VoidCallback onOpenMeetings;
  final Future<String> Function(String name)? createGroup;

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
        createGroup: createGroup ??
            ((name) => CoachApiService.instance.createGroup(name: name)),
      );
}

class AbundanceCoachCoreTasksScreen extends StatelessWidget {
  const AbundanceCoachCoreTasksScreen({super.key, this.loader, this.service});

  final AbundanceCoachCollectionLoader? loader;
  final GoalsService? service;

  static Future<List<Map<String, dynamic>>> loadFromA12() async {
    final roster =
        await GoalsService(null, A12ApiTransport()).fetchA12CoachRoster();
    final rows = <Map<String, dynamic>>[];
    for (final student in roster) {
      final name =
          '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}'.trim();
      final missions = student['missions'] is List
          ? (student['missions'] as List).whereType<Map>()
          : const <Map>[];
      final total = missions.length;
      final completed =
          missions.where((mission) => mission['completed'] == true).length;
      rows.add(<String, dynamic>{
        'studentName': name.isEmpty ? 'Student' : name,
        'studentId': student['id'],
        'completed': completed,
        'total': total,
        'progress': total == 0 ? 0.0 : completed / total,
        'missions': missions
            .map((mission) => Map<String, dynamic>.from(mission))
            .toList(),
      });
    }
    return rows;
  }

  static Future<List<Map<String, dynamic>>> loadFromInnerU() async {
    final api = CoachApiService.instance;
    final mentees = await api.fetchMentees();
    final rows = <Map<String, dynamic>>[];
    for (final mentee in mentees) {
      final id = (mentee['id'] ?? mentee['userId'] ?? '').toString();
      if (id.isEmpty) continue;
      final name = _value(mentee, const ['name', 'fullName', 'username'],
          fallback: 'Student');
      final tasks = await api.fetchMenteeTodoTasks(id);
      final daily = tasks.where((task) {
        final type = (task['goalType'] ?? task['goal_type'] ?? '')
            .toString()
            .toUpperCase();
        return type == 'EVERYDAY' || type == 'DAILY';
      }).toList();
      final completed = daily
          .where((task) =>
              task['completed'] == true || task['isCompleted'] == true)
          .length;
      rows.add(<String, dynamic>{
        'studentName': name,
        'completed': completed,
        'total': daily.length,
        'progress': daily.isEmpty ? 0.0 : completed / daily.length,
        'missions': daily
      });
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return _CoreTaskMonitoringScreen(
      loader: loader ??
          () async {
            try {
              final roster =
                  await (service ?? GoalsService(null, A12ApiTransport()))
                      .fetchA12CoachRoster();
              return _missionRows(roster);
            } catch (_) {
              try {
                return await loadFromInnerU();
              } catch (_) {
                return const <Map<String, dynamic>>[];
              }
            }
          },
    );
  }
}

List<Map<String, dynamic>> _missionRows(List<Map<String, dynamic>> roster) {
  final rows = <Map<String, dynamic>>[];
  for (final student in roster) {
    final name =
        '${student['firstName'] ?? ''} ${student['lastName'] ?? ''}'.trim();
    final missions = student['missions'] is List
        ? (student['missions'] as List).whereType<Map>()
        : const <Map>[];
    final total = missions.length;
    final completed =
        missions.where((mission) => mission['completed'] == true).length;
    rows.add(<String, dynamic>{
      'studentName': name.isEmpty ? 'Student' : name,
      'studentId': student['id'],
      'completed': completed,
      'total': total,
      'progress': total == 0 ? 0.0 : completed / total,
      'missions': missions
          .map((mission) => Map<String, dynamic>.from(mission))
          .toList(),
    });
  }
  return rows;
}

class _CoreTaskMonitoringScreen extends StatelessWidget {
  const _CoreTaskMonitoringScreen({required this.loader});

  final AbundanceCoachCollectionLoader loader;

  @override
  Widget build(BuildContext context) => _AbundanceCoachCollectionScreen(
        title: 'Core Tasks',
        copy: 'Monitor mission progress for every student assigned to you.',
        emptyMessage: 'No mission progress is available yet.',
        loader: loader,
        label: (item) => _value(
          item,
          const ['title', 'name', 'studentName'],
          fallback: 'Student',
        ),
        subtitle: (item) =>
            '${item['completed'] ?? 0}/${item['total'] ?? 0} missions completed',
        progress: (item) => (item['progress'] as num?)?.toDouble() ?? 0,
        detail: (item) => _missionSummary(item),
      );
}

String _missionSummary(Map<String, dynamic> item) {
  final missions = item['missions'];
  if (missions is! List || missions.isEmpty) return 'No missions scheduled.';
  return missions
      .map((mission) {
        if (mission is! Map) return '';
        final title = mission['name'] ?? mission['title'] ?? 'Mission';
        return '$title · ${mission['completed'] == true ? 'Completed' : 'Not completed'}';
      })
      .where((value) => value.isNotEmpty)
      .join('\n');
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
    this.createGroup,
    this.onItemTap,
    this.itemActionLabel,
    this.progress,
    this.detail,
  });

  final String title;
  final String copy;
  final String emptyMessage;
  final AbundanceCoachCollectionLoader loader;
  final String Function(Map<String, dynamic>) label;
  final String Function(Map<String, dynamic>) subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Future<String> Function(String name)? createGroup;
  final ValueChanged<Map<String, dynamic>>? onItemTap;
  final String? itemActionLabel;
  final double Function(Map<String, dynamic>)? progress;
  final String Function(Map<String, dynamic>)? detail;

  @override
  State<_AbundanceCoachCollectionScreen> createState() =>
      _AbundanceCoachCollectionScreenState();
}

class _AbundanceCoachCollectionScreenState
    extends State<_AbundanceCoachCollectionScreen> {
  late Future<List<Map<String, dynamic>>> _future = widget.loader();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    if (widget.title == 'Students') {
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (mounted) {
          final future = widget.loader();
          setState(() {
            _future = future;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final future = widget.loader();
    setState(() {
      _future = future;
    });
    await future;
  }

  Future<void> _showCreateCouncil() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AbundanceColors.surfaceRaised,
        title: const Text('Create council',
            style: TextStyle(color: AbundanceColors.foreground)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AbundanceColors.foreground),
          decoration: const InputDecoration(
            labelText: 'Council name',
            labelStyle: TextStyle(color: AbundanceColors.muted),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || name == null || name.trim().isEmpty) return;
    try {
      await widget.createGroup!(name.trim());
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Council created.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Council could not be created.')),
      );
    }
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
                    if (widget.createGroup != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          onPressed: _showCreateCouncil,
                          icon: const Icon(Icons.add),
                          label: const Text('Create council'),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    for (final item in items)
                      AbundanceCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.shield_outlined,
                                  color: AbundanceColors.primaryGold),
                              title: Text(widget.label(item),
                                  style: AbundanceTypography.title),
                              subtitle: Text(widget.subtitle(item),
                                  style: AbundanceTypography.body
                                      .copyWith(color: AbundanceColors.muted)),
                              onTap: widget.onItemTap == null
                                  ? null
                                  : () => widget.onItemTap!(item),
                            ),
                            if (widget.progress != null) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: LinearProgressIndicator(
                                  value: widget.progress!(item).clamp(0, 1),
                                  minHeight: 7,
                                  backgroundColor:
                                      AbundanceColors.surfaceSunken,
                                  valueColor: const AlwaysStoppedAnimation(
                                      AbundanceColors.primaryGold),
                                ),
                              ),
                              if (widget.detail != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 8, 16, 12),
                                  child: Text(widget.detail!(item),
                                      style: AbundanceTypography.body.copyWith(
                                          color: AbundanceColors.muted)),
                                ),
                            ],
                            if (widget.itemActionLabel != null &&
                                widget.onItemTap != null)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => widget.onItemTap!(item),
                                  child: Text(widget.itemActionLabel!),
                                ),
                              ),
                          ],
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
