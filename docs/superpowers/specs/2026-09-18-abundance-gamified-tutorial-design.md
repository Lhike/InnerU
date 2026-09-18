# Abundance 12 Gamified Tutorial

## Goal

Port the guided tutorial behavior and UI from
`abundance-inneru-tracker-mobile` into the Flutter Abundance shell so the
InnerU app has the same cross-page, spotlight-based gamified tour rather than
the current three-page tutorial.

The feature remains scoped to the Abundance company shell. Other InnerU
companies and their navigation/tutorial behavior must not change.

## Reference behavior

The tutorial follows the reference repository's model:

- A role-aware ordered step list for members and coaches.
- Named live targets on Home, Missions, Quests, Awards, Guild, and Profile.
- Automatic navigation to the route containing the active target.
- Automatic scrolling until the target is visible.
- A dimmed overlay with a gold spotlight around the target.
- A bottom or top explanatory sheet chosen to avoid covering the target.
- Progress bar, step count, Back, Next, Skip, and Finish actions.
- First-run launch and replay from the account/profile menu.
- Completion and replay persistence through the tutorial API, with local
  persistence as a safe offline fallback.

## Architecture

### Tutorial model

Create typed Flutter equivalents of the reference `TourStep` model:

- eyebrow
- title
- description
- optional target key
- target tab/route
- optional role restriction

The step catalog will contain the same member, shared, and coach-specific
content and ordering as the reference app. The controller will derive the
catalog from the current Abundance role.

### Tutorial controller and target registry

Add an Abundance-scoped controller/provider that owns:

- active/inactive state
- current step index
- registered target rectangles
- registered scroll controllers and viewport measurements
- route/tab navigation callback
- completion/replay state
- in-flight/error state for persistence

Expose a target wrapper widget. Each wrapper registers its rendered bounds
when the tour is active and unregisters on disposal. The wrapper must preserve
the child widget's existing layout and behavior.

### Shell integration

The Abundance shell remains the owner of tab navigation. The tutorial
controller receives a callback into the shell for Home, Missions, Quests,
Awards, Guild, Profile, and coach destinations. The existing first-run and
Replay tutorial entry points will start the controller instead of pushing the
old pager.

When the active step changes route, the shell switches tabs first. After the
target tab is built, the controller waits for layout, measures the target,
scrolls its registered scroll view if needed, and then displays the spotlight.

### Overlay layout

The overlay is rendered above the shell using a stack. Four shaded regions
around the target create the spotlight without altering the target widget.
For steps without a target, the full screen is shaded.

The explanatory sheet chooses the top or bottom safe-area position based on
the target's available space. It uses Abundance typography and theme tokens,
including light-mode support already scoped to the Abundance shell.

### Persistence

Add typed tutorial API methods for completion and replay using the same A12
transport/auth path used by the existing profile and council services. The
controller marks the tour complete only after the request succeeds. If the
backend is unavailable, the existing per-user `SharedPreferences` key is used
so the user can still finish the tour offline.

Replay clears the completed state through the backend when supported, starts
the tour at step one, and falls back to the existing local flow when offline.

## Target placement

Add target wrappers to the equivalent visible sections:

- Home overview, daily missions, and goal score sections.
- Quests overview, Life Power, category filters, and quest list.
- Missions overview and mission board.
- Guild overview, controls, rank, and leaderboard.
- Awards overview, tally, and awards wall.
- Profile character card, progression, council, and settings.

Coach-only steps will target the existing coach student and coach quest
surfaces. If a role-specific surface is unavailable, its step is omitted from
the catalog rather than pointing at a missing rectangle.

## Error and lifecycle behavior

- Missing targets show the overlay without a spotlight and retry measurement
  after the next frame; they must not crash or block navigation.
- Failed completion displays an inline error and keeps the tour active so the
  user can retry.
- Disposing or leaving the shell removes registered targets and cancels stale
  measurement callbacks.
- Back/Next never leaves the valid step range.
- Skip uses the same completion persistence path as Finish, matching the
  reference behavior.

## Testing

Add tests for:

- role-specific step catalogs and ordering
- target registration/removal
- route matching and automatic tab navigation
- scroll offset calculation and target visibility
- top/bottom sheet placement
- overlay action behavior, including Skip and Finish
- backend completion/replay requests and offline fallback
- Abundance shell first-run and replay entry points
- target wrappers on each member page without changing existing page actions

Run the existing Abundance analyzer and member-page/widget test suites in
addition to the new focused tutorial tests.
