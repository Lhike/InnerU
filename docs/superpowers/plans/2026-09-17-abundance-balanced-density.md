# Abundance Balanced Density Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every ABU15DN A12 page feel balanced and readable by reducing oversized typography, padding, gaps, and artwork while preserving source behavior and company isolation.

**Architecture:** Update the A12-only typography, card, button, and status primitives first. Then remove the largest page-local overrides in the active shell pages and modals; no global InnerU theme tokens are changed. Verification covers focused A12 tests, the complete suite, analyzer output, and an iOS release build.

**Tech Stack:** Flutter/Dart, Material widgets, existing A12 theme primitives, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-09-17-abundance-density-design.md`

## Global Constraints

- Changes apply only inside `lib/src/features/abundance` and the ABU15DN shell.
- Preserve A12 colors, copy, ordering, navigation, gestures, and data behavior.
- Keep touch targets at least 44px high.
- Do not modify InnerU login/signup or non-Abundance company presentation.

---

### Task 1: Compact shared A12 tokens and primitives

**Files:**
- Modify: `lib/src/features/abundance/theme/abundance_typography.dart`
- Modify: `lib/src/features/abundance/widgets/abundance_button.dart`
- Modify: `lib/src/features/abundance/widgets/abundance_card.dart`
- Modify: `lib/src/features/abundance/widgets/abundance_status_view.dart`
- Test: `test/widget/abundance/abundance_member_pages_test.dart`

**Interfaces:**
- Produces compact `AbundanceTypography.display/title/body/eyebrow` values used by all A12 pages.
- Keeps `AbundanceButton` and `AbundanceCard` public constructors unchanged.

- [ ] **Step 1: Add/adjust token assertions in the existing A12 widget coverage** so rendered A12 buttons remain touch-safe and use the shared styles.
- [ ] **Step 2: Run the focused tests** with `flutter test --no-pub test/widget/abundance/abundance_member_pages_test.dart --reporter compact`; expect the new assertions to fail before implementation if needed.
- [ ] **Step 3: Change only A12 token values** to display 28px, title 18px, body 14px, eyebrow 10px; use 44px minimum button height, 14px button text, 16px card radius, and 16px status padding.
- [ ] **Step 4: Run the focused tests again** and confirm they pass.
- [ ] **Step 5: Commit** with `git add lib/src/features/abundance/theme lib/src/features/abundance/widgets test/widget/abundance/abundance_member_pages_test.dart && git commit -m "style: compact A12 shared density tokens"`.

### Task 2: Normalize active member pages and modal spacing

**Files:**
- Modify: `lib/src/features/abundance/screens/member/abundance_missions_screen.dart`
- Modify: `lib/src/features/abundance/screens/member/abundance_achievements_screen.dart`
- Modify: `lib/src/features/abundance/screens/member/abundance_guild_screen.dart`
- Modify: `lib/src/features/abundance/screens/member/abundance_more_sheet.dart`
- Modify: `lib/src/features/abundance/widgets/abundance_header_profile_button.dart`
- Test: `test/widget/abundance/abundance_guild_screen_test.dart`

**Interfaces:**
- Preserves all existing screen constructors and interaction callbacks.
- Keeps guild council states, filters, profile overlay actions, and modal semantics unchanged.

- [ ] **Step 1: Identify page-local values above the compact contract** (29–32px headings, 20–24px padding, 20–28px gaps, oversized achievement tiles) and capture focused widget expectations before changing them.
- [ ] **Step 2: Replace the outliers** with 14–16px card padding, 12–14px gaps, 26–28px page headings, and proportionally smaller achievement artwork/tile heights.
- [ ] **Step 3: Keep the source top bar dimensions and reduce only overlay/menu interior density** so labels remain visible without the menu dominating the screen.
- [ ] **Step 4: Run `flutter test --no-pub test/widget/abundance/abundance_guild_screen_test.dart test/widget/abundance/abundance_header_profile_button_test.dart --reporter compact` and fix any layout/semantics regressions.
- [ ] **Step 5: Commit** with `git add lib/src/features/abundance/screens/member lib/src/features/abundance/widgets/abundance_header_profile_button.dart test/widget/abundance && git commit -m "style: balance A12 member page density"`.

### Task 3: Normalize Home, Quests, goal detail, and coach A12 surfaces

**Files:**
- Modify: `lib/src/features/abundance/screens/mentee/abundance_mentee_dashboard_screen.dart`
- Modify: `lib/src/features/abundance/screens/mentee/goals_hub_screen.dart`
- Modify: `lib/src/features/abundance/screens/mentee/goal_detail_screen.dart`
- Modify: `lib/src/features/abundance/screens/coach/abundance_coach_home_screen.dart`
- Modify: `lib/src/features/abundance/screens/coach/coach_quests_roster_screen.dart`
- Test: `test/widget/abundance/goals_hub_screen_test.dart`

**Interfaces:**
- Preserves goal creation, action-plan editing, status changes, score updates, coach roster actions, and navigation callbacks.

- [ ] **Step 1: Audit active Home/Quests/goal-detail local sizes** and list only values that exceed the shared A12 density contract.
- [ ] **Step 2: Reduce page headings, card padding, nested card padding, and repeated vertical gaps** without changing field validation or async callbacks.
- [ ] **Step 3: Reduce large score/hero numerals only where they dominate compact phone viewports; preserve score emphasis and colors.
- [ ] **Step 4: Run `flutter test --no-pub test/widget/abundance/goals_hub_screen_test.dart test/widget/abundance/goal_detail_sheet_test.dart --reporter compact` and verify action-plan and status interactions still pass.
- [ ] **Step 5: Commit** with `git add lib/src/features/abundance/screens/mentee lib/src/features/abundance/screens/coach test/widget/abundance && git commit -m "style: balance A12 home quest and coach surfaces"`.

### Task 4: Normalize shell chrome and verify company isolation

**Files:**
- Modify: `lib/src/features/abundance/screens/abundance_shell_screen.dart`
- Modify: `lib/src/features/abundance/screens/member/abundance_character_screen.dart`
- Test: `test/widget/abundance/abundance_shell_screen_test.dart`
- Test: `test/widget/setup_navbar_test.dart`

**Interfaces:**
- Keeps ABU15DN gating, sign-out-to-LoginScreen, six-tab navigation, and non-Abundance setup behavior unchanged.

- [ ] **Step 1: Reduce only shell/profile page-local outliers** such as oversized profile sections and menu controls; keep header and bottom-nav touch targets intact.
- [ ] **Step 2: Run shell and setup navigation tests** and confirm A12 chrome appears only for ABU15DN.
- [ ] **Step 3: Commit** with `git add lib/src/features/abundance/screens/abundance_shell_screen.dart lib/src/features/abundance/screens/member/abundance_character_screen.dart test/widget/abundance/abundance_shell_screen_test.dart test/widget/setup_navbar_test.dart && git commit -m "style: balance A12 shell and profile density"`.

### Task 5: Full verification

- [ ] **Step 1:** Run `flutter test --no-pub --reporter compact`; expected: all tests pass.
- [ ] **Step 2:** Run `flutter analyze --no-pub`; expected: only the existing unrelated analyzer infos/warnings remain.
- [ ] **Step 3:** Run `git diff --check`; expected: no output.
- [ ] **Step 4:** Run `flutter build ios --no-codesign`; expected: release `Runner.app` succeeds.
- [ ] **Step 5:** Review `git diff --stat` and confirm modifications are limited to A12 density work plus the committed plan/spec.
