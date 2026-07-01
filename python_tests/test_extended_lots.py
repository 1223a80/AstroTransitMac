"""Tests for extended Arabic Parts (Lots) definitions."""
from __future__ import annotations

from astro_backend_classical_lots import LOT_LIST, lot_value, house_cusp_lon


class TestLotStructure:
    """Verify lot definitions are complete and internally consistent."""

    def test_total_lots_at_least_50(self):
        assert len(LOT_LIST) >= 50, f"Expected 50+, got {len(LOT_LIST)}"

    def test_core_group_exists(self):
        core = [l for l in LOT_LIST if l["group"] == "core"]
        assert len(core) == 7

    def test_life_group_exists(self):
        life = [l for l in LOT_LIST if l["group"] == "life"]
        assert 20 <= len(life) <= 30, f"Life group has {len(life)} lots"

    def test_career_group_exists(self):
        career = [l for l in LOT_LIST if l["group"] == "career"]
        assert 10 <= len(career) <= 15, f"Career group has {len(career)} lots"

    def test_spirit_group_exists(self):
        spirit = [l for l in LOT_LIST if l["group"] == "spirit"]
        assert 8 <= len(spirit) <= 12, f"Spirit group has {len(spirit)} lots"

    def test_all_have_formulas(self):
        for l in LOT_LIST:
            assert l["day_p1"] and l["day_p2"], f"{l['lot_id']} missing day formula"
            assert l["night_p1"] and l["night_p2"], f"{l['lot_id']} missing night formula"

    def test_all_have_group(self):
        for l in LOT_LIST:
            assert l["group"] in ("core", "life", "career", "spirit", "experimental")

    def test_fortune_formula_correct(self):
        fortune = next(l for l in LOT_LIST if l["lot_id"] == "fortune")
        assert fortune["day_p1"] == "planet:MOON"
        assert fortune["day_p2"] == "planet:SUN"


class TestLotValue:
    """Basic math verification."""

    def test_lot_value_basic(self):
        # ASC + A - B normalized to 0-360
        result = lot_value(10.0, 100.0, 50.0)
        assert result == 60.0

    def test_lot_value_wrapping(self):
        result = lot_value(350.0, 100.0, 200.0)
        assert result == 250.0

    def test_lot_value_negative(self):
        result = lot_value(10.0, 5.0, 30.0)
        assert abs(result - 345.0) < 0.001

    def test_house_cusp(self):
        assert house_cusp_lon(1) == 0.0
        assert house_cusp_lon(2) == 30.0
        assert house_cusp_lon(10) == 270.0
