"""Tests for extended Arabic Parts (Lots) definitions."""
from __future__ import annotations

from astro_backend_classical_lots import LOT_LIST, calculate_lots, lot_value, house_cusp_lon


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


class TestMagisteryFormulaText:
    """F1: Magistery formula displays MC not 0°."""

    ANGLES = {"ASC": 100.0, "MC": 10.0}
    CUSPS = [i * 30.0 for i in range(12)]
    POSITIONS = {
        "SUN": {"longitude": 45.0},
        "MOON": {"longitude": 135.0},
        "MERCURY": {"longitude": 75.0},
        "VENUS": {"longitude": 165.0},
        "MARS": {"longitude": 210.0},
        "JUPITER": {"longitude": 255.0},
        "SATURN": {"longitude": 300.0},
    }

    def test_magistery_day_formula_text(self):
        rows = calculate_lots(self.ANGLES, self.POSITIONS, self.CUSPS, is_day=True, mc=self.ANGLES["MC"])
        mag = next(r for r in rows if r["id"] == "magistery")
        assert "MC" in mag["formula"], f"formula should contain MC, got: {mag['formula']}"
        assert "0°" not in mag["formula"], f"formula should not contain 0°, got: {mag['formula']}"
        # Day: ASC + MC - Sun = 100 + 10 - 45 = 65
        expected = (self.ANGLES["ASC"] + self.ANGLES["MC"] - self.POSITIONS["SUN"]["longitude"]) % 360.0
        assert abs(mag["longitude"] - expected) < 1e-9

    def test_magistery_night_formula_text(self):
        rows = calculate_lots(self.ANGLES, self.POSITIONS, self.CUSPS, is_day=False, mc=self.ANGLES["MC"])
        mag = next(r for r in rows if r["id"] == "magistery")
        assert "MC" in mag["formula"], f"formula should contain MC, got: {mag['formula']}"
        assert "0°" not in mag["formula"], f"formula should not contain 0°, got: {mag['formula']}"
        # Night: ASC + Sun - MC = 100 + 45 - 10 = 135
        expected = (self.ANGLES["ASC"] + self.POSITIONS["SUN"]["longitude"] - self.ANGLES["MC"]) % 360.0
        assert abs(mag["longitude"] - expected) < 1e-9


class TestLotsMissingPlanet:
    """F2: Missing planet KeyError does not crash calculate_lots."""

    ANGLES = {"ASC": 100.0, "MC": 10.0}
    CUSPS = [i * 30.0 for i in range(12)]
    POSITIONS = {
        "SUN": {"longitude": 45.0},
        "MOON": {"longitude": 135.0},
        "MERCURY": {"longitude": 75.0},
        "VENUS": {"longitude": 165.0},
        "MARS": {"longitude": 210.0},
        "JUPITER": {"longitude": 255.0},
        # SATURN is intentionally missing
    }

    def test_no_exception_with_missing_planet(self):
        warnings: list[str] = []
        rows = calculate_lots(self.ANGLES, self.POSITIONS, self.CUSPS, is_day=True, mc=self.ANGLES["MC"], warnings=warnings)
        # No exception — test passes by reaching here

    def test_lots_referencing_missing_planet_skipped(self):
        warnings: list[str] = []
        rows = calculate_lots(self.ANGLES, self.POSITIONS, self.CUSPS, is_day=True, mc=self.ANGLES["MC"], warnings=warnings)
        # nemesis uses SATURN
        assert all(r["id"] != "nemesis" for r in rows), "nemesis should be skipped"
        # dignity uses SATURN
        assert all(r["id"] != "dignity" for r in rows), "dignity should be skipped"

    def test_warning_contains_missing_planet_id(self):
        warnings: list[str] = []
        calculate_lots(self.ANGLES, self.POSITIONS, self.CUSPS, is_day=True, mc=self.ANGLES["MC"], warnings=warnings)
        assert any("SATURN" in w for w in warnings), f"warning should mention SATURN, got: {warnings}"

    def test_unrelated_lots_still_produced(self):
        warnings: list[str] = []
        rows = calculate_lots(self.ANGLES, self.POSITIONS, self.CUSPS, is_day=True, mc=self.ANGLES["MC"], warnings=warnings)
        # fortune uses only SUN/MOON, both present
        fortune_ids = [r["id"] for r in rows]
        assert "fortune" in fortune_ids, "fortune should still be produced"
        assert "spirit" in fortune_ids, "spirit should still be produced"
        assert "basis" in fortune_ids, "basis should still be produced"
