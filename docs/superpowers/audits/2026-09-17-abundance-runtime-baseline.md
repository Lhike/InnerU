# Abundance runtime baseline — 2026-09-17

## Runtimes

- Device: iPhone 16e simulator, iOS 26.3 (`EAFD3141-5991-4FAA-AA5E-37FF25E5BF88`).
- Source: `com.abundanceinneru.tracker`, started with `CI=1 npx expo run:ios --device "iPhone 16e"`.
- Target: `com.valenin.inneru`, started with `flutter run -d EAFD3141-5991-4FAA-AA5E-37FF25E5BF88`.
- Both native apps built and launched successfully. The Expo Go attempt was not used for comparison because its missing native `RNGoogleSignin` module produced a false red screen; the native source build is the valid oracle.

## Checks

- Source `npm test -- --run`: passed (58 files, 208 tests).
- Source `npm run typecheck`: passed.
- Target `flutter analyze`: passed with no issues.
- Target focused Abundance widget tests: passed.

## Safe cleanup

The initial build failed with `No space left on device`. After measuring disk usage, only explicit regenerable artifacts were removed: the target `build`, source `ios/Pods` and `ios/build`, and one Xcode DerivedData directory. No source, credentials, database, environment, configuration, or production asset files were removed. Native dependencies were regenerated successfully and the simulator builds completed.

## Captures

- `output/runtime-compare/source-home.png`
- `output/runtime-compare/target-home.png`
- `output/runtime-compare/source-quests.png`
- `output/runtime-compare/source-achievements.png`
- `output/runtime-compare/source-current.png`
- `output/runtime-compare/target-home-final2.png`
- `output/runtime-compare/target-quests-fixed-runtime.png` (captured before the rebuilt target tab was navigated again)

## Confirmed comparison notes

Home header, hero, Life Power, mission card, goal card, and six-item animated shell are present in both apps. The first target comparison exposed an oversized, stats-heavy Quests layout; it was replaced with the source's `QUESTS (GOAL)` hero, left-aligned New Quest action, horizontal Life Power card, source filters, and scene-backed quest cards. The source Achievements wall was also mirrored with the Hall of Records heading, three-count summary, recently-unlocked section, grouped relic grids, and the complete 15-item catalog.
