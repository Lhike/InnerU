# Abundance Company Experience — Design

**Date:** 2026-09-15
**Status:** Approved by user

## Objective

Complete the Abundance-specific mobile experience inside the existing Flutter
`InnerU` application, using the sibling
`abundance-inneru-tracker-mobile` Expo application as the visual and
functional reference.

The customization applies only after InnerU authenticates a user and resolves
that user's registered or active company as Abundance. InnerU's existing login,
sign-up, company-code validation, session behavior, and every non-Abundance
experience remain unchanged.

## Confirmed product flow

1. A user signs up or logs in through the existing InnerU authentication UI.
2. Registration continues to validate and save company codes through the
   existing implementation.
3. After authentication, InnerU loads the user's active company through its
   existing company-membership and company-theme services.
4. The app uses the existing centralized predicate:

   ```dart
   AbundanceCompany.matches(companyCode, companyName)
   ```

   This predicate accepts a normalized company code of `ABU15DN` or a
   normalized company name of `ABUNDANCE`.
5. A matching member receives the parallel Abundance application shell and
   Abundance screens. A non-matching or company-less user continues into the
   existing InnerU shell without any visual or behavioral change.

The login and sign-up screens will not be reskinned. Pre-authentication UI is
deliberately company-neutral because the user has not yet been authenticated
and the authoritative registered company is not yet available.

## Existing implementation

InnerU already contains a partial Abundance integration:

- `AbundanceCompany.matches()` is the central company gate.
- `CompanyLoadingGate` resolves a signed-in user's company before building the
  authenticated shell.
- `Setuppage` and `CoachSetuppage` select `AbundanceShellScreen` for matching
  members and preserve the standard shell for everyone else.
- `lib/src/features/abundance/` contains domain/scoring code, a dashboard,
  Goals/Quests screens, a coach quest roster, a shell, visual tokens, and
  asset helpers.
- `assets/images/abundance/` contains a small initial set of rank and scene
  artwork.
- Unit and widget tests already cover company matching, gating sites, theme
  behavior, assets, scoring, goals, and the partial shell.

This work completes and refines that parallel feature area. It does not replace
the working Goals implementation or introduce a second company predicate.

## Reference experience inventory

The reference application's signed-in experience consists of:

- **Home:** fantasy scene hero, greeting, rank crest, level, Life Power ring,
  today's missions, goal cards with progress logging, achievement shelf,
  motivational copy, loading/error/empty states, XP feedback, and level-up
  celebration.
- **Everyday Missions:** daily and monthly calendar navigation, completion
  toggles, XP/reward feedback, category and icon treatment, mission creation,
  scheduled-time support, and a mission editor presented as a modal.
- **Quests:** realm filters, scene cards, Life Power/progress presentation,
  create/edit wizard, numeric and milestone goals, action plans, progress
  logging, status selection, history, comments, and guarded deletion.
- **Achievements:** grouped locked/unlocked catalog, branded achievement art,
  progress state, and navigation from the dashboard.
- **Guild:** member leaderboard, councils, council membership and invitations,
  member summaries, ranks, goal scores, and coach/member distinctions.
- **Profile / Character Sheet:** avatar editing, character selection, rank and
  progression, profile details, achievements, council choice, appearance,
  password/account controls, tutorial replay, and sign-out.
- **Notifications:** branded notification list with loading, error, and empty
  states.
- **Shell:** role-aware primary destinations, overflow menu, profile/header
  actions, responsive bottom navigation, animated selection indicator, safe
  area handling, and preserved tab state.
- **Coach tools:** councils, students, core tasks, quest roster/reports, coach
  directory, and appropriate read/write actions provided by the user's role.
- **First-run guidance:** conditional Abundance onboarding/tutorial content and
  replay behavior after authentication.

The public marketing pages and the reference application's separate admin
authentication are not ported. InnerU remains the sole authentication entry
point, as confirmed by the user.

## Architecture

### Parallel company feature

Abundance code remains under `lib/src/features/abundance/`, organized into
small responsibilities:

```text
abundance/
  domain/        company gate, scoring, ranks, presentation rules
  services/      adapters over existing InnerU services and APIs
  theme/         colors, typography, assets, shapes, motion values
  widgets/       reusable Abundance-only UI primitives
  screens/
    member/      home, missions, achievements, guild, profile, notifications
    mentee/      existing quests and goal flows
    coach/       coach-specific Abundance screens
  shell/         role-aware navigation and overflow behavior
```

Existing paths may remain where moving them would add risk; the intended
boundary is more important than a mechanical directory migration.

Shared InnerU components may be reused unchanged. If a shared service or route
needs a small extension, that extension must be data-oriented or explicitly
guarded by `AbundanceCompany.matches()`. Abundance styling must not be inserted
as an unguarded global default.

### Post-authentication routing

`CompanyLoadingGate` remains responsible for loading the authoritative company
identity. The resolved `CompanyThemeData` is passed into the normal or
Abundance shell; child screens do not independently guess a company from email,
device state, or branding cache.

The active-company selection flow remains authoritative for multi-company
users. Switching away from Abundance rebuilds the normal InnerU shell;
switching to Abundance builds the Abundance shell. A stale cached theme may be
used only as an offline last-known-good value for the same authenticated user,
following the current `CompanyThemeService` behavior.

### Role behavior

- A regular Abundance member receives the complete Abundance member shell.
- An Abundance coach receives the same member destinations plus applicable
  coach tools in the overflow/navigation structure.
- Existing InnerU administrator routing and authentication remain unchanged.
  Abundance company styling must not globally replace the admin console.
- Users from all other companies and users without a company remain on their
  current role-specific InnerU routes.

## Screen mapping and implementation strategy

| Reference screen | InnerU implementation |
| --- | --- |
| Home | Rebuild/complete `AbundanceMenteeDashboardScreen` using existing goal, daily-tracker, emotion, coach, profile, and point data. |
| Everyday Missions | Add an Abundance-only mission screen over InnerU's existing daily tracker/todo task functionality; keep writes in existing services. |
| Quests | Preserve and refine the existing `GoalsHubScreen`, `GoalFormScreen`, and `GoalDetailScreen`; close behavioral and visual gaps against the reference. |
| Achievements | Add an Abundance catalog/progress screen and dashboard shelf, deriving state from available InnerU progress data or an isolated API extension when existing data is insufficient. |
| Guild | Compose existing company leaderboard, coach-group/council, directory, and membership APIs into an Abundance-only Guild screen. |
| Profile / Character | Add an Abundance presentation around existing profile/account operations; store only new Abundance character preferences that have no InnerU equivalent. |
| Notifications | Present `NotificationApiService` data in an Abundance-only screen and link it from the shell. |
| Coach tools | Keep the existing quest roster and conditionally compose current coach dashboard, roster, group, and reporting capabilities with Abundance presentation. |
| Tutorial | Add an Abundance-only guided first-run/replay layer without changing the default InnerU onboarding flow. |

No feature will duplicate authentication, company membership, profile upload,
goal persistence, daily tracking, leaderboard, notification, or coach data
logic when an InnerU service already provides it.

## Navigation and state

The Abundance shell will mirror the reference's member destinations while
remaining practical on narrow devices:

- Primary destinations: Home, Missions, Quests, Achievements, Guild, and
  Profile.
- An overflow/More surface exposes Notifications, tutorial replay, appearance,
  sign-out, and coach tools when applicable.
- If six primary destinations do not fit accessibly on a device, the shell
  uses a five-item bottom bar and moves the remaining destinations into More;
  routing semantics and labels remain stable.
- Tab bodies are lazily constructed and retained so scroll positions and
  in-progress forms survive tab switches.
- Nested detail screens use the root Navigator consistently and return to the
  originating Abundance destination without exposing the standard shell.
- Notification and profile actions must be functional rather than decorative.

## Visual system

The default Abundance appearance follows the reference dark fantasy theme:

- Background `#080C1C`, raised surface `#0D1330`, sunken surface `#060916`.
- Border `#1C2650`, foreground/parchment `#F2ECD8`, muted `#9FA8C9`.
- Gold `#EAB73F`, cyan `#58C8FF`, success `#5EE6A8`, warning `#EAB73F`,
  danger `#F0607A`.
- Realm accents: Personal `#5EE6A8`, Professional `#A98BFF`, Contribution
  `#58C8FF`.
- Display typography follows the reference's Cinzel character; body typography
  follows Inter or the closest bundled, license-compatible Flutter font.
- Controls use the reference's compact radii, gold outlines, scene scrims,
  progress rings/bars, uppercase tracking, responsive spacing, and minimum
  accessible touch targets.

Typography assets will be bundled only for Abundance screens and registered in
`pubspec.yaml`; the global default font remains unchanged.

## Assets

Only assets actually used by the implemented mobile screens will be copied
from `abundance-inneru-tracker-mobile/assets/web/public/` into namespaced
directories below `assets/images/abundance/` (for example `brand/`, `scenes/`,
`characters/`, `ranks/`, and `achievements/`).

The implementation will reuse the existing rank and quest scene files when
identical. Large duplicate PNG/WebP variants, unused coach photos, public-site
video, and web-only SVG placeholders will not be copied. Raster assets will
retain appropriate resolution and be optimized only through a repeatable,
lossless or visually verified process.

No global launcher icon, splash image, login background, or default InnerU
asset is replaced.

## Interactions and motion

The Abundance implementation will include the reference interactions where the
corresponding data operation exists:

- optimistic mission completion with rollback and visible errors;
- progress and XP feedback;
- level-up and achievement celebration overlays;
- animated/floating navigation selection;
- modal or bottom-sheet editors for mission, progress, status, deletion, and
  More/profile actions;
- refresh/retry controls for network-backed lists;
- progress rings, bars, calendar selection, filter chips, and collapsible or
  horizontally scrollable mobile sections;
- accessible semantics, focus order, reduced-motion-safe behavior, and no
  gesture-only required action.

Animations must not delay persistence or make a failed write appear
successful.

## Data and API rules

- Existing InnerU Laravel/API and service abstractions are the source of truth.
- Every company-scoped read and write continues to use the active membership
  already resolved for the authenticated user.
- New API fields or endpoints are allowed only when a reference feature cannot
  be represented by existing InnerU data. Such additions must be additive and
  tested for company scoping and authorization.
- Existing goal data and APIs are reused; the already-shipped Abundance Goals
  feature is not forked into a second schema.
- Presentation adapters convert current InnerU models into Abundance view
  models so UI code does not depend on unrelated screen widgets.
- Mutations invalidate or refresh every affected Abundance view while leaving
  normal InnerU cache/state behavior unchanged.

## Loading, empty, offline, and error behavior

- Company identity is resolved before selecting a shell. While unresolved, a
  neutral loading gate is shown; the app must not briefly flash Abundance UI
  for an unknown or non-Abundance account.
- A failed fresh company lookup may use the current user's persisted
  last-known-good company, matching existing behavior. It must never use a
  different user's company cache.
- Each data-backed Abundance page has explicit loading, empty, error, and retry
  states matching the reference tone.
- Failed writes remain visibly failed and restore optimistic UI state.
- Authorization failures do not fall through into Abundance content; direct
  route attempts show a guarded denial/back action or redirect to the normal
  authenticated destination.

## Testing and safety verification

Implementation follows test-driven development. Tests are added before each
behavioral change.

### Company isolation

- `ABU15DN` matches regardless of surrounding whitespace or letter case.
- Company name `Abundance` matches according to the existing approved rule.
- Similar codes and names do not match.
- A matching member receives the Abundance shell and routes.
- A non-matching company receives the existing InnerU shell and unchanged
  pages.
- A company-less/default user receives the existing InnerU shell.
- Multi-company switching rebuilds the correct shell without stale Abundance
  chrome.

### Feature behavior

- Navigation exposes only role-appropriate destinations and retains tab state.
- Mission, quest, achievement, guild, profile, notification, and coach actions
  call the established services with the current user/company context.
- Loading, empty, retry, optimistic rollback, modal dismissal, and navigation
  return behavior are covered by widget/unit tests.
- Asset mapping tests ensure every declared Abundance asset exists and no
  global asset path is replaced.

### Regression suite

- Run focused Abundance unit/widget tests during each task.
- Run existing company-theme, membership, authentication, login, sign-up,
  default-navigation, and shell tests.
- Run the complete Flutter test suite and `flutter analyze`.
- Run affected Laravel tests when an API extension is required.
- Perform manual device-size checks for an Abundance member, a different
  company member, and a default user.

## Delivery sequence

The implementation is delivered as independently testable slices within one
cohesive company experience:

1. Shared Abundance typography, assets, widgets, shell, and isolation tests.
2. Home dashboard and Everyday Missions parity.
3. Quests parity audit and corrections without replacing working persistence.
4. Achievements and celebration behavior.
5. Guild/council experience.
6. Profile/Character Sheet, Notifications, More, and tutorial behavior.
7. Coach-only destinations and reference presentation.
8. Full regression, platform layout, and three-scenario safety verification.

Each slice must leave non-Abundance behavior unchanged and pass its focused
tests before the next slice starts.

## Explicit non-goals

- Changing InnerU login or sign-up UI.
- Reimplementing company-code validation.
- Making Abundance the default application theme.
- Replacing global InnerU widgets, assets, routes, or typography.
- Copying the reference public marketing site or separate admin login.
- Replacing existing InnerU backend logic when an adapter is sufficient.
- Redesigning other companies or unrelated default screens.
