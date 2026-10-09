# Individual Report — Member 3: Buyer Matching Engine & Marketplace Bidding System

- **Component Name:** Buyer Preference Matching, Multi-Criteria Compatibility Scoring & Bidding Workflow
- **Primary Actors:** Buyer, Fisherman, AI Buyer Matching Agent
- **Primary Technologies:** ASP.NET Core, EF Core, React (`BuyerDashboard.tsx` / `BuyerMatchPanel`), Python Agent (`run_buyer_matching`)

---

## 1. Primary Responsibilities & Architectural Boundary

1. **Buyer Demand Ingestion:** Captures buyer preferences (`BuyerPreference` table) including species, quantity range, budget limit, and city.
2. **Multi-Factor Compatibility Algorithm:** Computes a composite 0–100 match score across 5 weighted dimensions:
   - Species exact match (40 pts)
   - Quantity bracket fit (25 pts)
   - Price & budget savings (20 pts)
   - City / location proximity (10 pts)
   - Quality grade bonus (5 pts)
3. **Bidding State Machine:** Manages bids from `Pending` -> `Accepted` / `Rejected`.
4. **Order Generation on Acceptance:** When a fisherman accepts a winning bid, the system automatically marks the bid `Accepted`, creates a corresponding `Order` record, and updates the catch to `Completed`.
5. **Marketplace Guardrails:** Enforces business rules rejecting bids on unpublished/draft listings or bids with non-positive values.

---

## 2. Test Execution Commands

Run Member 3 tests individually in the terminal:

### Command A: Python Component Test (Standalone Runner)
```bash
python member3_tests.py
```

### Command B: C# xUnit Test Suite (.NET API)
```bash
dotnet test .\FishLink.API.Tests\FishLink.API.Tests.csproj --filter "Member3"
```

### Command C: Batch Runner (Runs both automatically)
```bash
.\run_member3.bat
```

---

## 3. Test Cases & Verification Results

| Test ID | Test Description | Input / Scenario | Expected Outcome | Result |
|---|---|---|---|---|
| **M3-TC01** | High Compatibility Scoring | Species match, 50kg in range, Rs.1100 <= Rs.1300, same city | Score >= 95/100 (Top match) | **PASS** |
| **M3-TC02** | Budget Overrun Penalty | Asking Rs.1800/kg vs Buyer Max Rs.1200/kg | Zero budget points awarded | **PASS** |
| **M3-TC03** | Species Mismatch Filter | Buyer wants Tuna, listing is Sailfish | Species score = 0, score < 60 | **PASS** |
| **M3-TC04** | Bid Acceptance -> Order Flow | Fisherman accepts Rs.2000/kg bid for 20kg catch | Bid: `Accepted`, Order created (Total: Rs.40,000) | **PASS** |
| **M3-TC05** | Marketplace Safety Guardrails | Bid placed on `Draft` (unpublished) catch | Rejected with descriptive guardrail error | **PASS** |

---

## 4. Key Code Locations

- **C# Controllers:** `FishLink.API/Controllers/BuyerMatchController.cs`, `FishLink.API/Controllers/BidsController.cs`
- **C# Entities:** `FishLink.API/Models/BuyerPreference.cs`, `FishLink.API/Models/Bid.cs`, `FishLink.API/Models/Order.cs`
- **C# xUnit Tests:** `FishLink.API.Tests/Member3_BuyerMatchingBidsTests.cs`
- **Python Tests:** `member3_tests.py` and `ai_agent/tests/test_member3_buyer_matching.py`
- **AI Agent Functions:** `ai_agent/main.py` (`score_catch`, `run_buyer_matching`)
