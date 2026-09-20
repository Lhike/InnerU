# Abundance Mission Persistence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist each member's selected Everyday Missions as a server-owned forward-looking set while keeping completion state independent for every calendar day.

**Architecture:** A12 will add one user-scoped `mobile_mission_defaults` row per active mission and materialize date-specific `mobile_missions` snapshots from those definitions. The Flutter A12 gateway and screen will pass the selected calendar date through every load and completion operation; legacy InnerU storage keeps its current optional-date behavior.

**Tech Stack:** Laravel 12/PHP, PostgreSQL-compatible migrations, Eloquent, Flutter/Dart, PHPUnit, Flutter widget/unit tests.

**Spec:** `docs/superpowers/specs/2026-09-21-abundance-mission-persistence-design.md`

## Global Constraints

- Active mission selection and daily completion state must remain separate.
- Existing `mobile_missions` completion history must not be deleted or rewritten.
- A daily snapshot always starts with `completed=false`, `completed_at=null`, and no copied reward/history metadata.
- API ownership remains user-scoped; a member cannot read or mutate another member's defaults or missions.
- The A12 API remains the source of truth for Abundance users; do not add an InnerU/Firestore fallback for this flow.

## Review Focus

- A user completes a mission today, then requests tomorrow: tomorrow contains the mission but it is incomplete.
- A user removes a mission today: the historical row remains, while a later requested date excludes it.
- A user adds a mission after the initial setup: later requested dates include the new definition.
- A user requests a date several days ahead before midnight: the API materializes the requested date idempotently without duplicates.
- Flutter loads and completes the selected calendar date rather than silently using device today.

---

### Task 1: Add the server-owned active mission set and requested-date materialization

**Files:**
- Create: `../abundance-inneru-tracker-mobile/backend/database/migrations/2026_09_21_000001_create_mobile_mission_defaults_table.php` (includes an `is_active` tombstone for removals)
- Create: `../abundance-inneru-tracker-mobile/backend/app/Models/MobileMissionDefault.php`
- Modify: `../abundance-inneru-tracker-mobile/backend/app/Models/User.php`
- Modify: `../abundance-inneru-tracker-mobile/backend/app/Models/MobileMission.php`
- Modify: `../abundance-inneru-tracker-mobile/backend/app/Services/MobileDashboardService.php`
- Modify: `../abundance-inneru-tracker-mobile/backend/app/Http/Controllers/Api/MobileDomainController.php`
- Test: `../abundance-inneru-tracker-mobile/backend/tests/Feature/MobileDomainFlowTest.php`
- Test: `../abundance-inneru-tracker-mobile/backend/tests/Feature/MissionCompletionTest.php`

**Interfaces:**
- Produces `User::mobileMissionDefaults(): HasMany`.
- Produces `MobileDashboardService::ensureMissionsForDate(User $user, Carbon|string $date): void`.
- `ensureTodayMissions(User $user)` remains as a wrapper for dashboard callers.
- `GET /api/v1/missions?date=YYYY-MM-DD` materializes the requested date before querying it.
- Create/delete mission mutations update the active defaults; completion only updates the addressed daily row.

- [ ] **Step 1: Write the failing feature tests.** Add tests that create a completed mission today, request tomorrow while the test clock is still today, and assert the copied row is present with `completed=false`; add tests that delete today’s row and assert its historical row remains while the next materialized day excludes it; add a test that adding a mission is present on a later requested day.

```php
public function test_requested_future_day_uses_active_missions_with_reset_completion(): void
{
    Carbon::setTestNow(Carbon::parse('2026-09-21 09:00:00', 'UTC'));
    [$member, $token] = $this->authenticatedUser();
    $member->onboarding()->create(['name' => 'Jordan', 'timezone' => 'Asia/Manila', 'completed_at' => now()]);

    $created = $this->withMobileToken($token)->postJson('/api/v1/missions', [
        'name' => 'Meditation', 'category' => 'MEDITATION', 'date' => '2026-09-21',
    ])->assertCreated()->json('taskId');
    $this->withMobileToken($token)->postJson("/api/v1/missions/$created/completion", ['completed' => true])->assertOk();

    $this->withMobileToken($token)->getJson('/api/v1/missions?date=2026-09-22&month=2026-09')
        ->assertOk()->assertJsonCount(1, 'items')->assertJsonPath('items.0.name', 'Meditation')
        ->assertJsonPath('items.0.completed', false);
}
```

- [ ] **Step 2: Run the focused tests to verify RED.**

Run: `MOBILE_SELF_CONTAINED=true php artisan test --filter='requested_future_day|removes|adding_a_mission'` from `abundance-inneru-tracker-mobile/backend`.

Expected: the requested-future-day test fails because the endpoint only ensures the local current day; deletion/propagation tests fail if the new default ownership is absent.

- [ ] **Step 3: Add the migration/model/relation.** Create `mobile_mission_defaults` with a foreign key to `users`, mission definition fields, and `(user_id, sort_order)` indexing. Add the model casts/fillable fields and `User::mobileMissionDefaults()`. Keep daily row metadata as the compatibility link to its default id.

- [ ] **Step 4: Implement idempotent materialization.** Refactor `MobileDashboardService` so `ensureMissionsForDate` first returns when the requested date already has rows, lazily seeds defaults from the latest recurring daily snapshot for legacy users, then creates fresh daily rows from defaults with reset completion/history metadata. Keep organization/core templates as the initial source when no user defaults exist, and make `ensureTodayMissions` call the new method with `localToday()`.

- [ ] **Step 5: Wire create/delete/requested-date behavior.** Make `missions()` parse the requested date before materialization. Make `createMission()` create the active default and daily snapshot together. Make `deleteMission()` remove only the addressed daily row and its linked active default. Leave `completeMission()` scoped to the daily row and preserve existing future-date and ownership validation.

- [ ] **Step 6: Run the focused backend suite to verify GREEN.**

Run: `MOBILE_SELF_CONTAINED=true php artisan test --filter='MobileDomainFlowTest|MissionCompletionTest'`.

Expected: all focused mission tests pass, including the new carry-forward, remove, add, and day-specific completion assertions.

- [ ] **Step 7: Commit the backend change.**

```bash
git add backend/database/migrations/2026_09_21_000001_create_mobile_mission_defaults_table.php backend/app/Models/MobileMissionDefault.php backend/app/Models/User.php backend/app/Models/MobileMission.php backend/app/Services/MobileDashboardService.php backend/app/Http/Controllers/Api/MobileDomainController.php backend/tests/Feature/MobileDomainFlowTest.php backend/tests/Feature/MissionCompletionTest.php
git commit -m "feat: persist active abundance missions"
```

### Task 2: Make the Flutter A12 mission gateway date-aware

**Files:**
- Modify: `lib/src/features/abundance/services/abundance_missions_service.dart`
- Modify: `test/unit/abundance/a12_abundance_missions_gateway_test.dart`
- Modify: `test/widget/abundance/abundance_daily_mission_setup_test.dart`
- Modify: `test/widget/abundance/abundance_member_pages_test.dart`

**Interfaces:**
- `AbundanceMissionsGateway.load({DateTime? date})` loads the requested day.
- `AbundanceMissionsGateway.update(Task task, {DateTime? day})` updates completion for the requested day.
- Existing non-A12 implementations may ignore the optional date and retain their current storage behavior.

- [ ] **Step 1: Write the failing gateway tests.** Make the fake transport record the requested date and test `load(date: DateTime(2026, 9, 22))` sends `GET /missions?date=2026-09-22&month=2026-09`. Create a task whose completion date is tomorrow and assert `update(task, day: tomorrow)` sends `completed=true` even when device today differs.

```dart
final tasks = await gateway.load(date: DateTime(2026, 9, 22));
expect(transport.requests, contains('GET /missions?date=2026-09-22&month=2026-09'));

await gateway.update(
  Task(/* completionDates contains 2026-09-22 */),
  day: DateTime(2026, 9, 22),
);
expect(transport.requests, contains('POST /missions/mission-7/completion true'));
```

- [ ] **Step 2: Run the focused Dart test to verify RED.**

Run: `flutter test --no-pub test/unit/abundance/a12_abundance_missions_gateway_test.dart`.

Expected: compilation fails because the gateway methods do not yet accept date parameters and the current implementation always uses `DateTime.now()`.

- [ ] **Step 3: Implement date-aware gateway methods.** Use a date-only helper for query and completion payload logic. Parse each A12 item as a snapshot of the requested date, while retaining the returned completion history only for historical display. Keep `create` using the task’s selected start date and `delete` user-scoped through A12.

- [ ] **Step 4: Update test fakes and run the focused Flutter tests.** Update every fake gateway signature, then run:

`flutter test --no-pub test/unit/abundance/a12_abundance_missions_gateway_test.dart test/widget/abundance/abundance_daily_mission_setup_test.dart test/widget/abundance/abundance_member_pages_test.dart`

Expected: all focused tests pass.

- [ ] **Step 5: Commit the gateway change.**

```bash
git add lib/src/features/abundance/services/abundance_missions_service.dart test/unit/abundance/a12_abundance_missions_gateway_test.dart test/widget/abundance/abundance_daily_mission_setup_test.dart test/widget/abundance/abundance_member_pages_test.dart
git commit -m "fix: load abundance missions by selected date"
```

### Task 3: Load the selected calendar day before showing its checklist

**Files:**
- Modify: `lib/src/features/abundance/screens/member/abundance_missions_screen.dart`
- Modify: `test/widget/abundance/abundance_member_pages_test.dart`

**Interfaces:**
- `_load({DateTime? date})` refreshes the gateway for that date.
- Calendar day taps set `_selected`, await `_load(date: _selected)`, then open the day modal.
- Completion calls pass `_selected` to the gateway and keep rollback behavior.

- [ ] **Step 1: Write the failing widget test.** Use a date-aware fake gateway with distinct mission lists for September 21 and September 22. Tap the 22nd and assert the checklist contains the September 22 mission and the fake recorded a load for that date.

```dart
testWidgets('selecting tomorrow loads tomorrow missions before opening the checklist', (tester) async {
  final gateway = _DateAwareMissionsGateway();
  await tester.pumpWidget(MaterialApp(home: AbundanceMissionsScreen(
    gateway: gateway,
    initialDate: DateTime(2026, 9, 21),
    today: DateTime(2026, 9, 22),
  )));
  await tester.pumpAndSettle();
  await tester.tap(find.text('22').last);
  await tester.pumpAndSettle();
  expect(find.text('Tomorrow meditation'), findsOneWidget);
  expect(gateway.loadedDates.last, DateTime(2026, 9, 22));
});
```

- [ ] **Step 2: Run the widget test to verify RED.**

Run: `flutter test --no-pub test/widget/abundance/abundance_member_pages_test.dart --plain-name 'selecting tomorrow loads tomorrow missions before opening the checklist'`.

Expected: the modal opens with the initial day’s task or the date-aware load is never recorded.

- [ ] **Step 3: Implement selected-date loading and completion.** Pass `_selected` into `_gateway.load` from initial/refresh loads, await the date load on calendar selection, and pass `_selected` into `_gateway.update`. Preserve the current error/rollback messages.

- [ ] **Step 4: Run the focused widget suite to verify GREEN.**

Run: `flutter test --no-pub test/widget/abundance/abundance_member_pages_test.dart test/widget/abundance/abundance_daily_mission_setup_test.dart`.

Expected: all mission calendar, setup, completion rollback, and selected-date tests pass with no overflow exceptions.

- [ ] **Step 5: Commit the screen change.**

```bash
git add lib/src/features/abundance/screens/member/abundance_missions_screen.dart test/widget/abundance/abundance_member_pages_test.dart
git commit -m "fix: refresh missions when changing days"
```

### Task 4: Full verification and release build

**Files:**
- No additional source files; verify the commits from Tasks 1–3.

- [ ] **Step 1: Run backend syntax and full tests.**

Run from `abundance-inneru-tracker-mobile/backend`:

```bash
php -l app/Services/MobileDashboardService.php
php -l app/Http/Controllers/Api/MobileDomainController.php
MOBILE_SELF_CONTAINED=true php artisan test
```

Expected: no syntax errors and the full backend suite passes.

- [ ] **Step 2: Run Flutter analysis and the full test suite.**

Run from the Flutter worktree:

```bash
flutter analyze
flutter test --no-pub
```

Expected: analyzer reports no issues and all tests pass.

- [ ] **Step 3: Build and install the iOS simulator app.**

```bash
flutter build ios --simulator --no-codesign -d EAFD3141-5991-4FAA-AA5E-37FF25E5BF88
flutter install -d EAFD3141-5991-4FAA-AA5E-37FF25E5BF88
xcrun simctl launch EAFD3141-5991-4FAA-AA5E-37FF25E5BF88 com.valenin.inneru
```

Expected: the build exits 0, the app installs, and the simulator launches the updated bundle.

- [ ] **Step 4: Review the complete diff and commit/push only the intended files.** Confirm both repositories are clean after their commits, then push the Flutter branch and the A12 backend branch through the configured release path. Do not delete any user data or rewrite historical mission rows.
