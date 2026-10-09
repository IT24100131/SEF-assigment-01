# ADR 0002: Flutter Mobile State Management & Service Architecture

- **Status:** Accepted
- **Date:** 2026-09-24
- **Decision owners:** FishLink group (Mobile & Full-Stack Leads)

## Context

Assignment 1 (SE3090) requires the implementation of a cross-platform mobile application using Flutter and Dart that consumes the centralized ASP.NET Core Web API. The specification mandates a justified state-management strategy (Section 8 & 14.2), secure token storage, responsive screen states (loading, empty, success, error), role-based operational workflows (Fisherman and Buyer), device sensor integration (Camera/Image Picker and GPS Geolocation), and deterministic offline fallback handling.

The mobile app must support fast bidirectional workflows:
1. Fisherman catch management: Creating drafts, pier weight verification, quality grade declarations, AI price recommendations, and instant auction publishing.
2. Real-time bidding and buyer matching.
3. Order lifecycle state progression (Confirmed -> Scheduled -> Picked Up -> In Transit -> Delivered).

## Decision

Adopt a **Feature-Oriented State Boundary Architecture** combining:
1. **`StatefulWidget` with localized immutable state mutations (`setState`)**: Keeps operational screen lifecycles localized, predictable, and memory-efficient on resource-constrained mobile hardware.
2. **Dedicated Singleton Service Layer (`ApiClient`)**: Encapsulates all HTTP REST communications, JSON serialization/deserialization, query string encoding, global bearer token attachment, and deterministic error message unwrapping.
3. **Hardware-Backed Secure Storage (`FlutterSecureStorage`)**: Persists JWT authentication tokens and role claims into Android Keystore / iOS Keychain, ensuring role-based routing guards without unencrypted credential storage.
4. **Hardware-Native Device Plugins (`geolocator` & `image_picker`)**: Provides seamless pier GPS location geotagging and catch photo verification with client-side preview controls.
5. **Deterministic Offline Fallbacks**: Provides resilient fallback data models so critical operational screens remain testable and demonstrable even if the local network encounters intermittent latency.

## Alternatives Considered

1. **BLoC (Business Logic Component) / Cubit — rejected:**
   While powerful for large enterprise teams, BLoC introduces significant boilerplate (events, states, transformers) that would disproportionately inflate the codebase for this single-semester integrated project without providing practical performance advantages over direct reactive controller services.
2. **Riverpod / Provider — rejected:**
   Global providers create scattered dependency graphs across widgets. The team chose an explicit `ApiClient` service boundary paired with localized widget state to ensure full traceability and unambiguous code ownership during final viva defense.
3. **Direct SQLite Local Persistence — rejected:**
   PostgreSQL connected through ASP.NET Core is the authoritative single source of truth for all business entities (catches, bids, orders, validations) as required by Section 10. Persisting relational entities locally on mobile would violate the shared cross-platform data consistency requirement.

## Consequences

- **Positive:**
  - Fast rendering and minimal CPU/memory overhead.
  - Zero third-party state boilerplate; easily explainable, debuggable, and testable during viva.
  - Full adherence to the mandatory backend boundary rule: Flutter never communicates directly with internal Python AI microservices, only through authenticated ASP.NET Core endpoints.
  - Clean separation between screen presentation, device sensors, and API communication.
- **Negative:**
  - Deep cross-widget state propagation must be handled via callbacks (`onSaved`, `onSignedIn`) or route returns rather than global dispatchers, which is well-managed within the app's clean navigation shell.

## Verification

- **Automated Widget & Unit Tests (`flutter test`)**: Verified with 5/5 passing automated tests covering Login required field validations, Register role picker, New Catch form constraints (quantity and asking price), MyCatches filter chips, and API base URL resolution.
- **Static Analysis (`flutter analyze`)**: 100% clean compilation across all Dart source files with zero errors.
- **Live Device Demonstration**: Verified on Android emulator with GPS pier location tagging, camera image selection, AI price prediction modal triggering, and live auction publishing.
