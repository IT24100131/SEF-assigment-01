# Individual Report — Member 2: Quality Assessment, Fraud Prevention & Market Price Intelligence

- **Component Name:** Quality Inspection, Anti-Fraud Shield & Hybrid Price Recommendation Engine
- **Primary Actors:** Quality Inspector, Market Pricing Subsystem, AI Agent
- **Primary Technologies:** ASP.NET Core, EF Core, Python FastAPI (`ai_agent/main.py`), Price Microservice (`price_api/`)

---

## 1. Primary Responsibilities & Architectural Boundary

1. **Inspector Audit Logging:** Captures physical inspection records (`QualityCheck` table) with verified weight and notes.
2. **Freshness & Grade Scoring:** Classifies catches into Grade A (score >= 85), Grade B (70-84), and Grade C (< 70).
3. **Weight Discrepancy & Fraud Detection:** Compares declared weight vs. inspector-verified weight. Flags `High` fraud risk if discrepancy > 25%, `Medium` if > 10%, and `Low` otherwise.
4. **Hybrid 60/40 WMA Price Model:** Combines ML price predictions (60% weight) with database 30-day historical averages (40% weight).
5. **Fault-Tolerant Fallback Mechanism:** Gracefully falls back to a deterministic 5% markup above asking price when the external pricing microservice is offline.

---

## 2. Test Execution Commands

Run Member 2 tests individually in the terminal:

### Command A: Python Component Test (Standalone Runner)
```bash
python member2_tests.py
```

### Command B: C# xUnit Test Suite (.NET API)
```bash
dotnet test .\FishLink.API.Tests\FishLink.API.Tests.csproj --filter "Member2"
```

### Command C: Batch Runner (Runs both automatically)
```bash
.\run_member2.bat
```

---

## 3. Test Cases & Verification Results

| Test ID | Test Description | Input / Scenario | Expected Outcome | Result |
|---|---|---|---|---|
| **M2-TC01** | Quality Grade Scoring | Scores: 92, 78, 62 | Grade A (92), Grade B (78), Grade C (62) | **PASS** |
| **M2-TC02** | Fraud Risk Thresholds | Declared 100kg vs Verified: 97kg, 85kg, 70kg | Low (3%), Medium (15%), High (30%) | **PASS** |
| **M2-TC03** | 60/40 Hybrid WMA Price Blend | Model: Rs.1200/kg, DB: Rs.1100/kg | Blended: Rs.1160.00/kg (`1200*0.6 + 1100*0.4`) | **PASS** |
| **M2-TC04** | Price Engine Fallback | Upstream Price API down, Asking: Rs.1000/kg | Fallback: Rs.1050.00/kg (5% floor) | **PASS** |
| **M2-TC05** | Quality Audit Trail Persistence | Inspector 9 audits Catch 201 (79.2kg verified) | DB record created, Status: `PendingValidation` | **PASS** |

---

## 4. Key Code Locations

- **C# Controller:** `FishLink.API/Controllers/QualityController.cs`
- **C# Entity:** `FishLink.API/Models/QualityCheck.cs`
- **C# xUnit Tests:** `FishLink.API.Tests/Member2_MarketPricingQualityTests.cs`
- **Python Tests:** `member2_tests.py` and `ai_agent/tests/test_member2_pricing_quality.py`
- **AI Agent Functions:** `ai_agent/main.py` (`run_quality_validation_agent`, `compute_final_recommendation`)
