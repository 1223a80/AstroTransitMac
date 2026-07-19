
from astro_backend_api import validate_required_fields
from astro_backend_prenatal_parans import calculate_prenatal_parans

def _req():
    import json
    from pathlib import Path
    return json.loads(Path("Examples/sample-prenatal-parans-request.json").read_text())

def test_api_accepts():
    assert validate_required_fields(_req()) is None

def test_calculate_shape():
    r = calculate_prenatal_parans(_req(), [])
    assert r["meta"]["mode"] == "prenatal_parans"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)
