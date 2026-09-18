# Abundance 12 Gamified Tutorial Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Flutter Abundance three-page tutorial with the reference repository's role-aware, cross-page, spotlight-based gamified tour.

**Architecture:** Add a pure step catalog and layout/scroll helpers, then add an Abundance-scoped tutorial controller with a target registry and overlay. The shell owns route/tab changes; page sections register named targets; persistence uses A12 tutorial endpoints with the current local preference as offline fallback.

**Tech Stack:** Flutter/Dart, `ChangeNotifier`, `Overlay`/`Stack`, `GlobalKey` measurement, `ScrollController`, `SharedPreferences`, existing `A12ApiTransport`, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-09-18-abundance-gamified-tutorial-design.md`

## Global Constraints

- Scope all tutorial behavior to the Abundance company shell; do not change other InnerU company flows.
- Match the reference step content and ordering for member, shared, and coach roles.
- Preserve existing page layout and interactions by making target wrappers layout-transparent.
- Do not hardcode user progress, council, award, or profile data into the tutorial.
- Keep local completion persistence as an offline fallback when tutorial API calls fail.
- Run focused tests after each task and the complete Abundance analyzer/member suite before completion.

## File Map

- Create `lib/src/features/abundance/tutorial/abundance_tutorial_steps.dart`: typed role-aware step catalog.
- Create `lib/src/features/abundance/tutorial/abundance_tutorial_math.dart`: pure route matching, scroll offset, and sheet placement helpers.
- Create `lib/src/features/abundance/tutorial/abundance_tutorial_controller.dart`: `ChangeNotifier` state, target registry, navigation/measurement lifecycle, completion/replay persistence.
- Create `lib/src/features/abundance/widgets/abundance_tutorial_target.dart`: target wrapper and measurement registration.
- Create `lib/src/features/abundance/widgets/abundance_tutorial_overlay.dart`: spotlight layers and instructional sheet.
- Modify `lib/src/features/abundance/screens/member/abundance_tutorial_screen.dart`: start the controller and render loading/error state instead of the old pager.
- Modify `lib/src/features/abundance/screens/abundance_shell_screen.dart`: host controller/overlay, expose tab navigation and scroll registrations, and start/replay the tour.
- Modify member page files for named target wrappers: Home/dashboard, Missions, Quests, Awards, Guild, and Profile.
- Modify `lib/src/features/abundance/services/abundance_api_transport.dart` or add `abundance_tutorial_service.dart`: typed completion/replay requests with existing auth transport.
- Create focused tests under `test/unit/abundance/` and `test/widget/abundance/` for each pure/controller/widget behavior.

### Task 1: Port the reference step catalog

**Files:**
- Create: `lib/src/features/abundance/tutorial/abundance_tutorial_steps.dart`
- Test: `test/unit/abundance/abundance_tutorial_steps_test.dart`

**Interfaces:**
- Produces `enum AbundanceTutorialRole { member, coach, admin }`.
- Produces immutable `AbundanceTutorialStep` with `eyebrow`, `title`, `description`, nullable `target`, and nullable `route`.
- Produces `List<AbundanceTutorialStep> abundanceTutorialStepsFor(Set<AbundanceTutorialRole> roles)`.

- [ ] **Step 1: Write failing catalog tests.** Verify member steps begin with the welcome step, contain the reference Home/Quests/Missions/Guild steps in order, include shared Awards/Profile steps, and exclude coach steps. Verify coach roles include the two coach steps.
- [ ] **Step 2: Run the focused test and confirm failure.**

  Run: `flutter test --no-pub test/unit/abundance/abundance_tutorial_steps_test.dart`

  Expected: FAIL because the catalog types/functions do not exist.
- [ ] **Step 3: Implement the typed catalog.** Copy the reference text and ordering into immutable Dart constants. Treat no roles as member for compatibility with the reference behavior.
- [ ] **Step 4: Run the focused test and confirm pass.**
- [ ] **Step 5: Commit.** `git add lib/src/features/abundance/tutorial test/unit/abundance/abundance_tutorial_steps_test.dart && git commit -m "feat: add abundance tutorial step catalog"`

### Task 2: Add pure tutorial geometry and route helpers

**Files:**
- Create: `lib/src/features/abundance/tutorial/abundance_tutorial_math.dart`
- Test: `test/unit/abundance/abundance_tutorial_math_test.dart`

**Interfaces:**
- Produces `AbundanceTutorialRect` with `left`, `top`, `width`, and `height`.
- Produces `String? tutorialRouteFor(String? route, String currentRoute)` matching shell tab routes.
- Produces `double? tutorialScrollOffset({required double targetTop, required double targetHeight, required double viewportTop, required double currentOffset, required double viewportHeight})`.
- Produces `AbundanceTutorialSheetPlacement tutorialSheetPlacement({required double? targetTop, required double? targetBottom, required double sheetHeight, required double safeTop, required double safeBottom, required double gap})`.

- [ ] **Step 1: Write failing tests** for route aliases, no-scroll when visible, scroll-up/down calculations, safe bounds, and top/bottom sheet choice.
- [ ] **Step 2: Run focused tests and confirm failure.**
- [ ] **Step 3: Implement pure helpers** with no Flutter widget dependencies beyond simple value types.
- [ ] **Step 4: Run focused tests and confirm pass.**
- [ ] **Step 5: Commit.** `git add lib/src/features/abundance/tutorial/abundance_tutorial_math.dart test/unit/abundance/abundance_tutorial_math_test.dart && git commit -m "feat: add tutorial layout helpers"`

### Task 3: Add tutorial persistence and controller state

**Files:**
- Create: `lib/src/features/abundance/services/abundance_tutorial_service.dart`
- Create: `lib/src/features/abundance/tutorial/abundance_tutorial_controller.dart`
- Modify: `lib/src/features/abundance/screens/member/abundance_tutorial_screen.dart`
- Test: `test/unit/abundance/abundance_tutorial_service_test.dart`
- Test: `test/unit/abundance/abundance_tutorial_controller_test.dart`

**Interfaces:**
- `AbundanceTutorialService.complete()` calls the A12 tutorial completion endpoint.
- `AbundanceTutorialService.replay()` calls the A12 tutorial replay endpoint.
- `AbundanceTutorialController` exposes `active`, `stepIndex`, `step`, `steps`, `targetRects`, `error`, `start()`, `next()`, `back()`, `skip()`, `finish()`, `registerTarget()`, `unregisterTarget()`, and `setCurrentRoute()`.
- Controller constructor accepts `uid`, role set, optional tutorial service, optional local preference store adapter, and navigation callback so tests do not require a live backend.

- [ ] **Step 1: Write failing service tests** asserting exact completion/replay paths and request bodies using a recording transport.
- [ ] **Step 2: Run tests and confirm failure.**
- [ ] **Step 3: Implement typed service methods** through `A12ApiTransport`, retaining the existing auth behavior.
- [ ] **Step 4: Write failing controller tests** for initial state, bounds-safe next/back, target registration, successful completion, failed API fallback, and error retention when both API and local persistence fail.
- [ ] **Step 5: Implement controller state and persistence.** On completion or skip, try the backend first, then local per-user storage; do not dismiss the tour if both fail. Replay resets to step zero and starts active.
- [ ] **Step 6: Replace the pager screen** with a minimal controller start/loading surface that returns to the shell after completion.
- [ ] **Step 7: Run focused tests and confirm pass.**
- [ ] **Step 8: Commit.** `git add lib/src/features/abundance/services/abundance_tutorial_service.dart lib/src/features/abundance/tutorial/abundance_tutorial_controller.dart lib/src/features/abundance/screens/member/abundance_tutorial_screen.dart test/unit/abundance/abundance_tutorial_*_test.dart && git commit -m "feat: add tutorial controller and persistence"`

### Task 4: Build the spotlight overlay and target wrapper

**Files:**
- Create: `lib/src/features/abundance/widgets/abundance_tutorial_target.dart`
- Create: `lib/src/features/abundance/widgets/abundance_tutorial_overlay.dart`
- Test: `test/widget/abundance/abundance_tutorial_overlay_test.dart`

**Interfaces:**
- `AbundanceTutorialTarget(name, controller, child)` preserves `child` layout and registers measured global bounds while active.
- `AbundanceTutorialOverlay(controller, onNavigate, onFinish)` renders either the full shade or four shade regions around the spotlight, the progress bar, explanatory sheet, close/Skip, Back, Next, and Finish.

- [ ] **Step 1: Write failing widget tests** for full-screen welcome overlay, spotlight bounds, step count/progress, Next/Back, Skip, Finish, and visible error text.
- [ ] **Step 2: Run focused widget tests and confirm failure.**
- [ ] **Step 3: Implement the target wrapper** using `GlobalKey`, `RenderBox.localToGlobal`, post-frame measurement, and unregister on dispose.
- [ ] **Step 4: Implement the overlay** with Abundance theme colors/typography and top/bottom sheet placement from Task 2. Use `IgnorePointer` only for shade/spotlight layers so target controls remain accessible when appropriate, while tutorial action controls remain interactive.
- [ ] **Step 5: Run focused widget tests and confirm pass.**
- [ ] **Step 6: Commit.** `git add lib/src/features/abundance/widgets/abundance_tutorial_* test/widget/abundance/abundance_tutorial_overlay_test.dart && git commit -m "feat: add abundance tutorial spotlight overlay"`

### Task 5: Integrate the controller with the Abundance shell

**Files:**
- Modify: `lib/src/features/abundance/screens/abundance_shell_screen.dart`
- Modify: `lib/src/features/abundance/screens/member/abundance_tutorial_screen.dart`
- Test: `test/widget/abundance/abundance_shell_screen_test.dart`

**Interfaces:**
- Shell owns one tutorial controller for its lifetime and passes it to the overlay and target-bearing tabs.
- Shell navigation callback maps tutorial route keys to tab indices and coach destinations.
- Shell registers the active tab's scroll controller and current route with the controller.

- [ ] **Step 1: Write failing shell tests** for first-run tour startup, route/tab changes when advancing, and replay entry from the profile menu.
- [ ] **Step 2: Run focused shell tests and confirm failure.**
- [ ] **Step 3: Implement shell ownership and overlay stacking.** Replace direct pushes of the old tutorial pager with controller start; preserve non-Abundance route guards and existing tab caching.
- [ ] **Step 4: Implement target-route synchronization.** On step changes, select the requested tab, wait for the frame, measure/scroll registered targets, and update the overlay.
- [ ] **Step 5: Run focused shell tests and confirm pass.**
- [ ] **Step 6: Commit.** `git add lib/src/features/abundance/screens/abundance_shell_screen.dart lib/src/features/abundance/screens/member/abundance_tutorial_screen.dart test/widget/abundance/abundance_shell_screen_test.dart && git commit -m "feat: integrate tutorial with abundance shell"`

### Task 6: Add named targets to all Abundance pages

**Files:**
- Modify: `lib/src/features/abundance/screens/mentee/abundance_mentee_dashboard_screen.dart`
- Modify: `lib/src/features/abundance/screens/member/abundance_missions_screen.dart`
- Modify: `lib/src/features/abundance/screens/mentee/goals_hub_screen.dart`
- Modify: `lib/src/features/abundance/screens/member/abundance_achievements_screen.dart`
- Modify: `lib/src/features/abundance/screens/member/abundance_guild_screen.dart`
- Modify: `lib/src/features/abundance/screens/member/abundance_character_screen.dart`
- Test: existing page widget tests plus `test/widget/abundance/abundance_tutorial_targets_test.dart`

**Interfaces:**
- Each page accepts an optional `AbundanceTutorialController? tutorialController` and wraps only the reference-equivalent sections.
- Target names match the catalog exactly: `home-overview`, `home-missions`, `home-goal`, `quests-overview`, `quests-life-power`, `quests-categories`, `quests-list`, `daily-overview`, `daily-board`, `allies-overview`, `allies-controls`, `allies-board`, `allies-rank`, `achievements-overview`, `achievements-tally`, `achievements-wall`, `profile-character`, `profile-stats`, `profile-council`, `profile-settings`, `coach-mentees`, and `coach-goals`.

- [ ] **Step 1: Write a target-presence widget test** that builds each page with a controller and confirms the named target registers after layout without changing existing labels/actions.
- [ ] **Step 2: Run the focused target test and confirm failure.**
- [ ] **Step 3: Add transparent wrappers** around the existing section widgets; do not duplicate data loading or alter page navigation.
- [ ] **Step 4: Pass the controller from the shell into cached page bodies and coach destinations.**
- [ ] **Step 5: Run target and existing page tests and confirm pass.**
- [ ] **Step 6: Commit.** `git add lib/src/features/abundance/screens lib/src/features/abundance/widgets test/widget/abundance/abundance_tutorial_targets_test.dart && git commit -m "feat: register abundance tutorial targets"`

### Task 7: Full verification and handoff

**Files:**
- Modify only files required by failing verification.

- [ ] **Step 1: Run formatting.** `dart format lib test`
- [ ] **Step 2: Run analyzer.** `flutter analyze`
- [ ] **Step 3: Run focused tutorial tests.** `flutter test --no-pub test/unit/abundance/abundance_tutorial_steps_test.dart test/unit/abundance/abundance_tutorial_math_test.dart test/unit/abundance/abundance_tutorial_service_test.dart test/unit/abundance/abundance_tutorial_controller_test.dart test/widget/abundance/abundance_tutorial_overlay_test.dart test/widget/abundance/abundance_tutorial_targets_test.dart`
- [ ] **Step 4: Run the existing Abundance suites.** `flutter test --no-pub test/unit/abundance test/widget/abundance`
- [ ] **Step 5: Run `git diff --check` and inspect the final diff for unintended company-wide theme/navigation changes.**
- [ ] **Step 6: Commit any verification-only fixes.** `git add <verified files> && git commit -m "test: verify abundance gamified tutorial"`
