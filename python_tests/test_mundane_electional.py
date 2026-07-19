from __future__ import annotations

from astro_backend_api import validate_required_fields
from astro_backend_mundane_electional import calculate_mundane_electional


def _req():
    import json
    from pathlib import Path

    return json.loads(Path("Examples/sample-mundane-electional-request.json").read_text())


def test_api_accepts():
    assert validate_required_fields(_req()) is None


def test_calculate_defining_facts():
    r = calculate_mundane_electional(_req(), [])
    assert r["meta"]["mode"] == "mundane_electional"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)

    ingresses = r["mundane_ingresses"]
    candidates = r["electional_candidates"]
    assert isinstance(ingresses, list)
    assert isinstance(candidates, list)
    # Window should cover at least one cardinal ingress or daily samples
    assert len(ingresses) + len(candidates) >= 1
    for ing in ingresses[:4]:
        assert ing.get("ingress") in {"aries", "cancer", "libra", "capricorn"}
        assert ing.get("exact_utc")
        assert ing.get("method_key") == "sun_sign_ingress_bisection"
    for c in candidates[:3]:
        assert "evidence" in c or "planets" in c or "planetary_hour" in c
        # No ranking / lucky pick fields
        assert "rank" not in c
        assert "lucky_score" not in c
