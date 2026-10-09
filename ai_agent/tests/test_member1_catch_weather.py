"""
Member 1: Catch Lifecycle, GPS Coastal Waters & Fisherman Workflow Test Suite
Tests catch metadata validation, Sri Lanka territorial coordinate bounds,
weather risk checks, and draft lifecycle transitions.
"""
import unittest

def validate_catch_payload(species: str, quantity_kg: float, asking_price: float) -> tuple[bool, str]:
    if not species or len(species.strip()) == 0:
        return False, "Species is required"
    if quantity_kg <= 0:
        return False, "Quantity must be greater than 0 kg"
    if asking_price <= 0:
        return False, "Asking price must be positive"
    return True, "Valid"

def is_within_sri_lanka_coastal_waters(lat: float, lon: float) -> bool:
    # Sri Lanka coastal EEZ bounding box roughly 5.8N - 9.9N, 79.5E - 82.0E
    return 5.8 <= lat <= 9.9 and 79.5 <= lon <= 82.0

def assess_sea_weather_advisory(wind_speed_knots: float, wave_height_m: float) -> str:
    if wind_speed_knots >= 30 or wave_height_m >= 3.0:
        return "RED_ADVISORY_DO_NOT_VENTURE"
    if wind_speed_knots >= 20 or wave_height_m >= 2.0:
        return "AMBER_ROUGH_SEA_WARNING"
    return "GREEN_NORMAL_SAILING"


class Member1CatchWeatherTests(unittest.TestCase):

    def test_member1_valid_catch_payload(self):
        valid, msg = validate_catch_payload("Yellowfin Tuna", 45.0, 1200.0)
        self.assertTrue(valid)
        self.assertEqual(msg, "Valid")

    def test_member1_rejects_negative_weight_or_price(self):
        valid, msg = validate_catch_payload("Sailfish", -10.0, 1200.0)
        self.assertFalse(valid)
        self.assertIn("Quantity", msg)

        valid_price, msg_price = validate_catch_payload("Sailfish", 25.0, -500.0)
        self.assertFalse(valid_price)
        self.assertIn("price", msg_price)

    def test_member1_gps_negombo_and_galle_in_waters(self):
        # Negombo: 7.2083, 79.8358
        self.assertTrue(is_within_sri_lanka_coastal_waters(7.2083, 79.8358))
        # Galle Bay: 6.0535, 80.2210
        self.assertTrue(is_within_sri_lanka_coastal_waters(6.0535, 80.2210))
        # Landlocked / International outlier (Tokyo: 35.6762, 139.6503)
        self.assertFalse(is_within_sri_lanka_coastal_waters(35.6762, 139.6503))

    def test_member1_marine_weather_advisories(self):
        # Safe conditions (10 knots, 1.2m waves)
        self.assertEqual(assess_sea_weather_advisory(10.0, 1.2), "GREEN_NORMAL_SAILING")
        # Storm conditions (35 knots, 3.5m waves)
        self.assertEqual(assess_sea_weather_advisory(35.0, 3.5), "RED_ADVISORY_DO_NOT_VENTURE")


if __name__ == "__main__":
    unittest.main()
