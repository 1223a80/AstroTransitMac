from __future__ import annotations

import calendar
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
FIRDARIA_SUB_SEQUENCE = ["SUN", "VENUS", "MERCURY", "MOON", "SATURN", "JUPITER", "MARS"]
FIRDARIA_NAMES = {"NORTH_NODE": "北交点", "SOUTH_NODE": "南交点"}

# Decennials (Hellenistic "10 years and 9 months" / 129 months). Independent of Firdaria.
# Minor years expressed as months: 30+12+15+19+8+20+25 = 129. No lunar nodes.
DECENNIALS_METHOD_PROFILE = "decennials_129_month_minor_years_v1"
DECENNIALS_MONTHS = {
    "SUN": 19,
    "VENUS": 8,
    "MERCURY": 20,
    "MOON": 25,
    "SATURN": 30,
    "JUPITER": 12,
    "MARS": 15,
}
DECENNIALS_TOTAL_MONTHS = sum(DECENNIALS_MONTHS.values())  # 129
# Day: from Sun in Chaldean descending order; night: from Moon.
DECENNIALS_ORDER_DAY = ["SUN", "VENUS", "MERCURY", "MOON", "SATURN", "JUPITER", "MARS"]
DECENNIALS_ORDER_NIGHT = ["MOON", "SATURN", "JUPITER", "MARS", "SUN", "VENUS", "MERCURY"]

_ZR_TOTAL_YEARS = sum(ZR_PERIOD_YEARS.values())


def _add_months_same_day(base: datetime, month_offset: int) -> datetime:
    total_month = base.year * 12 + (base.month - 1) + month_offset
    year = total_month // 12
    month = total_month % 12 + 1
    day = min(base.day, calendar.monthrange(year, month)[1])
    return base.replace(year=year, month=month, day=day)


def monthly_profection(birth_dt: datetime, reference_dt: datetime, year_sign_idx: int) -> dict[str, Any]:
    age = completed_age(birth_dt, reference_dt)
    year_start = same_month_day(birth_dt.year + age, birth_dt)
    month_delta = (reference_dt.year - year_start.year) * 12 + (reference_dt.month - year_start.month)
    if reference_dt.day < year_start.day:
        month_delta -= 1
    month_delta = min(max(month_delta, 0), 11)
    month_in_year = month_delta % 12
    sign_idx = (year_sign_idx + month_in_year) % 12
    lord_id = SIGN_RULERS[sign_idx]
    month_start = _add_months_same_day(year_start, month_delta)
    month_end = _add_months_same_day(year_start, month_delta + 1) - timedelta(seconds=1)
    house = month_in_year + 1
    return {
        "month": month_in_year + 1,
        "house": house,
        "sign": SIGNS[sign_idx],
        "lord": planet_name(lord_id),
        "lord_id": lord_id,
        "start_local": format_local(month_start),
        "end_local": format_local(month_end),
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
        "lordId": lord_id,
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
    if main_ruler not in FIRDARIA_SUB_SEQUENCE:
        return []
    start_index = FIRDARIA_SUB_SEQUENCE.index(main_ruler)
    sub_sequence = [
        FIRDARIA_SUB_SEQUENCE[(start_index + offset) % len(FIRDARIA_SUB_SEQUENCE)]
        for offset in range(len(FIRDARIA_SUB_SEQUENCE))
    ]
    fraction = 1 / len(FIRDARIA_SUB_SEQUENCE)
    sub_start = main_start
    rows: list[dict[str, Any]] = []
    for idx, sub_ruler in enumerate(sub_sequence):
        sub_duration_days = main_years * 365.2425 * fraction
        sub_end = sub_start + timedelta(days=sub_duration_days)
        rows.append({
            "id": f"firdaria-sub-{main_ruler}-{idx + 1}-{sub_ruler}",
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
            if sub_periods:
                sub_note = "7 等分次限，从主限星开始"
            else:
                sub_note = "交点主限不拆次限"
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
                "notes": [f"{'昼盘' if is_day else '夜盘'}序列", f"{years} 年主限", sub_note],
                "sub_periods": sub_periods,
                "current_sub_period": current_sub,
                "planetary_years": PLANETARY_YEARS,
                "_method": "Firdaria_Persian_Traditional",
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


def _decennials_order(is_day: bool) -> list[str]:
    return list(DECENNIALS_ORDER_DAY if is_day else DECENNIALS_ORDER_NIGHT)


def _decennials_add_months(base: datetime, months: float) -> datetime:
    """Advance by fractional months using tropical year / 12."""
    days = float(months) * (365.2425 / 12.0)
    return base + timedelta(days=days)


def decennials_build_timeline(
    birth_dt: datetime,
    is_day: bool,
    max_age_years: float = 100.0,
) -> list[dict[str, Any]]:
    """Build continuous major periods of the 129-month Decennials cycle (no Firdaria reuse)."""
    order = _decennials_order(is_day)
    birth_naive = birth_dt.replace(tzinfo=None) if birth_dt.tzinfo else birth_dt
    end_limit = birth_naive + timedelta(days=max_age_years * 365.2425)
    cursor = birth_naive
    cycle_index = 0
    periods: list[dict[str, Any]] = []
    while cursor < end_limit:
        for ruler in order:
            months = float(DECENNIALS_MONTHS[ruler])
            end = _decennials_add_months(cursor, months)
            periods.append({
                "ruler_id": ruler,
                "ruler": planet_name(ruler),
                "months": months,
                "years": round(months / 12.0, 6),
                "start": cursor,
                "end": end,
                "cycle_index": cycle_index,
            })
            cursor = end
            if cursor >= end_limit:
                break
        cycle_index += 1
    return periods


def decennials_sub_periods(
    main_ruler: str,
    main_start: datetime,
    main_months: float,
    is_day: bool,
) -> list[dict[str, Any]]:
    """Sub-periods proportional to minor-year months within the major period, starting at main ruler."""
    order = _decennials_order(is_day)
    if main_ruler not in order:
        return []
    start_index = order.index(main_ruler)
    rotated = [order[(start_index + offset) % len(order)] for offset in range(len(order))]
    total = float(DECENNIALS_TOTAL_MONTHS)
    sub_start = main_start.replace(tzinfo=None) if main_start.tzinfo else main_start
    rows: list[dict[str, Any]] = []
    for idx, sub_ruler in enumerate(rotated):
        fraction = DECENNIALS_MONTHS[sub_ruler] / total
        sub_months = float(main_months) * fraction
        sub_end = _decennials_add_months(sub_start, sub_months)
        rows.append({
            "id": f"decennials-sub-{main_ruler}-{idx + 1}-{sub_ruler}",
            "ruler_id": sub_ruler,
            "ruler": planet_name(sub_ruler),
            "start_local": format_local(sub_start),
            "end_local": format_local(sub_end),
            "months": round(sub_months, 6),
            "fraction": round(fraction, 6),
        })
        sub_start = sub_end
    return rows


def decennials_summary(birth_dt: datetime, reference_dt: datetime, is_day: bool) -> dict[str, Any]:
    """Current Decennials major period under the 129-month profile (decoupled from Firdaria)."""
    ref = reference_dt.replace(tzinfo=None) if reference_dt.tzinfo else reference_dt
    birth_naive = birth_dt.replace(tzinfo=None) if birth_dt.tzinfo else birth_dt
    timeline = decennials_build_timeline(birth_dt, is_day, max_age_years=120.0)
    active = next((p for p in timeline if p["start"] <= ref < p["end"]), None)
    expired = False
    if active is None and timeline:
        active = timeline[-1]
        expired = True

    if active is None:
        return {
            "id": "decennials-main-missing",
            "technique": "Decennials",
            "level": "主限",
            "ruler": "",
            "sign": None,
            "start_local": format_local(birth_naive),
            "end_local": format_local(birth_naive),
            "notes": ["未生成 Decennials 时间线"],
            "sub_periods": [],
            "method_profile": DECENNIALS_METHOD_PROFILE,
            "method_variant": DECENNIALS_METHOD_PROFILE,
            "total_cycle_months": DECENNIALS_TOTAL_MONTHS,
            "_method": "Decennials_Hellenistic_129_month",
            "_source_tradition": "Hellenistic",
        }

    sub_periods = decennials_sub_periods(active["ruler_id"], active["start"], active["months"], is_day)
    current_sub: dict[str, Any] | None = None
    for sub in sub_periods:
        sub_start_dt = datetime.strptime(sub["start_local"], "%Y-%m-%d %H:%M")
        sub_end_dt = datetime.strptime(sub["end_local"], "%Y-%m-%d %H:%M")
        if sub_start_dt <= ref < sub_end_dt:
            current_sub = sub
            break

    notes = [
        f"{'昼盘' if is_day else '夜盘'} 129 月体系",
        f"主限 {active['months']:.0f} 月（{active['years']:.2f} 年）",
        f"共 {len(sub_periods)} 个子限",
        "Decennials = 七曜小年换算为月，大周期 129 月（10年9月）；不含交点；与 Firdaria 完全解耦",
        f"cycle_index={active['cycle_index']}",
    ]
    if expired:
        notes.append("参考时刻超出生成窗口，返回最后一段")

    return {
        "id": "decennials-main-expired" if expired else "decennials-main",
        "technique": "Decennials",
        "level": "主限",
        "ruler": active["ruler"],
        "ruler_id": active["ruler_id"],
        "sign": None,
        "start_local": format_local(active["start"]),
        "end_local": format_local(active["end"]),
        "next_transition": format_local(active["end"]),
        "months": active["months"],
        "years": active["years"],
        "cycle_index": active["cycle_index"],
        "notes": notes,
        "sub_periods": sub_periods,
        "current_sub_period": current_sub,
        "method_profile": DECENNIALS_METHOD_PROFILE,
        "method_variant": DECENNIALS_METHOD_PROFILE,
        "total_cycle_months": DECENNIALS_TOTAL_MONTHS,
        "planetary_months": dict(DECENNIALS_MONTHS),
        "_method": "Decennials_Hellenistic_129_month",
        "_source_tradition": "Hellenistic",
        "independence_group": "decennials_129_month",
        "technique_family": "decennials",
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


# Classical Hybrid Profile for Zodiacal Releasing:
# - Level 1 (Years): Tropical astronomical year (365.2425 days / year via add_years_approx)
# - Level 2 (Months): Fixed 30.0 days per sign-year unit
# - Level 3 (Sub-periods): Fixed 2.5 days per sign-year unit
# - Level 4 (Micro-periods): Fixed 5.0 hours (5/24 days) per sign-year unit
ZR_UNIT_DAYS_BY_LEVEL = {
    2: 30.0,
    3: 2.5,
    4: 5.0 / 24.0,
}


def _zr_sub_periods_sequence(
    origin_sign_idx: int,
    parent_start: datetime,
    parent_end: datetime,
    reference_dt: datetime,
    level: int,
    max_level: int,
) -> list[dict[str, Any]]:
    if level > max_level or level not in ZR_UNIT_DAYS_BY_LEVEL:
        return []
    ref_naive = reference_dt.replace(tzinfo=None) if reference_dt.tzinfo else reference_dt
    cursor = parent_start.replace(tzinfo=None) if parent_start.tzinfo else parent_start
    parent_end_naive = parent_end.replace(tzinfo=None) if parent_end.tzinfo else parent_end

    unit_days = ZR_UNIT_DAYS_BY_LEVEL[level]
    rows: list[dict[str, Any]] = []
    step = 0
    curr_sign = origin_sign_idx

    while cursor < parent_end_naive:
        if step == 0:
            curr_sign = origin_sign_idx
        elif step == 12:
            # LoB jump after full 12-sign first cycle
            curr_sign = (origin_sign_idx + 6) % 12
        else:
            curr_sign = (curr_sign + 1) % 12

        sub_days = ZR_PERIOD_YEARS[curr_sign] * unit_days
        sub_end = cursor + timedelta(days=sub_days)
        if sub_end > parent_end_naive:
            sub_end = parent_end_naive

        is_active = cursor <= ref_naive < sub_end
        actual_days = (sub_end - cursor).total_seconds() / 86400.0
        row: dict[str, Any] = {
            "level": f"L{level}",
            "sign": SIGNS[curr_sign],
            "sign_index": curr_sign,
            "ruler": planet_name(SIGN_RULERS[curr_sign]),
            "years": round(actual_days / 365.2425, 4),
            "start_local": format_local(cursor),
            "end_local": format_local(sub_end),
            "is_active": is_active,
        }
        if is_active and level < max_level:
            row["sub_periods"] = _zr_sub_periods_sequence(
                curr_sign, cursor, sub_end, reference_dt, level + 1, max_level
            )
        rows.append(row)
        cursor = sub_end
        step += 1
        if step > 200:  # safety break
            break

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
    l4_periods: list[dict[str, Any]] | None = None,
    l4_origin_idx: int | None = None,
) -> tuple[bool, str, str]:
    checks = [
        (lot_sign_idx, l1_periods, "L1"),
        (l2_origin_idx, l2_periods or [], "L2"),
        (l3_origin_idx, l3_periods or [], "L3"),
        (l4_origin_idx, l4_periods or [], "L4"),
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
            "l4_periods": [],
            "loosing_of_bond": False,
            "loosing_of_bond_detail": "",
            "loosing_of_bond_level": "",
            "current_active_level": None,
        }

    active_period = next((p for p in l1_periods if p["is_active"]), l1_periods[-1])
    l1_start_dt = datetime.strptime(active_period["start_local"], "%Y-%m-%d %H:%M")
    l1_end_dt = datetime.strptime(active_period["end_local"], "%Y-%m-%d %H:%M")

    l2_periods: list[dict[str, Any]] = []
    l3_periods: list[dict[str, Any]] = []
    l4_periods: list[dict[str, Any]] = []

    if max_level >= 2:
        l2_periods = _zr_sub_periods_sequence(
            active_period["sign_index"], l1_start_dt, l1_end_dt, reference_dt, 2, max_level
        )
    active_l2 = next((p for p in l2_periods if p.get("is_active")), None) if l2_periods else None

    if max_level >= 3 and active_l2:
        l2_start_dt = datetime.strptime(active_l2["start_local"], "%Y-%m-%d %H:%M")
        l2_end_dt = datetime.strptime(active_l2["end_local"], "%Y-%m-%d %H:%M")
        l3_periods = _zr_sub_periods_sequence(
            active_l2["sign_index"], l2_start_dt, l2_end_dt, reference_dt, 3, max_level
        )
    active_l3 = next((p for p in l3_periods if p.get("is_active")), None) if l3_periods else None

    if max_level >= 4 and active_l3:
        l3_start_dt = datetime.strptime(active_l3["start_local"], "%Y-%m-%d %H:%M")
        l3_end_dt = datetime.strptime(active_l3["end_local"], "%Y-%m-%d %H:%M")
        l4_periods = _zr_sub_periods_sequence(
            active_l3["sign_index"], l3_start_dt, l3_end_dt, reference_dt, 4, max_level
        )
    active_l4 = next((p for p in l4_periods if p.get("is_active")), None) if l4_periods else None

    lob, lob_detail, lob_level = _detect_loosing_of_bond(
        start_sign,
        l1_periods,
        reference_dt,
        l2_periods,
        l3_periods,
        l2_origin_idx=active_period["sign_index"],
        l3_origin_idx=active_l2["sign_index"] if active_l2 else None,
        l4_periods=l4_periods,
        l4_origin_idx=active_l3["sign_index"] if active_l3 else None,
    )

    current_active_level = "L1"
    if active_l4:
        current_active_level = "L4"
    elif active_l3:
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

    finest = active_l4 or active_l3 or active_l2 or active_period

    def _level_fields(period: dict[str, Any] | None, level_name: str) -> dict[str, Any]:
        if not period:
            return {
                f"{level_name.lower()}_sign": None,
                f"{level_name.lower()}_ruler": None,
                f"{level_name.lower()}_ruler_id": None,
            }
        ruler_name = period.get("ruler") or ""
        # Prefer body id when present on period; else map from SIGN_RULERS by sign.
        ruler_id = period.get("ruler_id")
        if not ruler_id and period.get("sign_index") is not None:
            ruler_id = SIGN_RULERS[int(period["sign_index"])]
        return {
            f"{level_name.lower()}_sign": period.get("sign"),
            f"{level_name.lower()}_ruler": ruler_name,
            f"{level_name.lower()}_ruler_id": ruler_id,
        }

    l1f = _level_fields(active_period, "L1")
    l2f = _level_fields(active_l2, "L2")
    l3f = _level_fields(active_l3, "L3")
    l4f = _level_fields(active_l4, "L4")

    return {
        "id": f"zr-{lot['id']}",
        "technique": f"Zodiacal Releasing from {lot['name']}",
        # Top-level ruler/sign remain L1 (major period). Finer levels are explicit fields.
        "level": "L1",
        "ruler": active_period["ruler"],
        "ruler_id": SIGN_RULERS[active_period["sign_index"]],
        "sign": active_period["sign"],
        "start_local": active_period["start_local"],
        "end_local": active_period["end_local"],
        "next_transition": active_period["end_local"],
        "importance_score": importance,
        "notes": [
            "Top-level ruler/sign = L1. Use l1/l2/l3 fields for layered lords; do not label L1 as LL3.",
        ],
        "current_active_level": current_active_level,
        "current_level_ruler": finest.get("ruler") if finest else active_period["ruler"],
        "current_level_sign": finest.get("sign") if finest else active_period["sign"],
        "current_zr_lord_level": current_active_level,
        "current_zr_lord": finest.get("ruler") if finest else active_period["ruler"],
        "current_zr_lord_basis": f"finest_active_level={current_active_level}",
        **l1f,
        **l2f,
        **l3f,
        **l4f,
        "lot_angularity": angularity,
        "l1_periods": l1_periods,
        "l2_periods": l2_periods,
        "l3_periods": l3_periods,
        "l4_periods": l4_periods,
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
        {"id": "profection", "technique": _technique("profection"), "title": "Annual Profection", "start_local": profection["start_local"], "end_local": profection["end_local"], "kind": "period", "layer": "active_periods"},
        {"id": firdaria["id"], "technique": _technique(firdaria["id"]), "title": f"{firdaria['technique']} {firdaria['level']}", "start_local": firdaria["start_local"], "end_local": firdaria["end_local"], "kind": "period", "layer": "active_periods"},
        {"id": decennials["id"], "technique": _technique(decennials["id"]), "title": f"{decennials['technique']} {decennials['level']}", "start_local": decennials["start_local"], "end_local": decennials["end_local"], "kind": "period", "layer": "active_periods"},
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
                        "layer": "events",
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
            "layer": "active_periods",
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

    def _return_layer(row: dict[str, Any], snap: dict[str, Any]) -> str:
        label = snap.get("label")
        body_id = row.get("body_id", "")
        if label == "current_cycle_return":
            return "active_returns"
        if label == "previous_return":
            # Long-period returns (Jupiter, Saturn) → historical
            if body_id in ("JUPITER", "SATURN"):
                return "historical"
            # Short-period returns → events
            return "events"
        # next_return → events
        return "events"

    for row in returns:
        eid = f"return-{row['body_id'].lower()}"
        for field_name in ("previous_return", "current_cycle_return", "next_return"):
            snap = row.get(field_name)
            if not snap or not snap.get("exact_local"):
                continue
            rows.append({
                "id": f"{eid}-{field_name}",
                "technique": _technique(eid),
                "title": _return_timeline_title(row, snap),
                "start_local": snap["exact_local"],
                "end_local": snap["exact_local"],
                "kind": "event",
                "layer": _return_layer(row, snap),
            })

    rows.sort(key=lambda row: (row["start_local"], row["title"]))
    return rows
