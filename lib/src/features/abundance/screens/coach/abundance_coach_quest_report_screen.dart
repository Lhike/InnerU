import 'package:flutter/material.dart';

import 'package:selfcare_projects/src/features/abundance/coach/coach_quest_report.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_theme.dart';
import 'package:selfcare_projects/src/features/abundance/theme/abundance_typography.dart';

const _reportFieldBackground = Color(0xFFFDFDFD);
const _reportFieldText = Color(0xFF329B98);

enum AbundanceCoachReportScope { allStudents, assignedStudents }

class AbundanceCoachQuestReportScreen extends StatefulWidget {
  const AbundanceCoachQuestReportScreen({
    super.key,
    required this.isCoach,
    required this.scope,
    required this.rosterLoader,
  });

  final bool isCoach;
  final AbundanceCoachReportScope scope;
  final Future<List<Map<String, dynamic>>> Function() rosterLoader;

  @override
  State<AbundanceCoachQuestReportScreen> createState() =>
      _AbundanceCoachQuestReportScreenState();
}

class _AbundanceCoachQuestReportScreenState
    extends State<AbundanceCoachQuestReportScreen> {
  late Future<List<Map<String, dynamic>>> _rosterFuture;
  late DateTime _from;
  late DateTime _to;
  late DateTime _appliedFrom;
  late DateTime _appliedTo;
  String _council = 'all';
  String _student = 'all';

  @override
  void initState() {
    super.initState();
    final today = _dateOnly(DateTime.now());
    _from = today.subtract(const Duration(days: 83));
    _to = today;
    _appliedFrom = _from;
    _appliedTo = _to;
    _rosterFuture = widget.rosterLoader();
  }

  String get _title => widget.scope == AbundanceCoachReportScope.allStudents
      ? 'All students report'
      : 'View quests report';

  String get _subtitle => widget.scope == AbundanceCoachReportScope.allStudents
      ? 'Quest progress across all councils you lead.'
      : 'Quest progress for students assigned to you.';

  void _retry() {
    setState(() => _rosterFuture = widget.rosterLoader());
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCoach) {
      return Scaffold(
        backgroundColor: AbundanceColors.background,
        body: SafeArea(
          child: Center(
            child: Text(
              'Coach access is required to view reports.',
              style: AbundanceTypography.body.copyWith(
                color: AbundanceColors.muted,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AbundanceColors.background,
      appBar: AppBar(
        backgroundColor: AbundanceColors.surfaceRaised,
        foregroundColor: AbundanceColors.foreground,
        title: Text('Quest report', style: AbundanceTypography.title),
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _rosterFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _ErrorState(onRetry: _retry);
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AbundanceColors.primaryGold,
                ),
              );
            }
            return _buildReport(snapshot.data ?? const []);
          },
        ),
      ),
    );
  }

  Widget _buildReport(List<Map<String, dynamic>> roster) {
    final councils = <String>{
      for (final student in roster)
        if (_string(student['council']).isNotEmpty) _string(student['council']),
    }.toList()
      ..sort();
    final councilOptions = <String>['all', ...councils];
    if (!councilOptions.contains(_council)) _council = 'all';

    final councilStudents = roster.where((student) {
      return _council == 'all' || _string(student['council']) == _council;
    }).toList();
    final studentOptions = <String>[
      'all',
      for (final student in councilStudents) _string(student['id']),
    ];
    if (!studentOptions.contains(_student)) _student = 'all';
    final visibleStudents = councilStudents.where((student) {
      return _student == 'all' || _string(student['id']) == _student;
    }).toList();

    final from = _dayString(_appliedFrom);
    final to = _dayString(_appliedTo);
    final weeks = abundanceReportWeeks(from, to);
    final rows = buildAbundanceQuestReportRows(visibleStudents, from, to);
    final rangeError = _from.isAfter(_to);

    return RefreshIndicator(
      onRefresh: () async => _retry(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _HeroCard(title: _title, subtitle: _subtitle),
          const SizedBox(height: 14),
          _FilterCard(
            council: _council == 'all' ? 'All councils' : _council,
            student: _student == 'all'
                ? 'All students'
                : _studentName(councilStudents, _student),
            from: _from,
            to: _to,
            rangeError: rangeError,
            onCouncil: () => _chooseCouncil(councilOptions),
            onStudent: () => _chooseStudent(councilStudents),
            onFrom: () => _chooseDate(isFrom: true),
            onTo: () => _chooseDate(isFrom: false),
            onApply: rangeError
                ? null
                : () => setState(() {
                      _appliedFrom = _from;
                      _appliedTo = _to;
                    }),
          ),
          const SizedBox(height: 14),
          _StatsRow(
            students: visibleStudents.length,
            average: abundanceReportAverage(visibleStudents),
            from: _appliedFrom,
            to: _appliedTo,
          ),
          const SizedBox(height: 18),
          Text('Quests rating sheet', style: AbundanceTypography.title),
          const SizedBox(height: 4),
          Text(
            'Swipe sideways to view each weekly reporting period.',
            style: AbundanceTypography.body.copyWith(
              color: AbundanceColors.muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Text(
              'No quests match these filters.',
              style: AbundanceTypography.body.copyWith(
                color: AbundanceColors.muted,
              ),
            )
          else
            _ReportTable(rows: rows, weeks: weeks),
        ],
      ),
    );
  }

  Future<void> _chooseCouncil(List<String> options) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AbundanceColors.surfaceRaised,
      builder: (sheetContext) => _ChoiceSheet(
        title: 'Choose report council',
        options: options
            .map((value) => value == 'all' ? 'All councils' : value)
            .toList(),
      ),
    );
    if (picked == null) return;
    setState(() => _council = picked == 'All councils' ? 'all' : picked);
  }

  Future<void> _chooseStudent(List<Map<String, dynamic>> students) async {
    final labels = <String>['All students'];
    final ids = <String>['all'];
    for (final student in students) {
      ids.add(_string(student['id']));
      labels.add(_studentName([student], _string(student['id'])));
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AbundanceColors.surfaceRaised,
      builder: (sheetContext) => _IndexedChoiceSheet(
        title: 'Choose report student',
        options: labels,
      ),
    );
    if (picked == null || picked < 0 || picked >= ids.length) return;
    setState(() => _student = ids[picked]);
  }

  Future<void> _chooseDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: isFrom ? 'Choose start date' : 'Choose end date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AbundanceColors.primaryGold,
            surface: AbundanceColors.surfaceRaised,
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = _dateOnly(picked);
      } else {
        _to = _dateOnly(picked);
      }
    });
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AbundanceColors.surfaceRaised,
          border: Border.all(color: AbundanceColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('QUESTS REPORT', style: AbundanceTypography.eyebrow),
            const SizedBox(height: 6),
            Text(title, style: AbundanceTypography.display),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: AbundanceTypography.body.copyWith(
                color: AbundanceColors.muted,
              ),
            ),
          ],
        ),
      );
}

class _FilterCard extends StatelessWidget {
  const _FilterCard({
    required this.council,
    required this.student,
    required this.from,
    required this.to,
    required this.rangeError,
    required this.onCouncil,
    required this.onStudent,
    required this.onFrom,
    required this.onTo,
    required this.onApply,
  });

  final String council;
  final String student;
  final DateTime from;
  final DateTime to;
  final bool rangeError;
  final VoidCallback onCouncil;
  final VoidCallback onStudent;
  final VoidCallback onFrom;
  final VoidCallback onTo;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AbundanceColors.surfaceRaised,
          border: Border.all(color: AbundanceColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter report', style: AbundanceTypography.title),
            const SizedBox(height: 10),
            const Text('Council', style: _FieldLabelStyle()),
            _FilterButton(
              label: council,
              accessibilityLabel: 'Choose report council',
              onPressed: onCouncil,
            ),
            const SizedBox(height: 8),
            const Text('Student', style: _FieldLabelStyle()),
            _FilterButton(
              label: student,
              accessibilityLabel: 'Choose report student',
              onPressed: onStudent,
            ),
            const SizedBox(height: 8),
            const Text('Reporting cycle', style: _FieldLabelStyle()),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'Start date',
                    date: from,
                    onPressed: onFrom,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('to', style: _FieldLabelStyle()),
                ),
                Expanded(
                  child: _DateButton(
                    label: 'End date',
                    date: to,
                    onPressed: onTo,
                  ),
                ),
              ],
            ),
            if (rangeError)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Choose an end date on or after the start date.',
                  style: TextStyle(color: AbundanceColors.scoreCritical),
                ),
              ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onApply,
              style: FilledButton.styleFrom(
                backgroundColor: AbundanceColors.primaryGold,
                foregroundColor: AbundanceColors.background,
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Apply filters'),
            ),
          ],
        ),
      );
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.accessibilityLabel,
    required this.onPressed,
  });

  final String label;
  final String accessibilityLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: accessibilityLabel,
        child: OutlinedButton(
          onPressed: onPressed,
          style: ButtonStyle(
            alignment: Alignment.centerLeft,
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(42)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 12),
            ),
            backgroundColor:
                const WidgetStatePropertyAll(_reportFieldBackground),
            foregroundColor: const WidgetStatePropertyAll(_reportFieldText),
            side: const WidgetStatePropertyAll(
              BorderSide(color: _reportFieldBackground),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
      );
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onPressed,
  });

  final String label;
  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: OutlinedButton(
          onPressed: onPressed,
          style: ButtonStyle(
            alignment: Alignment.centerLeft,
            minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 10),
            ),
            backgroundColor:
                const WidgetStatePropertyAll(_reportFieldBackground),
            foregroundColor: const WidgetStatePropertyAll(_reportFieldText),
            side: const WidgetStatePropertyAll(
              BorderSide(color: _reportFieldBackground),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const _FieldLabelStyle()),
              Text(_displayDay(date)),
            ],
          ),
        ),
      );
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.students,
    required this.average,
    required this.from,
    required this.to,
  });

  final int students;
  final double average;
  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: _Stat(label: 'STUDENTS', value: '$students')),
          const SizedBox(width: 8),
          Expanded(
            child: _Stat(label: 'QUEST AVERAGE', value: '${average.round()}%'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Stat(
              label: 'REPORTING CYCLE',
              value: '${_displayDay(from)} – ${_displayDay(to)}',
            ),
          ),
        ],
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AbundanceColors.surfaceRaised,
          border: Border.all(color: AbundanceColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const _FieldLabelStyle()),
            const SizedBox(height: 5),
            Text(value, style: AbundanceTypography.body),
          ],
        ),
      );
}

class _ReportTable extends StatelessWidget {
  const _ReportTable({required this.rows, required this.weeks});

  final List<AbundanceReportRow> rows;
  final List<AbundanceReportWeek> weeks;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const WidgetStatePropertyAll(
            AbundanceColors.surfaceRaised,
          ),
          dataRowColor:
              const WidgetStatePropertyAll(AbundanceColors.background),
          headingTextStyle: const TextStyle(
            color: AbundanceColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
          dataTextStyle: const TextStyle(
            color: AbundanceColors.foreground,
            fontSize: 11,
            height: 1.4,
          ),
          dividerThickness: 1,
          headingRowHeight: 54,
          dataRowMinHeight: 58,
          dataRowMaxHeight: 76,
          horizontalMargin: 12,
          columnSpacing: 18,
          columns: [
            'STUDENT',
            'REALM',
            'QUEST',
            'TARGET',
            for (final week in weeks) '${week.start}\n${week.end}',
          ].map((label) => DataColumn(label: Text(label))).toList(),
          rows: rows
              .map(
                (row) => DataRow(
                  cells: [
                    DataCell(Text('${row.studentName}\n${row.council}')),
                    DataCell(Text(row.category)),
                    DataCell(Text(row.title)),
                    DataCell(Text(row.target)),
                    for (final value in row.weeklyProgress)
                      DataCell(Text('${value.round()}%')),
                  ],
                ),
              )
              .toList(),
        ),
      );
}

class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet({required this.title, required this.options});

  final String title;
  final List<String> options;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(title, style: AbundanceTypography.title),
            for (final option in options)
              ListTile(
                title: Text(option),
                onTap: () => Navigator.pop(context, option),
              ),
          ],
        ),
      );
}

class _IndexedChoiceSheet extends StatelessWidget {
  const _IndexedChoiceSheet({required this.title, required this.options});

  final String title;
  final List<String> options;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text(title, style: AbundanceTypography.title),
            for (var index = 0; index < options.length; index++)
              ListTile(
                title: Text(options[index]),
                onTap: () => Navigator.pop(context, index),
              ),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'The report could not be loaded.',
              style: AbundanceTypography.body.copyWith(
                color: AbundanceColors.muted,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}

class _FieldLabelStyle extends TextStyle {
  const _FieldLabelStyle()
      : super(
          color: AbundanceColors.muted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        );
}

String _studentName(List<Map<String, dynamic>> students, String id) {
  final student = students.firstWhere(
    (item) => _string(item['id']) == id,
    orElse: () => const <String, dynamic>{},
  );
  final name = '${_string(student['firstName'])} '
          '${_string(student['lastName'])}'
      .trim();
  return name.isEmpty ? 'Student' : name;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dayString(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _displayDay(DateTime value) =>
    '${value.month}/${value.day}/${value.year}';

String _string(Object? value) => value?.toString().trim() ?? '';
