"""Astrocartography (A*C*G) and Local Space calculations.

Method spike answers (verified against pyswisseph introspection + project docs):

1. Swiss bindings
   - ``swe.calc_ut(tjdut, planet, flags)`` with ``FLG_SWIEPH|FLG_EQUATORIAL``
     returns equatorial RA/Dec in ``xx[0]``/``xx[1]`` (degrees).
   - ``swe.sidtime(tjdut)`` returns Greenwich Mean Sidereal Time in **hours**.
   - ``swe.azalt(tjdut, flag, geopos, atpress, attemp, xin)`` with
     ``flag=ECL2HOR`` converts ecliptic lon/lat/dist → (azimuth, true_alt, app_alt).
     Swiss Ephemeris returns azimuth from the south point toward the west;
     product output converts it to north-origin clockwise degrees.
   - ACG and Local Space are physical sky geometry. Equatorial/ecliptic inputs
     therefore stay tropical true-of-date even when the surrounding chart UI
     is using a sidereal zodiac; changing ayanamsha must not move map lines.

2. ACG line formulas (documented classical geography; internal consistency tests)
   - **MC meridian**: at fixed UT, planet equatorial RA ``α`` and GMST ``θ``
     (degrees = sidtime*15). Geographic longitude λ (east+) where planet is on
     MC: ``λ = α − θ`` (mod 360, then mapped to −180…180).
   - **IC meridian**: ``λ = α − θ + 180°``.
   - **ASC/DSC curves**: sample geographic latitudes; for each latitude solve
     for true altitude ≈ 0° via ``swe.azalt`` on the full ecliptic vector
     ``(lon, lat, dist)`` so non-zero ecliptic latitude is respected. Label
     ASC (rising/east) vs DSC (setting/west) using north-clockwise azimuth
     after converting SE's south-westward measure with ``(az+180)%360``.
     Prefer continuity with the previous latitude. Polar / unsolved samples
     are omitted.

3. Polar / ±180° polyline strategy
   - MC/IC: single vertical meridian; split at antimeridian when rendering spans
     ±180° (two segments if needed).
   - ASC/DSC: ordered by latitude; break polyline when consecutive longitude
     samples jump by >180° (antimeridian wrap) or when a latitude has no root.
   - Polar: latitudes outside ±66° may be sparse; samples with no root are
     skipped rather than extrapolated.

4. MapKit feasibility (macOS 13+)
   - ``MKPolyline`` + ``MKMapView`` overlays support multi-segment polylines.
   - Hit-testing: nearest projected point within pixel tolerance; return
     planet/angle/method trace (implemented in Swift UI when product ships).
   - Performance: ≤10 planets × 4 angles × ~90 lat samples is fine offline.
   - Screenshot export: AppKit ``NSImage`` from map view — product UI concern.

5. Cross-check points
   - Recorded in handoff doc with internal consistency (MC longitude formula
     recompute; Local Space azimuth from azalt). External Astro.com/Solar Fire
     numeric cross-checks were not available offline; tolerances below are
     **internal** only, not claimed against third-party software.

Unverified / left empty:
- Parans, zenith/nadir extensions, fixed-star lines, Johndro/geodetic.
- Authoritative third-party sample coordinates (network-dependent).
"""

from __future__ import annotations

import math
from datetime import datetime, timezone
from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
    moment_to_jd,
    set_zodiac_mode,
    swe,
)
METHOD_ACG = "acg_mc_ic_meridian_asc_dsc_azalt_v1"
METHOD_LOCAL_SPACE = "local_space_azalt_great_circle_v1"
SCHEMA_VERSION = 1
PHYSICAL_COORDINATE_FRAME = "tropical_true_of_date_physical_sky"

DEFAULT_ACG_BODIES = (
    "SUN", "MOON", "MERCURY", "VENUS", "MARS",
    "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO",
)
ANGLE_KINDS = ("ASC", "DSC", "MC", "IC")


def _iso_utc_from_jd(jd: float) -> str:
    year, month, day, hour = swe.revjul(jd, swe.GREG_CAL)
    whole = int(hour)
    minutes_f = (hour - whole) * 60.0
    mins = int(minutes_f)
    seconds = (minutes_f - mins) * 60.0
    dt = datetime(int(year), int(month), int(day), whole % 24, mins, int(seconds), tzinfo=timezone.utc)
    return dt.isoformat().replace("+00:00", "Z")


def _geo_norm(lon: float) -> float:
    """Normalize geographic longitude to (−180, 180]."""
    return ((lon + 180.0) % 360.0) - 180.0


def _require_moment_jd(moment: Any, label: str) -> tuple[float, str]:
    if not isinstance(moment, dict):
        raise ValueError(f"{label} must be an object with exact moment fields")
    for field in ("year", "month", "day", "hour", "minute", "timezone"):
        if field not in moment:
            raise ValueError(f"{label}.{field} is required")
    jd, utc = moment_to_jd(moment)
    return jd, utc


def _planet_equatorial(jd: float, body_code: int, sidereal: bool) -> tuple[float, float, float]:
    flags = swe.FLG_SWIEPH | swe.FLG_EQUATORIAL
    if sidereal:
        flags |= swe.FLG_SIDEREAL
    xx, _ = swe.calc_ut(jd, body_code, flags)
    return float(xx[0]), float(xx[1]), float(xx[2])  # RA deg, Dec deg, dist


def _planet_ecliptic(jd: float, body_code: int, sidereal: bool) -> tuple[float, float, float]:
    flags = swe.FLG_SWIEPH
    if sidereal:
        flags |= swe.FLG_SIDEREAL
    xx, _ = swe.calc_ut(jd, body_code, flags)
    return float(xx[0]), float(xx[1]), float(xx[2])


def _gmst_degrees(jd: float) -> float:
    # swe.sidtime returns hours; convert to degrees of RA/longitude.
    return float(swe.sidtime(jd)) * 15.0


def mc_ic_longitudes(jd: float, body_code: int, sidereal: bool) -> tuple[float, float, dict[str, Any]]:
    """Return (MC_lon, IC_lon) geographic east-positive in (−180, 180]."""
    ra, dec, dist = _planet_equatorial(jd, body_code, sidereal)
    gmst = _gmst_degrees(jd)
    mc = _geo_norm(ra - gmst)
    ic = _geo_norm(mc + 180.0)
    trace = {
        "method_key": "mc_ic_ra_minus_gmst",
        "ra_deg": ra,
        "dec_deg": dec,
        "gmst_deg": gmst,
        "formula": "lambda_mc = RA - GMST; lambda_ic = lambda_mc + 180",
        "distance_au": dist,
    }
    return mc, ic, trace


# ASC/DSC line: places where the body has true horizon altitude ≈ 0 (uses ecl_lat).
_ALTITUDE_ACCEPT_DEG = 0.05


def _altitude_at(jd: float, lon: float, lat: float, ecl_lon: float, ecl_lat: float, dist: float) -> float:
    geopos = (lon, lat, 0.0)
    _az, true_alt, _app_alt = swe.azalt(
        jd,
        swe.ECL2HOR,
        geopos,
        0.0,
        0.0,
        (ecl_lon, ecl_lat, dist),
    )
    # Use true altitude (no refraction) so non-zero ecliptic latitude is respected.
    return float(true_alt)


def _azimuth_se_raw(jd: float, lon: float, lat: float, ecl_lon: float, ecl_lat: float, dist: float) -> tuple[float, float]:
    """Return Swiss Ephemeris raw azimuth (from south, westwards) and true altitude."""
    geopos = (lon, lat, 0.0)
    az, true_alt, _app_alt = swe.azalt(
        jd,
        swe.ECL2HOR,
        geopos,
        0.0,
        0.0,
        (ecl_lon, ecl_lat, dist),
    )
    return float(az), float(true_alt)


def se_azimuth_to_north_clockwise(az_from_south_westward: float) -> float:
    """Convert SE azalt azimuth to navigation azimuth (0=N, eastward/clockwise).

    Swiss Ephemeris measures azimuth from the south point toward the west.
    Local Space and map display use north-origin clockwise degrees.
    """
    return (float(az_from_south_westward) + 180.0) % 360.0


def _azimuth_at(jd: float, lon: float, lat: float, ecl_lon: float, ecl_lat: float, dist: float) -> tuple[float, float]:
    """Return (north-clockwise azimuth, true altitude)."""
    az_se, true_alt = _azimuth_se_raw(jd, lon, lat, ecl_lon, ecl_lat, dist)
    return se_azimuth_to_north_clockwise(az_se), true_alt


def _angle_orb(planet_lon: float, angle_lon: float) -> float:
    return abs(((float(planet_lon) - float(angle_lon) + 180.0) % 360.0) - 180.0)


def _circular_distance_deg(a: float, b: float) -> float:
    return abs(((float(a) - float(b) + 180.0) % 360.0) - 180.0)


def _classify_horizon_by_azimuth(az_north_clockwise: float) -> str:
    """ASC = rising ≈ east (90°); DSC = setting ≈ west (270°), north-clockwise."""
    if _circular_distance_deg(az_north_clockwise, 90.0) <= _circular_distance_deg(az_north_clockwise, 270.0):
        return "ASC"
    return "DSC"


def _horizon_roots_at_latitude(
    jd: float,
    latitude: float,
    ecl_lon: float,
    ecl_lat: float,
    dist: float,
) -> list[float]:
    """Refined geographic longitudes where true altitude crosses 0° (uses ecl_lat)."""
    samples: list[tuple[float, float]] = []
    for i in range(72):
        lon = -180.0 + i * 5.0
        samples.append((lon, _altitude_at(jd, lon, latitude, ecl_lon, ecl_lat, dist)))

    roots: list[float] = []
    for i in range(len(samples)):
        lon1, alt1 = samples[i]
        lon2, alt2 = samples[(i + 1) % len(samples)]
        lon2_u = lon2 if lon2 > lon1 else lon2 + 360.0
        if alt1 == 0.0:
            roots.append(_geo_norm(lon1))
            continue
        if alt1 * alt2 > 0:
            continue
        left, right = lon1, lon2_u
        a_left = alt1
        for _ in range(36):
            mid = (left + right) / 2.0
            mid_lon = _geo_norm(mid)
            a_mid = _altitude_at(jd, mid_lon, latitude, ecl_lon, ecl_lat, dist)
            if a_left * a_mid <= 0:
                right = mid
            else:
                left, a_left = mid, a_mid
            if abs(right - left) < 1e-5:
                break
        root = _geo_norm((left + right) / 2.0)
        if abs(_altitude_at(jd, root, latitude, ecl_lon, ecl_lat, dist)) <= _ALTITUDE_ACCEPT_DEG:
            roots.append(root)

    unique: list[float] = []
    for root in roots:
        if any(_circular_distance_deg(root, existing) < 0.05 for existing in unique):
            continue
        unique.append(root)
    return unique


def _solve_horizon_longitude(
    jd: float,
    latitude: float,
    ecl_lon: float,
    ecl_lat: float,
    dist: float,
    *,
    angle: str,
    previous_lon: float | None,
) -> float | None:
    """Geographic longitude of rising (ASC) or setting (DSC) for a body with ecl_lat."""
    if angle not in {"ASC", "DSC"}:
        raise ValueError(f"horizon angle must be ASC or DSC, got {angle}")

    scored: list[tuple[float, float, float]] = []  # (continuity, |alt|, lon)
    for root in _horizon_roots_at_latitude(jd, latitude, ecl_lon, ecl_lat, dist):
        az, alt = _azimuth_at(jd, root, latitude, ecl_lon, ecl_lat, dist)
        if abs(alt) > _ALTITUDE_ACCEPT_DEG:
            continue
        if _classify_horizon_by_azimuth(az) != angle:
            continue
        if previous_lon is None:
            continuity = 0.0
        else:
            continuity = _circular_distance_deg(root, previous_lon)
        scored.append((continuity, abs(alt), root))

    if not scored:
        return None
    # Prefer continuity first so high-latitude curves stay smooth; then tighter altitude.
    scored.sort(key=lambda item: (item[0], item[1]))
    return scored[0][2]


def sample_asc_dsc_curve(
    jd: float,
    body_code: int,
    sidereal: bool,
    *,
    angle: str,
    lat_step: float = 2.0,
) -> tuple[list[dict[str, float]], dict[str, Any]]:
    ecl_lon, ecl_lat, dist = _planet_ecliptic(jd, body_code, sidereal)
    points: list[dict[str, float]] = []
    skipped_polar = 0
    skipped_unclassified = 0
    previous_lon: float | None = None
    lat = -66.0
    while lat <= 66.0 + 1e-9:
        lon = _solve_horizon_longitude(
            jd,
            lat,
            ecl_lon,
            ecl_lat,
            dist,
            angle=angle,
            previous_lon=previous_lon,
        )
        if lon is None:
            if abs(lat) > 58.0:
                skipped_polar += 1
            else:
                skipped_unclassified += 1
            previous_lon = None
        else:
            points.append({"latitude": round(lat, 6), "longitude": round(lon, 6)})
            previous_lon = lon
        lat += lat_step

    segments = _split_antimeridian(points)
    trace = {
        "method_key": "asc_dsc_true_altitude_zero_with_ecl_lat",
        "ecliptic_longitude": ecl_lon,
        "ecliptic_latitude": ecl_lat,
        "lat_step_deg": lat_step,
        "samples": len(points),
        "skipped_near_polar": skipped_polar,
        "skipped_unclassified": skipped_unclassified,
        "segment_count": len(segments),
        "classification": "true altitude≈0 with ecl_lat; ASC/DSC by north-clockwise az east/west",
        "altitude_accept_deg": _ALTITUDE_ACCEPT_DEG,
        "planet_distance_au": dist,
        "azimuth_convention": "SE azalt from south westwards → (az+180)%360 north-clockwise",
    }
    return points, {"segments": segments, "trace": trace}


def _split_antimeridian(points: list[dict[str, float]]) -> list[list[dict[str, float]]]:
    if not points:
        return []
    segments: list[list[dict[str, float]]] = [[points[0]]]
    for point in points[1:]:
        prev = segments[-1][-1]
        if abs(point["longitude"] - prev["longitude"]) > 180.0:
            segments.append([point])
        else:
            segments[-1].append(point)
    return segments


def calculate_acg_lines(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    moment = request.get("moment") or request.get("birth", {}).get("moment")
    jd, utc = _require_moment_jd(moment, "moment")
    zodiac_requested = request.get("zodiac", "tropical")
    # Validate/report the requested zodiac, but never feed sidereal coordinates
    # into physical RA/horizon geometry. Ayanamsha is a zodiac labelling choice,
    # not a change in the body's actual sky position.
    set_zodiac_mode(zodiac_requested, warnings)
    sidereal = False

    body_ids = list(request.get("body_ids") or DEFAULT_ACG_BODIES)
    if len(body_ids) > 10:
        raise ValueError("acg body_ids v1 supports at most 10 bodies")
    for body_id in body_ids:
        if body_id not in BODY_REGISTRY:
            raise ValueError(f"unknown body_id: {body_id}")

    angle_kinds = list(request.get("angle_kinds") or list(ANGLE_KINDS))
    for angle in angle_kinds:
        if angle not in ANGLE_KINDS:
            raise ValueError(f"unsupported angle_kind: {angle}")

    lines: list[dict[str, Any]] = []
    for body_id in body_ids:
        spec = BODY_REGISTRY[body_id]
        try:
            mc_lon, ic_lon, mc_trace = mc_ic_longitudes(jd, spec.code, sidereal)
        except swe.Error as exc:
            warnings.append(f"ACG equatorial calc failed for {body_id}: {exc}")
            continue

        if "MC" in angle_kinds:
            lines.append(
                {
                    "id": f"{body_id}|MC",
                    "body_id": body_id,
                    "body_name": spec.name,
                    "angle_kind": "MC",
                    "geometry": "meridian",
                    "longitude": mc_lon,
                    "points": [
                        {"latitude": -90.0, "longitude": mc_lon},
                        {"latitude": 90.0, "longitude": mc_lon},
                    ],
                    "segments": [
                        [
                            {"latitude": -90.0, "longitude": mc_lon},
                            {"latitude": 90.0, "longitude": mc_lon},
                        ]
                    ],
                    "method_key": METHOD_ACG,
                    "trace": mc_trace,
                }
            )
        if "IC" in angle_kinds:
            lines.append(
                {
                    "id": f"{body_id}|IC",
                    "body_id": body_id,
                    "body_name": spec.name,
                    "angle_kind": "IC",
                    "geometry": "meridian",
                    "longitude": ic_lon,
                    "points": [
                        {"latitude": -90.0, "longitude": ic_lon},
                        {"latitude": 90.0, "longitude": ic_lon},
                    ],
                    "segments": [
                        [
                            {"latitude": -90.0, "longitude": ic_lon},
                            {"latitude": 90.0, "longitude": ic_lon},
                        ]
                    ],
                    "method_key": METHOD_ACG,
                    "trace": {**mc_trace, "branch": "IC"},
                }
            )

        for angle in ("ASC", "DSC"):
            if angle not in angle_kinds:
                continue
            try:
                points, meta = sample_asc_dsc_curve(jd, spec.code, sidereal, angle=angle)
            except swe.Error as exc:
                warnings.append(f"ACG {angle} curve failed for {body_id}: {exc}")
                continue
            if not points:
                warnings.append(
                    f"ACG {angle} line for {body_id}: no horizon roots in sampled latitudes "
                    "(polar/unverified region); line left empty."
                )
            lines.append(
                {
                    "id": f"{body_id}|{angle}",
                    "body_id": body_id,
                    "body_name": spec.name,
                    "angle_kind": angle,
                    "geometry": "curve",
                    "longitude": None,
                    "points": points,
                    "segments": meta["segments"],
                    "method_key": METHOD_ACG,
                    "trace": meta["trace"],
                }
            )

    return {
        "meta": {
            "mode": "astrocartography",
            "method": METHOD_ACG,
            "schema_version": SCHEMA_VERSION,
            "moment_utc": utc,
            "moment_jd": jd,
            "zodiac": "tropical",
            "zodiac_requested": zodiac_requested,
            "coordinate_frame": PHYSICAL_COORDINATE_FRAME,
            "body_ids": body_ids,
            "angle_kinds": angle_kinds,
            "ephemeris": "Swiss Ephemeris",
            "unverified": [
                "third_party_cross_check_coordinates",
                "parans",
                "zenith_nadir_lines",
            ],
        },
        "lines": lines,
        "warnings": warnings,
        "section_errors": None,
    }


def calculate_local_space(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    moment = request.get("moment")
    jd, utc = _require_moment_jd(moment, "moment")
    location = request.get("location")
    if not isinstance(location, dict):
        raise ValueError("location is required")
    for field in ("latitude", "longitude"):
        if field not in location:
            raise ValueError(f"location.{field} is required")
    lat = float(location["latitude"])
    lon = float(location["longitude"])
    if not (-90 <= lat <= 90 and -180 <= lon <= 180):
        raise ValueError("location coordinates out of range")
    alt = float(location.get("altitude_m") or 0.0)
    name = str(location.get("name") or "")

    zodiac_requested = request.get("zodiac", "tropical")
    set_zodiac_mode(zodiac_requested, warnings)
    sidereal = False
    body_ids = list(request.get("body_ids") or DEFAULT_ACG_BODIES)
    if len(body_ids) > 10:
        raise ValueError("local_space body_ids v1 supports at most 10 bodies")

    directions: list[dict[str, Any]] = []
    for body_id in body_ids:
        if body_id not in BODY_REGISTRY:
            raise ValueError(f"unknown body_id: {body_id}")
        spec = BODY_REGISTRY[body_id]
        try:
            ecl_lon, ecl_lat, dist = _planet_ecliptic(jd, spec.code, sidereal)
            az_se, true_alt = _azimuth_se_raw(jd, lon, lat, ecl_lon, ecl_lat, dist)
            az = se_azimuth_to_north_clockwise(az_se)
        except swe.Error as exc:
            warnings.append(f"Local Space azalt failed for {body_id}: {exc}")
            continue
        # Great-circle direction line: from observer along constant initial azimuth.
        # Product UI draws a geodesic; we provide azimuth + sample far point
        # using simple equirectangular step (not a full geodesic library).
        # Far-point sample is approximate; marked as such.
        # Approximate destination ~45° of arc along north-clockwise azimuth.
        rad_az = math.radians(az)
        dlat = 45.0 * math.cos(rad_az)
        dlon = 45.0 * math.sin(rad_az) / max(0.2, math.cos(math.radians(lat)))
        far_lat = max(-89.9, min(89.9, lat + dlat))
        far_lon = _geo_norm(lon + dlon)
        directions.append(
            {
                "id": f"local_space|{body_id}",
                "body_id": body_id,
                "body_name": spec.name,
                "azimuth_deg": az,
                "altitude_deg": true_alt,
                "ecliptic_longitude": ecl_lon,
                "ecliptic_latitude": ecl_lat,
                "observer": {"name": name, "latitude": lat, "longitude": lon, "altitude_m": alt},
                "great_circle_points": [
                    {"latitude": lat, "longitude": lon},
                    {"latitude": far_lat, "longitude": far_lon},
                ],
                "method_key": METHOD_LOCAL_SPACE,
                "trace": {
                    "azalt_flag": "ECL2HOR",
                    "formula": "swe.azalt SE az (from south westwards) → (az+180)%360 north-clockwise",
                    "se_azimuth_from_south_westward": az_se,
                    "azimuth_north_clockwise": az,
                    "far_point_note": "approximate equirectangular sample, not geodesic library",
                    "display_ray_deg": 45.0,
                },
            }
        )

    return {
        "meta": {
            "mode": "local_space",
            "method": METHOD_LOCAL_SPACE,
            "schema_version": SCHEMA_VERSION,
            "moment_utc": utc,
            "moment_jd": jd,
            "location": {"name": name, "latitude": lat, "longitude": lon, "altitude_m": alt},
            "zodiac": "tropical",
            "zodiac_requested": zodiac_requested,
            "coordinate_frame": PHYSICAL_COORDINATE_FRAME,
            "body_ids": body_ids,
            "ephemeris": "Swiss Ephemeris",
            "unverified": [
                "great_circle_far_point_is_approximate",
                "third_party_azimuth_cross_check",
            ],
        },
        "directions": directions,
        "warnings": warnings,
        "section_errors": None,
    }


def calculate_map_mode(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    """Router for map sub-modes: astrocartography | local_space."""
    mode = request.get("mode")
    if mode == "astrocartography":
        return calculate_acg_lines(request, warnings)
    if mode == "local_space":
        return calculate_local_space(request, warnings)
    # Allow map_kind inside a generic envelope.
    kind = request.get("map_kind")
    if kind == "astrocartography":
        return calculate_acg_lines(request, warnings)
    if kind == "local_space":
        return calculate_local_space(request, warnings)
    raise ValueError(f"unsupported map mode: {mode or kind}")
