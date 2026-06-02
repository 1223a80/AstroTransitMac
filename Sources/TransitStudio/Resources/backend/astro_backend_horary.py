from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from astro_backend_classical import EXALTATION_RULERS, SIGN_RULERS, classical_aspect_signature, classical_snapshot
from astro_backend_core import BODY_REGISTRY, SIGNS, angular_separation, format_local, moment_to_jd, moment_to_local_datetime, sign_degree, zodiac_sign_index
from astro_backend_ephemeris import body_longitude_at

CLASSICAL_ANGLES = {
    "conjunction": 0.0,
    "sextile": 60.0,
    "square": 90.0,
    "trine": 120.0,
    "opposition": 180.0,
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


def relative_orb_for_pair_at(
    dt: datetime,
    left_id: str,
    right_id: str,
    angle: float,
    warnings: list[str],
    warning_keys: set[str],
) -> float | None:
    left = body_longitude_at(dt, BODY_REGISTRY[left_id], warnings, warning_keys)
    right = body_longitude_at(dt, BODY_REGISTRY[right_id], warnings, warning_keys)
    if left is None or right is None:
        return None
    left_lon, _ = left
    right_lon, _ = right
    return angular_delta(left_lon, right_lon) - angle


def refine_pair_crossing(
    start: datetime,
    end: datetime,
    left_id: str,
    right_id: str,
    angle: float,
    warnings: list[str],
    warning_keys: set[str],
) -> datetime:
    left = relative_orb_for_pair_at(start, left_id, right_id, angle, warnings, warning_keys)
    if left is None:
        return start + (end - start) / 2

    for _ in range(40):
        middle = start + (end - start) / 2
        value = relative_orb_for_pair_at(middle, left_id, right_id, angle, warnings, warning_keys)
        if value is None:
            return middle
        if abs(value) < 1e-6:
            return middle
        if (left <= 0 <= value) or (left >= 0 >= value):
            end = middle
        else:
            start = middle
            left = value
    return start + (end - start) / 2


def next_exact_for_pair(
    chart_dt: datetime,
    left_id: str,
    right_id: str,
    angle: float,
    warnings: list[str],
    warning_keys: set[str],
    max_days: int,
    step_hours: int,
) -> datetime | None:
    previous = relative_orb_for_pair_at(chart_dt, left_id, right_id, angle, warnings, warning_keys)
    if previous is None:
        return None

    t = chart_dt
    end = chart_dt + timedelta(days=max_days)
    while t < end:
        next_t = min(t + timedelta(hours=step_hours), end)
        next_value = relative_orb_for_pair_at(next_t, left_id, right_id, angle, warnings, warning_keys)
        if next_value is None:
            return None
        if (previous <= 0 <= next_value) or (previous >= 0 >= next_value):
            return refine_pair_crossing(t, next_t, left_id, right_id, angle, warnings, warning_keys)
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
) -> datetime | None:
    previous = relative_orb_for_pair_at(chart_dt, left_id, right_id, angle, warnings, warning_keys)
    if previous is None:
        return None

    t = chart_dt
    end = chart_dt - timedelta(days=max_days)
    while t > end:
        next_t = max(t - timedelta(hours=step_hours), end)
        next_value = relative_orb_for_pair_at(next_t, left_id, right_id, angle, warnings, warning_keys)
        if next_value is None:
            return None
        if (previous <= 0 <= next_value) or (previous >= 0 >= next_value):
            return refine_pair_crossing(next_t, t, left_id, right_id, angle, warnings, warning_keys)
        t = next_t
        previous = next_value
    return None


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
) -> dict[str, Any]:
    planet_by_id = {row["id"]: row for row in planet_rows}
    moon = planet_by_id["MOON"]
    warning_keys: set[str] = set()

    sign_exit_hours = max((30.0 - sign_degree(moon["longitude"])) / max(moon["speed"], 0.0001) * 24.0, 0.0)
    sign_exit_dt = chart_dt + timedelta(hours=sign_exit_hours)
    current_sign_index = zodiac_sign_index(moon["longitude"])
    next_sign = SIGNS[(current_sign_index + 1) % 12]

    upcoming: list[dict[str, Any]] = []
    for target_id in ["SUN", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]:
        target = planet_by_id[target_id]
        for aspect_id, angle in CLASSICAL_ANGLES.items():
            exact = next_exact_for_pair(chart_dt, "MOON", target_id, angle, warnings, warning_keys, max_days=4, step_hours=1)
            if exact is None:
                continue
            upcoming.append(make_aspect_event(exact, moon, target, aspect_id))

    upcoming.sort(key=lambda row: row["exact_local"])
    before_sign_exit = [row for row in upcoming if row["exact_local"] <= format_local(sign_exit_dt)]

    previous_rows: list[dict[str, Any]] = []
    for target_id in ["SUN", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]:
        target = planet_by_id[target_id]
        for aspect_id, angle in CLASSICAL_ANGLES.items():
            exact = previous_exact_for_pair(chart_dt, "MOON", target_id, angle, warnings, warning_keys, max_days=4, step_hours=1)
            if exact is None:
                continue
            previous_rows.append(make_aspect_event(exact, moon, target, aspect_id))
    previous_rows.sort(key=lambda row: row["exact_local"], reverse=True)

    after_ingress_start = sign_exit_dt + timedelta(minutes=1)
    after_ingress_rows: list[dict[str, Any]] = []
    for target_id in ["SUN", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]:
        target = planet_by_id[target_id]
        for aspect_id, angle in CLASSICAL_ANGLES.items():
            exact = next_exact_for_pair(after_ingress_start, "MOON", target_id, angle, warnings, warning_keys, max_days=4, step_hours=1)
            if exact is None:
                continue
            after_ingress_rows.append(make_aspect_event(exact, moon, target, aspect_id))
    after_ingress_rows.sort(key=lambda row: row["exact_local"])

    return {
        "current_position": moon["degree_text"],
        "current_house": moon["house"],
        "last_aspect": previous_rows[0] if previous_rows else None,
        "last_aspect_time": previous_rows[0]["exact_local"] if previous_rows else "",
        "next_aspect": before_sign_exit[0] if before_sign_exit else None,
        "next_aspect_time": before_sign_exit[0]["exact_local"] if before_sign_exit else "",
        "upcoming_aspects": upcoming[:8],
        "before_sign_exit_aspects": before_sign_exit[:8],
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
    signature: tuple[str, str, float | None, str | None] | None,
    warnings: list[str],
) -> tuple[bool, str]:
    if signature is None:
        return False, ""
    aspect_name, aspect_type, _orb, applying, _ = signature
    if aspect_type != "度数" or applying != "入相":
        return False, ""
    warning_keys: set[str] = set()
    aspect_id = next((key for key, name in ASPECT_NAMES.items() if name == aspect_name), None)
    if aspect_id is None:
        return False, ""
    exact = next_exact_for_pair(chart_dt, left_row["id"], right_row["id"], CLASSICAL_ANGLES[aspect_id], warnings, warning_keys, max_days=30, step_hours=6)
    if exact is None:
        return False, ""
    return True, format_local(exact)


def key_significator_links(
    chart_dt: datetime,
    candidates: list[dict[str, Any]],
    planet_rows: list[dict[str, Any]],
    receptions: list[dict[str, Any]],
    moon_story: dict[str, Any],
    warnings: list[str],
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
        signature = classical_aspect_signature(left_row, right_row, 8.0)
        aspect = ""
        aspect_type = ""
        orb = None
        applying = ""
        perfection_reason = "no degree aspect"
        if signature is not None:
            aspect, aspect_type, orb, applying_value, _ = signature
            applying = applying_value or ""
            if aspect_type == "星座":
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
                orb = 0.0
                applying = "applying"
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
        perfects, exact_time = exact_time_for_signature(chart_dt, left_row, right_row, signature, warnings)
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
            signature = classical_aspect_signature(left_row, right_row, 8.0)
            if signature is None or signature[1] != "度数":
                continue
            aspect_name, _aspect_type, orb, applying, _ = signature
            _perfects, exact_time = exact_time_for_signature(chart_dt, left_row, right_row, signature, warnings)
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
        rows.append(
            {
                "id": row["id"],
                "planet": row["name"],
                "speed": row["speed"],
                "speed_state": row["motion"],
                "station": abs(row["speed"]) < 0.05 if row["id"] not in {"SUN", "MOON"} else False,
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
            signature = classical_aspect_signature(receiver_row, received_row, 8.0)
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


def _detect_translation(
    candidates: list[dict[str, Any]],
    key_links: list[dict[str, Any]],
    moon_story: dict[str, Any],
    planet_rows: list[dict[str, Any]],
) -> dict[str, Any]:
    by_role = {row["role"]: row for row in candidates if row.get("planet_id")}
    moon_meta = by_role.get("Moon")
    querent_meta = by_role.get("Querent")
    matter_meta = by_role.get("Matter / Outcome")

    if not (moon_meta and querent_meta and matter_meta):
        return {"id": "translation", "type": "Translation of Light", "status": "not detected", "details": "缺少关键象征星", "planets": [], "exact_time": None}

    planet_by_id = {row["id"]: row for row in planet_rows}
    moon_row = planet_by_id.get(moon_meta["planet_id"])
    querent_row = planet_by_id.get(querent_meta["planet_id"])
    matter_row = planet_by_id.get(matter_meta["planet_id"])

    if not (moon_row and querent_row and matter_row):
        return {"id": "translation", "type": "Translation of Light", "status": "not detected", "details": "无法取得行星数据", "planets": [], "exact_time": None}

    moon_matter_link = next((l for l in key_links if "Moon" in l["pair"] and "Matter" in l["pair"] and l["perfects_before_sign_exit"]), None)
    querent_matter_link = next((l for l in key_links if "Querent" in l["pair"] and "Matter" in l["pair"] and l["perfects_before_sign_exit"]), None)

    if moon_matter_link and querent_matter_link:
        return {
            "id": "translation",
            "type": "Translation of Light",
            "status": "detected",
            "details": f"Moon 与 Matter 精确，Querent ruler 也与 Matter 精确；Moon 充当翻译者",
            "planets": [moon_row["name"], querent_row["name"], matter_row["name"]],
            "exact_time": moon_matter_link.get("next_perfection", ""),
            "translator": moon_row["name"],
            "from": querent_row["name"],
            "to": matter_row["name"],
        }

    moon_querent_link = next((l for l in key_links if "Moon" in l["pair"] and "Querent" in l["pair"] and l["perfects_before_sign_exit"]), None)
    if moon_querent_link:
        return {
            "id": "translation",
            "type": "Translation of Light",
            "status": "detected",
            "details": f"Moon 先与 Querent ruler 精确，再翻译光线给 Matter ruler",
            "planets": [moon_row["name"], querent_row["name"], matter_row["name"]],
            "exact_time": moon_querent_link.get("next_perfection", ""),
            "translator": moon_row["name"],
            "from": querent_row["name"],
            "to": matter_row["name"],
        }

    return {"id": "translation", "type": "Translation of Light", "status": "not detected", "details": "Moon 未能同时连接 Querent 和 Matter", "planets": [], "exact_time": None}


def _detect_collection(
    candidates: list[dict[str, Any]],
    key_aspects: list[dict[str, Any]],
    planet_rows: list[dict[str, Any]],
) -> dict[str, Any]:
    by_role = {row["role"]: row for row in candidates if row.get("planet_id")}
    querent_meta = by_role.get("Querent")
    matter_meta = by_role.get("Matter / Outcome")

    if not (querent_meta and matter_meta):
        return {"id": "collection", "type": "Collection of Light", "status": "not detected", "details": "缺少关键象征星", "planets": [], "exact_time": None}

    planet_by_id = {row["id"]: row for row in planet_rows}
    planet_by_name = {row["name"]: row for row in planet_rows}

    fixed_signs_indices = {1, 4, 7, 10}
    for aspect_row in key_aspects:
        if aspect_row["applying"] != "入相":
            continue
        body_a_name = aspect_row["body_a"]
        body_b_name = aspect_row["body_b"]
        a_row = planet_by_name.get(body_a_name)
        b_row = planet_by_name.get(body_b_name)
        if not (a_row and b_row):
            continue
        a_sign_idx = zodiac_sign_index(a_row["longitude"])
        b_sign_idx = zodiac_sign_index(b_row["longitude"])
        a_fixed = a_sign_idx in fixed_signs_indices
        b_fixed = b_sign_idx in fixed_signs_indices
        a_angle = a_row.get("house", 0) in {1, 4, 7, 10}
        b_angle = b_row.get("house", 0) in {1, 4, 7, 10}

        collector = None
        other = None
        if a_fixed or a_angle:
            collector = a_row
            other = b_row
        elif b_fixed or b_angle:
            collector = b_row
            other = a_row

        if collector:
            return {
                "id": "collection",
                "type": "Collection of Light",
                "status": "detected",
                "details": f"{collector['name']} 在固定星座或角宫，收集 {body_a_name} 和 {body_b_name} 的光线",
                "planets": [body_a_name, body_b_name, collector["name"]],
                "exact_time": None,
                "collector": collector["name"],
                "from": body_a_name,
                "to": body_b_name,
            }

    return {"id": "collection", "type": "Collection of Light", "status": "not detected", "details": "未找到满足条件的收集者", "planets": [], "exact_time": None}


def _detect_prohibition(
    candidates: list[dict[str, Any]],
    key_links: list[dict[str, Any]],
    key_aspects: list[dict[str, Any]],
    moon_story: dict[str, Any],
    planet_rows: list[dict[str, Any]],
) -> dict[str, Any]:
    by_role = {row["role"]: row for row in candidates if row.get("planet_id")}
    querent_meta = by_role.get("Querent")
    matter_meta = by_role.get("Matter / Outcome")

    if not (querent_meta and matter_meta):
        return {"id": "prohibition", "type": "Prohibition", "status": "not evaluated", "details": "缺少关键象征星", "planets": [], "exact_time": None}

    planet_by_id = {row["id"]: row for row in planet_rows}
    planet_by_name = {row["name"]: row for row in planet_rows}

    querent_row = planet_by_id.get(querent_meta["planet_id"])
    matter_row = planet_by_id.get(matter_meta["planet_id"])

    if not (querent_row and matter_row):
        return {"id": "prohibition", "type": "Prohibition", "status": "not evaluated", "details": "无法取得行星数据", "planets": [], "exact_time": None}

    querent_matter_link = next((l for l in key_links if "Querent" in l["pair"] and "Matter" in l["pair"]), None)
    if querent_matter_link and querent_matter_link.get("applying") == "入相":
        for aspect_row in key_aspects:
            if aspect_row["applying"] != "入相":
                continue
            third_name = None
            if aspect_row["body_a"] in {querent_row["name"], matter_row["name"]}:
                third_name = aspect_row["body_b"] if aspect_row["body_a"] == querent_row["name"] else aspect_row["body_a"]
            else:
                continue
            if third_name and third_name not in {querent_row["name"], matter_row["name"]}:
                return {
                    "id": "prohibition",
                    "type": "Prohibition",
                    "status": "detected",
                    "details": f"{third_name} 在 Querent 和 Matter 完成精确相位前介入",
                    "planets": [querent_row["name"], matter_row["name"], third_name],
                    "exact_time": None,
                    "prohibitor": third_name,
                }

    return {"id": "prohibition", "type": "Prohibition", "status": "not detected", "details": "未检测到禁止相位", "planets": [], "exact_time": None}


def _detect_frustration(
    candidates: list[dict[str, Any]],
    key_links: list[dict[str, Any]],
    key_aspects: list[dict[str, Any]],
    moon_story: dict[str, Any],
    planet_rows: list[dict[str, Any]],
) -> dict[str, Any]:
    by_role = {row["role"]: row for row in candidates if row.get("planet_id")}
    querent_meta = by_role.get("Querent")
    matter_meta = by_role.get("Matter / Outcome")

    if not (querent_meta and matter_meta):
        return {"id": "frustration", "type": "Frustration", "status": "not evaluated", "details": "缺少关键象征星", "planets": [], "exact_time": None}

    planet_by_id = {row["id"]: row for row in planet_rows}
    planet_by_name = {row["name"]: row for row in planet_rows}

    querent_row = planet_by_id.get(querent_meta["planet_id"])
    matter_row = planet_by_id.get(matter_meta["planet_id"])

    if not (querent_row and matter_row):
        return {"id": "frustration", "type": "Frustration", "status": "not evaluated", "details": "无法取得行星数据", "planets": [], "exact_time": None}

    for link in key_links:
        if "Querent" in link["pair"] and "Matter" in link["pair"]:
            if link.get("applying") == "离相" or link.get("perfection_reason") == "separating":
                return {
                    "id": "frustration",
                    "type": "Frustration",
                    "status": "detected",
                    "details": f"Querent ruler 与 Matter ruler 正在离相，预期结果受阻",
                    "planets": [querent_row["name"], matter_row["name"]],
                    "exact_time": None,
                    "frustrated_planet": querent_row["name"],
                    "reason": "separating aspect",
                }

    for link in key_links:
        if link.get("applying") == "离相":
            planet_a = link["pair"].split(" – ")[0].strip()
            return {
                "id": "frustration",
                "type": "Frustration",
                "status": "detected",
                "details": f"{planet_a} 正在离相，光线被阻断",
                "planets": [planet_a],
                "exact_time": None,
                "frustrated_planet": planet_a,
                "reason": "separating aspect",
            }

    return {"id": "frustration", "type": "Frustration", "status": "not detected", "details": "未检测到受阻情况", "planets": [], "exact_time": None}


def advanced_candidates(
    candidates: list[dict[str, Any]],
    key_links: list[dict[str, Any]],
    key_aspects: list[dict[str, Any]],
    moon_story: dict[str, Any],
    planet_rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    translation = _detect_translation(candidates, key_links, moon_story, planet_rows)
    collection = _detect_collection(candidates, key_aspects, planet_rows)
    prohibition = _detect_prohibition(candidates, key_links, key_aspects, moon_story, planet_rows)
    frustration = _detect_frustration(candidates, key_links, key_aspects, moon_story, planet_rows)
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
    moon_packet = moon_storyline(chart_dt, snapshot["planets"], warnings)
    radicality = radicality_flags(snapshot, moon_packet)
    house_ruler_rows = house_rulers(snapshot["houses"])
    candidates = significator_candidates(question_text, snapshot)
    key_links = key_significator_links(chart_dt, candidates, snapshot["planets"], snapshot["receptions"], moon_packet, warnings)
    key_degree_aspects = degree_based_key_aspects(chart_dt, candidates, snapshot["planets"], warnings)
    key_lots = lot_ruler_condition(snapshot["lots"], snapshot["planets"])
    speeds = planetary_speeds(snapshot["planets"])
    solar_conditions = solar_condition(snapshot["planets"])
    negative_reception_rows = negative_receptions(snapshot["planets"], snapshot["receptions"])
    advanced = advanced_candidates(candidates, key_links, key_degree_aspects, moon_packet, snapshot["planets"])
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
