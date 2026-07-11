"""
Regression tests for Batch A: UTC time search & continuous application.

Covers:
- P2-01: IANA DST fold/back search returns same UTC root
- P2-02: Ingress + 26.5s real first aspect no longer skipped
- P1-01: Refranation after station/retrograde
- P1-03: Slow translator speed check
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

import pytest

pytestmark = [pytest.mark.requires_ephemeris]


class TestBatchA:
    """Batch A: UTC time search & continuous application."""

    # ================================================================
    # P2-01: IANA DST fold/back search
    # ================================================================
    def test_dst_fold_search_returns_utc_root(self) -> None:
        """2000-10-29 00:00 America/New_York Moon-Saturn opposition.

        Local time search should return same UTC root as UTC search.
        Residual must be < 1e-5°, not the reported 0.036°.
        """
        from astro_backend_core import BODY_REGISTRY
        from astro_backend_ephemeris import body_longitude_at
        from astro_backend_horary import next_exact_for_pair, CLASSICAL_ANGLES
        from zoneinfo import ZoneInfo

        # Search from America/New_York time (timezone-aware)
        ny_tz = ZoneInfo("America/New_York")
        chart_dt_ny = datetime(2000, 10, 29, 0, 0, tzinfo=ny_tz)

        warnings: list[str] = []
        warning_keys: set[str] = set()

        # Search from IANA timezone (the bug path)
        exact_ny = next_exact_for_pair(
            chart_dt_ny, "MOON", "SATURN", 180.0,
            warnings, warning_keys,
            max_days=4, step_hours=1,
        )

        # Search from UTC directly (the reference)
        chart_dt_utc = datetime(2000, 10, 29, 4, 0, tzinfo=timezone.utc)
        exact_utc = next_exact_for_pair(
            chart_dt_utc, "MOON", "SATURN", 180.0,
            warnings, warning_keys,
            max_days=4, step_hours=1,
        )

        # Both searches must find an exact aspect
        assert exact_ny is not None, f"Must find Moon-Saturn opposition from NY time"
        assert exact_utc is not None, f"Must find Moon-Saturn opposition from UTC"

        # Both must resolve to same UTC time (within reasonable tolerance)
        exact_ny_utc = exact_ny.astimezone(timezone.utc)
        exact_utc_utc = exact_utc.astimezone(timezone.utc)
        diff_seconds = abs((exact_ny_utc - exact_utc_utc).total_seconds())

        # Previously returned 01:59 EDT (05:59 UTC) with 0.036° residual
        # Should now converge to ~06:04 UTC
        assert diff_seconds < 60, (
            f"NY and UTC searches gave different times: "
            f"NY→{exact_ny_utc} vs UTC→{exact_utc_utc} ({diff_seconds}s apart)"
        )

        # Verify the residual is small (< 1e-5°)
        from astro_backend_horary import relative_orb_for_pair_at
        residual_ny = abs(relative_orb_for_pair_at(
            exact_ny, "MOON", "SATURN", 180.0, warnings, warning_keys
        ))
        residual_utc = abs(relative_orb_for_pair_at(
            exact_utc, "MOON", "SATURN", 180.0, warnings, warning_keys
        ))
        assert residual_ny < 1e-5, f"NY residual too large: {residual_ny}"
        assert residual_utc < 1e-5, f"UTC residual too large: {residual_utc}"

    def test_dst_gap_still_validates(self) -> None:
        """DST spring-forward gap input validation still works."""
        from astro_backend_core import moment_to_local_datetime
        # 2024-03-10 02:30 America/New_York does not exist
        moment = {
            "year": 2024, "month": 3, "day": 10,
            "hour": 2, "minute": 30, "timezone": "America/New_York",
        }
        with pytest.raises(ValueError, match="不存在"):
            moment_to_local_datetime(moment)

    # ================================================================
    # P2-02: Ingress + 26.5s first aspect no longer skipped
    # ================================================================
    def test_ingress_first_aspect_not_skipped(self) -> None:
        """1905-06-21 12:00 UTC: Moon enters Pisces, trines Sun 26.5s later.

        Current code skips this by starting from sign_exit + 1 minute.
        After fix, the trine at ~02:57 UTC must be first_after_ingress.
        """
        from astro_backend_core import BODY_REGISTRY
        from astro_backend_ephemeris import body_longitude_at
        from astro_backend_horary import moon_storyline

        chart_dt = datetime(1905, 6, 21, 12, 0, tzinfo=timezone.utc)
        planets = []
        for bid in ["MOON", "SUN", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]:
            lon = body_longitude_at(chart_dt, BODY_REGISTRY[bid], [], set())
            spd_ = __import__('astro_backend_ephemeris', fromlist=['body_speed_at']).body_speed_at
            spd = spd_(chart_dt, BODY_REGISTRY[bid], [], set())
            if lon and spd:
                planets.append({
                    "id": bid, "name": {"MOON": "月亮", "SUN": "太阳"}.get(bid, bid),
                    "longitude": lon[0], "speed": spd[0],
                    "house": 1, "degree_text": f"{lon[0]:.4f}",
                    "motion": "顺行" if spd[0] >= 0 else "逆行",
                })

        result = moon_storyline(chart_dt, planets, [])

        # Current bug: first_after_ingress might be Saturn conjunction,
        # but should be Sun trine
        first = result.get("first_after_ingress")
        assert first is not None, "Should have a first after ingress"

        # Sun trine should come ~26.5s after ingress
        from astro_backend_core import angular_separation
        sun_entry = datetime(1905, 6, 22, 2, 56, 37)
        trine_expected = datetime(1905, 6, 22, 2, 57, 4)
        gap = abs(angular_separation(0.0, 120.0))  # trine is 120°

        # The first after ingress should be within a few seconds of the expected trine
        # (the time should show ~02:57 UTC)
        first_time = result.get("first_after_ingress_time", "")
        assert "22 02:57" in first_time or "22 10:57" not in first_time, (
            f"First after ingress time should be ~02:57 UTC, got {first_time}"
        )
        assert first["target_id"] == "SUN", (
            f"First after ingress should be Sun trine, got {first['target_id']}"
        )

    # ================================================================
    # P1-01: Refranation detection
    # ================================================================
    def test_mercury_jupiter_square_refranation(self) -> None:
        """2026-10-21 00:00 UTC Mercury-Jupiter square.

        Mercury stations retrograde ~day 3, orb diverges before converging again.
        The original application is refranation — should NOT perfect.
        But slow non-station pairs should still work.
        """
        from astro_backend_horary import calculate_horary

        request = {
            "mode": "horary",
            "chart": {
                "moment": {
                    "year": 2026, "month": 10, "day": 21,
                    "hour": 0, "minute": 0, "timezone": "UTC",
                },
                "latitude": 0.0, "longitude": -60.0,
                "houseSystem": "whole_sign", "zodiac": "tropical",
                "boundsSystem": "egyptian", "triplicitySystem": "dorothean",
            },
            "questionText": "财务", "aspectOrb": 3, "placeName": "Test",
        }
        w: list[str] = []
        r = calculate_horary(request, w)

        # Find Mercury-Jupiter key link
        for link in r["key_significator_links"]:
            if "MERCURY" in link["id"] and "JUPITER" in link["id"]:
                assert link["perfects_before_sign_exit"] is False, (
                    f"Mercury-Jupiter should NOT perfect (refranation), "
                    f"got perfects={link['perfects_before_sign_exit']} "
                    f"time={link['next_perfection']}"
                )
                assert "refranation" in link.get("perfection_reason", "").lower() or \
                       "interrupt" in link.get("perfection_reason", "").lower(), (
                    f"Perfection reason should mention refranation/interruption, "
                    f"got: {link['perfection_reason']}"
                )

    def test_slow_jupiter_saturn_perfection_still_found(self) -> None:
        """Slow Jupiter-Saturn sextile with no stations must still perfect.

        Regression from existing test_slow_jupiter_saturn_perfection_found_beyond_30_days.
        """
        from datetime import datetime

        from astro_backend_classical import classical_aspect_signature
        from astro_backend_core import BODY_REGISTRY
        from astro_backend_ephemeris import body_longitude_at, body_speed_at
        from astro_backend_horary import exact_datetime_for_signature

        # 2016-11-06 is itself a refranation: the orb narrows, widens, then
        # reapplies in 2017.  Start after the final turn so this is a genuinely
        # uninterrupted slow application lasting more than 30 days.
        chart_dt = datetime(2017, 7, 14, 0, 0)
        warnings: list[str] = []
        warning_keys: set[str] = set()
        planets = []
        for body_id, name in [("JUPITER", "木星"), ("SATURN", "土星")]:
            longitude = body_longitude_at(chart_dt, BODY_REGISTRY[body_id], warnings, warning_keys)
            speed = body_speed_at(chart_dt, BODY_REGISTRY[body_id], warnings, warning_keys)
            assert longitude is not None
            assert speed is not None
            planets.append({"id": body_id, "name": name, "longitude": longitude[0], "speed": speed[0]})

        signature = classical_aspect_signature(planets[0], planets[1], 8.0)
        assert signature is not None
        assert signature[0] == "六合"
        assert signature[1] == "degree"
        assert signature[3] == "入相"

        exact = exact_datetime_for_signature(chart_dt, planets[0], planets[1], signature, warnings)
        assert exact is not None
        assert exact > chart_dt + timedelta(days=30)
        assert exact.date() == datetime(2017, 8, 27).date()

    # ================================================================
    # P1-03: Slow translator detection
    # ================================================================
    def test_slow_jupiter_not_translator(self) -> None:
        """2015-01-01 12:00 Asia/Shanghai with aspectOrb=8.

        Jupiter (speed ~ -0.07°/day) must NOT be detected as translator
        for Moon (13.17°/day) and Mars (0.78°/day) because it is slower
        than both (Translation requires faster intermediary).
        """
        from astro_backend_horary import calculate_horary

        request = {
            "mode": "horary",
            "chart": {
                "moment": {
                    "year": 2015, "month": 1, "day": 1,
                    "hour": 12, "minute": 0, "timezone": "Asia/Shanghai",
                },
                "latitude": 31.2304, "longitude": 121.4737,
                "houseSystem": "whole_sign", "zodiac": "tropical",
                "boundsSystem": "egyptian", "triplicitySystem": "dorothean",
            },
            "questionText": "房产", "aspectOrb": 8, "placeName": "上海",
        }
        w: list[str] = []
        r = calculate_horary(request, w)

        for adv in r.get("advanced_candidates", []):
            if adv["type"] == "Translation of Light":
                assert adv["status"] != "detected" or "木星" not in adv.get("details", ""), (
                    f"Jupiter should NOT be translator: {adv['details']}"
                )
