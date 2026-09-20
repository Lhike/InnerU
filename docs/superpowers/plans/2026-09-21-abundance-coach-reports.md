# Abundance Coach Directory and Quest Reports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reproduce the source Abundance coach directory and weekly quest report flow in the InnerU Flutter Abundance experience.

**Architecture:** Bundle the source coach catalog/artwork locally for the coach directory. Build the report from the existing A12-authoritative coach roster returned by `GoalsService.fetchA12CoachRoster`, with pure report calculations separated from the Flutter screen. Route both coach report actions through the existing Abundance shell and retain server-side assignment enforcement.

**Tech Stack:** Flutter/Dart, Material widgets, existing `GoalsService`/`A12ApiTransport`, Flutter widget tests, source JSON/JPG assets.

**Spec:** `docs/superpowers/specs/2026-09-21-abundance-coach-reports-design.md`

## Global Constraints

- This applies only inside the Abundance experience for users authorized as coaches by the A12/InnerU role bridge.
- Other InnerU companies and their existing coach screens remain unchanged.
- Coach/student scope is server-authoritative.
- “All students report” means all students in the councils/assignments returned for the signed-in coach.
- “View quests report” is limited to the signed-in coach’s assigned students.
- No mock report records or duplicate InnerU Abundance storage are introduced.

## Review Focus

- A malformed or reversed report date range must not produce misleading weekly columns — owned by Task 2 date-range tests.
- A coach with no assignments must see an empty report, not another company’s users — owned by Task 3 empty-state/widget tests.
- A non-coach must not open a report by constructing the screen directly — owned by Task 3 access test.
- Goal histories with missing targets or empty updates must produce zero/valid percentages — owned by Task 2 calculation tests.
- Missing coach artwork must not crash the directory — owned by Task 1 catalog/widget tests.

---

### Task 1: Source Coach Directory Catalog

**Files:**
- Create: `assets/data/a12_coaches.json`
- Create: `assets/images/abundance/coaches/*.jpg` (25 images referenced by the source catalog)
- Modify: `pubspec.yaml:127-138`
- Create: `lib/src/features/abundance/coach/coach_catalog.dart`
- Modify: `lib/src/features/abundance/screens/coach/abundance_coach_directory_screen.dart`
- Test: `test/unit/abundance/coach_catalog_test.dart`
- Test: `test/widget/abundance/abundance_coach_directory_screen_test.dart`

**Interfaces:**
- Produces `AbundanceCoachCatalog.load()` returning `Future<List<AbundanceCoachCatalogEntry>>`.
- `AbundanceCoachCatalogEntry` exposes `name`, `declaration`, `background`, and `assetPath`.

- [ ] **Step 1: Copy the source catalog and artwork**

Copy `abundance-inneru-tracker-mobile/src/data/a12_coaches.json` unchanged to `assets/data/a12_coaches.json` and copy the 25 JPG files named by its `picture` fields from `abundance-inneru-tracker-mobile/assets/web/public/coaches` into `assets/images/abundance/coaches`.

- [ ] **Step 2: Add the asset declarations**

Add the JSON and coach directory to the existing Flutter asset declarations without changing other asset paths:

```yaml
    - assets/data/a12_coaches.json
    - assets/images/abundance/coaches/
```

- [ ] **Step 3: Write failing catalog tests**

Assert the loaded catalog contains 25 records, starts with the source level-1/level-2 ordering, maps `picture` to `assets/images/abundance/coaches/<picture>`, and retains a declaration/background. Assert a missing asset path can be rendered with a fallback avatar.

- [ ] **Step 4: Run the catalog tests and verify RED**

Run `flutter test test/unit/abundance/coach_catalog_test.dart`; it must fail because the loader and catalog entry do not exist.

- [ ] **Step 5: Implement the typed catalog loader**

Load the asset JSON with `rootBundle`, parse only maps with a non-empty name/picture, sort using the source `level1-`, `level2-`, then source letter/name rule, and return typed entries. Use a deterministic fallback asset path in the card widget when `Image.asset` reports an error.

- [ ] **Step 6: Update the directory screen to use the catalog**

Replace the generic `/api/coaches` list in the Abundance directory with the catalog loader. Keep coach-only report actions and add a tappable source-style card/modal showing image, name, declaration, and background bullets. Do not change the generic InnerU `/api/coaches` screen.

- [ ] **Step 7: Add directory widget coverage**

Assert the exact report button labels, at least the source names `Aryanne Gengos` and `Charlie Gengos`, a source image path, and the detail modal interaction.

- [ ] **Step 8: Run Task 1 tests and commit**

Run `flutter test test/unit/abundance/coach_catalog_test.dart test/widget/abundance/abundance_coach_directory_screen_test.dart`; expected result is all passing. Commit with `feat: match abundance coach directory catalog`.

### Task 2: Pure Quest Report Calculations

**Files:**
- Create: `lib/src/features/abundance/coach/coach_quest_report.dart`
- Test: `test/unit/abundance/coach_quest_report_test.dart`

**Interfaces:**
- Produces `AbundanceReportStudent`, `AbundanceReportWeek`, `AbundanceReportRow`, `abundanceReportWeeks`, `buildAbundanceQuestReportRows`, and `abundanceReportAverage`.
- Consumes the existing A12 roster map shape: `id`, `firstName`, `lastName`, `council`, and `goals` with `history`, `targetValue`, `unit`, `statement`, `title`, `category`, and `status`.

- [ ] **Step 1: Write failing calculation tests**

Cover Monday-to-Sunday clipping, reversed/invalid dates returning no weeks, category ordering PERSONAL/PROFESSIONAL/CONTRIBUTION, abandoned-goal exclusion, weekly progress capped at 100%, target formatting, and average score across visible goals.

- [ ] **Step 2: Run the calculation tests and verify RED**

Run `flutter test test/unit/abundance/coach_quest_report_test.dart`; it must fail because the report types/functions do not exist.

- [ ] **Step 3: Implement the minimal pure report module**

Implement UTC-safe date parsing, week clipping, map-to-student conversion, history amount accumulation, target clamping, and average calculation without network or Flutter dependencies.

- [ ] **Step 4: Run the calculation tests and commit**

Run `flutter test test/unit/abundance/coach_quest_report_test.dart`; expected result is all passing. Commit with `feat: add abundance quest report calculations`.

### Task 3: Report Sheet and Routing

**Files:**
- Create: `lib/src/features/abundance/screens/coach/abundance_coach_quest_report_screen.dart`
- Modify: `lib/src/features/abundance/screens/coach/abundance_coach_directory_screen.dart`
- Modify: `lib/src/features/abundance/screens/abundance_shell_screen.dart`
- Test: `test/widget/abundance/abundance_coach_quest_report_screen_test.dart`
- Modify: `test/widget/abundance/abundance_coach_home_screen_test.dart`

**Interfaces:**
- Consumes `AbundanceReportStudent`/report functions from Task 2 and `AbundanceCoachCatalog` from Task 1.
- Produces `AbundanceCoachQuestReportScreen({required rosterLoader, required isCoach, required scope})` with `scope` values `allStudents` and `assignedStudents`.

- [ ] **Step 1: Write failing report widget tests**

Assert non-coach denial, both scope headings, council/student filter controls, start/end date controls, summary metrics, horizontal sheet headings (`STUDENT`, `COUNCIL`, `CATEGORY`, `QUEST`, `TARGET`), and empty roster behavior. Assert the directory actions route to the report screen rather than Core Tasks or the old quest roster.

- [ ] **Step 2: Run the widget tests and verify RED**

Run `flutter test test/widget/abundance/abundance_coach_quest_report_screen_test.dart test/widget/abundance/abundance_coach_home_screen_test.dart`; expected result is failure because the report screen and new routes are absent.

- [ ] **Step 3: Implement the report screen**

Use `FutureBuilder` for the A12 roster, date picker dialogs for start/end dates, modal selection sheets for council/student filters, source-aligned hero/filter/stats styling, and a horizontally scrollable `DataTable`-like row layout. Only display rows from the supplied roster; do not fetch generic InnerU users.

- [ ] **Step 4: Wire directory buttons and shell navigation**

Route “All students report” to `scope: allStudents` and “View quests report” to `scope: assignedStudents`; both use `GoalsService.fetchA12CoachRoster()` and retain the shell’s coach-only destination gate. Keep Core Tasks and Quest List available as separate tools.

- [ ] **Step 5: Run the focused coach suite and commit**

Run `flutter test test/widget/abundance/abundance_coach_quest_report_screen_test.dart test/widget/abundance/abundance_coach_home_screen_test.dart test/widget/abundance/coach_quests_roster_screen_test.dart test/unit/abundance/coach_catalog_test.dart test/unit/abundance/coach_quest_report_test.dart`; expected result is all passing. Commit with `feat: add source-aligned abundance coach reports`.

### Task 4: Full Verification, Rebuild, and Deployment

**Files:**
- Modify only files already listed above if verification finds a regression.

- [ ] **Step 1: Run formatting and analysis**

Run `dart format` on changed Dart files and `flutter analyze`; expected result is no new errors.

- [ ] **Step 2: Run the full Flutter test suite**

Run `flutter test`; expected result is all tests passing. If an unrelated pre-existing failure appears, record its exact test name and do not mask it.

- [ ] **Step 3: Build the iOS app**

Run `flutter build ios --simulator --no-codesign`; expected result is exit code 0 and a rebuilt `Runner.app` containing the coach catalog/artwork.

- [ ] **Step 4: Deploy the target branch changes**

Push the target feature branch to its existing remote and report the commit hash. Do not modify other company routes, schemas, or data.

- [ ] **Step 5: Record final verification**

Run `git status --short`, confirm only scoped changes exist, and report exact test/build/deployment results.
