
from astro_backend_api import validate_required_fields
from astro_backend_classical_derivatives import calculate_classical_derivatives

def _req():
    import json
    from pathlib import Path
    return json.loads(Path("Examples/sample-classical-derivatives-request.json").read_text())

def test_api_accepts():
    assert validate_required_fields(_req()) is None

def test_calculate_shape():
    r = calculate_classical_derivatives(_req(), [])
    assert r["meta"]["mode"] == "classical_derivatives"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)
