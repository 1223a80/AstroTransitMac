from __future__ import annotations

from astro_backend_api import validate_required_fields
from astro_backend_pd_audit import calculate_primary_directions_audit


def _req():
    import json
    from pathlib import Path

    return json.loads(Path("Examples/sample-primary-directions-audit-request.json").read_text())


def test_api_accepts():
    assert validate_required_fields(_req()) is None


def test_calculate_defining_facts():
    r = calculate_primary_directions_audit(_req(), [])
    assert r["meta"]["mode"] == "primary_directions_audit"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)

    assert r["meta"]["algorithm_name"]
    desc = r["algorithm_description"]
    assert desc["name"]
    assert desc.get("known_limits")
    assert desc.get("external_crosscheck_status")
    directions = r["directions"]
    assert isinstance(directions, list)
    assert len(directions) >= 1
    for d in directions[:5]:
        assert d.get("method_key") or d.get("algorithm_name")
        assert d.get("promissor") or d.get("promissor_id")
