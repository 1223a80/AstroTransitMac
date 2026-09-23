"""Focused tests for mode=hellenistic_condition_audit (B11)."""

from __future__ import annotations

from unittest.mock import patch

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


def _aspect_snapshot(aspects: list[dict]) -> dict:
    return {
        "planets": [
            {
                "id": "SUN",
                "name": "太阳",
                "longitude": 100.0,
                "house": 10,
                "speed": 1.0,
            },
            {
                "id": "MERCURY",
                "name": "水星",
                "longitude": 110.0,
                "house": 10,
                "speed": 1.5,
            },
        ],
        "houses": [{"cusp_longitude": float(index * 30)} for index in range(12)],
        "is_day": True,
        "aspects": aspects,
    }


def _audit_aspects(aspects: list[dict]) -> list[dict]:
    with patch(
        "astro_backend_hellenistic_audit.classical_snapshot",
        return_value=_aspect_snapshot(aspects),
    ):
        result = calculate_hellenistic_condition_audit(_request(), [])
    return [
        row
        for row in result["conditions"]
        if row["subject"] == "MERCURY"
        and row["condition_id"] in {"applying_aspect", "separating_aspect"}
    ]


def test_classical_aspect_id_and_chinese_phase_rows_are_audited_individually() -> None:
    rows = _audit_aspects(
        [
            {
                "id": "SUN|合相|MERCURY|degree",
                "body_a": "太阳",
                "body_b": "水星",
                "aspect": "合相",
                "aspect_type": "degree",
                "aspect_geometry": "degree",
                "aspect_kind": "degree-based aspect",
                "orb": 1.25,
                "applying": "入相",
            },
            {
                "id": "SUN|拱相|MERCURY|degree",
                "body_a": "太阳",
                "body_b": "水星",
                "aspect": "拱相",
                "aspect_type": "degree",
                "aspect_geometry": "degree",
                "aspect_kind": "degree-based aspect",
                "orb": 2.5,
                "applying": "离相",
            },
        ]
    )

    assert [row["condition_id"] for row in rows] == [
        "applying_aspect",
        "separating_aspect",
    ]
    assert [row["applying_separating"] for row in rows] == ["applying", "separating"]
    assert [row["actors"] for row in rows] == [["SUN"], ["SUN"]]
    assert [row["geometry"] for row in rows] == ["合相", "拱相"]
    assert [row["orb"] for row in rows] == [1.25, 2.5]


def test_explicit_false_is_preserved_as_separating() -> None:
    rows = _audit_aspects(
        [
            {
                "id": "SUN|六合|MERCURY|degree",
                "body1": "SUN",
                "body2": "MERCURY",
                "aspect": "六合",
                "aspect_type": "degree",
                "applying": False,
                "orb": 1.0,
            }
        ]
    )

    assert len(rows) == 1
    assert rows[0]["condition_id"] == "separating_aspect"
    assert rows[0]["applying_separating"] == "separating"


def test_zero_orb_is_not_replaced_by_exact_orb_fallback() -> None:
    rows = _audit_aspects(
        [
            {
                "id": "SUN|刑相|MERCURY|degree",
                "body1": "SUN",
                "body2": "MERCURY",
                "aspect": "刑相",
                "aspect_type": "degree",
                "applying": "separating",
                "orb": 0.0,
                "exact_orb": 2.75,
            }
        ]
    )

    assert len(rows) == 1
    assert rows[0]["condition_id"] == "separating_aspect"
    assert rows[0]["orb"] == 0.0
