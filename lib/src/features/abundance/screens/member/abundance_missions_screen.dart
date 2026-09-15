import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:selfcare_projects/src/features/abundance/services/abundance_missions_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_button.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_status_view.dart';
import 'package:selfcare_projects/src/features/authentication/screen/todo_list.dart';

class AbundanceMissionsScreen extends StatefulWidget {
  const AbundanceMissionsScreen({
    super.key,
    this.gateway,
    this.initialDate,
    this.today,
  });

  final AbundanceMissionsGateway? gateway;
  final DateTime? initialDate;
  final DateTime? today;

  @override
  State<AbundanceMissionsScreen> createState() =>
      _AbundanceMissionsScreenState();
}

class _AbundanceMissionsScreenState extends State<AbundanceMissionsScreen> {
  late final AbundanceMissionsGateway _gateway =
      widget.gateway ?? InnerUAbundanceMissionsGateway();
  late DateTime _selected =
      DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
  List<Task> _tasks = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tasks = await _gateway.load();
      if (mounted) setState(() => _tasks = tasks);
    } catch (_) {
      if (mounted) setState(() => _error = 'We could not load your missions.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Task> get _visible => _tasks
      .where((task) =>
          task.goalType == GoalType.everyday &&
          taskOccursOnDate(task, _selected))
      .toList(growable: false);

  bool _completed(Task task) => task.goalType == GoalType.everyday
      ? taskHasCompletionOnDate(task, _selected)
      : task.isCompleted;

  Future<void> _toggle(Task task, bool value) async {
    final previous = Task.fromJson(task.toJson());
    setState(() {
      if (task.goalType == GoalType.everyday) {
        task.completionDates
            .removeWhere((date) => DateUtils.isSameDay(date, _selected));
        if (value) task.completionDates.add(_selected);
      } else {
        task.isCompleted = value;
        task.completedAt = value ? DateTime.now() : null;
      }
    });
    try {
      await _gateway.update(task);
    } catch (_) {
      if (!mounted) return;
      final index = _tasks.indexOf(task);
      setState(() {
        if (index >= 0) _tasks[index] = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not update that mission.')),
      );
    }
  }

  Future<void> _openEditor([Task? existing]) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final descriptionController =
        TextEditingController(text: existing?.description ?? '');
    var tag = existing?.tag ?? TaskTag.none;
    var startDate = DateUtils.dateOnly(existing?.startDate ?? _selected);
    var dueDate = DateUtils.dateOnly(
      existing?.dueDate ?? _selected.add(const Duration(days: 29)),
    );
    final draft = await showModalBottomSheet<_MissionDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AbundanceColors.surfaceRaised,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                existing == null ? 'CREATE MISSION' : 'EDIT MISSION',
                style: AbundanceTypography.title,
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('mission-title-field'),
                controller: titleController,
                autofocus: true,
                maxLength: 120,
                style: AbundanceTypography.body,
                decoration: const InputDecoration(
                  labelText: 'Mission name',
                  labelStyle: TextStyle(color: AbundanceColors.muted),
                ),
              ),
              TextField(
                controller: descriptionController,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                style: AbundanceTypography.body,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  labelStyle: TextStyle(color: AbundanceColors.muted),
                ),
              ),
              DropdownButtonFormField<TaskTag>(
                initialValue: tag,
                dropdownColor: AbundanceColors.surfaceRaised,
                style: AbundanceTypography.body,
                decoration: const InputDecoration(labelText: 'Category'),
                items: TaskTag.values
                    .map((value) => DropdownMenuItem<TaskTag>(
                          value: value,
                          child: Text(value.displayName),
                        ))
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setSheetState(() => tag = value);
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final value = await showDatePicker(
                          context: sheetContext,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: startDate,
                        );
                        if (value != null) {
                          setSheetState(() {
                            startDate = value;
                            if (dueDate.isBefore(value)) dueDate = value;
                          });
                        }
                      },
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(DateFormat('MMM d').format(startDate)),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () async {
                        final value = await showDatePicker(
                          context: sheetContext,
                          firstDate: startDate,
                          lastDate: DateTime(2100),
                          initialDate:
                              dueDate.isBefore(startDate) ? startDate : dueDate,
                        );
                        if (value != null) {
                          setSheetState(() => dueDate = value);
                        }
                      },
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(DateFormat('MMM d').format(dueDate)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: AbundanceButton(
                  label: existing == null ? 'Create mission' : 'Save mission',
                  onPressed: () {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    Navigator.pop(
                      sheetContext,
                      _MissionDraft(
                        title: title,
                        description: descriptionController.text.trim(),
                        tag: tag,
                        startDate: startDate,
                        dueDate: dueDate,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // The modal Future resolves when pop begins; keep field controllers alive
    // until the reverse transition has detached its editable widgets.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    titleController.dispose();
    descriptionController.dispose();
    if (draft == null || !mounted) return;
    final task = Task(
      id: existing?.id ?? '',
      title: draft.title,
      description: draft.description,
      goalType: GoalType.everyday,
      startDate: draft.startDate,
      dueDate: draft.dueDate,
      tag: draft.tag,
      isCompleted: existing?.isCompleted ?? false,
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
      completedAt: existing?.completedAt,
      completionDates: existing?.completionDates,
      subTasks: existing?.subTasks,
    );
    try {
      if (existing == null) {
        await _gateway.create(task);
        if (mounted) setState(() => _tasks = [..._tasks, task]);
      } else {
        await _gateway.update(task);
        if (!mounted) return;
        final index = _tasks.indexOf(existing);
        if (index >= 0) setState(() => _tasks[index] = task);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existing == null
              ? 'We could not create that mission.'
              : 'We could not save that mission.'),
        ),
      );
    }
  }

  Future<void> _deleteMission(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete mission?'),
        content: Text('Remove "${task.title}" and its completion history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final previous = _tasks;
    setState(() => _tasks = _tasks.where((item) => item != task).toList());
    try {
      await _gateway.delete(task.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _tasks = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not delete that mission.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (index) => _selected.add(Duration(days: index - 3)),
    );
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      body: Column(
        children: [
          SizedBox(
            height: 82,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final day = days[index];
                final selected = DateUtils.isSameDay(day, _selected);
                return ChoiceChip(
                  selected: selected,
                  selectedColor: AbundanceColors.primaryGold,
                  backgroundColor: AbundanceColors.surfaceRaised,
                  label: Text(DateFormat('EEE\nd').format(day),
                      textAlign: TextAlign.center),
                  onSelected: (_) => setState(() => _selected = day),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EVERYDAY MISSIONS',
                          style: AbundanceTypography.eyebrow),
                      Text('Forge today.', style: AbundanceTypography.display),
                    ],
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Create mission',
                  onPressed: _openEditor,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const AbundanceStatusView.loading();
    if (_error != null) {
      return AbundanceStatusView.error(message: _error!, onRetry: _load);
    }
    if (_visible.isEmpty) {
      return AbundanceStatusView.empty(
        message: 'No missions are scheduled for this day.',
        actionLabel: 'Create mission',
        onAction: _openEditor,
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: _visible.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final task = _visible[index];
          final enabled = taskCalendarDayIsEnabled(
            task,
            _selected,
            today: widget.today,
          );
          return AbundanceCard(
            child: Row(
              children: [
                Semantics(
                  label: 'Complete ${task.title}',
                  checked: _completed(task),
                  onTap:
                      enabled ? () => _toggle(task, !_completed(task)) : null,
                  child: ExcludeSemantics(
                    child: Checkbox(
                      value: _completed(task),
                      activeColor: AbundanceColors.primaryGold,
                      onChanged: enabled
                          ? (value) => _toggle(task, value ?? false)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title, style: AbundanceTypography.title),
                      if (task.description.trim().isNotEmpty)
                        Text(task.description,
                            style: AbundanceTypography.body.copyWith(
                                color: AbundanceColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                const Text('+10 XP', style: AbundanceTypography.eyebrow),
                PopupMenuButton<String>(
                  iconColor: AbundanceColors.muted,
                  onSelected: (value) {
                    if (value == 'edit') _openEditor(task);
                    if (value == 'delete') _deleteMission(task);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MissionDraft {
  const _MissionDraft({
    required this.title,
    required this.description,
    required this.tag,
    required this.startDate,
    required this.dueDate,
  });

  final String title;
  final String description;
  final TaskTag tag;
  final DateTime startDate;
  final DateTime dueDate;
}
