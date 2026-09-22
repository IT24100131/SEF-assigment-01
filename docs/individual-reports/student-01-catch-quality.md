# SE3090 Assignment 1 — Individual Contribution Report
## Student 1: Catch Ingestion, Pier Inspection & Quality/Fraud Validation

* **Student Name**: [Student 1 Full Name]
* **Registration Number**: [IT Number, e.g. IT24100131]
* **Specialization**: BSc (Hons) in Information Technology (SE / AI)
* **Assigned Role**: Component Lead — Catch Ingestion & Quality/Fraud Validation
* **Primary Business Component**: Component A — Fish Catch Registration, Harbor Pier Inspection & Discrepancy Auditing
* **Assigned Agentic AI**: Quality Validation & Fraud Detection Agent

---

### 1. Primary Component Overview
This component manages the primary lifecycle of seafood landing records in Negombo Harbor. It provides the digital bridge between sea vessels and market auction, enforcing weight integrity, physical quality inspection, and automated fraud prevention.

* **Key Business Rules**:
  * A catch must specify species, declared weight, asking price, and GPS harbor location.
  * Before open bidding, catch must pass physical pier inspection or automated threshold check.
  * Discrepancies between declared weight and verified weight exceeding 15% trigger an `ADMIN REVIEW` hold via the Fraud Detection Agent.

---

### 2. Full-Stack Technical Contributions

#### A. ASP.NET Core Web API & Database (PostgreSQL)
* **Controllers Owned**:
  * `FishLink.API/Controllers/CatchesController.cs`: Handles CRUD operations for catch listings, harbor locations, status transitions (`Draft` ➔ `Published` ➔ `Sold`).
  * `FishLink.API/Controllers/QualityController.cs`: Pier inspector submission (`/api/Quality/inspect/{catchId}`), weight verification, and discrepancy calculation.
* **Entities & Data Modeling**:
  * `Catch.cs`: `DeclaredWeightKg`, `VerifiedWeightKg`, `DeclaredQualityGrade`, `QualityScore`, `FraudRisk`, `WeightDiscrepancyPct`, `RequiresAdminReview`.
  * `QualityCheck.cs`: Inspector relations, inspection timestamps, passing score.
* **Key API Endpoints**:
  1. `POST /api/Catches` — Register a new catch with GPS coordinates and photo URL.
  2. `GET /api/Catches` — Filter and retrieve active/published catches with pagination.
  3. `GET /api/Catches/{id}` — Retrieve detailed catch specifications with quality metadata.
  4. `POST /api/Quality/inspect/{catchId}` — Submit official pier inspector weight & grade.

#### B. React Web Application
* **Components Owned**:
  * `fishlink-dashboard/src/components/Dashboards/FishermanDashboard.tsx`: Catch status tracking, landing logs, pier selection.
  * `fishlink-dashboard/src/components/Dashboards/QualityDashboard.tsx`: Pier Inspector control panel, photo examination, discrepancy alert table.
  * `fishlink-dashboard/src/components/CatchRegistrationModal.tsx`: Web catch entry form with validation.

#### C. Flutter Mobile Application
* **Screens & Widgets Owned**:
  * `NewCatchScreen` (in `main.dart`): Mobile catch registration with `image_picker` camera capture, GPS harbor coordinates via `geolocator`, and form validation.
  * `_QualityModalContent` (in `features_15_25.dart`): Feature 19 Quality Verification view. Displays standard verified state (`Catch C103`, 98 kg, Grade A, Passed) and includes an interactive toggle to demonstrate the flagged suspicious case (`Catch C104`, 100 kg declared vs 62 kg verified, Status: `ADMIN REVIEW`).

#### D. Agentic AI Contribution: Quality Validation & Fraud Agent
* **Role**: Deterministic rule checking & multi-step fraud analysis.
* **Contract**:
  * **Input**: `CatchId`, `Species`, `DeclaredWeightKg`, `VerifiedWeightKg`, `AskingPrice`.
  * **Output**: `QualityScore (0-100)`, `DiscrepancyPct`, `FraudRisk (Low/Medium/High)`, `RequiresAdminReview (bool)`.
* **Deterministic Guardrails**:
  * Discrepancy $\le 5\%$: Classified as natural ice-melt/drip loss. Status: `VERIFIED ✅`.
  * Discrepancy $> 15\%$: Automatically sets `RequiresAdminReview = true` and updates state to `ADMIN REVIEW` for inspector physical audit.

---

### 3. Testing & Verification Evidence
* **Unit & Integration Tests**:
  * `FishLink.API.Tests/QualityAgentTests.cs`: Validates discrepancy mathematical logic and boundary conditions.
  * `CatchesControllerTests.cs`: Tests authorization, valid model binding, and draft-to-published state transitions.
* **Debugging / Viva Change Example**:
  * *Scenario*: What if the drip loss tolerance for large tuna (>100 kg) needs to be 3% instead of 2%?
  * *Code location*: `ai_agent/main.py` line 280 & `QualityController.cs` line 36. Modify threshold from `0.02` to `0.03`.

---

### 4. AI Usage Log & Individual Reflection (Section 18.3)
* **Tools Used**: GitHub Copilot, Gemini Code Assistant.
* **Reflection**:
  * *What AI did well*: Generating boilerplate EF Core migration configurations and Flutter form validation regular expressions.
  * *What was rejected / modified*: AI initially suggested auto-banning fishermen when a weight discrepancy occurred. I rejected this and replaced it with a human-in-the-loop `ADMIN REVIEW` flag to comply with safety requirements.
  * *Personal Learning*: Mastered handling multipart form uploads in Flutter with ASP.NET Core API authentication tokens.
