
from astro_backend_api import validate_required_fields
from astro_backend_time_lords_extended import calculate_time_lords_extended

def _req():
    import json
    from pathlib import Path
    return json.loads(Path("Examples/sample-time-lords-extended-request.json").read_text())

def test_api_accepts():
    assert validate_required_fields(_req()) is None

def test_calculate_shape():
    r = calculate_time_lords_extended(_req(), [])
    assert r["meta"]["mode"] == "time_lords_extended"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)
