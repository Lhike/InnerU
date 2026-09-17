# Abundance runtime comparison — 2026-09-17

Both native apps were launched on the same iPhone 16e simulator (`EAFD3141-5991-4FAA-AA5E-37FF25E5BF88`):

- Source: `com.abundanceinneru.tracker`, built with `CI=1 npx expo run:ios --device "iPhone 16e"`.
- Target: `com.valenin.inneru`, built with `flutter run -d EAFD3141-5991-4FAA-AA5E-37FF25E5BF88 --no-resident`.

The Expo Go launch was also attempted. Its red screen was a host limitation (`RNGoogleSignin` TurboModule is not present in Expo Go), so the source was validated with its native development build instead.

## Captures

Screenshots are under `/Users/arlenedacanay/a-12tracker/output/runtime-compare/`:

- `source-home.png` / `target-home-final2.png`: home shell, hero, goals, achievements, and six-slot navigation.
- `source-quests.png` / `target-quests-final2.png`: Quests heading, Life Power panel, icon filters, scene-backed cards, and progress rings.
- `source-achievements.png`: Hall of Records and relic sections.
- `target-mission-final4.png`: native target Mission tab after the calendar/modal port (A12 header, reset timer, five-week month grid, legend, setup CTA, and animated Mission tab).
- `source-final-native.png` / `target-final-native2.png`: final native simulator launch captures after the latest rebuild.

## Verified parity work

- Quests now uses the source title/copy, left-aligned New Quest action, compact horizontal Life Power panel, realm glyph filters, scene cards, rank medals, and right-side progress rings.
- Achievements now uses the Hall of Records layout, source relic catalog/assets, earned/locked grouping, summary counts, and recently-unlocked section.
- Goal detail targets stay in one row on compact iPhone widths and use server-provided daily/weekly targets when available.
- The member Profile route now follows the source Character Sheet hierarchy while retaining persisted character selection and account-settings navigation.
- Animated Abundance shell navigation remains six items and is only selected by the normalized `ABU15DN` company-code gate.
- Mission now follows the source flow: calendar-first Everyday Missions page, dynamic reset countdown, Monday-first month grid with selected-day progress, source legend/setup CTA, and a dimmed selected-day checklist/create-mission dialog with completion, category, description, and time controls.
- Quest detail now follows the source mobile order (`QUEST SCORE`, `THE QUEST`, `ACTION PLANS`, `PROGRESS HISTORY`), with source-style score ring/value entry, action-plan add/status cycling, and a dimmed `QUEST STATUS` selector. New Quest opens as a centered modal with the four source steps; Edit uses a single centered `EDIT QUEST` form.
- The native Mission calendar was rechecked after removing an unconstrained tile scaler: all five source-style weeks now render their day numbers and progress tracks on the iPhone simulator.
- Coach navigation now matches the source role contract: Coach accounts retain the normal Home and Quests tabs, while Students, Core Tasks, Quest List, Councils, and Coaches are overflow tools. The source member dashboard is no longer replaced by a Coach-tools home.
- The latest regression pass wires the header Appearance picker into the persisted company-theme service, refreshes the cached Home body after Quests writes, forces readable dark styling for Mission-type dropdown labels, and gives action-plan inputs/buttons explicit A12 colors.
- Action-plan status changes now refresh the plan list and derive the parent Quest status (`not started` → `in progress` → `completed`) instead of requiring a second manual Quest-status edit.
- Profile now includes source-style council, progression, earned-badges, and account-control sections. Council presentation is derived from the authenticated user's coach/group assignment; the empty state exposes `Join council` and the assigned state exposes `Change`.

## Remaining environment/data caveat

The simulator accounts do not contain identical backend fixtures, so names, scores, and mission counts differ between the captures. The target Guild route uses the existing A12-aware company leaderboard surface, which was verified against the source's Allies Company/Groups, podium, rank, refresh, scoring-help, and member-detail interactions. A12 API bridge configuration is required in the deployment environment (`ABUNDANCE_A12_API_URL` and `ABUNDANCE_A12_BRIDGE_SECRET`).
The native source build did not expose a seeded Coach credential in this environment, so Coach behavior was traced from the source Coach routes and role-navigation contract; the target now exposes those tools only from the Coach More menu.

## Verification

- Source: 58 Vitest files / 208 tests passed; TypeScript typecheck passed.
- Target: `flutter analyze --no-pub` passed with only existing info-level deprecations/unused helper warnings; native `flutter run` completed and the Mission tab was exercised on the iPhone 16e simulator. The focused shell/Mission/company-gating suite passes (30 tests), including the source calendar/modal flow and add-mission behavior. `flutter build ios --no-codesign` also completed successfully.
- Laravel route check confirms `POST api/abundance/a12/session` is registered.
- `git diff --check` passed.
- Rebuild after the regression fixes produced `build/ios/iphoneos/Runner.app`; the focused Abundance suite still passes all 30 tests.
