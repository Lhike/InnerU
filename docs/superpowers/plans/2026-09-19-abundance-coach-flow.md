# Plan: Abundance Coach onboarding and navigation

## Goal

Make the InnerU Abundance experience follow the source app for authenticated Coaches: resolve the Abundance company before applying onboarding, show the shared onboarding/tutorial flow when required, and expose the role-gated Coaching destinations without changing other company or user experiences.

## Source behavior

- The source reads `needsOnboarding`, `tutorialCompleted`, and `roles` from the authenticated `/api/v1/me` bootstrap response.
- `needsOnboarding` routes every role, including `COACH`, through the same four-step onboarding. Completion then routes to the tutorial; completed onboarding/tutorial are not repeated.
- Coaches keep the normal six primary destinations and receive an additional Coaching overflow/profile section: Councils, Students, Core Tasks, Quest List, and Coaches.
- Coach access is based on the authenticated `COACH` role, not a username or a frontend-only flag.

## Target changes

1. Add failing regression coverage for Coach onboarding, company isolation, and role-gated Coaching menu actions.
2. Fix `AbundancePostAuthGate` so Coach sessions resolve company membership and use the existing Abundance onboarding completion service instead of bypassing the gate.
3. Pass the authenticated Coach state into the Abundance profile menu and render the source-aligned Coaching actions only for Coaches.
4. Preserve the normal six-tab shell and existing non-Abundance behavior; keep the existing destination handlers for each Coach action.
5. Add the missing Coaches destination to the existing Coach tools screen where that screen is used.
6. Run focused widget/unit tests and static analysis, then inspect the diff for unrelated changes.

## Constraints

- Scope all changes to Abundance (`ABU15DN`) and existing role/company resolution.
- Do not change login, signup, authentication, password, or social-login flows.
- Do not create duplicate Coach or onboarding data.
- Preserve unrelated working-tree changes.
