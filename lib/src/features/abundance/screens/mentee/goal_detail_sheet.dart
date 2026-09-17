import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:selfcare_projects/src/features/abundance/domain/domain.dart';
import 'package:selfcare_projects/src/features/abundance/screens/mentee/goal_detail_screen.dart';
import 'package:selfcare_projects/src/features/abundance/services/goals_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';

/// Opens the compact goal preview used by Home. The full detail page remains
/// available through the sheet's explicit "View goal page" action.
Future<void> showGoalDetailSheet(
  BuildContext context, {
  required GoalSummary goal,
  required GoalsService service,
  required String uid,
}) {
  final navigator = Navigator.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .62),
    builder: (_) => GoalDetailSheet(
      initialGoal: goal,
      service: service,
      uid: uid,
      onViewGoalPage: () => navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => GoalDetailScreen(
            goalId: goal.id,
            service: service,
            uid: uid,
          ),
        ),
      ),
    ),
  );
}

class GoalDetailSheet extends StatefulWidget {
  const GoalDetailSheet({
    super.key,
    required this.initialGoal,
    required this.service,
    required this.uid,
    required this.onViewGoalPage,
  });

  final GoalSummary initialGoal;
  final GoalsService service;
  final String uid;
  final Future<void> Function() onViewGoalPage;

  @override
  State<GoalDetailSheet> createState() => _GoalDetailSheetState();
}

class _GoalDetailSheetState extends State<GoalDetailSheet> {
  final _logController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _logController.dispose();
    super.dispose();
  }

  String _number(double value) {
    if (value.truncateToDouble() == value) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  double _todayTarget(GoalSummary goal) {
    if (goal.dailyTarget != null) return goal.dailyTarget!;
    if (goal.goalType != GoalType.merit || goal.targetValue <= 0) {
      return goal.targetValue;
    }
    final periodDays = math.max(1, goal.targetPeriod.days);
    return goal.periodTarget / periodDays;
  }

  double _weekTarget(GoalSummary goal) {
    if (goal.weeklyTarget != null) return goal.weeklyTarget!;
    if (goal.goalType != GoalType.merit || goal.targetValue <= 0) {
      return goal.targetValue;
    }
    final periodDays = math.max(1, goal.targetPeriod.days);
    return goal.periodTarget * 7 / periodDays;
  }

  double _remaining(GoalSummary goal) {
    if (goal.direction == GoalDirection.lose) {
      return math.max(0, goal.currentValue - goal.targetValue);
    }
    return math.max(0, goal.targetValue - goal.currentValue);
  }

  String _unit(GoalSummary goal) =>
      goal.unit.trim().isEmpty ? '' : ' ${goal.unit.trim().toUpperCase()}';

  Future<void> _editCurrentValue(GoalSummary goal) async {
    final controller = TextEditingController(text: _number(goal.currentValue));
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AbundanceColors.surfaceRaised,
        title: const Text('Change current value'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Current value${_unit(goal)}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext)
                .pop(double.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _saveCurrentValue(goal, value);
  }

  Future<void> _logToday(GoalSummary goal) async {
    final amount = double.tryParse(_logController.text.trim());
    if (amount == null || amount <= 0) return;
    final nextValue = goal.direction == GoalDirection.lose
        ? math.max(0, goal.currentValue - amount)
        : goal.currentValue + amount;
    await _saveCurrentValue(goal, nextValue.toDouble());
    if (mounted) _logController.clear();
  }

  Future<void> _saveCurrentValue(GoalSummary goal, double value) async {
    if (goal.goalType != GoalType.merit || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.service.setGoalMeasure(
        goalId: goal.id,
        actorId: widget.uid,
        currentValue: value,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save progress')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        // Keep the preview sheet compact like the source A12 goal modal. The
        // body remains scrollable when the content is taller than the viewport.
        constraints: BoxConstraints(maxHeight: media.height * .82),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AbundanceColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: AbundanceColors.border)),
          ),
          child: StreamBuilder<GoalSummary?>(
            stream: widget.service.watchGoal(widget.initialGoal.id),
            builder: (context, snapshot) {
              final goal = snapshot.data ?? widget.initialGoal;
              return SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SheetHeader(onClose: () => Navigator.of(context).pop()),
                      const SizedBox(height: 24),
                      Text(
                        goal.title.toUpperCase(),
                        style: AbundanceTypography.display.copyWith(
                          fontSize: 21,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${goal.category.label} · ${goal.status.label.toUpperCase()}',
                        style: AbundanceTypography.body.copyWith(
                          color:
                              AbundanceColors.categoryColor(goal.category.code),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${goal.title} on or before ${DateFormat('MMMM d, yyyy').format(goal.targetDate)}.',
                        style: AbundanceTypography.body.copyWith(
                          color: AbundanceColors.muted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _TargetCard(
                              label: 'Your goal for today',
                              value: _todayTarget(goal),
                              unit: _unit(goal),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TargetCard(
                              label: 'Your goal for this week',
                              value: _weekTarget(goal),
                              unit: _unit(goal),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text('Where you are now',
                          style: AbundanceTypography.body.copyWith(
                            fontSize: 14,
                          )),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              '${_number(_remaining(goal))} of ${_number(goal.targetValue)}${_unit(goal)} to ${goal.direction == GoalDirection.lose ? 'lose' : 'gain'}',
                              style: AbundanceTypography.body
                                  .copyWith(fontSize: 14),
                            ),
                          ),
                          Text('${goal.progress}%',
                              style: AbundanceTypography.body
                                  .copyWith(fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: (goal.progress / 100).clamp(0.0, 1.0),
                          backgroundColor: Colors.black54,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            goal.status == GoalStatus.completed
                                ? AbundanceColors.scoreExcellent
                                : AbundanceColors.primaryGold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: goal.goalType == GoalType.merit
                            ? () => _editCurrentValue(goal)
                            : null,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'You are at ${_number(goal.currentValue)}${_unit(goal)} — tap to change',
                            style: AbundanceTypography.body.copyWith(
                              color: AbundanceColors.primaryGold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (goal.goalType == GoalType.merit)
                        _LogTodayCard(
                          controller: _logController,
                          unit: _unit(goal),
                          saving: _saving,
                          onLog: () => _logToday(goal),
                        ),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await widget.onViewGoalPage();
                          },
                          icon: const Icon(Icons.north_east_rounded, size: 18),
                          label: const Text('View goal page'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AbundanceColors.primaryGold,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: 92,
            height: 6,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: AbundanceColors.muted,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
              color: AbundanceColors.foreground,
              tooltip: 'Close',
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard(
      {required this.label, required this.value, required this.unit});

  final String label;
  final double value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final display = value.truncateToDouble() == value
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
    return Container(
      constraints: const BoxConstraints(minHeight: 100, maxHeight: 100),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AbundanceColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AbundanceColors.primaryGold, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AbundanceTypography.body.copyWith(fontSize: 14)),
          const Spacer(),
          Text(
            '$display$unit',
            style: AbundanceTypography.display.copyWith(
              color: AbundanceColors.primaryGold,
              fontSize: 19,
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTodayCard extends StatelessWidget {
  const _LogTodayCard({
    required this.controller,
    required this.unit,
    required this.saving,
    required this.onLog,
  });

  final TextEditingController controller;
  final String unit;
  final bool saving;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AbundanceColors.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AbundanceColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Log for today',
              style: AbundanceTypography.title.copyWith(fontSize: 22)),
          const SizedBox(height: 8),
          Text('Enter what you did today.',
              style: AbundanceTypography.body
                  .copyWith(color: AbundanceColors.muted)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('goal-preview-log-input'),
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(hintText: '0'),
                ),
              ),
              const SizedBox(width: 12),
              Text(unit.trim(), style: AbundanceTypography.body),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: saving ? null : onLog,
              style: FilledButton.styleFrom(
                backgroundColor: AbundanceColors.primaryGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(saving ? 'Saving…' : 'Log today'),
            ),
          ),
        ],
      ),
    );
  }
}
