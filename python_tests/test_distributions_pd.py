
from astro_backend_api import validate_required_fields
from astro_backend_distributions_pd import calculate_distributions_pd

def _req():
    import json
    from pathlib import Path
    return json.loads(Path("Examples/sample-distributions-pd-request.json").read_text())

def test_api_accepts():
    assert validate_required_fields(_req()) is None

def test_calculate_shape():
    r = calculate_distributions_pd(_req(), [])
    assert r["meta"]["mode"] == "distributions_pd"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)
