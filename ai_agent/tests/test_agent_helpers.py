import unittest

from main import (
    BuyerMatchRequest,
    WorkflowRequest,
    compute_final_recommendation,
    run_buyer_matching,
    tool_calculate_eta,
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


if __name__ == "__main__":
    unittest.main()
