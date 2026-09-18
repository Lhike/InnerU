# Flutter Awards Data-Driven Design

## Goal

Bring the Flutter Abundance Awards experience into parity with the Expo
Awards feature while keeping the Flutter app independent of the Expo API.
Awards must be driven by one typed achievement result shared by the Awards
page and the Home achievement shelf. The UI must not own the achievement
catalog or unlock rules.

## Current gap

The Expo app receives a 15-item achievement DTO catalog containing key, name,
description, tier, artwork, metric, target, progress, and unlock timestamp.
It derives unlocked, in-progress, locked, recent, grouped, hint, and percent
states from that catalog.

The Flutter app currently stores the award labels in the Awards screen and
returns only a set of unlocked keys from `AbundanceAchievementsGateway`. Its
local evaluator does not cover every Expo criterion, so Home and Awards can
show an incomplete or inconsistent catalog.

## Design

### Achievement domain

Create typed Flutter achievement definitions and records in the achievement
service layer. Definitions own the 15 canonical keys, names, descriptions,
tiers, artwork keys, metric, and target. Records add current progress,
unlocked state/timestamp, and derived percentage.

The evaluator consumes the existing mission and goal data available to the
Flutter app. It maps that data to the same canonical metrics used by Expo:
mission streak, goal completion by realm, total completed goals, Life Power,
daily mission completion, and reflection/check-in progress. Missing metrics
remain locked or at zero progress; they must never be silently treated as
unlocked.

`AbundanceAchievementsGateway` will return the complete typed catalog for a
user, including locked records. The service is the single owner of catalog
and unlock logic.

### Awards screen

Update `AbundanceAchievementsScreen` to consume the typed catalog and render:

- unlocked, in-progress, and locked totals;
- recently unlocked records;
- the Expo-equivalent groups: Discipline, The three realms, Quests, Life
  Power, Daily Quests, Reflection, and More when needed;
- artwork for unlocked records;
- tier, description, criterion hint, progress count, and progress bar for
  locked/in-progress records;
- an explicit unlocked state for earned records.

The screen remains refreshable and keeps its existing loading and retry states.

### Home shelf

The Home shelf receives the same complete catalog result, filters it to
unlocked records, and displays only those records. Its earned count is the
catalog’s unlocked count. The header action and each earned badge open the
Awards page through the existing navigation callback.

### Compatibility

The shell’s existing `achievementsLoaderOverride` test seam will be adapted
to the typed catalog. A small compatibility adapter may accept legacy key sets
only at test boundaries; production code will not reconstruct records from
screen-local constants.

## Error handling

Gateway failures keep the existing Awards retry state. Home can render its
normal dashboard without the shelf contents when achievement loading fails;
it must not invent unlocked records or display locked placeholders as earned.

## Testing

- Unit-test the canonical catalog and every evaluator metric boundary.
- Unit-test derived status, percentage, grouping, hints, and recent ordering.
- Widget-test Awards loading, error/retry, counts, locked progress, and earned
  artwork.
- Widget-test Home displays only unlocked records and routes both the header
  action and an earned badge to Awards.
- Run the affected Flutter tests and static analysis before completion.
