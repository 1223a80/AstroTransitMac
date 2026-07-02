"""Medieval astrological deepening for TransitStudio.

Implements:
1. Triplicity Rulers of the Sect Light
2. Kurios / Oikodespotes (Lord of the Nativity)
3. Profection + Solar Return synthesis
4. Monthly profection enhancement

See ``docs/expansion-002/medieval-deepening.md`` for the full specification.
"""
from __future__ import annotations

from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
    SIGNS,
    SIGN_RULERS,
    format_longitude,
    norm360,
    obliquity,
    planet_name,
    zodiac_sign_index,
)
from astro_backend_classical_dignity import (
    SIGN_ELEMENTS,
    TRIPLICITY_RULERS,
    dignity_rulers_for_lon,
    triplicity_ruler_details,
)
from astro_backend_classical import (
    PLANETARY_YEARS,
    house_strength,
    motion_label,
    sect_status,
    solar_phase,
)

_HOUSE_LABELS = ["", "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th", "11th", "12th"]

# ---------------------------------------------------------------------------
# 1. Triplicity Rulers of the Sect Light
# ---------------------------------------------------------------------------


def sect_light_triplicity_rulers(
    sun_lon: float,
    moon_lon: float,
    is_day: bool,
    asc_lon: float,
    planet_rows: list[dict[str, Any]],
    triplicity_system: str = "dorothean",
    positions_by_id: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Compute the triplicity rulers of the Sect Light.

    Day charts: the Sect Light is the Sun (light of the sect);
    Night charts: the Sect Light is the Moon.

    Returns a dict with the sect light's sign, its triplicity ruler sequence,
    and each ruler's natal condition.
    """
    light_lon = sun_lon if is_day else moon_lon
    light_name = "Sun" if is_day else "Moon"
    light_id = "SUN" if is_day else "MOON"
    sign_idx = zodiac_sign_index(light_lon)
    sign_name = SIGNS[sign_idx]

    # Get triplicity ruler IDs for that sign
    system = triplicity_system if triplicity_system in TRIPLICITY_RULERS else "dorothean"
    elem = SIGN_ELEMENTS[sign_idx]  # "fire", "earth", "air", or "water"
    day_ruler, night_ruler, participating = TRIPLICITY_RULERS[system][elem]

    # The active order: 1st = day ruler (day chart) or night ruler (night chart)
    first_ruler_id = day_ruler if is_day else night_ruler
    second_ruler_id = night_ruler if is_day else day_ruler
    third_ruler_id = participating

    rulers_info = []
    position_lookup = {r["id"]: r for r in planet_rows} if not positions_by_id else positions_by_id

    for idx, ruler_id in enumerate([first_ruler_id, second_ruler_id, third_ruler_id]):
        rank = idx + 1
        row = position_lookup.get(ruler_id, {})
        rulers_info.append({
            "planet": ruler_id,
            "planet_name": planet_name(ruler_id),
            "rank": rank,
            "label": "first" if rank == 1 else "second" if rank == 2 else "participating",
            "house": row.get("house", 0),
            "score": row.get("score", 0),
            "score_label": row.get("score_label", ""),
            "angular": row.get("accidental", "") in ("角宫", "Angular"),
        })

    return {
        "sect_light": light_id,
        "sect_light_name": light_name,
        "light_sign": sign_name,
        "light_sign_index": sign_idx,
        "light_longitude": round(light_lon, 4),
        "triplicity_system": triplicity_system,
        "rulers": rulers_info,
    }


# ---------------------------------------------------------------------------
# 2. Kurios / Oikodespotes (Lord of the Nativity)
# ---------------------------------------------------------------------------


def determine_kurios(
    asc_lon: float,
    is_day: bool,
    light_triplicity: dict[str, Any] | None,
    almuten: dict[str, Any] | None,
    profection_lord_id: str | None,
    planet_rows: list[dict[str, Any]],
    positions_by_id: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Determine the Kurios (Lord of the Nativity) using a weighted scoring system.

    Candidate sources and their base weights:
    - ASC Domicile Ruler: 5
    - 1st Triplicity Ruler of Sect Light: 4
    - Almuten Figuris winner: 3
    - 2nd Triplicity Ruler of Sect Light: 2
    - Profection Lord (yearly only): 1
    """
    position_lookup = {r["id"]: r for r in planet_rows} if not positions_by_id else positions_by_id

    # Candidates: (planet_id, role, base_weight)
    candidates: list[tuple[str, str, int]] = []

    # 1. ASC ruler
    asc_sign_idx = zodiac_sign_index(asc_lon)
    asc_ruler_id = SIGN_RULERS[asc_sign_idx]
    candidates.append((asc_ruler_id, "ASC Ruler", 5))

    # 2. Triplicity ruler(s) of sect light
    if light_triplicity and light_triplicity.get("rulers"):
        for r in light_triplicity["rulers"]:
            w = 4 if r["rank"] == 1 else 2
            candidates.append((r["planet"], f"{r['label'].capitalize()} Triplicity Ruler", w))

    # 3. Almuten Figuris
    if almuten and almuten.get("winner_id"):
        winner_id = almuten["winner_id"]
        if winner_id in BODY_REGISTRY:
            candidates.append((winner_id, "Almuten Figuris", 3))

    # 4. Profection Lord
    if profection_lord_id and profection_lord_id in BODY_REGISTRY:
        candidates.append((profection_lord_id, "Profection Lord", 1))

    # Remove duplicates, keeping highest weight
    seen: dict[str, tuple[str, str, int]] = {}
    for pid, role, weight in candidates:
        if pid not in seen or weight > seen[pid][2]:
            seen[pid] = (pid, role, weight)

    unique_candidates = list(seen.values())

    # Score each candidate
    scored: list[dict[str, Any]] = []
    for pid, role, base_weight in unique_candidates:
        row = position_lookup.get(pid, {})
        modifier = 0
        modifiers: list[str] = []

        # Angular
        acc = row.get("accidental", "")
        if acc in ("角宫", "Angular"):
            modifier += 3
            modifiers.append("角宫 +3")
        elif acc in ("续宫", "Succedent"):
            modifier += 1
            modifiers.append("续宫 +1")
        else:
            modifier -= 2
            modifiers.append("果宫 -2")

        # Score from dignity system
        score = row.get("score", 0)
        modifier += max(-5, min(score, 5))  # Cap to ±5
        modifiers.append(f"score {score}")

        # House
        house = row.get("house", 0)
        if house in (1, 10):
            modifier += 2
            modifiers.append("角宫主 +2")

        total = base_weight + modifier
        scored.append({
            "planet": pid,
            "planet_name": planet_name(pid),
            "role": role,
            "base_weight": base_weight,
            "modifier": modifier,
            "score": total,
            "modifiers": modifiers,
            "natal_house": row.get("house", 0),
            "natal_score_label": row.get("score_label", ""),
        })

    scored.sort(key=lambda x: -x["score"])

    result: dict[str, Any] = {
        "method": "compound_weighted",
        "primary": None,
        "candidates": scored,
    }
    if scored:
        result["primary"] = {
            "planet": scored[0]["planet"],
            "planet_name": scored[0]["planet_name"],
            "score": scored[0]["score"],
            "role": scored[0]["role"],
            "natal_house": scored[0]["natal_house"],
            "natal_score_label": scored[0]["natal_score_label"],
        }

    return result


# ---------------------------------------------------------------------------
# 3. Profection + Solar Return synthesis
# ---------------------------------------------------------------------------


def profection_solar_return_synthesis(
    profection: dict[str, Any],
    solar_return_snapshot: dict[str, Any],
    asc_lon: float,
    planet_rows: list[dict[str, Any]],
    is_day: bool,
    natal_planet_rows: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Synthesize the Profection Lord of the Year with the Solar Return chart.

    Args:
        profection: result from profection_summary()
        solar_return_snapshot: classical_snapshot() of the current solar return
        asc_lon: natal ASC longitude
        planet_rows: natal planet rows from classical_snapshot()

    Returns a structured synthesis with:
    - profection ASC sign vs SR ASC sign match
    - Lord of the Year in the SR chart (house, dignity, aspects)
    - SR highlights (ASC ruler, MC ruler, stellium house)
    - Generated summary text
    """
    # Profection data
    prof_asc_idx = zodiac_sign_index(profection.get("profected_asc_longitude", asc_lon))
    prof_asc_sign = SIGNS[prof_asc_idx]
    lord_id = profection.get("lordId", "")
    lord_name = profection.get("lord", "")

    # Solar return data
    sr_asc_lon = 0.0
    sr_planets = []
    for angle in solar_return_snapshot.get("angles", []):
        if angle.get("id") == "ASC":
            sr_asc_lon = angle["longitude"]
    sr_asc_idx = zodiac_sign_index(sr_asc_lon)
    sr_asc_sign = SIGNS[sr_asc_idx]
    sr_planet_rows = solar_return_snapshot.get("planets", [])

    asc_matches = (prof_asc_idx == sr_asc_idx)

    # Lord of the Year in SR chart
    lord_in_sr: dict[str, Any] = {"present": False}
    for p in sr_planet_rows:
        if p.get("id") == lord_id or p.get("name") == lord_name:
            house = p.get("house", 0)
            lord_in_sr = {
                "present": True,
                "planet": lord_id,
                "planet_name": lord_name,
                "house": house,
                "house_label": _HOUSE_LABELS[house] if 0 <= house <= 12 else "",
                "sign": p.get("sign", ""),
                "score": p.get("score", 0),
                "score_label": p.get("score_label", ""),
                "retrograde": p.get("motion", "").startswith("逆"),
                "angular": p.get("accidental", "") in ("角宫", "Angular"),
            }
            break

    # SR highlights
    sr_asc_ruler_id = SIGN_RULERS[sr_asc_idx]
    sr_mc_house = 10  # Whole Sign MC = 10th house
    sr_mc_sign_idx = (sr_asc_idx + 9) % 12  # MC = ASC + 9 signs in Whole Sign
    sr_mc_ruler_id = SIGN_RULERS[sr_mc_sign_idx]

    # Find stellium (3+ planets in same sign) in SR
    sr_sign_counts: dict[str, int] = {}
    for p in sr_planet_rows:
        sg = p.get("sign", "")
        sr_sign_counts[sg] = sr_sign_counts.get(sg, 0) + 1
    stellium_sign = None
    for sg, cnt in sr_sign_counts.items():
        if cnt >= 3:
            stellium_sign = sg
            break

    sr_highlights = {
        "asc_ruler": planet_name(sr_asc_ruler_id),
        "asc_ruler_house": 1,
        "mc_ruler": planet_name(sr_mc_ruler_id),
        "mc_ruler_house": 10,
        "stellium_sign": stellium_sign,
    }

    # Summary text
    summary_parts: list[str] = []
    if asc_matches:
        summary_parts.append(f"小限ASC（{prof_asc_sign}）与返照ASC（{sr_asc_sign}）一致，年内主题高度聚焦。")
    else:
        summary_parts.append(f"小限在{prof_asc_sign}，返照ASC在{sr_asc_sign}，关注领域在两者之间平衡。")

    if lord_in_sr.get("present"):
        lh = lord_in_sr.get("house", 0)
        lh_label = lord_in_sr.get("house_label", f"{lh}")
        status = "强旺" if lord_in_sr.get("score", 0) >= 10 else "尚可" if lord_in_sr.get("score", 0) >= 5 else "受克"
        retro = "，逆行小心反复" if lord_in_sr.get("retrograde") else ""
        summary_parts.append(f"年主{lord_name}在返照盘第{lh_label}宫，状态{status}{retro}。")

    if stellium_sign:
        summary_parts.append(f"返照盘{stellium_sign}有星群聚集，该星座领域为本年重点。")

    return {
        "profection_asc_sign": prof_asc_sign,
        "solar_return_asc_sign": sr_asc_sign,
        "asc_signs_match": asc_matches,
        "lord_of_year_in_sr": lord_in_sr,
        "sr_highlights": sr_highlights,
        "summary_text": "".join(summary_parts) if summary_parts else ""
    }
