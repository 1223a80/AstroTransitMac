
from astro_backend_api import validate_required_fields
from astro_backend_draconic_heliocentric import calculate_draconic_heliocentric, _draconic_shift

def _req():
    return {
        "mode": "draconic_heliocentric",
        "birth": {
            "moment": {"year": 1990, "month": 1, "day": 1, "hour": 12, "minute": 0, "timezone": "Asia/Shanghai"},
            "latitude": 31.2304, "longitude": 121.4737, "houseSystem": "whole_sign", "zodiac": "tropical",
        },
        "node_mode": "true_node",
    }

def test_api():
    assert validate_required_fields(_req()) is None

def test_draconic_node_to_zero():
    r = calculate_draconic_heliocentric(_req(), [])
    node_id = r["meta"]["node_id"]
    dnode = next(p for p in r["draconic"]["planets"] if p["body_id"] == node_id)
    assert abs(dnode["longitude"]) < 1e-6 or abs(dnode["longitude"] - 360) < 1e-6
    assert r["draconic"]["coordinate_system"] == "draconic_ecliptic"
    assert all(p["coordinate_center"] == "heliocentric" for p in r["heliocentric"]["planets"])
    assert r["draconic"]["to_natal_aspects"]
    assert r["heliocentric"]["aspects"]
    assert not any("aspects failed" in warning for warning in r["warnings"])
    assert r["heliocentric"]["earth_included"] is True
    assert r["heliocentric"]["sun_included"] is False
    assert r["heliocentric"]["moon_included"] is False
    assert r["geo_helio_comparison"]
    assert r["calculation_assumptions"]

def test_shift_math():
    assert abs(_draconic_shift(10.0) - 350.0) < 1e-9
