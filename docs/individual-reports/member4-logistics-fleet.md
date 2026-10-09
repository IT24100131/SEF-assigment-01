# Individual Report — Member 4: Logistics Fleet Scheduling & Delivery Dispatch Management

- **Component Name:** Cold-Fleet Scheduling, Geo-Routing, Weather-Aware Dispatch & Human-in-the-Loop Admin Approval
- **Primary Actors:** Logistics Manager, Cold-Truck Driver, System Dispatcher
- **Primary Technologies:** ASP.NET Core, EF Core, Python FastAPI Agent, OpenWeatherMap API, Haversine Engine

---

## 1. Primary Responsibilities & Architectural Boundary

1. **Refrigerated Fleet Allocation:** Filters vehicles based on active availability (`status == 'Available'`) and cargo capacity (`capacityKg >= catchWeightKg`).
2. **Active Driver Assignment:** Matches duty-ready drivers, excluding busy or resting staff.
3. **Haversine Geo-Distance Routing:** Computes true spherical distance across coastal Sri Lankan harbors and major cities (e.g. Negombo -> Colombo: ~35km).
4. **Weather Delay & ETA Buffer Engine:** Integrates weather forecasts. When rainfall or rough conditions are detected, automatically adds a +20 minute weather safety buffer.
5. **Human-in-the-Loop Admin Approval:** Prevents autonomous dispatch. Plans pause in `PendingApproval` state until a human administrator approves or rejects them.

---

## 2. Test Execution Commands

Run Member 4 tests individually in the terminal:

### Command A: Python Component Test (Standalone Runner)
```bash
python member4_tests.py
```

### Command B: C# xUnit Test Suite (.NET API)
```bash
dotnet test .\FishLink.API.Tests\FishLink.API.Tests.csproj --filter "Member4"
```

### Command C: Batch Runner (Runs both automatically)
```bash
.\run_member4.bat
```

---

## 3. Test Cases & Verification Results

| Test ID | Test Description | Input / Scenario | Expected Outcome | Result |
|---|---|---|---|---|
| **M4-TC01** | Fleet Capacity & Status Filtering | Catch: 350kg; Fleet: 100kg(Avail), 500kg(Avail), 1000kg(Busy) | Only V02 (500kg, Available) selected | **PASS** |
| **M4-TC02** | Driver Duty Assignment | Drivers: D01 (Available), D02 (Busy) | Only D01 assigned | **PASS** |
| **M4-TC03** | Haversine Geo-Distance Calculation | Negombo (7.208, 79.835) to Colombo (6.927, 79.861) | Distance calculated at ~31.4km (within 30-45km) | **PASS** |
| **M4-TC04** | Weather Delay Buffer Engine | 10:00 pickup, 60 min transit, rain expected | +20 min buffer added, ETA: 11:20 (80 min total) | **PASS** |
| **M4-TC05** | Human-in-the-Loop Approval Pause | Plan in `PendingApproval`, Admin clicks 'Approve' | Plan status updates to `Approved`, Dispatch permitted | **PASS** |

---

## 4. Key Code Locations

- **C# Controllers:** `FishLink.API/Controllers/LogisticsController.cs`, `FishLink.API/Controllers/WeatherController.cs`
- **C# Entities:** `FishLink.API/Models/DeliveryPlan.cs`, `FishLink.API/Models/Vehicle.cs`, `FishLink.API/Models/Driver.cs`
- **C# xUnit Tests:** `FishLink.API.Tests/Member4_LogisticsTests.cs`
- **Python Tests:** `member4_tests.py` and `ai_agent/tests/test_member4_logistics.py`
- **Frontend UI:** `fishlink-dashboard/src/components/DeliveryPlanWeather.tsx`
