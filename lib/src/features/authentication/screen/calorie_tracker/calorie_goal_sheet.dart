import 'package:flutter/material.dart';
import 'package:selfcare_projects/src/features/authentication/screen/calorie_tracker/calorie_tracker_math.dart';

/// Opens the goal calculator. Fields are prefilled from the saved profile
/// (or the user's age from their birthdate) and the goal updates live, so
/// one tap saves both the profile and the goal.
Future<CalorieProfile?> showCalorieGoalSheet(
  BuildContext context, {
  CalorieProfile? initialProfile,
  int? ageFromBirthdate,
}) {
  return showModalBottomSheet<CalorieProfile>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => CalorieGoalSheet(
      initialProfile: initialProfile,
      ageFromBirthdate: ageFromBirthdate,
    ),
  );
}

class CalorieGoalSheet extends StatefulWidget {
  const CalorieGoalSheet({
    super.key,
    this.initialProfile,
    this.ageFromBirthdate,
  });

  final CalorieProfile? initialProfile;
  final int? ageFromBirthdate;

  @override
  State<CalorieGoalSheet> createState() => _CalorieGoalSheetState();
}

class _CalorieGoalSheetState extends State<CalorieGoalSheet> {
  late bool _isMale;
  late ActivityLevel _activity;
  late CalorieGoalType _goalType;
  late bool _countSteps;
  late final TextEditingController _age;
  late final TextEditingController _height;
  late final TextEditingController _weight;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _isMale = profile?.isMale ?? true;
    _activity = profile?.activityLevel ?? ActivityLevel.sedentary;
    _goalType = profile?.goalType ?? CalorieGoalType.maintain;
    _countSteps = profile?.countSteps ?? true;
    _age = TextEditingController(
      text: '${profile?.age ?? widget.ageFromBirthdate ?? ''}',
    );
    _height = TextEditingController(text: _format(profile?.heightCm));
    _weight = TextEditingController(text: _format(profile?.weightKg));
  }

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  static String _format(double? value) {
    if (value == null) return '';
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  CalorieProfile? get _profile {
    final age = int.tryParse(_age.text.trim());
    final height = double.tryParse(_height.text.trim().replaceAll(',', '.'));
    final weight = double.tryParse(_weight.text.trim().replaceAll(',', '.'));
    if (age == null || height == null || weight == null) return null;
    return CalorieProfile(
      isMale: _isMale,
      age: age,
      heightCm: height,
      weightKg: weight,
      activityLevel: _activity,
      goalType: _goalType,
      countSteps: _countSteps,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final profile = _profile;
    final error = profile?.validate();
    final isValid = profile != null && error == null;

    Widget numberField(
      TextEditingController controller,
      String label,
      String suffix,
    ) {
      return Expanded(
        child: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            border: const OutlineInputBorder(),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your calorie goal',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Saved once, used every day.',
              style: TextStyle(color: colors.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Male')),
                ButtonSegment(value: false, label: Text('Female')),
              ],
              selected: {_isMale},
              onSelectionChanged: (value) =>
                  setState(() => _isMale = value.first),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                numberField(_age, 'Age', 'yrs'),
                const SizedBox(width: 10),
                numberField(_height, 'Height', 'cm'),
                const SizedBox(width: 10),
                numberField(_weight, 'Weight', 'kg'),
              ],
            ),
            const SizedBox(height: 16),
            Text('Goal', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: CalorieGoalType.values.map((type) {
                return ChoiceChip(
                  label: Text(type.label),
                  selected: type == _goalType,
                  onSelected: (_) => setState(() => _goalType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _countSteps,
              onChanged: (value) => setState(() => _countSteps = value),
              title: const Text('Add my steps to my budget'),
              subtitle: Text(
                _countSteps
                    ? 'Your goal starts from a resting baseline and grows with every step you walk.'
                    : 'Pick how active you usually are instead.',
              ),
            ),
            if (!_countSteps) ...[
              const SizedBox(height: 4),
              DropdownButtonFormField<ActivityLevel>(
                initialValue: _activity,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Activity level',
                  border: OutlineInputBorder(),
                ),
                items: ActivityLevel.values
                    .map((level) => DropdownMenuItem(
                          value: level,
                          child: Text('${level.label} · ${level.description}'),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _activity = value);
                },
              ),
            ],
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: !isValid
                  ? Text(
                      error ?? 'Enter your age, height and weight.',
                      style: TextStyle(
                        color: profile == null
                            ? colors.onSurface.withValues(alpha: 0.7)
                            : colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${profile.dailyGoal} kcal / day',
                          key: const ValueKey('calorie-goal-result'),
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Maintenance ${profile.maintenanceCalories.round()} kcal'
                          '${profile.goalType.dailyAdjustment == 0 ? '' : ' ${profile.goalType.dailyAdjustment > 0 ? '+' : '−'} ${profile.goalType.dailyAdjustment.abs()} kcal'}'
                          '${profile.countSteps ? ' · plus your steps each day' : ''}',
                          style: TextStyle(
                            color: colors.onSurface.withValues(alpha: 0.75),
                          ),
                        ),
                        if (profile.goalWasRaisedToMinimum) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Raised to ${profile.minimumGoal} kcal, the safe minimum without medical supervision.',
                            style: TextStyle(
                              color: colors.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    isValid ? () => Navigator.pop(context, profile) : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  isValid
                      ? 'Use ${profile.dailyGoal} kcal as my goal'
                      : 'Use this goal',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
