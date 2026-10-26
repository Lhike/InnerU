# Abundance A12 Data Isolation Design

## Goal

Keep InnerU as the account and company-membership system while storing all
Abundance-specific data in the A12 mobile backend/database, exclusively for
users whose verified company code is `ABU15DN`.

## Boundaries

- InnerU remains authoritative for registration, login, email verification,
  passwords, social authentication, user IDs, and company membership.
- The A12 backend remains authoritative for Abundance onboarding, quests,
  action plans, progress, scores, missions, and other Abundance data.
- No Flutter code connects directly to PostgreSQL. Flutter calls HTTPS APIs
  only.
- Existing non-Abundance API calls, screens, navigation, and authentication
  stay unchanged.

## Session bridge

The source A12 API uses `/api/v1` routes and its own `mobile.auth` access and
refresh tokens. InnerU uses a Sanctum bearer token, so the mobile app cannot
reuse the InnerU token against A12 directly.

The InnerU backend exposes an authenticated, Abundance-only session exchange.
It verifies the InnerU session and `ABU15DN`, then makes a signed server-to-
server request to the A12 backend. A12 upserts a technical identity link using
the InnerU user ID (no password is copied) and returns A12 mobile tokens.
Those tokens are held only by the Abundance client/session store.

Both sides reject requests that are not signed with the bridge secret. A12
data endpoints continue to require `mobile.auth`; the exchange is the only way
an InnerU session obtains an A12 session.

## Flutter transport

`GoalsService` gains an injectable API transport. Existing callers continue to
use the InnerU transport by default. The Abundance shell and onboarding pass
an A12 transport, whose base URL defaults to the source app's configured
production URL (`https://a14-api.valenin.com`) and can be overridden with a
build-time define. This keeps the A12 route and token handling scoped to the
Abundance shell.

## Failure handling

- A12 session exchange is retried through the A12 refresh token when an A12
  request returns 401.
- If A12 is unavailable, Abundance screens show their existing error/loading
  states; InnerU account access remains usable.
- Exchange and identity-link operations are idempotent on `inneru_user_id`.

## Verification

- Unit tests cover A12 URL selection and transport authorization/refresh.
- Backend feature tests cover rejecting non-`ABU15DN` exchange requests and
  creating/reusing the identity link.
- Existing InnerU and Abundance widget tests continue to run unchanged.
