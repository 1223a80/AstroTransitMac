from __future__ import annotations

from astro_backend_api import validate_required_fields
from astro_backend_orbital_dial import calculate_orbital_dial


def _req():
    import json
    from pathlib import Path

    return json.loads(Path("Examples/sample-orbital-dial-request.json").read_text())


def test_api_accepts():
    assert validate_required_fields(_req()) is None


def test_calculate_defining_facts():
    r = calculate_orbital_dial(_req(), [])
    assert r["meta"]["mode"] == "orbital_dial"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)

    points = r["orbital_points"]
    assert len(points) >= 1
    kinds = {p.get("kind") or p.get("point_type") or p.get("method_key") for p in points}
    assert kinds
    for p in points[:5]:
        assert p.get("longitude") is not None or p.get("body_id")
    # dial_pictures may be empty if no midpoints within orb; still a typed list
    assert isinstance(r["dial_pictures"], list)
    assert r["meta"]["orbital_point_count"] == len(points)
