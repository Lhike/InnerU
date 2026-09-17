# Abundance Runtime Replication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Run the React Native source and Flutter target, compare the complete Abundance Company journey, and close verified UI/UX/behavior gaps without changing other InnerU experiences.

**Architecture:** Treat `abundance-inneru-tracker-mobile` as the behavioral and visual oracle. Use the existing company gate (`ABU15DN`) to scope every target change to Abundance, retain InnerU authentication, and reuse the existing A12 API/data boundary rather than introducing a second auth or company system.

**Tech Stack:** Expo/React Native source, Flutter target, Dart widget tests, TypeScript/Vitest source tests, Laravel A12 mobile API, iOS simulator.

**Spec:** User request in the active conversation (runtime comparison and complete Abundance replication).

## Global Constraints

- Only company code `ABU15DN` may receive the Abundance experience.
- Other-company and no-company InnerU routes, onboarding, authentication, and data must remain unchanged.
- `abundance-inneru-tracker-mobile` is the source of truth for screens, copy, assets, navigation, interactions, and state.
- Do not delete source, user data, credentials, database files, production assets, or unclear-purpose files during cleanup.
- Verify each implementation change with focused tests before claiming completion.

---

### Task 1: Establish reproducible runtime baselines

**Files:**
- Read: `abundance-inneru-tracker-mobile/package.json`, `abundance-inneru-tracker-mobile/app.json`
- Read: `InnerU/.worktrees/abundance-company-experience/pubspec.yaml`
- Create: `docs/superpowers/audits/2026-09-17-abundance-runtime-baseline.md`

- [x] **Step 1: Run source static checks and tests**

Run `npm test -- --run` and `npm run typecheck` in the source app; record exit codes and failures.

- [x] **Step 2: Run target focused checks**

Run `flutter analyze` and `flutter test --no-pub test/widget/abundance`; record exit codes and test counts.

- [x] **Step 3: Start both apps on the available iOS simulator**

Start the source with `npx expo start --ios` (or `npx expo run:ios` if a native build is required) and the target with `flutter run -d EAFD3141-5991-4FAA-AA5E-37FF25E5BF88`; capture launch errors and screenshots when the environment permits.

- [x] **Step 4: If storage blocks either run, measure first and perform only scoped cleanup**

Use `df -h`, inspect project `.dart_tool`, `build`, `ios/Pods`, Expo/Metro temp output, and Xcode DerivedData sizes; remove only regenerable artifacts with explicit paths, then rerun the launch commands.

- [x] **Step 5: Record the baseline**

Write the exact commands, devices, source/target launch state, blockers, and screenshot paths to `docs/superpowers/audits/2026-09-17-abundance-runtime-baseline.md`.

### Task 2: Build a source-of-truth screen and interaction inventory

**Files:**
- Read: `abundance-inneru-tracker-mobile/app/**/*.tsx`
- Read: `abundance-inneru-tracker-mobile/src/features/**/*.tsx`
- Read: `abundance-inneru-tracker-mobile/src/features/**/*.ts`
- Create: `docs/superpowers/audits/2026-09-17-abundance-screen-inventory.md`

- [x] **Step 1: Trace entry and company-independent auth boundaries**

Document register, verify-email, sign-in, reset-password, and post-auth routing, explicitly marking these as read-only integration boundaries.

- [x] **Step 2: Trace member screens and navigation**

Inventory onboarding, Home, Missions, Quests, Achievements, Guild, Profile, Notifications, More, Tutorial, Character, public pages, goal detail/progress, and every modal/sheet reachable from them.

- [x] **Step 3: Trace role-specific coach/admin routes**

Inventory coach tools, student detail/report, council invitations, leaderboard, and admin routes, including visibility predicates and back behavior.

- [x] **Step 4: Trace data and interaction contracts**

For each screen, record API endpoint, query/mutation, loading/empty/error/success state, gesture, animation, button label, icon, asset, and persistence behavior.

- [x] **Step 5: Record source measurements**

Extract the source theme tokens, font families, dimensions, tab labels/icons, animation durations, and modal sizing from the implementation and runtime screenshots.

### Task 3: Compare company gate and post-auth routing

**Files:**
- Read/modify only if needed: `lib/src/services/default_landing_screen.dart`
- Read/modify only if needed: `lib/src/features/abundance/screens/abundance_post_auth_gate.dart`
- Test: `test/unit/default_landing_screen_test.dart`, `test/widget/abundance/abundance_post_auth_gate_test.dart`

- [x] **Step 1: Write or extend routing tests for three identities**

Cover `ABU15DN`, another company code, and no company; assert only the first enters Abundance.

- [x] **Step 2: Run the routing tests and confirm any failure**

Run the two focused test files before changing routing.

- [x] **Step 3: Fix only the failing company-gate boundary**

Preserve the existing login/register screens and default landing routes; do not move shared auth UI into the Abundance module.

- [x] **Step 4: Re-run routing tests and source route tests**

Confirm all three identities and existing auth behavior remain intact.

### Task 4: Compare and close member UI/behavior gaps

**Files:**
- Modify only Abundance-scoped files under `lib/src/features/abundance/`
- Test: matching files under `test/widget/abundance/` and `test/unit/`

- [x] **Step 1: Compare onboarding screen-by-screen**

Match source welcome and three quest steps, fields, validation, dropdowns, date picker, direction controls, action plans, AI suggestions, scroll/footer behavior, completion persistence, assets, and transitions.

- [x] **Step 2: Compare Home and goal flows**

Match dashboard card order, data-driven daily/weekly targets, goal progress sheet, goal detail page, log/edit behavior, loading/error states, and modal gestures.

- [x] **Step 3: Compare Missions and nested modals**

Match calendar, today mission modal, check-in/write behavior, completion feedback, empty/error states, and navigation history.

- [x] **Step 4: Compare Achievements, Guild, Profile, Notifications, More, Tutorial, and Character**

Match all visible content, icons, assets, appearance persistence, profile actions, tutorial replay, notification actions, role-specific destinations, and back behavior.

- [x] **Step 5: Implement one verified difference at a time**

For each difference, add a focused failing widget/unit test, make the smallest Abundance-only change, then rerun that test before moving to the next difference.

### Task 5: Match shell navigation, animations, and responsive layout

**Files:**
- Modify only `lib/src/features/abundance/screens/abundance_shell_screen.dart` and Abundance widgets/theme
- Test: `test/widget/abundance/abundance_shell_screen_test.dart`

- [x] **Step 1: Compare tab count, labels, icons, selected states, and destinations**

Use source `MemberTabBar`, `PersistentRootTabBar`, `tab-icons`, and `AnimatedTabItem` as the exact reference.

- [x] **Step 2: Compare indicator and transition timing**

Match active indicator position, spring/curve, press feedback, screen transition, safe-area inset, and keyboard behavior.

- [x] **Step 3: Add narrow-device overflow tests**

Pump the shell at iPhone-sized constraints and assert no overflow, duplicate AppBars, or missing bottom navigation.

- [x] **Step 4: Fix and rerun shell tests**

Keep the compatibility semantics required by existing InnerU automation while rendering source-equivalent Abundance chrome.

### Task 6: Data/API parity and isolation validation

**Files:**
- Modify only Abundance transport/service/domain files when a verified source contract is missing
- Test: `test/unit/` and `test/widget/abundance/`
- Read: `abundance-inneru-tracker-mobile/backend/app/Services/MobileGoalService.php`, `MobileDashboardService.php`, API route definitions

- [x] **Step 1: Compare every target endpoint and response field**

Verify goal targets, missions, achievements, guild, notifications, profile, onboarding state, and AI suggestions against source request/response contracts.

- [x] **Step 2: Add contract tests for dynamic fields and failures**

Assert server-calculated values are not hardcoded, authentication errors are visible and retryable, and no Abundance payload is requested for non-Abundance identities.

- [x] **Step 3: Fix transport translation at the boundary**

Preserve source field names/semantics at the Abundance service boundary and keep legacy Firestore fallback behavior only where it is explicitly required.

- [x] **Step 4: Run data-isolation tests**

Verify an alternate company and no-company user cannot read or mutate Abundance data through direct route construction or shared services.

### Task 7: Repeat runtime comparison and final verification

**Files:**
- Update: `docs/superpowers/audits/2026-09-17-abundance-runtime-comparison.md`

- [x] **Step 1: Relaunch source and target without stale hot-reload state**

Use hot restart first; use a full rebuild only if native assets or generated code changed and storage permits.

- [x] **Step 2: Walk the same source/target journey**

Run ABU15DN onboarding, existing ABU15DN login, another-company login, and no-company entry; compare every inventoried screen and interaction.

- [x] **Step 3: Capture remaining differences and resolve them**

For every remaining discrepancy, either fix it with a focused test or record an environment/backend blocker with evidence.

- [x] **Step 4: Run the complete validation set**

Run source `npm test -- --run` and `npm run typecheck`; target `flutter analyze`; target `flutter test --no-pub test/widget/abundance`; target routing/unit tests; and `git diff --check`.

- [x] **Step 5: Report evidence and explicit limitations**

State which apps actually ran, device used, screen coverage, test counts, storage cleanup performed (if any), and any backend/device limitation that prevents an exact claim.
