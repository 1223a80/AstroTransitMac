from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Any

import jsonschema
import pytest

import astro_backend_rectify_evidence as evidence_backend
from astro_backend_api import validate_required_fields
from astro_backend_rectify_evidence import compute_rectification_evidence
from astro_backend_rectify_primary_motion import (
    ascensional_difference,
    calculate_primary_motion_to_angles,
    equatorial_coordinates,
    primary_motion_arc_to_angle,
)


def _moment(year: int, month: int, day: int, hour: int = 0, minute: int = 0) -> dict[str, Any]:
    return {
        "year": year,
        "month": month,
        "day": day,
        "hour": hour,
        "minute": minute,
        "timezone": "Asia/Shanghai",
    }


def _request(**overrides: Any) -> dict[str, Any]:
    request: dict[str, Any] = {
        "mode": "rectify_evidence",
        "birth": {
            "moment": _moment(1990, 1, 1, 12),
            "latitude": 31.2304,
            "longitude": 121.4737,
            "houseSystem": "placidus",
            "zodiac": "tropical",
            "boundsSystem": "egyptian",
            "triplicitySystem": "dorothean",
        },
        "events": [
            {
                "id": "career-1",
                "category": "career",
                "description": "documented event",
                "source_quality": "documented_day",
                "confidence": 0.9,
                "holdout": True,
                "start": _moment(1990, 8, 20),
                "end": _moment(1990, 8, 30),
            }
        ],
        "display_timezone": "Asia/Shanghai",
        "candidate_window_seconds": 0,
        "candidate_step_seconds": 60,
        # Geometry-focused tests do not need to run the timing root solver.
        "timing_techniques": [],
    }
    request.update(overrides)
    return request


class TestPrimaryMotionGeometry:
    def test_equatorial_coordinates_at_cardinal_longitudes(self) -> None:
        ra0, decl0 = equatorial_coordinates(0.0, 0.0, 23.439291)
        ra90, decl90 = equatorial_coordinates(90.0, 0.0, 23.439291)
        assert ra0 == pytest.approx(0.0, abs=1e-10)
        assert decl0 == pytest.approx(0.0, abs=1e-10)
        assert ra90 == pytest.approx(90.0, abs=1e-10)
        assert decl90 == pytest.approx(23.439291, abs=1e-7)

    def test_ecliptic_latitude_changes_ra_and_declination(self) -> None:
        no_lat = equatorial_coordinates(123.0, 0.0, 23.439291)
        with_lat = equatorial_coordinates(123.0, 5.0, 23.439291)
        assert with_lat[0] != pytest.approx(no_lat[0], abs=1e-6)
        assert with_lat[1] != pytest.approx(no_lat[1], abs=1e-6)

    def test_ascensional_difference_and_circumpolar_guard(self) -> None:
        assert ascensional_difference(20.0, 0.0) == pytest.approx(0.0)
        assert ascensional_difference(80.0, 70.0) is None

    @pytest.mark.parametrize(
        ("angle_id", "ra"),
        [("MC", 100.0), ("IC", 280.0), ("ASC", 190.0), ("DSC", 10.0)],
    )
    def test_body_on_axis_has_zero_primary_motion_arc(self, angle_id: str, ra: float) -> None:
        calculated = primary_motion_arc_to_angle(
            right_ascension=ra,
            declination=0.0,
            geographic_latitude=31.0,
            armc=100.0,
            angle_id=angle_id,
        )
        assert calculated is not None
        arc, diagnostics = calculated
        assert arc == pytest.approx(0.0, abs=1e-12)
        assert diagnostics["arc_sign_convention"] == "target_minus_promissor_shortest_arc"

    def test_circumpolar_body_keeps_meridian_but_drops_horizon_direction(self) -> None:
        assert primary_motion_arc_to_angle(10.0, 80.0, 70.0, 100.0, "ASC") is None
        assert primary_motion_arc_to_angle(10.0, 80.0, 70.0, 100.0, "MC") is not None

    def test_calculator_emits_auditable_high_precision_rows(self) -> None:
        from astro_backend_core import jd_from_datetime, moment_to_local_datetime

        birth_dt = moment_to_local_datetime(_moment(1990, 1, 1, 12))
        rows = calculate_primary_motion_to_angles(
            jd_from_datetime(birth_dt),
            birth_dt,
            31.2304,
            121.4737,
            "placidus",
            [],
            body_ids=["SUN"],
            angle_ids=["MC"],
            key_profile="naibod_mean",
        )
        assert len(rows) == 1
        row = rows[0]
        assert row["method_status"] == "formal_geometry_subset"
        assert row["complete_primary_directions_suite"] is False
        assert row["proxy"] is False
        assert row["age_years"] > 0
        assert "T" in row["event_datetime_after_birth"]
        assert len(str(row["arc_abs"]).split(".")[-1]) > 4

    def test_unknown_key_is_rejected(self) -> None:
        from astro_backend_core import jd_from_datetime, moment_to_local_datetime

        birth_dt = moment_to_local_datetime(_moment(1990, 1, 1, 12))
        with pytest.raises(ValueError, match="key_profile"):
            calculate_primary_motion_to_angles(
                jd_from_datetime(birth_dt),
                birth_dt,
                31.2304,
                121.4737,
                "placidus",
                [],
                key_profile="invented",
            )


class TestRectificationEvidenceContract:
    def test_api_requires_structured_core_fields(self) -> None:
        error = validate_required_fields({"mode": "rectify_evidence"})
        assert error is not None
        assert set(error["missing"]) == {"birth", "events", "display_timezone"}

    def test_packet_keeps_methods_separate_and_never_selects_best_time(self) -> None:
        result = compute_rectification_evidence(_request())
        assert "error" not in result
        assert result["schema"]["schema_id"] == "rectification-evidence-packet/1.0"
        assert result["meta"]["automatic_best_time"] is False
        assert result["meta"]["scientific_validation"] == "not_established"
        assert result["events"][0]["holdout"] is True
        assert result["events"][0]["source_quality"] == "documented_day"
        assert [profile["family"] for profile in result["method_profiles"]] == ["primary_motion"]
        assert result["requested_config"]["timing_technique_ids"] == []
        assert result["requested_config"]["timing_techniques"] == []
        assert result["requested_config"]["reference_birth"] == _request()["birth"]
        assert result["requested_config"]["max_candidates"] == 121
        assert result["requested_config"]["confirmed_heavy_scan"] is False
        candidate = result["candidates"][0]
        assert set(candidate["family_hit_counts"]) == {
            "primary_motion", "transit", "secondary_progression", "solar_arc",
        }
        assert "aggregate_score" not in candidate
        assert "best_candidate" not in result

    def test_packet_matches_published_json_schema(self) -> None:
        result = compute_rectification_evidence(_request())
        schema_path = (
            Path(__file__).parents[1]
            / "docs"
            / "schemas"
            / "rectification-evidence-packet-1.0.json"
        )
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
        jsonschema.validate(instance=result, schema=schema)

    def test_candidate_grid_is_symmetric_absolute_time(self) -> None:
        result = compute_rectification_evidence(
            _request(candidate_window_seconds=60, candidate_step_seconds=60)
        )
        assert [row["offset_seconds"] for row in result["candidates"]] == [-60, 0, 60]
        assert [row["birth_local"][11:19] for row in result["candidates"]] == [
            "11:59:00", "12:00:00", "12:01:00",
        ]

    @pytest.mark.parametrize(
        "events",
        [
            [],
            [{"id": "x", "start": _moment(2020, 1, 2), "end": _moment(2020, 1, 1)}],
            [{
                "id": "x", "source_quality": "invented", "start": _moment(2020, 1, 1),
                "end": _moment(2020, 1, 2),
            }],
        ],
    )
    def test_invalid_event_contract_returns_structured_error(self, events: list[dict[str, Any]]) -> None:
        result = compute_rectification_evidence(_request(events=events))
        assert result["mode"] == "rectify_evidence"
        assert result["error"].startswith("Invalid rectification evidence request")

    def test_coordinate_and_candidate_limits_are_validated(self) -> None:
        bad_birth = {**_request()["birth"], "latitude": math.inf}
        assert "birth.latitude" in compute_rectification_evidence(_request(birth=bad_birth))["error"]
        too_many = compute_rectification_evidence(
            _request(candidate_window_seconds=60, candidate_step_seconds=1, max_candidates=10)
        )
        assert "max_candidates" in too_many["error"]

    @pytest.mark.parametrize(
        "techniques",
        [
            [
                {
                    "id": "transit",
                    "moving_body_ids": ["SATURN"],
                    "event_types": ["aspect", "aspect"],
                    "aspects": [{"id": "conjunction", "angle": 0.0, "orb": 1.0}],
                }
            ],
            [
                {
                    "id": "transit",
                    "moving_body_ids": ["SATURN"],
                    "event_types": ["aspect"],
                    "aspects": [{"id": "conjunction", "angle": 0.0, "orb": 1.0}],
                },
                {
                    "id": "transit",
                    "moving_body_ids": ["JUPITER"],
                    "event_types": ["aspect"],
                    "aspects": [{"id": "square", "angle": 90.0, "orb": 1.0}],
                },
            ],
        ],
    )
    def test_timing_configuration_cannot_violate_published_schema(
        self,
        techniques: list[dict[str, Any]],
    ) -> None:
        result = compute_rectification_evidence(_request(timing_techniques=techniques))
        assert "timing_techniques" in result["error"]

    def test_timing_families_preserve_independence_groups(
        self,
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        def fake_timing(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
            del warnings
            return {
                "meta": {"method": "fake-exact-root"},
                "events": [
                    {
                        "id": "transit-hit",
                        "source_type": "transit",
                        "exact_utc": "1990-08-25T04:00:00Z",
                    },
                    {
                        "id": "progression-hit",
                        "source_type": "secondary_progression",
                        "exact_utc": "1990-08-25T04:00:00Z",
                    },
                    {
                        "id": "solar-arc-hit",
                        "source_type": "solar_arc",
                        "exact_utc": "1990-08-25T04:00:00Z",
                    },
                ],
                "section_errors": None,
            }

        monkeypatch.setattr(evidence_backend, "calculate_modern_timing", fake_timing)
        result = compute_rectification_evidence(
            _request(timing_techniques=evidence_backend.DEFAULT_TIMING_TECHNIQUES)
        )
        packet = result["candidates"][0]["evidence_by_event"][0]["families"]
        assert packet["transit"]["independence_group"] == "transit"
        assert packet["secondary_progression"]["independence_group"] == "day_for_year"
        assert packet["solar_arc"]["independence_group"] == "day_for_year_solar_anchor"
        assert all(value["exact_hit_count"] == 1 for value in packet.values())
