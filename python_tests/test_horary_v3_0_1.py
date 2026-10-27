"""Tests for Horary V3.0.1 standalone engine."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
BACKEND_DIR = ROOT / "Sources/TransitStudio/Resources/backend"
sys.path.insert(0, str(BACKEND_DIR))

import astro_backend_horary_v3_0_1 as v301


@pytest.fixture
def sample_request():
    return {
        "chart": {
            "moment": {
                "year": 2026,
                "month": 10,
                "day": 1,
                "hour": 22,
                "minute": 3,
                "second": 10,
                "timezone": "Asia/Shanghai",
            },
            "latitude": 36.1075,
            "longitude": 120.4688,
            "houseSystem": "regiomontanus",
        },
        "questionText": "崂山区代表时刻测试",
        "placeName": "崂山区",
        "aspectOrb": 3.0,
    }


def test_horary_v3_0_1_schema_and_provenance(sample_request):
    res = v301.calculate_horary_v3_0_1(sample_request)
    assert res["schema"]["version"] == "3.0.1"
    assert res["schema"]["schema_id"] == "horary-data-packet/3.0.1"
    assert res["provenance"]["engine_name"] == "TransitStudio.horary_v3_0_1_standalone"
    assert res["provenance"]["engine_version"] == "3.0.1"
    assert len(res["provenance"]["input_hash_sha256"]) == 64


def test_horary_v3_0_1_core_calculations(sample_request):
    res = v301.calculate_horary_v3_0_1(sample_request)

    # 12 houses and cusps
    assert len(res["houses"]["cusps"]) == 12
    assert "ASC" in res["angles"]
    assert "MC" in res["angles"]
    assert "DSC" in res["angles"]
    assert "IC" in res["angles"]

    # 7 classical bodies + nodes
    for b in ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN", "TRUE_NODE", "SOUTH_TRUE_NODE"]:
        assert b in res["bodies"]
        assert 0.0 <= res["bodies"][b]["longitude"] < 360.0
        assert 1 <= res["bodies"][b]["house"] <= 12

    # Night chart for 22:03 local
    assert res["time_and_location"]["is_day"] is False

    # Dignities for 7 planets
    for b in ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]:
        d = res["dignities"][b]
        assert "score" in d
        assert "bound_ruler" in d
        assert "decan_ruler" in d


def test_horary_v3_0_1_egyptian_bounds():
    # Test Egyptian bounds for Aries (0)
    # Jupiter 0-6, Venus 6-12, Mercury 12-20, Mars 20-25, Saturn 25-30
    d_jup = v301.calc_essential_dignities("JUPITER", 5.0, True)
    assert d_jup["bound_ruler"] == "JUPITER"

    d_ven = v301.calc_essential_dignities("VENUS", 10.0, True)
    assert d_ven["bound_ruler"] == "VENUS"

    d_mer = v301.calc_essential_dignities("MERCURY", 15.0, True)
    assert d_mer["bound_ruler"] == "MERCURY"

    d_mar = v301.calc_essential_dignities("MARS", 22.0, True)
    assert d_mar["bound_ruler"] == "MARS"

    d_sat = v301.calc_essential_dignities("SATURN", 28.0, True)
    assert d_sat["bound_ruler"] == "SATURN"


def test_horary_v3_0_1_moon_story(sample_request):
    res = v301.calculate_horary_v3_0_1(sample_request)
    moon = res["moon"]

    assert moon["current_sign_zh"] == "双子"
    assert 0.0 <= moon["remaining_arc_deg"] <= 30.0
    assert moon["is_waxing"] is False  # Waning Moon on 2026-10-01
    assert moon["is_void_of_course"] is False
    assert moon["last_exact_aspect"] is not None
    assert moon["last_exact_aspect"]["aspect_zh"] == "六合"
    assert moon["last_exact_aspect"]["target_zh"] == "土星"


def test_horary_v3_0_1_arabic_lots_and_considerations(sample_request):
    res = v301.calculate_horary_v3_0_1(sample_request)

    # Fortune & Spirit lots
    lots = res["lots"]
    assert "fortune" in lots
    assert "spirit" in lots
    assert "上升 + 太阳 - 月亮 (夜盘)" in lots["fortune"]["formula_zh"]

    # Considerations: Early ASC detected
    cons = res["considerations"]
    early_asc = [c for c in cons if c["code"] == "early_asc"]
    assert len(early_asc) == 1


def test_horary_v3_0_1_reader_markdown(sample_request):
    res = v301.calculate_horary_v3_0_1(sample_request)
    md = res["display"]["reader_markdown"]

    assert "# Horary V3.0.1 解盘工作表" in md
    assert "## 1. 宫位与取用参考" in md
    assert "## 2. 七曜状态与运动" in md
    assert "## 3. 本质尊贵与得势 (Essential Dignities)" in md
    assert "## 4. 相位与成相候选" in md
    assert "## 5. 相关星对接纳关系 (Receptions)" in md
    assert "## 6. 月亮推进与空亡 (The Moon's Storyline)" in md
    assert "## 7. 审盘注意事项与考虑因素 (Considerations)" in md
    assert "## 8. 辅助点、恒星与日时主星" in md
    assert "当前月亮是否空亡：" in md


def test_horary_v3_0_1_cli_sample_run():
    cli_path = BACKEND_DIR / "astro_backend_horary_v3_0_1.py"
    proc = subprocess.run(
        [sys.executable, str(cli_path), "--sample"],
        capture_output=True,
        text=True,
        check=True,
    )
    data = json.loads(proc.stdout)
    assert data["schema"]["version"] == "3.0.1"
    assert "display" in data
    assert "reader_markdown" in data["display"]


def test_horary_v3_0_1_cli_markdown_run():
    cli_path = BACKEND_DIR / "astro_backend_horary_v3_0_1.py"
    proc = subprocess.run(
        [sys.executable, str(cli_path), "--sample", "--markdown"],
        capture_output=True,
        text=True,
        check=True,
    )
    assert "# Horary V3.0.1 解盘工作表" in proc.stdout
