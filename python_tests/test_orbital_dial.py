
from astro_backend_api import validate_required_fields
from astro_backend_orbital_dial import calculate_orbital_dial

def _req():
    import json
    from pathlib import Path
    return json.loads(Path("Examples/sample-orbital-dial-request.json").read_text())

def test_api_accepts():
    assert validate_required_fields(_req()) is None

def test_calculate_shape():
    r = calculate_orbital_dial(_req(), [])
    assert r["meta"]["mode"] == "orbital_dial"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)
