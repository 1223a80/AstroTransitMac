"""Focused tests for astrocartography and local_space."""

from __future__ import annotations

from astro_backend_core import BODY_REGISTRY, moment_to_jd, set_zodiac_mode
from astro_backend_ephemeris import build_houses
from astro_backend_map import (
    METHOD_ACG,
    METHOD_LOCAL_SPACE,
    _altitude_at,
    _angle_orb,
    _geo_norm,
    _planet_ecliptic,
    calculate_acg_lines,
    calculate_local_space,
    mc_ic_longitudes,
    sample_asc_dsc_curve,
    se_azimuth_to_north_clockwise,
)
from astro_backend_api import validate_required_fields


def _moment():
    return {
        "year": 1990,
        "month": 1,
        "day": 1,
        "hour": 12,
        "minute": 0,
        "timezone": "Asia/Shanghai",
    }


def test_acg_mc_ic_meridians_and_recompute():
    warnings: list[str] = []
    result = calculate_acg_lines(
        {
            "mode": "astrocartography",
            "moment": _moment(),
            "body_ids": ["SUN", "MOON"],
            "angle_kinds": ["MC", "IC", "ASC", "DSC"],
            "zodiac": "tropical",
        },
        warnings,
    )
    assert result["meta"]["method"] == METHOD_ACG
    by_id = {line["id"]: line for line in result["lines"]}
    assert "SUN|MC" in by_id
    assert "SUN|IC" in by_id
    mc = by_id["SUN|MC"]["longitude"]
    ic = by_id["SUN|IC"]["longitude"]
    delta = abs(((ic - mc + 180) % 360) - 180)
    assert abs(delta - 180) < 1e-6 or abs((ic - mc) % 360 - 180) < 1e-6

    jd, _ = moment_to_jd(_moment())
    set_zodiac_mode("tropical")
    recomputed_mc, recomputed_ic, _ = mc_ic_longitudes(jd, BODY_REGISTRY["SUN"].code, False)
    assert abs(recomputed_mc - mc) < 1e-9
    assert abs(recomputed_ic - ic) < 1e-9


def test_acg_asc_dsc_on_line_has_near_zero_altitude_including_latitude():
    """On-line places must put the body on the horizon (true alt≈0), using ecl_lat."""
    jd, _ = moment_to_jd(_moment())
    set_zodiac_mode("tropical")
    for body_id in ("SUN", "MOON", "PLUTO"):
        code = BODY_REGISTRY[body_id].code
        ecl_lon, ecl_lat, dist = _planet_ecliptic(jd, code, False)
        for angle in ("ASC", "DSC"):
            points, meta = sample_asc_dsc_curve(jd, code, False, angle=angle, lat_step=6.0)
            assert points, f"{body_id} {angle} should produce samples"
            assert meta["trace"]["method_key"] == "asc_dsc_true_altitude_zero_with_ecl_lat"
            assert abs(meta["trace"]["ecliptic_latitude"] - ecl_lat) < 1e-9
            checked = 0
            for point in points:
                if abs(point["latitude"]) > 55:
                    continue
                alt = _altitude_at(
                    jd, point["longitude"], point["latitude"], ecl_lon, ecl_lat, dist
                )
                assert abs(alt) < 0.1, (
                    f"{body_id} {angle} at lat={point['latitude']}: true alt={alt:.3f}° "
                    f"(ecl_lat={ecl_lat:.3f}°)"
                )
                checked += 1
                if checked >= 5:
                    break
            assert checked >= 3, f"{body_id} {angle}: need mid-latitude samples"


def test_acg_sun_asc_dsc_still_match_chart_angles_when_ecl_lat_near_zero():
    """Sun has ecl_lat≈0 so altitude-zero lines should also sit near chart ASC/DSC."""
    jd, _ = moment_to_jd(_moment())
    set_zodiac_mode("tropical")
    sun = BODY_REGISTRY["SUN"].code
    ecl_lon, ecl_lat, _dist = _planet_ecliptic(jd, sun, False)
    assert abs(ecl_lat) < 0.01
    for angle in ("ASC", "DSC"):
        points, _ = sample_asc_dsc_curve(jd, sun, False, angle=angle, lat_step=10.0)
        p = next(pt for pt in points if abs(pt["latitude"]) < 15)
        angles = build_houses(jd, p["latitude"], p["longitude"], "placidus", False, [])[1]
        orb_named = _angle_orb(ecl_lon, angles[angle])
        opp = "DSC" if angle == "ASC" else "ASC"
        orb_opp = _angle_orb(ecl_lon, angles[opp])
        assert orb_named < 1.0
        assert orb_named < orb_opp


def test_acg_asc_dsc_not_collapsed_at_high_latitude():
    jd, _ = moment_to_jd(_moment())
    set_zodiac_mode("tropical")
    sun_code = BODY_REGISTRY["SUN"].code
    asc_points, _ = sample_asc_dsc_curve(jd, sun_code, False, angle="ASC", lat_step=2.0)
    dsc_points, _ = sample_asc_dsc_curve(jd, sun_code, False, angle="DSC", lat_step=2.0)
    asc_by_lat = {round(p["latitude"], 3): p["longitude"] for p in asc_points}
    dsc_by_lat = {round(p["latitude"], 3): p["longitude"] for p in dsc_points}
    shared = sorted(set(asc_by_lat) & set(dsc_by_lat))
    targets = [lat for lat in shared if 48.0 <= abs(lat) <= 58.0] or shared
    assert targets
    for lat in targets[:6]:
        gap = abs(_geo_norm(asc_by_lat[lat] - dsc_by_lat[lat]))
        if gap > 180:
            gap = 360 - gap
        assert gap > 5.0, f"ASC/DSC collapsed at lat={lat}"


def test_map_geometry_is_invariant_across_zodiac_labelling():
    """Physical ACG/Local Space geometry must not move with ayanamsha."""
    base = {
        "mode": "astrocartography",
        "moment": _moment(),
        "body_ids": ["SUN", "MOON", "PLUTO"],
        "angle_kinds": ["MC", "IC", "ASC", "DSC"],
    }
    tropical = calculate_acg_lines({**base, "zodiac": "tropical"}, [])
    sidereal = calculate_acg_lines({**base, "zodiac": "sidereal_lahiri"}, [])
    assert tropical["meta"]["coordinate_frame"] == "tropical_true_of_date_physical_sky"
    assert sidereal["meta"]["zodiac_requested"] == "sidereal_lahiri"
    assert sidereal["meta"]["zodiac"] == "tropical"
    assert tropical["lines"] == sidereal["lines"]

    local_base = {
        "mode": "local_space",
        "moment": _moment(),
        "location": {
            "name": "Shanghai",
            "latitude": 31.2304,
            "longitude": 121.4737,
        },
        "body_ids": ["SUN", "MOON", "PLUTO"],
    }
    local_tropical = calculate_local_space({**local_base, "zodiac": "tropical"}, [])
    local_sidereal = calculate_local_space({**local_base, "zodiac": "sidereal_lahiri"}, [])
    assert local_tropical["directions"] == local_sidereal["directions"]
    assert local_sidereal["meta"]["coordinate_frame"] == "tropical_true_of_date_physical_sky"


def test_local_space_azimuth_is_north_clockwise_not_se_raw():
    """SE azalt is from south westwards; product azimuth must be (raw+180)%360."""
    # Documented conversion identity.
    assert abs(se_azimuth_to_north_clockwise(66.687536) - 246.687536) < 1e-9
    assert abs(se_azimuth_to_north_clockwise(0.0) - 180.0) < 1e-9  # south → 180
    assert abs(se_azimuth_to_north_clockwise(180.0) - 0.0) < 1e-9  # north → 0

    result = calculate_local_space(
        {
            "mode": "local_space",
            "moment": _moment(),
            "location": {
                "name": "Shanghai",
                "latitude": 31.2304,
                "longitude": 121.4737,
                "altitude_m": 0,
            },
            "body_ids": ["SUN", "MOON"],
            "zodiac": "tropical",
        },
        [],
    )
    assert result["meta"]["method"] == METHOD_LOCAL_SPACE
    for direction in result["directions"]:
        raw = float(direction["trace"]["se_azimuth_from_south_westward"])
        north = float(direction["trace"]["azimuth_north_clockwise"])
        assert abs(north - se_azimuth_to_north_clockwise(raw)) < 1e-9
        assert abs(direction["azimuth_deg"] - north) < 1e-9
        # Must not leave the SE raw value as the public azimuth.
        assert abs(direction["azimuth_deg"] - raw) > 1.0 or abs(raw - 180) < 1e-6
        assert len(direction["great_circle_points"]) >= 2
        assert direction["trace"]["azalt_flag"] == "ECL2HOR"
    assert "great_circle_far_point_is_approximate" in result["meta"]["unverified"]


def test_reference_validation_still_required_for_solar_arc():
    """B6 map-mode edits must not drop shared reference checks for time-based modes."""
    err = validate_required_fields(
        {
            "mode": "solar_arc",
            "birth": {
                "moment": {
                    "year": 1990,
                    "month": 1,
                    "day": 1,
                    "hour": 12,
                    "minute": 0,
                    "timezone": "Asia/Shanghai",
                },
                "latitude": 31.23,
                "longitude": 121.47,
            },
            "reference": {
                "year": 2026,
                "month": 6,
                "day": 1,
                "hour": 12,
                "minute": 0,
                # timezone intentionally missing
            },
        }
    )
    assert err is not None
    blob = str(err)
    assert "reference.timezone" in blob or "timezone" in blob
