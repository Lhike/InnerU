# Flutter Awards Data-Driven Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the Expo Awards catalog and presentation behavior into the Flutter Abundance app using one typed, data-driven achievement result shared by Awards and Home.

**Architecture:** The achievement service owns the canonical 15-award definitions and evaluates complete records from Flutter’s mission, goal, score, and check-in data. The Awards screen consumes those records for totals, groups, progress, hints, and artwork; the Home shelf consumes the same records and filters to unlocked records only.

**Tech Stack:** Flutter/Dart, Flutter widgets and tests, existing `GoalsService`, `AbundanceMissionsGateway`, `UserScore`, local asset catalog.

**Spec:** `docs/superpowers/specs/2026-09-18-flutter-awards-data-driven-design.md`

## Global Constraints

- Keep the Flutter app independent of the Expo API.
- The service layer owns the canonical catalog and unlock logic; screens must not reconstruct it from constants.
- Home displays only unlocked records and uses the same result as Awards.
- Missing metrics remain locked or at zero progress; they must never be treated as unlocked.
- Preserve existing loading, retry, refresh, and shell navigation behavior.

---

### Task 1: Define the canonical Flutter achievement model and catalog

**Files:**
- Modify: `lib/src/features/abundance/services/abundance_achievements_service.dart`
- Test: `test/unit/abundance/abundance_achievements_service_test.dart`

**Interfaces:**
- Produce `AbundanceAchievementDefinition` with `key`, `name`, `description`, `tier`, `assetKey`, `metric`, and `target`.
- Produce `AbundanceAchievementRecord` with a definition, `current`, `unlocked`, and `percent`.
- Produce `abundanceAchievementDefinitions` containing the 15 Expo keys and metadata.
- Change `AbundanceAchievementsGateway.load()` to return `Future<List<AbundanceAchievementRecord>>`.

- [ ] **Step 1: Write failing catalog and record tests.**

  Test that the catalog contains exactly the 15 canonical keys, each key has artwork and a positive target, and an unlocked record reports `percent == 100` while a locked record reports a bounded percentage from current/target.

- [ ] **Step 2: Run the focused tests and verify the expected API/model failure.**

  Run:

  ```bash
  flutter test test/unit/abundance/abundance_achievements_service_test.dart
  ```

  Expected: failure because the typed definitions, records, and gateway return type do not exist yet.

- [ ] **Step 3: Implement the typed definitions and records.**

  Move the Expo catalog metadata into the service file. Use the existing asset keys from `abundanceAchievementAssets`; do not duplicate asset paths in the screen. Define `percent` as `100` when unlocked, otherwise `0` for invalid/non-positive targets and otherwise `((current / target) * 100).round().clamp(0, 100)`.

- [ ] **Step 4: Run the focused tests and verify they pass.**

  Run the same command and expect all catalog/model assertions to pass.

- [ ] **Step 5: Commit the model/catalog change.**

  ```bash
  git add lib/src/features/abundance/services/abundance_achievements_service.dart test/unit/abundance/abundance_achievements_service_test.dart
  git commit -m "feat: add typed Abundance achievement catalog"
  ```

### Task 2: Implement complete progress evaluation and derived presentation data

**Files:**
- Modify: `lib/src/features/abundance/services/abundance_achievements_service.dart`
- Create: `lib/src/features/abundance/services/abundance_achievement_presentation.dart`
- Test: `test/unit/abundance/abundance_achievements_service_test.dart`
- Test: `test/unit/abundance/abundance_achievement_presentation_test.dart`

**Interfaces:**
- `InnerUAbundanceAchievementsGateway.load()` returns all 15 records in catalog order.
- Produce `abundanceAchievementHint(AbundanceAchievementRecord record)`.
- Produce `AbundanceAchievementCatalog` with `unlocked`, `inProgress`, `locked`, `recent`, and grouped sections.

- [ ] **Step 1: Write failing evaluator tests for criteria boundaries.**

  Cover first mission, 7/20/30/50/60-day streak thresholds, personal/professional/contribution completed goals, 1/2/3 completed goals, Life Power 60/80/90, daily mission completion, and check-in progress. Assert that the evaluator unlocks only the matching keys and preserves locked records with current progress.

- [ ] **Step 2: Run the evaluator tests and verify they fail for missing/incomplete criteria.**

  ```bash
  flutter test test/unit/abundance/abundance_achievements_service_test.dart
  ```

- [ ] **Step 3: Implement evaluator metrics from existing Flutter data.**

  Extend the gateway input collection to load missions and goals already available through `AbundanceMissionsGateway` and `GoalsService`; use the existing scoring/check-in data path for Life Power and reflection. Map each metric to the Expo key and create every record from the canonical definitions. Do not infer a missing metric as completed.

- [ ] **Step 4: Write failing presentation tests.**

  Assert unlocked/in-progress/locked counts, recent ordering by unlock state/order, group membership for Discipline, The three realms, Quests, Life Power, Daily Quests, Reflection, and More, plus exact criterion hints for each supported metric.

- [ ] **Step 5: Run presentation tests and verify the expected failures.**

  ```bash
  flutter test test/unit/abundance/abundance_achievement_presentation_test.dart
  ```

- [ ] **Step 6: Implement catalog derivation and hints.**

  Group records by metric, count in-progress records where `current > 0 && !unlocked`, compute locked as the remainder, and keep recent records in canonical evaluation order because the local model has no server timestamp. Return only non-empty sections.

- [ ] **Step 7: Run both focused unit suites and verify they pass.**

  ```bash
  flutter test test/unit/abundance/abundance_achievements_service_test.dart test/unit/abundance/abundance_achievement_presentation_test.dart
  ```

- [ ] **Step 8: Commit the evaluator and presentation change.**

  ```bash
  git add lib/src/features/abundance/services/abundance_achievements_service.dart lib/src/features/abundance/services/abundance_achievement_presentation.dart test/unit/abundance/abundance_achievements_service_test.dart test/unit/abundance/abundance_achievement_presentation_test.dart
  git commit -m "feat: evaluate complete Abundance achievement progress"
  ```

### Task 3: Rebuild the Flutter Awards screen from typed records

**Files:**
- Modify: `lib/src/features/abundance/screens/member/abundance_achievements_screen.dart`
- Modify: `lib/src/features/abundance/screens/abundance_shell_screen.dart`
- Modify: `test/widget/abundance/abundance_member_pages_test.dart`
- Modify: `test/widget/abundance/abundance_shell_screen_test.dart`

**Interfaces:**
- `AbundanceAchievementsScreen` consumes `Future<List<AbundanceAchievementRecord>> Function()` and an optional typed-record test override.
- The shell’s production gateway passes the complete typed catalog; legacy key-set overrides are adapted only in tests.

- [ ] **Step 1: Write failing widget tests for the Expo-equivalent Awards behavior.**

  Supply typed records containing unlocked, in-progress, and locked examples. Assert the three totals, “Recently unlocked,” group headings, artwork for unlocked records, criterion text/progress for locked records, and retry behavior after a loader failure.

- [ ] **Step 2: Run the widget tests and verify they fail against the key-only screen.**

  ```bash
  flutter test test/widget/abundance/abundance_member_pages_test.dart test/widget/abundance/abundance_shell_screen_test.dart
  ```

- [ ] **Step 3: Replace screen-local `_awards` definitions with service records.**

  Render the typed catalog, use the presentation helper for totals/groups/hints, preserve the existing visual language, and use `abundanceAchievementAssets[record.definition.assetKey]` for unlocked art. Keep locked cards visible on Awards, unlike Home.

- [ ] **Step 4: Update shell construction and test seams.**

  Pass the gateway’s typed `load()` result into Awards. Replace production use of `Set<String>` with typed records; keep any key-set adapter private to test setup so production cannot lose progress metadata.

- [ ] **Step 5: Run the affected widget tests and verify they pass.**

  ```bash
  flutter test test/widget/abundance/abundance_member_pages_test.dart test/widget/abundance/abundance_shell_screen_test.dart
  ```

- [ ] **Step 6: Commit the Awards UI change.**

  ```bash
  git add lib/src/features/abundance/screens/member/abundance_achievements_screen.dart lib/src/features/abundance/screens/abundance_shell_screen.dart test/widget/abundance/abundance_member_pages_test.dart test/widget/abundance/abundance_shell_screen_test.dart
  git commit -m "feat: render data-driven Abundance Awards"
  ```

### Task 4: Connect Home to the same typed catalog

**Files:**
- Modify: `lib/src/features/abundance/screens/mentee/abundance_mentee_dashboard_screen.dart`
- Modify: `lib/src/features/abundance/screens/abundance_shell_screen.dart`
- Modify: `test/widget/abundance/abundance_shell_screen_test.dart`

**Interfaces:**
- Home receives the same `List<AbundanceAchievementRecord>` source used by Awards.
- `_A12AchievementShelf` accepts typed records and `onOpenAwards`, filters `record.unlocked`, and invokes the callback from both the earned-count action and each badge.

- [ ] **Step 1: Write failing Home integration tests.**

  Assert that locked records do not render on the shelf, the count equals the typed unlocked count, and tapping an earned badge selects/opens Awards through the shell callback.

- [ ] **Step 2: Run the Home tests and verify they fail against the current screen-local achievement list.**

  ```bash
  flutter test test/widget/abundance/abundance_shell_screen_test.dart
  ```

- [ ] **Step 3: Replace Home’s local `Set<String>`/`_Achievement` construction with the typed gateway result.**

  Pass the typed records through the dashboard load, filter only unlocked records for the shelf, and keep the existing Awards navigation callback for the header and badges.

- [ ] **Step 4: Run the focused Home and Awards tests.**

  ```bash
  flutter test test/widget/abundance/abundance_shell_screen_test.dart test/widget/abundance/abundance_member_pages_test.dart
  ```

- [ ] **Step 5: Commit the Home integration.**

  ```bash
  git add lib/src/features/abundance/screens/mentee/abundance_mentee_dashboard_screen.dart lib/src/features/abundance/screens/abundance_shell_screen.dart test/widget/abundance/abundance_shell_screen_test.dart
  git commit -m "feat: share Awards data with Abundance Home"
  ```

### Task 5: Final verification

**Files:**
- Verify: all changed Flutter files and tests above.

- [ ] **Step 1: Run the complete Flutter test suite.**

  ```bash
  flutter test
  ```

- [ ] **Step 2: Run static analysis.**

  ```bash
  flutter analyze
  ```

- [ ] **Step 3: Inspect the final diff and worktree status.**

  ```bash
  git diff --check
  git status --short
  ```

- [ ] **Step 4: Commit any final test-only adjustments.**

  ```bash
  git add lib test
  git commit -m "test: verify data-driven Abundance Awards flow"
  ```
