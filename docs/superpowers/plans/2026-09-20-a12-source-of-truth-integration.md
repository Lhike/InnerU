# Plan: A12 source-of-truth Abundance integration

> **Spec:** `docs/superpowers/specs/2026-09-20-a12-source-of-truth-design.md`

## Goal

Make InnerU's `ABU15DN` experience a secure A12 client for member, Coach, and
Admin workflows without changing other companies.

## Global constraints

- Do not modify InnerU login, registration, or non-Abundance navigation.
- Do not persist or mutate Abundance domain data in InnerU.
- Never create an A12 identity before checking canonical identity then email.
- Keep A12 authorization authoritative; UI gating is supplementary only.
- Follow a RED → GREEN test cycle for every behavior change.
- Preserve user work and do not perform destructive repository operations.

## Task 1 — Make A12 identity exchange preserve source roles

**Repositories:** `abundance-inneru-tracker-mobile/backend`, InnerU backend

1. Add A12 feature coverage proving a canonical/email existing account is
   linked rather than duplicated and its `ADMIN`/`COACH` role remains intact.
2. Extend the signed exchange payload to permit a verified InnerU Admin intent
   and merge it safely; ordinary exchanges provision only a new MENTEE and
   never downgrade source roles.
3. Change the InnerU signed-session controller to send an Admin intent only
   for its existing authorized admin account condition; preserve current
   company checks.
4. Run A12 exchange feature tests and InnerU backend tests.

**Expected:** Existing users retain A12 roles/data; a non-Abundance account
cannot exchange; admin exchange receives A12 Admin capability only through
server-side validation.

## Task 2 — Expose and test Admin-controlled A12 relationship operations

**Repository:** `abundance-inneru-tracker-mobile/backend`

1. Add feature tests for A12 Admin-only coach-role and student assignment
   operations, including rejection for Coach and Mentee sessions.
2. Make the admin users/councils API return the stable fields required by
   InnerU: identity, display name, email, role set, active state, council,
   and assigned coach.
3. Ensure coach invitation/candidate write operations remain unavailable to
   the InnerU Coach client path; assignment remains the Admin API route.
4. Run the focused Admin and coach relationship feature suites.

**Expected:** Admin can promote/demote Coach and assign/reassign/remove a
student; a Coach cannot alter membership; the relationship lives in A12 only.

## Task 3 — Remove InnerU fallback from Abundance transport

**Repository:** InnerU

1. Add Dart tests that an A12 session calls A12 paths for council/guild,
   coach roster/student detail, quests/goals, mission calendar, notes and
   action items, and reports; a failed A12 request must not call an InnerU
   fallback.
2. Refactor `A12ApiTransport` and related services to use only its bearer
   session after `ABU15DN` exchange, with typed failure and retry state.
3. Replace default InnerU `GoalsService` injections inside the Abundance
   shell with the A12 transport, while leaving ordinary shells intact.
4. Run transport/service unit tests and `flutter analyze`.

**Expected:** An A12 outage is visible, not hidden behind stale InnerU data.

## Task 4 — Complete A12-backed Coach and Student detail behavior

**Repository:** InnerU

1. Add widget/service tests for A12 role-based coach navigation, roster,
   student quest cards with categories/progress bars/detail navigation, and
   calendar day selection displaying that student's finished missions.
2. Implement the source-aligned Coach student presentation using A12 data:
   quest list, progress, mission calendar, progress bars, details, notes,
   action items, and loading/empty/error states.
3. Route coaching note/action submission through A12 and make notification
   links open the targeted note; do not call InnerU coaching controllers.
4. Run focused Coach widgets and related full widget tests.

**Expected:** only assigned students are visible; data reflects the A12 user,
and notes/actions notify the intended student.

## Task 5 — Build the A12-backed Abundance admin client

**Repository:** InnerU

1. Add Dart tests for the A12 admin service path/payload mapping and role
   gating for users, roles, councils and student assignment.
2. Implement the Abundance Admin surface: select a user, make/remove Coach,
   select a student and Coach, assign/reassign/remove; reflect A12 responses.
3. Link the surface only from existing authorized Abundance Admin routes.
   Do not touch ordinary InnerU company administration.
4. Run focused widget/service tests and analysis.

**Expected:** Admin controls Coach status and relationships in A12; no local
InnerU Abundance assignment record is used.

## Task 6 — Regression, full QA, deployment, and CI monitoring

**Repositories:** both

1. Verify source/target mappings and assets, then run A12 PHP tests, InnerU
   backend tests, targeted Flutter tests, `flutter analyze`, and full Flutter
   tests.
2. Review all changes for company isolation, authorization, identity
   duplication, asset regressions, and forbidden local fallbacks.
3. Commit each repository separately, push the requested deploy branches,
   observe CI, inspect failures, and use systematic debugging to fix any
   failure before considering deployment complete.

**Expected:** clean targeted checks plus documented full-suite/CI result; no
unverified claim that a remote deployment succeeded.

## Shared interfaces pre-flight

- Task 1 produces a role-preserving A12 session consumed by Tasks 3–5.
- Task 2 produces stable Admin relationship payloads consumed by Task 5.
- Task 3 produces A12-only transport consumed by Task 4 and Task 5.
- Task 4 consumes the A12 notes/action-notification contract from source
  routes; no local InnerU write path is permitted.

## Review focus

- Identity matching must not merge distinct email/canonical users.
- Role merging must not grant Admin based on a client-controlled flag.
- Non-ABU15DN accounts must not obtain an A12 session.
- Every Abundance request must use A12; inspect for hidden fallback writes.
- Coach roster/detail queries must remain ownership-scoped server-side.
- Admin role/assignment actions need both UI and backend authorization.
- Calendar and quest views must render real A12 records, not placeholders.
