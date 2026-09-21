class AbundanceReportWeek {
  const AbundanceReportWeek({required this.start, required this.end});

  final String start;
  final String end;
}

class AbundanceReportRow {
  const AbundanceReportRow({
    required this.studentId,
    required this.studentName,
    required this.council,
    required this.categoryKey,
    required this.category,
    required this.title,
    required this.target,
    required this.weeklyProgress,
  });

  final String studentId;
  final String studentName;
  final String council;
  final String categoryKey;
  final String category;
  final String title;
  final String target;
  final List<double> weeklyProgress;
}

List<AbundanceReportWeek> abundanceReportWeeks(String from, String to) {
  final startDate = _parseDay(from);
  final endDate = _parseDay(to);
  if (startDate == null || endDate == null || startDate.isAfter(endDate)) {
    return const <AbundanceReportWeek>[];
  }

  var cursor = _mondayOf(startDate);
  final weeks = <AbundanceReportWeek>[];
  while (!cursor.isAfter(endDate)) {
    final weekEnd = cursor.add(const Duration(days: 6));
    final clippedStart = cursor.isBefore(startDate) ? startDate : cursor;
    final clippedEnd = weekEnd.isAfter(endDate) ? endDate : weekEnd;
    weeks.add(AbundanceReportWeek(
      start: _dayString(clippedStart),
      end: _dayString(clippedEnd),
    ));
    cursor = cursor.add(const Duration(days: 7));
  }
  return weeks;
}

List<AbundanceReportRow> buildAbundanceQuestReportRows(
  List<Map<String, dynamic>> students,
  String from,
  String to,
) {
  final weeks = abundanceReportWeeks(from, to);
  const categoryOrder = <String>['PERSONAL', 'PROFESSIONAL', 'CONTRIBUTION'];
  final rows = <AbundanceReportRow>[];

  for (final student in students) {
    final goals = _maps(student['goals'])
        .where((goal) => _string(goal['status']).toUpperCase() != 'ABANDONED')
        .toList();
    goals.sort((left, right) {
      final leftKey = _categoryKey(left);
      final rightKey = _categoryKey(right);
      final leftIndex = categoryOrder.indexOf(leftKey);
      final rightIndex = categoryOrder.indexOf(rightKey);
      final safeLeft = leftIndex == -1 ? categoryOrder.length : leftIndex;
      final safeRight = rightIndex == -1 ? categoryOrder.length : rightIndex;
      return safeLeft == safeRight
          ? _string(left['title']).compareTo(_string(right['title']))
          : safeLeft.compareTo(safeRight);
    });

    for (final goal in goals) {
      final category = _categoryMap(goal['category']);
      rows.add(AbundanceReportRow(
        studentId: _string(student['id']),
        studentName: '${_string(student['firstName'])} '
                '${_string(student['lastName'])}'
            .trim(),
        council: _string(student['council']).isEmpty
            ? '—'
            : _string(student['council']),
        categoryKey: _categoryKey(goal),
        category: _string(category['name']).isEmpty
            ? _categoryKey(goal)
            : _string(category['name']),
        title: _string(goal['statement']).isEmpty
            ? _string(goal['title'])
            : _string(goal['statement']),
        target: _targetLabel(goal),
        weeklyProgress: weeks
            .map((week) => _weeklyProgress(goal, week))
            .toList(growable: false),
      ));
    }
  }
  return rows;
}

double abundanceReportAverage(List<Map<String, dynamic>> students) {
  final scores = <double>[];
  for (final student in students) {
    for (final goal in _maps(student['goals'])) {
      if (_string(goal['status']).toUpperCase() == 'ABANDONED') continue;
      final score = _number(goal['score'] ?? goal['progress']);
      if (score != null) scores.add(score);
    }
  }
  if (scores.isEmpty) return 0;
  return scores.reduce((left, right) => left + right) / scores.length;
}

double _weeklyProgress(Map<String, dynamic> goal, AbundanceReportWeek week) {
  final target = _number(goal['targetValue']) ?? 0;
  if (target <= 0) return 0;
  final history = _maps(goal['history']);
  final loggedBefore = history
      .where((entry) => _string(entry['date']).compareTo(week.start) < 0)
      .map((entry) => _number(entry['amount']) ?? 0)
      .fold<double>(0, (sum, amount) => sum + amount);
  final loggedInRange = history
      .where((entry) {
        final date = _string(entry['date']);
        return date.compareTo(week.start) >= 0 && date.compareTo(week.end) <= 0;
      })
      .map((entry) => _number(entry['amount']) ?? 0)
      .fold<double>(0, (sum, amount) => sum + amount);
  final remaining = (target - loggedBefore).clamp(0, target).toDouble();
  return ((loggedInRange.clamp(0, remaining) / target) * 100)
      .clamp(0, 100)
      .toDouble();
}

String _targetLabel(Map<String, dynamic> goal) {
  final target = _number(goal['targetValue']);
  final value = target == null
      ? '0'
      : target == target.roundToDouble()
          ? target.toInt().toString()
          : target.toString();
  final unit = _string(goal['unit']);
  return unit.isEmpty ? value : '$value $unit';
}

Map<String, dynamic> _categoryMap(Object? raw) {
  return raw is Map ? Map<String, dynamic>.from(raw) : const {};
}

String _categoryKey(Map<String, dynamic> goal) {
  final category = _categoryMap(goal['category']);
  return _string(category['key']).isEmpty
      ? _string(category['code']).toUpperCase()
      : _string(category['key']).toUpperCase();
}

List<Map<String, dynamic>> _maps(Object? raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

double? _number(Object? raw) {
  if (raw is num) return raw.toDouble();
  return null;
}

String _string(Object? raw) => raw?.toString().trim() ?? '';

DateTime? _parseDay(String raw) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return null;
  final parsed = DateTime.tryParse('${raw}T00:00:00Z');
  if (parsed == null || _dayString(parsed) != raw) return null;
  return parsed;
}

DateTime _mondayOf(DateTime date) =>
    date.subtract(Duration(days: date.weekday - DateTime.monday));

String _dayString(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
