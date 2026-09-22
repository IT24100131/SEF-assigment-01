# FishLink AI - Four-member work allocation

This allocation follows the SE3090 rule that each student owns one primary
business component while contributing across ASP.NET Core, PostgreSQL, React,
Flutter, testing, Git and Agentic AI. Replace `Student 1`-`Student 4` with the
actual names and registration numbers before submission.

## Allocation summary

| Member | Primary component | Main business outcome | Distinct AI responsibility |
|---|---|---|---|
| Student 1 | Catch registration and quality/fraud | A fisherman creates a catch and receives quality/fraud validation | Quality Validation Agent |
| Student 2 | Marketplace, pricing and buyer matching | Buyers discover catches and receive ranked matches/prices | Market Intelligence Agent |
| Student 3 | Bids, orders and logistics delivery | A selected catch becomes a planned, trackable delivery | Logistics Scheduling Agent |
| Student 4 | Identity, administration and workflow governance | Roles, approval, workflow history and safe orchestration | Planning/Approval Orchestrator |

No member is a project-manager-only, testing-only or documentation-only
member. Documentation and testing are evidence produced for each member's own
component.

## Student 1 - Catch registration and quality/fraud

### Backend and database

- Own `CatchesController`, `CatchService`, catch DTOs and `Catch` validation.
- Define catch lifecycle rules: Draft, Published, PendingApproval and
  Cancelled.
- Maintain EF migration/index/constraint changes related to catch data.
- Add tests for create, update, ownership, publish and validation results.

### React

- Own the fisherman catch form, validation, photo/location display and catch
  status view.
- Demonstrate loading, API error and successful submission states.

### Flutter

- Own the mobile catch registration screen, quantity/price validation, camera
  evidence and GPS location capture.
- Demonstrate the same catch created in Flutter and displayed in React.

### Agentic AI

- Own the Quality Validation Agent contract and deterministic thresholds:
  weight discrepancy, inspection, quality grade, price anomaly, seller history
  and transaction checks.
- Demonstrate a low-risk result and a high-risk result that pauses for admin
  approval.

### Evidence

- API/DTO code links, migration link, React/Flutter screenshots, xUnit tests,
  AI validation output and one debugging/viva change.

## Student 2 - Marketplace, pricing and buyer matching

### Backend and database

- Own `BuyerMatchController`, market statistics and buyer preference queries.
- Maintain `BuyerPreference`, `Bid` read/query relationships and relevant
  database indexes.
- Add validation for species, quantity, maximum price and location preference.

### React

- Own the buyer dashboard, market listing filters, sorting, price trends and
  ranked buyer recommendations.
- Include empty, loading and API failure states.

### Flutter

- Add a mobile market view showing safety/market context and a buyer-facing
  listing or preference flow.
- Verify that the mobile view reads the shared API rather than local sample
  data.

### Agentic AI

- Own the Market Intelligence Agent and Buyer Matching Agent.
- Document the recommendation input/output contract, scoring weights and
  fallback behavior when the price service is unavailable.

### Evidence

- Controller/service/query links, preference migration, React/Flutter
  screenshots, matching tests, price fallback test and recommendation
  explanation.

## Student 3 - Bids, orders and logistics delivery

### Backend and database

- Own `BidsController`, `LogisticsController`, order/delivery models and
  delivery-plan migrations.
- Enforce bid ownership, valid bid states and authorized logistics operations.
- Add tests for bid creation, acceptance, delivery-plan validation and
  unavailable-resource errors.

### React

- Own buyer bidding/order screens and logistics dashboard.
- Show vehicle, driver, cold storage, route, weather risk, ETA and delivery
  status.

### Flutter

- Add a mobile order/status view or delivery tracking screen using the shared
  API.
- Include clear network loading and retry/error states.

### Agentic AI

- Own the Logistics Scheduling Agent and its six allow-listed tools:
  vehicles, drivers, cold storage, route, weather and ETA calculation.
- Demonstrate a successful plan and a safe partial/failure plan.

### Evidence

- Bid/order API links, relationship/migration evidence, dashboard/mobile
  screenshots, logistics tests, tool execution summary and approval result.

## Student 4 - Identity, administration and workflow governance

### Backend and database

- Own `AuthController`, `UsersController`, role policies, JWT configuration,
  `AgentGatewayController`, workflow state and admin approval endpoints.
- Review global exception handling, audit logging, health checks and secure
  configuration.
- Add tests for login, duplicate registration, role authorization, approval
  and safe agent-unavailable behavior.

### React

- Own login/register, protected routing, admin fraud-review screens and
  workflow execution-history summaries.
- Demonstrate Fisherman, Buyer, Admin and Logistics access differences.

### Flutter

- Own mobile login, secure token storage, sign-out and protected navigation.
- Verify that the app uses the API token and does not store passwords.

### Agentic AI

- Own the Planning Agent/orchestration contract, workflow state transitions,
  admin approval gate and execution-history audit summary.
- Ensure React and Flutter call the ASP.NET gateway and never call the Python
  agent directly.

### Evidence

- JWT/role policy links, auth/admin tests, protected-route screenshots, agent
  state history, CI run and security/configuration explanation.

## Shared responsibilities

Every member must:

1. Create issues and pull requests for their component.
2. Contribute code to all four required technology areas where their feature
   crosses the stack.
3. Write and run tests for their own behavior.
4. Keep an individual AI usage log and write an individual reflection.
5. Add screenshots and links for their own demonstration evidence.
6. Be able to explain and modify one controller, service, database relation,
   React screen, Flutter screen, test and AI decision in the viva.

## Suggested nine-week sequence

| Week | All members |
|---|---|
| 1 | Confirm domain, components, API contracts, ADR and Git branches |
| 2 | Complete database entities, migrations, DTOs and endpoint skeletons |
| 3 | Implement primary backend services and authorization |
| 4 | Implement React screens and API integration |
| 5 | Implement Flutter screens, secure storage and device features |
| 6 | Implement distinct AI agent responsibilities and gateway integration |
| 7 | Add unit, integration, AI evaluation and performance tests |
| 8 | Deploy, generate APK, collect screenshots and verify CI |
| 9 | Complete reports, AI logs, demo rehearsal and viva preparation |
