# SE3090 Assignment 1 — Individual Contribution Report
## Student 4: Order Fulfillment, Cold Storage & Autonomous Logistics Scheduling

* **Student Name**: [Student 4 Full Name]
* **Registration Number**: [IT Number, e.g. IT24100134]
* **Specialization**: BSc (Hons) in Information Technology (SE / AI)
* **Assigned Role**: Component Lead — Order Fulfillment, Cold Chain & Autonomous Logistics
* **Primary Business Component**: Component D — Order Processing, Cold Chain Monitoring, Automated Delivery Scheduling & Invoicing
* **Assigned Agentic AI**: Autonomous Logistics Scheduling & Multi-Tool Route Agent

---

### 1. Primary Component Overview
This component governs the end-to-end execution of finalized fish sales, from atomic order creation upon bid acceptance to cold-chain custody, live GPS transit tracking, and final customer delivery. The Autonomous Logistics Agent dynamically orchestrates physical delivery plans (selecting vehicles, qualified drivers, cold vaults, and weather-safe routes) subject to human-in-the-loop administrative approval.

* **Key Business Rules**:
  * An Order is automatically generated when a Fisherman accepts a Bid (e.g., Order #O102: Tuna 100 kg @ Rs.1600/kg = Rs.160,000).
  * The Order progresses through a strict 5-stage state machine: `CONFIRMED` ➔ `SCHEDULED` ➔ `PICKED UP` ➔ `IN TRANSIT` ➔ `DELIVERED`.
  * The Logistics Agent uses 6 internal tools to assemble a viable Delivery Plan without human manual data entry.
  * Before physical vehicle dispatch, the generated Delivery Plan requires human-in-the-loop approval on the React Admin Dashboard.
  * Cold storage temperature must strictly remain $\le 4^\circ\text{C}$; any spike $> 5^\circ\text{C}$ triggers a visual spoilage warning.
  * Integrated financial sandbox provides LankaQR / Card checkout and official Sri Lanka Tax Invoicing (INV102).

---

### 2. Full-Stack Technical Contributions

#### A. ASP.NET Core Web API & Database (PostgreSQL)
* **Controllers Owned**:
  * `FishLink.API/Controllers/OrdersController.cs`: Handles order generation, status step transitions, and customer invoice generation.
  * `FishLink.API/Controllers/LogisticsController.cs`: Integrates with the Logistics AI Agent to generate plans, manage vehicle fleets, assign drivers, and process admin approval (`/api/Logistics/approve/{planId}`).
* **Entities & Data Modeling**:
  * `Order.cs`: `Id`, `CatchId`, `BidId`, `BuyerName`, `SellerName`, `TotalAmount`, `Status`, `CreatedAt`.
  * `DeliveryPlan.cs`: `VehicleId`, `DriverName`, `PickupHarbor`, `Destination`, `PickupTime`, `EstimatedArrival`, `RouteDistanceKm`, `IsApprovedByAdmin`.
  * `ColdStorage.cs`: `FacilityId`, `VaultId`, `CurrentTempCelsius`, `ThresholdTempCelsius`, `Status`.
  * `Vehicle.cs` & `Driver.cs`: Fleet capacity, refrigeration capabilities, contact info.
* **Key API Endpoints**:
  1. `POST /api/Orders/from-bid/{bidId}` — Convert accepted bid into confirmed order.
  2. `GET /api/Orders/{id}` — Retrieve order timeline, items, and billing details.
  3. `POST /api/Logistics/schedule/{orderId}` — Invoke Logistics Agent to compute delivery plan.
  4. `POST /api/Logistics/approve/{planId}` — Admin approval gate for vehicle dispatch.
  5. `GET /api/Logistics/cold-chain/{orderId}` — Real-time telemetry feed for cold storage.

#### B. React Web Application
* **Components Owned**:
  * `fishlink-dashboard/src/components/Dashboards/LogisticsDashboard.tsx`: Fleet management dashboard showing active delivery routes, vehicle statuses, temperature alerts, and pending dispatches.
  * `fishlink-dashboard/src/components/DeliveryApprovalModal.tsx`: Human-in-the-loop approval modal presenting the AI-recommended vehicle, driver, weather risk score, and ETA for one-click admin signoff.

#### C. Flutter Mobile Application
* **Screens & Widgets Owned** (Features 15–25):
  * `OrdersScreen` (Feature 15 in `features_15_25.dart`): Order #O102 details with the 5-stage timeline stepper (`CONFIRMED` ➔ `SCHEDULED` ➔ `PICKED UP` ➔ `IN TRANSIT` ➔ `DELIVERED`).
  * `LogisticsDeliveryModal` (Feature 16): Displays assigned Vehicle V02, Driver 01, Pickup 10:00 AM, ETA 11:35 AM, Negombo ➔ Colombo route, and `APPROVED` status badge.
  * `LiveDeliveryTrackingModal` (Feature 17): Device GPS integration using `geolocator`, showing current live coordinates, animated delivery truck route, and distance to destination.
  * `ColdStorageMonitorModal` (Feature 18): Circular temperature gauge showing live 3.0°C (Safe) reading with dynamic warning banner if temperature exceeds threshold.
  * `PaymentModal` (Feature 20): Interactive payment modal with LankaQR QR-code visual and VISA Card mock payment simulator.
  * `InvoiceModal` (Feature 21): Formal Sri Lanka Tax Invoice (INV102) with breakdown (Subtotal Rs.160,000, VAT 0%, Total Rs.160,000) and simulated PDF download.
  * `NotificationsScreen` (Feature 22): Activity alerts stream for bid notifications, order status changes, and logistics approvals.
  * `HistoryScreen` (Feature 23): Historical record of past completed seafood deliveries with searchable archive.
  * `ProfileScreen` (Feature 24): User details, contact info, active role badge, and role switcher.
  * `BottomNavigationBar` (Feature 25 in `main.dart`): Persistent 5-tab navigation bar (Home, Browse, Orders, Quality, Profile) tying the mobile experience together.

#### D. Agentic AI Contribution: Autonomous Logistics Scheduling & Multi-Tool Agent
* **Role**: Autonomous multi-step decision agent coordinating vehicle allocation, driver assignment, cold vault reservation, and route optimization.
* **Agent Tools Utilized**:
  1. `get_available_vehicles()`: Filters refrigerated vehicles capable of holding catch payload.
  2. `get_available_drivers()`: Identifies licensed drivers on duty.
  3. `reserve_cold_vault()`: Books cold vault C02 at target transit depot.
  4. `compute_route_eta()`: Calculates transit distance and road travel time.
  5. `check_weather_clearance()`: Validates adverse weather conditions along the highway.
  6. `generate_dispatch_manifest()`: Synthesizes final delivery plan for admin sign-off.
* **Human-In-The-Loop Safety Policy**:
  * The agent will NEVER dispatch a vehicle directly. It stages the plan in `PENDING_APPROVAL` status until a verified logistics administrator reviews and clicks [Approve Dispatch].

---

### 3. Testing & Verification Evidence
* **Unit & Integration Tests**:
  * `FishLink.API.Tests/OrdersControllerTests.cs`: Tests order lifecycle transitions and verifies idempotency of the accepted bid to order generation endpoint.
  * `LogisticsAgentWorkflowTests.cs`: Simulates mock tool calls (vehicle selection, driver assignment, cold storage reservation) and asserts valid schema of generated dispatch manifest.
* **Debugging / Viva Change Example**:
  * *Scenario*: How do you change the cold storage safety threshold from 4°C to 2°C for sashimi-grade yellowfin tuna?
  * *Code location*: `features_15_25.dart` line 160 (`tempCelsius <= 4.0`) and `FishLink.API/Controllers/LogisticsController.cs` line 52.

---

### 4. AI Usage Log & Individual Reflection (Section 18.3)
* **Tools Used**: GitHub Copilot, Gemini Code Assistant.
* **Reflection**:
  * *What AI did well*: Generating the 5-step custom stepper widget in Flutter and standardizing the LankaQR invoice layout.
  * *What was rejected / modified*: The AI generated a script that directly finalized delivery without requiring the Admin approval button. I added the mandatory human-in-the-loop verification gate to satisfy project assessment requirements.
  * *Personal Learning*: Developed robust understanding of multi-tool agent patterns in Python and device geolocation APIs in Flutter web and mobile.
