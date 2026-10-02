import unittest
from unittest.mock import patch

from main import (
    BuyerMatchRequest,
    WorkflowRequest,
    compute_final_recommendation,
    run_buyer_matching,
    run_quality_validation_agent,
    tool_calculate_eta,
    tool_get_catch_details,
    tool_get_transaction_history,
)


class AgentHelperTests(unittest.TestCase):
    def test_eta_adds_weather_buffer(self):
        result = tool_calculate_eta("10:00", 90, True)
        self.assertEqual(result["estimatedETA"], "11:50")
        self.assertEqual(result["weatherBuffer"], 20)

    def test_price_recommendation_uses_fallback_when_sources_unavailable(self):
        price, summary = compute_final_recommendation("Tuna", 1000, None, None)
        self.assertEqual(price, 1050)
        self.assertIn("Fallback", summary)

    def test_buyer_matching_requires_species_and_returns_score(self):
        matches = run_buyer_matching(
            [{"fishSpecies": "Tuna", "quantityKg": 40,
              "askingPricePerKg": 1000, "location": "Negombo",
              "qualityScore": 85}],
            BuyerMatchRequest(species="Tuna", max_price_per_kg=1200),
        )
        self.assertEqual(len(matches), 1)
        self.assertGreaterEqual(matches[0]["matchScore"], 30)

    def test_workflow_request_keeps_structured_quality_fields(self):
        request = WorkflowRequest(
            workflow_id="test-1", catch_id=1, fisherman_id=2,
            quantity_kg=40, asking_price=1000, fish_species="Tuna",
            verified_weight_kg=38, declared_quality_grade="A",
            inspection_result="Passed",
        )
        self.assertEqual(request.declared_quality_grade, "A")
        self.assertEqual(request.verified_weight_kg, 38)

    def test_catch_details_tool_uses_quality_context_endpoint(self):
        catch = {"id": 9, "fishermanId": 2, "fishSpecies": "Tuna"}
        with patch("main.requests.get") as get:
            get.return_value.json.return_value = catch

            result = tool_get_catch_details(9)

        get.assert_called_once_with(
            "http://localhost:5157/api/Catches/9/quality-context", timeout=5
        )
        self.assertEqual(result, catch)

    def test_transaction_tool_uses_privacy_limited_pattern_endpoint(self):
        with patch("main.requests.get") as get:
            get.return_value.json.return_value = {
                "totalBids": 3,
                "duplicateBidCount": 1,
                "suspicious": True,
            }

            result = tool_get_transaction_history(9)

        get.assert_called_once_with(
            "http://localhost:5157/api/Bids/catch/9/quality-pattern", timeout=5
        )
        self.assertTrue(result["suspicious"])

    def test_poor_seller_history_does_not_make_clean_new_catch_high(self):
        request = WorkflowRequest(
            workflow_id="history-test",
            catch_id=1,
            fisherman_id=2,
            quantity_kg=40,
            asking_price=1000,
            fish_species="Tuna",
            verified_weight_kg=40,
            declared_quality_grade="A",
            inspection_result="Passed",
        )
        with (
            patch("main.tool_get_catch_details", return_value=None),
            patch("main.tool_get_market_price", return_value={"avgLast30": 1000}),
            patch("main.tool_get_seller_history", return_value={
                "sellerRisk": "Poor", "previousFraudFlags": 3,
                "totalCatches": 7, "avgQualityScore": 85,
            }),
            patch("main.tool_get_transaction_history", return_value={
                "totalBids": 0, "duplicateBidCount": 0, "suspicious": False,
            }),
        ):
            result = run_quality_validation_agent(request)

        self.assertEqual(result.fraud_risk, "Medium")
        self.assertEqual(result.recommended_status, "Published")
        self.assertTrue(result.requires_admin_review)

    def test_severe_current_weight_discrepancy_remains_high(self):
        request = WorkflowRequest(
            workflow_id="weight-test",
            catch_id=1,
            fisherman_id=2,
            quantity_kg=40,
            asking_price=1000,
            fish_species="Tuna",
            verified_weight_kg=20,
            declared_quality_grade="A",
            inspection_result="Passed",
        )
        with (
            patch("main.tool_get_catch_details", return_value=None),
            patch("main.tool_get_market_price", return_value={"avgLast30": 1000}),
            patch("main.tool_get_seller_history", return_value={
                "sellerRisk": "Good", "previousFraudFlags": 0,
                "totalCatches": 1, "avgQualityScore": 85,
            }),
            patch("main.tool_get_transaction_history", return_value={
                "totalBids": 0, "duplicateBidCount": 0, "suspicious": False,
            }),
        ):
            result = run_quality_validation_agent(request)

        self.assertEqual(result.fraud_risk, "High")
        self.assertEqual(result.recommended_status, "Draft")
        self.assertTrue(result.requires_admin_review)


if __name__ == "__main__":
    unittest.main()
