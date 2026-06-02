from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_core import (
    SIGNS,
    SIGN_RULERS,
    add_years_approx,
    completed_age,
    format_local,
    norm360,
    planet_name,
    same_month_day,
    sign_degree,
    zodiac_sign_index,
)

ZR_PERIOD_YEARS = {0: 15, 1: 8, 2: 20, 3: 25, 4: 19, 5: 20, 6: 8, 7: 15, 8: 12, 9: 27, 10: 30, 11: 12}

RETURN_CONFIG = {
    "SUN": {"title": "Solar Return", "search_days": 4, "step_hours": 6, "kind": "annual"},
    "MOON": {"title": "Lunar Return", "search_days": 35, "step_hours": 2, "kind": "nearest"},
    "VENUS": {"title": "Venus Return", "search_days": 730, "step_hours": 24, "kind": "nearest"},
    "MERCURY": {"title": "Mercury Return", "search_days": 400, "step_hours": 24, "kind": "nearest"},
    "MARS": {"title": "Mars Return", "search_days": 1100, "step_hours": 48, "kind": "nearest"},
    "JUPITER": {"title": "Jupiter Return", "search_days": 5000, "step_hours": 168, "kind": "nearest"},
    "SATURN": {"title": "Saturn Return", "search_days": 11500, "step_hours": 168, "kind": "nearest"},
}

PLANETARY_YEARS = {
    "SUN": 19, "MOON": 25, "MERCURY": 20, "VENUS": 8,
    "MARS": 15, "JUPITER": 12, "SATURN": 30,
}

FIRDARIA_SEQUENCE_DAY = [("SUN", 10), ("VENUS", 8), ("MERCURY", 13), ("MOON", 9), ("SATURN", 11), ("JUPITER", 12), ("MARS", 7), ("NORTH_NODE", 3), ("SOUTH_NODE", 2)]
FIRDARIA_SEQUENCE_NIGHT = [("MOON", 9), ("SATURN", 11), ("JUPITER", 12), ("MARS", 7), ("SUN", 10), ("VENUS", 8), ("MERCURY", 13), ("NORTH_NODE", 3), ("SOUTH_NODE", 2)]
FIRDARIA_NAMES = {"NORTH_NODE": "北交点", "SOUTH_NODE": "南交点"}

DECENNIALS_SEQUENCE_DAY = [("SUN", 10), ("VENUS", 8), ("MERCURY", 13), ("MOON", 9), ("SATURN", 11), ("JUPITER", 12), ("MARS", 7)]
DECENNIALS_SEQUENCE_NIGHT = [("MOON", 9), ("SATURN", 11), ("JUPITER", 12), ("MARS", 7), ("SUN", 10), ("VENUS", 8), ("MERCURY", 13)]

_ZR_TOTAL_YEARS = sum(ZR_PERIOD_YEARS.values())


def monthly_profection(birth_dt: datetime, reference_dt: datetime, year_sign_idx: int) -> dict[str, Any]:
    month_delta = (reference_dt.year - birth_dt.year) * 12 + (reference_dt.month - birth_dt.month)
    if reference_dt.day < birth_dt.day:
        month_delta -= 1
    month_delta = max(month_delta, 0)
    month_in_year = month_delta % 12
    sign_idx = (year_sign_idx + month_in_year) % 12
    lord_id = SIGN_RULERS[sign_idx]
    month_start = same_month_day(birth_dt.year, birth_dt)
    for _ in range(month_delta):
        month_start = same_month_day(month_start.year, birth_dt)
        next_month_start = same_month_day(month_start.year + 1, birth_dt) if month_start.month == 12 else same_month_day(month_start.year, birth_dt.replace(month=((birth_dt.month + 1) - 1) % 12 + 1))
        month_start = next_month_start if next_month_start != month_start else add_years_approx(month_start, 1)
    month_end = same_month_day(month_start.year, month_start)
    try:
        month_end = month_start.replace(month=(month_start.month % 12) + 1)
    except ValueError:
        month_end = month_start + timedelta(days=30)
    month_end = month_end.replace(day=min(month_end.day, 28)) + timedelta(days=1) - timedelta(seconds=1)
    month_start_calc = same_month_day(reference_dt.year, birth_dt)
    for _ in range(month_delta):
        try:
            month_start_calc = month_start_calc.replace(month=(month_start_calc.month % 12) + 1)
        except ValueError:
            month_start_calc = month_start_calc + timedelta(days=30)
    month_end_calc = month_start_calc + timedelta(days=27)
    house = month_in_year + 1
    return {
        "month": month_in_year + 1,
        "house": house,
        "sign": SIGNS[sign_idx],
        "lord": planet_name(lord_id),
        "lord_id": lord_id,
        "start_local": format_local(month_start_calc),
        "end_local": format_local(month_end_calc),
    }


def profection_summary(
    birth_dt: datetime,
    reference_dt: datetime,
    asc_lon: float,
    planet_rows: list[dict[str, Any]],
) -> dict[str, Any]:
    age = completed_age(birth_dt, reference_dt)
    start = same_month_day(birth_dt.year + age, birth_dt)
    end = same_month_day(birth_dt.year + age + 1, birth_dt)
    house = age % 12 + 1
    sign_idx = (zodiac_sign_index(asc_lon) + age) % 12
    lord_id = SIGN_RULERS[sign_idx]
    lord = planet_name(lord_id)
    lord_row = next((row for row in planet_rows if row["id"] == lord_id), None)
    activated_planets = [row["name"] for row in planet_rows if row["house"] == house]
    condition = ""
    if lord_row:
        condition = f"{lord_row['sign']} {lord_row['house']}宫，{lord_row['motion']}，评分 {lord_row['score']}"

    monthly = monthly_profection(birth_dt, reference_dt, sign_idx)
    monthly_lord_row = next((r for r in planet_rows if r["id"] == monthly["lord_id"]), None)
    monthly_condition = ""
    if monthly_lord_row:
        monthly_condition = f"{monthly_lord_row['sign']} {monthly_lord_row['house']}宫，{monthly_lord_row['motion']}，评分 {monthly_lord_row['score']}"
    monthly["lord_condition"] = monthly_condition

    profected_asc_lon = norm360(asc_lon + age * 30)
    profected_asc_sign_idx = zodiac_sign_index(profected_asc_lon)
    profected_asc_sign = SIGNS[profected_asc_sign_idx]

    natal_asc_sign = SIGNS[zodiac_sign_index(asc_lon)]
    logic_steps = [
        f"1. 年龄 {age}，从本命上升{natal_asc_sign}起数到第 {house} 宫。",
        f"2. 激活星座为 {SIGNS[sign_idx]}，年主为 {lord}。",
        f"3. 年主状态：{condition or '未取得年主状态'}。",
        f"4. 激活宫内行星：{'、'.join(activated_planets) if activated_planets else '无'}。",
        f"5. 月小限：第 {monthly['month']} 月，{monthly['sign']}，月主 {monthly['lord']}。",
        f"6. Profected ASC：{profected_asc_sign} {sign_degree(profected_asc_lon):.1f}°。",
    ]
    start_utc = start.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M") if start.tzinfo else format_local(start)
    end_utc = end.astimezone(timezone.utc).strftime("%Y-%m-%d %H:%M") if end.tzinfo else format_local(end)
    return {
        "age": age,
        "house": house,
        "sign": SIGNS[sign_idx],
        "lord": lord,
        "lord_condition": condition,
        "start_local": format_local(start),
        "end_local": format_local(end),
        "start_utc": start_utc,
        "end_utc": end_utc,
        "activated_planets": activated_planets,
        "logic_steps": logic_steps,
        "_method": "Annual_Profection_Hellenistic",
        "_source_tradition": "Hellenistic",
        "monthly": monthly,
        "profected_asc_longitude": round(profected_asc_lon, 4),
        "profected_asc_sign": profected_asc_sign,
    }


def firdaria_sub_periods(main_ruler: str, main_start: datetime, main_years: float, is_day: bool) -> list[dict[str, Any]]:
    sequence = FIRDARIA_SEQUENCE_DAY if is_day else FIRDARIA_SEQUENCE_NIGHT
    sub_sequence = [(r, y) for r, y in sequence if r != main_ruler]
    total_sub = sum(y for _, y in sub_sequence)
    sub_start = main_start
    rows: list[dict[str, Any]] = []
    for sub_ruler, sub_years in sub_sequence:
        fraction = sub_years / total_sub
        sub_duration_days = main_years * 365.2425 * fraction
        sub_end = sub_start + timedelta(days=sub_duration_days)
        rows.append({
            "id": f"firdaria-sub-{main_ruler}-{sub_ruler}",
            "ruler": FIRDARIA_NAMES.get(sub_ruler, planet_name(sub_ruler)),
            "start_local": format_local(sub_start),
            "end_local": format_local(sub_end),
            "fraction": round(fraction, 4),
        })
        sub_start = sub_end
    return rows


def firdaria_summary(birth_dt: datetime, reference_dt: datetime, is_day: bool) -> dict[str, Any]:
    sequence = FIRDARIA_SEQUENCE_DAY if is_day else FIRDARIA_SEQUENCE_NIGHT
    start = birth_dt
    for ruler, years in sequence:
        end = add_years_approx(start, years)
        if start <= reference_dt < end:
            sub_periods = firdaria_sub_periods(ruler, start, years, is_day)
            current_sub: dict[str, Any] | None = None
            for sub in sub_periods:
                sub_start_dt = datetime.strptime(sub["start_local"], "%Y-%m-%d %H:%M")
                sub_end_dt = datetime.strptime(sub["end_local"], "%Y-%m-%d %H:%M")
                if sub_start_dt <= reference_dt.replace(tzinfo=None) < sub_end_dt:
                    current_sub = sub
                    break
            return {
                "id": "firdaria-main",
                "technique": "Firdaria",
                "level": "主限",
                "ruler": FIRDARIA_NAMES.get(ruler, planet_name(ruler)),
                "sign": None,
                "start_local": format_local(start),
                "end_local": format_local(end),
                "next_transition": format_local(end),
                "notes": [f"{'昼盘' if is_day else '夜盘'}序列", f"{years} 年主限"],
                "sub_periods": sub_periods,
                "current_sub_period": current_sub,
                "planetary_years": PLANETARY_YEARS,
                "_method": "Firdaria_Persian",
                "_source_tradition": "Persian/Medieval",
            }
        start = end

    ruler, years = sequence[-1]
    return {
        "id": "firdaria-main-expired",
        "technique": "Firdaria",
        "level": "主限",
        "ruler": FIRDARIA_NAMES.get(ruler, planet_name(ruler)),
        "sign": None,
        "start_local": format_local(start),
        "end_local": format_local(add_years_approx(start, years)),
        "notes": ["超出基础 Firdaria 序列"],
        "sub_periods": [],
        "current_sub_period": None,
        "planetary_years": PLANETARY_YEARS,
    }


def decennials_sub_periods(main_ruler: str, main_start: datetime, main_years: float, is_day: bool) -> list[dict[str, Any]]:
    sequence = DECENNIALS_SEQUENCE_DAY if is_day else DECENNIALS_SEQUENCE_NIGHT
    sub_sequence = [(r, y) for r, y in sequence if r != main_ruler]
    total_sub = sum(y for _, y in sub_sequence)
    sub_start = main_start
    rows: list[dict[str, Any]] = []
    for sub_ruler, sub_years in sub_sequence:
        fraction = sub_years / total_sub
        sub_duration_days = main_years * 365.2425 * fraction
        sub_end = sub_start + timedelta(days=sub_duration_days)
        rows.append({
            "id": f"decennials-sub-{main_ruler}-{sub_ruler}",
            "ruler": planet_name(sub_ruler),
            "start_local": format_local(sub_start),
            "end_local": format_local(sub_end),
            "fraction": round(fraction, 4),
        })
        sub_start = sub_end
    return rows


def decennials_summary(birth_dt: datetime, reference_dt: datetime, is_day: bool) -> dict[str, Any]:
    sequence = DECENNIALS_SEQUENCE_DAY if is_day else DECENNIALS_SEQUENCE_NIGHT
    start = birth_dt
    for ruler, years in sequence:
        end = add_years_approx(start, years)
        if start <= reference_dt < end:
            sub_periods = decennials_sub_periods(ruler, start, years, is_day)
            return {
                "id": "decennials-main",
                "technique": "Decennials",
                "level": "主限",
                "ruler": planet_name(ruler),
                "sign": None,
                "start_local": format_local(start),
                "end_local": format_local(end),
                "notes": [f"{'昼盘' if is_day else '夜盘'}序列", f"{years} 年主限", f"共 {len(sub_periods)} 个子限", "Decennials = 7-planet 70-year cycle (no lunar nodes); differs from Firdaria which totals 75 years with nodes"],
                "sub_periods": sub_periods,
                "_method": "Decennials_Hellenistic_10_year_cycle",
                "_source_tradition": "Hellenistic",
                "method_variant": "decennials_7_planet_70_year_cycle",
            }
        start = end

    ruler, years = sequence[-1]
    return {
        "id": "decennials-main-expired",
        "technique": "Decennials",
        "level": "主限",
        "ruler": planet_name(ruler),
        "sign": None,
        "start_local": format_local(start),
        "end_local": format_local(add_years_approx(start, years)),
        "notes": ["超出基础 Decennials 序列"],
        "sub_periods": [],
    }


def _zr_walk(sign_idx: int, start: datetime, reference_dt: datetime, max_cycles: int) -> list[dict[str, Any]]:
    ref = reference_dt.replace(tzinfo=None) if reference_dt.tzinfo else reference_dt
    rows: list[dict[str, Any]] = []
    idx = sign_idx
    cursor = start.replace(tzinfo=None) if start.tzinfo else start
    for _ in range(max_cycles):
        years = ZR_PERIOD_YEARS[idx]
        end = add_years_approx(cursor, years)
        rows.append({
            "sign": SIGNS[idx],
            "sign_index": idx,
            "ruler": planet_name(SIGN_RULERS[idx]),
            "years": years,
            "start_local": format_local(cursor),
            "end_local": format_local(end),
        })
        if cursor <= ref < end:
            break
        cursor = end
        idx = (idx + 1) % 12
    return rows


def _zr_proportional_sub_periods(parent_sign_idx: int, parent_start: datetime, parent_duration_days: float, reference_dt: datetime, level: int, max_level: int) -> list[dict[str, Any]]:
    if level > max_level:
        return []
    ref_naive = reference_dt.replace(tzinfo=None) if reference_dt.tzinfo else reference_dt
    cursor = parent_start.replace(tzinfo=None) if parent_start.tzinfo else parent_start
    rem_days = parent_duration_days
    rows: list[dict[str, Any]] = []
    for offset in range(12):
        sign_idx = (parent_sign_idx + offset) % 12
        fraction = ZR_PERIOD_YEARS[sign_idx] / _ZR_TOTAL_YEARS
        sub_days = rem_days * fraction
        sub_end = cursor + timedelta(days=sub_days)
        is_active = cursor <= ref_naive < sub_end
        row: dict[str, Any] = {
            "level": f"L{level}",
            "sign": SIGNS[sign_idx],
            "sign_index": sign_idx,
            "ruler": planet_name(SIGN_RULERS[sign_idx]),
            "years": round(sub_days / 365.2425, 2),
            "start_local": format_local(cursor),
            "end_local": format_local(sub_end),
            "is_active": is_active,
        }
        if is_active and level < max_level:
            row["sub_periods"] = _zr_proportional_sub_periods(sign_idx, cursor, sub_days, reference_dt, level + 1, max_level)
        cursor = sub_end
        rows.append(row)
    return rows


def _zr_sub_levels(sign_idx: int, start: datetime, reference_dt: datetime, level: int, max_level: int, max_cycles: int = 60) -> list[dict[str, Any]]:
    if level > max_level:
        return []
    ref = reference_dt.replace(tzinfo=None) if reference_dt.tzinfo else reference_dt
    rows: list[dict[str, Any]] = []
    idx = sign_idx
    cursor = start.replace(tzinfo=None) if start.tzinfo else start
    for _ in range(max_cycles):
        years = ZR_PERIOD_YEARS[idx]
        end = add_years_approx(cursor, years)
        is_active = cursor <= ref < end
        row: dict[str, Any] = {
            "level": f"L{level}",
            "sign": SIGNS[idx],
            "sign_index": idx,
            "ruler": planet_name(SIGN_RULERS[idx]),
            "years": years,
            "start_local": format_local(cursor),
            "end_local": format_local(end),
            "is_active": is_active,
        }
        if is_active and level < max_level:
            row["sub_periods"] = _zr_sub_levels(idx, cursor, reference_dt, level + 1, max_level)
        rows.append(row)
        if is_active:
            break
        cursor = end
        idx = (idx + 1) % 12
    return rows


def _parse_period_dt(period: dict[str, Any], key: str) -> datetime | None:
    value = period.get(key)
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d %H:%M")
    except (TypeError, ValueError):
        return None


def _loosing_jump_origin(origin_sign_idx: int, prev_sign_idx: int, current_sign_idx: int) -> bool:
    expected_next = (prev_sign_idx + 1) % 12
    loosening_point = (origin_sign_idx + 6) % 12
    return current_sign_idx == loosening_point and current_sign_idx != expected_next


def _transition_is_current(prev: dict[str, Any], period: dict[str, Any], ref_naive: datetime) -> bool:
    if period.get("is_active") is True:
        return True

    start_dt = _parse_period_dt(period, "start_local")
    end_dt = _parse_period_dt(period, "end_local")
    if start_dt and end_dt:
        return start_dt <= ref_naive < end_dt

    prev_end_dt = _parse_period_dt(prev, "end_local")
    if prev_end_dt and end_dt:
        return prev_end_dt <= ref_naive < end_dt
    if prev_end_dt:
        return prev_end_dt <= ref_naive
    return False


def _detect_level_loosing_of_bond(origin_sign_idx: int, periods: list[dict[str, Any]], reference_dt: datetime, level: str) -> tuple[bool, str, str]:
    ref_naive = reference_dt.replace(tzinfo=None) if reference_dt.tzinfo else reference_dt
    loosening_point = (origin_sign_idx + 6) % 12

    for i, period in enumerate(periods):
        if i == 0:
            continue
        prev = periods[i - 1]
        if not _transition_is_current(prev, period, ref_naive):
            continue
        if _loosing_jump_origin(origin_sign_idx, prev["sign_index"], period["sign_index"]):
            return (
                True,
                f"{level} 从 {prev['sign']} 跳至 {period['sign']}（母周期 {SIGNS[origin_sign_idx]} 的对宫 {SIGNS[loosening_point]}），触发 Loosing of the Bond",
                level,
            )

    return False, "", ""


def _detect_loosing_of_bond(
    lot_sign_idx: int,
    l1_periods: list[dict[str, Any]],
    reference_dt: datetime,
    l2_periods: list[dict[str, Any]] | None = None,
    l3_periods: list[dict[str, Any]] | None = None,
    l2_origin_idx: int | None = None,
    l3_origin_idx: int | None = None,
) -> tuple[bool, str, str]:
    checks = [
        (lot_sign_idx, l1_periods, "L1"),
        (l2_origin_idx, l2_periods or [], "L2"),
        (l3_origin_idx, l3_periods or [], "L3"),
    ]
    for origin_idx, periods, level in checks:
        if origin_idx is None or not periods:
            continue
        lob, detail, lob_level = _detect_level_loosing_of_bond(origin_idx, periods, reference_dt, level)
        if lob:
            return lob, detail, lob_level

    return False, "", ""


def zodiacal_releasing_summary(lot: dict[str, Any], birth_dt: datetime, reference_dt: datetime, max_level: int = 3) -> dict[str, Any]:
    start_sign = zodiac_sign_index(lot["longitude"])
    active_idx = start_sign
    cursor = birth_dt
    l1_periods: list[dict[str, Any]] = []

    for _ in range(20):
        years = ZR_PERIOD_YEARS[active_idx]
        end = add_years_approx(cursor, years)
        is_active = cursor <= reference_dt < end
        l1_periods.append({
            "level": "L1",
            "sign": SIGNS[active_idx],
            "sign_index": active_idx,
            "ruler": planet_name(SIGN_RULERS[active_idx]),
            "years": years,
            "start_local": format_local(cursor),
            "end_local": format_local(end),
            "is_active": is_active,
        })
        if is_active:
            break
        cursor = end
        active_idx = (active_idx + 1) % 12

    if not l1_periods:
        return {
            "id": f"zr-{lot['id']}-unknown",
            "technique": f"Zodiacal Releasing from {lot['name']}",
            "level": "L1",
            "ruler": "",
            "sign": None,
            "start_local": "",
            "end_local": "",
            "notes": ["未找到参考日期所在周期"],
            "l1_periods": [],
            "l2_periods": [],
            "l3_periods": [],
            "loosing_of_bond": False,
            "loosing_of_bond_detail": "",
            "loosing_of_bond_level": "",
        }

    active_period = next((p for p in l1_periods if p["is_active"]), l1_periods[-1])
    l1_duration_days = active_period["years"] * 365.2425

    l2_periods: list[dict[str, Any]] = []
    l3_periods: list[dict[str, Any]] = []
    if max_level >= 2:
        l1_start_dt = datetime.strptime(active_period["start_local"], "%Y-%m-%d %H:%M")
        l2_periods = _zr_proportional_sub_periods(active_period["sign_index"], l1_start_dt, l1_duration_days, reference_dt, 2, max_level)
    if max_level >= 3 and l2_periods:
        active_l2 = next((p for p in l2_periods if p.get("is_active")), None)
        if active_l2:
            l2_start_dt = datetime.strptime(active_l2["start_local"], "%Y-%m-%d %H:%M")
            l2_duration_days = active_l2["years"] * 365.2425
            l3_periods = _zr_proportional_sub_periods(active_l2["sign_index"], l2_start_dt, l2_duration_days, reference_dt, 3, max_level)

    active_l2 = next((p for p in l2_periods if p.get("is_active")), None) if l2_periods else None
    active_l3 = next((p for p in l3_periods if p.get("is_active")), None) if l3_periods else None
    lob, lob_detail, lob_level = _detect_loosing_of_bond(
        start_sign,
        l1_periods,
        reference_dt,
        l2_periods,
        l3_periods,
        l2_origin_idx=active_period["sign_index"],
        l3_origin_idx=active_l2["sign_index"] if active_l2 else None,
    )

    current_active_level = "L1"
    if active_l3:
        current_active_level = "L3"
    elif active_l2:
        current_active_level = "L2"

    lot_house = lot.get("house", 0)
    angularity = "角宫" if lot_house in {1, 4, 7, 10} else "续宫" if lot_house in {2, 5, 8, 11} else "果宫"

    importance = 0
    if angularity == "角宫":
        importance += 3
    elif angularity == "续宫":
        importance += 1
    if lob:
        importance += 5
    if active_l2 and active_l2.get("sign_index") == active_period.get("sign_index"):
        importance += 2

    return {
        "id": f"zr-{lot['id']}",
        "technique": f"Zodiacal Releasing from {lot['name']}",
        "level": "L1",
        "ruler": active_period["ruler"],
        "sign": active_period["sign"],
        "start_local": active_period["start_local"],
        "end_local": active_period["end_local"],
        "next_transition": active_period["end_local"],
        "importance_score": importance,
        "notes": [],
        "current_active_level": current_active_level,
        "lot_angularity": angularity,
        "l1_periods": l1_periods,
        "l2_periods": l2_periods,
        "l3_periods": l3_periods,
        "loosing_of_bond": lob,
        "loosing_of_bond_detail": lob_detail,
        "loosing_of_bond_level": lob_level,
        "_method": "Zodiacal_Releasing_Valens",
        "_source_tradition": "Hellenistic",
    }


def return_search_bounds(body_id: str, birth_dt: datetime, reference_dt: datetime) -> tuple[datetime, datetime]:
    config = RETURN_CONFIG[body_id]
    if config["kind"] == "annual":
        half = timedelta(days=config["search_days"] // 2)
        prev_center = same_month_day(reference_dt.year - 1, birth_dt)
        curr_center = same_month_day(reference_dt.year, birth_dt)
        if reference_dt < curr_center:
            return prev_center - half, curr_center + half
        return curr_center - half, same_month_day(reference_dt.year + 1, birth_dt) + half
    half = timedelta(days=config["search_days"])
    return reference_dt - half, reference_dt + half


def timing_timeline(
    profection: dict[str, Any],
    firdaria: dict[str, Any],
    decennials: dict[str, Any],
    zodiacal_releasing: list[dict[str, Any]],
    returns: list[dict[str, Any]],
    birth_dt: datetime | None = None,
    reference_dt: datetime | None = None,
) -> list[dict[str, Any]]:
    def _technique(entry_id: str) -> str:
        if entry_id == "profection":
            return "小限"
        if "firdaria" in entry_id:
            return "Firdaria"
        if "decennials" in entry_id:
            return "Decennials"
        if entry_id.startswith("planetary-year"):
            return "行星年"
        if entry_id.startswith("zr-"):
            return "ZR"
        if entry_id.startswith("return-"):
            return "返照"
        return ""

    rows = [
        {"id": "profection", "technique": _technique("profection"), "title": "Annual Profection", "start_local": profection["start_local"], "end_local": profection["end_local"], "kind": "period"},
        {"id": firdaria["id"], "technique": _technique(firdaria["id"]), "title": f"{firdaria['technique']} {firdaria['level']}", "start_local": firdaria["start_local"], "end_local": firdaria["end_local"], "kind": "period"},
        {"id": decennials["id"], "technique": _technique(decennials["id"]), "title": f"{decennials['technique']} {decennials['level']}", "start_local": decennials["start_local"], "end_local": decennials["end_local"], "kind": "period"},
    ]

    if birth_dt and reference_dt:
        ref_age = completed_age(birth_dt, reference_dt)
        for body_id, years in PLANETARY_YEARS.items():
            cycles: list[int] = []
            for n in range(1, 121):
                age = n * years
                if age > 120:
                    break
                cycles.append(age)
                if age > ref_age and (n == 1 or cycles[-2] <= ref_age):
                    dt = add_years_approx(birth_dt, age)
                    eid = f"planetary-year-{body_id.lower()}"
                    rows.append({
                        "id": eid,
                        "technique": _technique(eid),
                        "title": f"{planet_name(body_id)} 行星年周期 ({years}y)",
                        "start_local": format_local(dt),
                        "end_local": format_local(dt),
                        "kind": "event",
                    })
                    break

    for row in zodiacal_releasing:
        rows.append({
            "id": row["id"],
            "technique": _technique(row["id"]),
            "title": f"{row['technique']} {row['level']}",
            "start_local": row["start_local"],
            "end_local": row["end_local"],
            "kind": "period",
        })

    def _return_timeline_title(row: dict[str, Any], snap: dict[str, Any]) -> str:
        label = snap.get("label")
        title = row["title"]
        if label == "current_cycle_return":
            return f"Current {title}（当前生效）"
        if label == "next_return":
            return f"Next {title}（下一次）"
        if label == "previous_return":
            return f"Previous {title}（上一次）"
        return title

    for row in returns:
        snap = row.get("current_cycle_return") or row.get("next_return") or row.get("previous_return")
        if snap and snap.get("exact_local"):
            eid = f"return-{row['body_id'].lower()}"
            rows.append({
                "id": eid,
                "technique": _technique(eid),
                "title": _return_timeline_title(row, snap),
                "start_local": snap["exact_local"],
                "end_local": snap["exact_local"],
                "kind": "event",
            })

    rows.sort(key=lambda row: (row["start_local"], row["title"]))
    return rows
