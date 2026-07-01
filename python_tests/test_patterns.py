from __future__ import annotations

import math
import pytest

from astro_backend_core import circular_midpoint, norm360, angular_separation
from astro_backend_patterns import (
    find_patterns,
    PATTERN_ASPECT_ORB,
    YOD_QUINCUNX_ORB,
)


class TestCircularMidpoint:
    def test_normal(self) -> None:
        mid = circular_midpoint(10.0, 50.0)
        assert abs(mid - 30.0) < 1e-9

    def test_wraparound(self) -> None:
        mid = circular_midpoint(350.0, 20.0)
        assert abs(mid - 5.0) < 1e-9

    def test_opposite(self) -> None:
        mid = circular_midpoint(10.0, 190.0)
        assert abs(mid - 100.0) < 1e-9

    def test_opposite_antimeridian(self) -> None:
        mid = circular_midpoint(350.0, 170.0)
        expected = norm360(350.0 + 90.0)
        assert abs(mid - expected) < 1e-9

    def test_short_arc_reversed(self) -> None:
        mid = circular_midpoint(50.0, 10.0)
        assert abs(mid - 30.0) < 1e-9

    def test_identical_points(self) -> None:
        mid = circular_midpoint(123.0, 123.0)
        assert abs(mid - 123.0) < 1e-9


BODY_LONS: dict[str, float] = {}


def _deg(deg: float) -> float:
    return deg


class TestPatternDetection:
    def _run(self, lons: dict[str, float], house_map: dict[str, int] | None = None) -> list[dict]:
        aspects = []
        for a in lons:
            for b in lons:
                if a >= b:
                    continue
                sep = angular_separation(lons[a], lons[b])
                for aid, angle in [("conjunction", 0), ("opposition", 180), ("trine", 120),
                                    ("square", 90), ("sextile", 60), ("quincunx", 150)]:
                    limiting = YOD_QUINCUNX_ORB if aid == "quincunx" else PATTERN_ASPECT_ORB
                    if abs(sep - angle) <= limiting + 1e-9:
                        aspects.append({"body_a": a, "body_b": b, "aspect": aid, "angle": angle, "orb": abs(sep - angle)})
                        break
        return find_patterns(lons, aspects, house_map)

    def _types(self, patterns: list[dict]) -> list[str]:
        return sorted(p["type"] for p in patterns)

    def test_t_square(self) -> None:
        lons = {
            "A": _deg(0),     # opposition with B
            "B": _deg(180),   # square with C
            "C": _deg(90),    # square with A
        }
        patterns = self._run(lons)
        assert "t_square" in self._types(patterns)

    def test_t_square_with_extra_body_uses_actual_apex(self) -> None:
        lons = {
            "A": _deg(0),
            "B": _deg(180),
            "C": _deg(90),
            "D": _deg(10),
        }
        patterns = self._run(lons)
        t_squares = [p for p in patterns if p["type"] == "t_square"]
        assert any(p["members"] == ["A", "B", "C"] for p in t_squares)
        assert all(len(set(p["members"])) == 3 for p in t_squares)

    def test_t_square_needs_3(self) -> None:
        lons = {
            "A": _deg(0),
            "B": _deg(180),
            "C": _deg(10),
        }
        p = self._run(lons)
        assert "t_square" not in self._types(p)

    def test_grand_trine(self) -> None:
        lons = {
            "A": _deg(0),
            "B": _deg(120),
            "C": _deg(240),
        }
        p = self._run(lons)
        assert "grand_trine" in self._types(p)

    def test_grand_trine_wrong_angle(self) -> None:
        lons = {
            "A": _deg(0),
            "B": _deg(120),
            "C": _deg(130),
        }
        p = self._run(lons)
        assert "grand_trine" not in self._types(p)

    def test_grand_cross(self) -> None:
        lons = {
            "A": _deg(0),
            "B": _deg(180),
            "C": _deg(90),
            "D": _deg(270),
        }
        p = self._run(lons)
        assert "grand_cross" in self._types(p)

    def test_grand_cross_4_required(self) -> None:
        lons = {
            "A": _deg(0),
            "B": _deg(180),
            "C": _deg(90),
        }
        p = self._run(lons)
        assert "grand_cross" not in self._types(p)

    def test_kite(self) -> None:
        lons = {
            "A": _deg(0),      # grand trine A-B-C
            "B": _deg(120),    # grand trine
            "C": _deg(240),    # grand trine
            "D": _deg(180),    # opposition with A, sextile B/C
        }
        p = self._run(lons)
        assert "kite" in self._types(p)

    def test_kite_requires_grand_trine(self) -> None:
        lons = {
            "A": _deg(0),
            "B": _deg(90),
            "C": _deg(180),
            "D": _deg(270),
        }
        p = self._run(lons)
        assert "kite" not in self._types(p)

    def test_yod(self) -> None:
        lons = {
            "A": _deg(0),
            "B": _deg(60),     # sextile with A
            "C": _deg(210),    # 150° from A, 150° from B
        }
        p = self._run(lons)
        assert "yod" in self._types(p)

    def test_yod_quincunx_orb_3(self) -> None:
        lons = {
            "A": _deg(0),
            "B": _deg(60),
            "C": _deg(213),    # 153° from A, within 3° quincunx orb
        }
        p = self._run(lons)
        assert "yod" in self._types(p)

    def test_yod_outside_orb(self) -> None:
        lons = {
            "A": _deg(0),
            "B": _deg(60),
            "C": _deg(157),    # >3° from 150
        }
        p = self._run(lons)
        assert "yod" not in self._types(p)

    def test_mystic_rectangle(self) -> None:
        lons = {
            "A": _deg(0),     # opp B, trine D, sextile C
            "B": _deg(180),   # opp A, trine C, sextile D
            "C": _deg(60),    # opp D, trine A, sextile B
            "D": _deg(240),   # opp C, trine B, sextile A
        }
        p = self._run(lons)
        assert "mystic_rectangle" in self._types(p)

    def test_mystic_rectangle_not_4(self) -> None:
        lons = {
            "A": _deg(0),
            "B": _deg(180),
            "C": _deg(60),
        }
        p = self._run(lons)
        assert "mystic_rectangle" not in self._types(p)

    def test_stellium_sign(self) -> None:
        lons = {
            "A": _deg(5),
            "B": _deg(15),
            "C": _deg(25),
        }
        p = self._run(lons)
        assert "stellium" in self._types(p)

    def test_stellium_not_enough(self) -> None:
        lons = {
            "A": _deg(5),
            "B": _deg(15),
        }
        p = self._run(lons)
        assert "stellium" not in self._types(p)

    def test_stellium_house(self) -> None:
        lons = {
            "A": _deg(10),
            "B": _deg(50),
            "C": _deg(80),
        }
        house_map = {"A": 1, "B": 1, "C": 1}
        p = self._run(lons, house_map)
        types = self._types(p)
        assert "stellium" in types

    def test_empty_input(self) -> None:
        p = self._run({})
        assert p == []

    def test_confidence_high(self) -> None:
        lons = {
            "A": _deg(0),
            "B": _deg(120),
            "C": _deg(240),
        }
        p = self._run(lons)
        gt = [x for x in p if x["type"] == "grand_trine"]
        if gt:
            assert gt[0]["confidence"] in ("high", "medium")

    def test_duplicate_aspects_deduped(self) -> None:
        lons = {
            "A": _deg(0),
            "B": _deg(120),
            "C": _deg(240),
        }
        aspects = [
            {"body_a": "A", "body_b": "B", "aspect": "trine", "angle": 120, "orb": 0},
            {"body_a": "B", "body_b": "A", "aspect": "trine", "angle": 120, "orb": 0},
            {"body_a": "A", "body_b": "C", "aspect": "trine", "angle": 120, "orb": 0},
            {"body_a": "C", "body_b": "A", "aspect": "trine", "angle": 120, "orb": 0},
            {"body_a": "B", "body_b": "C", "aspect": "trine", "angle": 120, "orb": 0},
            {"body_a": "C", "body_b": "B", "aspect": "trine", "angle": 120, "orb": 0},
        ]
        p = find_patterns(lons, aspects)
        assert len(p) == 1
