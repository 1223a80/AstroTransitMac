from __future__ import annotations

import pytest
from typing import Any

from astro_backend_core import angular_separation, norm360
from astro_backend_progressions import calculate_progressions, _calc_lunation
from astro_backend_solar_arc import calculate_solar_arc


NAtAL_BIRTH = {
    "moment": {
        "year": 1990, "month": 1, "day": 1, "hour": 12, "minute": 0,
        "timezone": "Asia/Shanghai",
    },
    "latitude": 31.2304,
    "longitude": 121.4737,
    "houseSystem": "whole_sign",
    "zodiac": "tropical",
    "boundsSystem": "egyptian",
    "triplicitySystem": "dorothean",
}

REFERENCE = {
    "year": 2026, "month": 6, "day": 2, "hour": 12, "minute": 0,
    "timezone": "Asia/Shanghai",
}

ASPECTS = [
    {"id": "conjunction", "name": "合相", "angle": 0, "orb": 6},
    {"id": "opposition", "name": "冲相", "angle": 180, "orb": 6},
    {"id": "trine", "name": "拱相", "angle": 120, "orb": 6},
    {"id": "square", "name": "刑相", "angle": 90, "orb": 6},
    {"id": "sextile", "name": "六合", "angle": 60, "orb": 6},
]


class TestLunation:
    def test_new_moon(self) -> None:
        l = _calc_lunation(10.0, 10.0)
        assert l["phase_name"] == "新月"
        assert l["sun_moon_separation"] == 0.0

    def test_full_moon(self) -> None:
        l = _calc_lunation(10.0, 190.0)
        assert l["phase_name"] == "满月"

    def test_first_quarter(self) -> None:
        l = _calc_lunation(10.0, 100.0)
        assert l["phase_name"] == "上弦月"

    def test_phase_angle(self) -> None:
        l = _calc_lunation(10.0, 50.0)
        assert l["phase_angle"] in (0, 45, 90, 135, 180, 225, 270, 315)


class TestProgressions:
    def test_returns_keys(self) -> None:
        request = {
            "mode": "progression",
            "birth": NAtAL_BIRTH,
            "reference": REFERENCE,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": ASPECTS,
        }
        warnings: list[str] = []
        result = calculate_progressions(request, warnings)
        for key in ("meta", "natal_planets", "progressed_planets",
                     "natal_angles", "progressed_angles",
                     "natal_houses", "progressed_houses",
                     "progressed_to_natal_aspects", "progressed_to_progressed_aspects",
                     "progressed_lunation", "warnings"):
            assert key in result, f"Missing key: {key}"
        assert isinstance(result["progressed_to_natal_aspects"], list)
        assert isinstance(result["progressed_to_progressed_aspects"], list)

    def test_natal_and_progressed_have_same_bodies(self) -> None:
        request = {
            "mode": "progression",
            "birth": NAtAL_BIRTH,
            "reference": REFERENCE,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": ASPECTS,
        }
        warnings: list[str] = []
        result = calculate_progressions(request, warnings)
        natal_ids = {p["body_id"] for p in result["natal_planets"]}
        prog_ids = {p["body_id"] for p in result["progressed_planets"]}
        common = natal_ids & prog_ids
        assert len(common) >= 7, f"Too few common bodies: {common}"

    def test_progressed_sun_differs(self) -> None:
        request = {
            "mode": "progression",
            "birth": NAtAL_BIRTH,
            "reference": REFERENCE,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": ASPECTS,
        }
        warnings: list[str] = []
        result = calculate_progressions(request, warnings)
        natal_sun = next(p for p in result["natal_planets"] if p["body_id"] == "SUN")
        prog_sun = next(p for p in result["progressed_planets"] if p["body_id"] == "SUN")
        assert abs(natal_sun["longitude"] - prog_sun["longitude"]) > 0.01, \
            "Progressed Sun should differ from natal Sun"

    def test_progressed_lunation(self) -> None:
        request = {
            "mode": "progression",
            "birth": NAtAL_BIRTH,
            "reference": REFERENCE,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": ASPECTS,
        }
        warnings: list[str] = []
        result = calculate_progressions(request, warnings)
        pl = result.get("progressed_lunation")
        if pl:
            for key in ("sun_moon_separation", "phase_angle", "phase_name"):
                assert key in pl, f"Missing {key} in progressed_lunation"

    def test_warnings_is_list(self) -> None:
        request = {
            "mode": "progression",
            "birth": NAtAL_BIRTH,
            "reference": REFERENCE,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": ASPECTS,
        }
        warnings: list[str] = []
        result = calculate_progressions(request, warnings)
        assert isinstance(result["warnings"], list)

    def test_empty_aspects_still_returns_lists(self) -> None:
        request = {
            "mode": "progression",
            "birth": NAtAL_BIRTH,
            "reference": REFERENCE,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": [],
        }
        warnings: list[str] = []
        result = calculate_progressions(request, warnings)
        assert isinstance(result["progressed_to_natal_aspects"], list)
        assert isinstance(result["progressed_to_progressed_aspects"], list)


class TestSolarArc:
    def test_returns_keys(self) -> None:
        request = {
            "mode": "solar_arc",
            "birth": NAtAL_BIRTH,
            "reference": REFERENCE,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": ASPECTS,
        }
        warnings: list[str] = []
        result = calculate_solar_arc(request, warnings)
        for key in ("meta", "natal_planets", "solar_arc_planets",
                     "solar_arc_angles", "solar_arc_houses",
                     "solar_arc_to_natal_aspects", "arc_value", "warnings"):
            assert key in result, f"Missing key: {key}"
        assert result["meta"]["method"] == "true_solar_arc"

    def test_arc_value_reasonable(self) -> None:
        request = {
            "mode": "solar_arc",
            "birth": NAtAL_BIRTH,
            "reference": REFERENCE,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": ASPECTS,
        }
        warnings: list[str] = []
        result = calculate_solar_arc(request, warnings)
        arc = result["arc_value"]
        assert 0 <= arc < 360, f"Arc out of range: {arc}"
        # ~36 years: solar arc roughly 0-40°
        assert arc > 0, "Solar arc should be non-zero after birth"

    def test_all_points_shifted_by_same_arc(self) -> None:
        request = {
            "mode": "solar_arc",
            "birth": NAtAL_BIRTH,
            "reference": REFERENCE,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": ASPECTS,
        }
        warnings: list[str] = []
        result = calculate_solar_arc(request, warnings)
        arc = result["arc_value"]
        for sa_row in result["solar_arc_planets"]:
            natal_row = next(
                (n for n in result["natal_planets"] if n["body_id"] == sa_row["body_id"]),
                None,
            )
            if natal_row:
                expected = norm360(natal_row["longitude"] + arc)
                assert abs(sa_row["longitude"] - expected) < 1e-6, \
                    f"{sa_row['body_id']}: SA lon {sa_row['longitude']} != natal {natal_row['longitude']} + arc {arc} = {expected}"

    def test_solar_arc_angles_shifted(self) -> None:
        request = {
            "mode": "solar_arc",
            "birth": NAtAL_BIRTH,
            "reference": REFERENCE,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": ASPECTS,
        }
        warnings: list[str] = []
        result = calculate_solar_arc(request, warnings)
        arc = result["arc_value"]
        # Natal angles aren't in the result directly, but we can check ASC/DSC consistency
        sa_angles = result["solar_arc_angles"]
        sa_asc = next(a["longitude"] for a in sa_angles if a["id"] == "ASC")
        sa_dsc = next(a["longitude"] for a in sa_angles if a["id"] == "DSC")
        sep = angular_separation(sa_asc, sa_dsc)
        assert abs(sep - 180.0) < 1.0, f"SA ASC/DSC not opposite: {sep}"

    def test_aspects_is_list(self) -> None:
        request = {
            "mode": "solar_arc",
            "birth": NAtAL_BIRTH,
            "reference": REFERENCE,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": ASPECTS,
        }
        warnings: list[str] = []
        result = calculate_solar_arc(request, warnings)
        assert isinstance(result["solar_arc_to_natal_aspects"], list)

    def test_warnings_is_list(self) -> None:
        request = {
            "mode": "solar_arc",
            "birth": NAtAL_BIRTH,
            "reference": REFERENCE,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": ASPECTS,
        }
        warnings: list[str] = []
        result = calculate_solar_arc(request, warnings)
        assert isinstance(result["warnings"], list)

    def test_arc_value_as_float(self) -> None:
        request = {
            "mode": "solar_arc",
            "birth": NAtAL_BIRTH,
            "reference": REFERENCE,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": ASPECTS,
        }
        warnings: list[str] = []
        result = calculate_solar_arc(request, warnings)
        assert isinstance(result["arc_value"], float)
