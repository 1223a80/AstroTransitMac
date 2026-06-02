from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import pytest

_backend_dir = Path(__file__).resolve().parents[1] / "Sources" / "TransitStudio" / "Resources" / "backend"
if str(_backend_dir) not in sys.path:
    sys.path.insert(0, str(_backend_dir))


@pytest.fixture
def sample_angles() -> dict[str, float]:
    return {"ASC": 280.0, "MC": 200.0, "DSC": 100.0, "IC": 20.0}


@pytest.fixture
def sample_cusps() -> list[float]:
    return [280.0, 310.0, 340.0, 10.0, 40.0, 70.0, 100.0, 130.0, 160.0, 190.0, 220.0, 250.0]


@pytest.fixture
def sample_planet_positions() -> dict[str, dict[str, Any]]:
    return {
        "SUN": {"longitude": 10.0, "name": "太阳", "score": 0, "speed": 0.955, "motion": "顺行", "house": 3},
        "MOON": {"longitude": 30.0, "name": "月亮", "score": 0, "speed": 13.0, "motion": "顺行", "house": 4},
        "MERCURY": {"longitude": 50.0, "name": "水星", "score": 0, "speed": 1.2, "motion": "顺行", "house": 5},
        "VENUS": {"longitude": 70.0, "name": "金星", "score": 0, "speed": 0.8, "motion": "顺行", "house": 6},
        "MARS": {"longitude": 90.0, "name": "火星", "score": 0, "speed": 0.524, "motion": "顺行", "house": 7},
        "JUPITER": {"longitude": 110.0, "name": "木星", "score": 0, "speed": 0.1, "motion": "顺行", "house": 8},
        "SATURN": {"longitude": 130.0, "name": "土星", "score": 0, "speed": 0.05, "motion": "顺行", "house": 9},
    }


@pytest.fixture
def sample_planet_rows(sample_planet_positions: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    from astro_backend_core import SIGNS, sign_degree, zodiac_sign_index

    rows = []
    for bid, data in sample_planet_positions.items():
        lon = data["longitude"]
        sign_idx = zodiac_sign_index(lon)
        deg = sign_degree(lon)
        rows.append({
            "id": bid,
            "name": data["name"],
            "longitude": lon,
            "sign": SIGNS[sign_idx],
            "degree_text": f"{int(deg)}°{int((deg % 1) * 60):02d}' {SIGNS[sign_idx]}",
            "house": data["house"],
            "speed": data["speed"],
            "motion": data["motion"],
            "score": data["score"],
            "solar_phase": "-" if bid == "SUN" else "可见",
            "bonification": [],
            "maltreatment": [],
        })
    return rows


@pytest.fixture
def sample_snapshot(sample_angles: dict[str, float], sample_planet_rows: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "angles": [{"id": k, "longitude": v, "name": k, "degree_text": f"{v:.1f}°"} for k, v in sample_angles.items()],
        "planets": sample_planet_rows,
        "houses": [
            {"house": i + 1, "sign": "白羊", "ruler": "火星", "longitude": float(i * 30)}
            for i in range(12)
        ],
        "aspects": [],
        "receptions": [],
        "lots": [
            {"id": "fortune", "name": "福点", "longitude": 50.0, "degree_text": "20° 双子", "house": 5, "ruler": "MERCURY"},
            {"id": "spirit", "name": "精神点", "longitude": 80.0, "degree_text": "20° 巨蟹", "house": 6, "ruler": "MOON"},
        ],
        "is_day": True,
        "sun_horizon_status": "above",
        "house_label": "Whole Sign",
        "ephemerides": {"Swiss Ephemeris"},
    }


@pytest.fixture
def sample_birth_moment() -> dict[str, Any]:
    return {
        "year": 1990, "month": 1, "day": 1, "hour": 12, "minute": 0,
        "timezone": "Asia/Shanghai",
    }


@pytest.fixture
def sample_classical_request(sample_birth_moment: dict[str, Any]) -> dict[str, Any]:
    return {
        "mode": "classical",
        "birth": {
            "moment": sample_birth_moment,
            "latitude": 31.2304,
            "longitude": 121.4737,
            "houseSystem": "whole_sign",
            "zodiac": "tropical",
            "boundsSystem": "egyptian",
            "triplicitySystem": "dorothean",
        },
        "reference": {
            "year": 2026, "month": 5, "day": 5, "hour": 12, "minute": 0,
            "timezone": "Asia/Shanghai",
        },
        "aspectOrb": 3,
        "ephemerisPath": None,
    }
