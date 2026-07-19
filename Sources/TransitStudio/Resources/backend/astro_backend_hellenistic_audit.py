"""Hellenistic planetary condition audit (evidence rows, not luck scores).

mode=hellenistic_condition_audit
"""

from __future__ import annotations

from typing import Any

from astro_backend_classical import classical_snapshot
from astro_backend_core import (
    CLASSICAL_BODY_IDS,
    SIGNS,
    SIGN_RULERS,
    angular_separation,
    moment_to_jd,
    moment_to_local_datetime,
    norm360,
    set_zodiac_mode,
    signed_orb,
    zodiac_sign_index,
)
from astro_backend_classical_dignity import EXALTATION_RULERS, hayz_status, sect_status, solar_phase

METHOD = "hellenistic_condition_audit_v1"
SCHEMA_VERSION = 1
SOURCE_PROFILE = "hellenistic_audit_v1_dorothean_sect_and_geometry"

# Superior planets (heliocentric outer relative to Earth): Mars+ outward.
SUPERIOR = {"MARS", "JUPITER", "SATURN"}
INFERIOR = {"MERCURY", "VENUS"}
BENEFIC = {"VENUS", "JUPITER"}
MALEFIC = {"MARS", "SATURN"}


def _row(
    condition_id: str,
    subject: str,
    actors: list[str],
    geometry: str,
    applying: str | None,
    orb: float | None,
    evidence: list[str],
    **extra: Any,
) -> dict[str, Any]:
    return {
        "condition_id": condition_id,
        "subject": subject,
        "actors": actors,
        "geometry": geometry,
        "applying_separating": applying,
        "orb": round(orb, 6) if orb is not None else None,
        "source_profile": SOURCE_PROFILE,
        "evidence": evidence,
        "method_key": METHOD,
        **extra,
    }


def _is_oriental(body_lon: float, sun_lon: float) -> bool:
    # Rising before Sun in diurnal motion: body is west of Sun in zodiac sense
    # commonly: body rises before Sun when it is behind Sun in zodiac for morning.
    # Project convention from sect_status Mercury: oriental if (sun - body) mod 360 < 180.
    return norm360(sun_lon - body_lon) < 180.0


def _house_for(lon: float, cusps: list[float]) -> int:
    from astro_backend_ephemeris import house_for_longitude

    return house_for_longitude(lon, cusps)


def _overcoming(lon_a: float, lon_b: float) -> bool:
    """A overcomes B if A is in a sign that is a dexter square/trine to B (right side).

    Simplified Hellenistic: earlier in the diurnal order from B by 90° (right-hand).
    Using whole-sign: A is 10th from B (overcoming by square) or trine positions.
    Here: whole-sign tenth from B overcomes B.
    """
    sign_a = zodiac_sign_index(lon_a)
    sign_b = zodiac_sign_index(lon_b)
    tenth = (sign_b + 9) % 12  # 10th whole-sign from B
    return sign_a == tenth


def _body_id(row: dict[str, Any]) -> str:
    return str(row.get("id") or row.get("body_id") or "")


def _enclosure(
    subject_lon: float,
    bodies: list[dict[str, Any]],
    subject_id: str,
) -> tuple[bool, list[str], float | None]:
    """Besiegement: subject between two malefics without a benefic intervening (longitude order)."""
    lons = [(float(b["longitude"]), _body_id(b)) for b in bodies if _body_id(b)]
    if len(lons) < 3:
        return False, [], None
    lons_sorted = sorted(lons, key=lambda x: x[0])
    n = len(lons_sorted)
    try:
        idx = next(i for i, (_lon, bid) in enumerate(lons_sorted) if bid == subject_id)
    except StopIteration:
        return False, [], None
    prev_lon, prev_id = lons_sorted[(idx - 1) % n]
    next_lon, next_id = lons_sorted[(idx + 1) % n]
    if prev_id in MALEFIC and next_id in MALEFIC:
        span = abs(signed_orb(next_lon, prev_lon))
        return True, [prev_id, next_id], span
    return False, [], None


def calculate_hellenistic_condition_audit(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    for field in ("latitude", "longitude"):
        if field not in birth:
            raise ValueError(f"birth.{field} is required")
    moment = birth["moment"]
    jd, birth_utc = moment_to_jd(moment)
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)
    house_system = birth.get("houseSystem", birth.get("house_system", "whole_sign"))
    bounds = birth.get("boundsSystem", birth.get("bounds_system", "egyptian"))
    triplicity = birth.get("triplicitySystem", birth.get("triplicity_system", "dorothean"))
    aspect_orb = float(request.get("aspect_orb", request.get("aspectOrb", 3.0)))
    profile = str(request.get("source_profile") or SOURCE_PROFILE)

    snap = classical_snapshot(
        jd,
        float(birth["latitude"]),
        float(birth["longitude"]),
        house_system,
        sidereal,
        bounds,
        triplicity,
        aspect_orb,
        warnings,
    )
    planets = snap["planets"]
    by_id = {_body_id(p): p for p in planets if _body_id(p)}
    sun = by_id.get("SUN")
    if sun is None:
        raise RuntimeError("SUN missing from classical snapshot")
    sun_lon = float(sun["longitude"])
    is_day = bool(snap["is_day"])
    cusps = [float(h["cusp_longitude"]) for h in snap["houses"]]

    conditions: list[dict[str, Any]] = []
    section_errors: dict[str, str] = {}

    try:
        for body_id in CLASSICAL_BODY_IDS:
            row = by_id.get(body_id)
            if row is None:
                continue
            lon = float(row["longitude"])
            house = int(row.get("house") or _house_for(lon, cusps))
            name = str(row.get("name") or body_id)

            # oriental / occidental (all planets vs Sun; Moon too)
            if body_id != "SUN":
                oriental = _is_oriental(lon, sun_lon)
                conditions.append(
                    _row(
                        "oriental_occidental",
                        body_id,
                        ["SUN"],
                        f"{'oriental' if oriental else 'occidental'} to Sun",
                        None,
                        angular_separation(lon, sun_lon),
                        [
                            f"{name} is {'oriental (rises before Sun)' if oriental else 'occidental (sets after Sun)'}",
                            f"sun_lon={sun_lon:.4f} body_lon={lon:.4f}",
                        ],
                        value="oriental" if oriental else "occidental",
                    )
                )

            # superior / inferior relationship label
            if body_id in SUPERIOR:
                conditions.append(
                    _row(
                        "superior_planet",
                        body_id,
                        [],
                        "heliocentric_class=superior",
                        None,
                        None,
                        [f"{name} is a superior planet (Mars–Saturn class)"],
                        value="superior",
                    )
                )
            elif body_id in INFERIOR:
                conditions.append(
                    _row(
                        "inferior_planet",
                        body_id,
                        [],
                        "heliocentric_class=inferior",
                        None,
                        None,
                        [f"{name} is an inferior planet (Mercury/Venus class)"],
                        value="inferior",
                    )
                )

            # sect / hayz evidence (reuse existing helpers)
            sect_label, _, _, sect_trace = sect_status(body_id, is_day, lon, sun_lon, house)
            conditions.append(
                _row(
                    "sect_agreement",
                    body_id,
                    [],
                    f"chart_sect={'day' if is_day else 'night'}",
                    None,
                    None,
                    [f"sect_label={sect_label}", f"trace={sect_trace}"],
                    value=sect_label,
                    trace=sect_trace,
                )
            )
            hayz_label, _, _, hayz_trace = hayz_status(body_id, is_day, lon, house, sun_lon)
            if hayz_label:
                conditions.append(
                    _row(
                        "hayz",
                        body_id,
                        [],
                        "hayz",
                        None,
                        None,
                        [f"hayz active for {name}", f"trace={hayz_trace.get('trace', hayz_trace)}"],
                        value="hayz",
                        trace=hayz_trace,
                    )
                )

            # solar phase
            if body_id != "SUN":
                phase_label, _, _, phase_trace = solar_phase(body_id, lon, sun_lon)
                conditions.append(
                    _row(
                        "solar_phase",
                        body_id,
                        ["SUN"],
                        phase_trace.get("solar_condition", phase_label),
                        None,
                        phase_trace.get("sun_distance_deg"),
                        [f"solar_phase={phase_label}", f"distance={phase_trace.get('sun_distance_deg')}°"],
                        value=phase_trace.get("solar_condition"),
                        trace=phase_trace,
                    )
                )

            # angularity
            angular = house in {1, 4, 7, 10}
            succeedent = house in {2, 5, 8, 11}
            cadent = house in {3, 6, 9, 12}
            conditions.append(
                _row(
                    "angularity",
                    body_id,
                    [],
                    f"house={house}",
                    None,
                    None,
                    [
                        f"house={house}",
                        "angular" if angular else ("succeedent" if succeedent else "cadent"),
                    ],
                    value="angular" if angular else ("succeedent" if succeedent else "cadent"),
                    house=house,
                )
            )

            # overcoming (others overcome subject or subject overcomes others)
            for other_id, other in by_id.items():
                if other_id == body_id:
                    continue
                other_lon = float(other["longitude"])
                if _overcoming(lon, other_lon):
                    conditions.append(
                        _row(
                            "overcoming",
                            body_id,
                            [other_id],
                            "whole_sign_10th_from_object",
                            None,
                            abs(signed_orb(lon, other_lon)),
                            [
                                f"{name} is in the 10th whole sign from {other.get('name', other_id)}",
                                "subject overcomes object (dexter configuration proxy)",
                            ],
                        )
                    )
                if _overcoming(other_lon, lon):
                    conditions.append(
                        _row(
                            "being_overcome",
                            body_id,
                            [other_id],
                            "whole_sign_10th_from_subject",
                            None,
                            abs(signed_orb(lon, other_lon)),
                            [
                                f"{other.get('name', other_id)} is in the 10th whole sign from {name}",
                                "subject is overcome",
                            ],
                        )
                    )

            # enclosure / besiegement by malefics
            enclosed, actors, span = _enclosure(lon, list(by_id.values()), body_id)
            if enclosed:
                conditions.append(
                    _row(
                        "enclosure_besiegement",
                        body_id,
                        actors,
                        "between_two_malefics_by_longitude",
                        None,
                        span,
                        [
                            f"{name} is between malefics {actors}",
                            "no intervening-body check beyond nearest neighbors",
                        ],
                    )
                )

            # bonification / maltreatment proxies (evidence only)
            dig_bits = [
                label
                for label, flag in (
                    ("domicile", row.get("domicile")),
                    ("exaltation", row.get("exaltation")),
                    ("triplicity", row.get("triplicity")),
                    ("bound", row.get("bound")),
                    ("decan", row.get("decan")),
                )
                if flag
            ]
            if dig_bits:
                conditions.append(
                    _row(
                        "essential_dignity_present",
                        body_id,
                        [],
                        "essential_dignity",
                        None,
                        None,
                        [f"dignities={dig_bits}"],
                        value=",".join(str(x) for x in dig_bits),
                    )
                )

            # chariot proxy: planet in domicile or exaltation and not combust
            sign_idx = zodiac_sign_index(lon)
            domicile = SIGN_RULERS[sign_idx] == body_id
            exalt = EXALTATION_RULERS.get(sign_idx) == body_id
            phase_label, _, _, phase_trace = solar_phase(body_id, lon, sun_lon) if body_id != "SUN" else ("-", 0, [], {"solar_condition": "-"})
            if (domicile or exalt) and phase_trace.get("solar_condition") not in {"combust", "under_beams"}:
                conditions.append(
                    _row(
                        "chariot_proxy",
                        body_id,
                        [],
                        "domicile_or_exaltation_and_not_combust",
                        None,
                        None,
                        [
                            f"domicile={domicile}",
                            f"exaltation={exalt}",
                            f"solar_condition={phase_trace.get('solar_condition')}",
                            "chariot-like protection proxy (not full Hellenistic chariot definition set)",
                        ],
                        value="chariot_proxy",
                    )
                )

            # applying assistance / separating testimony from classical aspects if present
            for aspect in snap.get("aspects") or []:
                a1 = aspect.get("body1") or aspect.get("body_a") or aspect.get("transit_body_id")
                a2 = aspect.get("body2") or aspect.get("body_b") or aspect.get("target_name")
                # classical aspects shape may use different keys
                left = aspect.get("a") or aspect.get("body_a_id") or aspect.get("p1")
                right = aspect.get("b") or aspect.get("body_b_id") or aspect.get("p2")
                bodies_pair = {a1, a2, left, right}
                if body_id not in bodies_pair:
                    continue
                applying = aspect.get("applying") or aspect.get("application")
                if applying is True or applying == "applying":
                    conditions.append(
                        _row(
                            "applying_aspect",
                            body_id,
                            [str(x) for x in bodies_pair if x and x != body_id],
                            str(aspect.get("type") or aspect.get("aspect") or aspect.get("aspect_name") or "aspect"),
                            "applying",
                            aspect.get("orb") or aspect.get("exact_orb"),
                            [f"aspect={aspect}"],
                        )
                    )
                elif applying is False or applying == "separating":
                    conditions.append(
                        _row(
                            "separating_aspect",
                            body_id,
                            [str(x) for x in bodies_pair if x and x != body_id],
                            str(aspect.get("type") or aspect.get("aspect") or aspect.get("aspect_name") or "aspect"),
                            "separating",
                            aspect.get("orb") or aspect.get("exact_orb"),
                            [f"aspect={aspect}"],
                        )
                    )

    except Exception as exc:
        section_errors["conditions"] = str(exc)
        warnings.append(f"条件审计部分失败：{exc}")

    # Deduplicate nearly identical rows
    seen: set[str] = set()
    unique: list[dict[str, Any]] = []
    for c in conditions:
        key = f"{c['condition_id']}|{c['subject']}|{','.join(c['actors'])}|{c['geometry']}"
        if key in seen:
            continue
        seen.add(key)
        unique.append(c)

    assumptions = [
        "输出为可审计证据行，不合成吉/凶分数。",
        f"source_profile={profile}",
        "oriental/occidental 使用 (sun_lon - body_lon) mod 360 < 180 判定。",
        "overcoming 使用 whole-sign 第 10 宫关系代理。",
        "enclosure 使用经度排序最近两颗邻居均为凶星的代理，不做完整射线 enclosure。",
        "chariot 为 domicile/exaltation 且非燃烧的简化代理，非完整传统定义集。",
        "sect/hayz/solar_phase 复用现有 classical_dignity 实现。",
    ]

    return {
        "meta": {
            "mode": "hellenistic_condition_audit",
            "method": METHOD,
            "schema_version": SCHEMA_VERSION,
            "source_profile": profile,
            "birth_utc": birth_utc,
            "is_day": is_day,
            "zodiac": zodiac,
            "house_system": house_system,
            "condition_count": len(unique),
            "ephemeris": "Swiss Ephemeris",
        },
        "requested_config": {
            "source_profile": request.get("source_profile"),
            "aspect_orb": request.get("aspect_orb", request.get("aspectOrb")),
            "zodiac": zodiac,
        },
        "effective_config": {
            "source_profile": profile,
            "aspect_orb": aspect_orb,
            "zodiac": zodiac,
            "house_system": house_system,
            "bounds_system": bounds,
            "triplicity_system": triplicity,
            "method": METHOD,
        },
        "conditions": unique,
        "planets_summary": [
            {
                "body_id": p.get("id") or p.get("body_id"),
                "name": p.get("name"),
                "longitude": p.get("longitude"),
                "house": p.get("house"),
                "speed": p.get("speed"),
            }
            for p in planets
        ],
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": section_errors or None,
        "calculation_assumptions": assumptions,
    }


__all__ = ["calculate_hellenistic_condition_audit", "METHOD"]
