# Abundance A12 balanced density design

## Scope

Reduce visual heaviness in the Abundance Company (`ABU15DN`) experience while
preserving the source app's content, hierarchy, colors, navigation, and
behavior. No shared InnerU defaults or non-Abundance company screens change.

## Visual contract

- A12 display headings use a compact 26–28px range; section titles use 18px;
  body copy uses 14px; eyebrow labels use 10px with the existing letter spacing.
- A12 cards use 14–16px internal padding, a 16px radius, and 12–14px vertical
  spacing. Nested cards must not add redundant large padding.
- Buttons and inputs remain touch-safe at 44–48px high, with 14px labels and
  appropriately smaller icons.
- Artwork and achievement tiles are reduced only where they dominate the
  viewport; their source ordering, labels, and tap behavior remain unchanged.
- The A12 header and bottom navigation retain their source proportions and are
  adjusted only when a page-specific outlier causes imbalance.

## Implementation

Centralize the compact values in A12 typography and button/card primitives,
then remove page-local oversized overrides in Home, Missions, Quests, Awards,
Guild, Profile, and A12 modals. Keep all changes in `lib/src/features/abundance`
and verify that company gating remains unchanged.

## Verification

Run the focused A12 widget tests, the complete Flutter test suite, `flutter
analyze --no-pub`, `git diff --check`, and an iOS release build with code
signing disabled. Existing unrelated analyzer infos/warnings are reported but
do not block the pass.
