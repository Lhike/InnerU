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
  const AbundanceMissionsScreen({super.key, this.gateway, this.initialDate});

  final AbundanceMissionsGateway? gateway;
  final DateTime? initialDate;

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
      .where((task) => taskOccursOnDate(task, _selected))
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

  Future<void> _createMission() async {
    final controller = TextEditingController();
    final title = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AbundanceColors.surfaceRaised,
      builder: (sheetContext) => Padding(
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
            const Text('CREATE MISSION', style: AbundanceTypography.title),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              style: AbundanceTypography.body,
              decoration: const InputDecoration(
                labelText: 'What will you do?',
                labelStyle: TextStyle(color: AbundanceColors.muted),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AbundanceButton(
                label: 'Create mission',
                onPressed: () {
                  final value = controller.text.trim();
                  if (value.isNotEmpty) Navigator.pop(sheetContext, value);
                },
              ),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (title == null || !mounted) return;
    final task = Task(
      id: '',
      title: title,
      goalType: GoalType.everyday,
      startDate: _selected,
      dueDate: _selected.add(const Duration(days: 29)),
    );
    try {
      await _gateway.create(task);
      if (mounted) setState(() => _tasks = [..._tasks, task]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('We could not create that mission.')),
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
                  onPressed: _createMission,
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
        onAction: _createMission,
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
          return AbundanceCard(
            child: Row(
              children: [
                Semantics(
                  label: 'Complete ${task.title}',
                  checked: _completed(task),
                  onTap: () => _toggle(task, !_completed(task)),
                  child: ExcludeSemantics(
                    child: Checkbox(
                      value: _completed(task),
                      activeColor: AbundanceColors.primaryGold,
                      onChanged: (value) => _toggle(task, value ?? false),
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
              ],
            ),
          );
        },
      ),
    );
  }
}
