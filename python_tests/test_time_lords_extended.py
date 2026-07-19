from __future__ import annotations

from astro_backend_api import validate_required_fields
from astro_backend_time_lords_extended import calculate_time_lords_extended


def _req():
    import json
    from pathlib import Path

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
