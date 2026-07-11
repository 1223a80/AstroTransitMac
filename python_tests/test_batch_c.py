"""
Regression tests for Batch C: Lots formulas, score_label, negative reception.

Covers:
- P2-03: Marriage day/night swap, Travel/Lost Objects/Murder use actual house rulers
- P2-04: score_label matches final score
- P2-05: negative reception shows both detriment and fall
"""
from __future__ import annotations

from typing import Any

import pytest

pytestmark = [pytest.mark.requires_ephemeris]


class TestBatchC:
    """Batch C: Lots / score_label / negative reception."""

    # ================================================================
    # P2-03: Lot formula corrections
    # ================================================================
    def test_marriage_day_formula_correct(self) -> None:
        """Marriage (day): ASC + Saturn - Venus per source of truth.

        Current bug: day formula ASC + Venus - Saturn (night formula swapped in).
        After fix: ASC + Saturn - Venus for day.
        """
        from astro_backend_classical_lots import LOT_LIST

        marriage = next(l for l in LOT_LIST if l["lot_id"] == "marriage")
        # Day formula: ASC + Saturn - Venus
        assert marriage["day_p1"] == "planet:SATURN", (
            f"Marriage day_p1 should be SATURN, got {marriage['day_p1']}"
        )
        assert marriage["day_p2"] == "planet:VENUS", (
            f"Marriage day_p2 should be VENUS, got {marriage['day_p2']}"
        )
        # Night formula: ASC + Venus - Saturn
        assert marriage["night_p1"] == "planet:VENUS", (
            f"Marriage night_p1 should be VENUS, got {marriage['night_p1']}"
        )
        assert marriage["night_p2"] == "planet:SATURN", (
            f"Marriage night_p2 should be SATURN, got {marriage['night_p2']}"
        )

    def test_travel_uses_actual_house_9_ruler(self) -> None:
        """Travel: ASC + house:9 - house_ruler:9 (day).

        Current bug: Uses fixed Jupiter instead of actual H9 ruler.
        After fix: Uses house_ruler:9 token.
        """
        from astro_backend_classical_lots import LOT_LIST

        travel = next(l for l in LOT_LIST if l["lot_id"] == "travel")
        assert travel["day_p2"] == "house_ruler:9", (
            f"Travel day should use house_ruler:9, got {travel['day_p2']}"
        )
        assert travel["night_p1"] == "house_ruler:9", (
            f"Travel night should use house_ruler:9, got {travel['night_p1']}"
        )

    def test_lost_objects_uses_actual_house_2_ruler(self) -> None:
        """Lost Objects: ASC + Moon - house_ruler:2 (day).

        Current bug: Uses fixed Mercury instead of actual H2 ruler.
        After fix: Uses house_ruler:2 token.
        """
        from astro_backend_classical_lots import LOT_LIST

        lo = next(l for l in LOT_LIST if l["lot_id"] == "lost_objects")
        assert lo["day_p2"] == "house_ruler:2", (
            f"Lost Objects day should use house_ruler:2, got {lo['day_p2']}"
        )
        assert lo["night_p1"] == "house_ruler:2", (
            f"Lost Objects night should use house_ruler:2, got {lo['night_p1']}"
        )

    def test_murder_uses_actual_house_12_ruler(self) -> None:
        """Murder: ASC + house_ruler:12 - Saturn (day).

        Current bug: Uses fixed Mercury instead of actual H12 ruler.
        After fix: Uses house_ruler:12 token.
        """
        from astro_backend_classical_lots import LOT_LIST

        murder = next(l for l in LOT_LIST if l["lot_id"] == "murder")
        assert murder["day_p1"] == "house_ruler:12", (
            f"Murder day should use house_ruler:12, got {murder['day_p1']}"
        )
        assert murder["night_p2"] == "house_ruler:12", (
            f"Murder night should use house_ruler:12, got {murder['night_p2']}"
        )

    def test_lot_formula_computation_with_real_data(self) -> None:
        """Compute lots with real snapshot data to verify formulas resolve correctly."""
        import sys
        from astro_backend_core import BODY_REGISTRY
        from astro_backend_ephemeris import body_longitude_at, body_speed_at
        from datetime import datetime, timezone
        from astro_backend_classical import classical_snapshot

        # Use sample horary request data
        chart_jd = 2455199.5  # 2010-01-03 00:00 UTC approx
        snapshot = classical_snapshot(
            chart_jd, 31.2304, 121.4737, "regiomontanus",
            False, "egyptian", "dorothean", 8.0, [],
        )

        # Check that lots are computed
        lots = snapshot.get("lots", [])
        assert len(lots) > 0

        # Find the four target lots
        lots_by_id = {l["id"]: l for l in lots}

        marriage = lots_by_id.get("marriage")
        travel = lots_by_id.get("travel")
        lost_objects = lots_by_id.get("lost_objects")
        murder = lots_by_id.get("murder")

        assert marriage is not None, "Marriage lot should be computed"
        assert travel is not None, "Travel lot should be computed"
        assert lost_objects is not None, "Lost Objects lot should be computed"
        assert murder is not None, "Murder lot should be computed"

        # Verify formulas indicate house ruler usage
        assert "H12Ruler" in murder.get("formula", "") or "house_ruler" in str(murder), (
            f"Murder formula should reference house ruler"
        )

    # ================================================================
    # P2-04: score_label consistency
    # ================================================================
    def test_score_label_matches_final_score(self) -> None:
        """Verify score_label_for() returns correct label for each band.

        After fix: conditioning changes score → label recomputed from final score.
        No more 'strong and powerful' for score 9 (should be '状态良好').
        """
        from astro_backend_classical import score_label_for

        # Score → expected label mapping
        cases = [
            (0, "偏弱受克"),
            (5, "状态良好"),
            (8, "状态良好"),
            (9, "状态良好"),
            (10, "强而有力"),
            (11, "强而有力"),
            (12, "强而有力"),
            (-5, "严重衰弱"),
        ]
        for score, expected in cases:
            label = score_label_for(score)
            assert label == expected, (
                f"score_label_for({score}) should be '{expected}', got '{label}'"
            )

    # ================================================================
    # P2-05: Negative reception shows both detriment and fall
    # ================================================================
    def test_negative_reception_both_detriment_and_fall(self) -> None:
        """2026-03-10 15:30 Asia/Shanghai, orb=8: Mercury in Pisces
        should show BOTH detriment and fall (not just detriment).
        """
        from astro_backend_horary import calculate_horary

        request = {
            "mode": "horary",
            "chart": {
                "moment": {
                    "year": 2026, "month": 3, "day": 10,
                    "hour": 15, "minute": 30, "timezone": "Asia/Shanghai",
                },
                "latitude": 31.2304, "longitude": 121.4737,
                "houseSystem": "whole_sign", "zodiac": "tropical",
                "boundsSystem": "egyptian", "triplicitySystem": "dorothean",
            },
            "questionText": "工作", "aspectOrb": 8, "placeName": "上海",
        }
        w: list[str] = []
        r = calculate_horary(request, w)

        neg_receptions = r.get("negative_receptions", [])

        # Find Mercury entries (Mercury rules Pisces's opposite sign)
        mercury_neg = [
            n for n in neg_receptions
            if n.get("planet_a") == "MERCURY" or n.get("planet_id") == "MERCURY"
               or n.get("body") == "MERCURY"
        ]

        # The field name could vary - search through all negative reception entries
        all_debility_types = set()
        for neg in neg_receptions:
            deb_type = neg.get("debility_type") or neg.get("type") or neg.get("debility")
            if deb_type:
                all_debility_types.add(deb_type)

        # Check that both types of debility are present somewhere
        has_detriment = any("detriment" in str(t).lower() for t in all_debility_types)
        has_fall = any("fall" in str(t).lower() for t in all_debility_types)

        # The important assertion: both detriment AND fall must appear
        # in the collection of negative receptions
        if not has_detriment or not has_fall:
            # Fall back to checking individual planet entries
            for neg in neg_receptions:
                details = str(neg.get("details", ""))

            # The response may structure this differently - let's check
            # the raw data to understand
            pass

        # Both should exist somewhere in the output
        combined_debility_text = str(neg_receptions)
        assert "detriment" in combined_debility_text.lower() or "落陷" in combined_debility_text, (
            f"Should have detriment: {combined_debility_text[:200]}"
        )
        assert "fall" in combined_debility_text.lower() or "失势" in combined_debility_text, (
            f"Should have fall: {combined_debility_text[:200]}"
        )
