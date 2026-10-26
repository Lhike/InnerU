import 'package:flutter/material.dart';

/// What the user did with a logged entry.
class CalorieEntryEdit {
  const CalorieEntryEdit.update({
    required this.meal,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  }) : delete = false;

  const CalorieEntryEdit.delete()
      : delete = true,
        meal = '',
        mealType = '',
        calories = 0,
        protein = 0,
        carbs = 0,
        fat = 0;

  final bool delete;
  final String meal;
  final String mealType;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
}

/// Edit or delete a logged meal. Returns null when dismissed.
Future<CalorieEntryEdit?> showCalorieEntryEditSheet(
  BuildContext context, {
  required Map<String, dynamic> entry,
  required List<String> mealTypes,
}) {
  return showModalBottomSheet<CalorieEntryEdit>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        CalorieEntryEditSheet(entry: entry, mealTypes: mealTypes),
  );
}

class CalorieEntryEditSheet extends StatefulWidget {
  const CalorieEntryEditSheet({
    super.key,
    required this.entry,
    required this.mealTypes,
  });

  final Map<String, dynamic> entry;
  final List<String> mealTypes;

  @override
  State<CalorieEntryEditSheet> createState() => _CalorieEntryEditSheetState();
}

class _CalorieEntryEditSheetState extends State<CalorieEntryEditSheet> {
  late final TextEditingController _meal;
  late final TextEditingController _calories;
  late final TextEditingController _protein;
  late final TextEditingController _carbs;
  late final TextEditingController _fat;
  late String _mealType;

  /// Scale every value when the portion changes, e.g. ate half.
  double _portion = 1;

  @override
  void initState() {
    super.initState();
    String read(String key) => '${(widget.entry[key] as num?)?.toInt() ?? 0}';
    _meal = TextEditingController(text: widget.entry['meal']?.toString() ?? '');
    _calories = TextEditingController(text: read('calories'));
    _protein = TextEditingController(text: read('protein'));
    _carbs = TextEditingController(text: read('carbs'));
    _fat = TextEditingController(text: read('fat'));
    final type = widget.entry['mealType']?.toString();
    _mealType =
        widget.mealTypes.contains(type) ? type! : widget.mealTypes.first;
  }

  @override
  void dispose() {
    _meal.dispose();
    _calories.dispose();
    _protein.dispose();
    _carbs.dispose();
    _fat.dispose();
    super.dispose();
  }

  void _setPortion(double portion) {
    final factor = portion / _portion;
    for (final controller in [_calories, _protein, _carbs, _fat]) {
      final value = int.tryParse(controller.text.trim()) ?? 0;
      controller.text = (value * factor).round().toString();
    }
    setState(() => _portion = portion);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text('"${_meal.text.trim()}" will be removed from today.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, const CalorieEntryEdit.delete());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calories = int.tryParse(_calories.text.trim()) ?? 0;
    final canSave = _meal.text.trim().isNotEmpty && calories > 0;

    Widget number(TextEditingController controller, String label, String unit) {
      return Expanded(
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            suffixText: unit,
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Edit entry',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete entry',
                  onPressed: _confirmDelete,
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _meal,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Food name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: widget.mealTypes
                  .map((type) => ChoiceChip(
                        label: Text(type),
                        selected: type == _mealType,
                        onSelected: (_) => setState(() => _mealType = type),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            Text('Portion eaten', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: const [0.5, 1.0, 1.5, 2.0]
                  .map((portion) => ChoiceChip(
                        label: Text(portion == 1 ? 'As logged' : '×$portion'),
                        selected: portion == _portion,
                        onSelected: (_) => _setPortion(portion),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 14),
            Row(children: [
              number(_calories, 'Calories', 'kcal'),
              const SizedBox(width: 10),
              number(_protein, 'Protein', 'g'),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              number(_carbs, 'Carbs', 'g'),
              const SizedBox(width: 10),
              number(_fat, 'Fat', 'g'),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSave
                    ? () => Navigator.pop(
                          context,
                          CalorieEntryEdit.update(
                            meal: _meal.text.trim(),
                            mealType: _mealType,
                            calories: calories,
                            protein: int.tryParse(_protein.text.trim()) ?? 0,
                            carbs: int.tryParse(_carbs.text.trim()) ?? 0,
                            fat: int.tryParse(_fat.text.trim()) ?? 0,
                          ),
                        )
                    : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
