from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
    CLASSICAL_BODY_IDS,
    SIGNS,
    SIGN_RULERS,
    add_years_approx,
    angular_separation,
    completed_age,
    format_local,
    format_longitude,
    jd_from_datetime,
    norm360,
    planet_name,
    sign_degree,
    signed_orb,
    zodiac_sign_index,
)
from astro_backend_ephemeris import (
    build_houses,
    body_longitude_at,
    calculate_positions,
    house_for_longitude,
    house_rows,
    longitude_in_interval,
    point_row,
)
from astro_backend_return_solver import search_return_exacts
from astro_backend_classical_audit import (
    calculate_almuten_figuris,
    calculate_hyleg_alcocoden,
    calculate_prenatal_syzygy,
)
from astro_backend_classical_dignity import (
    EGYPTIAN_BOUNDS,
    EXALTATION_RULERS,
    FACE_ORDER,
    JOY_HOUSE,
    PTOLEMAIC_BOUNDS,
    SIGN_ELEMENTS,
    SIGN_GENDER,
    TRIPLICITY_RULERS,
    bounds_ruler,
    calc_dodekatemorion,
    decan_ruler,
    dignity_labels,
    dignity_ownership,
    dignity_rulers_for_lon,
    hayz_status,
    house_strength,
    place_quality_fields,
    joy_status,
    motion_label,
    sect_status,
    solar_phase,
    triplicity_ruler_details,
    triplicity_set,
)
from astro_backend_classical_lots import (
    calculate_lots,
    exaltation_lon,
    lot_value,
)
from astro_backend_classical_timing import (
    FIRDARIA_SEQUENCE_DAY,
    FIRDARIA_SEQUENCE_NIGHT,
    PLANETARY_YEARS,
    RETURN_CONFIG,
    ZR_PERIOD_YEARS,
    _detect_loosing_of_bond,
    _zr_walk,
    decennials_summary,
    firdaria_sub_periods,
    firdaria_summary,
    monthly_profection,
    profection_summary,
    return_search_bounds,
    timing_timeline,
    zodiacal_releasing_summary,
)

CLASSICAL_ASPECTS = {
    "合相": 0.0,
    "六合": 60.0,
    "刑相": 90.0,
    "拱相": 120.0,
    "冲相": 180.0,
}


def calculate_antiscia(planet_rows: list[dict[str, Any]], natal_positions: dict[str, dict[str, Any]], orb_limit: float) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for row in planet_rows:
        lon = row["longitude"]
        antiscia_lon = norm360(180.0 - lon)
        contra_lon = norm360(360.0 - lon)
        ant_sign, ant_deg = format_longitude(antiscia_lon)
        contra_sign, contra_deg = format_longitude(contra_lon)

        hits: list[dict[str, Any]] = []
        for natal_id, natal in natal_positions.items():
            orb = angular_separation(antiscia_lon, natal["longitude"])
            if orb <= orb_limit:
                hits.append({
                    "id": f"{row['id']}|antiscia|{natal_id}",
                    "hit_planet": planet_name(natal_id),
                    "via": "antiscia",
                    "orb": round(orb, 2),
                })
            orb_contra = angular_separation(contra_lon, natal["longitude"])
            if orb_contra <= orb_limit:
                hits.append({
                    "id": f"{row['id']}|contra|{natal_id}",
                    "hit_planet": planet_name(natal_id),
                    "via": "contra-antiscia",
                    "orb": round(orb_contra, 2),
                })

        rows.append({
            "id": f"antiscia-{row['id']}",
            "planet": row["name"],
            "planet_id": row["id"],
            "longitude": round(lon, 4),
            "antiscia_longitude": round(antiscia_lon, 4),
            "contra_longitude": round(contra_lon, 4),
            "antiscia_sign": ant_sign,
            "antiscia_degree": ant_deg,
            "contra_sign": contra_sign,
            "contra_degree": contra_deg,
            "natal_hits": hits,
            "orb_threshold": round(orb_limit, 2),
        })
    return rows


def calculate_classical_planets(
    jd_ut: float,
    cusps: list[float],
    is_day: bool,
    sidereal: bool,
    bounds_system: str,
    triplicity_system: str,
    warnings: list[str],
) -> tuple[list[dict[str, Any]], dict[str, dict[str, Any]], set[str]]:
    specs = [BODY_REGISTRY[body_id] for body_id in CLASSICAL_BODY_IDS]
    positions = calculate_positions(jd_ut, specs, warnings, sidereal=sidereal)
    by_id = {row["body_id"]: row for row in positions}
    sun_lon = by_id["SUN"]["longitude"]
    ephemerides = {row.get("_ephemeris", "Swiss Ephemeris") for row in positions}

    positions_with_house: dict[str, dict[str, Any]] = {}
    for body_id, row in by_id.items():
        positions_with_house[body_id] = {
            **row,
            "house": house_for_longitude(row["longitude"], cusps),
        }

    triplicity_cache: dict[int, list[dict[str, Any]]] = {}

    rows: list[dict[str, Any]] = []
    for row in positions:
        body_id = row["body_id"]
        house = house_for_longitude(row["longitude"], cusps)
        dignity = dignity_labels(body_id, row["longitude"], is_day, bounds_system, triplicity_system)
        domicile, exaltation, triplicity, bound, decan, dignity_score, dignity_notes, dignity_breakdown, detriment_label, fall_label = dignity
        rulers = dignity_rulers_for_lon(row["longitude"], is_day, bounds_system, triplicity_system)
        ownership = dignity_ownership(
            body_id,
            rulers,
            triplicity_set(zodiac_sign_index(row["longitude"]), triplicity_system),
        )
        phase, phase_score, phase_notes, phase_breakdown = solar_phase(body_id, row["longitude"], sun_lon)
        solar_condition = phase_breakdown.get("solar_condition", "-")
        sun_distance_deg = phase_breakdown.get("sun_distance_deg", 0)
        motion, motion_score, motion_notes, motion_breakdown = motion_label(body_id, row["speed"])
        sect, sect_score, sect_notes, sect_breakdown = sect_status(body_id, is_day, row["longitude"], sun_lon, house)
        hayz, hayz_score, hayz_notes, hayz_breakdown = hayz_status(body_id, is_day, row["longitude"], house, sun_lon)
        joy, joy_score, joy_notes, joy_breakdown = joy_status(body_id, house)
        accidental = house_strength(house)
        place_fields = place_quality_fields(house)
        accidental_score = 3 if accidental == "角宫" else 1 if accidental == "续宫" else -1
        # Place quality is reported separately; scoring still uses angularity only (documented).
        base_score = dignity_score + phase_score + motion_score + sect_score + accidental_score + hayz_score + joy_score
        score_label = score_label_for(base_score)
        notes = dignity_notes + phase_notes + motion_notes + sect_notes + hayz_notes + joy_notes + [accidental]
        score_breakdown = dignity_breakdown + [
            phase_breakdown,
            motion_breakdown,
            sect_breakdown,
            hayz_breakdown,
            joy_breakdown,
            {"label": "accidental", "score": accidental_score, "value": accidental},
            {"label": "place_quality", "score": 0, "value": place_fields["place_quality"], "note": "not substituted for angularity score"},
        ]

        sign_idx = zodiac_sign_index(row["longitude"])
        if sign_idx not in triplicity_cache:
            triplicity_cache[sign_idx] = triplicity_ruler_details(sign_idx, triplicity_system, positions_with_house)

        # Expand sect layers from breakdown when available.
        sect_trace = sect_breakdown if isinstance(sect_breakdown, dict) else {}
        hayz_trace = (hayz_breakdown or {}).get("trace") if isinstance(hayz_breakdown, dict) else {}
        solar_trace = phase_breakdown if isinstance(phase_breakdown, dict) else {}

        rows.append(
            {
                "id": body_id,
                "name": row["name"],
                "longitude": row["longitude"],
                "declination": row.get("declination"),
                "out_of_bounds": row.get("out_of_bounds", False),
                "sign": row["sign"],
                "degree_text": row["degree_text"],
                "house": house,
                "speed": row["speed"],
                "motion": motion,
                "sect_status": sect,
                "chart_sect": sect_trace.get("chart_sect") or ("day" if is_day else "night"),
                "planet_sect": sect_trace.get("planet_sect"),
                "above_horizon": house >= 7,
                "sign_gender": SIGN_GENDER[sign_idx],
                "sect_agreement": sect_trace.get("sect_agreement"),
                "horizon_agreement": (hayz_trace or {}).get("above_horizon") if hayz_trace else (house >= 7) == is_day,
                "gender_agreement": (hayz_trace or {}).get("sign_gender"),
                "partial_hayz": bool(hayz) is False and bool(sect_trace.get("sect_agreement")),
                "angularity_class": place_fields["angularity_class"],
                "place_quality": place_fields["place_quality"],
                "beholds_ascendant": place_fields["beholds_ascendant"],
                "aversion_to_ascendant": place_fields["aversion_to_ascendant"],
                "traditional_place_name": place_fields["traditional_place_name"],
                "solar_elongation_condition": solar_trace.get("solar_elongation_condition") or solar_trace.get("solar_condition"),
                "combust": solar_trace.get("combust"),
                "under_beams": solar_trace.get("under_beams"),
                "cazimi": solar_trace.get("cazimi"),
                "heliacally_visible": solar_trace.get("heliacally_visible"),
                "visibility_method": solar_trace.get("visibility_method") or "solar_elongation_thresholds_only",
                "domicile": domicile,
                "detriment": detriment_label,
                "exaltation": exaltation,
                "fall": fall_label,
                "triplicity": triplicity,
                "triplicity_details": triplicity_cache[sign_idx],
                "bound": bound,
                "decan": decan,
                "domicile_ruler": ownership["domicile_ruler"],
                "exaltation_ruler": ownership["exaltation_ruler"],
                "triplicity_rulers": ownership["triplicity_rulers"],
                "bound_ruler": ownership["bound_ruler"],
                "decan_ruler": ownership["decan_ruler"],
                "subject_owns_domicile": ownership["subject_owns_domicile"],
                "subject_owns_exaltation": ownership["subject_owns_exaltation"],
                "subject_owns_triplicity": ownership["subject_owns_triplicity"],
                "subject_owns_bound": ownership["subject_owns_bound"],
                "subject_owns_decan": ownership["subject_owns_decan"],
                "solar_phase": phase,
                "solar_condition": solar_condition,
                "sun_distance_deg": sun_distance_deg,
                "accidental": accidental,
                "hayz": hayz,
                "joy": joy,
                "planetary_years": PLANETARY_YEARS.get(body_id, 0),
                "score": base_score,
                "score_label": score_label,
                "notes": notes,
                "score_breakdown": score_breakdown,
                "bonification": [],
                "maltreatment": [],
                "dodekatemorion_longitude": calc_dodekatemorion(row["longitude"])[0],
                "dodekatemorion_ruler": calc_dodekatemorion(row["longitude"])[2],
            }
        )

    return rows, by_id, ephemerides


def aspect_name_for_sign_delta(delta: int) -> str | None:
    return {0: "合相", 2: "六合", 3: "刑相", 4: "拱相", 6: "冲相", 8: "拱相", 9: "刑相", 10: "六合"}.get(delta % 12)


def aspect_offsets_for_angle(angle: float) -> list[float]:
    normalized = angle % 360.0
    if abs(normalized) < 1e-9:
        return [0.0]
    if abs(normalized - 180.0) < 1e-9:
        return [180.0]
    return [normalized, -normalized]


def signed_aspect_orb(a_longitude: float, b_longitude: float, angle: float) -> float:
    return min(
        (
            signed_orb(a_longitude, (b_longitude + offset) % 360.0)
            for offset in aspect_offsets_for_angle(angle)
        ),
        key=abs,
    )


def applying_label(a: dict[str, Any], b: dict[str, Any], angle: float) -> str:
    orb = signed_aspect_orb(a["longitude"], b["longitude"], angle)
    if abs(orb) < 1e-9:
        return "入相"
    relative_speed = float(a.get("speed", 0.0)) - float(b.get("speed", 0.0))
    if abs(relative_speed) < 1e-9:
        return "离相"
    return "入相" if orb * relative_speed < 0 else "离相"


def classical_aspect_signature(
    a: dict[str, Any],
    b: dict[str, Any],
    orb_limit: float,
) -> tuple[str, str, float | None, str | None, str | None] | None:
    sign_delta = zodiac_sign_index(b["longitude"]) - zodiac_sign_index(a["longitude"])
    sign_aspect = aspect_name_for_sign_delta(sign_delta)
    separation = angular_separation(a["longitude"], b["longitude"])
    for aspect_name, angle in CLASSICAL_ASPECTS.items():
        orb = abs(separation - angle)
        if orb <= orb_limit:
            aspect_geometry = "degree"
            return aspect_name, aspect_geometry, orb, applying_label(a, b, angle), "degree-based aspect"
    if sign_aspect:
        display_name: str
        aspect_geometry: str
        if sign_delta % 12 == 0:
            display_name = "同宫"
            aspect_geometry = "co_presence"
        else:
            display_name = f"整宫{sign_aspect}"
            aspect_geometry = "sign"
        return display_name, aspect_geometry, None, None, "sign-based aspect"
    return None


def reception_strength(dignity: str, via_aspect: str, applying: str | None, aspect_geometry: str = "degree") -> tuple[int, str]:
    dignity_weight = {"domicile": 5, "exaltation": 4, "triplicity": 3, "bound": 2, "decan": 1}.get(dignity, 1)
    aspect_weight = {"合相": 2, "拱相": 2, "六合": 1, "刑相": 0, "冲相": 0}.get(via_aspect, 0)
    if aspect_geometry == "sign":
        aspect_weight = max(0, aspect_weight - 1)
    applying_weight = 1 if applying == "入相" else 0
    total = dignity_weight + aspect_weight + applying_weight
    if total >= 7:
        return total, "强"
    if total >= 5:
        return total, "中"
    return total, "弱"


def conditioning_strength(aspect: str, orb: float | None, applying: str | None) -> tuple[int, str]:
    base = {"合相": 3, "拱相": 2, "六合": 1, "刑相": 2, "冲相": 3}.get(aspect, 1)
    if orb is not None and orb <= 1.0:
        base += 1
    if applying == "入相":
        base += 1
    if base >= 5:
        return base, "强"
    if base >= 3:
        return base, "中"
    return base, "弱"


def score_label_for(score: int) -> str:
    """Return the single display label for a planet's final score."""
    if score >= 10:
        return "强而有力"
    if score >= 5:
        return "状态良好"
    if score >= 1:
        return "一般可用"
    if score >= -4:
        return "偏弱受克"
    return "严重衰弱"


def apply_conditioning(
    planet_rows: list[dict[str, Any]],
    planet_positions: dict[str, dict[str, Any]],
    orb_limit: float,
) -> list[dict[str, Any]]:
    by_id = {row["id"]: row for row in planet_rows}
    ids = [row["id"] for row in planet_rows]
    benefics = {"VENUS", "JUPITER"}
    malefics = {"MARS", "SATURN"}

    for left_index, body_a in enumerate(ids):
        for body_b in ids[left_index + 1 :]:
            a = planet_positions[body_a]
            b = planet_positions[body_b]
            signature = classical_aspect_signature(a, b, orb_limit)
            if signature is None:
                continue
            aspect_name, aspect_geometry, orb, applying, _aspect_kind = signature

            def _benefic_strength_modifier(source_id: str) -> float:
                source_row = by_id.get(source_id)
                if source_row is None:
                    return 0.5
                source_score = source_row.get("score", 0)
                sect_val = source_row.get("sect_status", "")
                modifier = 1.0
                if source_score < 0:
                    modifier -= 0.5
                elif source_score < 2:
                    modifier -= 0.25
                if "违" in sect_val:
                    modifier -= 0.25
                return max(modifier, 0.25)

            def maybe_add(source_id: str, target_id: str) -> None:
                modifier_kind: str | None = None
                if source_id in benefics and aspect_name in {"合相", "拱相", "六合"}:
                    modifier_kind = "bonification"
                    base_delta = 2 if aspect_geometry == "degree" else 1
                    strength_mod = _benefic_strength_modifier(source_id)
                    score_delta = round(base_delta * strength_mod)
                    benefic_row = by_id.get(source_id, {})
                    benefic_condition = f"score={benefic_row.get('score',0)}"
                elif source_id in malefics and aspect_name in {"合相", "刑相", "冲相"}:
                    modifier_kind = "maltreatment"
                    base_delta = -2 if aspect_geometry == "degree" else -1
                    strength_mod = 1.0
                    score_delta = int(base_delta * strength_mod)
                    benefic_row = {}
                    benefic_condition = "malefic"
                if modifier_kind is None:
                    return
                strength_score, strength_label = conditioning_strength(aspect_name, orb, applying)
                source_row_data = by_id.get(source_id, {})
                by_id[target_id][modifier_kind].append(
                    {
                        "source": planet_name(source_id),
                        "aspect": aspect_name,
                        "orb": orb,
                        "applying": applying,
                        "strength_score": strength_score,
                        "strength_label": strength_label,
                        "aspect_geometry": aspect_geometry,
                        "score_delta": score_delta,
                        "benefic_condition": benefic_condition if source_id in benefics else "",
                        "strength_modifier": strength_mod if source_id in benefics else 1.0,
                        "base_delta": base_delta,
                    }
                )
                by_id[target_id]["score"] = by_id[target_id].get("score", 0) + score_delta
                by_id[target_id]["score_breakdown"].append({
                    "label": modifier_kind,
                    "score": score_delta,
                    "value": f"{planet_name(source_id)} {aspect_name}",
                })

            maybe_add(body_a, body_b)
            maybe_add(body_b, body_a)

    for row in planet_rows:
        row["score_label"] = score_label_for(int(row.get("score", 0)))
    return planet_rows


def classical_aspects_and_receptions(
    planet_rows: list[dict[str, Any]],
    planet_positions: dict[str, dict[str, Any]],
    is_day: bool,
    bounds_system: str,
    triplicity_system: str,
    orb_limit: float,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    aspects: list[dict[str, Any]] = []
    receptions: list[dict[str, Any]] = []
    ids = [row["id"] for row in planet_rows]

    for left_index, body_a in enumerate(ids):
        for body_b in ids[left_index + 1 :]:
            a = planet_positions[body_a]
            b = planet_positions[body_b]
            signature = classical_aspect_signature(a, b, orb_limit)
            if signature is None:
                continue
            aspect_name, aspect_geometry, aspect_orb, applying, aspect_kind = signature

            aspects.append(
                {
                    "id": f"{body_a}|{aspect_name}|{body_b}|{aspect_geometry}",
                    "body_a": planet_name(body_a),
                    "body_b": planet_name(body_b),
                    "aspect": aspect_name,
                    "aspect_type": aspect_geometry,
                    "aspect_geometry": aspect_geometry,
                    "aspect_kind": aspect_kind,
                    "orb": aspect_orb if aspect_geometry == "degree" else None,
                    "applying": applying if aspect_geometry == "degree" else None,
                }
            )
            via_aspect = aspect_name

            for received_id, receiver_id in [(body_a, body_b), (body_b, body_a)]:
                received = planet_positions[received_id]
                dignities = dignity_rulers_for_lon(received["longitude"], is_day, bounds_system, triplicity_system)
                for dignity, ruler in dignities.items():
                    if ruler == receiver_id:
                        strength_score, strength_label = reception_strength(dignity, via_aspect, applying, aspect_geometry)
                        receptions.append(
                            {
                                "id": f"{receiver_id}|receives|{received_id}|{dignity}|{via_aspect}",
                                "receiver": planet_name(receiver_id),
                                "received": planet_name(received_id),
                                "dignity": dignity,
                                "via_aspect": via_aspect,
                                "aspect_geometry": aspect_geometry,
                                "aspect_orb": aspect_orb,
                                "strength_score": strength_score,
                                "strength_label": strength_label,
                            }
                        )

    return aspects, receptions


def cross_chart_aspects(
    left_positions: dict[str, dict[str, Any]],
    right_positions: dict[str, dict[str, Any]],
    left_label: str,
    right_label: str,
    orb_limit: float,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for left_id, left in left_positions.items():
        for right_id, right in right_positions.items():
            signature = classical_aspect_signature(left, right, orb_limit)
            if signature is None:
                continue
            aspect_name, aspect_geometry, aspect_orb, applying, aspect_kind = signature
            is_degree = aspect_geometry == "degree"
            is_sign = aspect_geometry == "sign"
            is_co = aspect_geometry == "co_presence"

            display_zh = aspect_name
            display_en = "conjunction" if aspect_name == "合相" else "sextile" if aspect_name == "六合" or aspect_name == "整宫六合" else "square" if aspect_name == "刑相" or aspect_name == "整宫刑相" else "trine" if aspect_name == "拱相" or aspect_name == "整宫拱相" else "opposition" if aspect_name == "冲相" or aspect_name == "整宫冲相" else "co-presence" if aspect_name == "同宫" else aspect_name

            rows.append(
                {
                    "id": f"{left_id}|{aspect_name}|{right_id}|cross",
                    "left_body_id": left_id,
                    "left_body_name": left["name"],
                    "right_body_id": right_id,
                    "right_body_name": right["name"],
                    "left_label": left_label,
                    "right_label": right_label,
                    "aspect": aspect_name,
                    "aspect_geometry": aspect_geometry,
                    "aspect_kind": aspect_kind,
                    "orb": aspect_orb,
                    "applying": applying,
                    "is_degree_aspect": is_degree,
                    "is_whole_sign_aspect": is_sign,
                    "is_co_presence": is_co,
                    "display_label_zh": display_zh,
                    "display_label_en": display_en,
                }
            )
    rows.sort(key=lambda row: (row["orb"] if row["orb"] is not None else 999.0, row["left_body_name"], row["right_body_name"]))
    return rows


def classical_snapshot(
    jd_ut: float,
    latitude: float,
    longitude: float,
    house_system: str,
    sidereal: bool,
    bounds_system: str,
    triplicity_system: str,
    aspect_orb: float,
    warnings: list[str],
) -> dict[str, Any]:
    cusps, angles, house_label = build_houses(jd_ut, latitude, longitude, house_system, sidereal, warnings)
    angle_rows = [
        point_row("ASC", "ASC", angles["ASC"], cusps),
        point_row("MC", "MC", angles["MC"], cusps),
        point_row("DSC", "DSC", angles["DSC"], cusps),
        point_row("IC", "IC", angles["IC"], cusps),
    ]
    prelim_positions = calculate_positions(
        jd_ut,
        [BODY_REGISTRY[body_id] for body_id in CLASSICAL_BODY_IDS],
        warnings,
        sidereal=sidereal,
    )
    prelim_by_id = {row["body_id"]: row for row in prelim_positions}
    sun_longitude = prelim_by_id["SUN"]["longitude"]
    sun_house = house_for_longitude(sun_longitude, cusps)
    is_day = longitude_in_interval(sun_longitude, angles["DSC"], angles["ASC"])

    planet_rows, planet_positions, ephemerides = calculate_classical_planets(
        jd_ut, cusps, is_day, sidereal, bounds_system, triplicity_system, warnings
    )
    lot_rows = calculate_lots(angles, planet_positions, cusps, is_day, mc=angles.get("MC", 270.0), warnings=warnings)
    aspects, receptions = classical_aspects_and_receptions(
        planet_rows, planet_positions, is_day, bounds_system, triplicity_system, aspect_orb
    )
    planet_rows = apply_conditioning(planet_rows, planet_positions, aspect_orb)
    return {
        "house_label": house_label,
        "is_day": is_day,
        "sun_horizon_status": "above horizon" if is_day else "below horizon",
        "angles": angle_rows,
        "houses": house_rows(cusps),
        "planets": planet_rows,
        "planet_positions": planet_positions,
        "lots": lot_rows,
        "aspects": aspects,
        "receptions": receptions,
        "ephemerides": ephemerides,
    }
def _empty_return(body_id: str, spec: BodySpec, config: dict[str, Any], start: datetime, end: datetime) -> dict[str, Any]:
    from astro_backend_core import BodySpec
    window_days = int((end - start).total_seconds() / 172800)
    return {
        "id": body_id.lower(),
        "body_id": body_id,
        "body_name": spec.name,
        "title": config["title"],
        "no_hit_in_user_window": True,
        "suggested_window": f"建议搜索窗口 ±{window_days * 3} 天（当前为 ±{window_days} 天）",
        "previous_return": None,
        "current_cycle_return": None,
        "next_return": None,
        "search_start_local": format_local(start),
        "search_end_local": format_local(end),
    }


def return_summary(
    body_id: str,
    birth_dt: datetime,
    reference_dt: datetime,
    natal_longitude: float,
    natal_positions: dict[str, dict[str, Any]],
    latitude: float,
    longitude: float,
    sidereal: bool,
    house_system: str,
    bounds_system: str,
    triplicity_system: str,
    aspect_orb: float,
    warnings: list[str],
    natal_asc_lon: float = 0.0,
    natal_cusps: list[float] | None = None,
) -> dict[str, Any]:
    config = RETURN_CONFIG[body_id]
    spec = BODY_REGISTRY[body_id]
    start, end = return_search_bounds(body_id, birth_dt, reference_dt)
    exacts = search_return_exacts(
        body_spec=spec,
        target_longitude=natal_longitude,
        start=start,
        end=end,
        step_hours=config["step_hours"],
        sidereal=sidereal,
        warnings=warnings,
        title=config["title"],
    )
    before = [exact for exact in exacts if exact <= reference_dt]
    after = [exact for exact in exacts if exact > reference_dt]
    previous_exact: datetime | None = before[-1] if before else None
    prev_previous_exact: datetime | None = before[-2] if len(before) >= 2 else None
    next_exact: datetime | None = after[0] if after else None

    if previous_exact is None and next_exact is None:
        warnings.append(f"未能在搜索窗口内找到{config['title']}精确时间（窗口 {format_local(start)} 至 {format_local(end)}）。建议扩大搜索窗口。")
        return _empty_return(body_id, spec, config, start, end)

    def _build_snapshot(exact_dt: datetime, label: str) -> dict[str, Any]:
        snap = classical_snapshot(
            jd_ut=jd_from_datetime(exact_dt),
            latitude=latitude,
            longitude=longitude,
            house_system=house_system,
            sidereal=sidereal,
            bounds_system=bounds_system,
            triplicity_system=triplicity_system,
            aspect_orb=aspect_orb,
            warnings=warnings,
        )
        angle_id = {r["id"]: r for r in snap["angles"]}
        cross = cross_chart_aspects(snap["planet_positions"], natal_positions, config["title"], "Natal", aspect_orb)
        cusps_list = [h["cusp_longitude"] for h in snap["houses"]] if snap["houses"] else []
        r_asc_lon = angle_id["ASC"]["longitude"]
        r_asc_sign_idx = zodiac_sign_index(r_asc_lon)
        r_chart_ruler = SIGN_RULERS[r_asc_sign_idx]
        r_chart_ruler_name = planet_name(r_chart_ruler)
        r_angular = [p["name"] for p in snap["planets"] if p["house"] in {1, 4, 7, 10}]
        r_activated: list[str] = []
        if natal_cusps and natal_positions:
            for cr in cross:
                if cr.get("aspect") == "合相" and cr.get("orb") is not None and cr["orb"] <= 3.0:
                    n = cr.get("right_body_name", "")
                    if n and n not in r_activated:
                        r_activated.append(n)
        r_overlay: list[dict[str, Any]] = []
        if natal_cusps:
            for p in snap["planets"]:
                r_overlay.append({
                    "id": f"overlay-{p['id']}",
                    "planet": p["name"],
                    "return_house": p["house"],
                    "natal_house": house_for_longitude(p["longitude"], natal_cusps),
                })
        r_asc_natal_house = house_for_longitude(r_asc_lon, natal_cusps) if natal_cusps else 0
        r_age = completed_age(birth_dt, reference_dt)
        r_prof_asc_lon = norm360(natal_asc_lon + r_age * 30)
        r_prof_asc_sign = SIGNS[zodiac_sign_index(r_prof_asc_lon)]
        r_prof_asc_house = house_for_longitude(r_prof_asc_lon, cusps_list) if cusps_list else 0
        return {
            "label": label,
            "exact_local": format_local(exact_dt),
            "exact_utc": exact_dt.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M"),
            "ascendant": angle_id["ASC"]["degree_text"],
            "midheaven": angle_id["MC"]["degree_text"],
            "sect": "昼盘" if snap["is_day"] else "夜盘",
            "house_system": snap["house_label"],
            "return_chart_ruler": r_chart_ruler_name,
            "return_chart_ruler_id": r_chart_ruler,
            "angular_planets": r_angular,
            "activated_natal_points": r_activated,
            "angles": snap["angles"],
            "houses": snap["houses"],
            "planets": snap["planets"],
            "natal_cross_aspects": cross,
            "profected_asc_sign": r_prof_asc_sign,
            "profected_asc_house": r_prof_asc_house,
            "return_asc_in_natal_house": r_asc_natal_house,
            "house_overlay": r_overlay,
        }

    def _cluster_hits(exacts_list: list[datetime], gap_days: float = 120.0) -> list[list[datetime]]:
        """Group natal-degree crossings that belong to the same retrograde/return cycle."""
        if not exacts_list:
            return []
        ordered = sorted(exacts_list)
        clusters: list[list[datetime]] = [[ordered[0]]]
        for hit in ordered[1:]:
            if (hit - clusters[-1][-1]).total_seconds() <= gap_days * 86400:
                clusters[-1].append(hit)
            else:
                clusters.append([hit])
        return clusters

    # Cluster all hits in window; also attempt to classify postnatal recrossings (inner/outer).
    all_hits = sorted(exacts)
    clusters = _cluster_hits(all_hits, gap_days=150.0 if body_id in {"JUPITER", "SATURN"} else 40.0)

    def _annotate_hit(exact_dt: datetime | None, label: str) -> dict[str, Any] | None:
        if exact_dt is None:
            return None
        snap = _build_snapshot(exact_dt, label)
        # Find cluster membership
        cluster_idx = None
        hit_number = 1
        total_hits = 1
        for idx, cluster in enumerate(clusters):
            if exact_dt in cluster:
                cluster_idx = idx
                hit_number = cluster.index(exact_dt) + 1
                total_hits = len(cluster)
                break
        cycle_start = clusters[cluster_idx][0] if cluster_idx is not None else exact_dt
        cycle_end = clusters[cluster_idx][-1] if cluster_idx is not None else exact_dt
        prev_cluster = clusters[cluster_idx - 1] if cluster_idx and cluster_idx > 0 else None
        next_cluster = clusters[cluster_idx + 1] if cluster_idx is not None and cluster_idx + 1 < len(clusters) else None

        # Postnatal recrossing: hit after birth but belonging to the first post-birth degree re-pass
        # of the natal cycle (not a mature multi-orbit return). Heuristic: age < 3 years for outer planets.
        age_at_hit = completed_age(birth_dt, exact_dt)
        is_postnatal_recrossing = body_id in {"JUPITER", "SATURN", "MARS"} and age_at_hit < 3

        # valid_until: for Sun/Moon → next return; for others → end of distinct next cycle start if known
        if body_id in {"SUN", "MOON"} and next_exact is not None:
            valid_until = format_local(next_exact)
            is_current_cycle = previous_exact == exact_dt
        elif next_cluster is not None:
            valid_until = format_local(next_cluster[0])
            is_current_cycle = (
                previous_exact is not None
                and cluster_idx is not None
                and previous_exact in clusters[cluster_idx]
            )
        else:
            valid_until = None
            is_current_cycle = previous_exact == exact_dt

        # Do not mark early postnatal recrossings as a multi-decade "current return".
        if is_postnatal_recrossing:
            is_current_cycle = False
            valid_until = format_local(cycle_end) if cycle_end else valid_until

        snap.update({
            "return_cycle_id": f"{body_id.lower()}-cycle-{cluster_idx if cluster_idx is not None else 0}",
            "planet": body_id,
            "hit_number": hit_number,
            "total_hits": total_hits,
            "exact_time": snap.get("exact_utc") or snap.get("exact_local"),
            "motion_at_hit": next((p.get("motion") for p in snap.get("planets") or [] if p.get("id") == body_id), None),
            "cycle_start": format_local(cycle_start),
            "cycle_end": format_local(cycle_end),
            "previous_distinct_cycle": format_local(prev_cluster[0]) if prev_cluster else None,
            "next_distinct_cycle": format_local(next_cluster[0]) if next_cluster else None,
            "is_postnatal_recrossing": is_postnatal_recrossing,
            "is_current_cycle": is_current_cycle,
            "valid_until": valid_until,
            "location": {
                "latitude": latitude,
                "longitude": longitude,
                "source": "birth_place",
                "timezone": None,
            },
            "location_source": "birth_place",
        })
        return snap

    # Prefer not to present a postnatal recrossing as current_cycle_return when a later mature cycle exists.
    current_hit = previous_exact
    if current_hit is not None and body_id in {"JUPITER", "SATURN", "MARS"}:
        age_cur = completed_age(birth_dt, current_hit)
        if age_cur < 3:
            # Look for a later pre-reference hit that is not a postnatal recrossing.
            mature = [h for h in before if completed_age(birth_dt, h) >= 3]
            if mature:
                current_hit = mature[-1]
                # previous becomes the hit before current_hit
                earlier = [h for h in before if h < current_hit]
                prev_previous_exact = earlier[-1] if earlier else None
            else:
                # No mature return yet — keep as historical reference, not multi-decade current.
                pass

    previous_snapshot = _annotate_hit(prev_previous_exact, "previous_return") if prev_previous_exact else None
    current_snapshot = _annotate_hit(current_hit, "current_cycle_return") if current_hit else None
    next_snapshot = _annotate_hit(next_exact, "next_return") if next_exact else None

    all_hit_rows = []
    for c_idx, cluster in enumerate(clusters):
        for h_idx, hit in enumerate(cluster, start=1):
            all_hit_rows.append({
                "return_cycle_id": f"{body_id.lower()}-cycle-{c_idx}",
                "hit_number": h_idx,
                "total_hits": len(cluster),
                "exact_local": format_local(hit),
                "is_postnatal_recrossing": completed_age(birth_dt, hit) < 3 and body_id in {"JUPITER", "SATURN", "MARS"},
            })

    return {
        "id": body_id.lower(),
        "body_id": body_id,
        "body_name": spec.name,
        "title": config["title"],
        "no_hit_in_user_window": False,
        "suggested_window": None,
        "previous_return": previous_snapshot,
        "current_cycle_return": current_snapshot,
        "next_return": next_snapshot,
        "all_hits_in_window": all_hit_rows,
        "search_start_local": format_local(start),
        "search_end_local": format_local(end),
        "location": {
            "latitude": latitude,
            "longitude": longitude,
            "source": "birth_place",
        },
        "method_note": "Hits clustered by proximity into return cycles; postnatal recrossings are not multi-decade current returns.",
    }
