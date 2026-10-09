# Individual Report — Member 1: Catch Lifecycle & Fisherman Traceability

- **Component Name:** Catch Management, Fisherman Logging & Geolocation Traceability
- **Primary Actors:** Fisherman, System (Ingestion & Marine Validation)
- **Primary Technologies:** ASP.NET Core Web API, Entity Framework Core (PostgreSQL), React (`FishermanDashboard.tsx`), Python Agent (Coastal Bounds)

---

## 1. Primary Responsibilities & Architectural Boundary

1. **Catch Ingestion & Validation:** Captures declared species, quantity (kg), asking price per kg, location/harbor, and seller notes.
2. **Lifecycle State Machine:** Manages state progression (`Draft` -> `PendingValidation` -> `Published` -> `Completed` / `Cancelled`).
3. **Ownership & Access Control:** Strict authorization checks ensuring only the registered owner (Fisherman ID) or an administrator can publish or modify listings.
4. **Coastal Territorial Validation (EEZ Geo-fencing):** Validates fishing coordinates against Sri Lankan territorial waters (Lat 5.8N–9.9N, Lon 79.5E–82.0E).
5. **Multi-criteria Filtering & Paging:** Dynamic SQL/LINQ queries for search by species, location, and price sorting.

---

## 2. Test Execution Commands

Run Member 1 tests individually in the terminal:

### Command A: Python Component Test (Standalone Runner)
```bash
python member1_tests.py
```

### Command B: C# xUnit Test Suite (.NET API)
```bash
dotnet test .\FishLink.API.Tests\FishLink.API.Tests.csproj --filter "Member1"
```

### Command C: Batch Runner (Runs both automatically)
```bash
.\run_member1.bat
```

---

## 3. Test Cases & Verification Results

| Test ID | Test Description | Input / Scenario | Expected Outcome | Result |
|---|---|---|---|---|
| **M1-TC01** | Catch Creation & Draft State | Yellowfin Tuna, 50kg, Rs.1100/kg, Negombo | Status: `Draft`, FraudRisk: `Unassessed` | **PASS** |
| **M1-TC02** | Security Rejection on Publish | Fisherman 99 attempts to publish Fisherman 5's catch | `UnauthorizedAccessException` thrown | **PASS** |
| **M1-TC03** | Owner Publishing Transition | Fisherman 5 publishes their own draft catch | Status transitions to `Published` | **PASS** |
| **M1-TC04** | Paged Search & Harbor Filter | Filter Query: 'Negombo', Species: 'Tuna' | Exactly matches Negombo landings, paged | **PASS** |
| **M1-TC05** | Coastal Geofence Bounds | Negombo (7.208, 79.835) vs Outlier (0.0, 0.0) | Negombo = `True`, Outlier = `False` | **PASS** |
| **M1-TC06** | Input Guardrails Validation | Negative quantity (-10kg) or negative price | Validation error, rejected by boundary | **PASS** |

---

## 4. Key Code Locations

- **C# Controller:** `FishLink.API/Controllers/CatchesController.cs`
- **C# Service:** `FishLink.API/Services/CatchService.cs`
- **C# xUnit Tests:** `FishLink.API.Tests/Member1_CatchManagementTests.cs`
- **Python Tests:** `member1_tests.py` and `ai_agent/tests/test_member1_catch_weather.py`
- **Frontend UI:** `fishlink-dashboard/src/components/Dashboards/FishermanDashboard.tsx`
