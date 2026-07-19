"""Dynamic declination timeline: parallel / contraparallel / OOB / declination stations.

mode=declination_timing

Reuses modern_timing root primitives (_find_roots, _refine_root, _lifecycle_bounds)
and real Swiss Ephemeris equatorial coordinates (not longitude-only approximations)
for moving bodies. OOB threshold uses true ecliptic obliquity at each event time.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Optional
from zoneinfo import ZoneInfo

from astro_backend_core import (
    BODY_REGISTRY,
    CLASSICAL_BODY_IDS,
    declination_from_lon,
    jd_from_datetime,
    moment_to_jd,
    moment_to_local_datetime,
    obliquity as mean_obliquity,
    resolve_timezone,
    set_zodiac_mode,
    swe,
)
from astro_backend_ephemeris import (
    build_houses,
    calculate_positions,
    house_for_longitude,
    resolve_bodies,
)
from astro_backend_modern_points import finalize_point_set, resolve_point_set
from astro_backend_modern_timing import (
    EXACT_DEDUPE_SECONDS,
    _dedupe_and_number_events,
    _find_roots,
    _id_stamp,
    _lifecycle_bounds,
    _refine_root,
    _step_for,
)
from astro_backend_scan import step_for_body

METHOD = "declination_timing_v1"
SCHEMA_VERSION = 1
COORDINATE_KIND = "declination"

EVENT_TYPES = (
    "parallel",
    "contraparallel",
    "oob_entry",
    "oob_exit",
    "declination_station",
)

DEFAULT_EVENT_TYPES = list(EVENT_TYPES)
DEFAULT_ORB = 1.0
DEFAULT_MOVING = ["MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]

ANGLE_NAMES = {
    "ASC": "ASC",
    "MC": "MC",
    "DSC": "DSC",
    "IC": "IC",
    "VERTEX": "Vertex",
    "ANTIVERTEX": "Antivertex",
    "EQUATORIAL_ASCENDANT": "East Point (Equatorial Ascendant)",
}

NumericEvaluator = Callable[[datetime], Optional[float]]


@dataclass(frozen=True)
class DeclValue:
    declination: float
    declination_speed: float
    longitude: float
    name: str
    ephemeris: str
    out_of_bounds: bool
    oob_threshold: float
    threshold_method: str


@dataclass(frozen=True)
class NatalTarget:
    point_id: str
    name: str
    kind: str
    declination: float
    longitude: float | None
    method: str


def _iso_utc(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.astimezone(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _iso_local(value: datetime, display_zone: ZoneInfo) -> str:
    return value.astimezone(display_zone).isoformat(timespec="milliseconds")


def _motion_from_speed(speed: float) -> str:
    if speed > 1e-9:
        return "direct"
    if speed < -1e-9:
        return "retrograde"
    return "stationary"


def true_obliquity(jd: float) -> tuple[float, str]:
    """Return (obliquity_deg, method_key). Prefer true obliquity via ECL_NUT."""
    try:
        values, _ = swe.calc_ut(jd, swe.ECL_NUT)
        # SE: values[0] = true obliquity, values[1] = mean obliquity
        true_val = float(values[0])
        if math.isfinite(true_val) and 20.0 < true_val < 26.0:
            return true_val, "true_obliquity_ecl_nut"
    except Exception:
        pass
    return float(mean_obliquity(jd)), "mean_obliquity_iau_fallback"


def body_declination_at(
    at_utc: datetime,
    body_id: str,
    warnings: list[str],
    warning_keys: set[str],
) -> DeclValue | None:
    """Real equatorial declination + speed for a registered / asteroid body."""
    if body_id in BODY_REGISTRY:
        spec = BODY_REGISTRY[body_id]
    elif body_id.startswith("AST:"):
        try:
            number = int(body_id.split(":", 1)[1])
        except (TypeError, ValueError):
            return None
        specs = resolve_bodies([], [number], warnings)
        if not specs:
            return None
        spec = specs[0]
    else:
        return None

    jd = jd_from_datetime(at_utc)
    threshold, threshold_method = true_obliquity(jd)
    flags = swe.FLG_SWIEPH | swe.FLG_EQUATORIAL | swe.FLG_SPEED
    try:
        values, _ = swe.calc_ut(jd, spec.code, flags)
        dec = float(values[1])
        dec_speed = float(values[4]) if len(values) > 4 else 0.0
        # South Node reuses North Node code with longitude_offset=180.
        if spec.body_id in ("SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE"):
            dec = -dec
            dec_speed = -dec_speed
        ephemeris = "Swiss Ephemeris"
    except swe.Error as exc:
        key = f"{spec.body_id}:eq_failed"
        if key not in warning_keys:
            warnings.append(f"{spec.name} 赤道坐标失败，跳过赤纬事件：{exc}")
            warning_keys.add(key)
        return None

    # Longitude for diagnostics (ecliptic, not used for residual).
    try:
        ecl, _ = swe.calc_ut(jd, spec.code, swe.FLG_SWIEPH | swe.FLG_SPEED)
        longitude = (float(ecl[0]) + spec.longitude_offset) % 360.0
    except swe.Error:
        longitude = float("nan")

    oob = abs(dec) > threshold
    return DeclValue(
        declination=dec,
        declination_speed=dec_speed,
        longitude=longitude,
        name=spec.name,
        ephemeris=ephemeris,
        out_of_bounds=oob,
        oob_threshold=threshold,
        threshold_method=threshold_method,
    )


def _require_moment(value: Any, label: str) -> datetime:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be an object with year/month/day/hour/minute/timezone")
    for field in ("year", "month", "day", "hour", "minute", "timezone"):
        if field not in value:
            raise ValueError(f"{label}.{field} is required")
    return moment_to_local_datetime(value).astimezone(timezone.utc)


def _display_zone(name: str) -> ZoneInfo:
    zone = resolve_timezone(name if str(name or "").strip() else "UTC")
    if isinstance(zone, ZoneInfo):
        return zone
    # resolve_timezone may return a fixed-offset tzinfo for GMT±N labels.
    # Wrap via a local conversion still works with astimezone.
    return ZoneInfo("UTC") if name in ("", "UTC", "utc") else ZoneInfo("UTC")


def _build_natal_targets(
    request: dict[str, Any],
    warnings: list[str],
    sidereal: bool,
) -> tuple[list[NatalTarget], dict[str, Any], dict[str, str]]:
    birth = request["birth"]
    birth_utc = moment_to_local_datetime(birth["moment"]).astimezone(timezone.utc)
    birth_jd, _ = moment_to_jd(birth["moment"])
    latitude = float(birth["latitude"])
    longitude = float(birth["longitude"])
    house_system = birth.get("houseSystem", birth.get("house_system", "whole_sign"))
    raw_point_set = request.get("target_point_set") or request.get("point_set")
    node_mode = str(
        (raw_point_set or {}).get("node_mode", request.get("node_mode", "true_node"))
        if isinstance(raw_point_set, dict)
        else request.get("node_mode", "true_node")
    )
    point_set = resolve_point_set(raw_point_set, node_mode=node_mode)
    section_errors: dict[str, str] = {}

    targets: list[NatalTarget] = []
    body_ids = list(point_set["resolved_body_ids"])
    specs = resolve_bodies(
        [point_id for point_id in body_ids if not point_id.startswith("AST:")],
        list(point_set["custom_asteroids"]),
        warnings,
    )
    try:
        positions = calculate_positions(birth_jd, specs, warnings, sidereal=sidereal)
    except Exception as exc:
        section_errors["natal_bodies"] = str(exc)
        positions = []
        warnings.append(f"本命天体赤纬计算失败：{exc}")

    available_body_ids: list[str] = []
    for row in positions:
        if row["body_id"] not in body_ids:
            continue
        dec = row.get("declination")
        if dec is None or not math.isfinite(float(dec)):
            continue
        targets.append(
            NatalTarget(
                point_id=str(row["body_id"]),
                name=str(row.get("name") or row["body_id"]),
                kind="body",
                declination=float(dec),
                longitude=float(row["longitude"]),
                method="swiss_ephemeris_equatorial_natal",
            )
        )
        available_body_ids.append(str(row["body_id"]))

    available_angles: list[str] = []
    try:
        cusps, angles, _ = build_houses(
            birth_jd, latitude, longitude, house_system, sidereal, warnings
        )
        threshold, threshold_method = true_obliquity(birth_jd)
        for angle_id in point_set["angle_ids"]:
            lon = angles.get(angle_id)
            if lon is None or not math.isfinite(float(lon)):
                warnings.append(f"轴点 {angle_id} 不可用，已从 target_point_set 移除。")
                continue
            # Angles are ecliptic longitudes at latitude 0; lon-only declination is exact.
            dec = float(declination_from_lon(float(lon), threshold))
            targets.append(
                NatalTarget(
                    point_id=angle_id,
                    name=ANGLE_NAMES.get(angle_id, angle_id),
                    kind="angle",
                    declination=dec,
                    longitude=float(lon),
                    method=f"ecliptic_longitude_to_declination:{threshold_method}",
                )
            )
            available_angles.append(angle_id)
    except Exception as exc:
        section_errors["natal_angles"] = str(exc)
        warnings.append(f"本命轴点赤纬计算失败：{exc}")
        cusps, angles = [], {}

    available_lots: list[str] = []
    if point_set["lot_ids"]:
        try:
            from astro_backend_classical_lots import calculate_lots

            classical_specs = [BODY_REGISTRY[body_id] for body_id in CLASSICAL_BODY_IDS]
            classical_positions = calculate_positions(
                birth_jd, classical_specs, warnings, sidereal=sidereal
            )
            positions_by_id = {row["body_id"]: row for row in classical_positions}
            sun = positions_by_id.get("SUN")
            is_day = bool(sun and house_for_longitude(float(sun["longitude"]), cusps) >= 7)
            lot_rows = calculate_lots(
                angles if isinstance(angles, dict) else {},
                positions_by_id,
                cusps,
                is_day,
                mc=(angles or {}).get("MC") if isinstance(angles, dict) else None,
                warnings=warnings,
            )
            lots_by_id = {row["id"]: row for row in lot_rows}
            threshold, threshold_method = true_obliquity(birth_jd)
            for lot_id in point_set["lot_ids"]:
                row = lots_by_id.get(lot_id)
                if row is None:
                    warnings.append(f"阿拉伯点 {lot_id} 不可用，已从 target_point_set 移除。")
                    continue
                lon = float(row["longitude"])
                dec = float(declination_from_lon(lon, threshold))
                targets.append(
                    NatalTarget(
                        point_id=lot_id,
                        name=str(row["name"]),
                        kind="lot",
                        declination=dec,
                        longitude=lon,
                        method=f"ecliptic_longitude_to_declination:{threshold_method}",
                    )
                )
                available_lots.append(lot_id)
        except Exception as exc:
            section_errors["natal_lots"] = str(exc)
            warnings.append(f"本命阿拉伯点赤纬计算失败：{exc}")

    effective = finalize_point_set(
        point_set,
        available_body_ids,
        available_angle_ids=available_angles,
        warnings=warnings,
    )
    effective["lot_ids"] = available_lots
    effective["house_cusps"] = []
    return targets, effective, section_errors


def _parse_event_types(raw: Any) -> list[str]:
    if raw is None:
        return list(DEFAULT_EVENT_TYPES)
    if not isinstance(raw, list) or not raw:
        raise ValueError("event_types must be a non-empty array")
    out: list[str] = []
    for item in raw:
        if item not in EVENT_TYPES:
            raise ValueError(f"unsupported event_type: {item}")
        if item not in out:
            out.append(item)
    return out


def _parse_moving_ids(raw: Any) -> list[str]:
    if raw is None:
        return list(DEFAULT_MOVING)
    if not isinstance(raw, list) or not raw:
        raise ValueError("moving_body_ids must be a non-empty array")
    out: list[str] = []
    for item in raw:
        if not isinstance(item, str) or not item.strip():
            raise ValueError("moving_body_ids entries must be non-empty strings")
        if item not in out:
            out.append(item)
    return out


def _parse_orb(raw: Any) -> float:
    if raw is None:
        return DEFAULT_ORB
    if isinstance(raw, bool) or not isinstance(raw, (int, float)) or not math.isfinite(float(raw)):
        raise ValueError("declination_orb must be a finite number")
    value = float(raw)
    if value < 0 or value > 5:
        raise ValueError("declination_orb must be in [0, 5]")
    return value


def _aspect_events(
    *,
    moving_id: str,
    targets: list[NatalTarget],
    event_type: str,
    orb_limit: float,
    start_utc: datetime,
    end_utc: datetime,
    display_zone: ZoneInfo,
    warnings: list[str],
    warning_keys: set[str],
) -> list[dict[str, Any]]:
    step = _step_for("transit", moving_id, warnings)
    rows: list[dict[str, Any]] = []

    def moving_at(at_utc: datetime) -> DeclValue | None:
        return body_declination_at(at_utc, moving_id, warnings, warning_keys)

    for target in targets:
        if event_type == "parallel":
            residual: NumericEvaluator = lambda at_utc, t=target: (
                None if (m := moving_at(at_utc)) is None else m.declination - t.declination
            )
            boundary: NumericEvaluator = lambda at_utc, t=target: (
                None
                if (m := moving_at(at_utc)) is None
                else abs(m.declination - t.declination) - orb_limit
            )
            aspect_id = "parallel"
            aspect_name = "平行"
            method_key = "declination_parallel_bisection"
        else:
            residual = lambda at_utc, t=target: (
                None if (m := moving_at(at_utc)) is None else m.declination + t.declination
            )
            boundary = lambda at_utc, t=target: (
                None
                if (m := moving_at(at_utc)) is None
                else abs(m.declination + t.declination) - orb_limit
            )
            aspect_id = "contraparallel"
            aspect_name = "反平行"
            method_key = "declination_contraparallel_bisection"

        for exact_utc, residual_abs in _find_roots(residual, start_utc, end_utc, step):
            moving = moving_at(exact_utc)
            if moving is None:
                continue
            entering, leaving, clipped_start, clipped_end = _lifecycle_bounds(
                boundary,
                exact_utc,
                start_utc,
                end_utc,
                step,
                orb_limit,
            )
            if event_type == "parallel":
                exact_orb = abs(moving.declination - target.declination)
            else:
                exact_orb = abs(moving.declination + target.declination)
            group_id = f"transit|{moving_id}|{event_type}|{target.point_id}"
            rows.append(
                {
                    "id": f"{group_id}|{_id_stamp(exact_utc)}",
                    "group_id": group_id,
                    "coordinate_kind": COORDINATE_KIND,
                    "source_type": "transit",
                    "event_type": event_type,
                    "moving_point_id": moving_id,
                    "moving_point_name": moving.name,
                    "target_point_id": target.point_id,
                    "target_point_name": target.name,
                    "target_point_kind": target.kind,
                    "aspect_id": aspect_id,
                    "aspect_name": aspect_name,
                    "orb_limit": orb_limit,
                    "entering_utc": _iso_utc(entering),
                    "exact_utc": _iso_utc(exact_utc),
                    "leaving_utc": _iso_utc(leaving),
                    "exact_local": _iso_local(exact_utc, display_zone),
                    "motion": _motion_from_speed(moving.declination_speed),
                    "moving_declination": round(moving.declination, 9),
                    "moving_declination_speed": round(moving.declination_speed, 12),
                    "target_declination": round(target.declination, 9),
                    "exact_orb": round(min(residual_abs, exact_orb), 12),
                    "oob_threshold": round(moving.oob_threshold, 9),
                    "threshold_method": moving.threshold_method,
                    "out_of_bounds": moving.out_of_bounds,
                    "moving_longitude": round(moving.longitude, 9) if math.isfinite(moving.longitude) else None,
                    "target_longitude": (
                        round(target.longitude, 9) if target.longitude is not None else None
                    ),
                    "pass_index_in_window": 0,
                    "pass_count_in_window": 0,
                    "window_clipped_start": clipped_start,
                    "window_clipped_end": clipped_end,
                    "search_precision_seconds": 0.05,
                    "method_key": method_key,
                    "target_method": target.method,
                }
            )
    return rows


def _oob_events(
    *,
    moving_id: str,
    start_utc: datetime,
    end_utc: datetime,
    display_zone: ZoneInfo,
    warnings: list[str],
    warning_keys: set[str],
) -> list[dict[str, Any]]:
    step = _step_for("transit", moving_id, warnings)
    rows: list[dict[str, Any]] = []

    def residual(at_utc: datetime) -> float | None:
        value = body_declination_at(at_utc, moving_id, warnings, warning_keys)
        if value is None:
            return None
        return abs(value.declination) - value.oob_threshold

    # Sample residual sign changes and classify entry vs exit.
    left = start_utc
    f_left = residual(left)
    while left < end_utc:
        right = min(left + step, end_utc)
        f_right = residual(right)
        if f_left is not None and f_right is not None:
            if abs(f_left) <= 1e-10:
                refined_utc = left
                residual_abs = abs(f_left)
                crossing = True
            elif f_left * f_right < 0:
                refined = _refine_root(residual, left, right)
                if refined is None:
                    left, f_left = right, f_right
                    continue
                refined_utc, residual_abs = refined
                crossing = True
            else:
                crossing = False
                refined_utc = left
                residual_abs = 0.0

            if crossing:
                moving = body_declination_at(refined_utc, moving_id, warnings, warning_keys)
                if moving is not None:
                    # Entry: residual goes - → + (becoming OOB); exit: + → -.
                    # Use a tiny probe after exact when f_left/f_right ambiguous at root.
                    probe = residual(min(end_utc, refined_utc + timedelta(seconds=30)))
                    before = residual(max(start_utc, refined_utc - timedelta(seconds=30)))
                    if before is not None and probe is not None:
                        is_entry = before < 0 <= probe or (before <= 0 and probe > 0)
                        is_exit = before > 0 >= probe or (before >= 0 and probe < 0)
                    else:
                        is_entry = f_left is not None and f_right is not None and f_left < 0 < f_right
                        is_exit = f_left is not None and f_right is not None and f_left > 0 > f_right
                    if is_entry or is_exit:
                        event_type = "oob_entry" if is_entry else "oob_exit"
                        group_id = f"transit|{moving_id}|{event_type}"
                        rows.append(
                            {
                                "id": f"{group_id}|{_id_stamp(refined_utc)}",
                                "group_id": group_id,
                                "coordinate_kind": COORDINATE_KIND,
                                "source_type": "transit",
                                "event_type": event_type,
                                "moving_point_id": moving_id,
                                "moving_point_name": moving.name,
                                "target_point_id": None,
                                "target_point_name": None,
                                "target_point_kind": None,
                                "aspect_id": event_type,
                                "aspect_name": "进入出界" if is_entry else "离开出界",
                                "orb_limit": None,
                                "entering_utc": None,
                                "exact_utc": _iso_utc(refined_utc),
                                "leaving_utc": None,
                                "exact_local": _iso_local(refined_utc, display_zone),
                                "motion": _motion_from_speed(moving.declination_speed),
                                "moving_declination": round(moving.declination, 9),
                                "moving_declination_speed": round(moving.declination_speed, 12),
                                "target_declination": None,
                                "exact_orb": round(residual_abs, 12),
                                "oob_threshold": round(moving.oob_threshold, 9),
                                "threshold_method": moving.threshold_method,
                                "out_of_bounds": moving.out_of_bounds,
                                "moving_longitude": (
                                    round(moving.longitude, 9)
                                    if math.isfinite(moving.longitude)
                                    else None
                                ),
                                "target_longitude": None,
                                "pass_index_in_window": 0,
                                "pass_count_in_window": 0,
                                "window_clipped_start": False,
                                "window_clipped_end": False,
                                "search_precision_seconds": 0.05,
                                "method_key": "oob_boundary_true_obliquity_bisection",
                                "target_method": None,
                            }
                        )
        left = right
        f_left = f_right
    return rows


def _station_events(
    *,
    moving_id: str,
    start_utc: datetime,
    end_utc: datetime,
    display_zone: ZoneInfo,
    warnings: list[str],
    warning_keys: set[str],
) -> list[dict[str, Any]]:
    step = _step_for("transit", moving_id, warnings)
    rows: list[dict[str, Any]] = []

    def speed_residual(at_utc: datetime) -> float | None:
        value = body_declination_at(at_utc, moving_id, warnings, warning_keys)
        if value is None:
            return None
        return value.declination_speed

    for exact_utc, residual_abs in _find_roots(speed_residual, start_utc, end_utc, step):
        moving = body_declination_at(exact_utc, moving_id, warnings, warning_keys)
        if moving is None:
            continue
        if moving.declination > 1e-6:
            station_kind = "max_north"
            aspect_name = "最大北赤纬"
        elif moving.declination < -1e-6:
            station_kind = "max_south"
            aspect_name = "最大南赤纬"
        else:
            station_kind = "equatorial_turn"
            aspect_name = "赤纬回转"
        group_id = f"transit|{moving_id}|declination_station|{station_kind}"
        rows.append(
            {
                "id": f"{group_id}|{_id_stamp(exact_utc)}",
                "group_id": group_id,
                "coordinate_kind": COORDINATE_KIND,
                "source_type": "transit",
                "event_type": "declination_station",
                "moving_point_id": moving_id,
                "moving_point_name": moving.name,
                "target_point_id": station_kind,
                "target_point_name": aspect_name,
                "target_point_kind": "declination_extreme",
                "aspect_id": station_kind,
                "aspect_name": aspect_name,
                "orb_limit": None,
                "entering_utc": None,
                "exact_utc": _iso_utc(exact_utc),
                "leaving_utc": None,
                "exact_local": _iso_local(exact_utc, display_zone),
                "motion": "stationary",
                "moving_declination": round(moving.declination, 9),
                "moving_declination_speed": round(moving.declination_speed, 12),
                "target_declination": None,
                "exact_orb": round(residual_abs, 12),
                "oob_threshold": round(moving.oob_threshold, 9),
                "threshold_method": moving.threshold_method,
                "out_of_bounds": moving.out_of_bounds,
                "moving_longitude": (
                    round(moving.longitude, 9) if math.isfinite(moving.longitude) else None
                ),
                "target_longitude": None,
                "pass_index_in_window": 0,
                "pass_count_in_window": 0,
                "window_clipped_start": False,
                "window_clipped_end": False,
                "search_precision_seconds": 0.05,
                "method_key": "declination_speed_zero_bisection",
                "target_method": None,
            }
        )
    return rows


def calculate_declination_timing(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    start_utc = _require_moment(request.get("start"), "start")
    end_utc = _require_moment(request.get("end"), "end")
    if end_utc <= start_utc:
        raise ValueError("end must be later than start")
    if (end_utc - start_utc).days > 3700:
        raise ValueError("declination_timing window must be ≤ 10 years")

    display_timezone = str(request.get("display_timezone") or "UTC").strip() or "UTC"
    try:
        display_zone = ZoneInfo(display_timezone)
    except Exception:
        # Support GMT±N labels via project resolver; format with that offset.
        tz = resolve_timezone(display_timezone)
        display_zone = tz  # type: ignore[assignment]

    birth = request.get("birth")
    if not isinstance(birth, dict):
        raise ValueError("birth must be an object")
    if "moment" not in birth:
        raise ValueError("birth.moment is required")
    for field in ("latitude", "longitude"):
        if field not in birth:
            raise ValueError(f"birth.{field} is required")

    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)

    requested_config = {
        "mode": "declination_timing",
        "start": request.get("start"),
        "end": request.get("end"),
        "display_timezone": display_timezone,
        "moving_body_ids": request.get("moving_body_ids"),
        "event_types": request.get("event_types"),
        "declination_orb": request.get("declination_orb"),
        "target_point_set": request.get("target_point_set") or request.get("point_set"),
        "zodiac": zodiac,
        "node_mode": request.get("node_mode"),
    }

    moving_ids = _parse_moving_ids(request.get("moving_body_ids"))
    event_types = _parse_event_types(request.get("event_types"))
    orb_limit = _parse_orb(request.get("declination_orb"))

    targets, effective_point_set, target_section_errors = _build_natal_targets(
        request, warnings, sidereal
    )
    section_errors: dict[str, str] = dict(target_section_errors)
    warning_keys: set[str] = set()
    events: list[dict[str, Any]] = []

    need_targets = any(t in event_types for t in ("parallel", "contraparallel"))
    if need_targets and not targets:
        section_errors["targets"] = "no resolvable natal target points with declination"
        warnings.append("无可计算的本命目标点；平行/反平行事件已跳过。")

    for moving_id in moving_ids:
        try:
            if "parallel" in event_types and targets:
                events.extend(
                    _aspect_events(
                        moving_id=moving_id,
                        targets=targets,
                        event_type="parallel",
                        orb_limit=orb_limit,
                        start_utc=start_utc,
                        end_utc=end_utc,
                        display_zone=display_zone,  # type: ignore[arg-type]
                        warnings=warnings,
                        warning_keys=warning_keys,
                    )
                )
            if "contraparallel" in event_types and targets:
                events.extend(
                    _aspect_events(
                        moving_id=moving_id,
                        targets=targets,
                        event_type="contraparallel",
                        orb_limit=orb_limit,
                        start_utc=start_utc,
                        end_utc=end_utc,
                        display_zone=display_zone,  # type: ignore[arg-type]
                        warnings=warnings,
                        warning_keys=warning_keys,
                    )
                )
            if "oob_entry" in event_types or "oob_exit" in event_types:
                oob_rows = _oob_events(
                    moving_id=moving_id,
                    start_utc=start_utc,
                    end_utc=end_utc,
                    display_zone=display_zone,  # type: ignore[arg-type]
                    warnings=warnings,
                    warning_keys=warning_keys,
                )
                if "oob_entry" not in event_types:
                    oob_rows = [row for row in oob_rows if row["event_type"] != "oob_entry"]
                if "oob_exit" not in event_types:
                    oob_rows = [row for row in oob_rows if row["event_type"] != "oob_exit"]
                events.extend(oob_rows)
            if "declination_station" in event_types:
                events.extend(
                    _station_events(
                        moving_id=moving_id,
                        start_utc=start_utc,
                        end_utc=end_utc,
                        display_zone=display_zone,  # type: ignore[arg-type]
                        warnings=warnings,
                        warning_keys=warning_keys,
                    )
                )
        except Exception as exc:
            section_errors[f"mover:{moving_id}"] = str(exc)
            warnings.append(f"行运体 {moving_id} 赤纬事件计算失败：{exc}")

    events = _dedupe_and_number_events(events)

    effective_config = {
        "mode": "declination_timing",
        "start_utc": _iso_utc(start_utc),
        "end_utc": _iso_utc(end_utc),
        "display_timezone": display_timezone,
        "moving_body_ids": moving_ids,
        "event_types": event_types,
        "declination_orb": orb_limit,
        "target_point_set": effective_point_set,
        "zodiac": zodiac,
        "coordinate_kind": COORDINATE_KIND,
        "oob_threshold_method": "true_obliquity_at_event_time",
        "search_method": "bracket_plus_bisection",
        "search_precision_seconds": 0.05,
    }

    calculation_assumptions = [
        "行运体赤纬与赤纬速度来自 Swiss Ephemeris 赤道坐标（FLG_EQUATORIAL|FLG_SPEED）。",
        "OOB 阈值使用事件时刻真实黄赤交角（swe.ECL_NUT true obliquity）；失败时回退 mean obliquity。",
        "平行 exact 条件：moving_declination − target_declination = 0。",
        "反平行 exact 条件：moving_declination + target_declination = 0。",
        "平行/反平行 lifecycle 由 orb 边界求根（abs residual − orb = 0）；窗口截断时 entering/leaving 为 null。",
        "赤纬停滞 exact 条件：declination_speed = 0；按赤纬符号标注 max_north / max_south。",
        "本命天体目标使用出生时刻真实赤道赤纬；本命轴点/阿拉伯点使用黄经→赤纬（黄纬=0）近似。",
        "结果仅为可复算的时间与坐标事实，不含解释性论断。",
        f"搜索精度：时间二分至约 {0.05} 秒。",
    ]

    # Sample one event threshold for meta documentation.
    sample_threshold = None
    sample_method = "true_obliquity_ecl_nut"
    if events:
        sample_threshold = events[0].get("oob_threshold")
        sample_method = events[0].get("threshold_method") or sample_method
    else:
        mid = start_utc + (end_utc - start_utc) / 2
        sample_threshold, sample_method = true_obliquity(jd_from_datetime(mid))

    meta = {
        "mode": "declination_timing",
        "method": METHOD,
        "schema_version": SCHEMA_VERSION,
        "coordinate_kind": COORDINATE_KIND,
        "start_utc": _iso_utc(start_utc),
        "end_utc": _iso_utc(end_utc),
        "display_timezone": display_timezone,
        "moving_body_ids": moving_ids,
        "event_types": event_types,
        "declination_orb": orb_limit,
        "target_count": len(targets),
        "event_count": len(events),
        "ephemeris": "Swiss Ephemeris",
        "effective_point_set": effective_point_set,
        "oob_threshold_method": "true_obliquity_at_event_time",
        "oob_threshold_sample": round(float(sample_threshold), 9) if sample_threshold is not None else None,
        "oob_threshold_sample_method": sample_method,
        "search_precision_seconds": 0.05,
        "search_method": "bracket_plus_bisection",
        "zodiac": zodiac,
    }

    return {
        "meta": meta,
        "requested_config": requested_config,
        "effective_config": effective_config,
        "events": events,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": section_errors or None,
        "calculation_assumptions": calculation_assumptions,
    }


__all__ = [
    "EVENT_TYPES",
    "METHOD",
    "body_declination_at",
    "calculate_declination_timing",
    "true_obliquity",
]
