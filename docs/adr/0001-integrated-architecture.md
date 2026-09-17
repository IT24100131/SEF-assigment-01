# ADR 0001: Integrated multi-client architecture

- **Status:** Accepted
- **Date:** 2026-09-17
- **Decision owners:** FishLink group

## Context

The assignment requires one coherent system with ASP.NET Core, PostgreSQL,
React, Flutter and an Agentic AI workflow. The web and mobile clients must
share identity, authorization, data and business rules. The AI subsystem must
not be exposed directly to either client.

## Decision

Use ASP.NET Core Web API as the single public application boundary. Use EF Core
with the PostgreSQL provider for persistence, JWT bearer authentication for
the shared identity model, and role-based authorization in controllers. React
and Flutter call the API over HTTPS. A private Python agent is called by the
API through a named `HttpClient`. Agent results are posted back to an
authenticated API workflow, where deterministic validation and admin approval
remain server-side.

Flutter uses a small feature-oriented state boundary (screen state plus
`ApiClient`) and platform secure storage. It uses camera and GPS only to
collect catch evidence; the API remains the source of truth.

## Alternatives considered

1. **Separate APIs per client — rejected.** This duplicates permissions and
   makes cross-platform data consistency difficult to demonstrate.
2. **Direct Flutter/React calls to the Python service — rejected.** It violates
   the mandatory backend boundary and exposes internal agent capabilities.
3. **Client-managed passwords or tokens — rejected.** Identity and token
   verification must be controlled by the API.
4. **In-memory-only persistence — rejected.** PostgreSQL and relational
   constraints are required for the assessed system.

## Consequences

The API must handle validation, authorization, error mapping and observability.
Clients need loading and error states and must send the same DTO contract.
Deployment is slightly more involved because the API, database and internal
agent must be configured together, but the resulting workflow is testable and
auditable.

## Verification

- `FishLink.API.Tests` covers service business rules and controller status codes.
- Flutter tests cover login validation; manual device verification covers
  camera and GPS permissions.
- Swagger, `/health`, API logs and the agent workflow provide integration
  evidence for the final demonstration.
