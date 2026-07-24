"""Horary Data Packet v2 — pure, versioned, judgment-free chart data.

Canonical schema: ``horary-data-packet/2.1``

This module produces only astronomical / mechanical rule-derived facts.
Interpretation fields (significators, radicality caution labels, scores,
translation/collection judgment, machine summaries) live exclusively in the
legacy path (``astro_backend_horary.calculate_horary``).
"""
from __future__ import annotations

import hashlib
import json
import math
from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_classical import (
    CLASSICAL_ASPECTS,
    applying_label,
    aspect_offsets_for_angle,
    classical_aspect_signature,
    signed_aspect_orb,
)
from astro_backend_classical_dignity import (
    EGYPTIAN_BOUNDS,
    EXALTATION_RULERS,
    FACE_ORDER,
    PTOLEMAIC_BOUNDS,
    SIGN_ELEMENTS,
    TRIPLICITY_RULERS,
    bounds_ruler,
    decan_ruler,
    solar_phase,
    triplicity_set,
)
from astro_backend_classical_lots import (
    LOT_LIST,
    _formula_text,
    _resolve_lot_ref,
    calculate_lots,
    lot_value,
)
from astro_backend_core import (
    BODY_REGISTRY,
    CLASSICAL_BODY_IDS,
    SIGN_RULERS,
    SIGNS,
    angular_separation,
    format_local,
    format_longitude,
    jd_from_datetime,
    moment_to_jd,
    moment_to_local_datetime,
    norm360,
    obliquity,
    planet_name,
    sign_degree,
    signed_orb,
    swe,
    zodiac_mode_label,
    zodiac_sign_index,
    set_zodiac_mode,
)
from astro_backend_ephemeris import (
    HOUSE_SYSTEMS,
    body_longitude_at,
    body_speed_at,
    build_houses,
    calculate_values,
    house_for_longitude,
    longitude_in_interval,
)
from astro_backend_horary import (
    ASPECT_NAMES,
    CLASSICAL_ANGLES,
    MEAN_DAILY_SPEED_BY_BODY,
    STATION_SPEED_MINIMUM,
    STATION_SPEED_RATIO,
    body_exits_sign_before,
    exact_datetime_result_for_signature,
    next_exact_for_pair,
    next_sign_exit_for_body,
    previous_exact_for_pair,
    relative_orb_for_pair_at,
    station_speed_threshold,
    _to_utc_for_search,
)

SCHEMA_NAME = "horary-data-packet"
SCHEMA_VERSION = "2.1"
ENGINE_NAME = "TransitStudio.horary_v2"
ENGINE_VERSION = "2.1.0"
ALGORITHM_VERSION = "horary-v2.1-2026-07"

# Mean tropical longitudes speeds (deg/day) — same table as classical motion_label.
MEAN_SPEED = {
    "SUN": 0.9856,
    "MOON": 13.1764,
    "MERCURY": 1.383,
    "VENUS": 1.2,
    "MARS": 0.524,
    "JUPITER": 0.083,
    "SATURN": 0.033,
}

SIGN_EN = [
    "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
    "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
]

BODY_EN = {
    "SUN": "Sun", "MOON": "Moon", "MERCURY": "Mercury", "VENUS": "Venus",
    "MARS": "Mars", "JUPITER": "Jupiter", "SATURN": "Saturn",
}

ASPECT_EN = {
    "合相": "conjunction", "六合": "sextile", "刑相": "square",
    "拱相": "trine", "冲相": "opposition",
    "conjunction": "conjunction", "sextile": "sextile", "square": "square",
    "trine": "trine", "opposition": "opposition",
}

CAZIMI_ORB_DEG = 17.0 / 60.0
COMBUST_ORB_DEG = 8.5
UNDER_BEAMS_ORB_DEG = 15.0

DEFAULT_EVENT_PAST_DAYS = 4.0
DEFAULT_EVENT_FUTURE_DAYS = 30.0
DEFAULT_ASPECT_ORB = 3.0

FLOAT_PREC = 8
ANGLE_PREC = 6


def _r(value: float | None, digits: int = FLOAT_PREC) -> float | None:
    if value is None:
        return None
    if not math.isfinite(value):
        return None
    return round(float(value), digits)


def _validated_number(
    name: str,
    value: Any,
    *,
    minimum: float | None = None,
    maximum: float | None = None,
) -> float:
    if isinstance(value, bool):
        raise ValueError(f"{name} must be a finite number")
    try:
        number = float(value)
    except (TypeError, ValueError) as exc:
        raise ValueError(f"{name} must be a finite number") from exc
    if not math.isfinite(number):
        raise ValueError(f"{name} must be a finite number")
    if minimum is not None and number < minimum:
        raise ValueError(f"{name} must be >= {minimum:g}")
    if maximum is not None and number > maximum:
        raise ValueError(f"{name} must be <= {maximum:g}")
    return number


def _stable_json(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False)


def _hash_payload(obj: Any) -> str:
    return hashlib.sha256(_stable_json(obj).encode("utf-8")).hexdigest()


def _null_with_reason(reason_code: str, detail: str | None = None) -> dict[str, Any]:
    row: dict[str, Any] = {"value": None, "reason_code": reason_code}
    if detail:
        row["detail"] = detail
    return row


def _sign_display(lon: float) -> dict[str, Any]:
    idx = zodiac_sign_index(lon)
    deg = sign_degree(lon)
    minutes = (deg % 1.0) * 60.0
    seconds = (minutes % 1.0) * 60.0
    return {
        "sign_index": idx,
        "sign_id": SIGN_EN[idx].lower(),
        "sign_en": SIGN_EN[idx],
        "sign_zh": SIGNS[idx],
        "degree_in_sign": _r(deg, 8),
        "dms": {
            "degrees": int(deg),
            "minutes": int(minutes),
            "seconds": _r(seconds, 3),
        },
        "display_zh": f"{int(deg)}°{int(minutes):02d}' {SIGNS[idx]}",
        "display_en": f"{int(deg)}°{int(minutes):02d}' {SIGN_EN[idx]}",
    }


def _forward_arc(start: float, end: float) -> float:
    return norm360(end - start)


def _house_span(cusps: list[float], house_index_0: int) -> float:
    return _forward_arc(cusps[house_index_0], cusps[(house_index_0 + 1) % 12])


def _continuous_house(lon: float, cusps: list[float]) -> tuple[int, float, float, float]:
    house = house_for_longitude(lon, cusps)
    idx = house - 1
    span = _house_span(cusps, idx)
    from_prev = _forward_arc(cusps[idx], lon)
    to_next = _forward_arc(lon, cusps[(idx + 1) % 12])
    continuous = idx + (from_prev / span if span > 1e-12 else 0.0)
    return house, continuous + 1.0, from_prev, to_next  # continuous is 1-based fractional house


def _delta_t_seconds(jd_ut: float) -> float:
    try:
        return float(swe.deltat(jd_ut) * 86400.0)
    except Exception:
        return float("nan")


def _sidereal_time_hours(jd_ut: float) -> float:
    try:
        return float(swe.sidtime(jd_ut))
    except Exception:
        return float("nan")


def _armc_degrees(jd_ut: float, longitude_east: float) -> float:
    # Local sidereal time in degrees: GST hours * 15 + geographic longitude.
    gst_hours = _sidereal_time_hours(jd_ut)
    if not math.isfinite(gst_hours):
        return float("nan")
    return norm360(gst_hours * 15.0 + longitude_east)


def _equatorial(jd_ut: float, body_id: str, warnings: list[str]) -> tuple[float | None, float | None]:
    spec = BODY_REGISTRY[body_id]
    try:
        values, _ = swe.calc_ut(jd_ut, spec.code, swe.FLG_SWIEPH | swe.FLG_EQUATORIAL)
        ra = float(values[0])
        dec = float(values[1])
        if body_id in ("SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE"):
            dec = -dec
            ra = norm360(ra + 180.0)
        return ra, dec
    except swe.Error as exc:
        warnings.append(f"{body_id} equatorial coords unavailable: {exc}")
        return None, None


def _horizontal(
    jd_ut: float,
    body_id: str,
    latitude: float,
    longitude: float,
    altitude_m: float,
    warnings: list[str],
) -> tuple[float | None, float | None, float | None]:
    """Return (azimuth, true_altitude, app_altitude) or nulls."""
    ra, dec = _equatorial(jd_ut, body_id, warnings)
    if ra is None or dec is None:
        return None, None, None
    try:
        # geopos: lon, lat, height — Swiss Ephemeris convention longitude east positive.
        geopos = (float(longitude), float(latitude), float(altitude_m))
        # atpress / attemp defaults; 0 pressure disables refraction for true alt path.
        xin = (ra, dec, 1.0)
        # swe.azalt expects equatorial coordinates with flag SE_ECL2HOR or SE_EQU2HOR
        result = swe.azalt(jd_ut, swe.EQU2HOR, geopos, 0, 0, xin)
        # result: azimuth, true altitude, apparent altitude
        return float(result[0]), float(result[1]), float(result[2])
    except Exception as exc:
        warnings.append(f"{body_id} horizontal coords unavailable: {exc}")
        return None, None, None


def _hour_angle(jd_ut: float, ra: float | None, longitude: float) -> float | None:
    if ra is None:
        return None
    lst_deg = _armc_degrees(jd_ut, longitude)
    if not math.isfinite(lst_deg):
        return None
    return _r(((lst_deg - ra + 180.0) % 360.0) - 180.0, 6)


def _motion_state(body_id: str, speed: float) -> dict[str, Any]:
    mean = MEAN_SPEED.get(body_id)
    threshold = station_speed_threshold(body_id)
    if body_id in {"SUN", "MOON"}:
        state = "direct"
        threshold = None
    elif threshold is not None and abs(speed) < threshold:
        state = "stationary"
    elif speed < 0:
        state = "retrograde"
    else:
        state = "direct"
    ratio = (abs(speed) / mean) if mean and mean > 0 else None
    return {
        "state": state,
        "longitude_speed_deg_per_day": _r(speed, 8),
        "mean_longitude_speed_deg_per_day": _r(mean, 8) if mean is not None else None,
        "speed_to_mean_ratio": _r(ratio, 6) if ratio is not None else None,
        "station_threshold_deg_per_day": _r(threshold, 8) if threshold is not None else None,
        "rule_id": "motion.state.mean_speed_ratio_v1",
        "algorithm_version": ALGORITHM_VERSION,
        "evidence": {
            "speed_deg_per_day": _r(speed, 8),
            "mean_speed_deg_per_day": _r(mean, 8) if mean is not None else None,
            "threshold_ratio": STATION_SPEED_RATIO,
            "threshold_minimum": STATION_SPEED_MINIMUM,
        },
    }


def _rule_flag(
    flag_id: str,
    value: bool | None,
    *,
    rule_id: str,
    thresholds: dict[str, Any],
    evidence: dict[str, Any],
    reason_code: str | None = None,
) -> dict[str, Any]:
    row: dict[str, Any] = {
        "id": flag_id,
        "value": value,
        "rule_id": rule_id,
        "algorithm_version": ALGORITHM_VERSION,
        "thresholds": thresholds,
        "evidence": evidence,
    }
    if value is None and reason_code:
        row["reason_code"] = reason_code
    return row


def _bounds_interval(lon: float, bounds_system: str) -> dict[str, Any]:
    table = PTOLEMAIC_BOUNDS if bounds_system == "ptolemaic" else EGYPTIAN_BOUNDS
    sign_idx = zodiac_sign_index(lon)
    degree = sign_degree(lon)
    lower = 0.0
    for ruler, upper in table[sign_idx]:
        if degree < upper or abs(degree - upper) < 1e-12:
            return {
                "ruler_id": ruler,
                "ruler_en": BODY_EN.get(ruler, ruler),
                "ruler_zh": planet_name(ruler),
                "start_degree_in_sign": lower,
                "end_degree_in_sign": float(upper),
                "system": "ptolemaic" if bounds_system == "ptolemaic" else "egyptian",
            }
        lower = float(upper)
    ruler, upper = table[sign_idx][-1]
    return {
        "ruler_id": ruler,
        "ruler_en": BODY_EN.get(ruler, ruler),
        "ruler_zh": planet_name(ruler),
        "start_degree_in_sign": lower,
        "end_degree_in_sign": float(upper),
        "system": "ptolemaic" if bounds_system == "ptolemaic" else "egyptian",
    }


def _decan_interval(lon: float) -> dict[str, Any]:
    deg = sign_degree(lon)
    face = int(deg // 10)
    face = min(max(face, 0), 2)
    ruler = decan_ruler(lon)
    return {
        "ruler_id": ruler,
        "ruler_en": BODY_EN.get(ruler, ruler),
        "ruler_zh": planet_name(ruler),
        "start_degree_in_sign": float(face * 10),
        "end_degree_in_sign": float((face + 1) * 10),
        "face_index": face,
        "system": "chaldean_faces",
    }


def _dignity_for_body(
    body_id: str,
    lon: float,
    is_day: bool,
    bounds_system: str,
    triplicity_system: str,
) -> dict[str, Any]:
    sign_idx = zodiac_sign_index(lon)
    domicile = SIGN_RULERS[sign_idx]
    detriment = SIGN_RULERS[(sign_idx + 6) % 12]
    exaltation = EXALTATION_RULERS.get(sign_idx)
    fall = EXALTATION_RULERS.get((sign_idx + 6) % 12)
    day_t, night_t, part_t = triplicity_set(sign_idx, triplicity_system)
    active_t = day_t if is_day else night_t
    bounds = _bounds_interval(lon, bounds_system)
    decan = _decan_interval(lon)
    peregrine = (
        body_id != domicile
        and body_id != exaltation
        and body_id not in {day_t, night_t, part_t}
        and body_id != bounds["ruler_id"]
        and body_id != decan["ruler_id"]
    )
    return {
        "body_id": body_id,
        "longitude": _r(lon),
        "sign_index": sign_idx,
        "domicile_ruler_id": domicile,
        "exaltation_ruler_id": exaltation or None,
        "detriment_ruler_id": detriment,
        "fall_ruler_id": fall or None,
        "triplicity": {
            "system": triplicity_system if triplicity_system in TRIPLICITY_RULERS else "dorothean",
            "element": SIGN_ELEMENTS[sign_idx],
            "day_ruler_id": day_t or None,
            "night_ruler_id": night_t or None,
            "participating_ruler_id": part_t or None,
            "active_ruler_id": active_t or None,
            "sect_used": "day" if is_day else "night",
        },
        "bounds": bounds,
        "decan": decan,
        "is_peregrine": peregrine,
        "is_in_own_domicile": body_id == domicile,
        "is_in_own_exaltation": body_id == exaltation if exaltation else False,
        "is_in_detriment": body_id == detriment,
        "is_in_fall": body_id == fall if fall else False,
        "rule_id": "dignity.assignment.v1",
        "algorithm_version": ALGORITHM_VERSION,
        "systems": {
            "bounds": bounds["system"],
            "triplicity": triplicity_system if triplicity_system in TRIPLICITY_RULERS else "dorothean",
            "decan": "chaldean_faces",
        },
    }


def _full_body_calc(
    jd_ut: float,
    body_id: str,
    cusps: list[float],
    angles: dict[str, float],
    latitude: float,
    longitude: float,
    altitude_m: float,
    sidereal: bool,
    warnings: list[str],
) -> dict[str, Any] | None:
    spec = BODY_REGISTRY[body_id]
    calculated = calculate_values(jd_ut, spec, warnings, sidereal=sidereal)
    if calculated is None:
        return None
    values, ephemeris_name = calculated
    lon = (values[0] + spec.longitude_offset) % 360.0
    lat = float(values[1])
    dist = float(values[2])
    lon_speed = float(values[3])
    lat_speed = float(values[4]) if len(values) > 4 else None
    dist_speed = float(values[5]) if len(values) > 5 else None
    house, continuous, from_prev, to_next = _continuous_house(lon, cusps)
    ra, dec = _equatorial(jd_ut, body_id, warnings)
    az, alt_true, alt_app = _horizontal(jd_ut, body_id, latitude, longitude, altitude_m, warnings)
    ha = _hour_angle(jd_ut, ra, longitude)
    above = None if alt_true is None else alt_true > 0.0
    axis_dist = {
        key: _r(angular_separation(lon, angles[key]), 6)
        for key in ("ASC", "MC", "DSC", "IC")
        if key in angles
    }
    return {
        "body_id": body_id,
        "names": {
            "en": BODY_EN.get(body_id, body_id),
            "zh": planet_name(body_id),
        },
        "ecliptic": {
            "longitude_deg": _r(lon),
            "latitude_deg": _r(lat),
            "distance_au": _r(dist, 10),
            "longitude_speed_deg_per_day": _r(lon_speed),
            "latitude_speed_deg_per_day": _r(lat_speed) if lat_speed is not None else None,
            "distance_speed_au_per_day": _r(dist_speed, 10) if dist_speed is not None else None,
        },
        "sign": _sign_display(lon),
        "equatorial": {
            "right_ascension_deg": _r(ra) if ra is not None else None,
            "declination_deg": _r(dec) if dec is not None else None,
            "hour_angle_deg": ha,
        },
        "horizontal": {
            "azimuth_deg": _r(az) if az is not None else None,
            "altitude_true_deg": _r(alt_true) if alt_true is not None else None,
            "altitude_apparent_deg": _r(alt_app) if alt_app is not None else None,
            "above_horizon": above,
        },
        "house": {
            "integer_house": house,
            "continuous_house": _r(continuous, 6),
            "distance_from_previous_cusp_deg": _r(from_prev, 6),
            "distance_to_next_cusp_deg": _r(to_next, 6),
            "uses_ecliptic_longitude_only": True,
        },
        "distance_to_angles_deg": axis_dist,
        "motion": _motion_state(body_id, lon_speed),
        "ephemeris_source": ephemeris_name,
        "precision": {
            "coordinate_center": "geocentric",
            "position_type": "true_position",
            "note": "Swiss Ephemeris FLG_SWIEPH|FLG_SPEED; no light-time correction flag beyond SE defaults",
        },
    }


def _search_station(
    chart_dt: datetime,
    body_id: str,
    direction: str,
    warnings: list[str],
    sidereal: bool,
    max_days: float = 400.0,
) -> dict[str, Any] | None:
    """Find next/previous speed zero crossing (station)."""
    if body_id in {"SUN", "MOON"}:
        return None
    spec = BODY_REGISTRY[body_id]
    warning_keys: set[str] = set()
    step = timedelta(hours=6)
    span = timedelta(days=max_days)
    start = chart_dt
    if direction == "previous":
        end = chart_dt - span
        step = -step
    else:
        end = chart_dt + span

    prev_dt = start
    prev_speed_t = body_speed_at(prev_dt, spec, warnings, warning_keys, sidereal=sidereal)
    if prev_speed_t is None:
        return None
    prev_speed = prev_speed_t[0]
    t = start + step
    while (direction == "next" and t <= end) or (direction == "previous" and t >= end):
        cur = body_speed_at(t, spec, warnings, warning_keys, sidereal=sidereal)
        if cur is None:
            return None
        speed = cur[0]
        if prev_speed == 0 or speed == 0 or (prev_speed < 0 < speed) or (prev_speed > 0 > speed):
            # binary refine on UTC
            a, b = prev_dt, t
            a_utc, _ = _to_utc_for_search(a)
            b_utc, _ = _to_utc_for_search(b)
            if b_utc < a_utc:
                a_utc, b_utc = b_utc, a_utc
            for _ in range(40):
                mid = a_utc + (b_utc - a_utc) / 2
                mid_local = mid.astimezone(chart_dt.tzinfo) if chart_dt.tzinfo else mid.replace(tzinfo=None)
                mid_speed_t = body_speed_at(mid_local, spec, warnings, warning_keys, sidereal=sidereal)
                if mid_speed_t is None:
                    break
                if abs(mid_speed_t[0]) < 1e-8:
                    a_utc = mid
                    break
                left_speed_t = body_speed_at(
                    a_utc.astimezone(chart_dt.tzinfo) if chart_dt.tzinfo else a_utc.replace(tzinfo=None),
                    spec, warnings, warning_keys, sidereal=sidereal,
                )
                if left_speed_t is None:
                    break
                if (left_speed_t[0] < 0 < mid_speed_t[0]) or (left_speed_t[0] > 0 > mid_speed_t[0]) or left_speed_t[0] == 0:
                    b_utc = mid
                else:
                    a_utc = mid
            exact = a_utc.astimezone(chart_dt.tzinfo) if chart_dt.tzinfo else a_utc.replace(tzinfo=None)
            after = body_speed_at(exact + timedelta(hours=1), spec, warnings, warning_keys, sidereal=sidereal)
            before = body_speed_at(exact - timedelta(hours=1), spec, warnings, warning_keys, sidereal=sidereal)
            kind = "station_direct" if after and after[0] > 0 else "station_retrograde"
            if before and after and before[0] > 0 and after[0] < 0:
                kind = "station_retrograde"
            elif before and after and before[0] < 0 and after[0] > 0:
                kind = "station_direct"
            return {
                "kind": kind,
                "datetime_local": format_local(exact),
                "datetime_utc": exact.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "offset_seconds_from_query": int((exact.astimezone(timezone.utc) - chart_dt.astimezone(timezone.utc)).total_seconds()),
            }
        prev_dt = t
        prev_speed = speed
        t = t + step
    return None


def _pair_key(a: str, b: str) -> str:
    left, right = sorted((a, b))
    return f"{left}|{right}"


def _applying_with_motion(
    chart_dt: datetime,
    left_id: str,
    right_id: str,
    angle: float,
    left_speed: float,
    right_speed: float,
    left_lon: float,
    right_lon: float,
    warnings: list[str],
    sidereal: bool,
) -> tuple[str, dict[str, Any]]:
    """Determine applying/separating using relative motion; evidence includes speeds."""
    orb = signed_aspect_orb(left_lon, right_lon, angle)
    rel_speed = left_speed - right_speed
    if abs(orb) < 1e-9:
        label = "applying"  # exact at chart moment
        zh = "入相"
    elif abs(rel_speed) < 1e-12:
        label = "separating"
        zh = "离相"
    else:
        zh = "入相" if orb * rel_speed < 0 else "离相"
        label = "applying" if zh == "入相" else "separating"
    return label, {
        "signed_orb_deg": _r(orb, 8),
        "relative_speed_deg_per_day": _r(rel_speed, 8),
        "method": "signed_orb_times_relative_speed",
        "label_zh": zh,
    }


def _build_pairwise(
    chart_dt: datetime,
    bodies: list[dict[str, Any]],
    aspect_orb: float,
    warnings: list[str],
    sidereal: bool,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    by_id = {b["body_id"]: b for b in bodies}
    ids = [b["body_id"] for b in bodies]
    geometry_rows: list[dict[str, Any]] = []
    aspect_rows: list[dict[str, Any]] = []
    warning_keys: set[str] = set()

    for i, left_id in enumerate(ids):
        for right_id in ids[i + 1 :]:
            left = by_id[left_id]
            right = by_id[right_id]
            lon_a = left["ecliptic"]["longitude_deg"]
            lon_b = right["ecliptic"]["longitude_deg"]
            spd_a = left["ecliptic"]["longitude_speed_deg_per_day"] or 0.0
            spd_b = right["ecliptic"]["longitude_speed_deg_per_day"] or 0.0
            raw_sep = norm360(lon_b - lon_a)
            min_sep = angular_separation(lon_a, lon_b)
            rel_speed = spd_a - spd_b
            nearest_aspect = None
            nearest_delta = None
            for aspect_name_zh, angle in CLASSICAL_ASPECTS.items():
                delta = abs(min_sep - angle)
                if nearest_delta is None or delta < nearest_delta:
                    nearest_delta = delta
                    nearest_aspect = {
                        "aspect_id": ASPECT_EN.get(aspect_name_zh, aspect_name_zh),
                        "aspect_angle_deg": angle,
                        "delta_to_aspect_deg": _r(delta, 8),
                        "within_orb": delta <= aspect_orb,
                    }

            pair = {
                "id": _pair_key(left_id, right_id),
                "body_a_id": left_id,
                "body_b_id": right_id,
                "raw_separation_deg": _r(raw_sep, 8),
                "minimum_separation_deg": _r(min_sep, 8),
                "relative_speed_deg_per_day": _r(rel_speed, 8),
                "motion_direction": "converging" if (nearest_aspect and nearest_aspect["within_orb"] and applying_label(
                    {"longitude": lon_a, "speed": spd_a},
                    {"longitude": lon_b, "speed": spd_b},
                    nearest_aspect["aspect_angle_deg"],
                ) == "入相") else "diverging",
                "deltas_to_aspect_angles": [
                    {
                        "aspect_id": ASPECT_EN[name],
                        "angle_deg": ang,
                        "delta_deg": _r(abs(min_sep - ang), 8),
                    }
                    for name, ang in sorted(CLASSICAL_ASPECTS.items(), key=lambda kv: kv[1])
                ],
                "nearest_aspect": nearest_aspect,
                "orb_limit_deg": aspect_orb,
                "geometry_type": "zodiacal",
                "algorithm_version": ALGORITHM_VERSION,
            }
            geometry_rows.append(pair)

            # Degree aspects within orb
            fake_a = {"id": left_id, "name": left["names"]["zh"], "longitude": lon_a, "speed": spd_a}
            fake_b = {"id": right_id, "name": right["names"]["zh"], "longitude": lon_b, "speed": spd_b}
            for aspect_name_zh, angle in CLASSICAL_ASPECTS.items():
                orb = abs(min_sep - angle)
                if orb > aspect_orb:
                    continue
                apply_label, apply_ev = _applying_with_motion(
                    chart_dt, left_id, right_id, angle, spd_a, spd_b, lon_a, lon_b, warnings, sidereal,
                )
                signature = (aspect_name_zh, "degree", orb, apply_ev["label_zh"], "degree-based aspect")
                exact_dt, reason = exact_datetime_result_for_signature(
                    chart_dt, fake_a, fake_b, signature, warnings, sidereal=sidereal,
                )
                prev_exact = previous_exact_for_pair(
                    chart_dt, left_id, right_id, angle, warnings, warning_keys,
                    max_days=int(DEFAULT_EVENT_PAST_DAYS) + 1, step_hours=6, sidereal=sidereal,
                )
                left_exit_before = False
                right_exit_before = False
                refranation = reason.startswith("refranation") if reason else False
                if exact_dt is not None:
                    left_exit_before = body_exits_sign_before(
                        chart_dt, exact_dt, left_id, warnings, warning_keys, sidereal=sidereal
                    )
                    right_exit_before = body_exits_sign_before(
                        chart_dt, exact_dt, right_id, warnings, warning_keys, sidereal=sidereal
                    )
                aspect_id = ASPECT_EN[aspect_name_zh]
                aspect_rows.append({
                    "id": f"{_pair_key(left_id, right_id)}|{aspect_id}",
                    "body_a_id": left_id,
                    "body_b_id": right_id,
                    "aspect_id": aspect_id,
                    "aspect_angle_deg": angle,
                    "orb_deg": _r(orb, 8),
                    "orb_limit_deg": aspect_orb,
                    "within_orb": True,
                    "application": apply_label,
                    "application_evidence": apply_ev,
                    "previous_exact": {
                        "datetime_local": format_local(prev_exact) if prev_exact else None,
                        "datetime_utc": prev_exact.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if prev_exact else None,
                    } if prev_exact else None,
                    "next_exact": {
                        "datetime_local": format_local(exact_dt) if exact_dt else None,
                        "datetime_utc": exact_dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if exact_dt else None,
                        "root_status": "found" if exact_dt else "not_found",
                        "root_reason": reason,
                    },
                    "sign_exit_before_exact": {
                        "body_a": left_exit_before,
                        "body_b": right_exit_before,
                    },
                    "refranation_detected": refranation,
                    "geometry_type": "zodiacal",
                    "rule_id": "aspect.ptolemaic.degree.v1",
                    "algorithm_version": ALGORITHM_VERSION,
                })

    geometry_rows.sort(key=lambda r: r["id"])
    aspect_rows.sort(key=lambda r: r["id"])
    return geometry_rows, aspect_rows


def _build_receptions(
    bodies: list[dict[str, Any]],
    dignities: list[dict[str, Any]],
    aspects: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    dig_by = {d["body_id"]: d for d in bodies}
    dig_map = {d["body_id"]: d for d in dignities}
    aspect_index = {
        _pair_key(a["body_a_id"], a["body_b_id"]): a["id"]
        for a in aspects
    }
    rows: list[dict[str, Any]] = []
    seen: set[str] = set()
    for received in bodies:
        rid = received["body_id"]
        dig = dig_map[rid]
        assignments = [
            ("domicile", dig["domicile_ruler_id"]),
            ("exaltation", dig["exaltation_ruler_id"]),
            ("triplicity", dig["triplicity"]["active_ruler_id"]),
            ("bound", dig["bounds"]["ruler_id"]),
            ("decan", dig["decan"]["ruler_id"]),
            ("detriment", dig["detriment_ruler_id"] if dig["is_in_detriment"] else None),
            ("fall", dig["fall_ruler_id"] if dig["is_in_fall"] else None),
        ]
        # Always emit domicile/exaltation/triplicity/bound/decan as "received by ruler"
        for dignity_type, receiver_id in [
            ("domicile", dig["domicile_ruler_id"]),
            ("exaltation", dig["exaltation_ruler_id"]),
            ("triplicity", dig["triplicity"]["active_ruler_id"]),
            ("bound", dig["bounds"]["ruler_id"]),
            ("decan", dig["decan"]["ruler_id"]),
        ]:
            if not receiver_id or receiver_id == rid:
                continue
            if receiver_id not in dig_by:
                continue
            key = f"{receiver_id}|{rid}|{dignity_type}"
            if key in seen:
                continue
            seen.add(key)
            pair = _pair_key(receiver_id, rid)
            rows.append({
                "id": key,
                "receiver_id": receiver_id,
                "received_body_id": rid,
                "dignity_type": dignity_type,
                "dignity_interval": {
                    "bounds": dig["bounds"] if dignity_type == "bound" else None,
                    "decan": dig["decan"] if dignity_type == "decan" else None,
                    "sign_index": dig["sign_index"],
                },
                "system": dig["systems"],
                "direction": "receiver_disposes_received",
                "related_aspect_id": aspect_index.get(pair),
                "rule_id": "reception.directed.v1",
                "algorithm_version": ALGORITHM_VERSION,
            })
    rows.sort(key=lambda r: r["id"])
    return rows


def _event_row(
    event_type: str,
    exact: datetime,
    chart_dt: datetime,
    body_ids: list[str],
    *,
    aspect_id: str | None = None,
    extras: dict[str, Any] | None = None,
    root_error: float | None = None,
    rule_id: str = "event.v1",
) -> dict[str, Any]:
    utc = exact.astimezone(timezone.utc)
    chart_utc = chart_dt.astimezone(timezone.utc)
    eid_parts = [event_type] + body_ids
    if aspect_id:
        eid_parts.append(aspect_id)
    eid_parts.append(utc.strftime("%Y%m%dT%H%M%SZ"))
    row = {
        "id": "|".join(eid_parts),
        "event_type": event_type,
        "body_ids": body_ids,
        "aspect_id": aspect_id,
        "datetime_utc": utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "datetime_local": format_local(exact),
        "offset_seconds_from_query": int((utc - chart_utc).total_seconds()),
        "root_error_deg": _r(root_error, 10) if root_error is not None else None,
        "rule_id": rule_id,
        "algorithm_version": ALGORITHM_VERSION,
        "in_configured_window": True,
    }
    if extras:
        row.update(extras)
    return row


def _jd_ut_to_local(jd_ut: float, chart_dt: datetime) -> datetime:
    year, month, day, hour_f = swe.revjul(jd_ut, swe.GREG_CAL)
    hour = int(hour_f)
    minute = int((hour_f - hour) * 60.0)
    second = int(round((((hour_f - hour) * 60.0) - minute) * 60.0))
    if second >= 60:
        second = 0
        minute += 1
    if minute >= 60:
        minute = 0
        hour += 1
    utc = datetime(int(year), int(month), int(day), hour % 24, minute, max(0, min(second, 59)), tzinfo=timezone.utc)
    if chart_dt.tzinfo is not None:
        return utc.astimezone(chart_dt.tzinfo)
    return utc.replace(tzinfo=None)


def _next_sun_rise_or_set(
    chart_dt: datetime,
    latitude: float,
    longitude: float,
    altitude_m: float,
    rise: bool,
) -> datetime | None:
    jd = jd_from_datetime(chart_dt)
    geopos = (float(longitude), float(latitude), float(altitude_m))
    rsmi = swe.CALC_RISE if rise else swe.CALC_SET
    try:
        res, tret = swe.rise_trans(jd, swe.SUN, rsmi, geopos, 0.0, 0.0)
    except swe.Error:
        return None
    if res != 0:
        return None
    return _jd_ut_to_local(float(tret[0]), chart_dt)


def _next_house_change(
    chart_dt: datetime,
    body_id: str,
    cusps: list[float],
    warnings: list[str],
    sidereal: bool,
    max_days: float,
    step_hours: int,
) -> tuple[datetime, int, int] | None:
    """Return (exact, from_house, to_house) for next integer house change."""
    warning_keys: set[str] = set()
    spec = BODY_REGISTRY[body_id]
    start = body_longitude_at(chart_dt, spec, warnings, warning_keys, sidereal=sidereal)
    if start is None:
        return None
    prev_house = house_for_longitude(start[0], cusps)
    prev_dt = chart_dt
    t = chart_dt
    end = chart_dt + timedelta(days=max_days)
    step = timedelta(hours=step_hours)
    while t < end:
        t = min(t + step, end)
        cur = body_longitude_at(t, spec, warnings, warning_keys, sidereal=sidereal)
        if cur is None:
            return None
        house = house_for_longitude(cur[0], cusps)
        if house != prev_house:
            # binary refine on UTC
            a_utc, _ = _to_utc_for_search(prev_dt)
            b_utc, _ = _to_utc_for_search(t)
            left_house = prev_house
            for _ in range(40):
                mid = a_utc + (b_utc - a_utc) / 2
                mid_local = mid.astimezone(chart_dt.tzinfo) if chart_dt.tzinfo else mid.replace(tzinfo=None)
                mid_lon = body_longitude_at(mid_local, spec, warnings, warning_keys, sidereal=sidereal)
                if mid_lon is None:
                    break
                mid_house = house_for_longitude(mid_lon[0], cusps)
                if mid_house == left_house:
                    a_utc = mid
                else:
                    b_utc = mid
            exact = b_utc.astimezone(chart_dt.tzinfo) if chart_dt.tzinfo else b_utc.replace(tzinfo=None)
            return exact, prev_house, house
        prev_dt = t
        prev_house = house
    return None


def _previous_house_change(
    chart_dt: datetime,
    body_id: str,
    cusps: list[float],
    warnings: list[str],
    sidereal: bool,
    max_days: float,
    step_hours: int,
) -> tuple[datetime, int, int] | None:
    """Return (exact, from_house, to_house) for most recent past integer house change.

    Scans backward from chart_dt within past_days. ``from_house`` is the house
    before the crossing; ``to_house`` is the house entered at the crossing
    (same semantics as next: pre-change house, post-change house).
    """
    warning_keys: set[str] = set()
    spec = BODY_REGISTRY[body_id]
    start = body_longitude_at(chart_dt, spec, warnings, warning_keys, sidereal=sidereal)
    if start is None:
        return None
    # At chart: current house is "after" the last change.
    curr_house = house_for_longitude(start[0], cusps)
    prev_dt = chart_dt
    t = chart_dt
    end = chart_dt - timedelta(days=max_days)
    step = timedelta(hours=step_hours)
    while t > end:
        t = max(t - step, end)
        cur = body_longitude_at(t, spec, warnings, warning_keys, sidereal=sidereal)
        if cur is None:
            return None
        house = house_for_longitude(cur[0], cusps)
        if house != curr_house:
            # Crossing between t (older, house=from) and prev_dt (newer, house=to=curr_house)
            a_utc, _ = _to_utc_for_search(t)
            b_utc, _ = _to_utc_for_search(prev_dt)
            left_house = house
            for _ in range(40):
                mid = a_utc + (b_utc - a_utc) / 2
                mid_local = mid.astimezone(chart_dt.tzinfo) if chart_dt.tzinfo else mid.replace(tzinfo=None)
                mid_lon = body_longitude_at(mid_local, spec, warnings, warning_keys, sidereal=sidereal)
                if mid_lon is None:
                    break
                mid_house = house_for_longitude(mid_lon[0], cusps)
                if mid_house == left_house:
                    a_utc = mid
                else:
                    b_utc = mid
            exact = b_utc.astimezone(chart_dt.tzinfo) if chart_dt.tzinfo else b_utc.replace(tzinfo=None)
            # from_house at older side, to_house at chart side of crossing
            return exact, house, curr_house
        prev_dt = t
        curr_house = house
    return None


def _build_events(
    chart_dt: datetime,
    body_ids: list[str],
    bodies: list[dict[str, Any]],
    aspects: list[dict[str, Any]],
    past_days: float,
    future_days: float,
    warnings: list[str],
    sidereal: bool,
    latitude: float,
    longitude: float,
    sun_lon: float,
    cusps: list[float] | None = None,
    altitude_m: float = 0.0,
    moon_index: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    warning_keys: set[str] = set()
    events: list[dict[str, Any]] = []
    chart_utc = chart_dt.astimezone(timezone.utc)
    window_start = chart_dt - timedelta(days=past_days)
    window_end = chart_dt + timedelta(days=future_days)

    # Aspect exacts from aspect rows + past searches
    for asp in aspects:
        ne = asp.get("next_exact") or {}
        if ne.get("datetime_local"):
            # parse via existing search already done; re-search for datetime object
            exact = next_exact_for_pair(
                chart_dt, asp["body_a_id"], asp["body_b_id"],
                CLASSICAL_ANGLES[asp["aspect_id"]], warnings, warning_keys,
                max_days=int(future_days) + 1, step_hours=6, sidereal=sidereal,
            )
            if exact is not None and window_start <= exact <= window_end:
                events.append(_event_row(
                    "aspect_exact", exact, chart_dt,
                    [asp["body_a_id"], asp["body_b_id"]],
                    aspect_id=asp["aspect_id"],
                    rule_id="event.aspect_exact.v1",
                    extras={"application_at_query": asp["application"]},
                ))
        pe = asp.get("previous_exact")
        if pe and pe.get("datetime_local"):
            prev = previous_exact_for_pair(
                chart_dt, asp["body_a_id"], asp["body_b_id"],
                CLASSICAL_ANGLES[asp["aspect_id"]], warnings, warning_keys,
                max_days=int(past_days) + 1, step_hours=6, sidereal=sidereal,
            )
            if prev is not None and window_start <= prev <= window_end:
                events.append(_event_row(
                    "aspect_exact", prev, chart_dt,
                    [asp["body_a_id"], asp["body_b_id"]],
                    aspect_id=asp["aspect_id"],
                    rule_id="event.aspect_exact.v1",
                ))

    # Sign exits
    for body_id in body_ids:
        exit_dt = next_sign_exit_for_body(
            chart_dt, body_id, warnings, warning_keys,
            max_days=min(int(future_days) + 1, 1200),
            step_hours=1 if body_id == "MOON" else 6,
            sidereal=sidereal,
        )
        if exit_dt is not None and window_start <= exit_dt <= window_end:
            events.append(_event_row(
                "sign_ingress", exit_dt, chart_dt, [body_id],
                rule_id="event.sign_ingress.v1",
            ))

    # Stations
    for body_id in body_ids:
        if body_id in {"SUN", "MOON"}:
            continue
        for direction in ("next", "previous"):
            st = _search_station(chart_dt, body_id, direction, warnings, sidereal, max_days=min(future_days, 400) if direction == "next" else min(past_days, 400))
            if st is None:
                continue
            # rebuild datetime
            try:
                exact = datetime.strptime(st["datetime_utc"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
                if chart_dt.tzinfo:
                    exact = exact.astimezone(chart_dt.tzinfo)
            except Exception:
                continue
            if window_start <= exact <= window_end:
                events.append(_event_row(
                    st["kind"], exact, chart_dt, [body_id],
                    rule_id="event.station.v1",
                ))

    # Solar condition boundary crossings for non-sun bodies (ecliptic separation)
    for body_id in body_ids:
        if body_id == "SUN":
            continue
        for label, threshold in (
            ("cazimi", CAZIMI_ORB_DEG),
            ("combust", COMBUST_ORB_DEG),
            ("under_beams", UNDER_BEAMS_ORB_DEG),
        ):
            for angle in (threshold,):
                # entering/leaving approximated by exact separation = threshold
                for direction, start in (("next", chart_dt), ("previous", chart_dt)):
                    if direction == "next":
                        exact = next_exact_for_pair(
                            start, "SUN", body_id, angle, warnings, warning_keys,
                            max_days=int(future_days) + 1, step_hours=6, sidereal=sidereal,
                        )
                    else:
                        exact = previous_exact_for_pair(
                            start, "SUN", body_id, angle, warnings, warning_keys,
                            max_days=int(past_days) + 1, step_hours=6, sidereal=sidereal,
                        )
                    if exact is None or not (window_start <= exact <= window_end):
                        continue
                    events.append(_event_row(
                        f"solar_{label}_boundary",
                        exact,
                        chart_dt,
                        ["SUN", body_id],
                        rule_id=f"event.solar_{label}_boundary.v1",
                        extras={"threshold_deg": threshold},
                    ))

    # Sunrise / sunset (next within window; also previous day boundary if in past window)
    for rise, etype in ((True, "sunrise"), (False, "sunset")):
        exact = _next_sun_rise_or_set(chart_dt - timedelta(days=1), latitude, longitude, altitude_m, rise)
        # walk forward up to future_days+1
        probes = [chart_dt - timedelta(hours=1)]
        for day_off in range(0, int(future_days) + 2):
            probes.append(chart_dt + timedelta(days=day_off))
        seen_jd: set[str] = set()
        for probe in probes:
            exact = _next_sun_rise_or_set(probe, latitude, longitude, altitude_m, rise)
            if exact is None:
                continue
            key = exact.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            if key in seen_jd:
                continue
            seen_jd.add(key)
            if window_start <= exact <= window_end:
                events.append(_event_row(
                    etype, exact, chart_dt, ["SUN"],
                    rule_id=f"event.{etype}.swiss_rise_trans.v1",
                    extras={"state_before": "below_horizon" if rise else "above_horizon",
                            "state_after": "above_horizon" if rise else "below_horizon"},
                ))

    # Lunar phase exacts: new moon (0°) and full moon (180°)
    for phase_name, angle in (("new_moon", 0.0), ("full_moon", 180.0)):
        for direction in ("next", "previous"):
            if direction == "next":
                exact = next_exact_for_pair(
                    chart_dt, "MOON", "SUN", angle, warnings, warning_keys,
                    max_days=int(future_days) + 1, step_hours=6, sidereal=sidereal,
                )
            else:
                exact = previous_exact_for_pair(
                    chart_dt, "MOON", "SUN", angle, warnings, warning_keys,
                    max_days=int(past_days) + 1, step_hours=6, sidereal=sidereal,
                )
            if exact is None or not (window_start <= exact <= window_end):
                continue
            events.append(_event_row(
                "lunar_phase_exact", exact, chart_dt, ["MOON", "SUN"],
                aspect_id="conjunction" if angle == 0.0 else "opposition",
                rule_id="event.lunar_phase_exact.v1",
                extras={"phase_name": phase_name, "phase_angle_deg": angle},
            ))

    # House changes (future + past within configured window)
    if cusps is not None and len(cusps) == 12:
        for body_id in body_ids:
            step_h = 1 if body_id == "MOON" else 6
            fut_days = min(future_days, 40 if body_id == "MOON" else 400)
            past_scan = min(past_days, 40 if body_id == "MOON" else 400)
            hit = _next_house_change(
                chart_dt, body_id, cusps, warnings, sidereal,
                max_days=fut_days,
                step_hours=step_h,
            )
            if hit is not None:
                exact, from_h, to_h = hit
                if window_start <= exact <= window_end:
                    events.append(_event_row(
                        "house_change", exact, chart_dt, [body_id],
                        rule_id="event.house_change.v1",
                        extras={
                            "state_before": {"integer_house": from_h},
                            "state_after": {"integer_house": to_h},
                            "direction": "next",
                        },
                    ))
            prev_hit = _previous_house_change(
                chart_dt, body_id, cusps, warnings, sidereal,
                max_days=past_scan,
                step_hours=step_h,
            )
            if prev_hit is not None:
                exact, from_h, to_h = prev_hit
                if window_start <= exact <= window_end:
                    events.append(_event_row(
                        "house_change", exact, chart_dt, [body_id],
                        rule_id="event.house_change.v1",
                        extras={
                            "state_before": {"integer_house": from_h},
                            "state_after": {"integer_house": to_h},
                            "direction": "previous",
                        },
                    ))

    # VOC start / end from moon index rules (if provided)
    if moon_index is not None:
        for rule in moon_index.get("void_of_course_rules", []):
            interval = rule.get("interval") or {}
            start_s = interval.get("start_datetime_utc")
            end_s = interval.get("end_datetime_utc")
            if start_s:
                try:
                    start_dt = datetime.strptime(start_s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
                    if chart_dt.tzinfo:
                        start_dt = start_dt.astimezone(chart_dt.tzinfo)
                    if window_start <= start_dt <= window_end:
                        events.append(_event_row(
                            "void_of_course_start", start_dt, chart_dt, ["MOON"],
                            rule_id=rule["rule_id"],
                            extras={"voc_rule_id": rule["rule_id"]},
                        ))
                except ValueError:
                    pass
            if end_s:
                try:
                    end_dt = datetime.strptime(end_s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
                    if chart_dt.tzinfo:
                        end_dt = end_dt.astimezone(chart_dt.tzinfo)
                    if window_start <= end_dt <= window_end:
                        events.append(_event_row(
                            "void_of_course_end", end_dt, chart_dt, ["MOON"],
                            rule_id=rule["rule_id"],
                            extras={"voc_rule_id": rule["rule_id"]},
                        ))
                except ValueError:
                    pass

    # Deduplicate by id, sort by offset then id
    uniq: dict[str, dict[str, Any]] = {}
    for ev in events:
        uniq[ev["id"]] = ev
    ordered = sorted(uniq.values(), key=lambda e: (e["offset_seconds_from_query"], e["id"]))
    return ordered


def _moon_index(
    chart_dt: datetime,
    bodies: list[dict[str, Any]],
    events: list[dict[str, Any]],
    warnings: list[str],
    sidereal: bool,
) -> dict[str, Any]:
    warning_keys: set[str] = set()
    moon = next(b for b in bodies if b["body_id"] == "MOON")
    moon_lon = moon["ecliptic"]["longitude_deg"]
    sun = next(b for b in bodies if b["body_id"] == "SUN")
    sun_lon = sun["ecliptic"]["longitude_deg"]
    phase_angle = norm360(moon_lon - sun_lon)
    elongation = angular_separation(moon_lon, sun_lon)
    illumination = (1.0 - math.cos(math.radians(phase_angle))) / 2.0
    # age approximation: phase_angle / mean moon-sun relative speed
    age_days = phase_angle / (MEAN_SPEED["MOON"] - MEAN_SPEED["SUN"])

    sign_exit = next_sign_exit_for_body(
        chart_dt, "MOON", warnings, warning_keys, max_days=4, step_hours=1, sidereal=sidereal,
    )
    remaining_arc = 30.0 - sign_degree(moon_lon)
    remaining_seconds = None
    if sign_exit is not None:
        remaining_seconds = int((sign_exit.astimezone(timezone.utc) - chart_dt.astimezone(timezone.utc)).total_seconds())

    classical_targets = [b for b in CLASSICAL_BODY_IDS if b != "MOON"]
    past_in_sign: list[dict[str, Any]] = []
    future_in_sign: list[dict[str, Any]] = []
    for target_id in classical_targets:
        for aspect_id, angle in CLASSICAL_ANGLES.items():
            prev = previous_exact_for_pair(
                chart_dt, "MOON", target_id, angle, warnings, warning_keys,
                max_days=4, step_hours=1, sidereal=sidereal,
            )
            if prev is not None and (sign_exit is None or prev < sign_exit):
                # ensure still same sign as chart moon for "in current sign"
                prev_lon = body_longitude_at(prev, BODY_REGISTRY["MOON"], warnings, warning_keys, sidereal=sidereal)
                if prev_lon and zodiac_sign_index(prev_lon[0]) == zodiac_sign_index(moon_lon):
                    past_in_sign.append({
                        "target_id": target_id,
                        "aspect_id": aspect_id,
                        "datetime_local": format_local(prev),
                        "datetime_utc": prev.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                    })
            nxt = next_exact_for_pair(
                chart_dt, "MOON", target_id, angle, warnings, warning_keys,
                max_days=4, step_hours=1, sidereal=sidereal,
            )
            if nxt is not None and (sign_exit is None or nxt <= sign_exit):
                future_in_sign.append({
                    "target_id": target_id,
                    "aspect_id": aspect_id,
                    "datetime_local": format_local(nxt),
                    "datetime_utc": nxt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                })

    past_in_sign.sort(key=lambda r: r["datetime_utc"], reverse=True)
    future_in_sign.sort(key=lambda r: r["datetime_utc"])

    after_ingress: list[dict[str, Any]] = []
    if sign_exit is not None:
        start = sign_exit + timedelta(microseconds=1)
        next_exit = next_sign_exit_for_body(
            start, "MOON", warnings, warning_keys, max_days=4, step_hours=1, sidereal=sidereal,
        )
        for target_id in classical_targets:
            for aspect_id, angle in CLASSICAL_ANGLES.items():
                nxt = next_exact_for_pair(
                    start, "MOON", target_id, angle, warnings, warning_keys,
                    max_days=4, step_hours=1, sidereal=sidereal,
                )
                if nxt is None:
                    continue
                if next_exit is not None and nxt > next_exit:
                    continue
                after_ingress.append({
                    "target_id": target_id,
                    "aspect_id": aspect_id,
                    "datetime_local": format_local(nxt),
                    "datetime_utc": nxt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                })
        after_ingress.sort(key=lambda r: r["datetime_utc"])

    # VOC rule variants — neutral data only, each with start/end/duration when known.
    def _voc_interval(
        *,
        value_at_query: bool,
        last_exact_utc: str | None,
        last_future_exact_utc: str | None,
        sign_exit_utc: str | None,
    ) -> dict[str, Any]:
        """Interval of VOC within current sign under exact-before-sign-exit family."""
        end_utc = sign_exit_utc
        if value_at_query:
            # Already VOC: started after last exact in sign (if any).
            start_utc = last_exact_utc
        else:
            # Not VOC now: VOC begins after the final exact still inside the sign.
            start_utc = last_future_exact_utc
        duration = None
        if start_utc and end_utc:
            try:
                s = datetime.strptime(start_utc, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
                e = datetime.strptime(end_utc, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
                duration = int((e - s).total_seconds())
            except ValueError:
                duration = None
        return {
            "start_datetime_utc": start_utc,
            "end_datetime_utc": end_utc,
            "duration_seconds": duration,
            "complete": start_utc is not None and end_utc is not None,
            "reason_code": None if (start_utc and end_utc) else "interval_partial_missing_endpoint",
        }

    sign_exit_utc = (
        sign_exit.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if sign_exit else None
    )
    last_past_utc = past_in_sign[0]["datetime_utc"] if past_in_sign else None
    last_future_utc = future_in_sign[-1]["datetime_utc"] if future_in_sign else None
    voc_before_sign_exit = len(future_in_sign) == 0

    # Rule A: modern exact perfection to classical planets before sign exit (no orb gate)
    rule_a_interval = _voc_interval(
        value_at_query=voc_before_sign_exit,
        last_exact_utc=last_past_utc,
        last_future_exact_utc=last_future_utc,
        sign_exit_utc=sign_exit_utc,
    )
    # Rule B: same aspect set but only count future exacts that are currently applying
    # at the query snapshot (degree application label via relative speed) — independent rule_id.
    applying_future = [
        row for row in future_in_sign
        # conservative: all future_in_sign are exacts searched forward = applying completions
    ]
    voc_applying_only = len(applying_future) == 0
    rule_b_interval = _voc_interval(
        value_at_query=voc_applying_only,
        last_exact_utc=last_past_utc,
        last_future_exact_utc=last_future_utc,
        sign_exit_utc=sign_exit_utc,
    )

    voc_rules = [
        {
            "rule_id": "voc.modern_exact_before_sign_exit.v1",
            "algorithm_version": ALGORITHM_VERSION,
            "value": voc_before_sign_exit,
            "definition": {
                "counts_applying_only": True,
                "requires_exact_perfection": True,
                "bodies": classical_targets,
                "aspects": list(CLASSICAL_ANGLES.keys()),
                "uses_aspect_orb_at_query": False,
                "traditional_seven_only": True,
                "ptolemaic_only": True,
            },
            "interval": rule_a_interval,
            "evidence": {
                "future_exact_count_before_sign_exit": len(future_in_sign),
                "past_exact_count_in_sign": len(past_in_sign),
                "sign_exit_local": format_local(sign_exit) if sign_exit else None,
                "sign_exit_utc": sign_exit_utc,
            },
        },
        {
            "rule_id": "voc.modern_exact_before_sign_exit.applying_completions.v1",
            "algorithm_version": ALGORITHM_VERSION,
            "value": voc_applying_only,
            "definition": {
                "counts_applying_only": True,
                "requires_exact_perfection": True,
                "bodies": classical_targets,
                "aspects": list(CLASSICAL_ANGLES.keys()),
                "uses_aspect_orb_at_query": False,
                "traditional_seven_only": True,
                "ptolemaic_only": True,
                "note": "Separate rule_id for consumers; currently same completion set as v1",
            },
            "interval": rule_b_interval,
            "evidence": {
                "future_exact_count_before_sign_exit": len(applying_future),
                "sign_exit_utc": sign_exit_utc,
            },
        },
    ]

    # Node distance (true node if available in body set — optional)
    node_sep = None

    return {
        "current_sign": moon["sign"],
        "ecliptic_latitude_deg": moon["ecliptic"]["latitude_deg"],
        "declination_deg": moon["equatorial"]["declination_deg"],
        "phase_angle_deg": _r(phase_angle, 6),
        "elongation_from_sun_deg": _r(elongation, 6),
        "illumination_fraction": _r(illumination, 6),
        "age_days_approx": _r(age_days, 6),
        "sign_exit": {
            "datetime_local": format_local(sign_exit) if sign_exit else None,
            "datetime_utc": sign_exit.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if sign_exit else None,
            "remaining_arc_deg": _r(remaining_arc, 6),
            "remaining_seconds": remaining_seconds,
        },
        "past_exact_aspects_in_current_sign": past_in_sign,
        "future_exact_aspects_in_current_sign": future_in_sign,
        "last_exact_aspect_in_current_sign": past_in_sign[0] if past_in_sign else None,
        "next_exact_aspect_in_current_sign": future_in_sign[0] if future_in_sign else None,
        "aspects_in_next_sign": after_ingress,
        "void_of_course_rules": voc_rules,
        "distance_to_north_node_deg": node_sep,
        "notes": {
            "age_method": "phase_angle / (mean_moon_speed - mean_sun_speed)",
            "illumination_method": "(1 - cos(phase_angle)) / 2",
        },
    }


def _visibility_for_bodies(
    bodies: list[dict[str, Any]],
    sun_body: dict[str, Any],
) -> list[dict[str, Any]]:
    sun_lon = sun_body["ecliptic"]["longitude_deg"]
    sun_alt = sun_body["horizontal"]["altitude_true_deg"]
    rows: list[dict[str, Any]] = []
    for body in bodies:
        bid = body["body_id"]
        lon = body["ecliptic"]["longitude_deg"]
        lat = body["ecliptic"]["latitude_deg"] or 0.0
        # spherical separation approx using ecliptic lon/lat vs sun lon/lat
        sun_lat = sun_body["ecliptic"]["latitude_deg"] or 0.0
        # haversine-like on sphere for small angles; use cos formula
        dlon = math.radians(lon - sun_lon)
        a = math.sin(math.radians(lat)) * math.sin(math.radians(sun_lat)) + math.cos(math.radians(lat)) * math.cos(math.radians(sun_lat)) * math.cos(dlon)
        a = max(-1.0, min(1.0, a))
        sphere_sep = math.degrees(math.acos(a))
        lon_sep = angular_separation(lon, sun_lon)

        if bid == "SUN":
            solar_condition = None
            phase = None
            thresholds = {
                "cazimi_deg": CAZIMI_ORB_DEG,
                "combust_deg": COMBUST_ORB_DEG,
                "under_beams_deg": UNDER_BEAMS_ORB_DEG,
            }
            flags = []
        else:
            _, _, _, phase_breakdown = solar_phase(bid, lon, sun_lon, CAZIMI_ORB_DEG, COMBUST_ORB_DEG, UNDER_BEAMS_ORB_DEG)
            solar_condition = phase_breakdown.get("solar_condition")
            thresholds = {
                "cazimi_deg": CAZIMI_ORB_DEG,
                "combust_deg": COMBUST_ORB_DEG,
                "under_beams_deg": UNDER_BEAMS_ORB_DEG,
            }
            flags = [
                _rule_flag(
                    "cazimi",
                    solar_condition == "cazimi",
                    rule_id="solar.cazimi.ecliptic_sep.v1",
                    thresholds={"orb_deg": CAZIMI_ORB_DEG},
                    evidence={"ecliptic_separation_deg": _r(lon_sep, 6)},
                ),
                _rule_flag(
                    "combust",
                    solar_condition == "combust",
                    rule_id="solar.combust.ecliptic_sep.v1",
                    thresholds={"orb_deg": COMBUST_ORB_DEG},
                    evidence={"ecliptic_separation_deg": _r(lon_sep, 6)},
                ),
                _rule_flag(
                    "under_beams",
                    solar_condition == "under_beams",
                    rule_id="solar.under_beams.ecliptic_sep.v1",
                    thresholds={"orb_deg": UNDER_BEAMS_ORB_DEG},
                    evidence={"ecliptic_separation_deg": _r(lon_sep, 6)},
                ),
            ]

        # morning/evening star: east/west of sun by ecliptic longitude
        morning_evening = None
        if bid not in {"SUN"}:
            # oriental: rises before sun → planet longitude west? Traditional: planet is oriental if it rises before sun.
            # Using elongation sign: if planet is behind sun in longitude (sun-planet in 0..180 via norm) ...
            sep_signed = ((lon - sun_lon + 180) % 360) - 180
            morning_evening = "evening" if sep_signed > 0 else "morning"
            # evening star: east of sun (visible after sunset) when planet lon > sun lon in direct motion convention
            # sep_signed > 0 means planet is ahead of sun in zodiac → evening for superior?

        rows.append({
            "body_id": bid,
            "ecliptic_separation_from_sun_deg": _r(lon_sep, 6),
            "spherical_separation_from_sun_deg": _r(sphere_sep, 6),
            "sun_altitude_deg": _r(sun_alt) if sun_alt is not None else None,
            "body_altitude_deg": body["horizontal"]["altitude_true_deg"],
            "phase_angle_deg": _r(sphere_sep, 6) if bid != "SUN" else None,
            "illumination_fraction": None,  # needs pheno; filled below if available
            "apparent_magnitude": None,
            "morning_evening": morning_evening,
            "morning_evening_definition": "signed_ecliptic_offset_from_sun_v1",
            "solar_condition_flags": flags,
            "visible": None,
            "visible_reason_code": "visibility_model_not_configured",
            "visibility_model_id": None,
            "atmosphere": {
                "pressure_mbar": None,
                "temperature_c": None,
                "reason_code": "not_provided",
            },
            "thresholds": thresholds,
            "algorithm_version": ALGORITHM_VERSION,
        })
        # Try pheno_ut for magnitude/phase when available
        if bid != "SUN":
            try:
                spec = BODY_REGISTRY[bid]
                # pheno requires jd and planet; use 0 for attr
                # swe.pheno_ut(jd, planet, flags) -> [phase, phase_angle, elongation, diameter, magnitude]
            except Exception:
                pass
    return rows


def _build_lots_v2(
    angles: dict[str, float],
    body_positions: dict[str, dict[str, Any]],
    cusps: list[float],
    is_day: bool,
    bounds_system: str,
    triplicity_system: str,
    warnings: list[str],
) -> list[dict[str, Any]]:
    """Build judgment-free lots with formula intermediates (no confidence/strength)."""
    pos_for_lots = {
        bid: {"longitude": row["ecliptic"]["longitude_deg"], "name": row["names"]["zh"]}
        for bid, row in body_positions.items()
    }
    asc = angles["ASC"]
    mc_lon = angles.get("MC")
    if mc_lon is None and len(cusps) == 12:
        mc_lon = norm360(cusps[9])
    computed: dict[str, float] = {}
    out: list[dict[str, Any]] = []

    for lot_def in LOT_LIST:
        lid = lot_def["lot_id"]
        try:
            p1_spec = lot_def["day_p1"] if is_day else lot_def["night_p1"]
            p2_spec = lot_def["day_p2"] if is_day else lot_def["night_p2"]
            a = _resolve_lot_ref(p1_spec, computed, pos_for_lots, asc, mc=mc_lon, cusps=cusps)
            b = _resolve_lot_ref(p2_spec, computed, pos_for_lots, asc, mc=mc_lon, cusps=cusps)
            pre_norm = asc + a - b
            lon = norm360(pre_norm)
            computed[lid] = lon
        except (KeyError, TypeError, ValueError) as exc:
            warnings.append(f"lot {lid} skipped: {exc}")
            continue

        day_f, night_f = _formula_text(
            lot_def["day_p1"], lot_def["day_p2"],
            lot_def["night_p1"], lot_def["night_p2"],
        )
        used = day_f if is_day else night_f
        house, continuous, from_prev, to_next = _continuous_house(lon, cusps)
        dig = _dignity_for_body("LOT", lon, is_day, bounds_system, triplicity_system)
        out.append({
            "id": lid,
            "names": {
                "zh": lot_def.get("name_cn", lid),
                "en": lot_def.get("name_en", lid),
            },
            "formula_id": f"lot.{lid}.v1",
            "formula_day": day_f,
            "formula_night": night_f,
            "formula_used": used,
            "sect_used": "day" if is_day else "night",
            "input_points": {
                "asc_longitude_deg": _r(asc),
                "first_operand_spec": p1_spec,
                "first_operand_longitude_deg": _r(a),
                "second_operand_spec": p2_spec,
                "second_operand_longitude_deg": _r(b),
            },
            "intermediates": {
                "asc_plus_first_minus_second_raw": _r(pre_norm, 10),
                "formula": "norm360(ASC + first - second)",
            },
            "longitude_before_normalize_deg": _r(pre_norm, 10),
            "longitude_deg": _r(lon),
            "sign": _sign_display(lon),
            "house": {
                "integer_house": house,
                "continuous_house": _r(continuous, 6),
                "distance_from_previous_cusp_deg": _r(from_prev, 6),
                "distance_to_next_cusp_deg": _r(to_next, 6),
            },
            "domicile_ruler_id": dig["domicile_ruler_id"],
            "bounds_ruler_id": dig["bounds"]["ruler_id"],
            "decan_ruler_id": dig["decan"]["ruler_id"],
            "triplicity_active_ruler_id": dig["triplicity"]["active_ruler_id"],
            "source_tradition": lot_def.get("source"),
            "group": lot_def.get("group"),
            "formula_version": ALGORITHM_VERSION,
        })
    out.sort(key=lambda r: r["id"])
    return out


def _optional_modules(
    bodies: list[dict[str, Any]],
    chart_dt: datetime,
    latitude: float,
    longitude: float,
    is_day: bool,
) -> dict[str, Any]:
    antiscia = []
    for body in bodies:
        lon = body["ecliptic"]["longitude_deg"]
        ant = norm360(180.0 - lon)
        contra = norm360(360.0 - lon)
        antiscia.append({
            "body_id": body["body_id"],
            "longitude_deg": _r(lon),
            "antiscia_longitude_deg": _r(ant),
            "contra_antiscia_longitude_deg": _r(contra),
            "rule_id": "antiscia.cancer_capricorn_axis.v1",
        })
    antiscia.sort(key=lambda r: r["body_id"])

    # Via Combusta fact: traditional Libra 15° – Scorpio 15° (195–225° tropical)
    via = []
    for body in bodies:
        lon = body["ecliptic"]["longitude_deg"]
        hit = 195.0 <= lon < 225.0
        via.append({
            "body_id": body["body_id"],
            "in_via_combusta": hit,
            "interval_deg": {"start": 195.0, "end": 225.0},
            "rule_id": "via_combusta.libra15_scorpio15.v1",
            "evidence": {"longitude_deg": _r(lon)},
        })
    via.sort(key=lambda r: r["body_id"])

    # Dodecatemoria: 12 * sign_degree projected
    dodeka = []
    for body in bodies:
        lon = body["ecliptic"]["longitude_deg"]
        sign_idx = zodiac_sign_index(lon)
        deg = sign_degree(lon)
        d_lon = norm360(sign_idx * 30.0 + deg * 12.0)
        dodeka.append({
            "body_id": body["body_id"],
            "source_longitude_deg": _r(lon),
            "dodecatemoria_longitude_deg": _r(d_lon),
            "rule_id": "dodecatemoria.twelve_fold.v1",
        })
    dodeka.sort(key=lambda r: r["body_id"])

    return {
        "antiscia": antiscia,
        "via_combusta": via,
        "dodecatemoria": dodeka,
        "declination_parallels": {
            "status": "not_computed_in_core",
            "reason_code": "optional_module_deferred",
        },
        "fixed_stars": {
            "status": "not_computed_in_core",
            "reason_code": "optional_module_deferred",
            "note": "Use classical_visibility / fixed star modules for star data",
        },
        "planetary_hour": {
            "status": "not_computed_in_core",
            "reason_code": "optional_module_deferred",
        },
    }


FORBIDDEN_V2_KEYS = {
    "machine_summary",
    "radicality_flags",
    "significator_candidates",
    "key_significator_links",
    "degree_based_key_aspects",
    "advanced_candidates",
    "bonification",
    "maltreatment",
    "score",
    "score_label",
    "score_breakdown",
    "supported_by",
    "negative_receptions",
    "confidence",
    "confidence_tag",
    "strength",
    "strength_label",
    "strength_score",
    "summary",
    "caution",
    "radicality",
    "querent",
    "matter",
    "outcome",
    "natural_significator",
    "negative_reception",
}

# Strength / judgment tokens that must not appear as generator-emitted string values
# (question_text / place_name are excluded — user input may contain any words).
FORBIDDEN_VALUE_TOKENS = frozenset({
    "strong", "medium", "weak",
    "positive", "negative",
    "caution", "summary",
    "bonification", "maltreatment",
})

_USER_TEXT_PATH_MARKERS = (
    "question_metadata.question_text",
    "question_metadata.place_name",
    "validation.warnings",
)


def assert_no_forbidden_fields(packet: dict[str, Any], path: str = "") -> list[str]:
    """Return paths that contain forbidden judgment keys or strength labels."""
    hits: list[str] = []
    if isinstance(packet, dict):
        for key, value in packet.items():
            here = f"{path}.{key}" if path else key
            if key in FORBIDDEN_V2_KEYS or key.startswith("key_"):
                hits.append(here)
            hits.extend(assert_no_forbidden_fields(value, here))
    elif isinstance(packet, list):
        for i, item in enumerate(packet):
            hits.extend(assert_no_forbidden_fields(item, f"{path}[{i}]"))
    elif isinstance(packet, str):
        if any(path.startswith(m) or path == m for m in _USER_TEXT_PATH_MARKERS):
            return hits
        token = packet.strip().lower()
        if token in FORBIDDEN_VALUE_TOKENS:
            hits.append(f"{path}=value:{token}")
    return hits


def _ensure_bundled_ephemeris_path() -> None:
    """Point Swiss Ephemeris at the app-bundled SE files when available."""
    from pathlib import Path

    backend_dir = Path(__file__).resolve().parent
    candidates = [
        backend_dir.parent / "ephemeris",  # Sources/TransitStudio/Resources/ephemeris
        backend_dir / "ephemeris",
    ]
    for path in candidates:
        if path.is_dir() and any(path.glob("*.se1")):
            swe.set_ephe_path(str(path))
            return


def calculate_horary_v2(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    _ensure_bundled_ephemeris_path()
    chart = request["chart"]
    question_text = str(request.get("questionText", "")).strip()
    place_name = str(request.get("placeName", "")).strip()
    aspect_orb = _validated_number(
        "aspectOrb", request.get("aspectOrb", DEFAULT_ASPECT_ORB), minimum=0.0, maximum=10.0,
    )
    altitude_m = _validated_number(
        "altitudeM", request.get("altitudeM", chart.get("altitudeM", 0.0)) or 0.0,
    )
    event_past_days = _validated_number(
        "eventPastDays", request.get("eventPastDays", DEFAULT_EVENT_PAST_DAYS), minimum=0.0,
    )
    event_future_days = _validated_number(
        "eventFutureDays", request.get("eventFutureDays", DEFAULT_EVENT_FUTURE_DAYS), minimum=0.0,
    )
    decl_orb = _validated_number(
        "declinationOrb",
        request.get("declinationOrb", request.get("declination_orb", 1.0)),
        minimum=0.0,
    )
    antiscia_orb = _validated_number(
        "antisciaOrb",
        request.get("antisciaOrb", request.get("antiscia_orb", 1.0)),
        minimum=0.0,
    )
    node_mode = str(request.get("nodeMode") or request.get("node_mode") or "mean").strip().lower()
    if node_mode not in {"mean", "true", "both"}:
        raise ValueError("nodeMode must be one of: mean, true, both")

    raw_body_ids = request.get("bodyIds")
    if raw_body_ids is None:
        body_ids = list(CLASSICAL_BODY_IDS)
    elif isinstance(raw_body_ids, list):
        body_ids = list(raw_body_ids)
    else:
        raise ValueError("bodyIds must be an array")
    for bid in body_ids:
        if not isinstance(bid, str) or bid not in BODY_REGISTRY:
            raise ValueError(f"unknown body id: {bid}")
    if len(body_ids) != len(set(body_ids)):
        raise ValueError("bodyIds must not contain duplicates")
    # Moon index, sect/visibility, and solar conditions require Sun + Moon.
    required_bodies = ("SUN", "MOON")
    missing_required = [b for b in required_bodies if b not in body_ids]
    if missing_required:
        raise ValueError(
            "bodyIds must include at least SUN and MOON "
            f"(missing: {', '.join(missing_required)})"
        )

    chart_dt = moment_to_local_datetime(chart["moment"])
    chart_jd, chart_utc_iso = moment_to_jd(chart["moment"])
    latitude = float(chart["latitude"])
    longitude = float(chart["longitude"])
    house_system = chart.get("houseSystem", "regiomontanus")
    zodiac = chart.get("zodiac", "tropical")
    bounds_system = chart.get("boundsSystem", "egyptian")
    triplicity_system = chart.get("triplicitySystem", "dorothean")

    sidereal = set_zodiac_mode(zodiac, warnings)
    delta_t = _delta_t_seconds(chart_jd)
    jd_tt = chart_jd + (delta_t / 86400.0 if math.isfinite(delta_t) else 0.0)
    obliq = obliquity(chart_jd)
    lst_hours = _sidereal_time_hours(chart_jd)
    armc = _armc_degrees(chart_jd, longitude)

    house_fallback = False
    house_fallback_reason = None
    try:
        cusps, angles, house_label = build_houses(chart_jd, latitude, longitude, house_system, sidereal, warnings)
        if any("改用 Whole Sign" in w or "宫位计算失败" in w for w in warnings):
            house_fallback = True
            house_fallback_reason = "house_system_fallback_to_whole_sign"
    except Exception as exc:
        house_fallback = True
        house_fallback_reason = str(exc)
        cusps, angles, house_label = build_houses(chart_jd, latitude, longitude, "whole_sign", sidereal, warnings)

    # Sun for sect
    sun_calc = calculate_values(chart_jd, BODY_REGISTRY["SUN"], warnings, sidereal=sidereal)
    if sun_calc is None:
        raise RuntimeError("unable to compute Sun position")
    sun_lon = (sun_calc[0][0]) % 360.0
    is_day = longitude_in_interval(sun_lon, angles["DSC"], angles["ASC"])

    bodies: list[dict[str, Any]] = []
    for body_id in body_ids:
        row = _full_body_calc(
            chart_jd, body_id, cusps, angles, latitude, longitude, altitude_m, sidereal, warnings,
        )
        if row is None:
            warnings.append(f"body {body_id} failed to compute")
            continue
        # stations / sign exits attached
        nxt_station = _search_station(chart_dt, body_id, "next", warnings, sidereal)
        prev_station = _search_station(chart_dt, body_id, "previous", warnings, sidereal)
        warning_keys: set[str] = set()
        nxt_sign = next_sign_exit_for_body(
            chart_dt, body_id, warnings, warning_keys,
            max_days=sign_exit_days(body_id), step_hours=1 if body_id == "MOON" else 6, sidereal=sidereal,
        )
        row["events_index"] = {
            "next_station": nxt_station,
            "previous_station": prev_station,
            "next_sign_exit": {
                "datetime_local": format_local(nxt_sign) if nxt_sign else None,
                "datetime_utc": nxt_sign.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if nxt_sign else None,
            } if nxt_sign else None,
        }
        bodies.append(row)
    bodies.sort(key=lambda b: body_ids.index(b["body_id"]))

    dignities = [
        _dignity_for_body(b["body_id"], b["ecliptic"]["longitude_deg"], is_day, bounds_system, triplicity_system)
        for b in bodies
    ]
    dignities.sort(key=lambda d: body_ids.index(d["body_id"]) if d["body_id"] in body_ids else 99)

    from astro_backend_horary_v2_aspects import (
        aspect_exact_events_from_candidates,
        build_aspect_candidates,
    )
    from astro_backend_horary_v2_modules import (
        accidental_condition,
        antiscia_contacts,
        build_nodes,
        considerations_evidence,
        declination_parallels,
        enrich_visibility_pheno,
        event_graph,
        fixed_star_contacts,
        full_reception_matrix,
        planetary_day_hour,
    )

    node_bodies = build_nodes(
        chart_dt, chart_jd, cusps, angles, latitude, longitude, altitude_m,
        sidereal, warnings, _full_body_calc, node_mode=node_mode,
    )
    # Attach accidental conditions for classical bodies
    for b in bodies:
        b["accidental"] = accidental_condition(b, is_day, sun_lon, angles, cusps)
        b["distance_to_angles_deg"] = b.get("distance_to_angles_deg") or {
            k: angular_separation(b["ecliptic"]["longitude_deg"], angles[k])
            for k in ("ASC", "MC", "DSC", "IC") if k in angles
        }

    all_bodies_for_geometry = bodies + [
        n for n in node_bodies if n["body_id"] not in {b["body_id"] for b in bodies}
    ]

    pairwise, aspect_candidates = build_aspect_candidates(
        chart_dt,
        bodies,  # Ptolemaic candidates among classical planets only
        aspect_orb,
        warnings,
        sidereal,
        event_past_days=event_past_days,
        event_future_days=event_future_days,
    )
    # v2.1: `aspects` aliases the full Ptolemaic candidate matrix (compat name);
    # `aspect_candidates` is the canonical full set; `aspects_in_display_orb` is
    # the display-orb convenience filter (does not gate candidate geometry).
    aspects = aspect_candidates
    aspects_in_display_orb = [c for c in aspect_candidates if c.get("within_display_orb")]

    receptions = full_reception_matrix(
        bodies,
        dignities,
        aspect_candidates,
        chart_dt=chart_dt,
        cusps=cusps,
        is_day=is_day,
        bounds_system=bounds_system,
        triplicity_system=triplicity_system,
        warnings=warnings,
        sidereal=sidereal,
    )

    body_pos_map = {b["body_id"]: b for b in bodies}
    lots = _build_lots_v2(angles, body_pos_map, cusps, is_day, bounds_system, triplicity_system, warnings)

    # Moon index first so VOC intervals can feed the unified event stream.
    moon = _moon_index(chart_dt, bodies, [], warnings, sidereal)
    events = _build_events(
        chart_dt, [b["body_id"] for b in bodies], bodies, aspects_in_display_orb,
        event_past_days, event_future_days, warnings, sidereal, latitude, longitude, sun_lon,
        cusps=cusps,
        altitude_m=altitude_m,
        moon_index=moon,
    )
    # Replace/merge aspect_exact from full candidates (not display-filtered)
    non_aspect_events = [e for e in events if e.get("event_type") != "aspect_exact"]
    aspect_events = aspect_exact_events_from_candidates(
        chart_dt, aspect_candidates, event_past_days, event_future_days,
    )
    events = sorted(
        {e["id"]: e for e in (non_aspect_events + aspect_events)}.values(),
        key=lambda e: (e["offset_seconds_from_query"], e["id"]),
    )
    graph = event_graph(
        bodies,
        events,
        aspect_candidates,
        chart_dt,
        cusps=cusps,
        is_day=is_day,
        bounds_system=bounds_system,
        triplicity_system=triplicity_system,
        warnings=warnings,
        sidereal=sidereal,
    )
    # Attach prev/next house_change into each body's events_index
    for body in bodies:
        bid = body["body_id"]
        hc = [
            e for e in events
            if e.get("event_type") == "house_change" and bid in (e.get("body_ids") or [])
        ]
        past_hc = [e for e in hc if e["offset_seconds_from_query"] < 0]
        fut_hc = [e for e in hc if e["offset_seconds_from_query"] >= 0]
        past_hc.sort(key=lambda e: e["offset_seconds_from_query"])
        fut_hc.sort(key=lambda e: e["offset_seconds_from_query"])
        idx = body.setdefault("events_index", {})
        idx["previous_house_change"] = {
            "event_id": past_hc[-1]["id"],
            "datetime_utc": past_hc[-1]["datetime_utc"],
            "datetime_local": past_hc[-1].get("datetime_local"),
            "state_before": past_hc[-1].get("state_before"),
            "state_after": past_hc[-1].get("state_after"),
        } if past_hc else None
        idx["next_house_change"] = {
            "event_id": fut_hc[0]["id"],
            "datetime_utc": fut_hc[0]["datetime_utc"],
            "datetime_local": fut_hc[0].get("datetime_local"),
            "state_before": fut_hc[0].get("state_before"),
            "state_after": fut_hc[0].get("state_after"),
        } if fut_hc else None
    planetary = planetary_day_hour(chart_dt, latitude, longitude, altitude_m, warnings)
    # Mark current hour if available
    try:
        ref_utc = chart_dt.astimezone(timezone.utc)
        for hour in planetary.get("hours") or []:
            start = datetime.fromisoformat(hour["start_utc"].replace("Z", "+00:00"))
            end = datetime.fromisoformat(hour["end_utc"].replace("Z", "+00:00"))
            if start <= ref_utc < end:
                planetary["current_hour"] = hour
                break
    except Exception:
        pass
    considerations = considerations_evidence(angles, bodies, moon, planetary, {"cusps": cusps})
    decl_packet = declination_parallels(
        bodies + node_bodies,
        chart_dt=chart_dt,
        orb_deg=decl_orb,
        warnings=warnings,
        sidereal=sidereal,
        past_days=event_past_days,
        future_days=event_future_days,
    )
    if isinstance(decl_packet, dict):
        declination_rows = decl_packet.get("contacts") or []
        moon_decl_seq = decl_packet.get("moon_sequence")
    else:
        declination_rows = decl_packet
        moon_decl_seq = None
    antiscia_rows = antiscia_contacts(bodies + node_bodies, angles, cusps, lots, orb_deg=antiscia_orb)
    stars_packet = fixed_star_contacts(chart_jd, bodies, angles, sidereal, warnings)
    sun_body = body_pos_map["SUN"]
    visibility = enrich_visibility_pheno(
        chart_jd, _visibility_for_bodies(bodies, sun_body), bodies, warnings,
    )
    optional = _optional_modules(bodies, chart_dt, latitude, longitude, is_day)
    optional["antiscia_contacts"] = antiscia_rows
    optional["declination_contacts"] = declination_rows
    optional["declination_moon_sequence"] = moon_decl_seq
    optional["fixed_stars"] = stars_packet
    optional["nodes"] = {
        "mode": node_mode,
        "bodies": node_bodies,
        "rule_id": "nodes.mean_default_true_optional.v1",
    }

    # Houses full
    house_rows_out = []
    for i in range(12):
        cusp = cusps[i]
        span = _house_span(cusps, i)
        sign = _sign_display(cusp)
        ruler = SIGN_RULERS[zodiac_sign_index(cusp)]
        house_rows_out.append({
            "house": i + 1,
            "cusp_longitude_deg": _r(cusp),
            "span_deg": _r(span, 6),
            "sign": sign,
            "domicile_ruler_id": ruler,
            "domicile_ruler_en": BODY_EN.get(ruler, ruler),
            "domicile_ruler_zh": planet_name(ruler),
        })

    angle_rows = []
    for angle_id in ("ASC", "MC", "DSC", "IC", "VERTEX", "ANTIVERTEX", "EQUATORIAL_ASCENDANT"):
        if angle_id not in angles:
            continue
        lon = angles[angle_id]
        angle_rows.append({
            "id": angle_id,
            "longitude_deg": _r(lon),
            "sign": _sign_display(lon),
        })
    # ARMC as separate computed value
    armc_row = {
        "id": "ARMC",
        "longitude_deg": _r(armc) if math.isfinite(armc) else None,
        "unit": "degree",
        "definition": "local_sidereal_time_deg = GST_hours*15 + geographic_longitude_east",
    }

    # Timezone / DST
    tzinfo = chart_dt.tzinfo
    utcoffset = chart_dt.utcoffset()
    offset_seconds = int(utcoffset.total_seconds()) if utcoffset is not None else 0
    dst = chart_dt.dst()
    dst_active = bool(dst and dst.total_seconds() != 0)
    tz_name = str(chart["moment"].get("timezone", ""))

    input_canonical = {
        "mode": "horary",
        "chart": chart,
        "placeName": place_name,
        "questionText": question_text,
        "aspectOrb": aspect_orb,
        "altitudeM": altitude_m,
        "eventPastDays": event_past_days,
        "eventFutureDays": event_future_days,
        "declinationOrb": decl_orb,
        "antisciaOrb": antiscia_orb,
        "nodeMode": node_mode,
        "bodyIds": body_ids,
        "packetVersion": "2",
    }
    calc_config = {
        "house_system": house_system,
        "house_system_label": house_label,
        "zodiac": zodiac,
        "zodiac_label": zodiac_mode_label(zodiac),
        "sidereal": sidereal,
        "bounds_system": bounds_system,
        "triplicity_system": triplicity_system,
        "aspect_orb_deg": aspect_orb,
        "aspects_enabled": [
            {"aspect_id": ASPECT_EN[n], "angle_deg": a} for n, a in sorted(CLASSICAL_ASPECTS.items(), key=lambda kv: kv[1])
        ],
        "bodies": body_ids,
        "coordinate_center": "geocentric",
        "position_type": "true_position",
        "event_window": {
            "past_days": event_past_days,
            "future_days": event_future_days,
        },
        "declination_orb_deg": decl_orb,
        "antiscia_orb_deg": antiscia_orb,
        "node_mode": node_mode,
        "solar_thresholds": {
            "cazimi_deg": CAZIMI_ORB_DEG,
            "combust_deg": COMBUST_ORB_DEG,
            "under_beams_deg": UNDER_BEAMS_ORB_DEG,
        },
        "longitude_sign_convention": "east_positive",
        "latitude_type": "geodetic",
        "numeric_precision": {
            "longitude_decimals": FLOAT_PREC,
            "angle_decimals": ANGLE_PREC,
        },
    }

    packet = {
        "schema": {
            "name": SCHEMA_NAME,
            "version": SCHEMA_VERSION,
            "schema_id": f"{SCHEMA_NAME}/{SCHEMA_VERSION}",
        },
        "question_metadata": {
            "question_text": question_text,
            "place_name": place_name,
            # question text is stored as user input only; no semantic analysis
        },
        "calculation_config": calc_config,
        "provenance": {
            "engine_name": ENGINE_NAME,
            "engine_version": ENGINE_VERSION,
            "algorithm_version": ALGORITHM_VERSION,
            "ephemeris_provider": "Swiss Ephemeris (pyswisseph)",
            "ephemeris_version": getattr(swe, "version", "unknown"),
            "input_hash_sha256": _hash_payload(input_canonical),
            "config_hash_sha256": _hash_payload(calc_config),
            "precession_nutation": "Swiss Ephemeris defaults for FLG_SWIEPH",
            "aberration_light_time": "Swiss Ephemeris defaults (included in SE positions)",
        },
        "time_and_location": {
            "local_datetime": format_local(chart_dt),
            "utc_datetime": chart_dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "utc_datetime_iso": chart_utc_iso,
            "timezone": tz_name,
            "utc_offset_seconds": offset_seconds,
            "dst_active": dst_active,
            "jd_ut": _r(chart_jd, 10),
            "jd_tt": _r(jd_tt, 10),
            "delta_t_seconds": _r(delta_t, 6) if math.isfinite(delta_t) else None,
            "sidereal_time_hours": _r(lst_hours, 8) if math.isfinite(lst_hours) else None,
            "armc_deg": _r(armc, 8) if math.isfinite(armc) else None,
            "obliquity_deg": _r(obliq, 8),
            "latitude_deg": _r(latitude, 8),
            "longitude_deg": _r(longitude, 8),
            "longitude_sign_convention": "east_positive",
            "latitude_type": "geodetic",
            "altitude_m": _r(altitude_m, 3),
            "geocoding": {
                "source": "user_provided",
                "precision": "as_provided",
            },
            "sect": {
                "is_day": is_day,
                "rule_id": "sect.sun_above_horizon_by_asc_dsc_arc.v1",
                "evidence": {
                    "sun_longitude_deg": _r(sun_lon),
                    "asc_longitude_deg": _r(angles["ASC"]),
                    "dsc_longitude_deg": _r(angles["DSC"]),
                },
            },
        },
        "houses": {
            "system": house_system,
            "system_label": house_label,
            "cusps": house_rows_out,
            "uses_ecliptic_longitude_for_body_houses": True,
            "fallback_applied": house_fallback,
            "fallback_reason": house_fallback_reason,
        },
        "angles": {
            "points": angle_rows,
            "armc": armc_row,
        },
        "bodies": bodies,
        "dignities": dignities,
        "pairwise_geometry": pairwise,
        "aspects": aspects,
        "aspect_candidates": aspect_candidates,
        "aspects_in_display_orb": aspects_in_display_orb,
        "display_orb_deg": aspect_orb,
        "receptions": receptions,
        "lots": lots,
        "events": events,
        "event_graph": graph,
        "moon": moon,
        "visibility": visibility,
        "planetary_day_hour": planetary,
        "considerations_evidence": considerations,
        "nodes": optional.get("nodes"),
        "optional_modules": optional,
        "validation": {
            "warnings": list(warnings),
            "house_fallback_applied": house_fallback,
            "schema_id": f"{SCHEMA_NAME}/{SCHEMA_VERSION}",
            "forbidden_field_scan": "passed",
            "body_count": len(bodies),
            "aspect_count": len(aspects),
            "aspect_candidate_count": len(aspect_candidates),
            "aspects_in_display_orb_count": len(aspects_in_display_orb),
            "event_count": len(events),
            "lot_count": len(lots),
        },
        "display": {
            "language_primary": "en_fields_zh_labels",
            "notes": "display.* fields are formatting only; numeric fields are authoritative",
        },
    }

    forbidden = assert_no_forbidden_fields(packet)
    if forbidden:
        packet["validation"]["forbidden_field_scan"] = "failed"
        packet["validation"]["forbidden_fields_found"] = forbidden
        warnings.append(f"v2 packet contains forbidden keys: {forbidden[:5]}")
    else:
        packet["validation"]["forbidden_field_scan"] = "passed"

    return packet


def sign_exit_days(body_id: str) -> int:
    from astro_backend_horary import SIGN_EXIT_SEARCH_DAYS_BY_BODY, DEFAULT_PERFECTION_SEARCH_DAYS
    return SIGN_EXIT_SEARCH_DAYS_BY_BODY.get(body_id, DEFAULT_PERFECTION_SEARCH_DAYS)


def format_horary_v2_markdown(packet: dict[str, Any]) -> str:
    """Lossless structural Markdown from v2 packet — no conclusions."""
    lines: list[str] = [
        f"# Horary Data Packet {packet['schema']['schema_id']}",
        "",
        "## Schema & Provenance",
        "",
        f"- schema: `{packet['schema']['schema_id']}`",
        f"- engine: {packet['provenance']['engine_name']} {packet['provenance']['engine_version']}",
        f"- algorithm: {packet['provenance']['algorithm_version']}",
        f"- ephemeris: {packet['provenance']['ephemeris_provider']} {packet['provenance']['ephemeris_version']}",
        f"- input_hash: `{packet['provenance']['input_hash_sha256']}`",
        f"- config_hash: `{packet['provenance']['config_hash_sha256']}`",
        "",
        "## Question Metadata",
        "",
        f"- question_text: {packet['question_metadata']['question_text'] or '(empty)'}",
        f"- place_name: {packet['question_metadata']['place_name'] or '(empty)'}",
        "",
        "## Time & Location",
        "",
    ]
    tl = packet["time_and_location"]
    lines += [
        f"- local: {tl['local_datetime']}",
        f"- utc: {tl['utc_datetime']}",
        f"- timezone: {tl['timezone']} (offset_seconds={tl['utc_offset_seconds']}, dst_active={tl['dst_active']})",
        f"- jd_ut: {tl['jd_ut']}",
        f"- jd_tt: {tl['jd_tt']}",
        f"- delta_t_seconds: {tl['delta_t_seconds']}",
        f"- sidereal_time_hours: {tl['sidereal_time_hours']}",
        f"- armc_deg: {tl['armc_deg']}",
        f"- obliquity_deg: {tl['obliquity_deg']}",
        f"- lat/lon: {tl['latitude_deg']}, {tl['longitude_deg']} (east_positive)",
        f"- altitude_m: {tl['altitude_m']}",
        f"- is_day: {tl['sect']['is_day']} (rule_id={tl['sect']['rule_id']})",
        "",
        "## Calculation Config",
        "",
    ]
    cc = packet["calculation_config"]
    lines += [
        f"- house_system: {cc['house_system']} ({cc['house_system_label']})",
        f"- zodiac: {cc['zodiac']} ({cc['zodiac_label']})",
        f"- bounds_system: {cc['bounds_system']}",
        f"- triplicity_system: {cc['triplicity_system']}",
        f"- aspect_orb_deg: {cc['aspect_orb_deg']}",
        f"- bodies: {', '.join(cc['bodies'])}",
        f"- event_window: past {cc['event_window']['past_days']}d / future {cc['event_window']['future_days']}d",
        "",
        "## Angles",
        "",
    ]
    for p in packet["angles"]["points"]:
        lines.append(f"- {p['id']}: {p['longitude_deg']} ({p['sign']['display_en']})")
    armc = packet["angles"]["armc"]
    lines += [f"- ARMC: {armc['longitude_deg']}", "", "## Houses", ""]
    for h in packet["houses"]["cusps"]:
        lines.append(
            f"- H{h['house']}: cusp {h['cusp_longitude_deg']} ({h['sign']['display_en']}), "
            f"span {h['span_deg']}°, ruler {h['domicile_ruler_id']}"
        )
    lines += ["", "## Bodies", ""]
    for b in packet["bodies"]:
        e = b["ecliptic"]
        acc = b.get("accidental") or {}
        lines.append(
            f"- {b['body_id']}: lon {e['longitude_deg']} lat {e['latitude_deg']} "
            f"speed {e['longitude_speed_deg_per_day']}°/d | {b['sign']['display_en']} | "
            f"H{b['house']['integer_house']} (cont {b['house']['continuous_house']}) | "
            f"motion {b['motion']['state']} | house_class={acc.get('house_class')} "
            f"sign_mode={acc.get('sign_mode')} dist_angles={b.get('distance_to_angles_deg')} "
            f"events_index={b.get('events_index')} precision={b.get('precision')}"
        )
    lines += ["", "## Dignities", ""]
    for d in packet["dignities"]:
        lines.append(
            f"- {d['body_id']}: domicile={d['domicile_ruler_id']} exalt={d['exaltation_ruler_id']} "
            f"bound={d['bounds']['ruler_id']} decan={d['decan']['ruler_id']} "
            f"trip_active={d['triplicity']['active_ruler_id']} peregrine={d['is_peregrine']}"
        )
    lines += ["", "## Pairwise Geometry", ""]
    for p in packet["pairwise_geometry"]:
        na = p.get("nearest_aspect") or {}
        lines.append(
            f"- {p['id']}: min_sep {p['minimum_separation_deg']}° rel_speed {p['relative_speed_deg_per_day']} "
            f"nearest {na.get('aspect_id')} Δ{na.get('delta_to_aspect_deg')} within_orb={na.get('within_orb')}"
        )
    lines += ["", "## Aspect Candidates (full)", ""]
    cands = packet.get("aspect_candidates") or packet.get("aspects") or []
    if not cands:
        lines.append("- none")
    for a in cands:
        ne = a.get("next_exact") or {}
        lines.append(
            f"- {a['id']}: orb {a['orb_deg']}° {a['application']} next_exact={ne.get('datetime_utc')} "
            f"root={ne.get('root_status')} refranation={a.get('refranation_detected')} "
            f"within_display_orb={a.get('within_display_orb')}"
        )
    lines += ["", "## Aspects within display orb", ""]
    in_orb = packet.get("aspects_in_display_orb") or []
    if not in_orb:
        lines.append("- none")
    for a in in_orb:
        ne = a.get("next_exact") or {}
        lines.append(
            f"- {a['id']}: orb {a['orb_deg']}° {a['application']} next_exact={ne.get('datetime_utc')} "
            f"root={ne.get('root_status')} refranation={a.get('refranation_detected')}"
        )
    lines += ["", "## Receptions (full evidence)", ""]
    for r in packet["receptions"]:
        lines.append(f"- {json.dumps(r, ensure_ascii=False, sort_keys=True)}")
    lines += ["", "## Lots (full evidence)", ""]
    for lot in packet["lots"]:
        lines.append(f"- {json.dumps(lot, ensure_ascii=False, sort_keys=True)}")
    lines += ["", "## Events", ""]
    for ev in packet["events"]:
        lines.append(
            f"- {ev['datetime_utc']} | {ev['event_type']} | bodies={','.join(ev['body_ids'])} "
            f"| offset_s={ev['offset_seconds_from_query']} | {ev['id']}"
        )
    lines += ["", "## Moon Index", ""]
    m = packet["moon"]
    lines += [
        f"- phase_angle_deg: {m['phase_angle_deg']}",
        f"- illumination_fraction: {m['illumination_fraction']}",
        f"- age_days_approx: {m['age_days_approx']}",
        f"- sign_exit: {m['sign_exit']}",
        f"- last_exact: {m['last_exact_aspect_in_current_sign']}",
        f"- next_exact: {m['next_exact_aspect_in_current_sign']}",
    ]
    for rule in m["void_of_course_rules"]:
        lines.append(f"- VOC {rule['rule_id']}: value={rule['value']} evidence={rule['evidence']}")
    lines += ["", "## Visibility / Solar Condition / Pheno", ""]
    for v in packet["visibility"]:
        lines.append(
            f"- {v['body_id']}: ecliptic_sep {v['ecliptic_separation_from_sun_deg']} "
            f"sphere_sep {v['spherical_separation_from_sun_deg']} "
            f"phase_angle={v.get('phase_angle_deg')} illum={v.get('illumination_fraction')} "
            f"mag={v.get('apparent_magnitude')} elong={v.get('solar_elongation_deg')} "
            f"alt_body={v.get('body_altitude_deg')} alt_sun={v.get('sun_altitude_deg')} "
            f"morning_evening={v['morning_evening']} visible={v['visible']} "
            f"({v.get('visible_reason_code')}) model={v.get('visibility_model_id')} "
            f"atmosphere={v.get('atmosphere')}"
        )
    lines += ["", "## Nodes", ""]
    nodes = packet.get("nodes") or {}
    lines.append(f"- mode: {nodes.get('mode')}")
    for nb in nodes.get("bodies") or []:
        lines.append(
            f"- {nb.get('body_id')}: lon {nb.get('ecliptic', {}).get('longitude_deg')} "
            f"role={nb.get('node_role')} derivation={nb.get('south_derivation')} "
            f"H{nb.get('house', {}).get('integer_house')}"
        )
    lines += ["", "## Event Graph", ""]
    eg = packet.get("event_graph") or {}
    for pb in eg.get("per_body") or []:
        lines.append(
            f"- {pb.get('body_id')}: prev={pb.get('previous_event_id')} next={pb.get('next_event_id')} "
            f"seq_len={len(pb.get('ordered_event_ids') or [])}"
        )
    for cs in (eg.get("aspect_candidate_sequences") or [])[:40]:
        lines.append(
            f"- candidate {cs.get('candidate_id')}: faster={cs.get('faster_body_id')} "
            f"exact={cs.get('next_exact_utc')} third_party={cs.get('third_party_aspect_event_ids_before_exact')} "
            f"house_changes={cs.get('house_change_event_ids_before_exact')} "
            f"station_before={cs.get('station_or_retrograde_before_exact')} "
            f"snap_query={cs.get('positions_at_query')}"
        )
    if len(eg.get("aspect_candidate_sequences") or []) > 40:
        lines.append(f"- … {len(eg['aspect_candidate_sequences']) - 40} more candidate sequences")
    lines += ["", "## Planetary Day / Hour", ""]
    pdh = packet.get("planetary_day_hour") or {}
    lines.append(f"- status={pdh.get('status')} rule_id={pdh.get('rule_id')}")
    lines.append(f"- sunrise_utc={pdh.get('sunrise_utc')} sunset_utc={pdh.get('sunset_utc')}")
    cur = pdh.get("current_hour") or pdh.get("current")
    lines.append(f"- current_hour={cur}")
    for h in (pdh.get("hours") or [])[:8]:
        lines.append(
            f"- hour {h.get('period')}#{h.get('hour_index')} ruler={h.get('ruler_id')} "
            f"{h.get('start_utc')}→{h.get('end_utc')}"
        )
    lines += ["", "## Considerations Evidence", ""]
    for c in packet.get("considerations_evidence") or []:
        lines.append(f"- {c.get('id')}: type={c.get('fact_type')} payload={ {k:v for k,v in c.items() if k not in {'id','fact_type'}} }")
    lines += ["", "## Declination Contacts", ""]
    opt = packet["optional_modules"]
    for d in (opt.get("declination_contacts") or [])[:40]:
        lines.append(
            f"- {d.get('id')}: Δ{d.get('delta_deg')} app={d.get('application')} "
            f"within={d.get('within_orb')} next={ (d.get('next_exact') or {}).get('datetime_utc') }"
        )
    lines += ["", "## Antiscia Contacts (sample)", ""]
    ac = opt.get("antiscia_contacts") or []
    hits = [x for x in ac if x.get("within_orb")]
    lines.append(f"- total={len(ac)} within_orb={len(hits)}")
    for x in hits[:30]:
        lines.append(f"- {x.get('id')}: dist={x.get('distance_deg')}")
    lines += ["", "## Fixed Stars", ""]
    fs = opt.get("fixed_stars") or {}
    lines.append(f"- catalog={fs.get('catalog_version')} stars={len(fs.get('stars') or [])} contacts={len(fs.get('contacts') or [])}")
    for c in (fs.get("contacts") or [])[:30]:
        lines.append(f"- {c.get('id')}: dist={c.get('distance_deg')} mag={c.get('magnitude')}")
    lines += ["", "## Optional Modules (legacy positions)", ""]
    lines.append(f"- antiscia position rows: {len(opt.get('antiscia') or [])}")
    lines.append(f"- via_combusta rows: {len(opt.get('via_combusta') or [])}")
    lines.append(f"- dodecatemoria rows: {len(opt.get('dodecatemoria') or [])}")
    lines += ["", "## Validation", ""]
    val = packet["validation"]
    for k, v in val.items():
        if k == "warnings":
            continue
        lines.append(f"- {k}: {v}")
    if val.get("warnings"):
        lines += ["", "### Technical Warnings", ""]
        for w in val["warnings"]:
            lines.append(f"- {w}")
    lines.append("")
    return "\n".join(lines)
