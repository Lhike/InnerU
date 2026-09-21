# Abundance Coach Directory and Quest Reports

## Goal

Make the InnerU Abundance coach directory and reporting flow match `abundance-inneru-tracker-mobile`: use the source coach records and artwork, expose two coach-only report actions, and render an Excel-like weekly quest report backed by the A12 roster.

## Scope and constraints

- This applies only inside the Abundance experience for users authorized as coaches by the A12/InnerU role bridge.
- Other InnerU companies and their existing coach screens remain unchanged.
- Coach/student scope is server-authoritative. The report receives students from the authenticated coach roster; the client must not invent or broaden assignments.
- “All students report” means all students in the councils/assignments returned for the signed-in coach, matching the source app’s “all councils you lead” behavior.
- “View quests report” is limited to the signed-in coach’s assigned students and supports council/student filtering.
- No mock report records or duplicate InnerU Abundance storage are introduced.

## Source behavior to reproduce

The source `Coaches` screen uses the sorted records from `src/data/a12_coaches.json`, displays each coach with artwork, declaration, and background details, and shows the two report actions only for a coach. Its report screen filters by council, student, and date range, calculates Monday-to-Sunday weekly progress from quest history, and displays a horizontally scrollable sheet with student, council, category, quest, target, and weekly percentage columns.

## Target design

1. Add a bundled `a12_coaches.json` and the 25 coach images referenced by that source catalog under the Abundance asset namespace. Add a typed loader that preserves the source sort order: level 1, level 2, then the remaining records by source sort key/name.
2. Update `AbundanceCoachDirectoryScreen` to render the source list and source-style detail modal. Keep the report buttons visible only from the coach-only Abundance destination.
3. Add pure Dart report calculations for validated dates, clipped Monday-to-Sunday ranges, category ordering, target formatting, weekly progress from goal history, and average score.
4. Add `AbundanceCoachQuestReportScreen` with all-students/assigned-students scopes, council and student filters, calendar date pickers, summary cards, and a horizontally scrollable table.
5. Route the two directory buttons to the report screen instead of Core Tasks/quest roster. Pass the A12 roster through the existing `GoalsService.fetchA12CoachRoster()` path.

## Error and security behavior

- A non-coach cannot reach either report route from the Abundance shell.
- A report load failure shows a retryable error state and never falls back to unrelated InnerU users.
- Empty data shows a source-aligned empty state rather than fabricated rows.
- Invalid date ranges disable Apply and show a validation message.

## Verification

- Unit tests cover source coach sorting, date ranges, weekly progress, target formatting, and report filtering.
- Widget tests cover coach directory action routing, coach list rendering, report scope, table headings, date picker entry points, and non-coach denial.
- Run the focused Flutter coach suite and the full Flutter test command before rebuilding.
