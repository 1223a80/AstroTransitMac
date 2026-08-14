"""Judgment-free Krishnamurti Paddhati (KP) horary data engine.

Entry point: ``calculate_kp_horary(request, warnings)``
Mode: ``kp_horary``

The question time determines planetary positions.  The selected 1--249 KP
number determines a sidereal Ascendant segment; a separate Swiss Ephemeris
reference instant is solved only to obtain internally consistent Placidus
cusps for that Ascendant.  Both instants and the solve residual are exposed in
the packet so consumers cannot mistake the construction for an ordinary event
chart.
"""

from __future__ import annotations

import math
from datetime import timedelta, timezone
from fractions import Fraction
from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
    SIGN_RULERS,
    format_longitude,
    jd_from_datetime,
    moment_to_local_datetime,
    norm360,
    set_zodiac_mode,
    swe,
    zodiac_sign_index,
)
from astro_backend_ephemeris import (
    calculate_positions,
    call_houses_ex,
    house_for_longitude,
)
from astro_backend_jyotish_data import (
    NAKSHATRA_DATA,
    VEDIC_PLANET_NAMES,
    VIMSOTTARI_DURATIONS,
    VIMSOTTARI_LORD_ORDER,
    VIMSOTTARI_TOTAL,
)


SCHEMA_ID = "kp-horary-data-packet/1.0"
KP_ZODIAC = "sidereal_krishnamurti"
KP_HOUSE_SYSTEM = "placidus"
KP_PLANET_ORDER = [
    "SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN", "RAHU", "KETU",
]
WEEKDAY_LORDS = ["MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN", "SUN"]


def _planet_name(planet_id: str) -> str:
    vedic = VEDIC_PLANET_NAMES.get(planet_id)
    if vedic is not None:
        return vedic[1]
    body = BODY_REGISTRY.get(planet_id)
    return body.name if body is not None else planet_id


def _lord_row(planet_id: str) -> dict[str, str]:
    return {"id": planet_id, "name": _planet_name(planet_id)}


def _rotated_lords(start_lord: str) -> list[str]:
    start = VIMSOTTARI_LORD_ORDER.index(start_lord)
    return VIMSOTTARI_LORD_ORDER[start:] + VIMSOTTARI_LORD_ORDER[:start]


def _base_sub_segments() -> list[dict[str, Any]]:
    """Return the canonical 243 Nakshatra/sub-lord intervals as Fractions."""
    rows: list[dict[str, Any]] = []
    nakshatra_length = Fraction(40, 3)
    total = Fraction(VIMSOTTARI_TOTAL, 1)
    for nakshatra_index in range(27):
        start = Fraction(nakshatra_index, 1) * nakshatra_length
        nakshatra_lord = VIMSOTTARI_LORD_ORDER[nakshatra_index % 9]
        cursor = start
        for sub_lord in _rotated_lords(nakshatra_lord):
            end = cursor + nakshatra_length * Fraction(VIMSOTTARI_DURATIONS[sub_lord], 1) / total
            rows.append(
                {
                    "nakshatra_index": nakshatra_index,
                    "nakshatra_lord": nakshatra_lord,
                    "sub_lord": sub_lord,
                    "start": cursor,
                    "end": end,
                }
            )
            cursor = end
    return rows


def kp_number_segments() -> list[dict[str, Any]]:
    """Return all 249 sign-safe KP horary-number intervals.

    Six of the 243 Nakshatra/sub-lord intervals cross a 30-degree sign
    boundary. Splitting those intervals at the boundary yields the traditional
    249-number table without storing an opaque CSV.
    """
    result: list[dict[str, Any]] = []
    sign_boundaries = [Fraction(value, 1) for value in range(30, 360, 30)]
    for base in _base_sub_segments():
        cuts = [base["start"]]
        cuts.extend(boundary for boundary in sign_boundaries if base["start"] < boundary < base["end"])
        cuts.append(base["end"])
        for start, end in zip(cuts, cuts[1:]):
            result.append(
                {
                    "number": len(result) + 1,
                    "nakshatra_index": base["nakshatra_index"],
                    "nakshatra_lord": base["nakshatra_lord"],
                    "sub_lord": base["sub_lord"],
                    "start": float(start),
                    "end": float(end),
                }
            )
    if len(result) != 249:
        raise RuntimeError(f"KP number table invariant failed: expected 249, got {len(result)}")
    return result


_BASE_SUB_SEGMENTS = _base_sub_segments()
_KP_NUMBER_SEGMENTS = kp_number_segments()


def _contains(value: Fraction, start: Fraction, end: Fraction, *, final: bool = False) -> bool:
    return start <= value <= end if final else start <= value < end


def _sub_segment_for_longitude(longitude: float) -> dict[str, Any]:
    normalized = norm360(longitude)
    value = Fraction(str(normalized))
    for index, row in enumerate(_BASE_SUB_SEGMENTS):
        if _contains(value, row["start"], row["end"], final=index == len(_BASE_SUB_SEGMENTS) - 1):
            return row
    return _BASE_SUB_SEGMENTS[0]


def _sub_sub_segment(longitude: float, sub_segment: dict[str, Any]) -> dict[str, Any]:
    value = Fraction(str(norm360(longitude)))
    cursor: Fraction = sub_segment["start"]
    sub_length: Fraction = sub_segment["end"] - sub_segment["start"]
    total = Fraction(VIMSOTTARI_TOTAL, 1)
    sequence = _rotated_lords(sub_segment["sub_lord"])
    for index, lord in enumerate(sequence):
        end = cursor + sub_length * Fraction(VIMSOTTARI_DURATIONS[lord], 1) / total
        if _contains(value, cursor, end, final=index == len(sequence) - 1):
            return {"lord": lord, "start": cursor, "end": end}
        cursor = end
    return {"lord": sequence[-1], "start": cursor, "end": sub_segment["end"]}


def _hierarchy(longitude: float) -> dict[str, Any]:
    longitude = norm360(longitude)
    sign_index = zodiac_sign_index(longitude)
    nakshatra_index = min(int(longitude / (40.0 / 3.0)), 26)
    nakshatra = NAKSHATRA_DATA[nakshatra_index]
    nak_start = Fraction(nakshatra_index * 40, 3)
    nak_end = Fraction((nakshatra_index + 1) * 40, 3)
    pada = min(int((longitude - float(nak_start)) / (10.0 / 3.0)) + 1, 4)
    sub = _sub_segment_for_longitude(longitude)
    sub_sub = _sub_sub_segment(longitude, sub)
    sign_lord = SIGN_RULERS[sign_index]
    return {
        "sign_lord": _lord_row(sign_lord),
        "nakshatra": {
            "index": nakshatra_index + 1,
            "name": nakshatra["name_sa"],
            "name_zh": nakshatra["name_zh"],
            "lord": _lord_row(nakshatra["lord"]),
            "pada": pada,
            "start_longitude": float(nak_start),
            "end_longitude": float(nak_end),
        },
        "sub_lord": {
            **_lord_row(sub["sub_lord"]),
            "start_longitude": float(sub["start"]),
            "end_longitude": float(sub["end"]),
        },
        "sub_sub_lord": {
            **_lord_row(sub_sub["lord"]),
            "start_longitude": float(sub_sub["start"]),
            "end_longitude": float(sub_sub["end"]),
        },
    }


def _position_identity(longitude: float) -> dict[str, Any]:
    sign, degree_text = format_longitude(longitude)
    return {
        "longitude": norm360(longitude),
        "sign": sign,
        "degree_text": degree_text,
        **_hierarchy(longitude),
    }


def _angular_distance(first: float, second: float) -> float:
    return abs(((first - second + 180.0) % 360.0) - 180.0)


def _sidereal_ascendant(jd_ut: float, latitude: float, longitude: float) -> float:
    _, ascmc = call_houses_ex(jd_ut, latitude, longitude, "P", True)
    if len(ascmc) < 2:
        raise ValueError("Swiss Ephemeris did not return Placidus ASC/MC")
    return norm360(float(ascmc[0]))


def _solve_house_reference_jd(
    question_jd: float,
    latitude: float,
    longitude: float,
    target_ascendant: float,
) -> tuple[float, float, int]:
    """Find a nearby instant whose sidereal Placidus ASC matches the target."""
    search_half_days = 0.55
    coarse_step = 5.0 / 1440.0
    evaluations = 0
    best_jd = question_jd
    best_distance = math.inf
    steps = int((search_half_days * 2.0) / coarse_step) + 1
    for index in range(steps):
        candidate = question_jd - search_half_days + index * coarse_step
        distance = _angular_distance(
            _sidereal_ascendant(candidate, latitude, longitude), target_ascendant
        )
        evaluations += 1
        if distance < best_distance:
            best_distance = distance
            best_jd = candidate

    left = best_jd - coarse_step
    right = best_jd + coarse_step
    golden = (math.sqrt(5.0) - 1.0) / 2.0
    first = right - golden * (right - left)
    second = left + golden * (right - left)
    first_value = _angular_distance(_sidereal_ascendant(first, latitude, longitude), target_ascendant)
    second_value = _angular_distance(_sidereal_ascendant(second, latitude, longitude), target_ascendant)
    evaluations += 2
    for _ in range(64):
        if first_value <= second_value:
            right = second
            second = first
            second_value = first_value
            first = right - golden * (right - left)
            first_value = _angular_distance(
                _sidereal_ascendant(first, latitude, longitude), target_ascendant
            )
        else:
            left = first
            first = second
            first_value = second_value
            second = left + golden * (right - left)
            second_value = _angular_distance(
                _sidereal_ascendant(second, latitude, longitude), target_ascendant
            )
        evaluations += 1

    solved_jd = (left + right) / 2.0
    residual = _angular_distance(
        _sidereal_ascendant(solved_jd, latitude, longitude), target_ascendant
    )
    if residual > 1e-5:
        raise ValueError(f"KP Ascendant solve did not converge: residual={residual:.9f}°")
    return solved_jd, residual, evaluations


def _extract_cusps(raw_cusps: list[float]) -> list[float]:
    if len(raw_cusps) >= 13:
        result = [norm360(float(value)) for value in raw_cusps[1:13]]
    elif len(raw_cusps) == 12:
        result = [norm360(float(value)) for value in raw_cusps]
    else:
        raise ValueError(f"Swiss Ephemeris returned {len(raw_cusps)} Placidus cusps; expected 12")
    if len(result) != 12:
        raise ValueError("Placidus cusp extraction failed")
    return result


def _kp_planet_specs(node_mode: str) -> list[tuple[str, Any]]:
    node_id = "TRUE_NODE" if node_mode == "true" else "MEAN_NODE"
    south_id = "SOUTH_TRUE_NODE" if node_mode == "true" else "SOUTH_MEAN_NODE"
    body_ids = ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"]
    rows = [(body_id, BODY_REGISTRY[body_id]) for body_id in body_ids]
    rows.extend([("RAHU", BODY_REGISTRY[node_id]), ("KETU", BODY_REGISTRY[south_id])])
    return rows


def _planet_rows(
    question_jd: float,
    cusps: list[float],
    node_mode: str,
    warnings: list[str],
) -> list[dict[str, Any]]:
    spec_pairs = _kp_planet_specs(node_mode)
    calculated = calculate_positions(question_jd, [spec for _, spec in spec_pairs], warnings, sidereal=True)
    by_body_id = {row["body_id"]: row for row in calculated}
    result: list[dict[str, Any]] = []
    for kp_id, spec in spec_pairs:
        row = by_body_id.get(spec.body_id)
        if row is None:
            continue
        longitude = norm360(float(row["longitude"]))
        result.append(
            {
                "id": kp_id,
                "name": _planet_name(kp_id),
                **_position_identity(longitude),
                "house": house_for_longitude(longitude, cusps),
                "latitude": float(row["latitude"]),
                "declination": float(row["declination"]),
                "speed": float(row["speed"]),
                "retrograde": float(row["speed"]) < 0.0,
                "ephemeris": row.get("_ephemeris", "Swiss Ephemeris"),
            }
        )
    return result


def _house_rows(cusps: list[float]) -> list[dict[str, Any]]:
    return [
        {
            "house": index,
            **_position_identity(cusp),
        }
        for index, cusp in enumerate(cusps, start=1)
    ]


def _angle_rows(ascmc: list[float]) -> list[dict[str, Any]]:
    asc = norm360(float(ascmc[0]))
    mc = norm360(float(ascmc[1]))
    values = [("ASC", "上升", asc), ("MC", "天顶", mc), ("DSC", "下降", asc + 180.0), ("IC", "天底", mc + 180.0)]
    return [{"id": angle_id, "name": name, **_position_identity(value)} for angle_id, name, value in values]


def _scope_for_planet(
    planet_id: str,
    planet_by_id: dict[str, dict[str, Any]],
    owned_houses: dict[str, list[int]],
) -> dict[str, Any]:
    planet = planet_by_id.get(planet_id)
    return {
        "planet": _lord_row(planet_id),
        "occupied_house": planet.get("house") if planet else None,
        "owned_houses": owned_houses.get(planet_id, []),
    }


def _significators(
    planets: list[dict[str, Any]],
    houses: list[dict[str, Any]],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    planet_by_id = {row["id"]: row for row in planets}
    owned_houses: dict[str, list[int]] = {planet_id: [] for planet_id in KP_PLANET_ORDER}
    occupants: dict[int, list[str]] = {house: [] for house in range(1, 13)}
    for house in houses:
        owned_houses.setdefault(house["sign_lord"]["id"], []).append(house["house"])
    for planet in planets:
        occupants[planet["house"]].append(planet["id"])

    planet_rows: list[dict[str, Any]] = []
    for planet in planets:
        star_lord = planet["nakshatra"]["lord"]["id"]
        sub_lord = planet["sub_lord"]["id"]
        direct = _scope_for_planet(planet["id"], planet_by_id, owned_houses)
        star_scope = _scope_for_planet(star_lord, planet_by_id, owned_houses)
        sub_scope = _scope_for_planet(sub_lord, planet_by_id, owned_houses)
        candidate_houses = sorted(
            {
                value
                for scope in (direct, star_scope, sub_scope)
                for value in ([scope["occupied_house"]] + scope["owned_houses"])
                if value is not None
            }
        )
        planet_rows.append(
            {
                "planet": _lord_row(planet["id"]),
                "direct": direct,
                "star_lord_scope": star_scope,
                "sub_lord_scope": sub_scope,
                "candidate_houses": candidate_houses,
                "policy": "transparent_sources_no_weighting",
            }
        )

    order = {planet_id: index for index, planet_id in enumerate(KP_PLANET_ORDER)}
    house_rows: list[dict[str, Any]] = []
    for house in houses:
        number = house["house"]
        occupant_ids = occupants[number]
        sign_lord = house["sign_lord"]["id"]
        stars_of_occupants = [
            planet["id"]
            for planet in planets
            if planet["nakshatra"]["lord"]["id"] in occupant_ids
        ]
        stars_of_sign_lord = [
            planet["id"]
            for planet in planets
            if planet["nakshatra"]["lord"]["id"] == sign_lord
        ]

        def lord_rows(ids: list[str]) -> list[dict[str, str]]:
            return [_lord_row(value) for value in sorted(set(ids), key=lambda value: order.get(value, 99))]

        house_rows.append(
            {
                "house": number,
                "cusp_sign_lord": _lord_row(sign_lord),
                "tiers": [
                    {"tier": 1, "source": "planets_in_stars_of_occupants", "planets": lord_rows(stars_of_occupants)},
                    {"tier": 2, "source": "occupants", "planets": lord_rows(occupant_ids)},
                    {"tier": 3, "source": "planets_in_stars_of_cusp_sign_lord", "planets": lord_rows(stars_of_sign_lord)},
                    {"tier": 4, "source": "cusp_sign_lord", "planets": lord_rows([sign_lord])},
                ],
                "policy": "candidate_tiers_no_automatic_verdict",
            }
        )
    return planet_rows, house_rows


def _node_representations(planets: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for node_id in ("RAHU", "KETU"):
        node = next((planet for planet in planets if planet["id"] == node_id), None)
        if node is None:
            continue
        rows.append(
            {
                "node": _lord_row(node_id),
                "occupied_house": node["house"],
                "sign_lord": node["sign_lord"],
                "star_lord": node["nakshatra"]["lord"],
                "sub_lord": {key: node["sub_lord"][key] for key in ("id", "name")},
                "policy": "direct_connections_only_no_conjunction_or_aspect_inference",
            }
        )
    return rows


def calculate_kp_horary(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    chart = request["chart"]
    moment = chart["moment"]
    latitude = float(chart["latitude"])
    longitude = float(chart["longitude"])
    number = int(request["horary_number"])
    focus_house = int(request.get("focus_house", 1))
    node_mode = str(request.get("node_mode", "mean")).strip().lower()
    if not 1 <= number <= 249:
        raise ValueError("horary_number must be an integer in [1, 249]")
    if not 1 <= focus_house <= 12:
        raise ValueError("focus_house must be an integer in [1, 12]")
    if node_mode not in {"mean", "true"}:
        raise ValueError("node_mode must be mean or true")

    local_dt = moment_to_local_datetime(moment)
    question_jd = jd_from_datetime(local_dt)
    set_zodiac_mode(KP_ZODIAC, warnings)

    segment = _KP_NUMBER_SEGMENTS[number - 1]
    width = segment["end"] - segment["start"]
    interior_offset = width / 2.0
    representative_longitude = norm360(segment["start"] + interior_offset)

    solved_jd, residual, evaluations = _solve_house_reference_jd(
        question_jd, latitude, longitude, representative_longitude
    )
    raw_cusps, ascmc = call_houses_ex(solved_jd, latitude, longitude, "P", True)
    cusps = _extract_cusps(raw_cusps)
    solved_asc = norm360(float(ascmc[0]))
    solved_utc = local_dt.astimezone(timezone.utc) + timedelta(days=solved_jd - question_jd)

    planets = _planet_rows(question_jd, cusps, node_mode, warnings)
    houses = _house_rows(cusps)
    angles = _angle_rows(ascmc)
    planet_significators, house_significators = _significators(planets, houses)
    focus = next(row for row in house_significators if row["house"] == focus_house)
    asc_identity = _position_identity(solved_asc)
    moon = next(planet for planet in planets if planet["id"] == "MOON")
    weekday_lord = WEEKDAY_LORDS[local_dt.weekday()]

    return {
        "mode": "kp_horary",
        "schema": {
            "name": "kp-horary-data-packet",
            "version": "1.0",
            "schema_id": SCHEMA_ID,
        },
        "question": {
            "text": str(request.get("question_text", "")).strip(),
            "horary_number": number,
            "focus_house": focus_house,
            "place_name": str(request.get("place_name", "")).strip(),
        },
        "time_and_location": {
            "question_local": local_dt.isoformat(),
            "question_utc": local_dt.astimezone(timezone.utc).isoformat(),
            "house_solution_utc": solved_utc.isoformat(),
            "timezone": str(moment["timezone"]),
            "latitude": latitude,
            "longitude": longitude,
        },
        "calculation_config": {
            "zodiac": KP_ZODIAC,
            "ayanamsha": "Krishnamurti",
            "ayanamsha_degrees_at_question": float(swe.get_ayanamsa_ut(question_jd)),
            "house_system": KP_HOUSE_SYSTEM,
            "node_mode": node_mode,
            "planet_time_policy": "question_time",
            "house_time_policy": "number_selected_ascendant_with_question_time_planets",
            "number_longitude_policy": "segment_midpoint",
            "automatic_judgment": False,
        },
        "horary_number": {
            "number": number,
            "interval_start_longitude": segment["start"],
            "interval_end_longitude": segment["end"],
            "representative_longitude": representative_longitude,
            "interior_offset_degrees": interior_offset,
            **_position_identity(representative_longitude),
        },
        "house_solution": {
            "target_ascendant": representative_longitude,
            "solved_ascendant": solved_asc,
            "residual_degrees": residual,
            "evaluations": evaluations,
            "search_window_days": 1.1,
        },
        "angles": angles,
        "planets": planets,
        "houses": houses,
        "ruling_planets": [
            {"source": "ascendant_sign_lord", "planet": asc_identity["sign_lord"]},
            {"source": "ascendant_star_lord", "planet": asc_identity["nakshatra"]["lord"]},
            {"source": "ascendant_sub_lord", "planet": {key: asc_identity["sub_lord"][key] for key in ("id", "name")}},
            {"source": "moon_sign_lord", "planet": moon["sign_lord"]},
            {"source": "moon_star_lord", "planet": moon["nakshatra"]["lord"]},
            {"source": "moon_sub_lord", "planet": {key: moon["sub_lord"][key] for key in ("id", "name")}},
            {"source": "local_weekday_lord", "planet": _lord_row(weekday_lord)},
        ],
        "planet_significators": planet_significators,
        "house_significators": house_significators,
        "focus_house": focus,
        "node_representations": _node_representations(planets),
        "warnings": warnings,
    }
