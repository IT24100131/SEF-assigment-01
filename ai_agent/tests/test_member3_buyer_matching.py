"""
Member 3: Buyer Matching Engine Automated Test Suite
Tests buyer preference matching, multi-criteria scoring algorithm,
budget compatibility, and candidate rank ordering.
"""
import unittest
import sys
import os

# Ensure parent directory is on sys.path to import from main
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import (
    BuyerMatchRequest,
    score_catch,
    run_buyer_matching,
)


class Member3BuyerMatchingTests(unittest.TestCase):

    def test_member3_exact_species_match_yields_high_score(self):
        catch = {
            "fishSpecies": "Yellowfin Tuna",
            "quantityKg": 60,
            "askingPricePerKg": 1100,
            "location": "Negombo",
            "qualityScore": 92
        }
        pref = BuyerMatchRequest(
            species="Yellowfin Tuna",
            min_quantity_kg=20,
            max_quantity_kg=100,
            max_price_per_kg=1200,
            preferred_city="Negombo"
        )
        scored = score_catch(catch, pref)
        self.assertGreaterEqual(scored["matchScore"], 90, f"Expected high score, got {scored['matchScore']}")
        self.assertIn("Exact species match", scored["matchReasons"])

    def test_member3_over_budget_penalty(self):
        catch = {
            "fishSpecies": "Tuna",
            "quantityKg": 50,
            "askingPricePerKg": 2000,  # Over budget
            "location": "Colombo",
            "qualityScore": 80
        }
        pref = BuyerMatchRequest(
            species="Tuna",
            max_price_per_kg=1200
        )
        scored = score_catch(catch, pref)
        self.assertIn("over budget", scored["matchReasons"])

    def test_member3_run_buyer_matching_ranks_descending(self):
        catches = [
            {"fishSpecies": "Tuna", "quantityKg": 50, "askingPricePerKg": 1100, "location": "Negombo", "qualityScore": 85},
            {"fishSpecies": "Tuna", "quantityKg": 50, "askingPricePerKg": 1300, "location": "Galle", "qualityScore": 70},
            {"fishSpecies": "Crab", "quantityKg": 20, "askingPricePerKg": 900, "location": "Colombo", "qualityScore": 80},
        ]
        pref = BuyerMatchRequest(species="Tuna", max_price_per_kg=1250, preferred_city="Negombo")
        results = run_buyer_matching(catches, pref)

        # Crab shouldn't rank above Tuna; top rank should be the Negombo Tuna
        self.assertGreater(len(results), 0)
        self.assertEqual(results[0]["fishSpecies"], "Tuna")
        self.assertEqual(results[0]["location"], "Negombo")


if __name__ == "__main__":
    unittest.main()
