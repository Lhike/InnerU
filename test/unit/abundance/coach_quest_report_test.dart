import 'package:flutter_test/flutter_test.dart';

import 'package:selfcare_projects/src/features/abundance/coach/coach_quest_report.dart';

void main() {
  final students = <Map<String, dynamic>>[
    {
      'id': 'student-1',
      'firstName': 'Jamie',
      'lastName': 'Rivera',
      'council': 'Dawn',
      'goals': [
        {
          'status': 'IN_PROGRESS',
          'category': {'key': 'CONTRIBUTION', 'name': 'Contribution'},
          'title': 'Read books',
          'statement': 'Read 10 books',
          'targetValue': 10,
          'unit': 'books',
          'score': 50,
          'history': [
            {'date': '2026-09-14', 'amount': 4},
            {'date': '2026-09-16', 'amount': 3},
            {'date': '2026-09-21', 'amount': 5},
          ],
        },
        {
          'status': 'ABANDONED',
          'category': {'key': 'PERSONAL', 'name': 'Personal'},
          'title': 'Ignored quest',
          'targetValue': 1,
        },
        {
          'status': 'IN_PROGRESS',
          'category': {'key': 'PERSONAL', 'name': 'Personal'},
          'title': 'Meditate',
          'targetValue': 7,
          'unit': 'days',
          'score': 80,
        },
      ],
    },
  ];

  test('clips a date range into Monday-to-Sunday report weeks', () {
    final weeks = abundanceReportWeeks('2026-09-16', '2026-09-27');

    expect(weeks.map((week) => '${week.start}/${week.end}'), [
      '2026-09-16/2026-09-20',
      '2026-09-21/2026-09-27',
    ]);
    expect(abundanceReportWeeks('2026-09-28', '2026-09-20'), isEmpty);
    expect(abundanceReportWeeks('bad', '2026-09-20'), isEmpty);
  });

  test('builds ordered rows and caps weekly progress by remaining target', () {
    final rows = buildAbundanceQuestReportRows(
      students,
      '2026-09-14',
      '2026-09-27',
    );

    expect(rows, hasLength(2));
    expect(rows.map((row) => row.categoryKey), ['PERSONAL', 'CONTRIBUTION']);
    final reading = rows.last;
    expect(reading.target, '10 books');
    expect(reading.weeklyProgress, [70, 30]);
  });

  test('calculates the average from non-abandoned goal scores', () {
    expect(abundanceReportAverage(students), 65);
  });

  test('uses zero for missing or invalid targets and history values', () {
    final rows = buildAbundanceQuestReportRows([
      {
        'id': 'student-2',
        'firstName': 'Taylor',
        'lastName': 'Stone',
        'goals': [
          {
            'status': 'IN_PROGRESS',
            'category': {'key': 'PERSONAL', 'name': 'Personal'},
            'title': 'Unknown',
            'targetValue': 0,
            'history': [
              {'date': '2026-09-14', 'amount': 'bad'},
            ],
          },
        ],
      },
    ], '2026-09-14', '2026-09-20');

    expect(rows.single.weeklyProgress, [0]);
    expect(
        abundanceReportAverage([
          {
            'goals': [
              {'status': 'IN_PROGRESS', 'score': 'bad'},
            ],
          },
        ]),
        0);
  });
}
