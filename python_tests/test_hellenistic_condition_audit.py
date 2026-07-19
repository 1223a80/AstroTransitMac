"""Focused tests for mode=hellenistic_condition_audit (B11)."""

from __future__ import annotations

from astro_backend_api import validate_required_fields
from astro_backend_hellenistic_audit import calculate_hellenistic_condition_audit


def _request() -> dict:
    return {
        "mode": "hellenistic_condition_audit",
        "birth": {
            "moment": {
                "year": 1990,
                "month": 1,
                "day": 1,
                "hour": 12,
                "minute": 0,
                "timezone": "Asia/Shanghai",
            },
            "latitude": 31.2304,
            "longitude": 121.4737,
            "houseSystem": "whole_sign",
            "zodiac": "tropical",
            "boundsSystem": "egyptian",
            "triplicitySystem": "dorothean",
        },
        "aspect_orb": 3.0,
    }


def test_api_accepts() -> None:
    assert validate_required_fields(_request()) is None


def test_conditions_are_evidence_rows_not_scores() -> None:
    result = calculate_hellenistic_condition_audit(_request(), [])
    assert result["meta"]["method"] == "hellenistic_condition_audit_v1"
    assert result["meta"]["condition_count"] >= 10
    types = {c["condition_id"] for c in result["conditions"]}
    assert "oriental_occidental" in types
    assert "angularity" in types
    assert "sect_agreement" in types
    for row in result["conditions"]:
        assert "condition_id" in row
        assert "subject" in row
        assert "evidence" in row
        assert isinstance(row["evidence"], list)
        assert row.get("source_profile")
        # Must not present a single luck score as the product
        assert "luck_score" not in row
        assert "ji_xiong" not in row
    assert result["calculation_assumptions"]
    assert result["requested_config"] is not None
    assert result["effective_config"] is not None


def test_all_classical_bodies_covered() -> None:
    result = calculate_hellenistic_condition_audit(_request(), [])
    subjects = {c["subject"] for c in result["conditions"]}
    for body in ("SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"):
        assert body in subjects
