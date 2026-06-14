from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from astro_backend_classical import EXALTATION_RULERS, SIGN_RULERS, aspect_offsets_for_angle, classical_aspect_signature, classical_snapshot
from astro_backend_core import BODY_REGISTRY, SIGNS, angular_separation, format_local, moment_to_jd, moment_to_local_datetime, sign_degree, signed_orb, zodiac_sign_index
from astro_backend_ephemeris import body_longitude_at

CLASSICAL_ANGLES = {
    "conjunction": 0.0,
    "sextile": 60.0,
    "square": 90.0,
    "trine": 120.0,
    "opposition": 180.0,
}

CROSSING_EPSILON = 1e-7

MEAN_DAILY_SPEED_BY_BODY = {
    "MERCURY": 1.383,
    "VENUS": 1.2,
    "MARS": 0.524,
    "JUPITER": 0.083,
    "SATURN": 0.033,
}
STATION_SPEED_RATIO = 0.03
STATION_SPEED_MINIMUM = 0.001
DEFAULT_PERFECTION_SEARCH_DAYS = 1200
SIGN_EXIT_SEARCH_DAYS_BY_BODY = {
    "MOON": 4,
    "SUN": 35,
    "MERCURY": 130,
    "VENUS": 130,
    "MARS": 260,
    "JUPITER": 450,
    "SATURN": 1100,
}

ASPECT_NAMES = {
    "conjunction": "合相",
    "sextile": "六合",
    "square": "刑相",
    "trine": "拱相",
    "opposition": "冲相",
}

QUESTION_PATTERNS = [
    (("恋爱", "关系", "感情", "婚", "对象"), {"house": 7, "natural": "VENUS"}),
    (("工作", "事业", "升职", "老板", "职业"), {"house": 10, "natural": "SUN"}),
    (("财务", "钱", "收入", "投资", "借"), {"house": 2, "natural": "JUPITER"}),
    (("房", "家", "搬家", "地产"), {"house": 4, "natural": "MOON"}),
    (("学习", "考试", "留学", "学业"), {"house": 9, "natural": "MERCURY"}),
    (("旅行", "出行", "远行"), {"house": 9, "natural": "JUPITER"}),
    (("健康", "病", "治疗"), {"house": 6, "natural": "SATURN"}),
]


def angular_delta(a: float, b: float) -> float:
    return abs(((a - b + 180.0) % 360.0) - 180.0)


def same_body(left_row: dict[str, Any], right_row: dict[str, Any]) -> bool:
    return bool(left_row.get("id")) and left_row.get("id") == right_row.get("id")


def station_speed_threshold(body_id: str) -> float | None:
    mean_speed = MEAN_DAILY_SPEED_BY_BODY.get(body_id)
    if mean_speed is None:
        return None
    return max(mean_speed * STATION_SPEED_RATIO, STATION_SPEED_MINIMUM)


def degree_orb_between_rows(left_row: dict[str, Any], right_row: dict[str, Any], angle: float) -> float:
    return min(
        (
            abs(signed_orb(left_row["longitude"], (right_row["longitude"] + offset) % 360.0))
            for offset in aspect_offsets_for_angle(angle)
        ),
        default=0.0,
    )


def relative_orb_for_pair_at(
    dt: datetime,
    left_id: str,
    right_id: str,
    angle: float,
    warnings: list[str],
    warning_keys: set[str],
    branch_offset: float | None = None,
    sidereal: bool = False,
) -> float | None:
    left = body_longitude_at(dt, BODY_REGISTRY[left_id], warnings, warning_keys, sidereal=sidereal)
    right = body_longitude_at(dt, BODY_REGISTRY[right_id], warnings, warning_keys, sidereal=sidereal)
    if left is None or right is None:
        return None
    left_lon, _ = left
    right_lon, _ = right
    offset = aspect_offsets_for_angle(angle)[0] if branch_offset is None else branch_offset
    return signed_orb(left_lon, (right_lon + offset) % 360.0)


def crosses_zero(previous: float, next_value: float) -> bool:
    if abs(previous) < CROSSING_EPSILON or abs(next_value) < CROSSING_EPSILON:
        return True
    if abs(next_value - previous) > 180.0:
        return False
    return (previous < 0.0 < next_value) or (previous > 0.0 > next_value)


def refine_pair_crossing(
    start: datetime,
    end: datetime,
    left_id: str,
    right_id: str,
    angle: float,
    warnings: list[str],
    warning_keys: set[str],
    branch_offset: float,
    sidereal: bool = False,
) -> datetime:
    left = relative_orb_for_pair_at(start, left_id, right_id, angle, warnings, warning_keys, branch_offset, sidereal)
    if left is None:
        return start + (end - start) / 2

    for _ in range(40):
        middle = start + (end - start) / 2
        value = relative_orb_for_pair_at(middle, left_id, right_id, angle, warnings, warning_keys, branch_offset, sidereal)
        if value is None:
            return middle
        if abs(value) < 1e-6:
            return middle
        if crosses_zero(left, value):
            end = middle
        else:
            start = middle
            left = value
    return start + (end - start) / 2


def next_exact_for_pair_branch(
    chart_dt: datetime,
    left_id: str,
    right_id: str,
    angle: float,
    warnings: list[str],
    warning_keys: set[str],
    max_days: int,
    step_hours: int,
    branch_offset: float,
    sidereal: bool = False,
) -> datetime | None:
    previous = relative_orb_for_pair_at(chart_dt, left_id, right_id, angle, warnings, warning_keys, branch_offset, sidereal)
    if previous is None:
        return None
    if abs(previous) < CROSSING_EPSILON:
        return chart_dt

    t = chart_dt
    end = chart_dt + timedelta(days=max_days)
    while t < end:
        next_t = min(t + timedelta(hours=step_hours), end)
        next_value = relative_orb_for_pair_at(next_t, left_id, right_id, angle, warnings, warning_keys, branch_offset, sidereal)
        if next_value is None:
            return None
        if crosses_zero(previous, next_value):
            return refine_pair_crossing(t, next_t, left_id, right_id, angle, warnings, warning_keys, branch_offset, sidereal)
        t = next_t
        previous = next_value
    return None


def next_exact_for_pair(
    chart_dt: datetime,
    left_id: str,
    right_id: str,
    angle: float,
    warnings: list[str],
    warning_keys: set[str],
    max_days: int,
    step_hours: int,
    sidereal: bool = False,
) -> datetime | None:
    exacts: list[datetime] = []
    for offset in aspect_offsets_for_angle(angle):
        exact = next_exact_for_pair_branch(
            chart_dt,
            left_id,
            right_id,
            angle,
            warnings,
            warning_keys,
            max_days,
            step_hours,
            offset,
            sidereal,
        )
        if exact is not None:
            exacts.append(exact)
    return min(exacts) if exacts else None


def previous_exact_for_pair_branch(
    chart_dt: datetime,
    left_id: str,
    right_id: str,
    angle: float,
    warnings: list[str],
    warning_keys: set[str],
    max_days: int,
    step_hours: int,
    branch_offset: float,
    sidereal: bool = False,
) -> datetime | None:
    previous = relative_orb_for_pair_at(chart_dt, left_id, right_id, angle, warnings, warning_keys, branch_offset, sidereal)
    if previous is None:
        return None
    if abs(previous) < CROSSING_EPSILON:
        return chart_dt

    t = chart_dt
    end = chart_dt - timedelta(days=max_days)
    while t > end:
        next_t = max(t - timedelta(hours=step_hours), end)
        next_value = relative_orb_for_pair_at(next_t, left_id, right_id, angle, warnings, warning_keys, branch_offset, sidereal)
        if next_value is None:
            return None
        if crosses_zero(previous, next_value):
            return refine_pair_crossing(next_t, t, left_id, right_id, angle, warnings, warning_keys, branch_offset, sidereal)
        t = next_t
        previous = next_value
    return None


def previous_exact_for_pair(
    chart_dt: datetime,
    left_id: str,
    right_id: str,
    angle: float,
    warnings: list[str],
    warning_keys: set[str],
    max_days: int,
    step_hours: int,
    sidereal: bool = False,
) -> datetime | None:
    exacts: list[datetime] = []
    for offset in aspect_offsets_for_angle(angle):
        exact = previous_exact_for_pair_branch(
            chart_dt,
            left_id,
            right_id,
            angle,
            warnings,
            warning_keys,
            max_days,
            step_hours,
            offset,
            sidereal,
        )
        if exact is not None:
            exacts.append(exact)
    return max(exacts) if exacts else None


def sign_exit_boundary(start_sign: int, next_sign: int) -> float:
    if next_sign == (start_sign + 1) % 12:
        return ((start_sign + 1) * 30.0) % 360.0
    if next_sign == (start_sign - 1) % 12:
        return (start_sign * 30.0) % 360.0
    forward = ((start_sign + 1) * 30.0) % 360.0
    backward = (start_sign * 30.0) % 360.0
    return forward if next_sign > start_sign else backward


def refine_body_longitude_crossing(
    start: datetime,
    end: datetime,
    body_id: str,
    exact_longitude: float,
    warnings: list[str],
    warning_keys: set[str],
    sidereal: bool = False,
) -> datetime:
    calculated = body_longitude_at(start, BODY_REGISTRY[body_id], warnings, warning_keys, sidereal=sidereal)
    if calculated is None:
        return start + (end - start) / 2
    left = signed_orb(calculated[0], exact_longitude)

    for _ in range(40):
        middle = start + (end - start) / 2
        middle_result = body_longitude_at(middle, BODY_REGISTRY[body_id], warnings, warning_keys, sidereal=sidereal)
        if middle_result is None:
            return middle
        value = signed_orb(middle_result[0], exact_longitude)
        if abs(value) < 1e-6:
            return middle
        if crosses_zero(left, value):
            end = middle
        else:
            start = middle
            left = value
    return start + (end - start) / 2


def next_sign_exit_for_body(
    chart_dt: datetime,
    body_id: str,
    warnings: list[str],
    warning_keys: set[str],
    max_days: float,
    step_hours: int,
    sidereal: bool = False,
) -> datetime | None:
    start_result = body_longitude_at(chart_dt, BODY_REGISTRY[body_id], warnings, warning_keys, sidereal=sidereal)
    if start_result is None:
        return None
    start_sign = zodiac_sign_index(start_result[0])

    t = chart_dt
    end = chart_dt + timedelta(days=max_days)
    while t < end:
        next_t = min(t + timedelta(hours=step_hours), end)
        next_result = body_longitude_at(next_t, BODY_REGISTRY[body_id], warnings, warning_keys, sidereal=sidereal)
        if next_result is None:
            return None
        next_sign = zodiac_sign_index(next_result[0])
        if next_sign != start_sign:
            boundary = sign_exit_boundary(start_sign, next_sign)
            return refine_body_longitude_crossing(t, next_t, body_id, boundary, warnings, warning_keys, sidereal)
        t = next_t
    return None


def sign_exit_search_days_for_body(body_id: str) -> int:
    return SIGN_EXIT_SEARCH_DAYS_BY_BODY.get(body_id, DEFAULT_PERFECTION_SEARCH_DAYS)


def sign_exit_step_hours_for_body(body_id: str) -> int:
    return 1 if body_id == "MOON" else 6


def perfection_deadline_for_pair(
    chart_dt: datetime,
    left_id: str,
    right_id: str,
    warnings: list[str],
    warning_keys: set[str],
    sidereal: bool = False,
) -> datetime | None:
    exits: list[datetime] = []
    for body_id in {left_id, right_id}:
        exit_dt = next_sign_exit_for_body(
            chart_dt,
            body_id,
            warnings,
            warning_keys,
            max_days=sign_exit_search_days_for_body(body_id),
            step_hours=sign_exit_step_hours_for_body(body_id),
            sidereal=sidereal,
        )
        if exit_dt is not None:
            exits.append(exit_dt)
    return min(exits) if exits else None


def exact_search_days_until(chart_dt: datetime, deadline: datetime | None) -> int:
    if deadline is None:
        return DEFAULT_PERFECTION_SEARCH_DAYS
    if deadline <= chart_dt:
        return 1
    span_days = (deadline - chart_dt).total_seconds() / 86400.0
    return max(1, min(DEFAULT_PERFECTION_SEARCH_DAYS, int(span_days) + 2))


def body_exits_sign_before(
    chart_dt: datetime,
    exact_dt: datetime,
    body_id: str,
    warnings: list[str],
    warning_keys: set[str],
    sidereal: bool = False,
) -> bool:
    if exact_dt <= chart_dt:
        return False
    span_days = max((exact_dt - chart_dt).total_seconds() / 86400.0, 0.1)
    step_hours = sign_exit_step_hours_for_body(body_id)
    exit_dt = next_sign_exit_for_body(chart_dt, body_id, warnings, warning_keys, span_days, step_hours, sidereal)
    return exit_dt is not None and exit_dt < exact_dt


def make_aspect_event(
    exact: datetime,
    source_row: dict[str, Any],
    target_row: dict[str, Any],
    aspect_id: str,
) -> dict[str, Any]:
    return {
        "id": f"{source_row['id']}|{aspect_id}|{target_row['id']}|{exact.strftime('%Y%m%d%H%M')}",
        "target_id": target_row["id"],
        "target_name": target_row["name"],
        "aspect_id": aspect_id,
        "aspect_name": ASPECT_NAMES[aspect_id],
        "exact_local": format_local(exact),
        "moon_longitude": source_row["longitude"],
        "target_longitude": target_row["longitude"],
        "moon_house": source_row["house"],
        "target_house": target_row["house"],
    }


def moon_storyline(
    chart_dt: datetime,
    planet_rows: list[dict[str, Any]],
    warnings: list[str],
    sidereal: bool = False,
) -> dict[str, Any]:
    planet_by_id = {row["id"]: row for row in planet_rows}
    moon = planet_by_id["MOON"]
    warning_keys: set[str] = set()

    sign_exit_dt = next_sign_exit_for_body(chart_dt, "MOON", warnings, warning_keys, max_days=4, step_hours=1, sidereal=sidereal)
    if sign_exit_dt is None:
        sign_exit_hours = max((30.0 - sign_degree(moon["longitude"])) / max(moon["speed"], 0.0001) * 24.0, 0.0)
        sign_exit_dt = chart_dt + timedelta(hours=sign_exit_hours)
    current_sign_index = zodiac_sign_index(moon["longitude"])
    next_sign = SIGNS[(current_sign_index + 1) % 12]

    upcoming_events: list[tuple[datetime, dict[str, Any]]] = []
    for target_id in ["SUN", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]:
        target = planet_by_id[target_id]
        for aspect_id, angle in CLASSICAL_ANGLES.items():
            exact = next_exact_for_pair(chart_dt, "MOON", target_id, angle, warnings, warning_keys, max_days=4, step_hours=1, sidereal=sidereal)
            if exact is None:
                continue
            upcoming_events.append((exact, make_aspect_event(exact, moon, target, aspect_id)))

    upcoming_events.sort(key=lambda item: item[0])
    before_sign_exit_events = [
        item
        for item in upcoming_events
        if item[0] <= sign_exit_dt
        and not body_exits_sign_before(chart_dt, item[0], item[1]["target_id"], warnings, warning_keys, sidereal=sidereal)
    ]
    upcoming = [event for _exact, event in upcoming_events]
    before_sign_exit = [event for _exact, event in before_sign_exit_events]

    previous_events: list[tuple[datetime, dict[str, Any]]] = []
    for target_id in ["SUN", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]:
        target = planet_by_id[target_id]
        for aspect_id, angle in CLASSICAL_ANGLES.items():
            exact = previous_exact_for_pair(chart_dt, "MOON", target_id, angle, warnings, warning_keys, max_days=4, step_hours=1, sidereal=sidereal)
            if exact is None:
                continue
            previous_events.append((exact, make_aspect_event(exact, moon, target, aspect_id)))
    previous_events.sort(key=lambda item: item[0], reverse=True)
    previous_rows = [event for _exact, event in previous_events]

    after_ingress_start = sign_exit_dt + timedelta(minutes=1)
    after_ingress_events: list[tuple[datetime, dict[str, Any]]] = []
    for target_id in ["SUN", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]:
        target = planet_by_id[target_id]
        for aspect_id, angle in CLASSICAL_ANGLES.items():
            exact = next_exact_for_pair(after_ingress_start, "MOON", target_id, angle, warnings, warning_keys, max_days=4, step_hours=1, sidereal=sidereal)
            if exact is None:
                continue
            after_ingress_events.append((exact, make_aspect_event(exact, moon, target, aspect_id)))
    after_ingress_events.sort(key=lambda item: item[0])
    after_ingress_rows = [event for _exact, event in after_ingress_events]

    return {
        "current_position": moon["degree_text"],
        "current_house": moon["house"],
        "last_aspect": previous_rows[0] if previous_rows else None,
        "last_aspect_time": previous_rows[0]["exact_local"] if previous_rows else "",
        "next_aspect": before_sign_exit[0] if before_sign_exit else None,
        "next_aspect_time": before_sign_exit[0]["exact_local"] if before_sign_exit else "",
        "upcoming_aspects": upcoming[:8],
        "before_sign_exit_aspects": before_sign_exit,
        "voc": len(before_sign_exit) == 0,
        "sign_exit_local": format_local(sign_exit_dt),
        "next_sign": next_sign,
        "next_sign_ingress_time": format_local(sign_exit_dt),
        "first_after_ingress": after_ingress_rows[0] if after_ingress_rows else None,
        "first_after_ingress_time": after_ingress_rows[0]["exact_local"] if after_ingress_rows else "",
    }


def house_rulers(houses: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [
        {
            "house": row["house"],
            "sign": row["sign"],
            "ruler": row["ruler"],
        }
        for row in houses
    ]


def radicality_flags(snapshot: dict[str, Any], moon_story: dict[str, Any]) -> list[dict[str, Any]]:
    flags: list[dict[str, Any]] = []
    asc = next(row for row in snapshot["angles"] if row["id"] == "ASC")
    asc_degree = sign_degree(asc["longitude"])
    if asc_degree < 3:
        flags.append({"id": "asc_early", "label": "ASC 早度", "severity": "caution"})
    if asc_degree > 27:
        flags.append({"id": "asc_late", "label": "ASC 晚度", "severity": "caution"})
    saturn = next((row for row in snapshot["planets"] if row["id"] == "SATURN"), None)
    if saturn and saturn["house"] == 7:
        flags.append({"id": "saturn_in_7", "label": "土星在 7 宫", "severity": "caution"})
    if moon_story["voc"]:
        flags.append({"id": "moon_voc", "label": "Moon VOC", "severity": "caution"})
    return flags


def machine_summary(snapshot: dict[str, Any], moon_story: dict[str, Any], flags: list[dict[str, Any]]) -> list[str]:
    moon = next(row for row in snapshot["planets"] if row["id"] == "MOON")
    summary = [
        f"Moon 位于第 {moon['house']} 宫，{moon['degree_text']}，{moon['motion']}。",
        f"Moon 将于 {moon_story['sign_exit_local']} 左右离开当前星座。",
        f"Moon VOC：{'是' if moon_story['voc'] else '否'}。",
    ]
    if moon_story["next_aspect"]:
        summary.append(
            f"Moon 下一关键相位：{moon_story['next_aspect']['aspect_name']} {moon_story['next_aspect']['target_name']}，约 {moon_story['next_aspect']['exact_local']}。"
        )
    if flags:
        summary.append("Radicality Flags：" + "、".join(flag["label"] for flag in flags) + "。")
    return summary


def infer_matter_role(question_text: str, house_ruler_rows: list[dict[str, Any]]) -> tuple[int, str]:
    lowered = question_text.lower()
    for keywords, config in QUESTION_PATTERNS:
        if any(keyword in lowered for keyword in keywords):
            house = config["house"]
            ruler = next((row["ruler"] for row in house_ruler_rows if row["house"] == house), "")
            return house, ruler
    return 0, ""


def infer_natural_significator(question_text: str) -> str:
    lowered = question_text.lower()
    for keywords, config in QUESTION_PATTERNS:
        if any(keyword in lowered for keyword in keywords):
            return config["natural"]
    return ""


def condition_text(planet_row: dict[str, Any]) -> str:
    return f"{planet_row['motion']}, score {planet_row['score']}"


def significator_candidates(question_text: str, snapshot: dict[str, Any]) -> list[dict[str, Any]]:
    house_ruler_rows = house_rulers(snapshot["houses"])
    planet_by_name = {row["name"]: row for row in snapshot["planets"]}
    planet_by_id = {row["id"]: row for row in snapshot["planets"]}

    querent_house_ruler = house_ruler_rows[0]
    matter_house, matter_ruler_name = infer_matter_role(question_text, house_ruler_rows)
    natural_id = infer_natural_significator(question_text)
    querent_row = planet_by_name.get(querent_house_ruler["ruler"])
    moon_row = planet_by_id["MOON"]
    matter_row = planet_by_name.get(matter_ruler_name)
    natural_row = planet_by_id.get(natural_id)

    rows: list[dict[str, Any]] = []
    if querent_row:
        rows.append(
            {
                "id": "querent",
                "role": "Querent",
                "planet": querent_row["name"],
                "source": "1H ruler",
                "position": querent_row["degree_text"],
                "house": querent_row["house"],
                "condition": condition_text(querent_row),
                "planet_id": querent_row["id"],
            }
        )
    rows.append(
        {
            "id": "moon",
            "role": "Moon",
            "planet": moon_row["name"],
            "source": "General significator",
            "position": moon_row["degree_text"],
            "house": moon_row["house"],
            "condition": condition_text(moon_row),
            "planet_id": moon_row["id"],
        }
    )
    if matter_row:
        rows.append(
            {
                "id": "matter",
                "role": "Matter / Outcome",
                "planet": matter_row["name"],
                "source": f"{matter_house}H ruler",
                "position": matter_row["degree_text"],
                "house": matter_row["house"],
                "condition": condition_text(matter_row),
                "planet_id": matter_row["id"],
            }
        )
    else:
        rows.append(
            {
                "id": "matter_unknown",
                "role": "Matter / Outcome",
                "planet": "unknown",
                "source": "question text insufficient",
                "position": "",
                "house": 0,
                "condition": "",
                "planet_id": "",
            }
        )
    if natural_row:
        rows.append(
            {
                "id": "natural",
                "role": "Natural significator",
                "planet": natural_row["name"],
                "source": "Natural ruler",
                "position": natural_row["degree_text"],
                "house": natural_row["house"],
                "condition": condition_text(natural_row),
                "planet_id": natural_row["id"],
            }
        )
    else:
        rows.append(
            {
                "id": "natural_unknown",
                "role": "Natural significator",
                "planet": "unknown",
                "source": "question text insufficient",
                "position": "",
                "house": 0,
                "condition": "",
                "planet_id": "",
            }
        )
    return rows


def pair_reception_summary(left_name: str, right_name: str, receptions: list[dict[str, Any]]) -> str:
    matches = [
        row for row in receptions
        if (row["receiver"] == left_name and row["received"] == right_name)
        or (row["receiver"] == right_name and row["received"] == left_name)
    ]
    if not matches:
        return ""
    strongest = sorted(matches, key=lambda row: row.get("strength_score", 0), reverse=True)[0]
    return f"{strongest['receiver']} receives {strongest['received']} ({strongest.get('strength_label', '')})"


def exact_time_for_signature(
    chart_dt: datetime,
    left_row: dict[str, Any],
    right_row: dict[str, Any],
    signature: tuple[str, str, float | None, str | None, str | None] | None,
    warnings: list[str],
    sidereal: bool = False,
) -> tuple[bool, str]:
    exact = exact_datetime_for_signature(chart_dt, left_row, right_row, signature, warnings, sidereal=sidereal)
    if exact is None:
        return False, ""
    return True, format_local(exact)


def exact_datetime_for_signature(
    chart_dt: datetime,
    left_row: dict[str, Any],
    right_row: dict[str, Any],
    signature: tuple[str, str, float | None, str | None, str | None] | None,
    warnings: list[str],
    sidereal: bool = False,
) -> datetime | None:
    if signature is None:
        return None
    if same_body(left_row, right_row):
        return None
    aspect_name, aspect_type, _orb, applying, _ = signature
    if aspect_type != "degree" or applying != "入相":
        return None
    warning_keys: set[str] = set()
    aspect_id = next((key for key, name in ASPECT_NAMES.items() if name == aspect_name), None)
    if aspect_id is None:
        return None
    deadline = perfection_deadline_for_pair(
        chart_dt,
        left_row["id"],
        right_row["id"],
        warnings,
        warning_keys,
        sidereal=sidereal,
    )
    exact = next_exact_for_pair(
        chart_dt,
        left_row["id"],
        right_row["id"],
        CLASSICAL_ANGLES[aspect_id],
        warnings,
        warning_keys,
        max_days=exact_search_days_until(chart_dt, deadline),
        step_hours=6,
        sidereal=sidereal,
    )
    if exact is None:
        return None
    if deadline is not None and exact > deadline:
        return None
    if body_exits_sign_before(chart_dt, exact, left_row["id"], warnings, warning_keys, sidereal=sidereal):
        return None
    if body_exits_sign_before(chart_dt, exact, right_row["id"], warnings, warning_keys, sidereal=sidereal):
        return None
    return exact


def key_significator_links(
    chart_dt: datetime,
    candidates: list[dict[str, Any]],
    planet_rows: list[dict[str, Any]],
    receptions: list[dict[str, Any]],
    moon_story: dict[str, Any],
    warnings: list[str],
    aspect_orb: float,
    sidereal: bool = False,
) -> list[dict[str, Any]]:
    by_role = {row["role"]: row for row in candidates if row["planet_id"]}
    by_id = {row["id"]: row for row in planet_rows}
    pairs = [
        ("Querent ruler", by_role.get("Querent"), "Matter ruler", by_role.get("Matter / Outcome")),
        ("Moon", by_role.get("Moon"), "Matter ruler", by_role.get("Matter / Outcome")),
        ("Querent ruler", by_role.get("Querent"), "Natural significator", by_role.get("Natural significator")),
    ]
    rows: list[dict[str, Any]] = []
    for left_label, left_meta, right_label, right_meta in pairs:
        if left_meta is None or right_meta is None:
            continue
        left_row = by_id.get(left_meta["planet_id"])
        right_row = by_id.get(right_meta["planet_id"])
        if left_row is None or right_row is None:
            continue
        if same_body(left_row, right_row):
            rows.append(
                {
                    "id": f"{left_row['id']}|{right_row['id']}|link",
                    "pair": f"{left_label} – {right_label}",
                    "aspect": "",
                    "type": "",
                    "orb": None,
                    "applying": "",
                    "perfects_before_sign_exit": False,
                    "next_perfection": "",
                    "perfection_reason": "same significator",
                    "reception": "",
                }
            )
            continue
        signature = classical_aspect_signature(left_row, right_row, aspect_orb)
        aspect = ""
        aspect_type = ""
        orb = None
        applying = ""
        perfection_reason = "no degree aspect"
        if signature is not None:
            aspect, aspect_type, orb, applying_value, _ = signature
            applying = applying_value or ""
            if aspect_type in {"sign", "co_presence"}:
                perfection_reason = "sign-based only"
            elif applying != "入相":
                perfection_reason = "separating"
            else:
                perfection_reason = "degree aspect applies"
        if left_row["id"] == "MOON" and right_row["id"] != "MOON":
            moon_exact = next(
                (row for row in moon_story["before_sign_exit_aspects"] if row["target_id"] == right_row["id"]),
                None,
            )
            if moon_exact is not None:
                aspect = moon_exact["aspect_name"]
                aspect_type = "degree"
                aspect_angle = CLASSICAL_ANGLES.get(moon_exact["aspect_id"])
                orb = degree_orb_between_rows(left_row, right_row, aspect_angle) if aspect_angle is not None else None
                applying = "入相"
                rows.append(
                    {
                        "id": f"{left_row['id']}|{right_row['id']}|link",
                        "pair": f"{left_label} – {right_label}",
                        "aspect": aspect,
                        "type": aspect_type,
                        "orb": orb,
                        "applying": applying,
                        "perfects_before_sign_exit": True,
                        "next_perfection": moon_exact["exact_local"],
                        "perfection_reason": "degree perfection before Moon sign exit",
                        "reception": pair_reception_summary(left_row["name"], right_row["name"], receptions),
                    }
                )
                continue
        perfects, exact_time = exact_time_for_signature(chart_dt, left_row, right_row, signature, warnings, sidereal=sidereal)
        if perfects:
            perfection_reason = "degree perfection"
        rows.append(
            {
                "id": f"{left_row['id']}|{right_row['id']}|link",
                "pair": f"{left_label} – {right_label}",
                "aspect": aspect,
                "type": aspect_type,
                "orb": orb,
                "applying": applying,
                "perfects_before_sign_exit": perfects,
                "next_perfection": exact_time,
                "perfection_reason": perfection_reason,
                "reception": pair_reception_summary(left_row["name"], right_row["name"], receptions),
            }
        )
    return rows


def degree_based_key_aspects(
    chart_dt: datetime,
    candidates: list[dict[str, Any]],
    planet_rows: list[dict[str, Any]],
    warnings: list[str],
    aspect_orb: float,
    sidereal: bool = False,
) -> list[dict[str, Any]]:
    by_id = {row["id"]: row for row in planet_rows}
    candidate_ids: list[str] = []
    for candidate in candidates:
        planet_id = candidate.get("planet_id", "")
        if planet_id and planet_id not in candidate_ids:
            candidate_ids.append(planet_id)

    rows: list[dict[str, Any]] = []
    for index, left_id in enumerate(candidate_ids):
        left_row = by_id.get(left_id)
        if left_row is None:
            continue
        for right_id in candidate_ids[index + 1 :]:
            right_row = by_id.get(right_id)
            if right_row is None:
                continue
            signature = classical_aspect_signature(left_row, right_row, aspect_orb)
            if signature is None or signature[1] != "degree":
                continue
            aspect_name, _aspect_type, orb, applying, _ = signature
            _perfects, exact_time = exact_time_for_signature(chart_dt, left_row, right_row, signature, warnings, sidereal=sidereal)
            rows.append(
                {
                    "id": f"{left_id}|{aspect_name}|{right_id}|degree",
                    "body_a": left_row["name"],
                    "aspect": aspect_name,
                    "body_b": right_row["name"],
                    "orb": orb,
                    "applying": applying or "",
                    "exact_time": exact_time,
                }
            )
    rows.sort(key=lambda row: (row["orb"] if row["orb"] is not None else 999.0, row["body_a"], row["body_b"]))
    return rows


def lot_ruler_condition(lots: list[dict[str, Any]], planet_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    keep = {"fortune", "spirit", "eros", "necessity"}
    planet_by_name = {row["name"]: row for row in planet_rows}
    rows: list[dict[str, Any]] = []
    for lot in lots:
        if lot["id"] not in keep:
            continue
        ruler_row = planet_by_name.get(lot["ruler"])
        notes: list[str] = []
        if ruler_row:
            if ruler_row["bonification"]:
                notes.append("supported by " + "/".join(modifier["source"] for modifier in ruler_row["bonification"]))
            if ruler_row["maltreatment"]:
                notes.append("afflicted by " + "/".join(modifier["source"] for modifier in ruler_row["maltreatment"]))
        rows.append(
            {
                "id": lot["id"],
                "lot": lot["name"],
                "position": lot["degree_text"],
                "house": lot["house"],
                "ruler": lot["ruler"],
                "ruler_condition": condition_text(ruler_row) if ruler_row else "",
                "key_notes": "、".join(notes),
            }
        )
    return rows


def planetary_speeds(planet_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for row in planet_rows:
        threshold = station_speed_threshold(row["id"])
        rows.append(
            {
                "id": row["id"],
                "planet": row["name"],
                "speed": row["speed"],
                "speed_state": row["motion"],
                "station": abs(float(row["speed"])) <= threshold if threshold is not None else False,
            }
        )
    return rows


def solar_condition(planet_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    sun = next(row for row in planet_rows if row["id"] == "SUN")
    rows: list[dict[str, Any]] = []
    for row in planet_rows:
        if row["id"] == "SUN":
            continue
        rows.append(
            {
                "id": row["id"],
                "planet": row["name"],
                "condition": row["solar_phase"],
                "distance_from_sun": angular_separation(row["longitude"], sun["longitude"]),
            }
        )
    return rows


def negative_receptions(
    planet_rows: list[dict[str, Any]],
    receptions: list[dict[str, Any]],
    aspect_orb: float = 8.0,
) -> list[dict[str, Any]]:
    by_name = {row["name"]: row for row in planet_rows}
    by_id = {row["id"]: row for row in planet_rows}
    rows: list[dict[str, Any]] = []

    for receiver_id, receiver_row in by_id.items():
        for received_id, received_row in by_id.items():
            if receiver_id == received_id:
                continue
            sign_idx = zodiac_sign_index(received_row["longitude"])
            debility = ""
            if SIGN_RULERS[(sign_idx + 6) % 12] == receiver_id:
                debility = "detriment"
            elif EXALTATION_RULERS.get((sign_idx + 6) % 12) == receiver_id:
                debility = "fall"
            if not debility:
                continue
            signature = classical_aspect_signature(receiver_row, received_row, aspect_orb)
            if signature is None:
                continue
            aspect_name, _aspect_type, _orb, applying, _ = signature
            strength = "强" if debility == "detriment" and aspect_name in {"合相", "冲相", "刑相"} else "中" if debility == "detriment" else "弱"
            rows.append(
                {
                    "id": f"{receiver_id}|negative|{received_id}|{debility}",
                    "receiver": receiver_row["name"],
                    "received": received_row["name"],
                    "debility": debility,
                    "via_aspect": aspect_name,
                    "strength": strength,
                }
            )

    rows.sort(key=lambda row: (row["receiver"], row["received"], row["debility"]))
    return rows


def significator_rows(
    candidates: list[dict[str, Any]],
    planet_rows: list[dict[str, Any]],
) -> tuple[dict[str, Any] | None, dict[str, Any] | None, dict[str, Any] | None]:
    by_role = {row["role"]: row for row in candidates if row.get("planet_id")}
    moon_meta = by_role.get("Moon")
    querent_meta = by_role.get("Querent")
    matter_meta = by_role.get("Matter / Outcome")
    planet_by_id = {row["id"]: row for row in planet_rows}
    querent_row = planet_by_id.get(querent_meta["planet_id"]) if querent_meta else None
    matter_row = planet_by_id.get(matter_meta["planet_id"]) if matter_meta else None
    moon_row = planet_by_id.get(moon_meta["planet_id"]) if moon_meta else None
    return querent_row, matter_row, moon_row


def degree_signature(
    left_row: dict[str, Any],
    right_row: dict[str, Any],
    aspect_orb: float,
) -> tuple[str, str, float | None, str | None, str | None] | None:
    if same_body(left_row, right_row):
        return None
    signature = classical_aspect_signature(left_row, right_row, aspect_orb)
    if signature is None or signature[1] != "degree":
        return None
    return signature


def _detect_translation(
    candidates: list[dict[str, Any]],
    key_links: list[dict[str, Any]],
    moon_story: dict[str, Any],
    planet_rows: list[dict[str, Any]],
    chart_dt: datetime | None = None,
    warnings: list[str] | None = None,
    aspect_orb: float = 8.0,
    sidereal: bool = False,
) -> dict[str, Any]:
    querent_row, matter_row, moon_row = significator_rows(candidates, planet_rows)

    if not (moon_row and querent_row and matter_row):
        return {"id": "translation", "type": "Translation of Light", "status": "not detected", "details": "缺少关键象征星", "planets": [], "exact_time": None}

    warning_list = warnings if warnings is not None else []
    translators = [moon_row] + [
        row
        for row in planet_rows
        if row["id"] not in {moon_row["id"], querent_row["id"], matter_row["id"]}
    ]
    for translator in translators:
        for separated_row, applying_row in [(querent_row, matter_row), (matter_row, querent_row)]:
            if translator["id"] in {separated_row["id"], applying_row["id"]}:
                continue
            separated_signature = degree_signature(translator, separated_row, aspect_orb)
            applying_signature = degree_signature(translator, applying_row, aspect_orb)
            if not (separated_signature and applying_signature):
                continue
            if separated_signature[3] != "离相" or applying_signature[3] != "入相":
                continue
            exact_time = None
            if chart_dt is not None:
                exact = exact_datetime_for_signature(chart_dt, translator, applying_row, applying_signature, warning_list, sidereal=sidereal)
                if exact is None:
                    continue
                exact_time = format_local(exact)
            return {
                "id": "translation",
                "type": "Translation of Light",
                "status": "detected",
                "details": f"{translator['name']} 先离相于 {separated_row['name']}，再入相于 {applying_row['name']}",
                "planets": [translator["name"], separated_row["name"], applying_row["name"]],
                "exact_time": exact_time,
                "translator": translator["name"],
                "from": separated_row["name"],
                "to": applying_row["name"],
            }

    return {"id": "translation", "type": "Translation of Light", "status": "not detected", "details": "未找到先离相一方、再入相另一方的翻译者", "planets": [], "exact_time": None}


def _detect_collection(
    candidates: list[dict[str, Any]],
    key_aspects: list[dict[str, Any]],
    planet_rows: list[dict[str, Any]],
    chart_dt: datetime | None = None,
    warnings: list[str] | None = None,
    aspect_orb: float = 8.0,
    sidereal: bool = False,
) -> dict[str, Any]:
    querent_row, matter_row, _moon_row = significator_rows(candidates, planet_rows)
    if not (querent_row and matter_row):
        return {"id": "collection", "type": "Collection of Light", "status": "not detected", "details": "缺少关键象征星", "planets": [], "exact_time": None}
    if same_body(querent_row, matter_row):
        return {"id": "collection", "type": "Collection of Light", "status": "not detected", "details": "Querent 与 Matter 是同一征象星，无收集光线判定", "planets": [], "exact_time": None}

    warning_list = warnings if warnings is not None else []
    for collector in planet_rows:
        if collector["id"] in {querent_row["id"], matter_row["id"]}:
            continue
        if abs(float(collector.get("speed", 0.0))) >= abs(float(querent_row.get("speed", 0.0))):
            continue
        if abs(float(collector.get("speed", 0.0))) >= abs(float(matter_row.get("speed", 0.0))):
            continue
        querent_signature = degree_signature(querent_row, collector, aspect_orb)
        matter_signature = degree_signature(matter_row, collector, aspect_orb)
        if not (querent_signature and matter_signature):
            continue
        if querent_signature[3] != "入相" or matter_signature[3] != "入相":
            continue

        exact_times: list[datetime] = []
        if chart_dt is not None:
            for source_row, signature in [(querent_row, querent_signature), (matter_row, matter_signature)]:
                exact = exact_datetime_for_signature(chart_dt, source_row, collector, signature, warning_list, sidereal=sidereal)
                if exact is None:
                    break
                exact_times.append(exact)
            if len(exact_times) != 2:
                continue

        completion_time = format_local(max(exact_times)) if exact_times else None
        return {
            "id": "collection",
            "type": "Collection of Light",
            "status": "detected",
            "details": f"{querent_row['name']} 与 {matter_row['name']} 同时入相于更慢的 {collector['name']}",
            "planets": [querent_row["name"], matter_row["name"], collector["name"]],
            "exact_time": completion_time,
            "collector": collector["name"],
            "from": querent_row["name"],
            "to": matter_row["name"],
        }

    return {"id": "collection", "type": "Collection of Light", "status": "not detected", "details": "未找到两颗征象星同时入相的更慢收集者", "planets": [], "exact_time": None}


def _detect_prohibition(
    candidates: list[dict[str, Any]],
    key_links: list[dict[str, Any]],
    key_aspects: list[dict[str, Any]],
    moon_story: dict[str, Any],
    planet_rows: list[dict[str, Any]],
    chart_dt: datetime | None = None,
    warnings: list[str] | None = None,
    aspect_orb: float = 8.0,
    sidereal: bool = False,
) -> dict[str, Any]:
    querent_row, matter_row, _moon_row = significator_rows(candidates, planet_rows)
    if not (querent_row and matter_row):
        return {"id": "prohibition", "type": "Prohibition", "status": "not evaluated", "details": "缺少关键象征星", "planets": [], "exact_time": None}
    if same_body(querent_row, matter_row):
        return {"id": "prohibition", "type": "Prohibition", "status": "not detected", "details": "Querent 与 Matter 是同一征象星，无主相位可比较", "planets": [], "exact_time": None}

    warning_list = warnings if warnings is not None else []
    main_signature = degree_signature(querent_row, matter_row, aspect_orb)
    if main_signature is None or main_signature[3] != "入相":
        return {"id": "prohibition", "type": "Prohibition", "status": "not detected", "details": "Querent 与 Matter 没有正在入相的主相位", "planets": [], "exact_time": None}

    main_exact: datetime | None = None
    if chart_dt is not None:
        main_exact = exact_datetime_for_signature(chart_dt, querent_row, matter_row, main_signature, warning_list, sidereal=sidereal)
        if main_exact is None:
            return {"id": "prohibition", "type": "Prohibition", "status": "not detected", "details": "主相位未在换座前完成，无法比较禁止顺序", "planets": [], "exact_time": None}

    for third_row in planet_rows:
        if third_row["id"] in {querent_row["id"], matter_row["id"]}:
            continue
        for target_row in [querent_row, matter_row]:
            signature = degree_signature(third_row, target_row, aspect_orb)
            if signature is None or signature[3] != "入相":
                continue
            if chart_dt is not None and main_exact is not None:
                third_exact = exact_datetime_for_signature(chart_dt, third_row, target_row, signature, warning_list, sidereal=sidereal)
                if third_exact is None or third_exact >= main_exact:
                    continue
                return {
                    "id": "prohibition",
                    "type": "Prohibition",
                    "status": "detected",
                    "details": f"{third_row['name']} 先于 Querent 与 Matter 的主相位成相",
                    "planets": [querent_row["name"], matter_row["name"], third_row["name"]],
                    "exact_time": format_local(third_exact),
                    "prohibitor": third_row["name"],
                }

    return {"id": "prohibition", "type": "Prohibition", "status": "not detected", "details": "未检测到禁止相位", "planets": [], "exact_time": None}


def _detect_frustration(
    candidates: list[dict[str, Any]],
    key_links: list[dict[str, Any]],
    key_aspects: list[dict[str, Any]],
    moon_story: dict[str, Any],
    planet_rows: list[dict[str, Any]],
    chart_dt: datetime | None = None,
    warnings: list[str] | None = None,
    aspect_orb: float = 8.0,
    sidereal: bool = False,
) -> dict[str, Any]:
    querent_row, matter_row, _moon_row = significator_rows(candidates, planet_rows)
    if not (querent_row and matter_row):
        return {"id": "frustration", "type": "Frustration", "status": "not evaluated", "details": "缺少关键象征星", "planets": [], "exact_time": None}
    if same_body(querent_row, matter_row):
        return {"id": "frustration", "type": "Frustration", "status": "not detected", "details": "Querent 与 Matter 是同一征象星，无受挫判定", "planets": [], "exact_time": None}

    main_signature = degree_signature(querent_row, matter_row, aspect_orb)
    if main_signature is None or main_signature[3] != "入相":
        return {"id": "frustration", "type": "Frustration", "status": "not detected", "details": "Querent 与 Matter 没有正在入相的主相位", "planets": [], "exact_time": None}

    if chart_dt is None:
        return {"id": "frustration", "type": "Frustration", "status": "not evaluated", "details": "缺少成相时间，无法比较受挫顺序", "planets": [], "exact_time": None}

    warning_list = warnings if warnings is not None else []
    main_exact = exact_datetime_for_signature(chart_dt, querent_row, matter_row, main_signature, warning_list, sidereal=sidereal)
    if main_exact is None:
        return {"id": "frustration", "type": "Frustration", "status": "not detected", "details": "主相位未在换座前完成，无法形成受挫", "planets": [], "exact_time": None}

    querent_speed = abs(float(querent_row.get("speed", 0.0)))
    matter_speed = abs(float(matter_row.get("speed", 0.0)))
    if abs(querent_speed - matter_speed) < 1e-9:
        return {"id": "frustration", "type": "Frustration", "status": "not detected", "details": "两颗征象星速度相近，未判定较慢受挫方", "planets": [], "exact_time": None}

    faster_row, slower_row = (querent_row, matter_row) if querent_speed > matter_speed else (matter_row, querent_row)
    slower_speed = abs(float(slower_row.get("speed", 0.0)))
    for third_row in planet_rows:
        if third_row["id"] in {querent_row["id"], matter_row["id"]}:
            continue
        if abs(float(third_row.get("speed", 0.0))) > slower_speed:
            continue
        third_signature = degree_signature(slower_row, third_row, aspect_orb)
        if third_signature is None or third_signature[3] != "入相":
            continue
        third_exact = exact_datetime_for_signature(chart_dt, slower_row, third_row, third_signature, warning_list, sidereal=sidereal)
        if third_exact is None or third_exact >= main_exact:
            continue
        return {
            "id": "frustration",
            "type": "Frustration",
            "status": "detected",
            "details": f"{slower_row['name']} 先与 {third_row['name']} 成相，使 {faster_row['name']} 无法完成主相位",
            "planets": [faster_row["name"], slower_row["name"], third_row["name"]],
            "exact_time": format_local(third_exact),
            "frustrated_planet": faster_row["name"],
            "frustrating_planet": third_row["name"],
        }

    return {"id": "frustration", "type": "Frustration", "status": "not detected", "details": "未检测到主相位前较慢方先与第三方成相", "planets": [], "exact_time": None}


def advanced_candidates(
    candidates: list[dict[str, Any]],
    key_links: list[dict[str, Any]],
    key_aspects: list[dict[str, Any]],
    moon_story: dict[str, Any],
    planet_rows: list[dict[str, Any]],
    chart_dt: datetime,
    warnings: list[str],
    aspect_orb: float,
    sidereal: bool = False,
) -> list[dict[str, Any]]:
    translation = _detect_translation(candidates, key_links, moon_story, planet_rows, chart_dt, warnings, aspect_orb, sidereal)
    collection = _detect_collection(candidates, key_aspects, planet_rows, chart_dt, warnings, aspect_orb, sidereal)
    prohibition = _detect_prohibition(candidates, key_links, key_aspects, moon_story, planet_rows, chart_dt, warnings, aspect_orb, sidereal)
    frustration = _detect_frustration(candidates, key_links, key_aspects, moon_story, planet_rows, chart_dt, warnings, aspect_orb, sidereal)
    return [translation, collection, prohibition, frustration]


def calculate_horary(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    chart = request["chart"]
    question_text = str(request.get("questionText", "")).strip()
    place_name = str(request.get("placeName", "")).strip()
    aspect_orb = float(request.get("aspectOrb", 3.0))

    chart_dt = moment_to_local_datetime(chart["moment"])
    chart_jd, chart_utc = moment_to_jd(chart["moment"])
    latitude = float(chart["latitude"])
    longitude = float(chart["longitude"])
    house_system = chart.get("houseSystem", "regiomontanus")
    zodiac = chart.get("zodiac", "tropical")
    bounds_system = chart.get("boundsSystem", "egyptian")
    triplicity_system = chart.get("triplicitySystem", "dorothean")

    from astro_backend_core import set_zodiac_mode

    sidereal = set_zodiac_mode(zodiac)
    snapshot = classical_snapshot(
        chart_jd,
        latitude,
        longitude,
        house_system,
        sidereal,
        bounds_system,
        triplicity_system,
        aspect_orb,
        warnings,
    )
    moon_packet = moon_storyline(chart_dt, snapshot["planets"], warnings, sidereal=sidereal)
    radicality = radicality_flags(snapshot, moon_packet)
    house_ruler_rows = house_rulers(snapshot["houses"])
    candidates = significator_candidates(question_text, snapshot)
    key_links = key_significator_links(chart_dt, candidates, snapshot["planets"], snapshot["receptions"], moon_packet, warnings, aspect_orb, sidereal=sidereal)
    key_degree_aspects = degree_based_key_aspects(chart_dt, candidates, snapshot["planets"], warnings, aspect_orb, sidereal=sidereal)
    key_lots = lot_ruler_condition(snapshot["lots"], snapshot["planets"])
    speeds = planetary_speeds(snapshot["planets"])
    solar_conditions = solar_condition(snapshot["planets"])
    negative_reception_rows = negative_receptions(snapshot["planets"], snapshot["receptions"], aspect_orb)
    advanced = advanced_candidates(candidates, key_links, key_degree_aspects, moon_packet, snapshot["planets"], chart_dt, warnings, aspect_orb, sidereal=sidereal)
    summary = machine_summary(snapshot, moon_packet, radicality)

    return {
        "meta": {
            "asked_local": chart_dt.strftime("%Y-%m-%d %H:%M"),
            "asked_utc": chart_utc,
            "place_name": place_name,
            "latitude": latitude,
            "longitude": longitude,
            "sect": "night chart" if not snapshot["is_day"] else "day chart",
            "sun_horizon_status": snapshot["sun_horizon_status"],
            "house_system": snapshot["house_label"],
            "zodiac": "Lahiri Sidereal" if sidereal else "Tropical",
            "bounds_system": "Ptolemaic" if bounds_system == "ptolemaic" else "Egyptian",
            "triplicity_system": "Ptolemaic" if triplicity_system == "ptolemaic" else "Dorothean",
            "ephemeris": ", ".join(sorted(snapshot["ephemerides"])) if snapshot["ephemerides"] else "unknown",
        },
        "question_text": question_text,
        "machine_summary": summary,
        "radicality_flags": radicality,
        "moon_voc_criterion": "Moon perfects applying Ptolemaic aspects to classical planets before sign exit" if not moon_packet["voc"] else "no applying Ptolemaic aspect to classical planets before sign exit",
        "angles": snapshot["angles"],
        "house_rulers": house_ruler_rows,
        "planets": snapshot["planets"],
        "significator_candidates": candidates,
        "moon_storyline": moon_packet,
        "key_significator_links": key_links,
        "degree_based_key_aspects": key_degree_aspects,
        "planetary_speeds": speeds,
        "solar_condition": solar_conditions,
        "negative_receptions": negative_reception_rows,
        "lots_summary": key_lots,
        "advanced_candidates": advanced,
        "houses": snapshot["houses"],
        "lots": snapshot["lots"],
        "aspects": snapshot["aspects"],
        "receptions": snapshot["receptions"],
        "warnings": warnings,
    }
