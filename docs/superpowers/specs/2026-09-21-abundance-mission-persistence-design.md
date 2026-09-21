# Abundance Mission Persistence Design

## Goal

Make Everyday Missions continuous across days: a member's selected mission set persists on the server, while each calendar day gets independent completion state.

## Current problem

The A12 mission API stores one `mobile_missions` row per day and already has a legacy copy-forward path, but the Flutter A12 gateway always requests `DateTime.now()` and posts completion changes against today. Selecting tomorrow therefore cannot reliably load tomorrow's rows, and a completion can be sent to the wrong day.

## Design

### 1. Separate active selection from daily state

Add a user-owned `mobile_mission_defaults` table. Each row represents one active mission definition:

- `user_id`
- `name`, `description`
- `category`, `scheduled_time`, `icon`
- `sort_order`
- `is_active` (inactive rows preserve intentional removals and prevent legacy backfill from restoring a mission)
- timestamps

The active rows are the forward-looking mission set. Daily `mobile_missions` rows remain immutable snapshots of that set for a date, except for that day's completion and notes/review state.

Each materialized daily row stores its originating default id in metadata. Completion fields remain on the daily row and are never copied from another day.

### 2. Materialize the requested day

`GET /api/v1/missions?date=YYYY-MM-DD` will materialize the requested date, not only the user's local today. If rows already exist, it returns them unchanged. Otherwise it creates rows from the active defaults with `completed=false`, no `completed_at`, no reward-claim metadata, and an empty daily history.

For existing accounts without defaults, the service backfills defaults from the latest recurring daily set before materializing the requested date. Organization/core mission templates remain supported and are included through the existing server-owned catalog path.

### 3. Mutations update the forward set

- Creating a mission creates the selected day's row and upserts the corresponding active default.
- Deleting a mission deletes only that day's row and removes its active default, so future days no longer receive it; previous days remain unchanged.
- Existing completion endpoint changes only the addressed daily row. It must never mutate the active defaults or another date.
- Existing edit behavior remains scoped to the current UI contract; completion and add/remove persistence are the required behavior for this change.

Future materialization therefore uses the latest active set, while past daily snapshots and their completion history remain intact.

### 4. Flutter date-aware gateway

Change `AbundanceMissionsGateway.load` to accept an optional date and change completion updates to accept the selected day. `A12AbundanceMissionsGateway` sends the selected `date` and `month`, maps the response rows to that date, and sends completion for the selected day. The missions screen loads the selected date before opening its checklist and refreshes after calendar navigation.

The existing InnerU gateway keeps its current behavior through default parameters, so non-A12 users are not changed.

## Error handling

- Materialization is idempotent: concurrent/repeated reads cannot create duplicate rows for the same user/date.
- A failed date load keeps the existing screen error state and does not alter local mission data.
- A failed add/remove/completion mutation rolls back the optimistic UI state where applicable.
- Existing API ownership and future-completion validation remain enforced.

## Compatibility and migration

The new table is additive. Existing `mobile_missions` rows are not rewritten. The first read after deployment lazily seeds defaults from the latest recurring daily rows when needed. No user completion history is deleted or migrated.

## Verification

Regression tests will cover:

1. A selected mission set appears on the next requested day with all completion flags reset.
2. Removing a mission changes future materialization but leaves the removed day's historical row intact.
3. Adding a mission becomes part of later days.
4. Completing today does not complete tomorrow.
5. Flutter requests the selected date and sends completion to that date.
6. The mission screen loads the selected calendar day before opening its checklist.
