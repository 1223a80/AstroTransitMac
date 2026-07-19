from __future__ import annotations

from astro_backend_api import validate_required_fields
from astro_backend_core import circular_midpoint
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
    assert isinstance(r["dial_pictures"], list)
    assert r["meta"]["orbital_point_count"] == len(points)


def test_circular_midpoint_across_zero_and_geocentric_nodes():
    mid = circular_midpoint(350.0, 10.0)
    assert abs(mid % 360.0) < 1e-9 or abs(mid - 360.0) < 1e-9
    # linear mean would wrongly give 180
    assert abs(mid - 180.0) > 1.0

    r = calculate_orbital_dial(_req(), [])
    assert r["orbital_points"]
    for p in r["orbital_points"]:
        assert p.get("coordinate_center") == "geocentric"
        assert "heliocentric" not in str(p.get("coordinate_center", "")).lower()

    # Any midpoint pairs in dial_pictures that straddle 0 should use circular mid
    for hit in r["dial_pictures"]:
        if hit.get("method_key", "").startswith("circular_midpoint") and "midpoint_longitude" in hit:
            assert 0.0 <= float(hit["midpoint_longitude"]) < 360.0
