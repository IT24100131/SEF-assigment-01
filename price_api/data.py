"""
Realistic 90-day historical fish price data for Negombo, Sri Lanka.
Prices are in LKR per kg, modelled on real market patterns:
  - Tuna (Yellowfin): premium species, Rs.2000–2600, seasonal demand swings
  - Skipjack:         mid-range,         Rs.600–950,  tied to export demand
  - Trevally (Paraw): steady local fish,  Rs.900–1300, gradual rise
  - Mackerel:         budget species,      Rs.400–700,  volatile with weather
Each list = one day entry from 90 days ago → today (oldest first).
"""

from datetime import datetime, timedelta, timezone

_SPECIES_PATTERNS = {
    "Tuna (Yellowfin)": {
        # Base price, weekly drift, noise amplitude
        "base": 2100,
        "weekly_deltas": [
            # week 1-4 slow rise, week 5-8 dip, week 9-13 recovery & spike
            30, 20, -10, 15, 25, 30, -20, -30, 10, 40, 50, 20, 30
        ],
        "noise": 80,
        "unit": "LKR/kg",
    },
    "Skipjack": {
        "base": 680,
        "weekly_deltas": [10, -5, 15, 20, -10, -20, 5, 10, 15, -5, 10, 20, 15],
        "noise": 40,
        "unit": "LKR/kg",
    },
    "Trevally (Paraw)": {
        "base": 950,
        "weekly_deltas": [15, 10, 20, 10, -5, 10, 15, 20, 10, 25, 15, 20, 10],
        "noise": 50,
        "unit": "LKR/kg",
    },
    "Mackerel": {
        "base": 450,
        "weekly_deltas": [5, -10, 20, -15, 30, -20, 10, 15, -10, 20, 30, -15, 20],
        "noise": 35,
        "unit": "LKR/kg",
    },
}

import random
random.seed(42)  # deterministic — same data every restart


def _generate_prices(pattern: dict, days: int = 90) -> list[dict]:
    """Generate daily price entries using base + weekly drift + bounded noise."""
    records = []
    price = float(pattern["base"])
    deltas = pattern["weekly_deltas"]

    for day_offset in range(days, 0, -1):  # oldest → newest
        week = (days - day_offset) // 7
        weekly_drift = deltas[week % len(deltas)]
        noise = random.uniform(-pattern["noise"], pattern["noise"])
        price = max(pattern["base"] * 0.7, price + (weekly_drift / 7) + noise)
        price = min(pattern["base"] * 1.6, price)

        date = datetime.now(timezone.utc) - timedelta(days=day_offset)
        records.append({
            "date": date.strftime("%Y-%m-%d"),
            "price": round(price, 2),
            "unit": pattern["unit"],
        })

    return records


# Pre-generate all data at import time (fast, deterministic)
HISTORICAL_DATA: dict[str, list[dict]] = {
    species: _generate_prices(pattern)
    for species, pattern in _SPECIES_PATTERNS.items()
}

SUPPORTED_SPECIES = list(_SPECIES_PATTERNS.keys())
