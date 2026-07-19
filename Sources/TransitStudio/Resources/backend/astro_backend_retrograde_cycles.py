"""Retrograde cycles with pre-shadow / retrograde / post-shadow from true stations.

mode=retrograde_cycles

Shadow longitudes are the *actual* station longitudes of the paired stations,
not fixed-day approximations.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Optional
from zoneinfo import ZoneInfo

from astro_backend_core import (
    moment_to_local_datetime,
    resolve_timezone,
    set_zodiac_mode,
    signed_orb,
)
from astro_backend_ephemeris import body_longitude_at, body_speed_at, resolve_bodies
from astro_backend_modern_timing import _find_roots, _refine_root, _step_for
from astro_backend_scan import step_for_body

METHOD = "retrograde_shadow_from_true_stations_v1"
SCHEMA_VERSION = 1

# Bodies that actually station (Sun/Moon never retrograde geocentrically).
DEFAULT_BODIES = ["MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]
SUPPORTED_BODIES = {
    "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN",
    "URANUS", "NEPTUNE", "PLUTO", "CHIRON",
}


def _iso_utc(dt: datetime | None) -> str | None:
    if dt is None:
        return None
    return dt.astimezone(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _iso_local(dt: datetime, zone: ZoneInfo) -> str:
    return dt.astimezone(zone).isoformat(timespec="milliseconds")


def _require_moment(value: Any, label: str) -> datetime:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be an object with year/month/day/hour/minute/timezone")
    for field in ("year", "month", "day", "hour", "minute", "timezone"):
        if field not in value:
            raise ValueError(f"{label}.{field} is required")
    return moment_to_local_datetime(value).astimezone(timezone.utc)


def _find_stations(
    body_id: str,
    start_utc: datetime,
    end_utc: datetime,
    sidereal: bool,
    warnings: list[str],
) -> list[dict[str, Any]]:
    specs = resolve_bodies([body_id], [], warnings)
    if not specs:
        return []
    spec = specs[0]
    warning_keys: set[str] = set()
    step = step_for_body(spec)

    def speed_residual(at_utc: datetime) -> float | None:
        value = body_speed_at(at_utc, spec, warnings, warning_keys, sidereal=sidereal)
        if value is None:
            return None
        return float(value[0])

    stations: list[dict[str, Any]] = []
    for exact_utc, residual in _find_roots(speed_residual, start_utc, end_utc, step):
        lon_value = body_longitude_at(exact_utc, spec, warnings, warning_keys, sidereal=sidereal)
        speed_value = body_speed_at(exact_utc, spec, warnings, warning_keys, sidereal=sidereal)
        if lon_value is None or speed_value is None:
            continue
        # Classify by speed sign change around exact.
        before = speed_residual(max(start_utc, exact_utc - timedelta(hours=6)))
        after = speed_residual(min(end_utc, exact_utc + timedelta(hours=6)))
        if before is None or after is None:
            continue
        if before > 0 and after < 0:
            kind = "retrograde_station"
        elif before < 0 and after > 0:
            kind = "direct_station"
        else:
            # Fall back to local slope of speed.
            kind = "retrograde_station" if after < before else "direct_station"
        stations.append(
            {
                "kind": kind,
                "exact_utc": exact_utc,
                "longitude": float(lon_value[0]),
                "speed": float(speed_value[0]),
                "exact_orb": float(residual),
            }
        )
    return stations


def _refine_longitude_crossing(
    *,
    body_id: str,
    target_lon: float,
    start_utc: datetime,
    end_utc: datetime,
    sidereal: bool,
    warnings: list[str],
    prefer: str = "first",
) -> datetime | None:
    specs = resolve_bodies([body_id], [], warnings)
    if not specs:
        return None
    spec = specs[0]
    warning_keys: set[str] = set()
    step = step_for_body(spec)

    def residual(at_utc: datetime) -> float | None:
        value = body_longitude_at(at_utc, spec, warnings, warning_keys, sidereal=sidereal)
        if value is None:
            return None
        return signed_orb(float(value[0]), target_lon)

    roots = _find_roots(residual, start_utc, end_utc, step)
    if not roots:
        return None
    if prefer == "last":
        return roots[-1][0]
    return roots[0][0]


def _build_cycle_from_pair(
    *,
    body_id: str,
    body_name: str,
    retro: dict[str, Any],
    direct: dict[str, Any],
    search_start: datetime,
    search_end: datetime,
    sidereal: bool,
    display_zone: ZoneInfo,
    warnings: list[str],
    cycle_index: int,
) -> dict[str, Any] | None:
    retro_utc: datetime = retro["exact_utc"]
    direct_utc: datetime = direct["exact_utc"]
    if direct_utc <= retro_utc:
        return None
    lon_retro = float(retro["longitude"])
    lon_direct = float(direct["longitude"])

    # Pre-shadow: first time the body reaches the *direct-station longitude*
    # while still direct, before the retrograde station.
    pre_start = _refine_longitude_crossing(
        body_id=body_id,
        target_lon=lon_direct,
        start_utc=search_start,
        end_utc=retro_utc,
        sidereal=sidereal,
        warnings=warnings,
        prefer="last",
    )
    # Post-shadow: first time after direct station the body again reaches the
    # *retrograde-station longitude* while direct.
    post_end = _refine_longitude_crossing(
        body_id=body_id,
        target_lon=lon_retro,
        start_utc=direct_utc,
        end_utc=search_end,
        sidereal=sidereal,
        warnings=warnings,
        prefer="first",
    )

    clipped = {
        "pre_shadow_start_clipped": pre_start is None,
        "post_shadow_end_clipped": post_end is None,
    }

    return {
        "id": f"{body_id}|retro_cycle|{_iso_utc(retro_utc)}",
        "body_id": body_id,
        "body_name": body_name,
        "cycle_index_in_window": cycle_index,
        "pre_shadow_start_utc": _iso_utc(pre_start),
        "pre_shadow_start_local": _iso_local(pre_start, display_zone) if pre_start else None,
        "retrograde_station_utc": _iso_utc(retro_utc),
        "retrograde_station_local": _iso_local(retro_utc, display_zone),
        "direct_station_utc": _iso_utc(direct_utc),
        "direct_station_local": _iso_local(direct_utc, display_zone),
        "post_shadow_end_utc": _iso_utc(post_end),
        "post_shadow_end_local": _iso_local(post_end, display_zone) if post_end else None,
        "retrograde_station_longitude": round(lon_retro, 9),
        "direct_station_longitude": round(lon_direct, 9),
        "shadow_longitude_pre": round(lon_direct, 9),
        "shadow_longitude_post": round(lon_retro, 9),
        "retrograde_duration_days": round((direct_utc - retro_utc).total_seconds() / 86400.0, 6),
        "method_key": METHOD,
        "window_clipped": clipped,
        "phases": [
            {
                "phase": "pre_shadow",
                "start_utc": _iso_utc(pre_start),
                "end_utc": _iso_utc(retro_utc),
                "definition": "body reaches direct-station longitude while still direct, until retrograde station",
            },
            {
                "phase": "retrograde",
                "start_utc": _iso_utc(retro_utc),
                "end_utc": _iso_utc(direct_utc),
                "definition": "retrograde station to direct station",
            },
            {
                "phase": "post_shadow",
                "start_utc": _iso_utc(direct_utc),
                "end_utc": _iso_utc(post_end),
                "definition": "direct station until body re-crosses retrograde-station longitude",
            },
        ],
    }


def calculate_retrograde_cycles(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    start_utc = _require_moment(request.get("start"), "start")
    end_utc = _require_moment(request.get("end"), "end")
    if end_utc <= start_utc:
        raise ValueError("end must be later than start")
    if (end_utc - start_utc).days > 3700:
        raise ValueError("retrograde_cycles window must be ≤ 10 years")

    display_timezone = str(request.get("display_timezone") or "UTC").strip() or "UTC"
    try:
        display_zone = ZoneInfo(display_timezone)
    except Exception:
        display_zone = resolve_timezone(display_timezone)  # type: ignore[assignment]

    raw_bodies = request.get("body_ids") or DEFAULT_BODIES
    if not isinstance(raw_bodies, list) or not raw_bodies:
        raise ValueError("body_ids must be a non-empty array")
    body_ids: list[str] = []
    for item in raw_bodies:
        if item not in SUPPORTED_BODIES:
            raise ValueError(f"unsupported body_id for retrograde_cycles: {item}")
        if item not in body_ids:
            body_ids.append(item)

    zodiac = request.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)

    # Expand search slightly so pre-shadow starts and post-shadow ends near the
    # window edge can still be resolved when stations fall inside the window.
    pad_days = 120
    search_start = start_utc - timedelta(days=pad_days)
    search_end = end_utc + timedelta(days=pad_days)

    section_errors: dict[str, str] = {}
    cycles: list[dict[str, Any]] = []
    stations_out: list[dict[str, Any]] = []

    for body_id in body_ids:
        try:
            specs = resolve_bodies([body_id], [], warnings)
            body_name = specs[0].name if specs else body_id
            stations = _find_stations(body_id, search_start, search_end, sidereal, warnings)
            for station in stations:
                if start_utc <= station["exact_utc"] <= end_utc:
                    stations_out.append(
                        {
                            "id": f"{body_id}|{station['kind']}|{_iso_utc(station['exact_utc'])}",
                            "body_id": body_id,
                            "body_name": body_name,
                            "station_kind": station["kind"],
                            "exact_utc": _iso_utc(station["exact_utc"]),
                            "exact_local": _iso_local(station["exact_utc"], display_zone),
                            "longitude": round(station["longitude"], 9),
                            "speed": round(station["speed"], 12),
                            "exact_orb": station["exact_orb"],
                            "method_key": "longitude_speed_zero_bisection",
                        }
                    )
            # Pair each retrograde station with the next direct station.
            retro_list = [s for s in stations if s["kind"] == "retrograde_station"]
            direct_list = [s for s in stations if s["kind"] == "direct_station"]
            cycle_index = 0
            for retro in retro_list:
                following = [d for d in direct_list if d["exact_utc"] > retro["exact_utc"]]
                if not following:
                    continue
                direct = following[0]
                # Keep cycles whose retro or direct station intersects the user window.
                if not (
                    start_utc <= retro["exact_utc"] <= end_utc
                    or start_utc <= direct["exact_utc"] <= end_utc
                ):
                    continue
                cycle_index += 1
                cycle = _build_cycle_from_pair(
                    body_id=body_id,
                    body_name=body_name,
                    retro=retro,
                    direct=direct,
                    search_start=search_start,
                    search_end=search_end,
                    sidereal=sidereal,
                    display_zone=display_zone,  # type: ignore[arg-type]
                    warnings=warnings,
                    cycle_index=cycle_index,
                )
                if cycle is not None:
                    cycles.append(cycle)
        except Exception as exc:
            section_errors[f"body:{body_id}"] = str(exc)
            warnings.append(f"{body_id} 逆行周期计算失败：{exc}")

    cycles.sort(key=lambda row: row.get("retrograde_station_utc") or "")
    stations_out.sort(key=lambda row: row.get("exact_utc") or "")

    calculation_assumptions = [
        "站度由黄经速度过零的 bracket + bisection 求根得到。",
        "前阴影起点：逆行站之前，行运体最后一次到达“顺行站黄经”的时刻。",
        "逆行区间：逆行站 → 顺行站。",
        "后阴影终点：顺行站之后，行运体首次再次到达“逆行站黄经”的时刻。",
        "阴影边界使用真实站度，不是固定天数近似。",
        "窗口外若无法解析阴影端点，则对应字段为 null 并在 window_clipped 中标记。",
        "结果为可复算时间与坐标事实，不含解释性论断。",
    ]

    requested_config = {
        "mode": "retrograde_cycles",
        "start": request.get("start"),
        "end": request.get("end"),
        "display_timezone": display_timezone,
        "body_ids": request.get("body_ids"),
        "zodiac": zodiac,
    }
    effective_config = {
        "mode": "retrograde_cycles",
        "start_utc": _iso_utc(start_utc),
        "end_utc": _iso_utc(end_utc),
        "display_timezone": display_timezone,
        "body_ids": body_ids,
        "zodiac": zodiac,
        "search_pad_days": pad_days,
        "method": METHOD,
    }

    return {
        "meta": {
            "mode": "retrograde_cycles",
            "method": METHOD,
            "schema_version": SCHEMA_VERSION,
            "start_utc": _iso_utc(start_utc),
            "end_utc": _iso_utc(end_utc),
            "display_timezone": display_timezone,
            "body_ids": body_ids,
            "cycle_count": len(cycles),
            "station_count": len(stations_out),
            "zodiac": zodiac,
            "ephemeris": "Swiss Ephemeris",
            "search_pad_days": pad_days,
        },
        "requested_config": requested_config,
        "effective_config": effective_config,
        "stations": stations_out,
        "cycles": cycles,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": section_errors or None,
        "calculation_assumptions": calculation_assumptions,
    }


__all__ = ["SUPPORTED_BODIES", "calculate_retrograde_cycles"]
