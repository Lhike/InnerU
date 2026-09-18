import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/domain/domain.dart';
import 'package:selfcare_projects/src/features/abundance/services/abundance_onboarding_service.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_assets.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_backdrop.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_button.dart';
import 'package:selfcare_projects/src/features/abundance/widgets/abundance_card.dart';

/// The four-step member setup from the Abundance mobile app.
///
/// This remains inside the company-gated feature. It mirrors the source
/// app's single scrollable form per step while using the A12-backed goal
/// service for persistence.
class AbundanceOnboardingScreen extends StatefulWidget {
  const AbundanceOnboardingScreen({
    super.key,
    required this.uid,
    required this.initialName,
    this.service,
    this.onCompleted,
  });

  final String uid;
  final String initialName;
  final AbundanceOnboardingService? service;
  final VoidCallback? onCompleted;

  @override
  State<AbundanceOnboardingScreen> createState() =>
      _AbundanceOnboardingScreenState();
}

class _AiSuggestionResult {
  const _AiSuggestionResult({
    required this.declaration,
    required this.qualities,
    required this.plans,
  });

  final String declaration;
  final String qualities;
  final List<String> plans;
}

class _AiSuggestionsSheet extends StatefulWidget {
  const _AiSuggestionsSheet({
    required this.options,
    required this.initialGoal,
    required this.initialPlans,
    required this.initialQualities,
  });

  final List<String> options;
  final String initialGoal;
  final String initialPlans;
  final String initialQualities;

  @override
  State<_AiSuggestionsSheet> createState() => _AiSuggestionsSheetState();
}

class _AiSuggestionsSheetState extends State<_AiSuggestionsSheet> {
  late final TextEditingController _what =
      TextEditingController(text: widget.initialGoal);
  late final TextEditingController _how =
      TextEditingController(text: widget.initialPlans);
  late final TextEditingController _qualities =
      TextEditingController(text: widget.initialQualities);
  bool _picking = false;
  String? _error;

  @override
  void dispose() {
    _what.dispose();
    _how.dispose();
    _qualities.dispose();
    super.dispose();
  }

  void _choose(String declaration) {
    final plans = _how.text
        .split(RegExp(r'[,\n]+'))
        .map((plan) => plan.trim())
        .where((plan) => plan.isNotEmpty)
        .toList(growable: false);
    Navigator.of(context).pop(_AiSuggestionResult(
      declaration: declaration,
      qualities: _qualities.text.trim(),
      plans: plans,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: _picking ? _options() : _questions(),
      ),
    );
  }

  Widget _options() => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Choose your declaration', style: AbundanceTypography.title),
          const SizedBox(height: 6),
          Text(
            'Select one of five declarations to fill your quest. You can edit it afterwards.',
            style: AbundanceTypography.body.copyWith(
              color: AbundanceColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          ...widget.options.map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _choose(option),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AbundanceColors.surfaceSunken,
                    border: Border.all(color: AbundanceColors.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(option, style: AbundanceTypography.body),
                ),
              ),
            ),
          ),
        ],
      );

  Widget _questions() => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Create declaration suggestions',
                style: AbundanceTypography.title),
            const SizedBox(height: 6),
            Text(
              'Review the three answers used to create five declarations. You can edit them without changing your quest.',
              style: AbundanceTypography.body
                  .copyWith(color: AbundanceColors.muted),
            ),
            const SizedBox(height: 16),
            _field('What is the goal?', _what, 'Finish 100 km'),
            const SizedBox(height: 12),
            _field(
                'How will you achieve it?', _how, 'Run three times each week'),
            const SizedBox(height: 12),
            _field('What qualities will you embody?', _qualities,
                'Commitment, Discipline, Excellence'),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(_error!,
                  style: const TextStyle(color: AbundanceColors.scoreCritical)),
            ],
            const SizedBox(height: 16),
            AbundanceButton(
              label: '✣ Get 5 AI suggestions',
              onPressed: () {
                if (_what.text.trim().length < 3 ||
                    _how.text.trim().isEmpty ||
                    _qualities.text.trim().isEmpty) {
                  setState(() => _error =
                      'Complete the goal, action plans, and qualities first.');
                  return;
                }
                setState(() => _picking = true);
              },
            ),
          ],
        ),
      );

  Widget _field(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(label,
            style: AbundanceTypography.body
                .copyWith(color: AbundanceColors.muted, fontSize: 15)),
        const SizedBox(height: 7),
        TextField(
          controller: controller,
          maxLines: 2,
          style: AbundanceTypography.body,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                AbundanceTypography.body.copyWith(color: AbundanceColors.muted),
            filled: true,
            fillColor: AbundanceColors.surfaceSunken,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AbundanceColors.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AbundanceColors.border)),
          ),
        ),
      ],
    );
  }
}

class _GoalDraftState {
  String declaration = '';
  GoalDirection direction = GoalDirection.gain;
  String unit = '';
  bool customUnit = false;
  String target = '';
  bool increment = true;
  DateTime? targetDate;
  String qualities = '';
  final List<String> plans = <String>[''];
}

class _AbundanceOnboardingScreenState extends State<AbundanceOnboardingScreen> {
  late final AbundanceOnboardingService _service =
      widget.service ?? AbundanceOnboardingService();
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  final TextEditingController _headline = TextEditingController();
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<GoalCategory, _GoalDraftState> _goals =
      <GoalCategory, _GoalDraftState>{
    for (final category in GoalCategory.values) category: _GoalDraftState(),
  };
  final ScrollController _scroll = ScrollController();
  int _step = 0;
  bool _saving = false;
  String? _error;

  static const List<String> _units = <String>[
    'KG',
    'KM',
    'STEPS',
    'HOURS',
    'PROFIT(PESO)',
    'VIDEOS',
    'PROJECT',
    'MILESTONE',
  ];

  static const Map<GoalCategory, List<String>> _examples =
      <GoalCategory, List<String>>{
    GoalCategory.personal: <String>[
      'I see myself lighter, stronger and sleeping properly.',
      'I see myself moving with energy every day.',
      'I see myself caring for my body with consistency.',
      'I see myself creating a calm and healthy rhythm.',
      'I see myself feeling proud of how I show up for myself.',
    ],
    GoalCategory.professional: <String>[
      'I see myself leading a team of my own.',
      'I see myself delivering excellent work with confidence.',
      'I see myself growing into the role I am ready for.',
      'I see myself creating value for my team every day.',
      'I see myself becoming the professional I respect.',
    ],
    GoalCategory.contribution: <String>[
      'I see myself giving back to the people coming up behind me.',
      'I see myself making a meaningful difference around me.',
      'I see myself sharing what I have learned generously.',
      'I see myself helping others move forward with courage.',
      'I see myself leaving every community stronger than I found it.',
    ],
  };

  @override
  void dispose() {
    _name.dispose();
    _headline.dispose();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  GoalCategory? get _category =>
      _step == 0 ? null : GoalCategory.values[_step - 1];

  _GoalDraftState get _currentGoal => _goals[_category]!;

  bool _isValid() {
    if (_step == 0) return _name.text.trim().isNotEmpty;
    final goal = _currentGoal;
    return AbundanceOnboardingGoalDraft(
      category: _category!,
      declaration: goal.declaration,
      direction: goal.direction,
      unit: goal.unit,
      target: double.tryParse(goal.target.trim()) ?? 0,
      increment: goal.increment,
      plans: goal.plans,
      qualities: goal.qualities,
      targetDate: goal.targetDate,
    ).isValid;
  }

  Future<void> _next() async {
    if (!_isValid()) {
      setState(() => _error = 'Complete the required fields to continue.');
      return;
    }
    setState(() => _error = null);
    if (_step < 3) {
      setState(() => _step++);
      _scroll.jumpTo(0);
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.complete(
        uid: widget.uid,
        name: _name.text,
        headline: _headline.text,
        goals: GoalCategory.values.map((category) {
          final goal = _goals[category]!;
          return AbundanceOnboardingGoalDraft(
            category: category,
            declaration: goal.declaration,
            direction: goal.direction,
            unit: goal.unit,
            target: double.tryParse(goal.target.trim()) ?? 0,
            increment: goal.increment,
            plans: goal.plans,
            qualities: goal.qualities,
            targetDate: goal.targetDate,
          );
        }).toList(growable: false),
      );
      if (!mounted) return;
      widget.onCompleted?.call();
      if (widget.onCompleted == null && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (cause) {
      if (mounted) {
        setState(
            () => _error = cause.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() {
    if (_step == 0 || _saving) return;
    setState(() {
      _step--;
      _error = null;
    });
    _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final category = _category;
    return Scaffold(
      backgroundColor: AbundanceColors.background,
      body: AbundanceBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _header(),
                const SizedBox(height: 14),
                _progress(),
                const SizedBox(height: 18),
                AbundanceCard(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Text(
                        _step == 0 ? 'WELCOME' : 'QUEST $_step OF 3',
                        style: AbundanceTypography.eyebrow.copyWith(
                          color: AbundanceColors.accentCyan,
                          fontSize: 13,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _step == 0
                            ? 'Welcome, ${_name.text.trim().isEmpty ? 'champion' : _name.text.trim()}.'
                            : 'Your ${category!.label.toLowerCase()} quest',
                        style:
                            AbundanceTypography.display.copyWith(fontSize: 30),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _step == 0
                            ? "Let's forge the system that scores whether you actually showed up."
                            : 'Answer in the present tense, then give it a number so it can be scored.',
                        style: AbundanceTypography.body.copyWith(
                          color: AbundanceColors.muted,
                          fontSize: 17,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_step == 0) _welcomeBody() else _questBody(category!),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(_error!,
                            style: const TextStyle(
                                color: AbundanceColors.scoreCritical)),
                      ],
                      const SizedBox(height: 24),
                      _footer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Image.asset(abundanceLogoAsset, width: 58, height: 58),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('ABUNDANCE 12', style: AbundanceTypography.title),
                SizedBox(height: 3),
                Text('THE GAME OF MY LIFE', style: AbundanceTypography.eyebrow),
              ],
            ),
          ),
          Text('Step ${_step + 1} of 4',
              style: AbundanceTypography.body
                  .copyWith(color: AbundanceColors.muted, fontSize: 16)),
        ],
      );

  Widget _progress() => Column(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (_step + 1) / 4,
              minHeight: 5,
              backgroundColor: AbundanceColors.surfaceSunken,
              color: AbundanceColors.primaryGold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(4, (index) {
              final done = index < _step;
              final current = index == _step;
              return Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done
                      ? AbundanceColors.primaryGold
                      : (current
                          ? AbundanceColors.surfaceSunken
                          : AbundanceColors.surfaceRaised),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: done || current
                          ? AbundanceColors.primaryGold
                          : AbundanceColors.border,
                      width: current ? 2 : 1),
                ),
                child: Text(done ? '✓' : '${index + 1}',
                    style: TextStyle(
                        color: done
                            ? AbundanceColors.surfaceSunken
                            : AbundanceColors.muted,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              );
            }),
          ),
        ],
      );

  Widget _welcomeBody() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _fieldLabel('What shall we call you, champion?'),
          _textField(
              controller: _name,
              hint: 'cookie milo',
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 22),
          _fieldLabel('Your Declaration'),
          _textField(controller: _headline, hint: 'e.g. I matter', maxLines: 2),
          const SizedBox(height: 10),
          Text(
              'One line on who you are becoming. It sits under your name wherever your council sees you. Optional, and you can change it any time from your profile.',
              style: AbundanceTypography.body
                  .copyWith(color: AbundanceColors.muted, fontSize: 15)),
          const SizedBox(height: 20),
          _infoBox(),
        ],
      );

  Widget _questBody(GoalCategory category) {
    final goal = _goals[category]!;
    final milestone = goal.unit.trim().toUpperCase() == 'MILESTONE';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _aiBanner(category),
        const SizedBox(height: 24),
        _fieldLabel('What do you joyfully see yourself achieving?',
            required: true),
        _draftField('${category.name}.declaration',
            hint: 'I see myself…',
            maxLines: 4,
            onChanged: (value) => setState(() => goal.declaration = value)),
        const SizedBox(height: 22),
        _fieldLabel('Deadline (optional)'),
        _deadlineField(goal),
        const SizedBox(height: 8),
        Text(
            'Set the last day to complete this quest, or leave blank if it has no deadline.',
            style: AbundanceTypography.body
                .copyWith(color: AbundanceColors.muted, fontSize: 15)),
        if (!milestone) ...<Widget>[
          const SizedBox(height: 24),
          _fieldLabel('Direction', required: true),
          Row(children: <Widget>[
            _directionButton(goal, GoalDirection.gain),
            const SizedBox(width: 12),
            _directionButton(goal, GoalDirection.lose)
          ]),
          const SizedBox(height: 24),
          _fieldLabel('Measure'),
          _measureField(goal, category),
          const SizedBox(height: 8),
          Text('e.g. kg, km, books',
              style: AbundanceTypography.body
                  .copyWith(color: AbundanceColors.muted, fontSize: 15)),
          if (goal.customUnit) ...<Widget>[
            const SizedBox(height: 16),
            _fieldLabel('Custom measure'),
            _draftField('${category.name}.customUnit',
                hint: 'e.g. pages', onChanged: (value) => goal.unit = value),
          ],
          const SizedBox(height: 24),
          _fieldLabel('Target value', required: true),
          _draftField('${category.name}.target',
              hint: '15',
              keyboardType: TextInputType.number,
              onChanged: (value) => setState(() => goal.target = value)),
          const SizedBox(height: 22),
          _wholeNumbers(goal),
        ],
        if (milestone) ...<Widget>[
          const SizedBox(height: 20),
          Text(
              'This quest is measured by its action plans. Not started counts as 0%, in progress as 50%, and done as 100%.',
              style: AbundanceTypography.body
                  .copyWith(color: AbundanceColors.muted, fontSize: 15)),
        ],
        const SizedBox(height: 24),
        _plansBox(goal, category, milestone),
        const SizedBox(height: 24),
        _fieldLabel('What qualities will you embody?', required: true),
        _draftField('${category.name}.qualities',
            hint: 'Love, Compassion, Integrity, Excellence, Awareness',
            maxLines: 4,
            onChanged: (value) => setState(() => goal.qualities = value)),
        const SizedBox(height: 10),
        Text('Separate each quality with a comma.',
            style: AbundanceTypography.body
                .copyWith(color: AbundanceColors.muted, fontSize: 15)),
        const SizedBox(height: 20),
        _preview(goal, category),
      ],
    );
  }

  Widget _aiBanner(GoalCategory category) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AbundanceColors.surfaceRaised.withValues(alpha: .86),
            borderRadius: BorderRadius.circular(14)),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Start with AI declaration suggestions',
                  style: AbundanceTypography.body
                      .copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                  'Answer three questions, choose from five declarations, then review the rest of this page.',
                  style: AbundanceTypography.body
                      .copyWith(color: AbundanceColors.muted, fontSize: 15)),
              const SizedBox(height: 14),
              AbundanceButton(
                  label: '✣ Get 5 AI suggestions',
                  outlined: true,
                  onPressed: () => _showSuggestions(category)),
            ]),
      );

  Future<void> _showSuggestions(GoalCategory category) async {
    final goal = _goals[category]!;
    final selected = await showModalBottomSheet<_AiSuggestionResult>(
      context: context,
      backgroundColor: AbundanceColors.surfaceRaised,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AiSuggestionsSheet(
        options: _examples[category]!,
        initialGoal: goal.declaration,
        initialPlans:
            goal.plans.where((plan) => plan.trim().isNotEmpty).join(', '),
        initialQualities: goal.qualities,
      ),
    );
    final chosenQualities = selected?.qualities.trim() ?? '';
    final chosenPlans = selected?.plans ?? const <String>[];
    if (selected == null || !mounted) return;
    setState(() {
      goal.declaration = selected.declaration;
      goal.qualities = chosenQualities.isEmpty
          ? 'Love, Compassion, Integrity, Excellence, Awareness'
          : chosenQualities;
      if (chosenPlans.isNotEmpty) {
        goal.plans
          ..clear()
          ..addAll(chosenPlans);
      }
    });
    _controller('${category.name}.declaration').text = selected.declaration;
    if (goal.qualities.isNotEmpty) {
      _controller('${category.name}.qualities').text = goal.qualities;
    }
  }

  Widget _deadlineField(_GoalDraftState goal) => InkWell(
        onTap: () async {
          final picked = await showDatePicker(
              context: context,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 3650)),
              initialDate: goal.targetDate ??
                  DateTime.now().add(const Duration(days: 90)));
          if (picked != null) setState(() => goal.targetDate = picked);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
            height: 58,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: _boxDecoration(),
            child: Row(children: <Widget>[
              Expanded(
                  child: Text(
                      goal.targetDate == null
                          ? 'Choose a date'
                          : MaterialLocalizations.of(context)
                              .formatMediumDate(goal.targetDate!),
                      style: AbundanceTypography.body.copyWith(
                          color: goal.targetDate == null
                              ? AbundanceColors.muted
                              : AbundanceColors.foreground,
                          fontSize: 17))),
              const Icon(Icons.calendar_month_outlined,
                  color: AbundanceColors.primaryGold, size: 24)
            ])),
      );

  Widget _measureField(_GoalDraftState goal, GoalCategory category) {
    final controller = _controller('${category.name}.unit');
    if (controller.text != goal.unit) controller.text = goal.unit;
    return TextField(
      controller: controller,
      readOnly: true,
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
            context: context,
            backgroundColor: AbundanceColors.surfaceRaised,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (context) => SafeArea(
                    child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(18),
                        children: <Widget>[
                      Text('Choose a measure',
                          style: AbundanceTypography.title),
                      const SizedBox(height: 12),
                      ..._units.map((unit) => ListTile(
                          title: Text(unit, style: AbundanceTypography.body),
                          onTap: () => Navigator.pop(context, unit))),
                      ListTile(
                          title: Text('OTHER', style: AbundanceTypography.body),
                          onTap: () => Navigator.pop(context, 'OTHER'))
                    ])));
        if (picked == null || !mounted) return;
        setState(() {
          goal.customUnit = picked == 'OTHER';
          goal.unit = goal.customUnit ? '' : picked;
          controller.text = goal.unit;
        });
      },
      style: AbundanceTypography.body.copyWith(fontSize: 17),
      decoration: InputDecoration(
        hintText: 'Type or choose a measure',
        hintStyle: AbundanceTypography.body
            .copyWith(color: AbundanceColors.muted, fontSize: 17),
        filled: true,
        fillColor: AbundanceColors.surfaceSunken,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        suffixIcon: IconButton(
          tooltip: 'Choose a measure',
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AbundanceColors.muted, size: 28),
          onPressed: () async {
            final picked = await showModalBottomSheet<String>(
                context: context,
                backgroundColor: AbundanceColors.surfaceRaised,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20))),
                builder: (context) => SafeArea(
                        child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(18),
                            children: <Widget>[
                          Text('Choose a measure',
                              style: AbundanceTypography.title),
                          const SizedBox(height: 12),
                          ..._units.map((unit) => ListTile(
                              title:
                                  Text(unit, style: AbundanceTypography.body),
                              onTap: () => Navigator.pop(context, unit))),
                          ListTile(
                              title: Text('OTHER',
                                  style: AbundanceTypography.body),
                              onTap: () => Navigator.pop(context, 'OTHER'))
                        ])));
            if (picked == null || !mounted) return;
            setState(() {
              goal.customUnit = picked == 'OTHER';
              goal.unit = goal.customUnit ? '' : picked;
              controller.text = goal.unit;
            });
          },
        ),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AbundanceColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AbundanceColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: AbundanceColors.primaryGold, width: 1.5)),
      ),
    );
  }

  Widget _directionButton(_GoalDraftState goal, GoalDirection direction) {
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => goal.direction = direction),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 92,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AbundanceColors.surfaceSunken,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: goal.direction == direction
                  ? AbundanceColors.primaryGold
                  : AbundanceColors.border,
              width: goal.direction == direction ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    direction == GoalDirection.gain
                        ? Icons.north_east_rounded
                        : Icons.south_east_rounded,
                    color: direction == GoalDirection.gain
                        ? AbundanceColors.scoreExcellent
                        : AbundanceColors.scoreCritical,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    direction == GoalDirection.gain ? 'Gain' : 'Release',
                    style: AbundanceTypography.body.copyWith(
                      color: goal.direction == direction
                          ? AbundanceColors.primaryGold
                          : AbundanceColors.foreground,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _wholeNumbers(_GoalDraftState goal) => Semantics(
        checked: goal.increment,
        button: true,
        label: 'Only use whole numbers',
        child: InkWell(
          onTap: () => setState(() => goal.increment = !goal.increment),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: _boxDecoration(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: goal.increment
                        ? AbundanceColors.primaryGold
                        : Colors.transparent,
                    border: Border.all(
                        color: AbundanceColors.primaryGold, width: 2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: goal.increment
                      ? const Text('✓',
                          style: TextStyle(
                              color: AbundanceColors.surfaceSunken,
                              fontSize: 21,
                              fontWeight: FontWeight.w900))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text('Only use whole numbers',
                              style: AbundanceTypography.body
                                  .copyWith(fontSize: 17)),
                          const SizedBox(width: 5),
                          const Text('?',
                              style: TextStyle(
                                  color: AbundanceColors.muted, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                          'Turn this on when half does not make sense, like half a participant or half a visit.',
                          style: AbundanceTypography.body.copyWith(
                              color: AbundanceColors.muted, fontSize: 15)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _plansBox(
          _GoalDraftState goal, GoalCategory category, bool milestone) =>
      Container(
          padding: const EdgeInsets.all(16),
          decoration: _boxDecoration(),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(children: <Widget>[
                  const Text('☷',
                      style: TextStyle(
                          color: AbundanceColors.foreground, fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('Action plans',
                      style: AbundanceTypography.body.copyWith(fontSize: 17)),
                  const Spacer(),
                  Text(
                      '${goal.plans.where((plan) => plan.trim().isNotEmpty).length} plans',
                      style: AbundanceTypography.body
                          .copyWith(color: AbundanceColors.muted, fontSize: 16))
                ]),
                const SizedBox(height: 12),
                Text(
                    milestone
                        ? "Required — the steps you'll take. Their statuses determine the score."
                        : "Optional — the steps you'll take. The score comes from the measure above; these just track the work.",
                    style: AbundanceTypography.body
                        .copyWith(color: AbundanceColors.muted, fontSize: 15)),
                const SizedBox(height: 14),
                ...List<Widget>.generate(
                    goal.plans.length,
                    (index) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(children: <Widget>[
                          Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  border: Border.all(
                                      color: AbundanceColors.border, width: 2),
                                  borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _draftField('${category.name}.plan.$index',
                                  hint: index == 0
                                      ? _planHint(category)
                                      : 'Plan ${index + 1}',
                                  onChanged: (value) => setState(
                                      () => goal.plans[index] = value))),
                          IconButton(
                              onPressed: goal.plans.length == 1
                                  ? null
                                  : () => setState(
                                      () => goal.plans.removeAt(index)),
                              icon: const Icon(Icons.close,
                                  color: AbundanceColors.muted))
                        ]))),
                Align(
                    alignment: Alignment.centerLeft,
                    child: AbundanceButton(
                        label: '+ Add plan',
                        outlined: true,
                        onPressed: () => setState(() => goal.plans.add('')))),
              ]));

  String _planHint(GoalCategory category) => switch (category) {
        GoalCategory.personal => 'Book a gym induction',
        GoalCategory.professional => 'Ask my manager what senior looks like',
        GoalCategory.contribution => 'Offer to mentor one junior this month'
      };

  Widget _preview(_GoalDraftState goal, GoalCategory category) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AbundanceColors.surfaceRaised.withValues(alpha: .72),
          border: Border.all(
              color: AbundanceColors.primaryGold.withValues(alpha: .55),
              width: 1.5),
          borderRadius: BorderRadius.circular(14)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('YOUR ${category.label.toUpperCase()} DECLARATION',
                style: AbundanceTypography.eyebrow),
            const SizedBox(height: 12),
            Text(
                goal.declaration.trim().isEmpty
                    ? 'Your declaration will appear here.'
                    : goal.declaration.trim(),
                style: AbundanceTypography.body.copyWith(fontSize: 17)),
            if (goal.qualities.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text('QUALITIES', style: AbundanceTypography.eyebrow),
              const SizedBox(height: 6),
              Text(goal.qualities.trim(),
                  style: AbundanceTypography.body.copyWith(fontSize: 16))
            ]
          ]));

  Widget _infoBox() => Container(
      padding: const EdgeInsets.all(16),
      decoration: _boxDecoration(),
      child:
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                border:
                    Border.all(color: AbundanceColors.primaryGold, width: 2),
                borderRadius: BorderRadius.circular(6)),
            child: const Text('i',
                style: TextStyle(
                    color: AbundanceColors.primaryGold,
                    fontSize: 20,
                    fontWeight: FontWeight.w700))),
        const SizedBox(width: 14),
        Expanded(
            child: Text(
                'Abundance 12 forges your quests, daily disciplines and nightly reckonings into one honest score. Setup takes about two minutes.',
                style: AbundanceTypography.body
                    .copyWith(color: AbundanceColors.muted, fontSize: 15)))
      ]));

  Widget _footer() => Row(children: <Widget>[
        if (_step > 0)
          Expanded(
              child: AbundanceButton(
                  label: '← Back',
                  outlined: true,
                  onPressed: _saving ? null : _back))
        else
          const Spacer(),
        const SizedBox(width: 14),
        Expanded(
            child: AbundanceButton(
                label: _saving
                    ? 'Saving…'
                    : (_step == 0
                        ? 'Begin'
                        : _step == 3
                            ? 'Enter Abundance 12'
                            : 'Continue'),
                onPressed: _saving ? null : _next)),
      ]);

  TextEditingController _controller(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  Widget _draftField(String key,
          {required String hint,
          ValueChanged<String>? onChanged,
          int maxLines = 1,
          TextInputType? keyboardType}) =>
      _textField(
          controller: _controller(key),
          hint: hint,
          onChanged: onChanged,
          maxLines: maxLines,
          keyboardType: keyboardType);

  Widget _fieldLabel(String label, {bool required = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text.rich(TextSpan(
          text: label,
          style: AbundanceTypography.body
              .copyWith(color: AbundanceColors.muted, fontSize: 16),
          children: required
              ? const <InlineSpan>[
                  TextSpan(
                      text: ' *',
                      style: TextStyle(color: AbundanceColors.scoreCritical))
                ]
              : const <InlineSpan>[])));

  Widget _textField(
          {required TextEditingController controller,
          required String hint,
          ValueChanged<String>? onChanged,
          int maxLines = 1,
          TextInputType? keyboardType}) =>
      TextField(
          controller: controller,
          onChanged: onChanged,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: AbundanceTypography.body.copyWith(fontSize: 17),
          decoration: InputDecoration(
              hintText: hint,
              hintStyle: AbundanceTypography.body
                  .copyWith(color: AbundanceColors.muted, fontSize: 17),
              filled: true,
              fillColor: AbundanceColors.surfaceSunken,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AbundanceColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AbundanceColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                      color: AbundanceColors.primaryGold, width: 1.5))));

  BoxDecoration _boxDecoration() => BoxDecoration(
      color: AbundanceColors.surfaceSunken,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AbundanceColors.border));
}
