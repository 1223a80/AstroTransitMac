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
        selected_luminary = "SUN"
        degree_selection_profile = "new_moon_sun_degree_v1"
        syzygy_degree_note = "Sun degree (sun_position; Moon conjunct)"
        syzygy_axis = None
    else:
        # Full moon is an axis: Sun and Moon opposite. Default profile uses Sun degree.
        syzygy_degree_used = syzygy_sun_lon
        selected_luminary = "SUN"
        degree_selection_profile = "full_moon_sun_degree_profile_v1"
        syzygy_degree_note = (
            "Sun degree (sun_position; full moon axis, Moon opposite). "
            "Full-moon axis: sun_longitude and moon_longitude both reported; "
            "selected_degree uses Sun by profile (not the Moon opposite degree alone)."
        )
        syzygy_axis = {
            "sun_longitude": round(syzygy_sun_lon, 6),
            "moon_longitude": round(syzygy_moon_lon, 6),
            "axis_span_deg": round(abs(((syzygy_moon_lon - syzygy_sun_lon + 180) % 360) - 180), 4),
        }

    sign_idx = zodiac_sign_index(syzygy_degree_used)
    degree = syzygy_degree_used - sign_idx * 30.0

    syzygy_dt_utc = datetime(2000, 1, 1, 12, tzinfo=tz.utc) + timedelta(days=syzygy_jd - 2451545.0)
    syzygy_dt_utc_rounded = syzygy_dt_utc + timedelta(seconds=30)
    ruler_id = SIGN_RULERS[sign_idx]
    dignities = dignity_rulers_for_lon(syzygy_degree_used, True, "egyptian", "dorothean")

    return {
        "syzygy_type": syzygy_type,
        "exact_utc": syzygy_dt_utc_rounded.strftime("%Y-%m-%d %H:%M"),
        "exact_jd": float(syzygy_jd),
        "jd": float(syzygy_jd),
        "longitude": round(syzygy_degree_used, 4),
        "sun_longitude": round(syzygy_sun_lon, 4),
        "moon_longitude": round(syzygy_moon_lon, 4),
        "sun_position": round(syzygy_sun_lon, 4),
        "moon_position": round(syzygy_moon_lon, 4),
        "syzygy_axis": syzygy_axis,
        "degree_selection_profile": degree_selection_profile,
        "selected_degree": round(syzygy_degree_used, 4),
        "selected_luminary": selected_luminary,
        "sign": SIGNS[sign_idx],
        "degree": round(degree, 2),
        "ruler": planet_name(ruler_id),
        "ruler_id": ruler_id,
        "ruler_basis": "domicile_ruler_of_selected_degree_sign",
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
    planetary_day_ruler: str | None = None,
    planetary_hour_ruler: str | None = None,
    include_day_hour_bonus: bool = False,
    include_accidental: bool = False,
) -> dict[str, Any]:
    """Almuten Figuris under an explicit scoring profile.

    Default profile scores only essential dignities of five chart points.
    Day/hour/accidental bonuses are optional and must be requested explicitly.
    Title meaning: strongest under the current profile — not absolute chart ruler.
    """
    almuten_profile = (
        "almuten_figuris_5_point_essential_v1"
        if not include_day_hour_bonus and not include_accidental
        else "almuten_figuris_5_point_extended_v1"
    )
    points = [
        ("Sun", planet_positions["SUN"]["longitude"]),
        ("Moon", planet_positions["MOON"]["longitude"]),
        ("ASC", angles["ASC"]),
        ("Fortune", lot_fortune_lon),
        ("Syzygy", syzygy["longitude"]),
    ]
    included_dignities = ["domicile", "exaltation", "triplicity", "bound", "decan"]
    weights = {"domicile": 5, "exaltation": 4, "triplicity": 3, "bound": 2, "decan": 1}

    score_table: dict[str, dict[str, Any]] = {}
    for pid in ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]:
        score_table[pid] = {
            "planet": planet_name(pid),
            "planet_id": pid,
            "total": 0,
            "contributions": [],
        }

    for point_name, lon in points:
        rulers = dignity_rulers_for_lon(lon, is_day, bounds_system, triplicity_system)
        for dignity_key, ruler_id in rulers.items():
            if ruler_id in score_table and dignity_key in weights:
                weight = weights[dignity_key]
                score_table[ruler_id]["total"] += weight
                score_table[ruler_id]["contributions"].append({
                    "point": point_name,
                    "dignity": dignity_key,
                    "weight": weight,
                    "owned_by": ruler_id,
                    "source": f"{point_name}.{dignity_key}",
                })

    day_ruler_bonus = 0
    hour_ruler_bonus = 0
    accidental_dignity_bonus = 0
    if include_day_hour_bonus:
        day_ruler_bonus = 7
        hour_ruler_bonus = 6
        if planetary_day_ruler and planetary_day_ruler in score_table:
            score_table[planetary_day_ruler]["total"] += day_ruler_bonus
            score_table[planetary_day_ruler]["contributions"].append({
                "point": "planetary_day",
                "dignity": "day_ruler",
                "weight": day_ruler_bonus,
                "owned_by": planetary_day_ruler,
                "source": "planetary_day_ruler",
            })
        if planetary_hour_ruler and planetary_hour_ruler in score_table:
            score_table[planetary_hour_ruler]["total"] += hour_ruler_bonus
            score_table[planetary_hour_ruler]["contributions"].append({
                "point": "planetary_hour",
                "dignity": "hour_ruler",
                "weight": hour_ruler_bonus,
                "owned_by": planetary_hour_ruler,
                "source": "planetary_hour_ruler",
            })
    if include_accidental:
        accidental_dignity_bonus = 0  # reserved; not auto-applied without house strengths

    ranked = sorted(score_table.values(), key=lambda value: -value["total"])
    winner = ranked[0] if ranked else None
    syzygy_valid = (
        syzygy
        and syzygy.get("longitude", 0) > 0
        and syzygy.get("method_variant") == "prenatal_syzygy_nearest_before_birth"
    )
    confidence_level = "high" if syzygy_valid else "low"

    return {
        "winner": winner["planet"] if winner else "",
        "winner_id": winner.get("planet_id", "") if winner else "",
        "title": "当前profile下的Almuten Figuris",
        "score_table": ranked,
        "points_used": [point[0] for point in points],
        "included_points": [point[0] for point in points],
        "included_dignities": included_dignities,
        "day_ruler_bonus": day_ruler_bonus if include_day_hour_bonus else 0,
        "hour_ruler_bonus": hour_ruler_bonus if include_day_hour_bonus else 0,
        "accidental_dignity_bonus": accidental_dignity_bonus,
        "planetary_day_ruler": planetary_day_ruler,
        "planetary_hour_ruler": planetary_hour_ruler,
        "method": "traditional_5_point",
        "method_variant": almuten_profile,
        "almuten_profile": almuten_profile,
        "confidence": confidence_level,
        "_source_tradition": "Hellenistic",
        "note": "Winner is strongest under the stated profile only; not an absolute chart governor.",
    }


# Ptolemaic major aspects used for "witnesses hyleg" under the default proxy profile.
_HYLEG_WITNESS_ASPECTS = {
    "conjunction": (0.0, 8.0),
    "sextile": (60.0, 5.0),
    "square": (90.0, 6.0),
    "trine": (120.0, 6.0),
    "opposition": (180.0, 8.0),
}


def _witness_aspect(a_lon: float, b_lon: float) -> tuple[bool, str | None, float | None]:
    """Return (sees, aspect_name, orb) for classical major aspects."""
    sep = angular_separation(a_lon, b_lon)
    best: tuple[str, float] | None = None
    for name, (angle, orb_max) in _HYLEG_WITNESS_ASPECTS.items():
        orb = abs(sep - angle)
        if orb <= orb_max and (best is None or orb < best[1]):
            best = (name, orb)
    if best is None:
        return False, None, None
    return True, best[0], round(best[1], 4)


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
    """Hyleg/Alcocoden audit-only module.

    Profile: hyleg_hylegical_places_proxy_v1 — simplified place filter, NOT full traditional judgment.
    Exactly one selected Hyleg. eligible ≠ selected.
    Alcocoden requires witness of Hyleg under this profile; longevity years are never output.
    """
    _ = birth_jd, sidereal
    hyleg_profile = "hyleg_hylegical_places_proxy_v1"
    alcocoden_profile = "alcocoden_dignity_witness_proxy_v1"
    hylegical_places = {1, 10, 11, 7, 9}
    # Selection order (first eligible becomes selected).
    selection_order = ["SUN", "MOON", "ASC", "fortune", "spirit"]

    def _house_for(lon: float) -> int:
        return house_for_longitude(lon, cusps)

    sun_lon = planet_positions["SUN"]["longitude"]
    moon_lon = planet_positions["MOON"]["longitude"]
    asc_lon = angles["ASC"]

    potential_hyleg_points = [
        {"name": "Sun", "id": "SUN", "lon": sun_lon},
        {"name": "Moon", "id": "MOON", "lon": moon_lon},
        {"name": "ASC", "id": "ASC", "lon": asc_lon},
        {"name": "Fortune", "id": "fortune", "lon": lot_fortune_lon},
        {"name": "Spirit", "id": "spirit", "lon": lot_spirit_lon},
    ]

    all_candidates: list[dict[str, Any]] = []
    for point in potential_hyleg_points:
        house = _house_for(point["lon"])
        in_place = house in hylegical_places
        place_pass = "angular" if house in {1, 10, 7, 9} else ("succedent" if house in {11, 5, 2, 8} else "cadent")

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
        order_rank = selection_order.index(point["id"]) if point["id"] in selection_order else 99

        all_candidates.append({
            "name": point["name"],
            "id": point["id"],
            "lon": point["lon"],
            "eligible": eligible,
            "selected": False,
            "reason": select_reason if eligible else (reject_reason or ""),
            "house": house,
            "hylegical_place_pass": place_pass,
            "sect_relevance": sect_relevance,
            "visibility": visibility,
            "selection_order": order_rank,
            "final_rank": order_rank if eligible else 99,
            "reject_reason": reject_reason,
        })

    # Exactly one selected: first eligible in selection order.
    eligible_sorted = sorted(
        [c for c in all_candidates if c["eligible"]],
        key=lambda c: c["selection_order"],
    )
    selected_hyleg = eligible_sorted[0] if eligible_sorted else None
    if selected_hyleg:
        selected_hyleg["selected"] = True
        for c in all_candidates:
            if c["id"] != selected_hyleg["id"] and c["eligible"]:
                c["reason"] = (c.get("reason") or "") + "（eligible 但未选中；仅一个 selected Hyleg）"

    alcocoden_candidates: list[dict[str, Any]] = []
    selectable_alcocoden: dict[str, Any] | None = None
    if selected_hyleg:
        hyleg_lon = selected_hyleg["lon"]
        rulers = dignity_rulers_for_lon(hyleg_lon, is_day, bounds_system, triplicity_system)
        weights = {"domicile": 5, "exaltation": 4, "triplicity": 3, "bound": 2, "decan": 1}
        dignity_by_planet: dict[str, list[tuple[str, int]]] = {
            pid: [] for pid in ["SATURN", "MERCURY", "MARS", "JUPITER", "VENUS"]
        }
        for dignity_key, ruler_id in rulers.items():
            if ruler_id in dignity_by_planet:
                dignity_by_planet[ruler_id].append((dignity_key, weights.get(dignity_key, 0)))

        for ruler_id in ["SATURN", "MERCURY", "MARS", "JUPITER", "VENUS"]:
            if ruler_id not in planet_positions:
                continue
            ruler_pos = planet_positions[ruler_id]
            ruler_lon = ruler_pos["longitude"]
            sees, witness_aspect, witness_orb = _witness_aspect(ruler_lon, hyleg_lon)
            own_condition = dignity_labels(ruler_id, ruler_lon, is_day, bounds_system, triplicity_system)
            _, _, _, _, _, own_score, _, _, _, _ = own_condition
            dignity_hits = dignity_by_planet.get(ruler_id, [])
            dignity_label = "+".join(item[0] for item in dignity_hits) if dignity_hits else "none"
            total_weight = sum(item[1] for item in dignity_hits)

            rejection_reason = None
            eligible_under_profile = True
            if total_weight <= 0:
                eligible_under_profile = False
                rejection_reason = "no dignity over hyleg position"
            elif not sees:
                eligible_under_profile = False
                rejection_reason = "does_not_see_hyleg"

            candidate = {
                "planet": planet_name(ruler_id),
                "planet_id": ruler_id,
                "dignity_at_hyleg": dignity_label,
                "weight": total_weight,
                "sees_hyleg": sees,
                "witness_aspect": witness_aspect,
                "witness_orb": witness_orb,
                "aspect_to_hyleg": round(angular_separation(ruler_lon, hyleg_lon), 2),
                "own_condition_score": own_score,
                "own_condition_summary": _dignity_summary_short(
                    ruler_id, ruler_lon, is_day, bounds_system, triplicity_system
                ),
                "eligible_under_profile": eligible_under_profile,
                "rejection_reason": rejection_reason,
                "rank": 0,
                "reason": (
                    f"{dignity_label} ruler of hyleg"
                    + (f"；见证 {witness_aspect} orb={witness_orb}" if sees else "；不见 Hyleg → 淘汰")
                ),
            }
            alcocoden_candidates.append(candidate)

        # Select only among candidates that see Hyleg and hold dignity.
        selectable_pool = [c for c in alcocoden_candidates if c["eligible_under_profile"]]
        selectable_pool.sort(key=lambda c: (-c["weight"], -c["own_condition_score"]))
        for index, candidate in enumerate(alcocoden_candidates):
            candidate["rank"] = index + 1
        for index, candidate in enumerate(selectable_pool):
            candidate["rank"] = index + 1
        selectable_alcocoden = selectable_pool[0] if selectable_pool else None
        if selectable_alcocoden is None and any(c["weight"] > 0 for c in alcocoden_candidates):
            warnings.append(
                "Alcocoden: all dignity holders fail witness test under profile; no selection (longevity years suppressed)."
            )

    return {
        "hyleg": {
            "selected": selected_hyleg["name"] if selected_hyleg else "",
            "selected_id": selected_hyleg["id"] if selected_hyleg else "",
            "longitude": round(selected_hyleg["lon"], 4) if selected_hyleg else 0,
            "reason": selected_hyleg.get("reason", "") if selected_hyleg else "No eligible Hyleg candidate",
            "candidates": all_candidates,
            "eligible_count": sum(1 for c in all_candidates if c["eligible"]),
            "selected_count": 1 if selected_hyleg else 0,
            "selection_order": selection_order,
            "hylegical_places": sorted(hylegical_places),
            "day_night_rule": "day prefers Sun then ASC/lots; night prefers Moon then ASC/lots",
            "proxy": True,
            "hyleg_profile": hyleg_profile,
        },
        "alcocoden": {
            "selected": selectable_alcocoden["planet"] if selectable_alcocoden else "",
            "selected_id": selectable_alcocoden["planet_id"] if selectable_alcocoden else "",
            "dignity": selectable_alcocoden["dignity_at_hyleg"] if selectable_alcocoden else "",
            "candidates": alcocoden_candidates,
            "requires_witness": True,
            "proxy": True,
            "alcocoden_profile": alcocoden_profile,
            "longevity_years": None,
            "longevity_years_suppressed": True,
            "longevity_note": "寿命年数在 Hyleg/Alcocoden profile 经历史验证前禁止输出",
        },
        "method": "medieval_arabic_basic",
        "method_variant": hyleg_profile,
        "hyleg_profile": hyleg_profile,
        "alcocoden_profile": alcocoden_profile,
        "proxy": True,
        "_source_tradition": "Arabic/Medieval",
        "limitations": [
            "Simplified hylegical-places filter; not full traditional Hyleg judgment",
            "Witness uses major-aspect orb proxy",
            "No longevity years output",
        ],
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
