"""
FishLink Price API — standalone historical fish price service.
Runs on port 8001 (ai_agent runs on 8000).

Endpoints:
  GET /api/prices/species                        — list supported species
  GET /api/prices/{species}                      — full 90-day history
  GET /api/prices/{species}/summary              — 30d avg, prev 30d avg, trend %
  GET /api/prices/{species}/predict              — 7-day price prediction
  GET /health
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from statistics import mean, stdev
from data import HISTORICAL_DATA, SUPPORTED_SPECIES

app = FastAPI(title="FishLink Price API", version="1.0.0")

# Allow calls from React (port 3000) and ai_agent (same host)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "http://localhost:8000", "http://localhost:5157"],
    allow_methods=["GET"],
    allow_headers=["*"],
)


def _resolve_species(species: str) -> str:
    """Case-insensitive species lookup."""
    for s in SUPPORTED_SPECIES:
        if s.lower() == species.lower().replace("-", " ").replace("_", " "):
            return s
    raise HTTPException(
        status_code=404,
        detail=f"Species '{species}' not found. Available: {SUPPORTED_SPECIES}",
    )


def _compute_summary(prices: list[float]) -> dict:
    """
    Given a list of daily prices (oldest→newest), compute:
      - last-30d average
      - previous-30d average
      - trend % change
      - min / max / stddev
    """
    last30  = prices[-30:]
    prev30  = prices[-60:-30] if len(prices) >= 60 else prices[:30]

    avg_last  = round(mean(last30), 2)
    avg_prev  = round(mean(prev30), 2)
    trend_pct = round((avg_last - avg_prev) / avg_prev * 100, 2) if avg_prev else 0

    return {
        "avgLast30":  avg_last,
        "avgPrev30":  avg_prev,
        "trendPct":   trend_pct,
        "minLast30":  round(min(last30), 2),
        "maxLast30":  round(max(last30), 2),
        "stddevLast30": round(stdev(last30), 2) if len(last30) > 1 else 0,
    }


def _predict_next_7(prices: list[float], trend_pct: float) -> list[dict]:
    """
    Simple linear-weighted moving average prediction for next 7 days.
    Uses last 14 days with linearly increasing weights + trend momentum.
    """
    from datetime import datetime, timedelta, timezone

    window = prices[-14:]
    weights = list(range(1, len(window) + 1))          # 1,2,...,14
    wma = sum(p * w for p, w in zip(window, weights)) / sum(weights)

    daily_drift = (wma * trend_pct / 100) / 30          # spread trend over month

    predictions = []
    base = datetime.now(timezone.utc)
    for i in range(1, 8):
        predicted = round(wma + daily_drift * i, 2)
        predictions.append({
            "date":           (base + timedelta(days=i)).strftime("%Y-%m-%d"),
            "predictedPrice": predicted,
        })
    return predictions


# ── Routes ────────────────────────────────────────────────────────────────────

@app.get("/health")
def health():
    return {"status": "FishLink Price API running", "species": SUPPORTED_SPECIES}


@app.get("/api/prices/species")
def list_species():
    return {"species": SUPPORTED_SPECIES}


@app.get("/api/prices/{species}")
def get_history(species: str, days: int = 90):
    """Return up to `days` daily price records for the given species."""
    resolved = _resolve_species(species)
    history  = HISTORICAL_DATA[resolved]
    return {
        "species": resolved,
        "unit":    "LKR/kg",
        "records": history[-days:],
    }


@app.get("/api/prices/{species}/summary")
def get_summary(species: str):
    """30-day avg, previous 30-day avg, trend %, min, max, stddev."""
    resolved = _resolve_species(species)
    prices   = [r["price"] for r in HISTORICAL_DATA[resolved]]
    summary  = _compute_summary(prices)
    return {"species": resolved, "unit": "LKR/kg", **summary}


@app.get("/api/prices/{species}/predict")
def get_prediction(species: str):
    """
    7-day price forecast using weighted moving average + trend momentum.
    Also returns summary stats so the caller gets everything in one request.
    """
    resolved = _resolve_species(species)
    prices   = [r["price"] for r in HISTORICAL_DATA[resolved]]
    summary  = _compute_summary(prices)

    predictions = _predict_next_7(prices, summary["trendPct"])

    # Recommended sell price = average of predictions (smoothed forecast)
    avg_pred = round(mean(p["predictedPrice"] for p in predictions), 2)

    return {
        "species":          resolved,
        "unit":             "LKR/kg",
        "summary":          summary,
        "next7Days":        predictions,
        "recommendedPrice": avg_pred,
        "confidence":       "medium" if abs(summary["trendPct"]) > 5 else "high",
        "insight": _build_insight(resolved, summary, avg_pred),
    }


def _build_insight(species: str, summary: dict, recommended: float) -> str:
    t = summary["trendPct"]
    if t > 5:
        direction = f"rising strongly (+{t}%)"
        action    = "Hold quality stock and wait for peak bids."
    elif t > 1:
        direction = f"gradually rising (+{t}%)"
        action    = "Good time to list — upward momentum favours sellers."
    elif t < -5:
        direction = f"falling sharply ({t}%)"
        action    = "List immediately to avoid further price erosion."
    elif t < -1:
        direction = f"slightly declining ({t}%)"
        action    = "Monitor closely and consider listing soon."
    else:
        direction = "stable"
        action    = "Stable market — list at recommended price for steady returns."

    return (
        f"{species} prices are {direction} over the past 30 days "
        f"(avg Rs.{summary['avgLast30']}/kg vs Rs.{summary['avgPrev30']}/kg prior period). "
        f"Predicted price next 7 days: Rs.{recommended}/kg. {action}"
    )
