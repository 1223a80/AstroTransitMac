from __future__ import annotations

import json
import pytest
from typing import Any

from astro_backend_core import circular_midpoint, geographic_longitude_midpoint, norm360, angular_separation
from astro_backend_synastry import calculate_synastry
from astro_backend_composite import calculate_composite
from astro_backend_davison import calculate_davison


def test_geographic_longitude_midpoint_crosses_dateline() -> None:
    assert geographic_longitude_midpoint(170.0, -170.0) == -180.0
    assert geographic_longitude_midpoint(-170.0, 170.0) == -180.0


@pytest.fixture
def person_a() -> dict[str, Any]:
    return {
        "name": "Person A",
        "moment": {
            "year": 1990, "month": 1, "day": 1, "hour": 12, "minute": 0,
            "timezone": "Asia/Shanghai",
        },
        "latitude": 31.2304,
        "longitude": 121.4737,
    }


@pytest.fixture
def person_b() -> dict[str, Any]:
    return {
        "name": "Person B",
        "moment": {
            "year": 1992, "month": 6, "day": 15, "hour": 8, "minute": 30,
            "timezone": "America/New_York",
        },
        "latitude": 40.7128,
        "longitude": -74.0060,
    }


@pytest.fixture
def aspect_specs() -> list[dict[str, Any]]:
    return [
        {"id": "conjunction", "name": "合相", "angle": 0, "orb": 8},
        {"id": "opposition", "name": "冲相", "angle": 180, "orb": 8},
        {"id": "trine", "name": "拱相", "angle": 120, "orb": 6},
        {"id": "square", "name": "刑相", "angle": 90, "orb": 6},
        {"id": "sextile", "name": "六合", "angle": 60, "orb": 6},
    ]


class TestSynastry:
    def test_synastry_returns_expected_keys(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "synastry",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_synastry(request, warnings)
        assert isinstance(result, dict)
        # Top-level keys
        for key in ("meta", "person_a_planets", "person_b_planets",
                     "person_a_angles", "person_b_angles",
                     "person_a_houses", "person_b_houses",
                     "cross_aspects", "a_in_b_houses", "b_in_a_houses",
                     "warnings"):
            assert key in result, f"Missing key: {key}"
        assert isinstance(result["cross_aspects"], list)
        assert isinstance(result["warnings"], list)

    def test_cross_aspects_have_required_fields(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "synastry",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_synastry(request, warnings)
        for asp in result["cross_aspects"]:
            for key in ("transit_body_id", "transit_body_name", "natal_body_id",
                         "natal_body_name", "aspect_id", "aspect_name", "angle",
                         "separation", "orb"):
                assert key in asp, f"Missing field {key} in cross_aspect: {asp.get('id', '')}"

    def test_swap_ab_gives_same_orbs(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request_ab = {
            "mode": "synastry",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        request_ba = {
            "mode": "synastry",
            "person_a": person_b,
            "person_b": person_a,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        w_ab: list[str] = []
        w_ba: list[str] = []
        r_ab = calculate_synastry(request_ab, w_ab)
        r_ba = calculate_synastry(request_ba, w_ba)

        orbs_ab = {(a["transit_body_id"], a["natal_body_id"], a["aspect_id"]): round(a["orb"], 6)
                   for a in r_ab["cross_aspects"]}
        orbs_ba = {(a["transit_body_id"], a["natal_body_id"], a["aspect_id"]): round(a["orb"], 6)
                   for a in r_ba["cross_aspects"]}

        for key, orb_ab in orbs_ab.items():
            # Swapped: transit↔natal should match
            swapped_key = (key[1], key[0], key[2])
            orb_ba = orbs_ba.get(swapped_key)
            if orb_ba is not None:
                assert abs(orb_ab - orb_ba) < 1e-6, f"Mismatch for {key} vs {swapped_key}: {orb_ab} != {orb_ba}"

    def test_house_placements(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "synastry",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_synastry(request, warnings)
        for placement_list_name in ("a_in_b_houses", "b_in_a_houses"):
            placements = result[placement_list_name]
            assert isinstance(placements, list)
            for p in placements:
                assert "body_id" in p
                assert "house" in p
                assert isinstance(p["house"], int)
                assert 1 <= p["house"] <= 12

    def test_empty_aspects(self, person_a: dict[str, Any], person_b: dict[str, Any]) -> None:
        request = {
            "mode": "synastry",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": [],
        }
        warnings: list[str] = []
        result = calculate_synastry(request, warnings)
        assert result["cross_aspects"] == []

    def test_synastry_method(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "synastry",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_synastry(request, warnings)
        assert result["meta"]["method"] == "synastry_cross_aspect"


class TestComposite:
    def test_returns_keys(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "composite",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_composite(request, warnings)
        for key in ("meta", "angles", "houses", "planets", "aspects", "warnings"):
            assert key in result, f"Missing key: {key}"
        assert result["meta"]["method"] == "composite_midpoint"
        assert result["meta"]["person_a_utc"] == "1990-01-01T04:00:00+00:00"
        assert result["meta"]["person_b_utc"] == "1992-06-15T12:30:00+00:00"

    def test_planets(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "composite",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_composite(request, warnings)
        planets = result["planets"]
        assert isinstance(planets, list)
        assert len(planets) > 0
        for p in planets:
            assert "body_id" in p
            assert "longitude" in p

    def test_aspects_list(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "composite",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_composite(request, warnings)
        assert isinstance(result["aspects"], list)

    def test_warnings_is_list(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "composite",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_composite(request, warnings)
        assert isinstance(result["warnings"], list)

    def test_houses_12(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "composite",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_composite(request, warnings)
        assert len(result["houses"]) == 12

    @pytest.mark.parametrize("house_system", ("placidus", "equal", "porphyry"))
    def test_non_whole_sign_house_rebuild_uses_three_value_contract(
        self,
        person_a: dict[str, Any],
        person_b: dict[str, Any],
        aspect_specs: list[dict[str, Any]],
        house_system: str,
    ) -> None:
        request = {
            "mode": "composite",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": house_system,
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_composite(request, warnings)

        assert len(result["houses"]) == 12
        assert len({round(house["cusp_longitude"], 8) for house in result["houses"]}) > 1
        assert not any("Composite 宫位重建失败" in warning for warning in warnings)
        assert not any("too many values to unpack" in warning for warning in warnings)

    def test_house_rebuild_failure_warns(
        self,
        person_a: dict[str, Any],
        person_b: dict[str, Any],
        aspect_specs: list[dict[str, Any]],
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        import astro_backend_composite as composite_mod

        original = composite_mod.build_houses
        calls = {"n": 0}

        def flaky_build_houses(*args, **kwargs):
            calls["n"] += 1
            # First two calls are person A/B natal houses; third rebuilds composite cusps.
            if calls["n"] >= 3:
                raise RuntimeError("house rebuild exploded")
            return original(*args, **kwargs)

        monkeypatch.setattr(composite_mod, "build_houses", flaky_build_houses)
        request = {
            "mode": "composite",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "placidus",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_composite(request, warnings)
        assert len(result["houses"]) == 12
        assert any("宫位重建失败" in w and "house rebuild exploded" in w for w in warnings)
        assert not any("too many values to unpack" in w for w in warnings)

    def test_placidus_quadrant_houses_symmetric_under_ab_swap(
        self,
        person_a: dict[str, Any],
        person_b: dict[str, Any],
        aspect_specs: list[dict[str, Any]],
    ) -> None:
        req_ab = {
            "mode": "composite",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "placidus",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        req_ba = {
            "mode": "composite",
            "person_a": person_b,
            "person_b": person_a,
            "house_system": "placidus",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        res_ab = calculate_composite(req_ab, [])
        res_ba = calculate_composite(req_ba, [])

        cusps_ab = [h["cusp_longitude"] for h in res_ab["houses"]]
        cusps_ba = [h["cusp_longitude"] for h in res_ba["houses"]]

        for i, (c_ab, c_ba) in enumerate(zip(cusps_ab, cusps_ba)):
            assert c_ab == pytest.approx(c_ba, abs=1e-4), (
                f"House {i+1} cusp mismatch on AB swap: AB={c_ab}, BA={c_ba}"
            )

    def test_placidus_mc_aligns_with_composite_mc(
        self,
        person_a: dict[str, Any],
        person_b: dict[str, Any],
        aspect_specs: list[dict[str, Any]],
    ) -> None:
        req = {
            "mode": "composite",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "placidus",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        res = calculate_composite(req, [])
        mc_angle = next((a["longitude"] for a in res["angles"] if a["id"] == "MC"), None)
        assert mc_angle is not None
        # 10th house cusp is index 9
        mc_cusp = res["houses"][9]["cusp_longitude"]
        assert mc_cusp == pytest.approx(mc_angle, abs=1e-4)


class TestDavison:
    def test_returns_keys(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "davison",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_davison(request, warnings)
        for key in ("meta", "angles", "houses", "planets", "aspects", "warnings"):
            assert key in result, f"Missing key: {key}"
        assert result["meta"]["method"] == "davison_midtime_midspace"

    def test_method_stable(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "davison",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        w1: list[str] = []
        w2: list[str] = []
        r1 = calculate_davison(request, w1)
        r2 = calculate_davison(request, w2)
        assert r1["meta"]["method"] == r2["meta"]["method"]
        p1 = {p["body_id"]: p["longitude"] for p in r1["planets"]}
        p2 = {p["body_id"]: p["longitude"] for p in r2["planets"]}
        for bid in p1:
            assert abs(p1[bid] - p2[bid]) < 1e-6, f"Davison not stable for {bid}"

    def test_ab_swap_is_symmetric_across_different_timezones(
        self,
        person_a: dict[str, Any],
        person_b: dict[str, Any],
        aspect_specs: list[dict[str, Any]],
    ) -> None:
        request = {
            "mode": "davison",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "placidus",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        swapped_request = {**request, "person_a": person_b, "person_b": person_a}

        original = calculate_davison(request, [])
        swapped = calculate_davison(swapped_request, [])

        for section, id_key, longitude_key in (
            ("planets", "body_id", "longitude"),
            ("angles", "id", "longitude"),
            ("houses", "house", "cusp_longitude"),
        ):
            original_rows = {row[id_key]: row[longitude_key] for row in original[section]}
            swapped_rows = {row[id_key]: row[longitude_key] for row in swapped[section]}
            assert original_rows.keys() == swapped_rows.keys()
            for row_id in original_rows:
                assert swapped_rows[row_id] == pytest.approx(original_rows[row_id], abs=1e-9)

    def test_planets_present(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "davison",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_davison(request, warnings)
        assert len(result["planets"]) > 0

    def test_houses_always_list(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "davison",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        warnings: list[str] = []
        result = calculate_davison(request, warnings)
        assert isinstance(result["houses"], list)

    def test_aspects_always_list(self, person_a: dict[str, Any], person_b: dict[str, Any], aspect_specs: list[dict[str, Any]]) -> None:
        request = {
            "mode": "davison",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": [],
        }
        warnings: list[str] = []
        result = calculate_davison(request, warnings)
        assert isinstance(result["aspects"], list)

    def test_jd_failure_raises_instead_of_jd_zero(
        self,
        person_a: dict[str, Any],
        person_b: dict[str, Any],
        aspect_specs: list[dict[str, Any]],
        monkeypatch: pytest.MonkeyPatch,
    ) -> None:
        import astro_backend_core as core_mod

        def boom(_dt):
            raise RuntimeError("jd conversion exploded")

        monkeypatch.setattr(core_mod, "jd_from_datetime", boom)
        request = {
            "mode": "davison",
            "person_a": person_a,
            "person_b": person_b,
            "house_system": "whole_sign",
            "zodiac": "tropical",
            "node_mode": "true_node",
            "aspects": aspect_specs,
        }
        with pytest.raises(ValueError, match="儒略日"):
            calculate_davison(request, [])
