"""Arbitrary two-body synodic cycles and natal point-set contacts.

mode=planetary_synodic
"""

from __future__ import annotations

import math
from datetime import datetime, timedelta, timezone
from typing import Any, Optional
from zoneinfo import ZoneInfo

from astro_backend_core import (
    BODY_REGISTRY,
    angular_separation,
    moment_to_local_datetime,
    resolve_timezone,
    set_zodiac_mode,
    signed_orb,
)
from astro_backend_ephemeris import body_longitude_at, body_speed_at, calculate_positions, resolve_bodies
from astro_backend_modern_points import finalize_point_set, resolve_point_set
from astro_backend_modern_timing import _find_roots, _step_for
from astro_backend_core import moment_to_jd

METHOD = "planetary_synodic_v1"
SCHEMA_VERSION = 1
DEFAULT_PHASES = (
    {"id": "conjunction", "name": "合相", "angle": 0.0},
    {"id": "square", "name": "刑相", "angle": 90.0},
    {"id": "opposition", "name": "冲相", "angle": 180.0},
    {"id": "square_closing", "name": "闭刑", "angle": 270.0},
)


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


def _pair_state(
    at_utc: datetime,
    body_a: str,
    body_b: str,
    sidereal: bool,
    warnings: list[str],
    warning_keys: set[str],
) -> dict[str, float | str] | None:
    specs = resolve_bodies([body_a, body_b], [], warnings)
    by_id = {s.body_id: s for s in specs}
    if body_a not in by_id or body_b not in by_id:
        return None
    la = body_longitude_at(at_utc, by_id[body_a], warnings, warning_keys, sidereal=sidereal)
    lb = body_longitude_at(at_utc, by_id[body_b], warnings, warning_keys, sidereal=sidereal)
    sa = body_speed_at(at_utc, by_id[body_a], warnings, warning_keys, sidereal=sidereal)
    sb = body_speed_at(at_utc, by_id[body_b], warnings, warning_keys, sidereal=sidereal)
    if None in (la, lb, sa, sb):
        return None
    lon_a, _ = la
    lon_b, _ = lb
    speed_a, _ = sa
    speed_b, _ = sb
    separation = signed_orb(lon_a, lon_b)  # A - B in (-180,180]
    rel_speed = float(speed_a) - float(speed_b)
    return {
        "longitude_a": float(lon_a),
        "longitude_b": float(lon_b),
        "speed_a": float(speed_a),
        "speed_b": float(speed_b),
        "separation": float(separation),
        "relative_speed": float(rel_speed),
        "motion_a": "direct" if speed_a > 1e-9 else ("retrograde" if speed_a < -1e-9 else "stationary"),
        "motion_b": "direct" if speed_b > 1e-9 else ("retrograde" if speed_b < -1e-9 else "stationary"),
        "relative_motion": "applying" if rel_speed * separation < 0 else "separating",
    }


def _synodic_search_step(
    body_a: str,
    body_b: str,
    warnings: list[str] | None = None,
) -> float:
    """Return the search step for synodic event root-finding between two bodies."""
    return min(_step_for("transit", body_a, warnings), _step_for("transit", body_b, warnings))


def _phase_events(
    *,
    body_a: str,
    body_b: str,
    phases: list[dict[str, Any]],
    start_utc: datetime,
    end_utc: datetime,
    sidereal: bool,
    display_zone: ZoneInfo,
    warnings: list[str],
) -> list[dict[str, Any]]:
    warning_keys: set[str] = set()
    # Relative motion must be sampled at least as fast as the faster body; use the smaller step.
    step = _synodic_search_step(body_a, body_b, warnings)
    rows: list[dict[str, Any]] = []
    for phase in phases:
        angle = float(phase["angle"]) % 360.0
        phase_id = str(phase["id"])
        phase_name = str(phase.get("name") or phase_id)

        def residual(at_utc: datetime, target=angle) -> float | None:
            state = _pair_state(at_utc, body_a, body_b, sidereal, warnings, warning_keys)
            if state is None:
                return None
            # residual of signed separation vs target, unwrapped near target
            sep = float(state["separation"])
            # map separation from (-180,180] to residual around target
            # For target 270 use -90 equivalent of signed orb to 270? Better:
            # signed_orb(sep_mod, target) where sep_mod is 0..360 separation A-B
            sep360 = (float(state["longitude_a"]) - float(state["longitude_b"])) % 360.0
            return signed_orb(sep360, target)

        roots = _find_roots(residual, start_utc, end_utc, step)
        for index, (exact_utc, residual_abs) in enumerate(roots, start=1):
            state = _pair_state(exact_utc, body_a, body_b, sidereal, warnings, warning_keys)
            if state is None:
                continue
            group_id = f"{body_a}|{body_b}|{phase_id}"
            rows.append(
                {
                    "id": f"{group_id}|{_iso_utc(exact_utc)}",
                    "group_id": group_id,
                    "event_type": "phase",
                    "phase_id": phase_id,
                    "phase_name": phase_name,
                    "phase_angle": angle,
                    "body_a_id": body_a,
                    "body_b_id": body_b,
                    "body_a_name": BODY_REGISTRY.get(body_a).name if body_a in BODY_REGISTRY else body_a,
                    "body_b_name": BODY_REGISTRY.get(body_b).name if body_b in BODY_REGISTRY else body_b,
                    "exact_utc": _iso_utc(exact_utc),
                    "exact_local": _iso_local(exact_utc, display_zone),
                    "longitude_a": round(float(state["longitude_a"]), 9),
                    "longitude_b": round(float(state["longitude_b"]), 9),
                    "separation_deg": round(float(state["separation"]), 9),
                    "relative_speed": round(float(state["relative_speed"]), 12),
                    "motion_a": state["motion_a"],
                    "motion_b": state["motion_b"],
                    "relative_motion": state["relative_motion"],
                    "exact_orb": round(float(residual_abs), 12),
                    "pass_index_in_window": index,
                    "pass_count_in_window": len(roots),
                    "method_key": "relative_longitude_bisection",
                }
            )
    # Fix pass counts after all roots known per group
    by_group: dict[str, list[dict[str, Any]]] = {}
    for row in rows:
        by_group.setdefault(row["group_id"], []).append(row)
    for group_rows in by_group.values():
        ordered = sorted(group_rows, key=lambda r: r["exact_utc"])
        for i, row in enumerate(ordered, start=1):
            row["pass_index_in_window"] = i
            row["pass_count_in_window"] = len(ordered)
    return sorted(rows, key=lambda r: r["exact_utc"] or "")


def _build_cycles_from_conjunctions(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    conjunctions = sorted(
        [e for e in events if e.get("phase_angle") == 0.0 or e.get("phase_id") == "conjunction"],
        key=lambda e: e["exact_utc"],
    )
    cycles: list[dict[str, Any]] = []
    for i, start in enumerate(conjunctions):
        end = conjunctions[i + 1] if i + 1 < len(conjunctions) else None
        cycles.append(
            {
                "id": f"cycle|{start['id']}",
                "start_event_id": start["id"],
                "end_event_id": end["id"] if end else None,
                "start_utc": start["exact_utc"],
                "end_utc": end["exact_utc"] if end else None,
                "start_local": start["exact_local"],
                "end_local": end["exact_local"] if end else None,
                "body_a_id": start["body_a_id"],
                "body_b_id": start["body_b_id"],
                "duration_days": (
                    round(
                        (
                            datetime.fromisoformat(end["exact_utc"].replace("Z", "+00:00"))
                            - datetime.fromisoformat(start["exact_utc"].replace("Z", "+00:00"))
                        ).total_seconds()
                        / 86400.0,
                        6,
                    )
                    if end
                    else None
                ),
                "method_key": "synodic_cycle_between_conjunctions",
            }
        )
    return cycles


def _attach_natal_contacts(
    events: list[dict[str, Any]],
    birth: dict[str, Any],
    target_point_set: Any,
    contact_aspects: list[dict[str, Any]],
    sidereal: bool,
    warnings: list[str],
) -> None:
    birth_jd, _ = moment_to_jd(birth["moment"])
    node_mode = "true_node"
    if isinstance(target_point_set, dict):
        node_mode = str(target_point_set.get("node_mode", "true_node"))
    point_set = resolve_point_set(target_point_set, node_mode=node_mode)
    specs = resolve_bodies(
        [bid for bid in point_set["resolved_body_ids"] if not bid.startswith("AST:")],
        list(point_set["custom_asteroids"]),
        warnings,
    )
    natal_rows = calculate_positions(birth_jd, specs, warnings, sidereal=sidereal)
    for event in events:
        contacts = []
        for natal in natal_rows:
            for aspect in contact_aspects:
                angle = float(aspect["angle"])
                orb_limit = float(aspect.get("orb", 1.0))
                for lon_key, label in (("longitude_a", "body_a"), ("longitude_b", "body_b")):
                    lon = event.get(lon_key)
                    if lon is None:
                        continue
                    orb = abs(angular_separation(float(lon), float(natal["longitude"])) - angle)
                    # angular_separation is 0..180; for non-0/180 aspects need min over branches
                    if angle not in (0.0, 180.0):
                        d = abs(((float(lon) - float(natal["longitude"]) + 180) % 360) - 180)
                        orb = abs(d - angle)
                        orb = min(orb, abs(d - (360 - angle)))
                    if orb <= orb_limit:
                        contacts.append(
                            {
                                "id": f"{event['id']}|{label}|{natal['body_id']}|{aspect['id']}",
                                "source": label,
                                "natal_body_id": natal["body_id"],
                                "natal_body_name": natal["name"],
                                "natal_longitude": round(float(natal["longitude"]), 9),
                                "cycle_longitude": round(float(lon), 9),
                                "aspect_id": aspect["id"],
                                "aspect_name": aspect.get("name"),
                                "aspect_angle": angle,
                                "orb": round(orb, 9),
                                "exact_utc": event["exact_utc"],
                            }
                        )
        event["natal_contacts"] = contacts


def calculate_planetary_synodic(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    start_utc = _require_moment(request.get("start"), "start")
    end_utc = _require_moment(request.get("end"), "end")
    if end_utc <= start_utc:
        raise ValueError("end must be later than start")
    if (end_utc - start_utc).days > 3700:
        raise ValueError("planetary_synodic window must be ≤ 10 years")

    pair = request.get("pair") or {}
    if not isinstance(pair, dict):
        raise ValueError("pair must be an object with body_a and body_b")
    body_a = str(pair.get("body_a") or request.get("body_a") or "")
    body_b = str(pair.get("body_b") or request.get("body_b") or "")
    if not body_a or not body_b:
        raise ValueError("pair.body_a and pair.body_b are required")
    if body_a == body_b:
        raise ValueError("pair bodies must be different")
    if body_a not in BODY_REGISTRY or body_b not in BODY_REGISTRY:
        raise ValueError(f"unsupported body in pair: {body_a}, {body_b}")

    display_timezone = str(request.get("display_timezone") or "UTC").strip() or "UTC"
    try:
        display_zone = ZoneInfo(display_timezone)
    except Exception:
        display_zone = resolve_timezone(display_timezone)  # type: ignore[assignment]

    zodiac = request.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)

    raw_phases = request.get("phases") or list(DEFAULT_PHASES)
    if not isinstance(raw_phases, list) or not raw_phases:
        raise ValueError("phases must be a non-empty array")
    phases: list[dict[str, Any]] = []
    for item in raw_phases:
        if isinstance(item, (int, float)):
            phases.append({"id": f"phase_{item}", "name": f"{item}°", "angle": float(item)})
        elif isinstance(item, dict) and "angle" in item:
            phases.append(
                {
                    "id": str(item.get("id") or f"phase_{item['angle']}"),
                    "name": str(item.get("name") or f"{item['angle']}°"),
                    "angle": float(item["angle"]),
                }
            )
        else:
            raise ValueError("phases entries must be numbers or objects with angle")

    section_errors: dict[str, str] = {}
    events: list[dict[str, Any]] = []
    try:
        events = _phase_events(
            body_a=body_a,
            body_b=body_b,
            phases=phases,
            start_utc=start_utc,
            end_utc=end_utc,
            sidereal=sidereal,
            display_zone=display_zone,  # type: ignore[arg-type]
            warnings=warnings,
        )
    except Exception as exc:
        section_errors["phase_events"] = str(exc)
        warnings.append(f"会合相位搜索失败：{exc}")

    cycles = _build_cycles_from_conjunctions(events)

    # Current cycle progress at window end if we have a surrounding cycle.
    progress = None
    end_state = None
    try:
        end_state = _pair_state(end_utc, body_a, body_b, sidereal, warnings, set())
        for cycle in cycles:
            if cycle["start_utc"] and cycle["end_utc"]:
                if cycle["start_utc"] <= _iso_utc(end_utc) <= cycle["end_utc"]:
                    start_dt = datetime.fromisoformat(cycle["start_utc"].replace("Z", "+00:00"))
                    end_dt = datetime.fromisoformat(cycle["end_utc"].replace("Z", "+00:00"))
                    frac = (end_utc - start_dt).total_seconds() / max((end_dt - start_dt).total_seconds(), 1)
                    progress = {
                        "cycle_id": cycle["id"],
                        "fraction": round(min(max(frac, 0.0), 1.0), 6),
                        "at_utc": _iso_utc(end_utc),
                    }
                    break
    except Exception as exc:
        section_errors["cycle_progress"] = str(exc)

    birth = request.get("birth")
    if birth is not None and isinstance(birth, dict):
        try:
            contact_aspects = list(request.get("contact_aspects") or [
                {"id": "conjunction", "name": "合相", "angle": 0.0, "orb": 1.0},
                {"id": "opposition", "name": "冲相", "angle": 180.0, "orb": 1.0},
            ])
            _attach_natal_contacts(
                events,
                birth=birth,
                target_point_set=request.get("target_point_set") or request.get("point_set"),
                contact_aspects=contact_aspects,
                sidereal=sidereal,
                warnings=warnings,
            )
        except Exception as exc:
            section_errors["natal_contacts"] = str(exc)
            warnings.append(f"本命接触计算失败：{exc}")

    calculation_assumptions = [
        "相位 exact 定义为 body_a 与 body_b 相对黄经差到达目标角的 bracket + bisection 求根。",
        "synodic cycle 以相邻两次合相（0°）界定；无结束合相的周期 end 为 null。",
        "relative_speed = speed_a − speed_b；relative_motion 由 residual 与速度符号判定 applying/separating。",
        "同一相位因逆行可多次命中，pass_index/count 按 group 编号。",
        "对本命接触为事件时刻黄经与本命点的静态 orb 匹配，不另求 exact 时间。",
        "结果为可复算时间与坐标事实，不含解释性论断。",
    ]

    return {
        "meta": {
            "mode": "planetary_synodic",
            "method": METHOD,
            "schema_version": SCHEMA_VERSION,
            "start_utc": _iso_utc(start_utc),
            "end_utc": _iso_utc(end_utc),
            "display_timezone": display_timezone,
            "pair": {"body_a": body_a, "body_b": body_b},
            "phases": phases,
            "event_count": len(events),
            "cycle_count": len(cycles),
            "zodiac": zodiac,
            "ephemeris": "Swiss Ephemeris",
        },
        "requested_config": {
            "pair": pair,
            "phases": raw_phases,
            "start": request.get("start"),
            "end": request.get("end"),
            "display_timezone": display_timezone,
            "zodiac": zodiac,
        },
        "effective_config": {
            "pair": {"body_a": body_a, "body_b": body_b},
            "phases": phases,
            "start_utc": _iso_utc(start_utc),
            "end_utc": _iso_utc(end_utc),
            "display_timezone": display_timezone,
            "zodiac": zodiac,
            "method": METHOD,
        },
        "events": events,
        "cycles": cycles,
        "window_end_state": end_state,
        "current_cycle_progress": progress,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": section_errors or None,
        "calculation_assumptions": calculation_assumptions,
    }


__all__ = ["calculate_planetary_synodic"]
