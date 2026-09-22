# SE3090 Assignment 1 — Individual Contribution Report
## Student 3: Bidding Engine & Autonomous Buyer Matching

* **Student Name**: [Student 3 Full Name]
* **Registration Number**: [IT Number, e.g. IT24100133]
* **Specialization**: BSc (Hons) in Information Technology (SE / AI)
* **Assigned Role**: Component Lead — Bidding Engine & Autonomous Buyer Matching
* **Primary Business Component**: Component C — Competitive Auction Bidding, Real-Time Bid Evaluation & AI Buyer Matching
* **Assigned Agentic AI**: Autonomous Buyer Matching & Recommendation Agent

---

### 1. Primary Component Overview
This component manages the competitive commercial marketplace where seafood buyers and wholesale distributors discover fresh landings, place real-time bids, and receive AI-driven buyer-seller recommendations. It enables fishermen to maximize their yield through transparent competitive bidding and automated match ranking.

* **Key Business Rules**:
  * A bid must be greater than or equal to the minimum reserve price defined for the catch.
  * Fishermen can inspect incoming bids (Buyer, Price/kg, Volume, AI Match Score %) and choose to [Accept Bid] or [Reject].
  * When a Fisherman accepts a bid, the catch status automatically transitions from `PUBLISHED` to `SOLD`, and the Order Fulfillment pipeline is initiated (triggering the Logistics Agent).
  * The Autonomous Buyer Matching Agent ranks buyers based on six commercial affinity factors: species demand, purchase volume history, price willingness, geographic location, buyer reliability rating, and cold storage readiness.

---

### 2. Full-Stack Technical Contributions

#### A. ASP.NET Core Web API & Database (PostgreSQL)
* **Controllers Owned**:
  * `FishLink.API/Controllers/BidsController.cs`: Handles placing bids, validating bid amounts, listing active bids per catch, and processing the Fisherman's [Accept]/[Reject] decision.
  * `FishLink.API/Controllers/BuyerMatchController.cs`: Integrates with the Buyer Matching AI Agent to calculate ranking scores and affinity recommendations.
* **Entities & Data Modeling**:
  * `Bid.cs`: `Id`, `CatchId`, `BuyerId`, `BuyerName`, `AmountPerKg`, `QuantityKg`, `Status` (`PENDING`, `ACCEPTED`, `REJECTED`), `MatchScorePct`, `CreatedAt`.
  * `BuyerPreference.cs`: `BuyerId`, `PreferredSpecies`, `MinDailyVolumeKg`, `MaxPricePerKg`, `Location`, `CreditScore`.
* **Key API Endpoints**:
  1. `POST /api/Bids` — Submit a new competitive bid for a registered catch.
  2. `GET /api/Bids/catch/{catchId}` — Retrieve all incoming bids for a specific catch (with AI match scores).
  3. `POST /api/Bids/{id}/accept` — Accept an offer, reject competing bids, and create an order.
  4. `POST /api/Bids/{id}/reject` — Reject a bid and notify the buyer.
  5. `GET /api/BuyerMatch/recommend/{catchId}` — Query the AI Agent for top buyer matches for a catch.

#### B. React Web Application
* **Components Owned**:
  * `fishlink-dashboard/src/components/Dashboards/BuyerDashboard.tsx`: Commercial buyer portal showing market inventory, placed bids, won auctions, and AI recommendation feeds.
  * `fishlink-dashboard/src/components/LiveBiddingTable.tsx`: Live updating bids table with instant accept/reject buttons and percentage match badges.
  * `fishlink-dashboard/src/components/BuyerMatchingScoreCard.tsx`: Visual breakdown of buyer matching scores showing demand, distance, and rating breakdown.

#### C. Flutter Mobile Application
* **Screens & Widgets Owned**:
  * `BrowseFishScreen` (Feature 10 & 11 in `main.dart`): Commercial marketplace catalog with search, species filtering (Tuna, Seer, Prawns, Trevally), grade tags, and detailed catch modal sheets.
  * `PlaceBidModal` (Feature 12 in `main.dart`): Interactive bottom-sheet modal allowing buyers to input price per kg and quantity with instant total calculation and minimum price validation.
  * `MyBidsScreen` (Feature 13 in `main.dart`): Buyer portfolio showing all submitted bids with live status indicators (`PENDING`, `ACCEPTED`, `REJECTED`).
  * `CurrentBidsManagement` (Feature 8 in `main.dart`): Fisherman's incoming bid inspection view displaying Buyer A (Rs.1520/kg, 94% match), Buyer B (Rs.1580/kg, 91% match), Buyer C (Rs.1600/kg, 88% match) with one-tap [Accept Bid] and [Reject] actions.
  * `AI Buyer Matching Tab` (Feature 9 in `main.dart`): Direct AI recommendations displaying top matched buyers (🥇 ABC Seafood 94% Match, 🥈 Ocean Fresh 89% Match, 🥉 Lanka Marine 82% Match).

#### D. Agentic AI Contribution: Buyer Matching & Recommendation Agent
* **Role**: Multi-factor ranking agent evaluating buyer profile affinity for freshly landed catch.
* **Contract**:
  * **Input**: `CatchId`, `Species`, `QuantityKg`, `AskingPrice`, `HarborLocation`.
  * **Output**: `RankedBuyers[]` containing `BuyerId`, `BuyerName`, `MatchScore (0-100%)`, `DemandLevel (High/Med/Low)`, `Reasoning`.
* **Deterministic Scoring Formula**:
  * $\text{Score} = (w_1 \cdot \text{Demand}) + (w_2 \cdot \text{PriceMatch}) + (w_3 \cdot \text{VolumeFit}) + (w_4 \cdot \text{Proximity}) + (w_5 \cdot \text{Reliability}) + (w_6 \cdot \text{ColdChain})$
  * Automatic floor threshold: Matches below 60% are excluded from top recommendations.

---

### 3. Testing & Verification Evidence
* **Unit & Integration Tests**:
  * `FishLink.API.Tests/BidsControllerTests.cs`: Validates that bids below asking/reserve price fail validation and that accepting one bid atomically transitions competing bids to `REJECTED`.
  * `BuyerMatchAgentTests.cs`: Asserts that buyers with negative credit ratings are penalized in the ranking score regardless of bid price.
* **Debugging / Viva Change Example**:
  * *Scenario*: How would you adjust the buyer matching model to give 40% weight to buyers within 30 km radius?
  * *Code location*: `ai_agent/main.py` line 145 (in `match_buyers_for_catch`) — update distance weighting factor $w_4$ to `0.40`.

---

### 4. AI Usage Log & Individual Reflection (Section 18.3)
* **Tools Used**: Claude 3.5 Sonnet, GitHub Copilot.
* **Reflection**:
  * *What AI did well*: Assisted in writing the reactive Flutter State management code for instant bid updates and the responsive layout of `BuyerDashboard.tsx`.
  * *What was rejected / modified*: The AI suggested auto-accepting the highest bid after 1 hour without Fisherman input. I removed this automated behavior to preserve full Fisherman autonomy in accordance with our domain requirements.
  * *Personal Learning*: Gained in-depth expertise in atomic database transactions during auction bid acceptance and multi-attribute decision-making algorithms.
