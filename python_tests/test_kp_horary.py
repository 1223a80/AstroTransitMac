from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import jsonschema
import pytest

from astro_backend_api import validate_required_fields
from astro_backend_kp import calculate_kp_horary, kp_number_segments


ROOT = Path(__file__).resolve().parents[1]


def _request(**overrides: Any) -> dict[str, Any]:
    request = json.loads((ROOT / "Examples" / "sample-kp-horary-request.json").read_text())
    request.update(overrides)
    return request


class TestKPNumberTable:
    def test_table_has_249_contiguous_sign_safe_segments(self) -> None:
        segments = kp_number_segments()
        assert len(segments) == 249
        assert segments[0]["number"] == 1
        assert segments[0]["start"] == pytest.approx(0.0)
        assert segments[-1]["number"] == 249
        assert segments[-1]["end"] == pytest.approx(360.0)
        for left, right in zip(segments, segments[1:]):
            assert left["end"] == pytest.approx(right["start"], abs=1e-12)
        for segment in segments:
            assert int(segment["start"] // 30) == int((segment["end"] - 1e-10) // 30)

    def test_known_boundary_split_rows_are_exact(self) -> None:
        segments = kp_number_segments()
        assert segments[0] == {
            "number": 1,
            "nakshatra_index": 0,
            "nakshatra_lord": "KETU",
            "sub_lord": "KETU",
            "start": pytest.approx(0.0),
            "end": pytest.approx(7.0 / 9.0),
        }
        assert segments[21]["start"] == pytest.approx(29.22222222222222)
        assert segments[21]["end"] == pytest.approx(30.0)
        assert segments[22]["start"] == pytest.approx(30.0)
        assert segments[22]["end"] == pytest.approx(31.22222222222222)
        assert segments[21]["sub_lord"] == segments[22]["sub_lord"] == "RAHU"


class TestKPHoraryContract:
    def test_api_requires_and_validates_kp_inputs(self) -> None:
        missing = validate_required_fields({"mode": "kp_horary"})
        assert missing is not None
        assert set(missing["missing"]) == {"chart", "horary_number"}

        invalid = validate_required_fields(
            _request(horary_number=0, focus_house=13, node_mode="invented")
        )
        assert invalid is not None
        assert "horary_number must be an integer in [1, 249]" in invalid["invalid"]
        assert "focus_house must be an integer in [1, 12]" in invalid["invalid"]
        assert "node_mode must be mean or true" in invalid["invalid"]

    def test_sample_packet_is_complete_and_judgment_free(self) -> None:
        packet = calculate_kp_horary(_request(), [])
        assert packet["schema"]["schema_id"] == "kp-horary-data-packet/1.0"
        assert packet["calculation_config"]["zodiac"] == "sidereal_krishnamurti"
        assert packet["calculation_config"]["house_system"] == "placidus"
        assert packet["calculation_config"]["automatic_judgment"] is False
        assert len(packet["planets"]) == 9
        assert len(packet["houses"]) == 12
        assert len(packet["angles"]) == 4
        assert len(packet["planet_significators"]) == 9
        assert len(packet["house_significators"]) == 12
        assert packet["focus_house"]["house"] == 7
        assert len(packet["node_representations"]) == 2
        assert packet["house_solution"]["residual_degrees"] < 1e-5
        assert packet["horary_number"]["interval_start_longitude"] < packet["horary_number"]["representative_longitude"]
        assert packet["horary_number"]["representative_longitude"] < packet["horary_number"]["interval_end_longitude"]
        assert packet["calculation_config"]["number_longitude_policy"] == "segment_midpoint"

        serialized = json.dumps(packet, ensure_ascii=False).lower()
        for forbidden_key in ('"verdict"', '"outcome"', '"yes_no"', '"aggregate_score"'):
            assert forbidden_key not in serialized

    def test_planet_longitudes_use_question_time_not_number_selected_house_time(self) -> None:
        first = calculate_kp_horary(_request(horary_number=1), [])
        second = calculate_kp_horary(_request(horary_number=249), [])
        first_longitudes = {row["id"]: row["longitude"] for row in first["planets"]}
        second_longitudes = {row["id"]: row["longitude"] for row in second["planets"]}
        assert first_longitudes == pytest.approx(second_longitudes, abs=1e-10)
        assert first["house_solution"]["target_ascendant"] != second["house_solution"]["target_ascendant"]

    @pytest.mark.parametrize("number", [1, 22, 23, 249])
    def test_boundary_numbers_solve_inside_same_kp_hierarchy(self, number: int) -> None:
        packet = calculate_kp_horary(_request(horary_number=number), [])
        selected = packet["horary_number"]
        ascendant = packet["angles"][0]
        assert selected["interval_start_longitude"] < ascendant["longitude"] < selected["interval_end_longitude"]
        assert ascendant["sign_lord"]["id"] == selected["sign_lord"]["id"]
        assert ascendant["nakshatra"]["lord"]["id"] == selected["nakshatra"]["lord"]["id"]
        assert ascendant["sub_lord"]["id"] == selected["sub_lord"]["id"]

    @pytest.mark.parametrize("node_mode", ["mean", "true"])
    def test_both_node_modes_are_explicit(self, node_mode: str) -> None:
        packet = calculate_kp_horary(_request(node_mode=node_mode), [])
        assert packet["calculation_config"]["node_mode"] == node_mode
        assert [row["id"] for row in packet["planets"][-2:]] == ["RAHU", "KETU"]
        rahu, ketu = packet["planets"][-2:]
        assert (rahu["longitude"] - ketu["longitude"]) % 360 == pytest.approx(180.0)

    def test_significator_sources_are_auditable(self) -> None:
        packet = calculate_kp_horary(_request(), [])
        for row in packet["planet_significators"]:
            assert row["policy"] == "transparent_sources_no_weighting"
            assert set(row) == {
                "planet", "direct", "star_lord_scope", "sub_lord_scope", "candidate_houses", "policy",
            }
        for row in packet["house_significators"]:
            assert [tier["tier"] for tier in row["tiers"]] == [1, 2, 3, 4]
            assert row["policy"] == "candidate_tiers_no_automatic_verdict"

    def test_packet_matches_published_schema(self) -> None:
        packet = calculate_kp_horary(_request(), [])
        schema = json.loads(
            (ROOT / "docs" / "schemas" / "kp-horary-data-packet-1.0.json").read_text()
        )
        jsonschema.validate(instance=packet, schema=schema)
