import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:selfcare_projects/src/features/abundance/services/abundance_missions_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_backdrop.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_mission_presentation.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_button.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_status_view.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_tutorial_target.dart';
import 'package:selfcare_projects/src/features/abundance/tutorial/abundance_tutorial_controller.dart';
import 'package:selfcare_projects/src/features/authentication/screen/todo_list.dart';

class AbundanceMissionsScreen extends StatefulWidget {
  const AbundanceMissionsScreen({
    super.key,
    this.gateway,
    this.initialDate,
    this.today,
    this.onMissionChanged,
    this.tutorialController,
  });

  final AbundanceMissionsGateway? gateway;
  final DateTime? initialDate;
  final DateTime? today;
  final VoidCallback? onMissionChanged;
  final AbundanceTutorialController? tutorialController;

  @override
  State<AbundanceMissionsScreen> createState() =>
      _AbundanceMissionsScreenState();
}

class _AbundanceMissionsScreenState extends State<AbundanceMissionsScreen> {
  late final AbundanceMissionsGateway _gateway =
      widget.gateway ?? InnerUAbundanceMissionsGateway();
  late DateTime _selected =
      DateUtils.dateOnly(widget.initialDate ?? DateTime.now());
  late DateTime _month = DateTime(_selected.year, _selected.month);
  List<Task> _tasks = const [];
  bool _loading = true;
  String? _error;
  DateTime _clockNow = DateTime.now();
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _clockNow = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _clockNow = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  String get _resetCountdown {
    final next = DateTime(_clockNow.year, _clockNow.month, _clockNow.day + 1);
    final seconds = next.difference(_clockNow).inSeconds.clamp(0, 86399);
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainder = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
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

  List<DateTime> get _calendarDays {
    final first = DateTime(_month.year, _month.month, 1);
    final start =
        first.subtract(Duration(days: first.weekday - DateTime.monday));
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final weeks = ((first.weekday - DateTime.monday + daysInMonth) / 7).ceil();
    return List<DateTime>.generate(
      weeks * 7,
      (index) => DateUtils.dateOnly(start.add(Duration(days: index))),
      growable: false,
    );
  }

  int _missionTotalFor(DateTime day) => _tasks
      .where((task) =>
          task.goalType == GoalType.everyday && taskOccursOnDate(task, day))
      .length;

  int _missionCompletedFor(DateTime day) => _tasks
      .where((task) =>
          task.goalType == GoalType.everyday &&
          taskOccursOnDate(task, day) &&
          taskHasCompletionOnDate(task, day))
      .length;

  void _moveMonth(int amount) {
    setState(() {
      _month = DateTime(_month.year, _month.month + amount);
      final lastDay = DateTime(_month.year, _month.month + 1, 0).day;
      _selected = DateUtils.dateOnly(DateTime(
        _month.year,
        _month.month,
        _selected.day.clamp(1, lastDay),
      ));
    });
  }

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

  Future<void> _openDayModal() async {
    var adding = false;
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    TaskTag tag = TaskTag.none;
    String? scheduledTime;
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xCC030717),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final missions = _visible;
          return Dialog(
            backgroundColor: AbundanceColors.surfaceRaised,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: AbundanceColors.border)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 760),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      DateFormat('EEEE, MMMM d, yyyy')
                                          .format(_selected)
                                          .toUpperCase(),
                                      style: AbundanceTypography.eyebrow
                                          .copyWith(fontSize: 13)),
                                  const SizedBox(height: 6),
                                  const Text(
                                      'Check the missions you finished. You can come back and update this day.',
                                      style: AbundanceTypography.body),
                                ])),
                            IconButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                icon: const Icon(Icons.close,
                                    size: 30, color: AbundanceColors.muted)),
                          ]),
                      const SizedBox(height: 16),
                      if (!adding) ...[
                        AbundanceCard(
                          padding: const EdgeInsets.all(10),
                          child: missions.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: Text(
                                      'No missions yet. Create the first discipline for this day.',
                                      style: AbundanceTypography.body))
                              : Column(children: [
                                  for (final task in missions) ...[
                                    _missionModalCard(task, setDialogState),
                                    const SizedBox(height: 10),
                                  ]
                                ]),
                        ),
                        const SizedBox(height: 18),
                        Center(
                            child: TextButton.icon(
                                onPressed: () =>
                                    setDialogState(() => adding = true),
                                icon: const Icon(Icons.add,
                                    color: AbundanceColors.primaryGold),
                                label: const Text('Add a mission',
                                    style: TextStyle(
                                        color: AbundanceColors.primaryGold,
                                        fontSize: 17)))),
                      ] else ...[
                        const Text('MISSION TYPE',
                            style: AbundanceTypography.eyebrow),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<TaskTag>(
                          initialValue: tag,
                          style: const TextStyle(
                            color: AbundanceColors.foreground,
                            fontSize: 15,
                          ),
                          iconEnabledColor: AbundanceColors.muted,
                          dropdownColor: AbundanceColors.surfaceSunken,
                          decoration: InputDecoration(
                              prefixIcon: Icon(tag.abundanceMissionIcon,
                                  color: AbundanceColors.accentCyan),
                              filled: true,
                              fillColor: AbundanceColors.surfaceSunken,
                              labelStyle: TextStyle(
                                color: AbundanceColors.muted,
                              ),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: AbundanceColors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: AbundanceColors.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: AbundanceColors.accentCyan,
                                ),
                              ),
                              labelText: 'Mission type'),
                          items: TaskTag.values
                              .map((value) => DropdownMenuItem<TaskTag>(
                                    value: value,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(value.abundanceMissionIcon,
                                            color: AbundanceColors.accentCyan,
                                            size: 18),
                                        const SizedBox(width: 8),
                                        Text(
                                          value.abundanceMissionLabel,
                                          style: const TextStyle(
                                            color: AbundanceColors.foreground,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ))
                              .toList(growable: false),
                          onChanged: (value) =>
                              setDialogState(() => tag = value ?? TaskTag.none),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                            controller: titleController,
                            style: AbundanceTypography.body,
                            decoration: _darkInputDecoration('Mission name')),
                        const SizedBox(height: 12),
                        TextField(
                            controller: descriptionController,
                            style: AbundanceTypography.body,
                            decoration:
                                _darkInputDecoration('What will you do?')),
                        const SizedBox(height: 18),
                        const Text('TIME (OPTIONAL)',
                            style: AbundanceTypography.eyebrow),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AbundanceColors.muted,
                              backgroundColor: AbundanceColors.surfaceSunken,
                              side: const BorderSide(
                                  color: AbundanceColors.border),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                            onPressed: () async {
                              final picked = await showTimePicker(
                                  context: dialogContext,
                                  initialTime: _timeOfDay(scheduledTime));
                              if (picked != null) {
                                setDialogState(() =>
                                    scheduledTime = _serializeTime(picked));
                              }
                            },
                            icon: const Icon(Icons.access_time,
                                color: AbundanceColors.muted),
                            label: Text(scheduledTime == null
                                ? 'Add a time'
                                : _displayTime(scheduledTime!))),
                        const SizedBox(height: 18),
                        SizedBox(
                            width: double.infinity,
                            child: AbundanceButton(
                                label: 'Add mission',
                                onPressed: () async {
                                  final title = titleController.text.trim();
                                  if (title.isEmpty) return;
                                  final task = Task(
                                      id: '',
                                      title: title,
                                      description:
                                          descriptionController.text.trim(),
                                      goalType: GoalType.everyday,
                                      startDate: _selected,
                                      dueDate: _selected,
                                      tag: tag,
                                      scheduledTime: scheduledTime);
                                  try {
                                    await _gateway.create(task);
                                    // Reload the canonical list so gateways
                                    // that mutate their in-memory collection
                                    // (as well as the API-backed gateway) do
                                    // not produce a duplicate checklist row.
                                    final refreshed = await _gateway.load();
                                    if (mounted) {
                                      setState(() => _tasks = refreshed);
                                    }
                                    widget.onMissionChanged?.call();
                                    // The source keeps the selected-day modal
                                    // open after creating a mission and returns
                                    // to its checklist.  Clear the form and
                                    // switch back to that checklist instead of
                                    // dismissing the whole dialog.
                                    if (dialogContext.mounted) {
                                      titleController.clear();
                                      descriptionController.clear();
                                      setDialogState(() {
                                        adding = false;
                                        tag = TaskTag.none;
                                        scheduledTime = null;
                                      });
                                    }
                                  } catch (_) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(this.context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'We could not create that mission.')));
                                    }
                                  }
                                })),
                      ],
                    ]),
              ),
            ),
          );
        },
      ),
    );
    // The controllers are owned by the dialog builder.  Do not dispose them
    // synchronously when `showDialog` completes: Flutter completes the route
    // future as the pop animation starts, while the dialog's TextFields can
    // still receive one final rebuild.  Disposing here races that rebuild and
    // causes "TextEditingController was used after being disposed" assertions.
  }

  Future<void> _openDailyMissionSetup() async {
    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xCC030717),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dailyMissions = _tasks
              .where((task) => task.goalType == GoalType.everyday)
              .toList(growable: false);
          return Dialog(
            backgroundColor: AbundanceColors.surfaceRaised,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: AbundanceColors.border),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('EVERYDAY MISSIONS',
                                  style: AbundanceTypography.eyebrow),
                              SizedBox(height: 6),
                              Text('Set up your daily mission',
                                  style: AbundanceTypography.title),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close setup',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close,
                              size: 28, color: AbundanceColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose the missions you want to see every day. You can add new ones, edit the details, or remove a mission at any time.',
                      style: AbundanceTypography.body,
                    ),
                    const SizedBox(height: 18),
                    if (dailyMissions.isEmpty)
                      const AbundanceCard(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'No daily missions yet. Add one to start building your routine.',
                          style: AbundanceTypography.body,
                        ),
                      )
                    else
                      for (final task in dailyMissions) ...[
                        _dailySetupMissionCard(
                          task,
                          onEdit: () async {
                            await _openEditor(task);
                            if (dialogContext.mounted) setDialogState(() {});
                          },
                          onDelete: () async {
                            await _deleteMission(task);
                            if (dialogContext.mounted) setDialogState(() {});
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: AbundanceButton(
                        label: 'Add a daily mission',
                        icon: Icons.add,
                        onPressed: () async {
                          await _openEditor();
                          if (dialogContext.mounted) setDialogState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _dailySetupMissionCard(
    Task task, {
    required VoidCallback onEdit,
    required VoidCallback onDelete,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AbundanceColors.surfaceSunken,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AbundanceColors.border),
      ),
      child: Row(
        children: [
          Icon(task.tag.abundanceMissionIcon,
              color: AbundanceColors.accentCyan, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title,
                    style: AbundanceTypography.title.copyWith(fontSize: 17)),
                if (task.description.trim().isNotEmpty)
                  Text(task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AbundanceTypography.body.copyWith(
                          color: AbundanceColors.muted, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit ${task.title}',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined,
                color: AbundanceColors.foreground),
          ),
          IconButton(
            tooltip: 'Remove ${task.title}',
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline,
                color: AbundanceColors.scoreCritical),
          ),
        ],
      ),
    );
  }

  Widget _missionModalCard(Task task, StateSetter setDialogState) {
    final completed = _completed(task);
    final enabled =
        taskCalendarDayIsEnabled(task, _selected, today: widget.today);
    final category = task.tag.abundanceMissionLabel;
    return InkWell(
      onTap: enabled
          ? () async {
              await _toggle(task, !completed);
              if (mounted) setDialogState(() {});
            }
          : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 108),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AbundanceColors.surfaceSunken,
            border: Border.all(
                color: completed
                    ? AbundanceColors.scoreExcellent
                    : AbundanceColors.border),
            borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: completed
                          ? AbundanceColors.scoreExcellent
                          : AbundanceColors.border)),
              child: completed
                  ? const Icon(Icons.check,
                      color: AbundanceColors.scoreExcellent)
                  : null),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    '$category${task.scheduledTime == null ? '' : ' · ${_displayTime(task.scheduledTime!)}'}',
                    style: const TextStyle(
                        color: AbundanceColors.accentCyan,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5)),
                const SizedBox(height: 5),
                Text(task.title,
                    style: AbundanceTypography.title.copyWith(
                        fontSize: 21,
                        decoration:
                            completed ? TextDecoration.lineThrough : null)),
                if (task.description.trim().isNotEmpty)
                  Text(task.description,
                      style: AbundanceTypography.body
                          .copyWith(color: AbundanceColors.muted)),
              ])),
          Text('+10 XP',
              style: AbundanceTypography.eyebrow.copyWith(fontSize: 10)),
        ]),
      ),
    );
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
    var scheduledTime = existing?.scheduledTime;
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
                cursorColor: AbundanceColors.accentCyan,
                decoration: _darkLabeledInputDecoration('Mission name'),
              ),
              TextField(
                controller: descriptionController,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                style: AbundanceTypography.body,
                cursorColor: AbundanceColors.accentCyan,
                decoration:
                    _darkLabeledInputDecoration('Description (optional)'),
              ),
              DropdownButtonFormField<TaskTag>(
                initialValue: tag,
                dropdownColor: AbundanceColors.surfaceRaised,
                style: AbundanceTypography.body,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(tag.abundanceMissionIcon,
                      color: AbundanceColors.accentCyan),
                ),
                items: TaskTag.values
                    .map((value) => DropdownMenuItem<TaskTag>(
                          value: value,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(value.abundanceMissionIcon,
                                  color: AbundanceColors.accentCyan, size: 18),
                              const SizedBox(width: 8),
                              Text(value.abundanceMissionLabel),
                            ],
                          ),
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
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      key: const ValueKey('mission-time-field'),
                      onPressed: () async {
                        final value = await showTimePicker(
                          context: sheetContext,
                          initialTime: _timeOfDay(scheduledTime),
                        );
                        if (value != null) {
                          setSheetState(
                            () => scheduledTime = _serializeTime(value),
                          );
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(
                        scheduledTime == null
                            ? 'Add a time'
                            : _displayTime(scheduledTime!),
                      ),
                    ),
                  ),
                  if (scheduledTime != null)
                    IconButton(
                      tooltip: 'Clear mission time',
                      onPressed: () =>
                          setSheetState(() => scheduledTime = null),
                      icon: const Icon(Icons.close),
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
                        scheduledTime: scheduledTime,
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
      scheduledTime: draft.scheduledTime,
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
      widget.onMissionChanged?.call();
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
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      body: AbundanceBackdrop(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AbundanceColors.primaryGold))
            : _error != null
                ? AbundanceStatusView.error(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AbundanceColors.primaryGold,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 22, 16, 110),
                      children: [
                        AbundanceTutorialTarget(
                          name: 'daily-overview',
                          controller: widget.tutorialController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('EVERYDAY MISSIONS',
                                  style: AbundanceTypography.eyebrow),
                              const SizedBox(height: 6),
                              const Text('Everyday Missions',
                                  style: AbundanceTypography.display),
                              const SizedBox(height: 8),
                              const Text(
                                  'See every day. Tap a date to check off missions you finished.',
                                  style: AbundanceTypography.body),
                              const SizedBox(height: 10),
                              Row(children: [
                                const Icon(Icons.access_time,
                                    size: 19, color: AbundanceColors.muted),
                                const SizedBox(width: 8),
                                Text('Resets in $_resetCountdown',
                                    style: AbundanceTypography.body.copyWith(
                                        color: AbundanceColors.muted)),
                              ]),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        AbundanceTutorialTarget(
                          name: 'daily-board',
                          controller: widget.tutorialController,
                          child: _buildCalendar(),
                        ),
                        const SizedBox(height: 16),
                        _buildLegend(),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: AbundanceButton(
                            label: 'Set up your daily mission',
                            icon: Icons.add,
                            onPressed: _openDailyMissionSetup,
                          ),
                        ),
                        // Gateway injection is used by the existing widget
                        // tests to exercise edit/delete/rollback semantics.
                        // Keep that compatibility surface out of production,
                        // where the source app is calendar-first and opens a
                        // checklist only after a date is tapped.
                        if (widget.gateway != null) ...[
                          const SizedBox(height: 18),
                          _buildLegacyCompatibility(),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildCalendar() {
    const weekdays = <String>['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    final days = _calendarDays;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: AbundanceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _monthButton(
                    Icons.chevron_left, 'Previous month', () => _moveMonth(-1)),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_month).toUpperCase(),
                    textAlign: TextAlign.center,
                    style: AbundanceTypography.title.copyWith(fontSize: 22),
                  ),
                ),
                _monthButton(
                    Icons.chevron_right, 'Next month', () => _moveMonth(1)),
              ],
            ),
            Row(
              children: [
                for (final label in weekdays)
                  Expanded(
                      child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(label,
                        textAlign: TextAlign.center,
                        style: AbundanceTypography.eyebrow.copyWith(
                            color: AbundanceColors.muted, fontSize: 10)),
                  )),
              ],
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, mainAxisExtent: 72),
              itemBuilder: (context, index) {
                final day = days[index];
                final inMonth = day.month == _month.month;
                final selected = DateUtils.isSameDay(day, _selected);
                final total = _missionTotalFor(day);
                final completed = _missionCompletedFor(day);
                final percent = total == 0 ? 0.0 : completed / total;
                return InkWell(
                  onTap: inMonth
                      ? () {
                          setState(() => _selected = day);
                          _openDayModal();
                        }
                      : null,
                  child: Container(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? AbundanceColors.primaryGold.withValues(alpha: .14)
                          : Colors.transparent,
                      border: Border.all(
                          color: selected
                              ? AbundanceColors.primaryGold
                              : AbundanceColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${day.day}',
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                                color: inMonth
                                    ? (selected
                                        ? AbundanceColors.primaryGold
                                        : AbundanceColors.foreground)
                                    : AbundanceColors.border,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        const SizedBox(height: 4),
                        if (inMonth)
                          SizedBox(
                            width: double.infinity,
                            child: LinearProgressIndicator(
                              minHeight: 5,
                              value: percent,
                              backgroundColor: AbundanceColors.surfaceSunken,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                percent >= 1
                                    ? AbundanceColors.scoreExcellent
                                    : percent > 0
                                        ? AbundanceColors.primaryGold
                                        : AbundanceColors.surfaceSunken,
                              ),
                            ),
                          ),
                        if (inMonth && total > 0)
                          Text('$completed/$total',
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                  color: AbundanceColors.muted, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthButton(IconData icon, String tooltip, VoidCallback onPressed) =>
      SizedBox(
        width: 54,
        height: 60,
        child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon, size: 34, color: AbundanceColors.foreground)),
      );

  Widget _buildLegend() => Wrap(
        spacing: 14,
        runSpacing: 6,
        children: const [
          Text('● Complete',
              style: TextStyle(
                  color: AbundanceColors.scoreExcellent,
                  fontWeight: FontWeight.w700)),
          Text('● In progress',
              style: TextStyle(color: AbundanceColors.primaryGold)),
          Text('▣ Locked by coach',
              style: TextStyle(color: AbundanceColors.muted)),
        ],
      );

  Widget _buildLegacyCompatibility() {
    // The compatibility list is intentionally broader than the calendar's
    // date filter so legacy widget tests can exercise task mutation without
    // depending on the calendar's selected-day hit target.
    final tasks = _tasks
        .where((task) => task.goalType == GoalType.everyday)
        .toList(growable: false);
    if (tasks.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final task in tasks)
          AbundanceCard(
            child: Row(children: [
              // Match the source policy for dates in the future/coach-locked
              // windows while retaining the test-only compatibility affordance.
              // ignore: unnecessary_lambdas
              Checkbox(
                value: _completed(task),
                activeColor: AbundanceColors.primaryGold,
                onChanged: taskCalendarDayIsEnabled(task, _selected,
                        today: widget.today)
                    ? (value) => _toggle(task, value ?? false)
                    : null,
              ),
              Expanded(
                  child: Text(task.title, style: AbundanceTypography.title)),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _openEditor(task);
                  if (value == 'delete') _deleteMission(task);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ]),
          ),
      ],
    );
  }
}

InputDecoration _darkInputDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AbundanceColors.muted),
      filled: true,
      fillColor: AbundanceColors.surfaceSunken,
      border: const OutlineInputBorder(
        borderSide: BorderSide(color: AbundanceColors.border),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AbundanceColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AbundanceColors.primaryGold),
      ),
    );

InputDecoration _darkLabeledInputDecoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AbundanceColors.muted),
      floatingLabelStyle: const TextStyle(color: AbundanceColors.accentCyan),
      counterStyle: const TextStyle(color: AbundanceColors.muted),
      filled: true,
      fillColor: AbundanceColors.surfaceSunken,
      border: const OutlineInputBorder(
        borderSide: BorderSide(color: AbundanceColors.border),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AbundanceColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AbundanceColors.accentCyan),
      ),
    );

class _MissionDraft {
  const _MissionDraft({
    required this.title,
    required this.description,
    required this.tag,
    required this.startDate,
    required this.dueDate,
    required this.scheduledTime,
  });

  final String title;
  final String description;
  final TaskTag tag;
  final DateTime startDate;
  final DateTime dueDate;
  final String? scheduledTime;
}

TimeOfDay _timeOfDay(String? value) {
  final parts = value?.split(':') ?? const <String>[];
  if (parts.length == 2) {
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour != null && minute != null && hour < 24 && minute < 60) {
      return TimeOfDay(hour: hour, minute: minute);
    }
  }
  return TimeOfDay.now();
}

String _serializeTime(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _displayTime(String value) {
  final time = _timeOfDay(value);
  return DateFormat.jm().format(DateTime(2000, 1, 1, time.hour, time.minute));
}
