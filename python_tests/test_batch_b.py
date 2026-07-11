"""
Regression tests for Batch B: Unified event queue & P1-04 fix.

Covers:
- P1-04: Collection must complete BEFORE main aspect; Prohibition/Frustration
  must not both detect the same event as separate "detected" rows.
"""
from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

import pytest

pytestmark = [pytest.mark.requires_ephemeris]


class TestBatchB:
    """Batch B: unified event sequence."""

    def test_moon_on_right_reuses_storyline(self) -> None:
        """Matter ruler Moon must use the known Moon→Venus event at 08:40."""
        from astro_backend_horary import calculate_horary

        request = {
            "mode": "horary",
            "chart": {
                "moment": {"year": 2026, "month": 1, "day": 3, "hour": 0, "minute": 0, "timezone": "UTC"},
                "latitude": 0.0, "longitude": -10.0,
                "houseSystem": "whole_sign", "zodiac": "tropical",
                "boundsSystem": "egyptian", "triplicitySystem": "dorothean",
            },
            "questionText": "工作", "aspectOrb": 3, "placeName": "Test",
        }
        result = calculate_horary(request, [])
        link = next(row for row in result["key_significator_links"] if row["id"] == "VENUS|MOON|link")
        assert link["aspect"] == "冲相"
        assert link["perfects_before_sign_exit"] is True
        assert link["next_perfection"] == "2026-01-03 08:40"

    # ================================================================
    # P1-04: Advanced candidates no longer contradictory
    # ================================================================
    def test_collection_not_detected_when_after_main(self) -> None:
        """2010-01-03 00:00 Asia/Shanghai, 学习, orb=8.

        Current bug: Collection by Sun detected at 2010-01-12 05:05,
        but Venus-Mercury (main aspect) perfects at 2010-01-05 18:39.
        Collection cannot happen after the main aspect already perfected.

        After fix: Collection must check its completion is before the main aspect.
        """
        from astro_backend_horary import calculate_horary

        request = {
            "mode": "horary",
            "chart": {
                "moment": {
                    "year": 2010, "month": 1, "day": 3,
                    "hour": 0, "minute": 0, "timezone": "Asia/Shanghai",
                },
                "latitude": 31.2304, "longitude": 121.4737,
                "houseSystem": "regiomontanus", "zodiac": "tropical",
                "boundsSystem": "egyptian", "triplicitySystem": "dorothean",
            },
            "questionText": "学习", "aspectOrb": 8, "placeName": "上海",
        }
        w: list[str] = []
        r = calculate_horary(request, w)

        # Find the results
        collection = next(
            (a for a in r["advanced_candidates"] if a["type"] == "Collection of Light"),
            None,
        )
        prohibition = next(
            (a for a in r["advanced_candidates"] if a["type"] == "Prohibition"),
            None,
        )
        frustration = next(
            (a for a in r["advanced_candidates"] if a["type"] == "Frustration"),
            None,
        )

        # Collection must NOT be detected (completes at 01-12, main aspect at 01-05)
        assert collection is not None
        assert collection["status"] == "not detected", (
            f"Collection should NOT be detected when it completes after main aspect: "
            f"collection={collection.get('exact_time')}, "
            f"details={collection.get('details')}"
        )

        # Prohibition and Frustration must not both be "detected" for the same event
        # (Mercury-Sun at 2010-01-05 03:06). One must be "not detected" with explanation.
        detected_count = sum(
            1 for a in [prohibition, frustration]
            if a is not None and a["status"] == "detected"
        )
        assert detected_count == 1, (
            f"Only one of Prohibition/Frustration should be detected for the same event, "
            f"got: Prohibition={prohibition['status']}, Frustration={frustration['status']}"
        )

        # If both have same exact_time, verify dedup worked
        if (prohibition and frustration and
            prohibition.get("exact_time") and frustration.get("exact_time") and
            prohibition.get("exact_time") == frustration.get("exact_time")):
            # The more specific one (Frustration) should be detected
            assert frustration["status"] == "detected", (
                f"When same event triggers both, Frustration (more specific) should be detected"
            )
            assert prohibition["status"] != "detected", (
                f"When Frustration is detected on same event, Prohibition should be not detected"
            )

    def test_collection_valid_when_truly_before_main(self) -> None:
        """Verify Collection can still be detected when it genuinely completes first.

        Use a constructed case where both significators apply to a slower collector
        AND both aspects complete BEFORE the main querent-matter aspect.
        """
        from astro_backend_horary import _detect_collection

        # Querent = MARS (fast, ~0.5), Matter = VENUS (fast, ~1.0)
        # Collector = SATURN (slow, ~0.03)
        # Both MARS→SATURN and VENUS→SATURN complete before MARS→VENUS
        candidates = [
            {"role": "Querent", "planet_id": "MARS"},
            {"role": "Matter / Outcome", "planet_id": "VENUS"},
        ]
        planets = [
            {"id": "MARS", "name": "火星", "longitude": 30.0, "speed": 0.5, "house": 1},
            {"id": "VENUS", "name": "金星", "longitude": 45.0, "speed": 1.0, "house": 2},
            {"id": "SATURN", "name": "土星", "longitude": 100.0, "speed": 0.03, "house": 5},
        ]

        chart_dt = datetime(2026, 1, 1)
        applying = ("拱相", "degree", 2.0, "入相", "degree-based aspect")
        event_facts = {
            ("MARS", "SATURN"): {"applying": "入相", "exact": chart_dt + timedelta(days=2), "exact_time": "2026-01-03 00:00", "signature": applying},
            ("SATURN", "VENUS"): {"applying": "入相", "exact": chart_dt + timedelta(days=3), "exact_time": "2026-01-04 00:00", "signature": applying},
            ("MARS", "VENUS"): {"applying": "入相", "exact": chart_dt + timedelta(days=5), "exact_time": "2026-01-06 00:00", "signature": applying},
        }
        result = _detect_collection(
            candidates, [], planets, chart_dt, [], 8.0, False, event_facts,
        )
        assert result["status"] == "detected"
        assert result["collector"] == "土星"
        assert result["exact_time"] == "2026-01-04 00:00"

    def test_prohibition_and_frustration_not_both_detected(self) -> None:
        """Use monkeypatch to verify dedup logic directly.

        Same third party, same exact_time triggers both Prohibition and Frustration.
        Only one must be 'detected'.
        """
        import astro_backend_horary as horary
        from datetime import datetime

        chart_dt = datetime(2026, 1, 1)
        candidates = [
            {"role": "Querent", "planet_id": "MARS"},
            {"role": "Matter / Outcome", "planet_id": "JUPITER"},
        ]
        planets = [
            {"id": "MARS", "name": "火星", "longitude": 100.0, "speed": 1.0, "house": 1},
            {"id": "JUPITER", "name": "木星", "longitude": 0.0, "speed": 0.1, "house": 7},
            {"id": "SATURN", "name": "土星", "longitude": 58.0, "speed": 0.05, "house": 3},
        ]

        def fake_exact(
            _chart_dt: datetime,
            left_row: dict[str, Any],
            right_row: dict[str, Any],
            _sig: Any,
            _warnings: list[str],
            sidereal: bool = False,
        ) -> datetime | None:
            pair = {left_row["id"], right_row["id"]}
            if pair == {"MARS", "JUPITER"}:
                return chart_dt + timedelta(days=10)  # main aspect
            if pair == {"MARS", "SATURN"}:
                return chart_dt + timedelta(days=5)   # third w/ faster
            if pair == {"JUPITER", "SATURN"}:
                return chart_dt + timedelta(days=5)   # third w/ slower
            return None

        monkeypatch = pytest.MonkeyPatch()
        monkeypatch.setattr(horary, "exact_datetime_for_signature", fake_exact)

        try:
            prohibition = horary._detect_prohibition(
                candidates, [], [], {"voc": False}, planets,
                chart_dt, [], 8.0,
            )
            frustration = horary._detect_frustration(
                candidates, [], [], {"voc": False}, planets,
                chart_dt, [], 8.0,
            )

            # The dedup happens in advanced_candidates(), not per-detector
            # So individually they may both report detected
            # The final check is in advanced_candidates():
            result = horary.advanced_candidates(
                candidates, [], [], {"voc": False}, planets,
                chart_dt, [], 8.0,
            )
            detected_adv = [a for a in result if a["status"] == "detected"]
            prohibition_final = next(a for a in result if a["type"] == "Prohibition")
            frustration_final = next(a for a in result if a["type"] == "Frustration")

            assert len(detected_adv) <= 2  # at most prohibition+frustration
            # If same third party triggers both, only one "detected"
            if (prohibition_final.get("exact_time") and
                frustration_final.get("exact_time") and
                prohibition_final.get("exact_time") == frustration_final.get("exact_time")):
                detected_third_type = [a for a in result if a["status"] == "detected" and a["type"] in ("Prohibition", "Frustration")]
                assert len(detected_third_type) <= 1, (
                    f"Same event should not trigger both detected: {detected_third_type}"
                )
        finally:
            monkeypatch.undo()
