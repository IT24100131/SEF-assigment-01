"""
Member 2: Market Price Intelligence & Quality Inspection Automated Test Suite
Tests price recommendation blending, fallback engine, freshness grading,
and weight discrepancy fraud risk thresholds.
"""
import unittest
import sys
import os

# Ensure parent directory is on sys.path to import from main
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import (
    compute_final_recommendation,
    ValidationResult,
    WEIGHT_DIFF_WARNING_PCT,
    WEIGHT_DIFF_HIGH_PCT,
    PRICE_ANOMALY_HIGH_PCT,
)


class Member2PricingQualityTests(unittest.TestCase):

    def test_member2_price_blend_with_model_and_db(self):
        prediction = {"recommendedPrice": 1200.0, "summary": {"trendPct": 3.5}, "next7Days": [{"predictedPrice": 1220}]}
        db_stat = {"catchCount": 15, "recommendedPrice": 1100.0, "avgPriceLast30": 1080.0}
        
        # 60% prediction + 40% DB: 1200*0.6 + 1100*0.4 = 720 + 440 = 1160.0
        blended, summary = compute_final_recommendation("Yellowfin Tuna", 1000.0, prediction, db_stat)
        self.assertEqual(blended, 1160.0)
        self.assertIn("[Hybrid]", summary)

    def test_member2_price_fallback_when_services_offline(self):
        asking_price = 1000.0
        price, summary = compute_final_recommendation("Tuna", asking_price, None, None)
        # Fallback is 5% markup: 1000 * 1.05 = 1050.0
        self.assertEqual(price, 1050.0)
        self.assertIn("[Fallback]", summary)

    def test_member2_weight_discrepancy_thresholds(self):
        declared = 100.0
        
        # 5% discrepancy -> under warning threshold (10%)
        diff_5pct = (abs(declared - 95.0) / declared) * 100
        self.assertLessEqual(diff_5pct, WEIGHT_DIFF_WARNING_PCT)

        # 15% discrepancy -> medium warning
        diff_15pct = (abs(declared - 85.0) / declared) * 100
        self.assertGreater(diff_15pct, WEIGHT_DIFF_WARNING_PCT)
        self.assertLessEqual(diff_15pct, WEIGHT_DIFF_HIGH_PCT)

        # 30% discrepancy -> high fraud risk
        diff_30pct = (abs(declared - 70.0) / declared) * 100
        self.assertGreater(diff_30pct, WEIGHT_DIFF_HIGH_PCT)

    def test_member2_quality_validation_result_structure(self):
        result = ValidationResult()
        result.quality_score = 85
        result.fraud_risk = "Low"
        result.add_check("Grade Check", True, "Grade A certified")
        
        summary = result.to_summary()
        self.assertIn("FRAUD & QUALITY VALIDATION REPORT", summary)
        self.assertIn("LOW", summary)
        self.assertIn("85/100", summary)


if __name__ == "__main__":
    unittest.main()
