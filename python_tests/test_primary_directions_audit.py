
from astro_backend_api import validate_required_fields
from astro_backend_pd_audit import calculate_primary_directions_audit

def _req():
    import json
    from pathlib import Path
    return json.loads(Path("Examples/sample-primary-directions-audit-request.json").read_text())

def test_api_accepts():
    assert validate_required_fields(_req()) is None

def test_calculate_shape():
    r = calculate_primary_directions_audit(_req(), [])
    assert r["meta"]["mode"] == "primary_directions_audit"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)
