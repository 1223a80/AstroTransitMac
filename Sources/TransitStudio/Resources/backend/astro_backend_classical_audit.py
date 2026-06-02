from __future__ import annotations

from datetime import datetime, timedelta, timezone as tz
from typing import Any

from astro_backend_classical_dignity import dignity_labels, dignity_rulers_for_lon
from astro_backend_core import (
    BODY_REGISTRY,
    SIGNS,
    SIGN_RULERS,
    angular_separation,
    norm360,
    planet_name,
    zodiac_sign_index,
)
from astro_backend_ephemeris import calculate_values, house_for_longitude


def calculate_prenatal_syzygy(
    birth_jd: float,
    birth_dt: datetime,
    warnings: list[str],
    sidereal: bool = False,
) -> dict[str, Any]:
    import math

    sun_spec = BODY_REGISTRY["SUN"]
    moon_spec = BODY_REGISTRY["MOON"]
    warning_keys: set[str] = set()
    ephemerides: set[str] = set()

    def _lon(jd: float, spec: Any) -> float:
        calculated = calculate_values(jd, spec, warnings, warning_keys, sidereal)
        if calculated is None:
            raise RuntimeError(f"无法计算 {spec.name} 的 Swiss Ephemeris 位置")
        val, ephemeris_name = calculated
        ephemerides.add(ephemeris_name)
        return norm360(val[0])

    def _elongation(jd: float) -> tuple[float, float, float]:
        sun_lon = _lon(jd, sun_spec)
        moon_lon = _lon(jd, moon_spec)
        return norm360(moon_lon - sun_lon), sun_lon, moon_lon

    birth_elong, _birth_sun_lon, _birth_moon_lon = _elongation(birth_jd)

    def _signed_phase_error(jd: float, target_sep: float) -> float:
        elong, _, _ = _elongation(jd)
        return ((elong - target_sep + 180.0) % 360.0) - 180.0

    def _minimize_phase_error(approx_jd: float, target_sep: float) -> float:
        phi = (1.0 + math.sqrt(5.0)) / 2.0
        lo = approx_jd - 1.0
        hi = approx_jd + 1.0

        def _abs_error(jd: float) -> float:
            return abs(_signed_phase_error(jd, target_sep))

        for _ in range(50):
            mid1 = hi - (hi - lo) / phi
            mid2 = lo + (hi - lo) / phi
            if _abs_error(mid1) < _abs_error(mid2):
                hi = mid2
            else:
                lo = mid1
        return (lo + hi) / 2.0

    def _refine_syzygy(approx_jd: float, target_sep: float) -> float:
        lo = approx_jd - 1.0
        hi = approx_jd + 1.0
        step = 1.0 / 12.0
        prev_jd = lo
        prev_err = _signed_phase_error(prev_jd, target_sep)
        bracket: tuple[float, float, float, float] | None = None

        current_jd = lo + step
        while current_jd <= hi + 1e-9:
            curr_jd = min(current_jd, hi)
            curr_err = _signed_phase_error(curr_jd, target_sep)
            if abs(prev_err) < 1e-8:
                return prev_jd
            if abs(curr_err) < 1e-8:
                return curr_jd
            if prev_err * curr_err < 0 and max(abs(prev_err), abs(curr_err)) < 45.0:
                bracket = (prev_jd, curr_jd, prev_err, curr_err)
                break
            prev_jd = curr_jd
            prev_err = curr_err
            current_jd += step

        if bracket is None:
            warnings.append("Prenatal Syzygy 未能建立相位过零区间，改用最小误差校验。")
            return _minimize_phase_error(approx_jd, target_sep)

        left, right, left_err, _ = bracket
        for _ in range(60):
            mid = (left + right) / 2.0
            mid_err = _signed_phase_error(mid, target_sep)
            if abs(mid_err) < 1e-8 or (right - left) * 86400.0 < 0.5:
                return mid
            if left_err * mid_err <= 0:
                right = mid
            else:
                left = mid
                left_err = mid_err
        return (left + right) / 2.0

    relative_rate = 13.176 - 0.986
    candidates: list[tuple[float, str, float]] = []
    for candidate_type, target_sep in (("new_moon", 0.0), ("full_moon", 180.0)):
        days_since = ((birth_elong - target_sep) % 360.0) / relative_rate
        approx_jd = birth_jd - days_since
        exact_jd = _refine_syzygy(approx_jd, target_sep)
        if exact_jd <= birth_jd + 1e-8:
            candidates.append((exact_jd, candidate_type, target_sep))

    if not candidates:
        raise RuntimeError("未能找到出生前的朔望")

    syzygy_jd, syzygy_type, _target_sep = max(candidates, key=lambda item: item[0])
    _syzygy_elong, syzygy_sun_lon, syzygy_moon_lon = _elongation(syzygy_jd)

    if syzygy_type == "new_moon":
        syzygy_degree_used = syzygy_sun_lon
        syzygy_degree_note = "Sun degree (sun_position; Moon conjunct)"
    else:
        syzygy_degree_used = syzygy_sun_lon
        syzygy_degree_note = "Sun degree (sun_position; full moon axis, Moon opposite)"

    sign_idx = zodiac_sign_index(syzygy_degree_used)
    degree = syzygy_degree_used - sign_idx * 30.0

    syzygy_dt_utc = datetime(2000, 1, 1, 12, tzinfo=tz.utc) + timedelta(days=syzygy_jd - 2451545.0)
    syzygy_dt_utc_rounded = syzygy_dt_utc + timedelta(seconds=30)
    ruler_id = SIGN_RULERS[sign_idx]
    dignities = dignity_rulers_for_lon(syzygy_degree_used, True, "egyptian", "dorothean")

    return {
        "syzygy_type": syzygy_type,
        "exact_utc": syzygy_dt_utc_rounded.strftime("%Y-%m-%d %H:%M"),
        "longitude": round(syzygy_degree_used, 4),
        "sun_position": round(syzygy_sun_lon, 4),
        "moon_position": round(syzygy_moon_lon, 4),
        "sign": SIGNS[sign_idx],
        "degree": round(degree, 2),
        "ruler": planet_name(ruler_id),
        "ruler_id": ruler_id,
        "dignity_rulers": dignities,
        "syzygy_degree_used": syzygy_degree_note,
        "method_variant": "prenatal_syzygy_nearest_before_birth",
        "ephemeris": ", ".join(sorted(ephemerides)) if ephemerides else "unknown",
        "_method": "prenatal_syzygy_swiss_ephemeris_bracketed_bisection",
        "_source_tradition": "Hellenistic",
    }


def calculate_almuten_figuris(
    angles: dict[str, float],
    planet_positions: dict[str, dict[str, Any]],
    lot_fortune_lon: float,
    syzygy: dict[str, Any],
    is_day: bool,
    bounds_system: str,
    triplicity_system: str,
) -> dict[str, Any]:
    points = [
        ("Sun", planet_positions["SUN"]["longitude"]),
        ("Moon", planet_positions["MOON"]["longitude"]),
        ("ASC", angles["ASC"]),
        ("Fortune", lot_fortune_lon),
        ("Syzygy", syzygy["longitude"]),
    ]

    score_table: dict[str, dict[str, Any]] = {}
    for pid in ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]:
        score_table[pid] = {"planet": planet_name(pid), "total": 0, "contributions": []}

    for point_name, lon in points:
        rulers = dignity_rulers_for_lon(lon, is_day, bounds_system, triplicity_system)
        weights = {"domicile": 5, "exaltation": 4, "triplicity": 3, "bound": 2, "decan": 1}
        for dignity_key, ruler_id in rulers.items():
            if ruler_id in score_table:
                weight = weights.get(dignity_key, 0)
                score_table[ruler_id]["total"] += weight
                score_table[ruler_id]["contributions"].append({
                    "point": point_name,
                    "dignity": dignity_key,
                    "weight": weight,
                })

    ranked = sorted(score_table.values(), key=lambda value: -value["total"])
    winner = ranked[0] if ranked else None
    syzygy_valid = syzygy and syzygy.get("longitude", 0) > 0 and syzygy.get("method_variant") == "prenatal_syzygy_nearest_before_birth"
    confidence_level = "high" if syzygy_valid else "low"

    return {
        "winner": winner["planet"] if winner else "",
        "winner_id": next((pid for pid in ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"] if planet_name(pid) == (winner or {}).get("planet", "")), ""),
        "score_table": ranked,
        "points_used": [point[0] for point in points],
        "method": "traditional_5_point",
        "method_variant": "almuten_figuris_5_point_essential_dignity",
        "confidence": confidence_level,
        "_source_tradition": "Hellenistic",
    }


def calculate_hyleg_alcocoden(
    birth_jd: float,
    angles: dict[str, float],
    planet_positions: dict[str, dict[str, Any]],
    lot_fortune_lon: float,
    lot_spirit_lon: float,
    cusps: list[float],
    is_day: bool,
    bounds_system: str,
    triplicity_system: str,
    warnings: list[str],
    sidereal: bool = False,
) -> dict[str, Any]:
    _ = birth_jd, warnings, sidereal
    hylegical_places = {1, 10, 11, 7, 9}

    def _house_for(lon: float) -> int:
        return house_for_longitude(lon, cusps)

    sun_lon = planet_positions["SUN"]["longitude"]
    moon_lon = planet_positions["MOON"]["longitude"]
    asc_lon = angles["ASC"]

    all_candidates: list[dict[str, Any]] = []
    potential_hyleg_points = [
        {"name": "Sun", "id": "SUN", "lon": sun_lon},
        {"name": "Moon", "id": "MOON", "lon": moon_lon},
        {"name": "ASC", "id": "ASC", "lon": asc_lon},
        {"name": "Fortune", "id": "fortune", "lon": lot_fortune_lon},
        {"name": "Spirit", "id": "spirit", "lon": lot_spirit_lon},
    ]

    for point in potential_hyleg_points:
        house = _house_for(point["lon"])
        in_place = house in hylegical_places
        place_pass = "angular" if house in {1, 10, 7, 9} else ("succedent_cadent" if house in {11, 5, 2, 8} else "cadent")

        eligible = False
        reject_reason: str | None = None
        select_reason: str | None = None
        if point["id"] == "SUN":
            if is_day and in_place:
                eligible = True
                select_reason = f"昼盘太阳在 Hyleg 候选宫位（第 {house} 宫）"
            elif is_day:
                reject_reason = "昼盘太阳不在 hylegical places (1,10,11,7,9)"
            else:
                reject_reason = "夜盘不优先选太阳做 Hyleg"
        elif point["id"] == "MOON":
            if (not is_day) and in_place:
                eligible = True
                select_reason = f"夜盘月亮在 Hyleg 候选宫位（第 {house} 宫）"
            elif not is_day:
                reject_reason = "夜盘月亮不在 hylegical places"
            else:
                reject_reason = "昼盘不优先选月亮做 Hyleg"
        elif point["id"] in {"ASC", "fortune", "spirit"}:
            if in_place:
                eligible = True
                select_reason = f"{point['name']} 在 Hyleg 候选宫位（第 {house} 宫）"
            else:
                reject_reason = f"{point['name']} 不在 hylegical places"

        sect_relevance = "preferred" if ((point["id"] == "SUN" and is_day) or (point["id"] == "MOON" and not is_day)) else "secondary"
        visibility = "above_horizon" if house >= 7 else "below_horizon"

        all_candidates.append({
            "name": point["name"],
            "id": point["id"],
            "lon": point["lon"],
            "eligible": eligible,
            "reason": select_reason if eligible else (reject_reason or ""),
            "house": house,
            "hylegical_place_pass": place_pass,
            "sect_relevance": sect_relevance,
            "visibility": visibility,
            "final_rank": 1 if eligible else 99,
        })

    selected_hyleg = next((candidate for candidate in all_candidates if candidate["eligible"]), None)

    alcocoden_candidates: list[dict[str, Any]] = []
    if selected_hyleg:
        hyleg_lon = selected_hyleg["lon"]
        rulers = dignity_rulers_for_lon(hyleg_lon, is_day, bounds_system, triplicity_system)
        weights = {"domicile": 5, "exaltation": 4, "triplicity": 3, "bound": 2, "decan": 1}
        dignity_by_planet: dict[str, list[tuple[str, int]]] = {pid: [] for pid in ["SATURN", "MERCURY", "MARS", "JUPITER", "VENUS"]}
        for dignity_key, ruler_id in rulers.items():
            if ruler_id in dignity_by_planet:
                dignity_by_planet[ruler_id].append((dignity_key, weights.get(dignity_key, 0)))

        for ruler_id in ["SATURN", "MERCURY", "MARS", "JUPITER", "VENUS"]:
            if ruler_id in planet_positions:
                ruler_pos = planet_positions[ruler_id]
                ruler_lon = ruler_pos["longitude"]
                aspect_to = angular_separation(ruler_lon, hyleg_lon)
                sees = aspect_to < 120 or abs(aspect_to - 180) < 10
                own_condition = dignity_labels(ruler_id, ruler_lon, is_day, bounds_system, triplicity_system)
                _, _, _, _, _, own_score, _, _, _, _ = own_condition
                dignity_hits = dignity_by_planet.get(ruler_id, [])
                dignity_label = "+".join(item[0] for item in dignity_hits) if dignity_hits else "none"
                total_weight = sum(item[1] for item in dignity_hits)
                alcocoden_candidates.append({
                    "planet": planet_name(ruler_id),
                    "planet_id": ruler_id,
                    "dignity_at_hyleg": dignity_label,
                    "weight": total_weight,
                    "sees_hyleg": sees,
                    "aspect_to_hyleg": round(aspect_to, 2),
                    "own_condition_score": own_score,
                    "own_condition_summary": _dignity_summary_short(ruler_id, ruler_lon, is_day, bounds_system, triplicity_system),
                    "rank": 0,
                    "reason": f"{dignity_label} ruler of hyleg position{'（seeing hyleg）' if sees else '（not seeing hyleg）'}",
                })

        alcocoden_candidates.sort(key=lambda candidate: (-candidate["weight"], -candidate["own_condition_score"] if candidate["sees_hyleg"] else -99))
        for index, candidate in enumerate(alcocoden_candidates):
            candidate["rank"] = index + 1
        selectable_alcocoden = next((candidate for candidate in alcocoden_candidates if candidate["weight"] > 0), None)
    else:
        selectable_alcocoden = None

    return {
        "hyleg": {
            "selected": selected_hyleg["name"] if selected_hyleg else "",
            "selected_id": selected_hyleg["id"] if selected_hyleg else "",
            "longitude": round(selected_hyleg["lon"], 4) if selected_hyleg else 0,
            "reason": selected_hyleg.get("reason", "") if selected_hyleg else "No eligible Hyleg candidate",
            "candidates": all_candidates,
        },
        "alcocoden": {
            "selected": selectable_alcocoden["planet"] if selectable_alcocoden else "",
            "selected_id": selectable_alcocoden["planet_id"] if selectable_alcocoden else "",
            "dignity": selectable_alcocoden["dignity_at_hyleg"] if selectable_alcocoden else "",
            "candidates": alcocoden_candidates,
        },
        "method": "medieval_arabic_basic",
        "method_variant": "hyleg_alcocoden_hylegical_places_5_candidates",
        "_source_tradition": "Arabic/Medieval",
    }


def _dignity_summary_short(body_id: str, lon: float, is_day: bool, bounds_system: str, triplicity_system: str) -> str:
    parts: list[str] = []
    domicile, exaltation, triplicity, _bound, _decan, _score, _notes, _breakdown, detriment, fall = dignity_labels(
        body_id, lon, is_day, bounds_system, triplicity_system
    )
    if domicile:
        parts.append(domicile)
    if exaltation:
        parts.append(exaltation)
    if detriment:
        parts.append(detriment)
    if fall:
        parts.append(fall)
    if triplicity:
        parts.append(f"三分{triplicity}")
    if not parts:
        parts.append("peregrine")
    return "、".join(parts)
