# SE3090 Assignment 1 — Individual Contribution Report
## Student 2: Dynamic Market Intelligence, Price Discovery & Marine Safety

* **Student Name**: [Student 2 Full Name]
* **Registration Number**: [IT Number, e.g. IT24100132]
* **Specialization**: BSc (Hons) in Information Technology (SE / AI)
* **Assigned Role**: Component Lead — Dynamic Market Intelligence & Marine Safety
* **Primary Business Component**: Component B — Real-Time Market Price Discovery, Time-Series Forecasting & Weather Advisory
* **Assigned Agentic AI**: Market Intelligence & Price Recommendation Agent

---

### 1. Primary Component Overview
This component provides real-time fair market value estimation for seafood catches in Sri Lanka. It protects local fishermen from exploitative low prices by analyzing historical market prices, seasonal trends, and sea weather safety risks, providing actionable price suggestions before catches go to open auction.

* **Key Business Rules**:
  * Price recommendations use a 14-day Weighted Moving Average (WMA) combined with supply-demand indices.
  * Sea weather condition is fetched via OpenWeatherMap API; severe risk downgrades expected harbor supply and increases market price ceiling.
  * If the price AI service is unreachable, ASP.NET Core seamlessly falls back to local database historical averages.

---

### 2. Full-Stack Technical Contributions

#### A. ASP.NET Core Web API & Database (PostgreSQL)
* **Controllers Owned**:
  * `FishLink.API/Controllers/AgentGatewayController.cs`: Endpoints for price prediction (`/api/AgentGateway/prices/{species}/predict`), market trends, and pricing overrides.
  * `FishLink.API/Controllers/WeatherController.cs`: Marine safety checks, wave heights, wind speed ratings.
  * `FishLink.API/Services/WeatherService.cs`: Third-party integration with OpenWeatherMap API with in-memory caching.
* **Entities & Data Modeling**:
  * `MarketPriceIndex`: Species, historical average, 30-day min/max, timestamp.
  * `WeatherRiskLog`: Harbour location, wind speed, wave height, risk category.
* **Key API Endpoints**:
  1. `GET /api/AgentGateway/prices/{species}/predict` — AI Price recommendation (low, recommended, high, confidence, rationale).
  2. `GET /api/Weather/fishing-safety?location={loc}` — Marine safety status and wind/swell advisory.
  3. `GET /api/AgentGateway/market-trends` — Multi-species daily price trends.
  4. `POST /api/AgentGateway/prices/override` — Administrative price benchmark adjustments.

#### B. React Web Application
* **Components Owned**:
  * `fishlink-dashboard/src/components/Dashboards/MarketDashboard.tsx`: Live market price index, historical trend charts using Recharts.
  * `fishlink-dashboard/src/components/WeatherSafetyAdvisory.tsx`: Coastal harbor weather conditions and fishing safety badges.

#### C. Flutter Mobile Application
* **Screens & Widgets Owned**:
  * `showAiPriceRecommendationModal` (in `main.dart` lines 1800-1950): Feature 7 AI Price Recommendation dialog showing recommended range (`Rs. 1550 – Rs. 1650 / kg`), Demand (`HIGH`), Confidence (`87%`), and reasoning.
  * `MarketScreen` & Marine Weather Banner (in `main.dart` lines 4850-4960): Live market prices by species (Tuna, Mackerel, Seer Fish) and sea weather advisory card.

#### D. Agentic AI Contribution: Market Intelligence Agent
* **Role**: Domain analysis & market trend prediction.
* **Algorithm**:
  $$\text{WMA} = \frac{\sum_{i=1}^{n} w_i \times P_i}{\sum_{i=1}^{n} w_i}$$
  where recent transaction days carry progressively higher weights ($w_i$).
* **Fallback Resilience**:
  * Implemented structured exception handling in `AgentGatewayController.cs`. If the Python microservice is down, ASP.NET Core calculates the recommendation from local database transaction history with `Confidence = 75%`.

---

### 3. Testing & Verification Evidence
* **Unit & Integration Tests**:
  * `FishLink.API.Tests/PricePredictionTests.cs`: Tests WMA calculation consistency, JSON serialization, and fallback behavior.
  * `WeatherServiceTests.cs`: Mocked HTTP tests for OpenWeatherMap responses and timeout handling.
* **Viva Change Proposal**:
  * *Scenario*: Add a 5% price premium if the catch is tagged as "Organic Handline Caught".
  * *Implementation*: Adjust recommendation multiplier in `AgentGatewayController.cs` when `tag == "Handline"`.

---

### 4. AI Usage Log & Individual Reflection (Section 18.3)
* **Tools Used**: ChatGPT, Claude.
* **Reflection**:
  * *What AI did well*: Assisted in formulating the Weighted Moving Average mathematical formulas in C# and Python.
  * *What was rejected / modified*: AI generated a direct HTTP call from Flutter to the Python price port (`localhost:8001`). I rejected this to adhere strictly to the mandatory backend rule requiring all calls to route through ASP.NET Core (`/api/AgentGateway`).
  * *Personal Learning*: Gained a deep understanding of time-series caching strategies and circuit-breaker patterns in microservices.
