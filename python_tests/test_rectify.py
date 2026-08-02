"""Direct tests for the rectify (birth-time rectification) backend module.

Previously covered only by a shell smoke command; these tests exercise
astro_backend_rectify.compute_window: candidate window generation, candidate
structure, shift-vs-center bookkeeping, runtime clamping and error paths.
"""

from __future__ import annotations

import json

import pytest

from astro_backend_rectify import compute_window


def _base_request(**overrides: object) -> dict[str, object]:
    request: dict[str, object] = {
        "mode": "rectify",
        "birth_date": "1990-01-01",
        "center_time": "12:00",
        "timezone": "Asia/Shanghai",
        "latitude": 31.2304,
        "longitude": 121.4737,
        "house_system": "whole_sign",
        "zodiac": "tropical",
        "bounds_system": "egyptian",
        "triplicity_system": "dorothean",
        "max_age": 90,
        "window_minutes": 3,
        "step_minutes": 3,
    }
    request.update(overrides)
    return request


class TestWindowGeneration:
    def test_level1_minute_window_defaults_to_61_candidates(self) -> None:
        # ±30 minutes at 1-minute steps -> 61 candidates (UI level 1).
        response = compute_window(_base_request(window_minutes=30, step_minutes=1))
        assert response["total_candidates"] == 61
        assert response["window_minutes"] == 30
        assert response["step_minutes"] == 1

    def test_level2_seconds_window_produces_13_candidates(self) -> None:
        # ±30 seconds at 5-second steps -> 13 candidates (UI level 2).
        response = compute_window(_base_request(window_seconds=30, step_seconds=5))
        assert response["total_candidates"] == 13
        assert response["window_seconds"] == 30
        assert response["step_seconds"] == 5

    def test_level3_fine_window_produces_11_candidates(self) -> None:
        # ±5 seconds at 1-second steps -> 11 candidates (UI level 3).
        response = compute_window(_base_request(window_seconds=5, step_seconds=1))
        assert response["total_candidates"] == 11

    def test_offsets_are_symmetric_and_include_center(self) -> None:
        response = compute_window(_base_request(window_seconds=30, step_seconds=5))
        offsets = [c["offset_seconds"] for c in response["candidates"]]
        assert offsets == sorted(offsets)
        assert 0 in offsets
        assert min(offsets) == -30
        assert max(offsets) == 30
        assert response["center_offset_index"] == offsets.index(0)
        # Every offset must land exactly on the requested step grid.
        assert all(off % 5 == 0 for off in offsets)

    def test_center_offset_seconds_shifts_the_whole_window(self) -> None:
        baseline = compute_window(_base_request(window_minutes=3, step_minutes=3))
        response = compute_window(
            _base_request(center_offset_seconds=120, window_minutes=3, step_minutes=3)
        )
        offsets = [candidate["offset_seconds"] for candidate in response["candidates"]]
        # Relative offsets stay centered while the actual center advances two minutes.
        assert offsets == [-180, 0, 180]
        assert response["center_offset_index"] == 1
        baseline_center = baseline["candidates"][baseline["center_offset_index"]]
        shifted_center = response["candidates"][response["center_offset_index"]]
        assert baseline_center["birth_local"] == "1990-01-01 12:00"
        assert shifted_center["birth_local"] == "1990-01-01 12:02"
        assert shifted_center["meta"]["jd"] > baseline_center["meta"]["jd"]

    def test_step_seconds_clamped_to_at_least_one(self) -> None:
        response = compute_window(_base_request(window_seconds=30, step_seconds=0))
        assert response["step_seconds"] == 1
        assert response["total_candidates"] == 61

    def test_step_minutes_clamped_to_at_least_one(self) -> None:
        response = compute_window(_base_request(window_minutes=3, step_minutes=0))
        assert response["step_minutes"] == 1
        assert response["total_candidates"] == 7

    def test_window_seconds_clamped_up_from_zero(self) -> None:
        response = compute_window(_base_request(window_seconds=0, step_seconds=5))
        assert response["window_seconds"] == 60
        assert response["total_candidates"] == 25

    def test_small_window_with_uneven_step_extends_bound_to_grid(self) -> None:
        # bound 30 does not divide by step 4; the loop grows bound until it does.
        # Candidates still only enter when |offset| <= window_seconds.
        response = compute_window(_base_request(window_seconds=30, step_seconds=4))
        offsets = [c["offset_seconds"] for c in response["candidates"]]
        assert min(offsets) == -28 and max(offsets) == 28
        assert all(off % 4 == 0 for off in offsets)
        assert all(abs(off) <= 30 for off in offsets)


class TestCandidateStructure:
    def test_candidate_contains_expected_sections(self) -> None:
        response = compute_window(_base_request())
        candidate = response["candidates"][0]
        assert set(candidate) == {
            "angles", "birth_local", "meta", "offset_minutes",
            "offset_seconds", "planets_summary", "primary_directions",
        }
        assert set(candidate["meta"]) == {"jd", "sidereal", "is_day"}
        assert {"ASC", "MC", "DSC", "IC"}.issubset(set(candidate["angles"]))
        assert len(candidate["planets_summary"]) == 7  # classical seven
        assert all(p["house"] >= 1 and p["house"] <= 12 for p in candidate["planets_summary"])

    def test_candidate_meta_reports_sidereal_flag(self) -> None:
        tropical = compute_window(_base_request())
        sidereal = compute_window(_base_request(zodiac="sidereal_lahiri"))
        assert tropical["candidates"][0]["meta"]["sidereal"] is False
        assert sidereal["candidates"][0]["meta"]["sidereal"] is True

    def test_primary_directions_rows_carry_note_tags_and_houses(self) -> None:
        response = compute_window(_base_request())
        directions = response["candidates"][0]["primary_directions"]
        assert len(directions) > 0
        for d in directions:
            assert "note" in d and isinstance(d["note"], str) and d["note"]
            assert "tags" in d and isinstance(d["tags"], list) and d["tags"]
            assert "houses_involved" in d and isinstance(d["houses_involved"], list)
            assert "shift_vs_center_days" in d
            assert d["promissor_id"] and d["significator_id"]
            assert d["aspect_type"] in {"conjunction", "sextile", "square", "trine", "opposition"}

    def test_shift_vs_center_days_is_zero_at_center_and_scaled_elsewhere(self) -> None:
        response = compute_window(_base_request(window_minutes=3, step_minutes=3))
        center = response["candidates"][response["center_offset_index"]]
        center_ages = {d["id"]: d["age_from_abs_arc"] for d in center["primary_directions"]}
        assert all(d["shift_vs_center_days"] == 0.0 for d in center["primary_directions"])

        for cand in response["candidates"]:
            if cand["offset_seconds"] == 0:
                continue
            for d in cand["primary_directions"]:
                base = center_ages.get(d["id"])
                if base is not None:
                    expected = round((d["age_from_abs_arc"] - base) * 365.2425, 4)
                    assert d["shift_vs_center_days"] == expected

    def test_offset_minutes_derives_from_offset_seconds(self) -> None:
        response = compute_window(_base_request(window_seconds=30, step_seconds=5))
        for candidate in response["candidates"]:
            assert candidate["offset_minutes"] == int(candidate["offset_seconds"] / 60)


class TestErrorPaths:
    def test_missing_required_field_returns_invalid_request(self) -> None:
        response = compute_window({"mode": "rectify"})
        assert "error" in response and response["error"].startswith("Invalid request")

    def test_non_numeric_coordinate_returns_invalid_request(self) -> None:
        response = compute_window(_base_request(latitude="abc"))
        assert "error" in response and response["error"].startswith("Invalid request")

    def test_unknown_timezone_returns_explicit_error(self) -> None:
        response = compute_window(_base_request(timezone="Not/AZone"))
        assert response["error"] == "Unknown timezone: Not/AZone"

    def test_utc_fixed_offset_timezone_is_accepted(self) -> None:
        response = compute_window(_base_request(timezone="UTC+8"))
        assert "error" not in response
        assert response["total_candidates"] == 3

    def test_unparseable_datetime_returns_explicit_error(self) -> None:
        response = compute_window(_base_request(center_time="25:99"))
        assert response["error"].startswith("Cannot parse datetime")


class TestProgressReporting:
    def test_progress_lines_are_written_to_stderr(self, capsys: pytest.CaptureFixture[str]) -> None:
        compute_window(_base_request(window_minutes=3, step_minutes=3))
        captured = capsys.readouterr()
        lines = [line for line in captured.err.strip().splitlines() if line.strip()]
        # One progress line per candidate.
        assert len(lines) == 3
        for line in lines:
            payload = json.loads(line)
            assert set(payload) == {"progress"}
            assert 0.0 <= payload["progress"] <= 1.0
