# Abundance A12 Source-of-Truth Integration — Design

**Date:** 2026-09-20  
**Status:** Approved for implementation

## Goal

For authenticated InnerU members of company code `ABU15DN`, InnerU is an
Abundance client only. It uses InnerU for authentication and company access,
then resolves one existing `a12_mobile` identity and reads and writes every
Abundance concern through the A12 API. No Abundance screen may silently fall
back to an InnerU table.

## Invariants

- The company gate is exact and centralized: only `ABU15DN` activates this
  integration. Other company shells, APIs, accounts, and data remain unchanged.
- A12 identity resolution is canonical InnerU ID first (`inneru-{id}`), then
  the source application's verified email match. A matching account is linked;
  it is never duplicated or reset.
- A12 owns profile, onboarding, roles, coach/student relationships, goals,
  missions, quest progress, awards, guild, notifications, coaching notes, and
  action items. InnerU owns only its existing login/company validation and the
  short-lived signed A12 session exchange.
- Roles are read from A12 after exchange. The exchange can provision a new
  member or a validated InnerU administrator, but it never replaces an
  existing A12 role set.
- Only an A12 `ADMIN` user can make/remove a Coach role or assign, reassign,
  and remove Student-to-Coach relationships. Coaches have read/write access
  only to their already-assigned students; students cannot select a coach.
- Coaching notes and action items are written through A12's existing
  coach-scoped endpoints. A12 creates the student notification and its
  destination link; InnerU renders and follows that link.
- API failures produce explicit loading/error/retry states. They do not read
  from or write to legacy InnerU Abundance records.

## Request flow

```text
InnerU session + company membership
  -> exact ABU15DN gate
  -> signed server-to-server A12 exchange
  -> resolve canonical A12 user, then verified email
  -> issue short-lived A12 session
  -> A12 /me determines member / coach / admin UI and permissions
  -> all Abundance data requests use that A12 session
```

## Admin plan

The InnerU Abundance admin surface is an A12-admin client. It lists eligible
users and coaches from `a12_mobile`, lets an admin set/unset the A12 `COACH`
role, and assigns/reassigns/removes a student through the existing A12
`admin/councils` and `admin/councils/assign` operations. The UI never writes
`coach_mentees`, local Abundance goals, or any InnerU Abundance shadow table.
The A12 endpoint enforces the `ADMIN` role independently of UI visibility.

## Deliberate source-policy difference

The source Expo app exposes Coach council creation/invitation actions. The
approved InnerU policy is stricter: admin controls Coach role and all student
assignment. InnerU therefore omits those Coach mutation controls while
retaining the source's data presentation, coach roster, student detail,
progress, note, action-item, report, and notification behavior.

## Verification

- Backend feature tests prove exchange matching, no duplicate A12 user,
  role preservation, Admin-only role/assignment authorization, Coach-only
  assigned-student access, and student notification creation.
- Flutter tests prove no local fallback, A12 route mapping, role-gated
  navigation, readable quest/missions data, calendar interaction, and note /
  action-item submission.
- Static analysis, targeted widget suites, relevant A12 PHPUnit suites, and
  the full InnerU Flutter suite run before deploy.
- Deployment is pushed only after these checks; CI is observed and failures
  are fixed at their root cause.
