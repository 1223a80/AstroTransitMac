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

    ordered_rulers = [
        ruler_id for ruler_id in [first_ruler_id, second_ruler_id, third_ruler_id]
        if ruler_id
    ]
    for idx, ruler_id in enumerate(ordered_rulers):
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


def _score_governor_candidates(
    candidates: list[tuple[str, str, int]],
    planet_rows: list[dict[str, Any]],
    positions_by_id: dict[str, dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    position_lookup = {r["id"]: r for r in planet_rows} if not positions_by_id else positions_by_id
    seen: dict[str, tuple[str, str, int]] = {}
    for pid, role, weight in candidates:
        if pid not in seen or weight > seen[pid][2]:
            seen[pid] = (pid, role, weight)
    scored: list[dict[str, Any]] = []
    for pid, role, base_weight in seen.values():
        row = position_lookup.get(pid, {})
        modifier = 0
        modifiers: list[str] = []
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
        score = row.get("score", 0)
        modifier += max(-5, min(score, 5))
        modifiers.append(f"score {score}")
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
    return scored


def determine_oikodespotes(
    asc_lon: float,
    planet_rows: list[dict[str, Any]],
    positions_by_id: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Natal house-master (ASC domicile ruler) — permanent natal fact."""
    asc_sign_idx = zodiac_sign_index(asc_lon)
    asc_ruler_id = SIGN_RULERS[asc_sign_idx]
    scored = _score_governor_candidates(
        [(asc_ruler_id, "ASC Domicile Ruler / Oikodespotes", 5)],
        planet_rows,
        positions_by_id,
    )
    primary = scored[0] if scored else None
    return {
        "module": "natal_oikodespotes",
        "method": "asc_domicile_ruler",
        "primary": {
            "planet": primary["planet"],
            "planet_name": primary["planet_name"],
            "score": primary["score"],
            "role": primary["role"],
            "natal_house": primary["natal_house"],
            "natal_score_label": primary["natal_score_label"],
        } if primary else None,
        "candidates": scored,
        "note": "Oikodespotes = ASC domicile ruler (natal permanent).",
    }


def determine_natal_kurios(
    asc_lon: float,
    light_triplicity: dict[str, Any] | None,
    almuten: dict[str, Any] | None,
    planet_rows: list[dict[str, Any]],
    positions_by_id: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Natal Kurios candidates from permanent dignities only (no profection year lord)."""
    candidates: list[tuple[str, str, int]] = []
    asc_sign_idx = zodiac_sign_index(asc_lon)
    candidates.append((SIGN_RULERS[asc_sign_idx], "ASC Ruler", 5))
    if light_triplicity and light_triplicity.get("rulers"):
        for r in light_triplicity["rulers"]:
            w = 4 if r["rank"] == 1 else 2
            candidates.append((r["planet"], f"{r['label'].capitalize()} Triplicity Ruler", w))
    if almuten and almuten.get("winner_id") and almuten["winner_id"] in BODY_REGISTRY:
        candidates.append((almuten["winner_id"], "Almuten Figuris", 3))
    scored = _score_governor_candidates(candidates, planet_rows, positions_by_id)
    primary = scored[0] if scored else None
    return {
        "module": "natal_kurios",
        "method": "natal_weighted_permanent_dignities",
        "primary": {
            "planet": primary["planet"],
            "planet_name": primary["planet_name"],
            "score": primary["score"],
            "role": primary["role"],
            "natal_house": primary["natal_house"],
            "natal_score_label": primary["natal_score_label"],
        } if primary else None,
        "candidates": scored,
        "note": "Natal Kurios excludes annual profection lord and other time-lords.",
    }


def determine_current_compound_chart_governor(
    asc_lon: float,
    is_day: bool,
    light_triplicity: dict[str, Any] | None,
    almuten: dict[str, Any] | None,
    profection_lord_id: str | None,
    planet_rows: list[dict[str, Any]],
    positions_by_id: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Modern composite proxy mixing natal + current time-lord factors.

    Not a traditional permanent Kurios. Year lord may enter this module only.
    """
    _ = is_day
    candidates: list[tuple[str, str, int]] = []
    asc_sign_idx = zodiac_sign_index(asc_lon)
    candidates.append((SIGN_RULERS[asc_sign_idx], "ASC Ruler", 5))
    if light_triplicity and light_triplicity.get("rulers"):
        for r in light_triplicity["rulers"]:
            w = 4 if r["rank"] == 1 else 2
            candidates.append((r["planet"], f"{r['label'].capitalize()} Triplicity Ruler", w))
    if almuten and almuten.get("winner_id") and almuten["winner_id"] in BODY_REGISTRY:
        candidates.append((almuten["winner_id"], "Almuten Figuris", 3))
    if profection_lord_id and profection_lord_id in BODY_REGISTRY:
        candidates.append((profection_lord_id, "Annual Profection Lord (time-bound)", 1))
    scored = _score_governor_candidates(candidates, planet_rows, positions_by_id)
    primary = scored[0] if scored else None
    return {
        "module": "current_compound_chart_governor",
        "method": "current_compound_chart_governor",
        "method_legacy_alias": "compound_weighted",
        "proxy": True,
        "primary": {
            "planet": primary["planet"],
            "planet_name": primary["planet_name"],
            "score": primary["score"],
            "role": primary["role"],
            "natal_house": primary["natal_house"],
            "natal_score_label": primary["natal_score_label"],
        } if primary else None,
        "candidates": scored,
        "note": "Modern composite proxy: may include annual profection lord. Not natal Kurios.",
    }


def determine_kurios(
    asc_lon: float,
    is_day: bool,
    light_triplicity: dict[str, Any] | None,
    almuten: dict[str, Any] | None,
    profection_lord_id: str | None,
    planet_rows: list[dict[str, Any]],
    positions_by_id: dict[str, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Compatibility wrapper: returns three modules + legacy primary from natal Kurios.

    Legacy `method=compound_weighted` consumers should migrate to
    `current_compound_chart_governor` for timed composites and `natal_kurios` for natal.
    """
    oikodespotes = determine_oikodespotes(asc_lon, planet_rows, positions_by_id)
    natal_kurios = determine_natal_kurios(
        asc_lon, light_triplicity, almuten, planet_rows, positions_by_id
    )
    current_gov = determine_current_compound_chart_governor(
        asc_lon,
        is_day,
        light_triplicity,
        almuten,
        profection_lord_id,
        planet_rows,
        positions_by_id,
    )
    # Primary for backward compatibility: natal Kurios (no year lord).
    return {
        "method": "natal_kurios_with_modules",
        "method_legacy_alias": "compound_weighted",
        "primary": natal_kurios.get("primary"),
        "candidates": natal_kurios.get("candidates"),
        "natal_oikodespotes": oikodespotes,
        "natal_kurios": natal_kurios,
        "current_compound_chart_governor": current_gov,
        "note": (
            "Split modules: natal_oikodespotes, natal_kurios, current_compound_chart_governor. "
            "Year profection lord is only in current_compound_chart_governor."
        ),
    }


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
    sr_mc_lon: float | None = None
    for angle in solar_return_snapshot.get("angles", []):
        if angle.get("id") == "ASC":
            sr_asc_lon = angle["longitude"]
        elif angle.get("id") == "MC":
            sr_mc_lon = angle["longitude"]
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
    sr_mc_sign_idx = zodiac_sign_index(sr_mc_lon) if sr_mc_lon is not None else (sr_asc_idx + 9) % 12
    sr_mc_ruler_id = SIGN_RULERS[sr_mc_sign_idx]

    def ruler_house(ruler_id: str) -> int:
        row = next((planet for planet in sr_planet_rows if planet.get("id") == ruler_id), None)
        return int(row.get("house", 0)) if row is not None else 0

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
        "asc_ruler_house": ruler_house(sr_asc_ruler_id),
        "mc_ruler": planet_name(sr_mc_ruler_id),
        "mc_ruler_house": ruler_house(sr_mc_ruler_id),
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
