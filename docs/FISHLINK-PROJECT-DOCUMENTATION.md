# FishLink AI

## SE3090 Assignment 1 - Integrated Full-Stack and Agentic AI Application

**Project type:** Integrated fish marketplace and logistics platform  
**Required technologies:** ASP.NET Core Web API, PostgreSQL, React, Flutter and Agentic AI  
**Group size:** Four students  
**Document status:** Project documentation and submission guide

> Replace all `[TO COMPLETE]` fields with real group details and evidence.
> URLs, screenshots, test results and contribution claims must be based on
> actual execution and must not be fabricated.

---

## 1. Executive summary

FishLink AI is a digital fish marketplace that connects fishermen, buyers,
administrators and logistics staff through one integrated platform. Fishermen
can register catches from the Flutter mobile app, buyers can discover fish and
place bids through the React dashboard, administrators can review AI-detected
fraud risks, and logistics staff can coordinate delivery.

The system combines:

- ASP.NET Core REST API
- PostgreSQL relational database
- React web dashboard
- Flutter mobile application
- Python Agentic AI subsystem
- AI-assisted quality, pricing, buyer matching and logistics workflows
- JWT authentication and role-based authorization
- Human approval for high-risk decisions

React and Flutter use the same API, database, identity model and business
rules. The Python AI service is internal and is called through ASP.NET Core;
neither client calls the AI service directly.

---

## 2. Problem statement

Traditional fish-market workflows often depend on phone calls, informal
pricing, manual quality claims and disconnected transport arrangements. This
creates several problems:

1. Fishermen have limited visibility of current market prices.
2. Buyers cannot easily compare catches, price and quality.
3. Weight and quality claims are difficult to verify.
4. Suspicious listings may be published without review.
5. Bidding, orders and delivery planning are disconnected.
6. Web and mobile users may see inconsistent information.

FishLink addresses these problems by creating a shared, auditable workflow
from catch registration to market discovery, AI validation, approval and
delivery planning.

---

## 3. Project objectives

### Functional objectives

- Allow users to register and authenticate securely.
- Support Fisherman, Buyer, Admin and Logistics roles.
- Allow fishermen to create and manage catch listings.
- Support fish search, filtering, sorting and pagination.
- Provide market statistics and price recommendations.
- Allow buyers to match preferences against available catches.
- Support bidding and order workflows.
- Provide delivery planning using logistics data and weather.
- Run a controlled Agentic AI workflow.
- Pause high-risk workflows for administrator approval.
- Provide audit-friendly workflow status and summaries.

### Engineering objectives

- Use a layered ASP.NET Core architecture.
- Use EF Core migrations and PostgreSQL persistence.
- Use reusable React components and routing.
- Use Flutter widgets, API integration and device features.
- Protect endpoints with JWT and roles.
- Test controllers, services, clients and AI helpers.
- Use GitHub Actions for build and test automation.
- Document architecture, ownership and AI usage.

---

## 4. System architecture

```text
                         +----------------------+
                         |   React Web Client   |
                         +----------+-----------+
                                    |
                         +----------v-----------+
                         | ASP.NET Core Web API |
                         | Auth, CRUD, Gateway  |
                         +----+------+-----+----+
                              |      |     |
                   +----------v+ +---v---+ +v----------+
                   | PostgreSQL| | AI    | | Price API |
                   | Database  | | Agent | |           |
                   +-----------+ +-------+ +-----------+
                                    ^
                                    |
                         +----------+-----------+
                         | Flutter Mobile App  |
                         +----------------------+
```

### Integration boundary

The ASP.NET Core API is the only public business boundary:

```text
React -> ASP.NET Core API -> PostgreSQL
Flutter -> ASP.NET Core API -> PostgreSQL
ASP.NET Core API -> private Python Agentic AI service
ASP.NET Core API -> private Price API
ASP.NET Core API -> weather provider
```

Clients do not connect directly to PostgreSQL, the Python agent or external
weather services.

The architecture rationale is recorded in
[`0001-integrated-architecture.md`](./adr/0001-integrated-architecture.md).

---

## 5. Repository structure

| Path | Responsibility |
|---|---|
| `FishLink.API/` | ASP.NET Core API, controllers, services, models and migrations |
| `FishLink.API.Tests/` | xUnit controller and service tests |
| `fishlink-dashboard/` | React web application |
| `fishlink_mobile/` | Flutter mobile application |
| `ai_agent/` | Python Agentic AI service |
| `price_api/` | Python historical price and prediction service |
| `docs/` | ADRs, reports, allocation, checklists and evidence |
| `.github/workflows/` | GitHub Actions CI workflow |

Important files:

- [`Program.cs`](../FishLink.API/Program.cs)
- [`CatchesController.cs`](../FishLink.API/Controllers/CatchesController.cs)
- [`AgentGatewayController.cs`](../FishLink.API/Controllers/AgentGatewayController.cs)
- [`CatchService.cs`](../FishLink.API/Services/CatchService.cs)
- [`ApplicationDbContext.cs`](../FishLink.API/Data/ApplicationDbContext.cs)
- [`main.dart`](../fishlink_mobile/lib/main.dart)
- [`App.tsx`](../fishlink-dashboard/src/App.tsx)
- [`ai_agent/main.py`](../ai_agent/main.py)

---

## 6. User roles and permissions

### Fisherman

- Login and register
- Create, edit and delete own draft catches
- Publish or cancel own catches
- Add photo and GPS evidence from Flutter
- Start an AI validation workflow
- View catch status and history

### Buyer

- View available catches
- Search, filter, sort and paginate listings
- View market trends and recommended prices
- Match preferences to catches
- Place bids
- View orders and delivery information

### Admin

- View flagged catches
- Review AI fraud and quality results
- Approve or reject catches
- Review workflow status and execution history
- Monitor internal agent health
- Review logistics plans

### Logistics

- View delivery plans
- View vehicles, drivers and cold storage
- Review routes, weather risk and ETA
- Manage delivery dispatch information

---

## 7. Main business workflow

```text
Fisherman login
      |
      v
Register catch
      |
      v
Catch saved as Draft
      |
      v
Start Agentic AI workflow
      |
      v
Quality and fraud validation
      |
      +--> Low risk: continue
      |
      +--> Medium/high risk: Admin approval
      |
      v
Market intelligence and price recommendation
      |
      v
Buyer matching
      |
      v
Bidding and order
      |
      v
Logistics planning
      |
      v
Admin approval and execution history
```

### Catch fields

- Fish species
- Quantity in kilograms
- Asking price per kilogram
- Location
- Photo URL
- Seller note
- Verified weight
- Declared quality grade
- Inspection result
- Catch date/time
- Fraud risk
- Weight discrepancy percentage
- Quality score
- Validation summary
- Admin-review flag
- Listing status

---

## 8. Backend API

### Authentication

Implemented in [`AuthController.cs`](../FishLink.API/Controllers/AuthController.cs):

```text
POST /api/Auth/login
POST /api/Auth/register
```

Passwords are hashed using BCrypt and successful login returns a JWT containing
the user identity and role.

### Catch management

Implemented in
[`CatchesController.cs`](../FishLink.API/Controllers/CatchesController.cs):

```text
GET    /api/Catches
GET    /api/Catches/{id}
POST   /api/Catches
PUT    /api/Catches/{id}
DELETE /api/Catches/{id}
PATCH  /api/Catches/{id}/publish
PATCH  /api/Catches/{id}/cancel
GET    /api/Catches/flagged
GET    /api/Catches/market-stats
POST   /api/Catches/validate
PATCH  /api/Catches/{id}/admin-approve
PATCH  /api/Catches/{id}/admin-reject
```

### Agent gateway

Implemented in
[`AgentGatewayController.cs`](../FishLink.API/Controllers/AgentGatewayController.cs):

```text
POST /api/AgentGateway/workflow/start
POST /api/AgentGateway/buyer-match
POST /api/AgentGateway/logistics/plan
GET  /api/AgentGateway/prices/{species}/predict
GET  /api/AgentGateway/agent/health
```

The gateway persists workflow state before dispatching the internal agent.
Agent results return to the API through webhook/status operations.

### Weather

Implemented in
[`WeatherController.cs`](../FishLink.API/Controllers/WeatherController.cs):

```text
GET /api/Weather/current
GET /api/Weather/fishing-safety
GET /api/Weather/logistics
GET /api/Weather/locations
```

The weather provider is accessed from the backend so API keys are not exposed
to React or Flutter.

---

## 9. Database design

Main entities:

- `User`
- `Catch`
- `Bid`
- `Order`
- `AgentWorkflowState`
- `QualityCheck`
- `Delivery`
- `BuyerPreference`
- `Vehicle`
- `Driver`
- `ColdStorage`
- `DeliveryPlan`

Main relationships:

```text
User 1 ---- many Catch
User 1 ---- many Bid
Catch 1 ---- many Bid
Catch 1 ---- one Order
Order 1 ---- one Delivery
Delivery 1 ---- one DeliveryPlan
Catch 1 ---- workflow state/history
Buyer 1 ---- BuyerPreference
```

EF Core migrations are stored in
[`FishLink.API/Migrations`](../FishLink.API/Migrations).

Final ER diagram: `[TO COMPLETE: add diagram file/link]`

---

## 10. Agentic AI subsystem

The Agentic AI service is implemented in
[`ai_agent/main.py`](../ai_agent/main.py).

### Planning Agent

Starts the workflow, identifies the sequence of responsibilities and emits
workflow status updates.

### Quality Validation Agent

Uses:

1. Catch details
2. Market price
3. Seller history
4. Transaction history

Checks:

- Weight discrepancy
- Quality grade
- Inspection result
- Price anomaly
- Seller history
- Suspicious transactions

High-risk examples pause the workflow and set
`RequiresAdminReview = true`.

### Market Intelligence Agent

Combines price model data and database market history. The current hybrid
recommendation uses:

```text
Recommended price = model price * 60% + database price * 40%
```

Fallback behavior is used if external price data is unavailable.

### Buyer Matching Agent

Scores catches based on:

- Species
- Quantity range
- Maximum price
- Preferred city
- Quality score

It returns a ranked recommendation list with match reasons.

### Logistics Scheduling Agent

Uses six allow-listed tools:

1. Available vehicles
2. Available drivers
3. Cold storage
4. Route options
5. Weather
6. ETA calculation

The result contains the selected resources, route, weather risk, pickup time
and ETA.

### Human approval

AI cannot approve high-risk catches automatically. A flagged result becomes
`PendingApproval`; an authorized administrator must approve or reject it.

Agent helper tests are in
[`test_agent_helpers.py`](../ai_agent/tests/test_agent_helpers.py).

---

## 11. React web application

Implemented in [`fishlink-dashboard`](../fishlink-dashboard).

Main areas:

- Landing page
- Login and registration
- Fisherman dashboard
- Buyer dashboard
- Admin fraud review
- AI workflow summaries
- Logistics dashboard
- Market trends

React uses functional components, hooks, routing and API integration. It
provides role-specific navigation, loading states, error states and reusable
dashboard components.

---

## 12. Flutter mobile application

Implemented in [`fishlink_mobile`](../fishlink_mobile).

Main features:

- JWT login
- Secure token storage
- Catch registration
- Species selection
- Quantity and price validation
- Seller notes
- Camera evidence
- GPS location
- Catch list
- Weather/fishing safety information
- Pull-to-refresh
- Loading and error states
- Sign out

Packages:

- `http`
- `flutter_secure_storage`
- `image_picker`
- `geolocator`

Android and iOS permissions are declared for camera and location access.

Flutter API URL is configurable:

```bash
flutter run --dart-define=FISHLINK_API_URL=http://10.0.2.2:5157/api
```

---

## 13. Four-member work allocation

The detailed allocation is in
[`GROUP-WORK-ALLOCATION.md`](./GROUP-WORK-ALLOCATION.md).

| Member | Primary component | Agentic AI responsibility |
|---|---|---|
| Student 1 | Catch registration and quality/fraud | Quality Validation Agent |
| Student 2 | Marketplace, pricing and buyer matching | Market Intelligence and Buyer Matching |
| Student 3 | Bids, orders and logistics | Logistics Scheduling Agent |
| Student 4 | Identity, administration and workflow governance | Planning and Approval Orchestrator |

Every member must contribute to backend, database, React, Flutter, tests, Git,
documentation and Agentic AI. Replace the placeholders with actual members:

| Student | Name | Registration number | GitHub evidence |
|---|---|---|---|
| Student 1 | `[TO COMPLETE]` | `[TO COMPLETE]` | `[TO COMPLETE]` |
| Student 2 | `[TO COMPLETE]` | `[TO COMPLETE]` | `[TO COMPLETE]` |
| Student 3 | `[TO COMPLETE]` | `[TO COMPLETE]` | `[TO COMPLETE]` |
| Student 4 | `[TO COMPLETE]` | `[TO COMPLETE]` | `[TO COMPLETE]` |

---

## 14. Security

Implemented controls:

- JWT authentication
- BCrypt password hashing
- Role-based authorization
- Ownership validation
- Protected API endpoints
- Secure Flutter token storage
- API-only AI access
- Global error handling
- Structured logging
- Health monitoring
- Environment-based internal service URLs

Production secrets must be supplied through environment variables or a secret
manager. Do not commit PostgreSQL credentials, JWT keys, weather keys or
evaluator passwords.

---

## 15. Testing and quality evidence

### Backend

Command:

```powershell
dotnet test FishLink.API.Tests\FishLink.API.Tests.csproj
```

Current local evidence:

```text
5 tests passed
```

Covered behavior:

- Catch creation
- Draft status
- Ownership authorization
- Filtering
- Sorting
- Pagination
- Controller not-found status
- Authenticated controller create

### Agentic AI

Command:

```powershell
Set-Location ai_agent
.\venv\Scripts\python.exe -m unittest discover -s tests -v
```

Current local evidence:

```text
4 tests passed
```

### Flutter

Commands:

```powershell
Set-Location fishlink_mobile
flutter analyze
flutter test
```

Current local evidence:

```text
Flutter analyze: No issues
Flutter tests: Passed
```

### React

Commands:

```powershell
Set-Location fishlink-dashboard
npm ci
npm run build
```

Current local evidence:

```text
Production build compiled successfully
```

### Additional required evidence

| Test layer | Evidence |
|---|---|
| API integration test | `[TO COMPLETE]` |
| PostgreSQL migration test | `[TO COMPLETE]` |
| Agent workflow evaluation | `[TO COMPLETE]` |
| Performance test | `[TO COMPLETE]` |
| Mobile device test | `[TO COMPLETE]` |
| CI run | `[TO COMPLETE: GitHub Actions URL]` |

---

## 16. CI/CD

Workflow:

[`dotnet.yml`](../.github/workflows/dotnet.yml)

The workflow:

1. Checks out the repository.
2. Installs .NET.
3. Restores API and test project dependencies.
4. Builds the API.
5. Runs xUnit tests.
6. Installs Python dependencies.
7. Runs Agentic AI tests.
8. Installs Flutter.
9. Runs Flutter analysis and tests.
10. Builds the release APK.
11. Installs Node dependencies.
12. Builds the React dashboard.

Successful run URL: `[TO COMPLETE]`

---

## 17. Local setup

### API

```powershell
dotnet restore FishLink.API\FishLink.API.csproj
dotnet run --project FishLink.API
```

### Database

Configure `ConnectionStrings:DefaultConnection`, then run migrations and seed
demonstration data using the project's EF tooling and seed mode.

### React

```powershell
Set-Location fishlink-dashboard
npm ci
npm start
```

### Flutter

```powershell
Set-Location fishlink_mobile
flutter pub get
flutter run --dart-define=FISHLINK_API_URL=http://10.0.2.2:5157/api
```

### AI service

```powershell
Set-Location ai_agent
.\venv\Scripts\python.exe -m uvicorn main:app --reload --port 8000
```

### Price service

```powershell
Set-Location price_api
..\ai_agent\venv\Scripts\python.exe -m uvicorn main:app --reload --port 8001
```

---

## 18. Docker deployment

Docker files:

- [`Dockerfile.api`](../Dockerfile.api)
- [`Dockerfile.agent`](../Dockerfile.agent)
- [`Dockerfile.price`](../Dockerfile.price)

The API, Agentic AI service and Price API are separate services. Running only
the API container does not run the AI workflow.

Configure service URLs using environment variables:

```text
AiAgent__BaseUrl=http://agent:10000
PriceApi__BaseUrl=http://price-api:10000
ASP_NET=http://api:10000
PRICE_API_URL=http://price-api:10000/api/prices
```

Target deployment platform: `[TO COMPLETE]`  
API URL: `[TO COMPLETE]`  
Agent URL or private service address: `[TO COMPLETE]`  
Price API URL: `[TO COMPLETE]`  
PostgreSQL provider: `[TO COMPLETE]`

---

## 19. Final demonstration checklist

- [ ] Login as Fisherman.
- [ ] Register a catch from Flutter.
- [ ] Show the same catch in React.
- [ ] Show PostgreSQL data change.
- [ ] Show Swagger and API responses.
- [ ] Run the Agentic AI workflow.
- [ ] Show Planning, Quality, Market, Buyer and Logistics statuses.
- [ ] Show allow-listed tools.
- [ ] Show persisted workflow state.
- [ ] Demonstrate a high-risk catch.
- [ ] Show Admin approval/rejection.
- [ ] Show execution history.
- [ ] Demonstrate an unavailable-service safe failure.
- [ ] Show xUnit, Flutter, AI and React test/build output.
- [ ] Show successful GitHub Actions run.
- [ ] Show deployed applications and APK.
- [ ] Explain one controller, service, DTO, entity relationship, test and ADR.

See the detailed checklist in
[`DEMO-CHECKLIST.md`](./DEMO-CHECKLIST.md).

---

## 20. Submission evidence

Required before final submission:

- [ ] Actual React deployment URL
- [ ] Actual ASP.NET API URL
- [ ] Swagger URL
- [ ] Health endpoint URL
- [ ] PostgreSQL deployment evidence
- [ ] Agent health evidence
- [ ] Release Flutter APK
- [ ] Successful GitHub Actions run URL
- [ ] ER diagram
- [ ] Deployment diagram
- [ ] Agent workflow/state diagram
- [ ] Screenshots and screen recordings
- [ ] Four completed individual reports
- [ ] Individual AI usage logs
- [ ] Group AI usage declaration
- [ ] Integration test results
- [ ] Performance test results
- [ ] GitHub commits, issues and pull requests

The submission templates are available in:

- [`CONSOLIDATED-REPORT.md`](./CONSOLIDATED-REPORT.md)
- [`AI-USAGE-LOG-TEMPLATE.md`](./AI-USAGE-LOG-TEMPLATE.md)
- [`DEPLOYMENT-CHECKLIST.md`](./DEPLOYMENT-CHECKLIST.md)
- [`DEMO-CHECKLIST.md`](./DEMO-CHECKLIST.md)
- [`GROUP-WORK-ALLOCATION.md`](./GROUP-WORK-ALLOCATION.md)

---

## 21. Conclusion

FishLink AI is an integrated cross-platform marketplace rather than a set of
disconnected prototypes. Its main strength is the shared ASP.NET Core API and
PostgreSQL data model used by both React and Flutter, combined with a
controlled Agentic AI workflow that validates data, uses domain tools,
persists state and requests human approval when risk is high.

The implementation and local verification cover the core software solution.
The final assignment submission must still include real deployment, APK,
GitHub Actions, screenshots, individual contributions, AI logs and integration
or performance evidence.
