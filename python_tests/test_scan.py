from __future__ import annotations

from datetime import datetime, timedelta
from pathlib import Path
import re
from typing import Any

import pytest

pytestmark = [pytest.mark.requires_ephemeris]


class TestBodyWeights:
    def test_all_major_planets_have_weight(self) -> None:
        from astro_backend_scan import BODY_WEIGHT
        for planet in ("SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"):
            assert planet in BODY_WEIGHT
            assert 0 < BODY_WEIGHT[planet] <= 1.5

    def test_weights_in_range(self) -> None:
        from astro_backend_scan import BODY_WEIGHT
        for weight in BODY_WEIGHT.values():
            assert 0 < weight <= 1.5


class TestAspectWeights:
    def test_all_major_aspects_have_weight(self) -> None:
        from astro_backend_scan import ASPECT_WEIGHT
        for aspect in ("conjunction", "opposition", "square", "trine", "sextile"):
            assert aspect in ASPECT_WEIGHT
            assert 0 < ASPECT_WEIGHT[aspect] <= 1.0

    def test_conjunction_weight_max(self) -> None:
        from astro_backend_scan import ASPECT_WEIGHT
        assert ASPECT_WEIGHT["conjunction"] == 1.0
        assert ASPECT_WEIGHT["conjunction"] >= ASPECT_WEIGHT["opposition"]
        assert ASPECT_WEIGHT["opposition"] >= ASPECT_WEIGHT["square"]


class TestStepForBody:
    def test_moon_has_1h_step(self) -> None:
        from astro_backend_scan import step_for_body
        from astro_backend_core import BodySpec
        spec = BodySpec("MOON", "月亮", 1)
        assert step_for_body(spec) == timedelta(hours=1)

    def test_inner_planets_3h_step(self) -> None:
        from astro_backend_scan import step_for_body
        from astro_backend_core import BodySpec
        for bid in ("SUN", "MERCURY", "VENUS", "MARS"):
            spec = BodySpec(bid, "test", 1)
            assert step_for_body(spec) == timedelta(hours=3)

    def test_outer_planets_12h_step(self) -> None:
        from astro_backend_scan import step_for_body
        from astro_backend_core import BodySpec
        for bid in ("JUPITER", "SATURN", "TRUE_NODE", "CHIRON", "CERES"):
            spec = BodySpec(bid, "test", 1)
            assert step_for_body(spec) == timedelta(hours=12)

    def test_asteroids_12h_step(self) -> None:
        from astro_backend_scan import step_for_body
        from astro_backend_core import BodySpec
        spec = BodySpec("AST:433", "爱神星", 433)
        assert step_for_body(spec) == timedelta(hours=12)

    def test_fallback_2d_step(self) -> None:
        from astro_backend_scan import step_for_body
        from astro_backend_core import BodySpec
        spec = BodySpec("UNKNOWN", "unknown", 999)
        assert step_for_body(spec) == timedelta(days=2)


class TestExactLongitudes:
    def test_conjunction(self) -> None:
        from astro_backend_scan import exact_longitudes_for_aspect
        exacts = exact_longitudes_for_aspect(100.0, 0.0)
        assert exacts == [100.0]

    def test_opposition(self) -> None:
        from astro_backend_scan import exact_longitudes_for_aspect
        exacts = exact_longitudes_for_aspect(100.0, 180.0)
        assert exacts == [280.0]

    def test_square(self) -> None:
        from astro_backend_scan import exact_longitudes_for_aspect
        exacts = exact_longitudes_for_aspect(100.0, 90.0)
        assert 10.0 in exacts
        assert 190.0 in exacts
        assert len(exacts) == 2


class TestFindAspects:
    def test_exact_conjunction(self) -> None:
        from astro_backend_scan import find_aspects
        transit = [{"body_id": "MARS", "name": "火星", "longitude": 45.0}]
        natal = [{"body_id": "SUN", "name": "太阳", "longitude": 45.0}]
        aspects = [{"id": "conjunction", "name": "合相", "angle": 0, "orb": 3}]
        hits = find_aspects(transit, natal, aspects)
        assert len(hits) == 1
        assert hits[0]["aspect_id"] == "conjunction"
        assert hits[0]["transit_body_id"] == "MARS"
        assert hits[0]["natal_body_id"] == "SUN"

    def test_opposition_within_orb(self) -> None:
        from astro_backend_scan import find_aspects
        transit = [{"body_id": "MARS", "name": "火星", "longitude": 0.0}]
        natal = [{"body_id": "VENUS", "name": "金星", "longitude": 179.0}]
        aspects = [{"id": "opposition", "name": "冲相", "angle": 180, "orb": 3}]
        hits = find_aspects(transit, natal, aspects)
        assert len(hits) == 1
        assert hits[0]["aspect_id"] == "opposition"

    def test_outside_orb(self) -> None:
        from astro_backend_scan import find_aspects
        transit = [{"body_id": "MARS", "name": "火星", "longitude": 0.0}]
        natal = [{"body_id": "VENUS", "name": "金星", "longitude": 10.0}]
        aspects = [{"id": "conjunction", "name": "合相", "angle": 0, "orb": 3}]
        hits = find_aspects(transit, natal, aspects)
        assert len(hits) == 0

    def test_empty_transit(self) -> None:
        from astro_backend_scan import find_aspects
        hits = find_aspects([], [{"body_id": "SUN", "name": "太阳", "longitude": 0.0}], [])
        assert len(hits) == 0

    def test_empty_natal(self) -> None:
        from astro_backend_scan import find_aspects
        hits = find_aspects([{"body_id": "SUN", "name": "太阳", "longitude": 0.0}], [], [])
        assert len(hits) == 0


class TestScanPriority:
    def test_grade_a_for_high_score(self) -> None:
        from astro_backend_scan import scan_priority
        from astro_backend_core import BodySpec, TargetSpec
        spec = BodySpec("SUN", "太阳", 0)
        target = TargetSpec("Natal Sun", 10.0)
        aspect = {"id": "conjunction", "angle": 0, "orb": 3}
        score, grade = scan_priority(spec, target, aspect, 0.1)
        assert score >= 100
        assert grade == "A"

    def test_grade_d_for_low_score(self) -> None:
        from astro_backend_scan import scan_priority
        from astro_backend_core import BodySpec, TargetSpec
        spec = BodySpec("MOON", "月亮", 1)
        target = TargetSpec("generic point", 10.0)
        aspect = {"id": "semisquare", "angle": 45, "orb": 0.5}
        score, grade = scan_priority(spec, target, aspect, 0.5)
        assert grade == "D"

    def test_grade_b_mid_range(self) -> None:
        from astro_backend_scan import scan_priority
        from astro_backend_core import BodySpec, TargetSpec
        spec = BodySpec("VENUS", "金星", 2)
        target = TargetSpec("Natal Venus", 10.0)
        aspect = {"id": "trine", "angle": 120, "orb": 3}
        score, grade = scan_priority(spec, target, aspect, 0.1)
        assert grade in ("B", "C")


class TestTargetWeight:
    def test_asc_max(self) -> None:
        from astro_backend_scan import target_weight
        from astro_backend_core import TargetSpec
        assert target_weight(TargetSpec("Natal ASC", 0.0)) == 1.25
        assert target_weight(TargetSpec("Natal MC", 0.0)) == 1.25
        assert target_weight(TargetSpec("Natal DSC", 0.0)) == 1.25
        assert target_weight(TargetSpec("Natal IC", 0.0)) == 1.25

    def test_house_cusp_medium(self) -> None:
        from astro_backend_scan import target_weight
        from astro_backend_core import TargetSpec
        assert target_weight(TargetSpec("5th House Cusp", 0.0)) == 1.0

    def test_lot_high(self) -> None:
        from astro_backend_scan import target_weight
        from astro_backend_core import TargetSpec
        assert target_weight(TargetSpec("Lot of Fortune", 0.0)) == 1.15
        assert target_weight(TargetSpec("Lot of Spirit", 0.0)) == 1.15

    def test_sun_moon_elevated(self) -> None:
        from astro_backend_scan import target_weight
        from astro_backend_core import TargetSpec
        assert target_weight(TargetSpec("Natal Sun", 0.0)) == 1.1
        assert target_weight(TargetSpec("Natal Moon", 0.0)) == 1.1

    def test_default_weight(self) -> None:
        from astro_backend_scan import target_weight
        from astro_backend_core import TargetSpec
        assert target_weight(TargetSpec("Natal Jupiter", 0.0)) == 1.0


class TestRejectOversized:
    def test_python_and_swift_limits_match(self) -> None:
        from astro_backend_scan import MAX_SCAN_WORK_UNITS, SCAN_CONFIRMATION_WORK_UNITS

        swift_source = (
            Path(__file__).resolve().parents[1]
            / "Sources"
            / "TransitStudio"
            / "ScanWorkEstimator.swift"
        ).read_text()
        confirmation = re.search(
            r"static let confirmationRequired = ([0-9_]+)", swift_source
        )
        maximum = re.search(r"static let maximum = ([0-9_]+)", swift_source)

        assert confirmation is not None
        assert maximum is not None
        assert int(confirmation.group(1).replace("_", "")) == SCAN_CONFIRMATION_WORK_UNITS
        assert int(maximum.group(1).replace("_", "")) == MAX_SCAN_WORK_UNITS

    def test_under_limit_passes(self) -> None:
        from astro_backend_scan import reject_oversized_scan
        reject_oversized_scan(100)  # should not raise

    def test_soft_warning_is_non_blocking(self) -> None:
        from astro_backend_scan import reject_oversized_scan, SCAN_SOFT_WARNING_WORK_UNITS
        warnings = []
        reject_oversized_scan(SCAN_SOFT_WARNING_WORK_UNITS + 1, warnings=warnings)
        assert warnings

    def test_confirmation_threshold_requires_confirmation(self) -> None:
        from astro_backend_scan import reject_oversized_scan, SCAN_CONFIRMATION_WORK_UNITS
        with pytest.raises(ValueError, match="确认"):
            reject_oversized_scan(SCAN_CONFIRMATION_WORK_UNITS + 1)

    def test_confirmed_heavy_scan_passes_until_max_limit(self) -> None:
        from astro_backend_scan import reject_oversized_scan, SCAN_CONFIRMATION_WORK_UNITS
        warnings = []
        reject_oversized_scan(SCAN_CONFIRMATION_WORK_UNITS + 1, warnings=warnings, confirmed=True)
        assert warnings

    def test_over_limit_raises(self) -> None:
        from astro_backend_scan import reject_oversized_scan, MAX_SCAN_WORK_UNITS
        with pytest.raises(ValueError, match="扫描窗口过大"):
            reject_oversized_scan(MAX_SCAN_WORK_UNITS + 1, confirmed=True)


class TestEstimateSteps:
    def test_basic_calculation(self) -> None:
        from astro_backend_scan import estimated_steps
        from astro_backend_core import BodySpec
        start = datetime(2026, 1, 1, 0, 0)
        end = datetime(2026, 1, 2, 0, 0)
        spec = BodySpec("MOON", "月亮", 1)
        steps = estimated_steps(start, end, spec)
        # 24 hours / 1 hour step = 24 steps
        assert steps == 25  # +1 for the start point

    def test_zero_span(self) -> None:
        from astro_backend_scan import estimated_steps
        from astro_backend_core import BodySpec
        start = datetime(2026, 1, 1, 0, 0)
        spec = BodySpec("MOON", "月亮", 1)
        steps = estimated_steps(start, start, spec)
        assert steps == 1


class TestIngressScan:
    def test_retrograde_ingress_target_is_entered_sign(self, monkeypatch: pytest.MonkeyPatch) -> None:
        import astro_backend_scan as scan
        from astro_backend_core import BodySpec

        start = datetime(2026, 1, 1, 0, 0)
        end = start + timedelta(hours=1)

        def fake_longitude(
            dt: datetime,
            _spec: BodySpec,
            _warnings: list[str],
            _warning_keys: set[str],
            sidereal: bool = False,
        ) -> tuple[float, str]:
            if dt == start:
                return 0.5, "test"
            if dt == end:
                return 359.5, "test"
            return 0.0, "test"

        monkeypatch.setattr(scan, "body_longitude_at", fake_longitude)
        monkeypatch.setattr(scan, "step_for_body", lambda _spec: timedelta(hours=1))
        monkeypatch.setattr(
            scan,
            "refine_crossing",
            lambda _start, _end, _spec, _exact_lon, _warnings, _warning_keys, sidereal=False: start + timedelta(minutes=30),
        )

        result = scan.scan_ingresses(start, end, [BodySpec("MERCURY", "水星", 2)], "test", [])
        hit = result["hits"][0]

        assert hit["aspect_name"] == "逆行退回"
        assert hit["target_name"] == "双鱼"
        assert hit["exact_longitude"] == 0.0


class TestScanResponse:
    def test_structure(self) -> None:
        from astro_backend_scan import scan_response
        from datetime import datetime, timezone
        start = datetime(2026, 1, 1, 0, 0, tzinfo=timezone.utc)
        end = datetime(2026, 1, 2, 0, 0, tzinfo=timezone.utc)
        result = scan_response("test", "aspect", start, end, [], ["warning"], {"Swiss Ephemeris"}, 3)
        assert result["meta"]["label"] == "test"
        assert result["meta"]["scan_kind"] == "aspect"
        assert result["meta"]["target_count"] == 3
        assert result["hits"] == []
        assert "warning" in result["warnings"]
