from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_core import (
    BODY_REGISTRY,
    BodySpec,
    SIGNS,
    TargetSpec,
    angular_separation,
    aspect_orb,
    format_longitude,
    norm360,
    parse_targets,
    signed_orb,
    zodiac_sign_index,
)
from astro_backend_ephemeris import body_longitude_at, body_speed_at, resolve_bodies


BODY_WEIGHT = {
    "SUN": 1.0,
    "MOON": 0.85,
    "MERCURY": 0.9,
    "VENUS": 1.0,
    "MARS": 1.0,
    "JUPITER": 1.1,
    "SATURN": 1.1,
    "URANUS": 0.85,
    "NEPTUNE": 0.8,
    "PLUTO": 0.85,
}

SCAN_MIN_YEAR = 1800
SCAN_MAX_YEAR = 2100
MAX_SCAN_WORK_UNITS = 500_000

ASPECT_WEIGHT = {
    "conjunction": 1.0,
    "opposition": 0.95,
    "square": 0.9,
    "trine": 0.8,
    "sextile": 0.7,
    "quincunx": 0.7,
    "semisquare": 0.55,
    "sesquisquare": 0.55,
}


def find_aspects(
    transit_positions: list[dict[str, Any]],
    natal_positions: list[dict[str, Any]],
    aspect_specs: list[dict[str, Any]],
    skip_self_aspects: bool = False,
) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    seen_pairs: set[frozenset[str]] = set()

    for transit in transit_positions:
        for natal in natal_positions:
            if skip_self_aspects and transit["body_id"] == natal["body_id"]:
                continue
            pair = frozenset([transit["body_id"], natal["body_id"]])
            if skip_self_aspects and pair in seen_pairs:
                continue
            separation = angular_separation(transit["longitude"], natal["longitude"])
            for aspect in aspect_specs:
                angle = float(aspect["angle"])
                orb_limit = float(aspect["orb"])
                orb = abs(separation - angle)
                if orb <= orb_limit + 1e-9:
                    seen_pairs.add(pair)
                    hits.append(
                        {
                            "id": (
                                f"{transit['body_id']}|{aspect['id']}|"
                                f"{natal['body_id']}|{orb:.8f}"
                            ),
                            "transit_body_id": transit["body_id"],
                            "transit_body_name": transit["name"],
                            "natal_body_id": natal["body_id"],
                            "natal_body_name": natal["name"],
                            "aspect_id": aspect["id"],
                            "aspect_name": aspect["name"],
                            "angle": angle,
                            "separation": separation,
                            "orb": orb,
                        }
                    )

    hits.sort(key=lambda item: (item["orb"], item["transit_body_name"], item["natal_body_name"]))
    return hits


def step_for_body(spec: BodySpec) -> timedelta:
    if spec.body_id == "MOON":
        return timedelta(hours=1)
    if spec.body_id in {"SUN", "MERCURY", "VENUS", "MARS"}:
        return timedelta(hours=3)
    if spec.body_id in {
        "JUPITER",
        "SATURN",
        "MEAN_NODE",
        "TRUE_NODE",
        "SOUTH_MEAN_NODE",
        "SOUTH_TRUE_NODE",
        "CHIRON",
        "PHOLUS",
        "CERES",
        "PALLAS",
        "JUNO",
        "VESTA",
    } or spec.body_id.startswith("AST:"):
        return timedelta(hours=12)
    return timedelta(days=2)


def estimated_steps(start_dt: datetime, end_dt: datetime, spec: BodySpec) -> int:
    seconds = max((end_dt - start_dt).total_seconds(), 0.0)
    step_seconds = max(step_for_body(spec).total_seconds(), 1.0)
    return int(seconds // step_seconds) + 1


def reject_oversized_scan(work_units: int) -> None:
    if work_units > MAX_SCAN_WORK_UNITS:
        raise ValueError(
            f"扫描窗口过大，预计计算量 {work_units}，上限 {MAX_SCAN_WORK_UNITS}。"
            "请缩短时间范围、减少天体/目标点/相位。"
        )


def exact_longitudes_for_aspect(target_lon: float, aspect_angle: float) -> list[float]:
    angle = aspect_angle % 360.0
    exacts = {(target_lon + angle) % 360.0}
    if angle not in {0.0, 180.0}:
        exacts.add((target_lon - angle) % 360.0)
    return sorted(exacts)


def orb_at(
    dt: datetime,
    spec: BodySpec,
    exact_lon: float,
    warnings: list[str],
    warning_keys: set[str],
    sidereal: bool = False,
) -> tuple[float, str] | None:
    calculated = body_longitude_at(dt, spec, warnings, warning_keys, sidereal=sidereal)
    if calculated is None:
        return None
    longitude, ephemeris_name = calculated
    return signed_orb(longitude, exact_lon), ephemeris_name


def refine_crossing(
    t1: datetime,
    t2: datetime,
    spec: BodySpec,
    exact_lon: float,
    warnings: list[str],
    warning_keys: set[str],
    sidereal: bool = False,
) -> datetime:
    first = orb_at(t1, spec, exact_lon, warnings, warning_keys, sidereal=sidereal)
    if first is None:
        return t1 + (t2 - t1) / 2

    f1, _ = first
    for _ in range(50):
        mid = t1 + (t2 - t1) / 2
        middle = orb_at(mid, spec, exact_lon, warnings, warning_keys, sidereal=sidereal)
        if middle is None:
            return mid

        fm, _ = middle
        if abs(fm) < 1e-8:
            return mid
        if (f1 <= 0 <= fm) or (f1 >= 0 >= fm):
            t2 = mid
        else:
            t1 = mid
            f1 = fm
    return t1 + (t2 - t1) / 2


def refine_station(
    t1: datetime,
    t2: datetime,
    spec: BodySpec,
    warnings: list[str],
    warning_keys: set[str],
    sidereal: bool = False,
) -> datetime:
    first = body_speed_at(t1, spec, warnings, warning_keys, sidereal=sidereal)
    if first is None:
        return t1 + (t2 - t1) / 2

    f1, _ = first
    for _ in range(50):
        mid = t1 + (t2 - t1) / 2
        middle = body_speed_at(mid, spec, warnings, warning_keys, sidereal=sidereal)
        if middle is None:
            return mid

        fm, _ = middle
        if abs(fm) < 1e-9:
            return mid
        if (f1 <= 0 <= fm) or (f1 >= 0 >= fm):
            t2 = mid
        else:
            t1 = mid
            f1 = fm
    return t1 + (t2 - t1) / 2


def target_weight(target: TargetSpec) -> float:
    name = target.name.lower()
    if any(key in name for key in ["asc", "mc", "dsc", "ic"]):
        return 1.25
    if "house cusp" in name:
        return 1.0
    if "lot of" in name or "fortune" in name or "spirit" in name:
        return 1.15
    if "sun" in name or "moon" in name:
        return 1.1
    return 1.0


def scan_priority(spec: BodySpec, target: TargetSpec, aspect: dict[str, Any], orb: float) -> tuple[int, str]:
    body_weight = BODY_WEIGHT.get(spec.body_id, 0.65 if spec.body_id.startswith("AST:") else 0.75)
    aspect_weight = ASPECT_WEIGHT.get(aspect["id"], 0.65)
    max_orb = max(float(aspect.get("orb", 0.0)), 0.25)
    orb_factor = max(0.25, 1.0 - min(orb / max_orb, 1.0))
    score = int(round(100 * body_weight * aspect_weight * target_weight(target) * orb_factor))
    if score >= 100:
        grade = "A"
    elif score >= 80:
        grade = "B"
    elif score >= 60:
        grade = "C"
    else:
        grade = "D"
    return score, grade


def scan_response(
    label: str,
    scan_kind: str,
    start_dt: datetime,
    end_dt: datetime,
    rows: list[dict[str, Any]],
    warnings: list[str],
    ephemerides: set[str],
    target_count: int,
) -> dict[str, Any]:
    return {
        "meta": {
            "label": label,
            "scan_kind": scan_kind,
            "start_utc": start_dt.astimezone(timezone.utc).isoformat(),
            "end_utc": end_dt.astimezone(timezone.utc).isoformat(),
            "ephemeris": ", ".join(sorted(ephemerides)) if ephemerides else "unknown",
            "target_count": target_count,
        },
        "hits": rows,
        "warnings": warnings,
    }


def scan_ingresses(
    start_dt: datetime,
    end_dt: datetime,
    bodies: list[BodySpec],
    label: str,
    warnings: list[str],
) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    warning_keys: set[str] = set()
    ephemerides: set[str] = set()

    for spec in bodies:
        t_prev = start_dt
        previous = body_longitude_at(t_prev, spec, warnings, warning_keys)
        if previous is None:
            continue
        lon_prev, ephemeris_name = previous
        ephemerides.add(ephemeris_name)

        while t_prev < end_dt:
            t_next = min(t_prev + step_for_body(spec), end_dt)
            next_value = body_longitude_at(t_next, spec, warnings, warning_keys)
            if next_value is None:
                break
            lon_next, ephemeris_name = next_value
            ephemerides.add(ephemeris_name)
            sign_prev = zodiac_sign_index(lon_prev)
            sign_next = zodiac_sign_index(lon_next)
            distance = abs(signed_orb(lon_next, lon_prev))

            if sign_prev != sign_next and distance < 20:
                direction = 1 if signed_orb(lon_next, lon_prev) > 0 else -1
                boundary_sign = sign_next if direction > 0 else sign_prev
                exact_lon = boundary_sign * 30.0
                exact_t = refine_crossing(t_prev, t_next, spec, exact_lon, warnings, warning_keys)
                exact_result = body_longitude_at(exact_t, spec, warnings, warning_keys)
                if exact_result is not None:
                    exact_body_lon, ephemeris_name = exact_result
                    ephemerides.add(ephemeris_name)
                    _, position_text = format_longitude(exact_body_lon)
                    target_sign = SIGNS[boundary_sign % 12]
                    motion = "顺行进入" if direction > 0 else "逆行退回"
                    rows.append(
                        {
                            "id": f"{spec.body_id}|ingress|{boundary_sign}|{exact_t.strftime('%Y%m%d%H%M')}",
                            "window": label,
                            "date_time_local": exact_t.strftime("%Y-%m-%d %H:%M"),
                            "transit_body_id": spec.body_id,
                            "transit_body_name": spec.name,
                            "aspect_id": "ingress",
                            "aspect_name": motion,
                            "target_name": target_sign,
                            "target_longitude": exact_lon,
                            "transit_longitude": exact_body_lon,
                            "transit_position": position_text,
                            "exact_longitude": exact_lon,
                            "priority_score": 0,
                            "priority_grade": "E",
                        }
                    )

            t_prev = t_next
            lon_prev = lon_next

    rows.sort(key=lambda row: row["date_time_local"])
    return scan_response(label, "ingress", start_dt, end_dt, rows, warnings, ephemerides, 0)


def scan_stations(
    start_dt: datetime,
    end_dt: datetime,
    bodies: list[BodySpec],
    label: str,
    warnings: list[str],
) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    warning_keys: set[str] = set()
    ephemerides: set[str] = set()

    for spec in bodies:
        if spec.body_id in {"SUN", "MOON"}:
            continue
        t_prev = start_dt
        previous = body_speed_at(t_prev, spec, warnings, warning_keys)
        if previous is None:
            continue
        speed_prev, ephemeris_name = previous
        ephemerides.add(ephemeris_name)

        while t_prev < end_dt:
            t_next = min(t_prev + step_for_body(spec), end_dt)
            next_value = body_speed_at(t_next, spec, warnings, warning_keys)
            if next_value is None:
                break
            speed_next, ephemeris_name = next_value
            ephemerides.add(ephemeris_name)
            crossed = (speed_prev <= 0 <= speed_next) or (speed_prev >= 0 >= speed_next)

            if crossed and speed_prev != speed_next:
                exact_t = refine_station(t_prev, t_next, spec, warnings, warning_keys)
                exact_result = body_longitude_at(exact_t, spec, warnings, warning_keys)
                exact_speed = body_speed_at(exact_t, spec, warnings, warning_keys)
                if exact_result is not None and exact_speed is not None:
                    exact_body_lon, ephemeris_name = exact_result
                    speed_at_exact, _ = exact_speed
                    ephemerides.add(ephemeris_name)
                    _, position_text = format_longitude(exact_body_lon)
                    station_kind = "顺行站" if speed_prev < speed_next else "逆行站"
                    rows.append(
                        {
                            "id": f"{spec.body_id}|station|{station_kind}|{exact_t.strftime('%Y%m%d%H%M')}",
                            "window": label,
                            "date_time_local": exact_t.strftime("%Y-%m-%d %H:%M"),
                            "transit_body_id": spec.body_id,
                            "transit_body_name": spec.name,
                            "aspect_id": "station",
                            "aspect_name": station_kind,
                            "target_name": f"速度 {speed_at_exact:.8f}°/日",
                            "target_longitude": exact_body_lon,
                            "transit_longitude": exact_body_lon,
                            "transit_position": position_text,
                            "exact_longitude": exact_body_lon,
                            "priority_score": 0,
                            "priority_grade": "E",
                        }
                    )

            t_prev = t_next
            speed_prev = speed_next

    rows.sort(key=lambda row: row["date_time_local"])
    return scan_response(label, "station", start_dt, end_dt, rows, warnings, ephemerides, 0)


def scan_window(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    from astro_backend_core import moment_to_local_datetime

    start_dt = moment_to_local_datetime(request["start"])
    end_dt = moment_to_local_datetime(request["end"])
    original_start_dt = start_dt
    original_end_dt = end_dt
    min_dt = start_dt.replace(year=SCAN_MIN_YEAR, month=1, day=1, hour=0, minute=0, second=0, microsecond=0)
    max_dt = end_dt.replace(year=SCAN_MAX_YEAR, month=12, day=31, hour=23, minute=59, second=0, microsecond=0)
    if start_dt < min_dt:
        start_dt = min_dt
    if end_dt > max_dt:
        end_dt = max_dt
    if start_dt != original_start_dt or end_dt != original_end_dt:
        warnings.append(f"扫描窗口已限制在 {SCAN_MIN_YEAR}-01-01 至 {SCAN_MAX_YEAR}-12-31。")
    if end_dt <= start_dt:
        raise ValueError(f"扫描窗口必须落在 {SCAN_MIN_YEAR}-01-01 至 {SCAN_MAX_YEAR}-12-31 之间")

    bodies = resolve_bodies(
        request.get("transitBodies", []),
        [int(value) for value in request.get("customAsteroids", [])],
        warnings,
    )
    moon_filter = str(request.get("moonFilter", "")).lower()
    if moon_filter == "exclude":
        bodies = [spec for spec in bodies if spec.body_id != "MOON"]
    elif moon_filter == "only":
        bodies = [spec for spec in bodies if spec.body_id == "MOON"] or [BODY_REGISTRY["MOON"]]

    label = (request.get("label") or "Transit window").strip()
    scan_kind = request.get("scanKind", "aspect")
    if scan_kind == "ingress":
        reject_oversized_scan(sum(estimated_steps(start_dt, end_dt, spec) for spec in bodies))
        return scan_ingresses(start_dt, end_dt, bodies, label, warnings)
    if scan_kind == "station":
        station_bodies = [spec for spec in bodies if spec.body_id not in {"SUN", "MOON"}]
        reject_oversized_scan(sum(estimated_steps(start_dt, end_dt, spec) for spec in station_bodies))
        return scan_stations(start_dt, end_dt, bodies, label, warnings)

    targets = parse_targets(request.get("targetText", ""))
    aspects = request.get("aspects", [])
    aspect_exact_count = sum(len(exact_longitudes_for_aspect(0.0, float(aspect["angle"]))) for aspect in aspects)
    work_units = (
        sum(estimated_steps(start_dt, end_dt, spec) for spec in bodies)
        * max(len(targets), 1)
        * max(aspect_exact_count, 1)
    )
    reject_oversized_scan(work_units)
    rows: list[dict[str, Any]] = []
    seen_hits: set[str] = set()
    warning_keys: set[str] = set()
    ephemerides: set[str] = set()

    for spec in bodies:
        step = step_for_body(spec)
        for target in targets:
            for aspect in aspects:
                aspect_angle = float(aspect["angle"])
                for exact_lon in exact_longitudes_for_aspect(target.longitude, aspect_angle):
                    t_prev = start_dt
                    previous = orb_at(t_prev, spec, exact_lon, warnings, warning_keys)
                    if previous is None:
                        continue
                    f_prev, ephemeris_name = previous
                    ephemerides.add(ephemeris_name)

                    while t_prev < end_dt:
                        t_next = min(t_prev + step, end_dt)
                        next_value = orb_at(t_next, spec, exact_lon, warnings, warning_keys)
                        if next_value is None:
                            break
                        f_next, ephemeris_name = next_value
                        ephemerides.add(ephemeris_name)

                        if abs(f_prev - f_next) < 20:
                            crossed = (f_prev <= 0 <= f_next) or (f_prev >= 0 >= f_next)
                            if crossed:
                                exact_t = refine_crossing(t_prev, t_next, spec, exact_lon, warnings, warning_keys)
                                longitude_result = body_longitude_at(exact_t, spec, warnings, warning_keys)
                                if longitude_result is not None:
                                    p_lon, ephemeris_name = longitude_result
                                    ephemerides.add(ephemeris_name)
                                    _, transit_position = format_longitude(p_lon)
                                    _, target_position = format_longitude(target.longitude)
                                    _, exact_transit_position = format_longitude(exact_lon)
                                    exact_orb = aspect_orb(p_lon, target.longitude, aspect_angle)
                                    phase = "applying" if abs(f_prev) > abs(f_next) else "separating"
                                    priority_score, priority_grade = scan_priority(spec, target, aspect, exact_orb)
                                    hit_key = (
                                        f"{spec.body_id}|{aspect['id']}|{target.name}|"
                                        f"{exact_lon:.6f}|{exact_t.strftime('%Y%m%d%H%M')}"
                                    )
                                    if hit_key not in seen_hits:
                                        rows.append(
                                            {
                                                "id": hit_key,
                                                "window": label,
                                                "date_time_local": exact_t.strftime("%Y-%m-%d %H:%M"),
                                                "transit_body_id": spec.body_id,
                                                "transit_body_name": spec.name,
                                                "aspect_id": aspect["id"],
                                                "aspect_name": aspect["name"],
                                                "aspect_angle": aspect_angle,
                                                "target_name": target.name,
                                                "target_longitude": target.longitude,
                                                "target_position": target_position,
                                                "transit_longitude": p_lon,
                                                "transit_position": transit_position,
                                                "exact_transit_position": exact_transit_position,
                                                "exact_longitude": exact_lon,
                                                "orb": exact_orb,
                                                "phase": phase,
                                                "scan_step": str(step),
                                                "exact_method": "bisection",
                                                "max_orb": float(aspect.get("orb", 0.0)),
                                                "priority_score": priority_score,
                                                "priority_grade": priority_grade,
                                            }
                                        )
                                        seen_hits.add(hit_key)

                        t_prev = t_next
                        f_prev = f_next

    rows.sort(key=lambda row: (-row.get("priority_score", 0), row["date_time_local"]))
    return scan_response(label, "aspect", start_dt, end_dt, rows, warnings, ephemerides, len(targets))
