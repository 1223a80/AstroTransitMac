from __future__ import annotations

from copy import deepcopy
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

import pytest

from astro_backend_api import validate_required_fields
from astro_backend_composite import calculate_composite
from astro_backend_davison import calculate_davison
import astro_backend_modern_timing as timing_module
from astro_backend_modern_timing import (
    _build_relationship_targets,
    calculate_modern_timing,
)


ROOT = Path(__file__).resolve().parents[1]
BACKEND = ROOT / "Sources" / "TransitStudio" / "Resources" / "backend" / "transit_calc.py"
SAMPLES = {
    "composite": ROOT / "Examples" / "sample-modern-timing-composite-request.json",
    "davison": ROOT / "Examples" / "sample-modern-timing-davison-request.json",
}


def _sample(target_type: str) -> dict[str, Any]:
    return json.loads(SAMPLES[target_type].read_text())


def _single_target_request(target_type: str) -> dict[str, Any]:
    request = _sample(target_type)
    request["birth"]["houseSystem"] = "whole_sign"
    request["target_chart"]["point_set"] = {
        "body_ids": ["SUN"],
        "include_nodes": False,
        "node_mode": "true_node",
        "custom_asteroids": [],
        "angle_ids": [],
        "house_cusps": [],
        "lot_ids": [],
    }
    request["techniques"] = [
        {
            "id": "transit",
            "moving_body_ids": ["SUN"],
            "event_types": ["aspect"],
            "aspects": [
                {"id": "conjunction", "name": "合相", "angle": 0.0, "orb": 1.0}
            ],
        }
    ]
    return request


def _snapshot_request(request: dict[str, Any]) -> dict[str, Any]:
    target_chart = request["target_chart"]
    return {
        "mode": target_chart["type"],
        "person_a": target_chart["person_a"],
        "person_b": target_chart["person_b"],
        "point_set": target_chart["point_set"],
        "house_system": target_chart.get(
            "house_system", request["birth"]["houseSystem"]
        ),
        "zodiac": target_chart.get("zodiac", request["birth"]["zodiac"]),
        "node_mode": target_chart["point_set"]["node_mode"],
        "aspects": [],
    }


def _event_signature(result: dict[str, Any]) -> list[tuple[Any, ...]]:
    return [
        (
            event["source_type"],
            event["moving_point_id"],
            event["target_point_id"],
            event["target_point_kind"],
            event["aspect_id"],
            event["exact_utc"],
            event["target_longitude"],
            event["target_chart_type"],
            event["target_chart_method"],
        )
        for event in result["events"]
    ]


def test_omitted_target_chart_preserves_legacy_natal_shape() -> None:
    request = json.loads(
        (ROOT / "Examples" / "sample-modern-timing-request.json").read_text()
    )
    request["end"].update({"month": 1, "day": 3, "hour": 0, "minute": 0})
    request["techniques"] = [request["techniques"][0]]

    result = calculate_modern_timing(request, [])

    assert "target_chart_type" not in result["meta"]
    assert "target_chart_method" not in result["meta"]
    assert all("target_chart_type" not in event for event in result["events"])
    assert all("target_chart_method" not in event for event in result["events"])
    assert result["meta"]["effective_point_set"]["body_ids"] == [
        "SUN", "MOON", "MERCURY", "VENUS", "MARS"
    ]


def test_explicit_natal_target_matches_legacy_events_and_adds_provenance() -> None:
    legacy = _single_target_request("composite")
    legacy["target_point_set"] = legacy.pop("target_chart")["point_set"]
    explicit = deepcopy(legacy)
    explicit["target_chart"] = {
        "type": "natal",
        "point_set": explicit.pop("target_point_set"),
    }

    legacy_result = calculate_modern_timing(legacy, [])
    explicit_result = calculate_modern_timing(explicit, [])

    assert [event["id"] for event in explicit_result["events"]] == [
        event["id"] for event in legacy_result["events"]
    ]
    assert [event["target_longitude"] for event in explicit_result["events"]] == [
        event["target_longitude"] for event in legacy_result["events"]
    ]
    assert explicit_result["meta"]["target_chart_type"] == "natal"
    assert explicit_result["meta"]["target_chart_method"] == "natal"
    assert all(event["target_chart_type"] == "natal" for event in explicit_result["events"])


@pytest.mark.parametrize("target_type", ["composite", "davison"])
def test_single_target_matches_independent_relationship_snapshot(target_type: str) -> None:
    request = _single_target_request(target_type)
    calculator = calculate_composite if target_type == "composite" else calculate_davison
    snapshot = calculator(_snapshot_request(request), [])
    expected = snapshot["planets"][0]["longitude"]

    result = calculate_modern_timing(request, [])
    target_events = [
        event for event in result["events"] if event["target_point_id"] == "SUN"
    ]

    assert target_events
    assert all(
        event["target_longitude"] == pytest.approx(expected, abs=1e-9)
        for event in target_events
    )
    assert result["meta"]["target_count"] == 1
    assert result["meta"]["target_chart_type"] == target_type
    assert result["meta"]["target_chart_method"] == snapshot["meta"]["method"]
    assert all(event["target_chart_type"] == target_type for event in result["events"])
    assert all(
        event["target_chart_method"] == snapshot["meta"]["method"]
        for event in result["events"]
    )


@pytest.mark.parametrize("target_type", ["composite", "davison"])
def test_person_swap_preserves_targets_and_timing_events(target_type: str) -> None:
    request = _sample(target_type)
    request["birth"]["houseSystem"] = "whole_sign"
    request["techniques"] = [
        {
            "id": "transit",
            "moving_body_ids": ["SUN"],
            "event_types": ["aspect"],
            "aspects": [
                {"id": "conjunction", "name": "合相", "angle": 0.0, "orb": 1.0}
            ],
        }
    ]
    swapped = deepcopy(request)
    swapped["target_chart"]["person_a"], swapped["target_chart"]["person_b"] = (
        swapped["target_chart"]["person_b"],
        swapped["target_chart"]["person_a"],
    )

    original_result = calculate_modern_timing(request, [])
    swapped_result = calculate_modern_timing(swapped, [])

    assert (
        original_result["meta"]["target_chart_method"]
        == swapped_result["meta"]["target_chart_method"]
    )
    assert _event_signature(original_result) == _event_signature(swapped_result)
    assert {event["target_point_kind"] for event in original_result["events"]} == {
        "body", "angle", "house_cusp"
    }


@pytest.mark.parametrize("target_type", ["composite", "davison"])
def test_house_cusps_become_targets_only_when_explicitly_selected(target_type: str) -> None:
    request = _sample(target_type)
    without_houses = deepcopy(request["target_chart"])
    without_houses["point_set"]["house_cusps"] = []
    targets_without, _, _, _ = _build_relationship_targets(request, without_houses, [])

    with_houses = deepcopy(request["target_chart"])
    with_houses["point_set"]["house_cusps"] = [3]
    targets_with, effective, _, _ = _build_relationship_targets(request, with_houses, [])

    assert not any(target.kind == "house_cusp" for target in targets_without)
    house_targets = [target for target in targets_with if target.kind == "house_cusp"]
    assert [(target.point_id, target.kind) for target in house_targets] == [
        ("HOUSE_CUSP_3", "house_cusp")
    ]
    calculator = calculate_composite if target_type == "composite" else calculate_davison
    snapshot_request = _snapshot_request(request)
    snapshot_request["point_set"] = with_houses["point_set"]
    expected_house = next(
        row for row in calculator(snapshot_request, [])["houses"] if row["house"] == 3
    )
    assert house_targets[0].longitude == pytest.approx(
        expected_house["cusp_longitude"], abs=1e-9
    )
    assert effective["house_cusps"] == [3]


def test_snapshot_warnings_and_prefixed_section_errors_are_preserved(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    request = _single_target_request("composite")

    def fake_composite(
        snapshot_request: dict[str, Any], warnings: list[str]
    ) -> dict[str, Any]:
        assert snapshot_request["point_set"] is request["target_chart"]["point_set"]
        warnings.append("synthetic snapshot warning")
        return {
            "meta": {
                "method": "composite_midpoint",
                "effective_point_set": snapshot_request["point_set"],
            },
            "planets": [{"body_id": "SUN", "name": "太阳", "longitude": 0.0}],
            "angles": [],
            "houses": [],
            "warnings": warnings,
            "section_errors": {
                "aspects": "synthetic aspect failure",
                "patterns": "synthetic pattern failure",
            },
        }

    monkeypatch.setattr(timing_module, "calculate_composite", fake_composite)
    result = calculate_modern_timing(request, [])

    assert "synthetic snapshot warning" in result["warnings"]
    assert result["section_errors"]["target_chart.aspects"] == "synthetic aspect failure"
    assert result["section_errors"]["target_chart.patterns"] == "synthetic pattern failure"


def test_relationship_effective_point_set_removes_unavailable_snapshot_body(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    request = _single_target_request("composite")
    request["target_chart"]["point_set"]["custom_asteroids"] = [999999]

    def fake_composite(
        snapshot_request: dict[str, Any], warnings: list[str]
    ) -> dict[str, Any]:
        return {
            "meta": {
                "method": "composite_midpoint",
                "effective_point_set": {
                    **snapshot_request["point_set"],
                    "resolved_body_ids": ["SUN", "AST:999999"],
                },
            },
            "planets": [{"body_id": "SUN", "name": "太阳", "longitude": 0.0}],
            "angles": [],
            "houses": [],
            "warnings": warnings,
            "section_errors": None,
        }

    monkeypatch.setattr(timing_module, "calculate_composite", fake_composite)
    result = calculate_modern_timing(request, [])
    effective = result["meta"]["effective_point_set"]

    assert result["meta"]["target_count"] == 1
    assert effective["body_ids"] == ["SUN"]
    assert effective["resolved_body_ids"] == ["SUN"]
    assert effective["custom_asteroids"] == []


def test_relationship_target_chart_settings_override_top_level_birth(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    request = _single_target_request("composite")
    request["birth"]["houseSystem"] = "whole_sign"
    request["birth"]["zodiac"] = "tropical"
    request["target_chart"]["house_system"] = "placidus"
    request["target_chart"]["zodiac"] = "sidereal_lahiri"
    captured: dict[str, Any] = {}

    def fake_composite(
        snapshot_request: dict[str, Any], warnings: list[str]
    ) -> dict[str, Any]:
        captured["snapshot_request"] = snapshot_request
        return {
            "meta": {
                "method": "composite_midpoint",
                "effective_point_set": snapshot_request["point_set"],
            },
            "planets": [{"body_id": "SUN", "name": "太阳", "longitude": 0.0}],
            "angles": [],
            "houses": [],
            "warnings": warnings,
            "section_errors": None,
        }

    def fake_aspect_events(context: Any, *args: Any, **kwargs: Any) -> list[Any]:
        captured["moving_sidereal"] = context.sidereal
        return []

    monkeypatch.setattr(timing_module, "calculate_composite", fake_composite)
    monkeypatch.setattr(timing_module, "_aspect_events", fake_aspect_events)

    calculate_modern_timing(request, [])

    snapshot_request = captured["snapshot_request"]
    assert snapshot_request["house_system"] == "placidus"
    assert snapshot_request["zodiac"] == "sidereal_lahiri"
    assert captured["moving_sidereal"] is True


@pytest.mark.parametrize(
    "technique",
    [
        {
            "id": "secondary_progression",
            "moving_body_ids": ["SUN"],
            "event_types": ["aspect"],
            "aspects": [
                {"id": "conjunction", "name": "合相", "angle": 0.0, "orb": 1.0}
            ],
        },
        {
            "id": "solar_arc",
            "moving_body_ids": ["SUN"],
            "event_types": ["aspect"],
            "aspects": [
                {"id": "conjunction", "name": "合相", "angle": 0.0, "orb": 1.0}
            ],
        },
        {
            "id": "transit",
            "moving_body_ids": ["SUN"],
            "event_types": ["ingress"],
            "aspects": [],
        },
    ],
)
def test_relationship_target_defensively_rejects_non_transit_aspect_lifecycle(
    technique: dict[str, Any],
) -> None:
    request = _single_target_request("composite")
    request["techniques"] = [technique]

    with pytest.raises(ValueError, match="relationship target_chart v1"):
        calculate_modern_timing(request, [])


@pytest.mark.parametrize("target_type", ["composite", "davison"])
def test_samples_validate_and_run_through_backend_entrypoint(target_type: str) -> None:
    request = _sample(target_type)
    assert validate_required_fields(request) is None

    completed = subprocess.run(
        [sys.executable, str(BACKEND)],
        input=json.dumps(request, ensure_ascii=False),
        text=True,
        capture_output=True,
        check=False,
        timeout=120,
    )

    assert completed.returncode == 0, completed.stderr
    result = json.loads(completed.stdout)
    assert result["meta"]["target_chart_type"] == target_type
    assert result["meta"]["target_chart_method"] in {
        "composite_midpoint", "davison_midtime_midspace"
    }
    assert result["meta"]["target_count"] == 4
    assert result["section_errors"] is None
