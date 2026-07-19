from __future__ import annotations

from pathlib import Path

from astro_backend_api import validate_required_fields
from astro_backend_classical import classical_snapshot
from astro_backend_core import moment_to_jd, set_zodiac_mode
from astro_backend_time_lords_extended import calculate_time_lords_extended


def _req():
    import json

    return json.loads(Path("Examples/sample-time-lords-extended-request.json").read_text())


def test_api_accepts():
    assert validate_required_fields(_req()) is None


def test_calculate_defining_facts():
    r = calculate_time_lords_extended(_req(), [])
    assert r["meta"]["mode"] == "time_lords_extended"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)

    assert r.get("profection")
    daily = r["daily_profection"]
    assert daily.get("method_key") == "daily_profection_day_step_proxy_v1"
    assert daily.get("lord") or daily.get("activated_sign")
    zr = r["zodiacal_releasing"]
    assert zr.get("fortune") is not None
    assert zr.get("spirit") is not None
    assert zr.get("max_level") == 4
    assert r.get("firdaria") is not None
    assert isinstance(r.get("revolutions_concordance"), (list, dict))


def test_fortune_spirit_match_classical_lots_not_asc():
    req = _req()
    warnings: list[str] = []
    r = calculate_time_lords_extended(req, warnings)
    birth = req["birth"]
    jd, _ = moment_to_jd(birth["moment"])
    sidereal = set_zodiac_mode(birth.get("zodiac", "tropical"), [])
    snap = classical_snapshot(
        jd,
        float(birth["latitude"]),
        float(birth["longitude"]),
        birth.get("houseSystem", birth.get("house_system", "whole_sign")),
        sidereal,
        birth.get("boundsSystem", birth.get("bounds_system", "egyptian")),
        birth.get("triplicitySystem", birth.get("triplicity_system", "dorothean")),
        3.0,
        [],
    )
    lots = {str(l["id"]).lower(): l for l in snap.get("lots") or []}
    fortune = lots["fortune"]
    spirit = lots["spirit"]
    asc = float(snap["angles"][0]["longitude"])

    assert r["meta"]["fortune_longitude"] is not None
    assert r["meta"]["spirit_longitude"] is not None
    assert abs(float(r["meta"]["fortune_longitude"]) - float(fortune["longitude"])) < 1e-6
    assert abs(float(r["meta"]["spirit_longitude"]) - float(spirit["longitude"])) < 1e-6
    # Must not silently use ASC for both
    assert abs(float(r["meta"]["fortune_longitude"]) - asc) > 0.5
    assert abs(float(r["meta"]["spirit_longitude"]) - float(r["meta"]["fortune_longitude"])) > 0.5

    zf = r["zodiacal_releasing"]["fortune"]
    zs = r["zodiacal_releasing"]["spirit"]
    assert zf.get("lot_longitude") == r["meta"]["fortune_longitude"]
    assert zs.get("lot_longitude") == r["meta"]["spirit_longitude"]
    assert zf.get("current_active_level") in {"L1", "L2", "L3", "L4"}
    assert isinstance(zf.get("l4_periods"), list)
    assert len(zf["l4_periods"]) >= 1
    assert any(p.get("level") == "L4" for p in zf["l4_periods"])


def test_concordance_uses_stable_english_body_ids():
    r = calculate_time_lords_extended(_req(), [])
    for row in r["revolutions_concordance"]:
        bid = row["body_id"]
        assert bid == bid.upper() or bid in {"SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"} or bid.isascii()
        # Chinese-only ids must not appear as body_id
        assert bid not in {"月亮", "太阳", "火星", "金星", "水星", "木星", "土星"}
