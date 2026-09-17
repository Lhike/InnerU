# Abundance source screen inventory — 2026-09-17

Source: `abundance-inneru-tracker-mobile`.

## Auth boundary (unchanged)

Register, sign in, email verification, forgot/reset password, and terms are source routes but remain InnerU-owned. Abundance starts only after the existing company relationship resolves to `ABU15DN`.

## Member journey

- Onboarding: welcome identity/declaration, personal quest, professional quest, contribution quest; includes measure dropdown, numeric target, whole-number toggle, action-plan add/remove/check controls, qualities, optional deadline/date picker, direction controls, AI suggestions, validation, back/continue, and persisted completion.
- Home: A12 header/profile menu, ambient hero, rank/Life Power, today's mission/calendar, goals cards/progress, achievements strip, quote, and animated six-item navigation.
- Everyday Missions: month calendar and selected-day mission list; create/edit/delete modal, category/time controls, completion toggle, loading/empty/error/retry/refresh states.
- Quests: `QUESTS (GOAL)` hero and New Quest wizard, horizontal Life Power card, All/realm filters, scene-backed quest cards, empty/error/retry states, goal detail/progress sheet, logging and edit flows.
- Achievements: Hall of Records, unlocked/in-progress/locked counts, recently unlocked, Discipline/Three Realms/Quests/Life Power/Daily Quests/Reflection sections, relic art, locked progress, and scroll wall.
- Guild: council/coach/group experience and member roster states.
- Profile/Character: character selection and persisted profile settings.
- More: notifications, tutorial replay, profile/settings and sign out destinations; appearance controls are scoped to the A12 sheet.
- Notifications, Tutorial, Character, goal detail, and coach/admin routes are nested from the shell and preserve back behavior.

## Data and isolation

Goals, missions, achievements, profile, and company data use the existing InnerU/A12 transport boundary. The shell and all member screens are entered only by `AbundanceCompany.matches`, whose authoritative check is the normalized company code `ABU15DN`; other-company and no-company routes continue through the existing InnerU setup navigation.

## Visual source tokens

Source uses the dark navy theme, Cinzel display headings, Inter body copy, gold/cyan realm accents, raised/sunken surfaces, rounded cards, scene artwork, and a six-slot bottom bar whose active item lifts into a gold circle. The target's Abundance typography/theme/assets map these tokens without changing shared InnerU theme defaults.
