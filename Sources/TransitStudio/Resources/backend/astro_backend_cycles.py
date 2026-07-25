"""Modern lunation and eclipse cycle scan (mode=modern_cycles).

Swiss Ephemeris bindings used (verified via pyswisseph introspection):

- ``swe.sol_eclipse_when_glob(tjdut, flags=FLG_SWIEPH, ecltype=0, backwards=False)``
  → ``(retflag, tret)`` where ``tret[0]`` is global maximum.
- ``swe.lun_eclipse_when(tjdut, flags=FLG_SWIEPH, ecltype=0, backwards=False)``
  → ``(retflag, tret)`` where ``tret[0]`` is global maximum.
- ``swe.sol_eclipse_when_loc(tjdut, geopos, flags=FLG_SWIEPH, backwards=False)``
- ``swe.lun_eclipse_when_loc(tjdut, geopos, flags=FLG_SWIEPH, backwards=False)``
- ``swe.sol_eclipse_how`` / ``swe.lun_eclipse_how`` for type attributes.

New/Full Moon exacts are refined by Sun–Moon elongation root finding
(0° new / 180° full) using the project's existing longitude helpers.
"""

from __future__ import annotations

import math
from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_core import (
    jd_from_datetime,
    moment_to_jd,
    moment_to_local_datetime,
    resolve_timezone,
    set_zodiac_mode,
    signed_orb,
    swe,
)
from astro_backend_ephemeris import calculate_positions, resolve_bodies
from astro_backend_modern_points import resolve_point_set

METHOD = "swiss_ephemeris_cycles_v1"
SCHEMA_VERSION = 1

CYCLE_TYPES = ("new_moon", "full_moon", "solar_eclipse", "lunar_eclipse")
DEFAULT_CONTACT_ASPECTS = (
    {"id": "conjunction", "name": "合相", "angle": 0.0, "orb": 1.0},
    {"id": "opposition", "name": "对分", "angle": 180.0, "orb": 1.0},
)


def _iso_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _iso_local(dt: datetime, tz_name: str) -> str:
    """Format ``dt`` in the display zone. Supports IANA and Swift GMT±N labels.

    Must not silently fall back to UTC: product UI sends ``GMT+8`` via
    ``GMTOffset.label``, which ZoneInfo rejects.
    """
    zone = resolve_timezone(tz_name if str(tz_name or "").strip() else "UTC")
    return dt.astimezone(zone).isoformat()


def _utc_from_jd(jd: float) -> datetime:
    year, month, day, hour = swe.revjul(jd, swe.GREG_CAL)
    whole_hours = int(hour)
    minutes_f = (hour - whole_hours) * 60.0
    whole_minutes = int(minutes_f)
    seconds_f = (minutes_f - whole_minutes) * 60.0
    whole_seconds = int(seconds_f)
    micros = int(round((seconds_f - whole_seconds) * 1_000_000))
    if micros >= 1_000_000:
        whole_seconds += 1
        micros -= 1_000_000
    if whole_seconds >= 60:
        whole_minutes += 1
        whole_seconds -= 60
    if whole_minutes >= 60:
        whole_hours += 1
        whole_minutes -= 60
    return datetime(
        int(year),
        int(month),
        int(day),
        whole_hours % 24,
        whole_minutes,
        whole_seconds,
        max(0, micros),
        tzinfo=timezone.utc,
    )


def _require_moment(value: Any, label: str) -> datetime:
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be an object with year/month/day/hour/minute/timezone")
    for field in ("year", "month", "day", "hour", "minute", "timezone"):
        if field not in value:
            raise ValueError(f"{label}.{field} is required")
    local = moment_to_local_datetime(value)
    return local.astimezone(timezone.utc)


def _sun_moon_longitudes(jd: float, sidereal: bool, warnings: list[str]) -> tuple[float, float]:
    specs = resolve_bodies(["SUN", "MOON"], [], warnings)
    rows = calculate_positions(jd, specs, warnings, sidereal=sidereal)
    by_id = {row["body_id"]: float(row["longitude"]) for row in rows}
    if "SUN" not in by_id or "MOON" not in by_id:
        raise RuntimeError("无法计算日月黄经")
    return by_id["SUN"], by_id["MOON"]


def _elongation(jd: float, sidereal: bool, warnings: list[str]) -> float:
    sun, moon = _sun_moon_longitudes(jd, sidereal, warnings)
    return signed_orb(moon, sun)


def _refine_elongation_root(
    start: datetime,
    end: datetime,
    target: float,
    sidereal: bool,
    warnings: list[str],
) -> datetime | None:
    """Bisection on signed elongation residual into [target-180, target+180)."""
    left = start
    right = end
    for _ in range(48):
        mid = left + (right - left) / 2
        mid_jd = jd_from_datetime(mid)
        value = _elongation(mid_jd, sidereal, warnings)
        residual = ((value - target + 180.0) % 360.0) - 180.0
        left_jd = jd_from_datetime(left)
        left_val = _elongation(left_jd, sidereal, warnings)
        left_residual = ((left_val - target + 180.0) % 360.0) - 180.0
        if left_residual * residual <= 0:
            right = mid
        else:
            left = mid
        if abs((right - left).total_seconds()) < 0.05:
            break
    exact = left + (right - left) / 2
    exact_jd = jd_from_datetime(exact)
    residual = ((_elongation(exact_jd, sidereal, warnings) - target + 180.0) % 360.0) - 180.0
    if abs(residual) > 0.05:
        return None
    return exact


def _scan_lunations(
    start_utc: datetime,
    end_utc: datetime,
    *,
    want_new: bool,
    want_full: bool,
    sidereal: bool,
    display_timezone: str,
    warnings: list[str],
) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    if not want_new and not want_full:
        return events

    step = timedelta(hours=6)
    cursor = start_utc - step
    previous_jd = jd_from_datetime(cursor)
    previous_el = _elongation(previous_jd, sidereal, warnings)
    t = cursor + step
    while t <= end_utc + step:
        jd = jd_from_datetime(t)
        el = _elongation(jd, sidereal, warnings)
        # Crossing of 0° elongation (new moon).
        if want_new and previous_el * el < 0 and abs(previous_el) < 90 and abs(el) < 90:
            root = _refine_elongation_root(
                cursor if t - step == cursor else t - step,
                t,
                0.0,
                sidereal,
                warnings,
            )
            if root is not None and start_utc <= root <= end_utc:
                sun, moon = _sun_moon_longitudes(jd_from_datetime(root), sidereal, warnings)
                sep = abs(signed_orb(moon, sun))
                stamp = root.strftime("%Y%m%dT%H%M%SZ")
                events.append(
                    {
                        "id": f"new_moon|{stamp}",
                        "cycle_type": "new_moon",
                        "maximum_utc": _iso_utc(root),
                        "maximum_local": _iso_local(root, display_timezone),
                        "sun_longitude": sun,
                        "moon_longitude": moon,
                        "separation_deg": sep,
                        "eclipse_type": None,
                        "global_event": True,
                        "visible_at_location": None,
                        "visibility_details": None,
                        "contacts": [],
                        "method_key": "sun_moon_elongation_root",
                        "retflag": None,
                    }
                )
        # Crossing of ±180° (full moon): elongation near ±180 jumps sign across the branch cut.
        if want_full:
            prev_full = ((previous_el - 180.0 + 180.0) % 360.0) - 180.0
            curr_full = ((el - 180.0 + 180.0) % 360.0) - 180.0
            # Use raw elongation jump across opposition.
            if abs(previous_el) > 90 and abs(el) > 90 and previous_el * el < 0:
                root = _refine_elongation_root(t - step, t, 180.0, sidereal, warnings)
                if root is None:
                    root = _refine_elongation_root(t - step, t, -180.0, sidereal, warnings)
                if root is not None and start_utc <= root <= end_utc:
                    sun, moon = _sun_moon_longitudes(jd_from_datetime(root), sidereal, warnings)
                    sep = abs(signed_orb(moon, sun))
                    stamp = root.strftime("%Y%m%dT%H%M%SZ")
                    events.append(
                        {
                            "id": f"full_moon|{stamp}",
                            "cycle_type": "full_moon",
                            "maximum_utc": _iso_utc(root),
                            "maximum_local": _iso_local(root, display_timezone),
                            "sun_longitude": sun,
                            "moon_longitude": moon,
                            "separation_deg": sep,
                            "eclipse_type": None,
                            "global_event": True,
                            "visible_at_location": None,
                            "visibility_details": None,
                            "contacts": [],
                            "method_key": "sun_moon_elongation_root",
                            "retflag": None,
                        }
                    )
        previous_el = el
        cursor = t
        t += step

    return _dedupe_events(events)


def _eclipse_type_label(retflag: int, kind: str) -> str:
    if kind == "solar":
        if retflag & getattr(swe, "ECL_TOTAL", 4):
            return "total"
        if retflag & getattr(swe, "ECL_ANNULAR", 8):
            return "annular"
        if retflag & getattr(swe, "ECL_ANNULAR_TOTAL", 32) or retflag & getattr(swe, "ECL_HYBRID", 32):
            return "hybrid"
        if retflag & getattr(swe, "ECL_PARTIAL", 16):
            return "partial"
        return "solar"
    # lunar
    if retflag & getattr(swe, "ECL_TOTAL", 4):
        return "total"
    if retflag & getattr(swe, "ECL_PARTIAL", 16):
        return "partial"
    if retflag & getattr(swe, "ECL_PENUMBRAL", 64):
        return "penumbral"
    return "lunar"


def _scan_solar_eclipses(
    start_utc: datetime,
    end_utc: datetime,
    *,
    sidereal: bool,
    display_timezone: str,
    geopos: tuple[float, float, float] | None,
    warnings: list[str],
) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    jd = jd_from_datetime(start_utc) - 1.0
    end_jd = jd_from_datetime(end_utc) + 1.0
    flags = swe.FLG_SWIEPH
    safety = 0
    while jd < end_jd and safety < 200:
        safety += 1
        try:
            retflag, tret = swe.sol_eclipse_when_glob(jd, flags, 0, False)
        except swe.Error as exc:
            warnings.append(f"sol_eclipse_when_glob failed: {exc}")
            break
        maximum_jd = float(tret[0])
        if maximum_jd > end_jd + 0.5:
            break
        if maximum_jd < jd_from_datetime(start_utc) - 0.01:
            jd = maximum_jd + 1.0
            continue
        maximum = _utc_from_jd(maximum_jd)
        if not (start_utc <= maximum <= end_utc):
            jd = maximum_jd + 1.0
            continue
        sun, moon = _sun_moon_longitudes(maximum_jd, sidereal, warnings)
        stamp = maximum.strftime("%Y%m%dT%H%M%SZ")
        visible: bool | None = None
        visibility_details: dict[str, Any] | None = None
        if geopos is not None:
            try:
                loc_flag, loc_tret, attr = swe.sol_eclipse_when_loc(
                    maximum_jd - 0.5, geopos, flags, False
                )
                # Match if local maximum is within ~2 days of global event.
                loc_max = float(loc_tret[0])
                if abs(loc_max - maximum_jd) < 1.0 and loc_flag != 0:
                    visible = True
                    visibility_details = {
                        "method_key": "swe_sol_eclipse_when_loc",
                        "retflag": int(loc_flag),
                        "local_maximum_jd": loc_max,
                    }
                else:
                    # Also try how at the global maximum for this place.
                    how_flag, how_attr = swe.sol_eclipse_how(maximum_jd, geopos, flags)
                    visible = bool(how_flag)
                    visibility_details = {
                        "method_key": "swe_sol_eclipse_how",
                        "retflag": int(how_flag),
                    }
            except swe.Error as exc:
                visible = False
                visibility_details = {"error": str(exc), "method_key": "swe_sol_eclipse_when_loc"}
        events.append(
            {
                "id": f"solar_eclipse|{stamp}",
                "cycle_type": "solar_eclipse",
                "maximum_utc": _iso_utc(maximum),
                "maximum_local": _iso_local(maximum, display_timezone),
                "sun_longitude": sun,
                "moon_longitude": moon,
                "separation_deg": abs(signed_orb(moon, sun)),
                "eclipse_type": _eclipse_type_label(int(retflag), "solar"),
                "global_event": True,
                "visible_at_location": visible,
                "visibility_details": visibility_details,
                "contacts": [],
                "method_key": "swe_sol_eclipse_when_glob",
                "retflag": int(retflag),
            }
        )
        jd = maximum_jd + 1.0
    return events


def _scan_lunar_eclipses(
    start_utc: datetime,
    end_utc: datetime,
    *,
    sidereal: bool,
    display_timezone: str,
    geopos: tuple[float, float, float] | None,
    warnings: list[str],
) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    jd = jd_from_datetime(start_utc) - 1.0
    end_jd = jd_from_datetime(end_utc) + 1.0
    flags = swe.FLG_SWIEPH
    safety = 0
    while jd < end_jd and safety < 200:
        safety += 1
        try:
            retflag, tret = swe.lun_eclipse_when(jd, flags, 0, False)
        except swe.Error as exc:
            warnings.append(f"lun_eclipse_when failed: {exc}")
            break
        maximum_jd = float(tret[0])
        if maximum_jd > end_jd + 0.5:
            break
        if maximum_jd < jd_from_datetime(start_utc) - 0.01:
            jd = maximum_jd + 1.0
            continue
        maximum = _utc_from_jd(maximum_jd)
        if not (start_utc <= maximum <= end_utc):
            jd = maximum_jd + 1.0
            continue
        sun, moon = _sun_moon_longitudes(maximum_jd, sidereal, warnings)
        stamp = maximum.strftime("%Y%m%dT%H%M%SZ")
        visible: bool | None = None
        visibility_details: dict[str, Any] | None = None
        if geopos is not None:
            try:
                loc_flag, loc_tret, attr = swe.lun_eclipse_when_loc(
                    maximum_jd - 0.5, geopos, flags, False
                )
                loc_max = float(loc_tret[0])
                if abs(loc_max - maximum_jd) < 1.0 and loc_flag != 0:
                    visible = True
                    visibility_details = {
                        "method_key": "swe_lun_eclipse_when_loc",
                        "retflag": int(loc_flag),
                        "local_maximum_jd": loc_max,
                    }
                else:
                    how_flag, how_attr = swe.lun_eclipse_how(maximum_jd, geopos, flags)
                    visible = bool(how_flag)
                    visibility_details = {
                        "method_key": "swe_lun_eclipse_how",
                        "retflag": int(how_flag),
                    }
            except swe.Error as exc:
                visible = False
                visibility_details = {"error": str(exc), "method_key": "swe_lun_eclipse_when_loc"}
        events.append(
            {
                "id": f"lunar_eclipse|{stamp}",
                "cycle_type": "lunar_eclipse",
                "maximum_utc": _iso_utc(maximum),
                "maximum_local": _iso_local(maximum, display_timezone),
                "sun_longitude": sun,
                "moon_longitude": moon,
                "separation_deg": abs(signed_orb(moon, sun)),
                "eclipse_type": _eclipse_type_label(int(retflag), "lunar"),
                "global_event": True,
                "visible_at_location": visible,
                "visibility_details": visibility_details,
                "contacts": [],
                "method_key": "swe_lun_eclipse_when",
                "retflag": int(retflag),
            }
        )
        jd = maximum_jd + 1.0
    return events


def _dedupe_events(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    seen: set[str] = set()
    unique: list[dict[str, Any]] = []
    for event in events:
        event_id = str(event["id"])
        if event_id in seen:
            continue
        seen.add(event_id)
        unique.append(event)
    unique.sort(key=lambda row: row["maximum_utc"])
    return unique


def _event_time_key(event: dict[str, Any]) -> str:
    return str(event.get("maximum_utc") or event.get("exact_utc") or event.get("id") or "")


def _merge_eclipse_lunation_groups(
    events: list[dict[str, Any]],
    warnings: list[str],
) -> list[dict[str, Any]]:
    """Merge co-temporal new_moon+solar_eclipse (or full_moon+lunar_eclipse) into one group.

    Primary record is the eclipse; lunation exact time is retained as a sub-field.
    Same geometric event must not appear twice as independent cycle hits.
    """
    from datetime import datetime

    def _parse(ts: str) -> datetime | None:
        if not ts:
            return None
        try:
            return datetime.fromisoformat(str(ts).replace("Z", "+00:00"))
        except Exception:
            return None

    lunations = [e for e in events if e.get("cycle_type") in {"new_moon", "full_moon"}]
    eclipses = [e for e in events if e.get("cycle_type") in {"solar_eclipse", "lunar_eclipse"}]
    other = [e for e in events if e not in lunations and e not in eclipses]

    used_lunation_ids: set[str] = set()
    merged: list[dict[str, Any]] = []

    for ecl in eclipses:
        ecl_t = _parse(str(ecl.get("maximum_utc") or ecl.get("exact_utc") or ""))
        match = None
        want = "new_moon" if ecl.get("cycle_type") == "solar_eclipse" else "full_moon"
        if ecl_t is not None:
            best_dt = None
            for lun in lunations:
                if lun.get("cycle_type") != want:
                    continue
                if str(lun.get("id")) in used_lunation_ids:
                    continue
                lun_t = _parse(str(lun.get("maximum_utc") or lun.get("exact_utc") or ""))
                if lun_t is None:
                    continue
                delta = abs((ecl_t - lun_t).total_seconds())
                if delta <= 36 * 3600 and (best_dt is None or delta < best_dt):
                    best_dt = delta
                    match = lun
        row = dict(ecl)
        row["event_group"] = "eclipse_lunation"
        row["eclipse_type"] = ecl.get("cycle_type")
        row["eclipse_maximum_time"] = ecl.get("maximum_utc") or ecl.get("exact_utc")
        if match is not None:
            used_lunation_ids.add(str(match.get("id")))
            row["exact_syzygy_time"] = match.get("maximum_utc") or match.get("exact_utc")
            row["lunation_cycle_type"] = match.get("cycle_type")
            row["lunation_id"] = match.get("id")
            # Prefer richer contacts: take max of both if present
            c_ecl = ecl.get("contacts") or ecl.get("contact_count")
            c_lun = match.get("contacts") or match.get("contact_count")
            if isinstance(c_ecl, list) or isinstance(c_lun, list):
                combined = list(c_ecl or []) + [c for c in (c_lun or []) if c not in (c_ecl or [])]
                row["contacts"] = combined
                row["contact_count"] = len(combined)
                row["contacts_basis"] = "merged_eclipse_and_syzygy"
            row["merged_from"] = [ecl.get("id"), match.get("id")]
            # Keep eclipse id / cycle_type stable for consumers; group fields carry merge info.
            row["primary_record"] = "eclipse"
        else:
            row["exact_syzygy_time"] = None
            row["merged_from"] = [ecl.get("id")]
            row["primary_record"] = "eclipse"
        # Visibility clarity
        if row.get("visible_at_location") is None and not row.get("location_visibility"):
            row["location_visibility"] = "not_requested"
        merged.append(row)

    for lun in lunations:
        if str(lun.get("id")) in used_lunation_ids:
            continue
        row = dict(lun)
        row["event_group"] = "lunation_only"
        merged.append(row)

    out = other + merged
    out.sort(key=lambda row: str(row.get("maximum_utc") or row.get("exact_utc") or row.get("id") or ""))
    if used_lunation_ids:
        warnings.append(
            f"Merged {len(used_lunation_ids)} lunation(s) into eclipse_lunation groups (single primary record per eclipse)."
        )
    return out


def _attach_contacts(
    events: list[dict[str, Any]],
    *,
    birth: dict[str, Any] | None,
    target_point_set: Any,
    contact_aspects: list[dict[str, Any]],
    sidereal: bool,
    warnings: list[str],
) -> None:
    if birth is None:
        return
    moment = birth.get("moment")
    if not isinstance(moment, dict):
        raise ValueError("birth.moment is required for natal contacts")
    birth_jd, _ = moment_to_jd(moment)
    node_mode = "true_node"
    if isinstance(target_point_set, dict):
        node_mode = str(target_point_set.get("node_mode") or birth.get("node_mode") or "true_node")
    point_set = resolve_point_set(target_point_set if target_point_set is not None else None, node_mode=node_mode)
    specs = resolve_bodies(
        [body_id for body_id in point_set["resolved_body_ids"] if not str(body_id).startswith("AST:")],
        list(point_set["custom_asteroids"]),
        warnings,
    )
    natal_rows = calculate_positions(birth_jd, specs, warnings, sidereal=sidereal)
    aspects = contact_aspects or list(DEFAULT_CONTACT_ASPECTS)

    for event in events:
        # Contacts use the cycle's exact maximum — never shift the cycle UTC.
        # Lunation/eclipse contact reference is the Moon longitude at maximum.
        contact_longitude = float(event["moon_longitude"])
        contacts: list[dict[str, Any]] = []
        for natal in natal_rows:
            natal_lon = float(natal["longitude"])
            for aspect in aspects:
                angle = float(aspect.get("angle", 0.0))
                orb = float(aspect.get("orb", 1.0))
                sep = abs(signed_orb(contact_longitude, natal_lon))
                residual = abs(sep - angle)
                residual = min(residual, 360.0 - residual)
                if residual <= orb:
                    contacts.append(
                        {
                            "body_id": natal["body_id"],
                            "body_name": natal.get("name", natal["body_id"]),
                            "natal_longitude": natal_lon,
                            "cycle_longitude": contact_longitude,
                            "aspect_id": aspect.get("id"),
                            "aspect_name": aspect.get("name"),
                            "aspect_angle": angle,
                            "orb": residual,
                            "exact_utc": event["maximum_utc"],
                        }
                    )
        event["contacts"] = contacts


def cycle_event_to_timing_event(event: dict[str, Any]) -> dict[str, Any]:
    """Map a cycle event into a modern_timing-compatible registration row.

    Full ModernTimingEvent lifecycle fields that do not apply to instantaneous
    cycle maxima are filled with stable defaults so timeline adapters can
    filter on ``source_type == modern_cycles`` without inventing windows.
    """
    cycle_type = str(event["cycle_type"])
    is_moon = "moon" in cycle_type or cycle_type == "lunar_eclipse"
    moving_longitude = float(
        event["moon_longitude"] if is_moon else event.get("sun_longitude") or event["moon_longitude"]
    )
    # exact_orb is the residual at the exact instant relative to the cycle's
    # target elongation (0° new/solar eclipse, 180° full/lunar eclipse), not
    # the raw Sun–Moon separation. Full moons therefore report ~0°, not ~180°.
    separation = float(event.get("separation_deg") or 0.0)
    target_angle = 180.0 if cycle_type in {"full_moon", "lunar_eclipse"} else 0.0
    exact_orb = abs(separation - target_angle)
    if exact_orb > 180.0:
        exact_orb = 360.0 - exact_orb
    return {
        "id": f"modern_cycles|{event['id']}",
        "group_id": f"modern_cycles|{cycle_type}",
        "source_type": "modern_cycles",
        "event_type": cycle_type,
        "moving_point_id": "MOON" if is_moon else "SUN",
        "moving_point_name": "月亮" if is_moon else "太阳",
        "target_point_id": cycle_type,
        "target_point_name": cycle_type,
        "target_point_kind": "cycle",
        "target_axis_branch": None,
        "aspect_id": None,
        "aspect_name": None,
        "aspect_angle": None,
        "orb_limit": None,
        "entering_utc": None,
        "exact_utc": event["maximum_utc"],
        "leaving_utc": None,
        "exact_local": event.get("maximum_local") or event["maximum_utc"],
        "motion": "direct",
        "moving_longitude": moving_longitude,
        "target_longitude": None,
        "target_chart_type": None,
        "target_chart_method": None,
        "exact_orb": exact_orb,
        "pass_index_in_window": 1,
        "pass_count_in_window": 1,
        "window_clipped_start": False,
        "window_clipped_end": False,
        "method_key": str(event.get("method_key") or "modern_cycles"),
        "cycle": {
            "cycle_type": cycle_type,
            "eclipse_type": event.get("eclipse_type"),
            "global_event": event.get("global_event"),
            "visible_at_location": event.get("visible_at_location"),
            "sun_longitude": event.get("sun_longitude"),
            "moon_longitude": event.get("moon_longitude"),
            "method_key": event.get("method_key"),
            "separation_deg": separation,
        },
    }


def calculate_modern_cycles(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    start_utc = _require_moment(request.get("start"), "start")
    end_utc = _require_moment(request.get("end"), "end")
    if end_utc <= start_utc:
        raise ValueError("end must be after start")
    if (end_utc - start_utc).days > 3700:
        raise ValueError("modern_cycles window must be ≤ 10 years")

    display_timezone = str(request.get("display_timezone") or "UTC").strip() or "UTC"
    moment_to_local_datetime(
        {
            "year": 2026,
            "month": 1,
            "day": 1,
            "hour": 12,
            "minute": 0,
            "timezone": display_timezone if display_timezone not in {"UTC", "utc"} else "UTC",
        }
    ) if display_timezone not in {"UTC", "utc"} else None

    raw_types = request.get("cycle_types") or list(CYCLE_TYPES)
    if not isinstance(raw_types, list) or not raw_types:
        raise ValueError("cycle_types must be a non-empty array")
    cycle_types = []
    for item in raw_types:
        if item not in CYCLE_TYPES:
            raise ValueError(f"unsupported cycle_type: {item}")
        if item not in cycle_types:
            cycle_types.append(item)

    visibility = str(request.get("visibility") or "global")
    if visibility not in {"global", "location"}:
        raise ValueError("visibility must be global or location")

    geopos: tuple[float, float, float] | None = None
    location_meta = None
    if visibility == "location":
        location = request.get("location")
        if not isinstance(location, dict):
            raise ValueError("location is required when visibility=location")
        for field in ("latitude", "longitude"):
            if field not in location:
                raise ValueError(f"location.{field} is required")
        lat = float(location["latitude"])
        lon = float(location["longitude"])
        if not (-90 <= lat <= 90 and -180 <= lon <= 180):
            raise ValueError("location coordinates out of range")
        alt = float(location.get("altitude_m") or 0.0)
        geopos = (lon, lat, alt)  # Swiss Ephemeris: longitude, latitude, altitude
        location_meta = {
            "name": str(location.get("name") or ""),
            "latitude": lat,
            "longitude": lon,
            "altitude_m": alt,
        }

    zodiac = request.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(zodiac, warnings)

    events: list[dict[str, Any]] = []
    if "new_moon" in cycle_types or "full_moon" in cycle_types:
        events.extend(
            _scan_lunations(
                start_utc,
                end_utc,
                want_new="new_moon" in cycle_types,
                want_full="full_moon" in cycle_types,
                sidereal=sidereal,
                display_timezone=display_timezone,
                warnings=warnings,
            )
        )
    if "solar_eclipse" in cycle_types:
        events.extend(
            _scan_solar_eclipses(
                start_utc,
                end_utc,
                sidereal=sidereal,
                display_timezone=display_timezone,
                geopos=geopos,
                warnings=warnings,
            )
        )
    if "lunar_eclipse" in cycle_types:
        events.extend(
            _scan_lunar_eclipses(
                start_utc,
                end_utc,
                sidereal=sidereal,
                display_timezone=display_timezone,
                geopos=geopos,
                warnings=warnings,
            )
        )

    events = _dedupe_events(events)
    events = _merge_eclipse_lunation_groups(events, warnings)

    birth = request.get("birth")
    if birth is not None:
        _attach_contacts(
            events,
            birth=birth if isinstance(birth, dict) else None,
            target_point_set=request.get("target_point_set") or request.get("point_set"),
            contact_aspects=list(request.get("contact_aspects") or DEFAULT_CONTACT_ASPECTS),
            sidereal=sidereal,
            warnings=warnings,
        )

    # When visibility=location, global events remain listed; visible_at_location
    # may be false/null without dropping the event.
    timing_events = [cycle_event_to_timing_event(event) for event in events]

    return {
        "meta": {
            "mode": "modern_cycles",
            "method": METHOD,
            "schema_version": SCHEMA_VERSION,
            "start_utc": _iso_utc(start_utc),
            "end_utc": _iso_utc(end_utc),
            "display_timezone": display_timezone,
            "cycle_types": cycle_types,
            "visibility": visibility,
            "location": location_meta,
            "zodiac": zodiac,
            "ephemeris": "Swiss Ephemeris",
            "swiss_bindings": {
                "sol_eclipse_when_glob": "swe.sol_eclipse_when_glob(tjdut, flags=FLG_SWIEPH, ecltype=0, backwards=False)",
                "lun_eclipse_when": "swe.lun_eclipse_when(tjdut, flags=FLG_SWIEPH, ecltype=0, backwards=False)",
                "sol_eclipse_when_loc": "swe.sol_eclipse_when_loc(tjdut, geopos, flags=FLG_SWIEPH, backwards=False)",
                "lun_eclipse_when_loc": "swe.lun_eclipse_when_loc(tjdut, geopos, flags=FLG_SWIEPH, backwards=False)",
                "sol_eclipse_how": "swe.sol_eclipse_how(tjdut, geopos, flags=FLG_SWIEPH)",
                "lun_eclipse_how": "swe.lun_eclipse_how(tjdut, geopos, flags=FLG_SWIEPH)",
            },
        },
        "events": events,
        "timing_events": timing_events,
        "warnings": warnings,
        "section_errors": None,
    }
