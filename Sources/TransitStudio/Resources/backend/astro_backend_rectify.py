"""Rectification module — batch primary-direction computation for birth-time tuning.

Called via mode=rectify from astro_backend_api.
Computes a symmetric window of candidate birth times and returns
primary directions + notes + tags for each candidate.
"""

from __future__ import annotations

import json
import math
import sys
from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
    CLASSICAL_BODY_IDS,
    set_zodiac_mode,
    jd_from_datetime,
    format_local,
    norm360,
    planet_name,
)
from astro_backend_ephemeris import (
    build_houses,
    calculate_positions,
    configure_runtime,
    house_for_longitude,
    longitude_in_interval,
)
from astro_backend_primary_directions import calculate_primary_directions
from astro_backend_classical import dignity_labels, sect_status

# ---------------------------------------------------------------------------
#  House / significator / aspect theme tables
# ---------------------------------------------------------------------------

HOUSE_THEMES: dict[int, str] = {
    1: "自我、身体、身份与人生方向",
    2: "财务、资源与价值观",
    3: "学习、沟通、兄弟与短途",
    4: "家庭、居所与根源",
    5: "恋爱、子女、创作与享乐",
    6: "健康、劳务与日常服务",
    7: "关系、合作、婚姻与公开连接",
    8: "共享资源、债务、转变与危机",
    9: "远行、高等学习、信念与哲学",
    10: "事业、名望与社会地位",
    11: "社群、朋友、愿望与团体",
    12: "隐忧、隔离、灵性与消耗",
}

ANGLE_THEMES: dict[str, str] = {
    "ASC": "自我展现、人生方向与身体形象",
    "MC": "事业成就、社会地位与人生目标",
    "DSC": "关系合作、婚姻与公开连接",
    "IC": "家庭根源、内在基础与晚年",
}

PLANET_THEMES: dict[str, str] = {
    "SUN": "核心自我、生命力与意志",
    "MOON": "情绪需求、习惯与安全感",
    "MERCURY": "思维、沟通与学习",
    "VENUS": "关系、价值与审美",
    "MARS": "行动、冲劲与竞争",
    "JUPITER": "扩张、幸运与意义追寻",
    "SATURN": "责任、限制与结构建立",
}

ASPECT_STYLE: dict[str, str] = {
    "conjunction": "成形与显化",
    "sextile": "顺畅与助力",
    "square": "压力与取舍",
    "trine": "顺势展开",
    "opposition": "对立与拉扯",
}

FIXED_ANGLES: set[str] = {"ASC", "MC", "DSC", "IC"}


def _house_theme(n: int) -> str:
    return HOUSE_THEMES.get(n, f"{n}宫主题")


def _sig_theme(sig_id: str) -> str:
    if sig_id in ANGLE_THEMES:
        return ANGLE_THEMES[sig_id]
    return PLANET_THEMES.get(sig_id, f"{planet_name(sig_id)}主题")


def _benefic_label(body_id: str) -> str:
    if body_id in ("VENUS", "JUPITER"):
        return "吉星"
    if body_id in ("MARS", "SATURN"):
        return "凶星"
    return "中性"


def _generate_note(
    prom_id: str,
    sig_id: str,
    aspect_type: str,
    aspect_name: str,
    direction_type: str,
    sig_house: int | None,
    prom_house: int | None,
    is_day: bool,
    sig_dignities: list[str],
    sig_sect: str,
    prom_dignities: list[str],
    prom_sect: str,
) -> str:
    prom_name = planet_name(prom_id)
    sig_name = planet_name(sig_id) if sig_id not in FIXED_ANGLES else sig_id
    style = ASPECT_STYLE.get(aspect_type, aspect_type)

    theme = _sig_theme(sig_id)
    if sig_id not in FIXED_ANGLES and sig_house is not None:
        theme = _house_theme(sig_house)
    elif sig_id in FIXED_ANGLES:
        theme = ANGLE_THEMES.get(sig_id, "")

    tokens: list[str] = [f"{prom_name}触发{sig_name}"]
    if theme:
        tokens.append(f"{theme}被拉高")
    if aspect_type == "conjunction":
        tokens.append(style)
    else:
        tokens.append(f"{aspect_name}偏{style}")
    if direction_type == "converse":
        tokens.append("属回返内省，需向内整合沉淀")

    parens: list[str] = ["昼盘" if is_day else "夜盘"]
    sig_parts: list[str] = []
    if sig_house is not None and sig_id not in FIXED_ANGLES:
        sig_parts.append(f"{sig_house}宫")
    if sig_sect:
        sig_parts.append(sig_sect)
    worthy = [d for d in sig_dignities if d not in ("顺行", "逆行")]
    if worthy:
        sig_parts.append("、".join(worthy))
    if sig_id not in FIXED_ANGLES:
        sig_parts.append(_benefic_label(sig_id))
    if sig_parts:
        parens.append("Sig:" + " ".join(sig_parts))

    prom_parts: list[str] = []
    if prom_house is not None and prom_id not in FIXED_ANGLES:
        prom_parts.append(f"{prom_house}宫")
    if prom_sect:
        prom_parts.append(prom_sect)
    p_worthy = [d for d in prom_dignities if d not in ("顺行", "逆行")]
    if p_worthy:
        prom_parts.append("、".join(p_worthy))
    if prom_id not in FIXED_ANGLES:
        prom_parts.append(_benefic_label(prom_id))
    if prom_parts:
        parens.append("Pro:" + " ".join(prom_parts))

    note = "，".join(tokens)
    if parens:
        note += "（" + " · ".join(parens) + "）"
    note += "。"
    return note


def _generate_tags(
    prom_id: str,
    sig_id: str,
    aspect_type: str,
    direction_type: str,
    sig_house: int | None,
    prom_house: int | None,
) -> list[str]:
    tags: list[str] = []
    astyles: dict[str, list[str]] = {
        "conjunction": ["合相", "强调"],
        "sextile": ["六合", "助力"],
        "square": ["刑相", "压力"],
        "trine": ["拱相", "顺畅"],
        "opposition": ["冲相", "对立"],
    }
    tags.extend(astyles.get(aspect_type, [aspect_type]))
    if sig_id in FIXED_ANGLES:
        tags.append(f"角度_{sig_id}")
    else:
        tags.append(f"星体_{sig_id}")
        if sig_house is not None:
            tags.append(f"{sig_house}宫")
    if prom_id not in FIXED_ANGLES:
        tags.append(f"触发_{prom_id}")
        if prom_house is not None:
            tags.append(f"触发{prom_house}宫")
    tags.append(direction_type)
    return tags


# ---------------------------------------------------------------------------
#  Helpers
# ---------------------------------------------------------------------------

def _planets_summary(jd: float, cusps: list[float], sidereal: bool, warnings: list[str]) -> list[dict[str, Any]]:
    specs = [BODY_REGISTRY[bid] for bid in CLASSICAL_BODY_IDS]
    positions = calculate_positions(jd, specs, warnings, sidereal=sidereal)
    rows: list[dict[str, Any]] = []
    for p in positions:
        rows.append({
            "id": p["body_id"],
            "name": p["name"],
            "longitude": p["longitude"],
            "sign": p["sign"],
            "degree_text": p["degree_text"],
            "house": house_for_longitude(p["longitude"], cusps),
            "speed": p["speed"],
        })
    return rows


def _compute_candidate(
    birth_dt: datetime,
    jd: float,
    latitude: float,
    longitude: float,
    house_system: str,
    sidereal: bool,
    max_age: int,
    bounds_system: str,
    triplicity_system: str,
    warnings: list[str],
) -> dict[str, Any]:
    cusps, angles, _ = build_houses(jd, latitude, longitude, house_system, sidereal, warnings)
    planets = _planets_summary(jd, cusps, sidereal, warnings)
    sun_lon = next((p["longitude"] for p in planets if p["id"] == "SUN"), 0.0)
    is_day = longitude_in_interval(sun_lon, angles["DSC"], angles["ASC"])
    directions = calculate_primary_directions(jd, birth_dt, latitude, longitude, house_system, sidereal, warnings, max_age)

    planet_house = {p["id"]: p["house"] for p in planets}
    angle_house = {name: house_for_longitude(lon, cusps) for name, lon in angles.items()}
    all_house = {**planet_house, **angle_house}
    dig_cache: dict[str, Any] = {}

    for d in directions:
        pid = d["promissor_id"]
        sid = d["significator_id"]
        sh = all_house.get(sid)
        ph = all_house.get(pid)

        for bid in [sid, pid]:
            if bid in FIXED_ANGLES or bid in dig_cache:
                continue
            pdata = next((x for x in planets if x["id"] == bid), None)
            if pdata:
                _, _, _, _, _, _, dign, _, _, _ = dignity_labels(
                    bid, pdata["longitude"], is_day, bounds_system, triplicity_system,
                )
                sec, _, _, _ = sect_status(bid, is_day, pdata["longitude"], sun_lon, pdata["house"])
                dig_cache[bid] = {"dignities": dign, "sect": sec}

        sc = dig_cache.get(sid, {"dignities": [], "sect": ""})
        pc = dig_cache.get(pid, {"dignities": [], "sect": ""})

        d["note"] = _generate_note(
            pid, sid, d["aspect_type"], d["aspect_name"], d["direction_type"],
            sh, ph, is_day,
            sc["dignities"], sc["sect"],
            pc["dignities"], pc["sect"],
        )
        d["tags"] = _generate_tags(pid, sid, d["aspect_type"], d["direction_type"], sh, ph)
        d["houses_involved"] = [h for h in [sh, ph] if h is not None]
        d["shift_vs_center_days"] = 0.0

    return {
        "offset_minutes": 0,
        "birth_local": format_local(birth_dt),
        "meta": {"jd": round(jd, 6), "sidereal": sidereal, "is_day": is_day},
        "angles": {k: {"longitude": round(v, 4)} for k, v in angles.items()},
        "planets_summary": planets,
        "primary_directions": directions,
    }


# ---------------------------------------------------------------------------
#  Public entry point
# ---------------------------------------------------------------------------

def compute_window(request: dict[str, Any]) -> dict[str, Any]:
    import re
    from zoneinfo import ZoneInfo

    _TZ_RE = re.compile(r"^(?:(?:UTC|GMT)\s*)?([+-])\s*(\d{1,2})(?::(\d{2}))?$", re.IGNORECASE)

    def _parse_tz(s: str) -> Any:
        m = _TZ_RE.match(s.strip())
        if m:
            sign = 1 if m.group(1) == "+" else -1
            hours = int(m.group(2))
            minutes = int(m.group(3) or 0)
            if hours > 14 or minutes >= 60:
                return None
            return timezone(sign * timedelta(hours=hours, minutes=minutes))
        try:
            return ZoneInfo(s.strip())
        except (KeyError, ValueError, TypeError):
            return None

    try:
        bd = request["birth_date"]
        ct = request["center_time"]
        tz_str = request["timezone"]
        lat = float(request["latitude"])
        lng = float(request["longitude"])
        hs = request.get("house_system", "whole_sign")
        z = request.get("zodiac", "tropical")
        bs = request.get("bounds_system", "egyptian")
        ts = request.get("triplicity_system", "dorothean")
        max_age = int(request.get("max_age", 90))
        center_offset_seconds = int(request.get("center_offset_seconds", 0))

        if "window_seconds" in request and "step_seconds" in request:
            win_sec = int(request["window_seconds"])
            step_sec = int(request["step_seconds"])
            if step_sec < 1:
                step_sec = 1
            if win_sec < 1:
                win_sec = 60
        else:
            win_min = int(request.get("window_minutes", 30))
            step_min = int(request.get("step_minutes", 1))
            if step_min < 1:
                step_min = 1
            if win_min < 1:
                win_min = 30
            win_sec = win_min * 60
            step_sec = step_min * 60
    except (KeyError, ValueError, TypeError) as exc:
        return {"error": f"Invalid request: {exc}"}

    tz = _parse_tz(tz_str)
    if tz is None:
        return {"error": f"Unknown timezone: {tz_str}"}

    try:
        center_dt = datetime.strptime(f"{bd} {ct}", "%Y-%m-%d %H:%M").replace(tzinfo=tz)
    except ValueError:
        return {"error": f"Cannot parse datetime: {bd} {ct}"}

    center_dt += timedelta(seconds=center_offset_seconds)
    all_warnings: list[str] = []
    sidereal = set_zodiac_mode(z, all_warnings)
    configure_runtime(False, "warn")

    offsets = set()
    bound = win_sec
    while bound % step_sec != 0:
        bound += 1
    off = -bound
    while off <= bound:
        if abs(off) <= win_sec:
            offsets.add(off)
        off += step_sec

    candidates: list[dict[str, Any]] = []
    center_index = -1
    total = len(offsets)

    for i, sec_off in enumerate(sorted(offsets)):
        cand_dt = center_dt + timedelta(seconds=sec_off)
        cand_jd = jd_from_datetime(cand_dt)
        cw: list[str] = []
        cand = _compute_candidate(
            cand_dt, cand_jd, lat, lng, hs, sidereal, max_age, bs, ts, cw,
        )
        cand["offset_seconds"] = sec_off
        cand["offset_minutes"] = int(sec_off / 60)
        all_warnings.extend(cw)
        candidates.append(cand)
        if sec_off == 0:
            center_index = len(candidates) - 1

        progress = (i + 1) / total
        sys.stderr.write(json.dumps({"progress": round(progress, 3)}) + "\n")
        sys.stderr.flush()

    # shift-vs-center
    if center_index >= 0:
        center = candidates[center_index]
        cmap = {cd["id"]: cd["age_from_abs_arc"] for cd in center["primary_directions"]}
        for cand in candidates:
            for cd in cand["primary_directions"]:
                ca = cmap.get(cd["id"])
                if ca is not None:
                    cd["shift_vs_center_days"] = round((cd["age_from_abs_arc"] - ca) * 365.2425, 4)

    return {
        "center_offset_index": center_index,
        "total_candidates": len(candidates),
        "window_seconds": win_sec,
        "step_seconds": step_sec,
        "window_minutes": win_sec // 60,
        "step_minutes": step_sec // 60 if step_sec >= 60 else 0,
        "max_age": max_age,
        "candidates": candidates,
        "warnings": all_warnings,
    }
