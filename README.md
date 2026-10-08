# FishLink — Member 4 (IT24100131) Individual Contribution

## Component: Logistics & Delivery Fleet Scheduling
**Student ID:** IT24100131  
**Module:** SE3090 — Software Engineering Frameworks  
**Role:** Member 4  

---

### 1. Owned Business Component
* **Component Name:** Logistics, Cold Chain Fleet, and Dispatch Scheduling
* **Backend Controller:** [`FishLink.API/Controllers/LogisticsController.cs`](FishLink.API/Controllers/LogisticsController.cs)
* **Domain Models:**
  * [`DeliveryPlan.cs`](FishLink.API/Models/DeliveryPlan.cs)
  * [`Vehicle.cs`](FishLink.API/Models/Vehicle.cs)
  * [`Driver.cs`](FishLink.API/Models/Driver.cs)
  * [`ColdStorage.cs`](FishLink.API/Models/ColdStorage.cs)

---

### 2. Owned Agentic AI Contribution
* **Agent Role:** **Logistics Scheduling Agent**
* **Workflow:**
  1. Retrieves available cold-chain refrigerated vehicles matching catch weight.
  2. Queries on-duty drivers.
  3. Calculates route distances via Haversine geo-coordinates.
  4. Integrates live OpenWeather forecast to apply adverse weather delay buffers.
  5. Enforces **Human-in-the-Loop (HITL)** approval gate before dispatch.
* **Test Suite:** [`ai_agent/tests/test_member4_logistics.py`](ai_agent/tests/test_member4_logistics.py)

---

### 3. Frontend & Mobile UI Contribution
* **React Web Dashboard:**
  * [`LogisticsDashboard.tsx`](fishlink-dashboard/src/components/Dashboards/LogisticsDashboard.tsx)
  * [`DeliveryPlanWeather.tsx`](fishlink-dashboard/src/components/DeliveryPlanWeather.tsx)
  * [`LiveRouteTrackerModal.tsx`](fishlink-dashboard/src/components/LiveRouteTrackerModal.tsx)
* **Flutter Mobile App:**
  * [`admin_and_logistics.dart`](fishlink_mobile/lib/admin_and_logistics.dart)

---

### 4. Automated Testing
* **C# Backend xUnit Tests:** [`FishLink.API.Tests/Member4_LogisticsTests.cs`](FishLink.API.Tests/Member4_LogisticsTests.cs)
  ```bash
  dotnet test FishLink.API.Tests/FishLink.API.Tests.csproj --no-build --filter FullyQualifiedName~Member4
  ```
* **Python AI Agent Tests:** [`ai_agent/tests/test_member4_logistics.py`](ai_agent/tests/test_member4_logistics.py)
  ```bash
  python -m unittest ai_agent/tests/test_member4_logistics.py -v
  ```
