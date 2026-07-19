from __future__ import annotations

from astro_backend_api import validate_required_fields
from astro_backend_distributions_pd import calculate_distributions_pd


def _req():
    import json
    from pathlib import Path

    return json.loads(Path("Examples/sample-distributions-pd-request.json").read_text())


def test_api_accepts():
    assert validate_required_fields(_req()) is None


def test_calculate_defining_facts():
    r = calculate_distributions_pd(_req(), [])
    assert r["meta"]["mode"] == "distributions_pd"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)

    distributions = r.get("distributions") or r.get("distribution_packets") or []
    assert len(distributions) >= 1
    methods = {d.get("method_key") or d.get("bounds_system") for d in distributions}
    assert any("egyptian" in str(m) for m in methods) or any(
        d.get("bounds_system") == "egyptian" for d in distributions
    )
    multi = r.get("primary_directions_by_profile") or []
    assert len(multi) >= 1
    profile_ids = {row.get("method_profile") or row.get("method_key") for row in multi}
    assert len(profile_ids) >= 2
    assert "naibod_longitude_proxy" in profile_ids

