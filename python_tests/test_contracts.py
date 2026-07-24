"""Integration tests — run transit_calc.py as subprocess with sample JSON inputs.

These tests verify that the backend produces valid JSON with the expected
contract structure for each mode. They require pyswisseph and ephemeris files.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from typing import Any

import pytest

pytestmark = [pytest.mark.requires_ephemeris]

BACKEND_DIR = Path(__file__).resolve().parents[1] / "Sources" / "TransitStudio" / "Resources" / "backend"
TRANSIT_CALC = BACKEND_DIR / "transit_calc.py"
EXAMPLES_DIR = Path(__file__).resolve().parents[1] / "Examples"


def _run_transit_calc(input_file: str) -> dict[str, Any]:
    path = EXAMPLES_DIR / input_file
    assert path.exists(), f"Sample file not found: {path}"
    result = subprocess.run(
        ["python3", str(TRANSIT_CALC)],
        stdin=open(path),
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert result.returncode == 0, f"stderr: {result.stderr[:500]}"
    return json.loads(result.stdout)


class TestClassicalContract:
    def test_valid_json(self) -> None:
        data = _run_transit_calc("sample-classical-request.json")
        assert isinstance(data, dict)

    def test_has_meta(self) -> None:
        data = _run_transit_calc("sample-classical-request.json")
        meta = data.get("meta", {})
        assert "birth_utc" in meta
        assert "reference_utc" in meta
        assert "sect" in meta
        assert "house_system" in meta
        assert "zodiac" in meta

    def test_has_seven_planets(self) -> None:
        data = _run_transit_calc("sample-classical-request.json")
        planets = data.get("planets", [])
        assert len(planets) == 7
        ids = {p["id"] for p in planets}
        assert ids == {"SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"}

    def test_each_planet_has_required_fields(self) -> None:
        data = _run_transit_calc("sample-classical-request.json")
        for p in data.get("planets", []):
            assert "id" in p
            assert "longitude" in p
            assert "sign" in p
            assert "degree_text" in p
            assert "house" in p
            assert "motion" in p
            assert "score" in p

    def test_has_timing_structure(self) -> None:
        data = _run_transit_calc("sample-classical-request.json")
        timing = data.get("timing", {})
        assert "profection" in timing
        assert "firdaria" in timing
        assert "zodiacal_releasing" in timing
        assert "timeline" in timing

    def test_profection_has_required_fields(self) -> None:
        data = _run_transit_calc("sample-classical-request.json")
        p = data["timing"]["profection"]
        assert "age" in p
        assert "house" in p
        assert "sign" in p
        assert "lord" in p

    def test_planetary_returns_structure(self) -> None:
        data = _run_transit_calc("sample-classical-request.json")
        returns = data.get("planetary_returns", [])
        assert isinstance(returns, list)
        if returns:
            r = returns[0]
            assert "previous_return" in r
            assert "current_cycle_return" in r
            assert "next_return" in r
            for key in ("previous_return", "current_cycle_return", "next_return"):
                ret = r[key]
                assert ret is None or isinstance(ret, dict)
                if isinstance(ret, dict):
                    assert ret["label"] == key

    def test_has_lots(self) -> None:
        data = _run_transit_calc("sample-classical-request.json")
        assert isinstance(data.get("lots"), list)

    def test_has_aspects(self) -> None:
        data = _run_transit_calc("sample-classical-request.json")
        assert isinstance(data.get("aspects"), list)

    def test_warnings_is_list(self) -> None:
        data = _run_transit_calc("sample-classical-request.json")
        assert isinstance(data.get("warnings"), list)


class TestHoraryContract:
    """Horary default contract is Data Packet v2 (judgment-free)."""

    MINIMAL_HORARY_REQUEST = json.dumps({
        "mode": "horary",
        "packetVersion": "2",
        "chart": {
            "moment": {"year": 2026, "month": 5, "day": 5, "hour": 12, "minute": 0, "timezone": "Asia/Shanghai"},
            "latitude": 31.2304,
            "longitude": 121.4737,
            "houseSystem": "whole_sign",
            "zodiac": "tropical",
            "boundsSystem": "egyptian",
            "triplicitySystem": "dorothean",
        },
        "questionText": "感情",
        "aspectOrb": 3.0,
    })

    LEGACY_HORARY_REQUEST = json.dumps({
        "mode": "horary",
        "packetVersion": "1",
        "chart": {
            "moment": {"year": 2026, "month": 5, "day": 5, "hour": 12, "minute": 0, "timezone": "Asia/Shanghai"},
            "latitude": 31.2304,
            "longitude": 121.4737,
            "houseSystem": "whole_sign",
            "zodiac": "tropical",
            "boundsSystem": "egyptian",
            "triplicitySystem": "dorothean",
        },
        "questionText": "感情",
        "aspectOrb": 3.0,
    })

    def test_valid_json(self) -> None:
        result = subprocess.run(
            ["python3", str(TRANSIT_CALC)],
            input=self.MINIMAL_HORARY_REQUEST,
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert result.returncode == 0, f"stderr: {result.stderr[:500]}"
        data = json.loads(result.stdout)
        assert isinstance(data, dict)

    def test_has_required_keys(self) -> None:
        result = subprocess.run(
            ["python3", str(TRANSIT_CALC)],
            input=self.MINIMAL_HORARY_REQUEST,
            capture_output=True,
            text=True,
            timeout=30,
        )
        data = json.loads(result.stdout)
        assert data["schema"]["schema_id"] in {
            "horary-data-packet/2.0",
            "horary-data-packet/2.1",
        }
        for key in (
            "question_metadata",
            "calculation_config",
            "provenance",
            "time_and_location",
            "houses",
            "bodies",
            "moon",
            "events",
            "validation",
        ):
            assert key in data
        assert "machine_summary" not in data
        assert "significator_candidates" not in data

    def test_moon_index_has_required_fields(self) -> None:
        result = subprocess.run(
            ["python3", str(TRANSIT_CALC)],
            input=self.MINIMAL_HORARY_REQUEST,
            capture_output=True,
            text=True,
            timeout=30,
        )
        data = json.loads(result.stdout)
        ms = data["moon"]
        assert "void_of_course_rules" in ms
        assert "sign_exit" in ms
        assert "future_exact_aspects_in_current_sign" in ms

    def test_legacy_adapter_still_has_v1_fields(self) -> None:
        result = subprocess.run(
            ["python3", str(TRANSIT_CALC)],
            input=self.LEGACY_HORARY_REQUEST,
            capture_output=True,
            text=True,
            timeout=30,
        )
        data = json.loads(result.stdout)
        assert data["schema"]["version"] == "1.0"
        roles = {c["role"] for c in data["significator_candidates"]}
        assert "Querent" in roles
        assert "Moon" in roles
        assert "Matter / Outcome" in roles


class TestScanContract:
    def test_aspect_scan_valid_json(self) -> None:
        data = _run_transit_calc("sample-scan-request.json")
        assert isinstance(data, dict)

    def test_aspect_scan_has_meta_and_hits(self) -> None:
        data = _run_transit_calc("sample-scan-request.json")
        meta = data.get("meta", {})
        assert "label" in meta
        assert "start_utc" in meta
        assert "end_utc" in meta
        assert "target_count" in meta

    def test_ingress_scan_valid_json(self) -> None:
        data = _run_transit_calc("sample-ingress-request.json")
        assert isinstance(data, dict)

    def test_ingress_scan_has_hits(self) -> None:
        data = _run_transit_calc("sample-ingress-request.json")
        assert isinstance(data.get("hits"), list)
        assert data["meta"]["scan_kind"] == "ingress"

    def test_station_scan_valid_json(self) -> None:
        data = _run_transit_calc("sample-station-request.json")
        assert isinstance(data, dict)

    def test_station_scan_has_hits(self) -> None:
        data = _run_transit_calc("sample-station-request.json")
        assert isinstance(data.get("hits"), list)
        assert data["meta"]["scan_kind"] == "station"


class TestErrorContract:
    def test_invalid_mode_is_rejected_explicitly(self) -> None:
        result = subprocess.run(
            ["python3", str(TRANSIT_CALC)],
            input=json.dumps({"mode": "nonexistent"}),
            capture_output=True,
            text=True,
            timeout=10,
        )
        # Should return a clean JSON error instead of crashing
        assert result.returncode == 0
        data = json.loads(result.stdout)
        assert "error" in data
        assert data["error"] == "不支持的 mode：nonexistent"
        assert data["mode"] == "nonexistent"
        assert data["mode"] == "nonexistent"

    def test_missing_fields_handled_as_error(self) -> None:
        result = subprocess.run(
            ["python3", str(TRANSIT_CALC)],
            input=json.dumps({"mode": "moment"}),
            capture_output=True,
            text=True,
            timeout=10,
        )
        output = (result.stderr or "") + (result.stdout or "")
        assert "traceback" not in output.lower()

    def test_empty_input_handled_as_error(self) -> None:
        result = subprocess.run(
            ["python3", str(TRANSIT_CALC)],
            input="",
            capture_output=True,
            text=True,
            timeout=10,
        )
        assert result.returncode == 1
