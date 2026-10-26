# Abundance A12 Data Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route only verified `ABU15DN` Abundance data to the source A12 API/database while preserving InnerU authentication and all other company experiences.

**Architecture:** InnerU remains the identity plane. An authenticated InnerU backend endpoint exchanges an InnerU session for a signed A12 mobile session; the Flutter Abundance shell injects an A12 transport into `GoalsService`, while default/non-Abundance callers keep the existing InnerU transport.

**Tech Stack:** Flutter/Dart, Laravel/PHP, PostgreSQL, existing Sanctum and A12 mobile-session middleware.

**Spec:** `docs/superpowers/specs/2026-09-17-abundance-a12-data-isolation-design.md`

## Global Constraints

- Only company code `ABU15DN` may obtain an A12 session or access A12 data.
- Do not modify InnerU login, signup, password, email verification, or social-auth behavior.
- Do not put database passwords, bridge secrets, or service keys in Flutter.
- Keep existing `ApiClient` behavior unchanged for non-Abundance callers.

### Task 1: Add scoped transport interfaces and A12 configuration

**Files:**
- Modify: `lib/src/services/api_config.dart`
- Modify: `lib/src/features/abundance/services/goals_service.dart`
- Create: `lib/src/features/abundance/services/abundance_api_transport.dart`
- Test: `test/unit/abundance/abundance_api_transport_test.dart`

- [ ] Write tests for default A12 URL selection and transport method contracts.
- [ ] Run the tests and confirm they fail before implementation.
- [ ] Add an injectable transport adapter for the existing InnerU `ApiClient`.
- [ ] Add A12 base URL configuration with a build-time override.
- [ ] Run unit tests and analyzer.

### Task 2: Add InnerU-to-A12 session exchange

**Files:**
- Modify: `backend/routes/api.php`
- Create: `backend/app/Http/Controllers/Api/AbundanceSessionController.php`
- Create: `backend/app/Services/A12BridgeClient.php`
- Modify: `backend/config/services.php`
- Modify: `backend/.env.example`
- Test: `backend/tests/Feature/AbundanceSessionExchangeTest.php`

- [ ] Add failing feature tests for non-Abundance rejection and signed exchange.
- [ ] Add configuration validation for A12 URL and bridge secret.
- [ ] Add the authenticated `ABU15DN` exchange endpoint.
- [ ] Run the backend feature tests and static checks.

### Task 3: Add A12 bridge endpoint and identity link

**Files:**
- Modify: `backend/routes/api.php` in `abundance-inneru-tracker-mobile/backend`
- Create/modify: A12 bridge controller/service and migration for the InnerU ID link.
- Modify: A12 backend `.env.example`
- Test: A12 backend feature tests.

- [ ] Add failing tests for invalid signatures, non-Abundance identity, and idempotent linking.
- [ ] Implement signed exchange and A12 token issuance without copying passwords.
- [ ] Run A12 backend tests and migrations against the test database.

### Task 4: Implement the Abundance-only Flutter A12 session and transport

**Files:**
- Create: `lib/src/features/abundance/services/a12_session_service.dart`
- Create: `lib/src/features/abundance/services/a12_api_transport.dart`
- Modify: `lib/src/features/abundance/services/goals_service.dart`
- Modify: Abundance shell/onboarding construction sites.
- Test: Flutter A12 session and transport tests.

- [ ] Write failing tests for exchange, refresh-on-401, and request authorization.
- [ ] Implement secure token storage and A12 request handling.
- [ ] Inject this transport only from verified Abundance shell/onboarding paths.
- [ ] Run all Abundance widget tests and analyzer.

### Task 5: End-to-end isolation verification

**Files:**
- Modify/create: company-gate and integration tests only.

- [ ] Verify ABU15DN obtains A12 transport.
- [ ] Verify other-company and no-company users never invoke the A12 exchange.
- [ ] Verify InnerU auth and standard API tests remain green.
- [ ] Run `git diff --check` and document deployment environment variables.
