"""Classical visibility: heliacal phases, local rise/set, unequal planetary hours.

mode=classical_visibility
"""

from __future__ import annotations

import math
from datetime import datetime, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

from astro_backend_core import (
    BODY_REGISTRY,
    jd_from_datetime,
    moment_to_local_datetime,
    resolve_timezone,
    swe,
)

METHOD = "classical_visibility_v1"
SCHEMA_VERSION = 1

# Swiss Ephemeris ObjectName strings for heliacal_ut
HELIACAL_OBJECTS = {
    "MERCURY": "Mercury",
    "VENUS": "Venus",
    "MARS": "Mars",
    "JUPITER": "Jupiter",
    "SATURN": "Saturn",
    "MOON": "Moon",
}

HELIACAL_EVENT_TYPES = {
    "heliacal_rising": getattr(swe, "HELIACAL_RISING", 1),
    "heliacal_setting": getattr(swe, "HELIACAL_SETTING", 2),
    "morning_first": getattr(swe, "MORNING_FIRST", 1),
    "morning_last": getattr(swe, "MORNING_LAST", 2),
    "evening_first": getattr(swe, "EVENING_FIRST", 3),
    "evening_last": getattr(swe, "EVENING_LAST", 4),
}

# Prefer primary classical pair; optional extras when requested.
DEFAULT_HELIACAL_EVENTS = ["heliacal_rising", "heliacal_setting"]
DEFAULT_BODIES = ["MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]

# Planetary day rulers (weekday: Monday=0 ... Sunday=6 in Python)
WEEKDAY_RULER = {
    0: "MOON",      # Monday
    1: "MARS",      # Tuesday
    2: "MERCURY",   # Wednesday
    3: "JUPITER",   # Thursday
    4: "VENUS",     # Friday
    5: "SATURN",    # Saturday
    6: "SUN",       # Sunday
}

CHALDEAN_ORDER = ["SATURN", "JUPITER", "MARS", "SUN", "VENUS", "MERCURY", "MOON"]
PLANET_NAMES = {
    "SUN": "太阳",
    "MOON": "月亮",
    "MERCURY": "水星",
    "VENUS": "金星",
    "MARS": "火星",
    "JUPITER": "木星",
    "SATURN": "土星",
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
        int(year), int(month), int(day),
        whole_hours % 24, whole_minutes, whole_seconds, max(0, micros),
        tzinfo=timezone.utc,
    )


def _sun_rise_set(
    day_utc_midnightish: datetime,
    latitude: float,
    longitude: float,
    altitude_m: float,
    warnings: list[str],
) -> tuple[datetime | None, datetime | None, list[str]]:
    """Return (sunrise_utc, sunset_utc) for the local civil day containing day_utc."""
    notes: list[str] = []
    geopos = (longitude, latitude, altitude_m)
    jd0 = jd_from_datetime(day_utc_midnightish) - 0.5  # start a bit before
    flags = swe.FLG_SWIEPH
    rise = set_ = None
    try:
        rsmi = swe.CALC_RISE | swe.BIT_DISC_CENTER
        res, tret = swe.rise_trans(jd0, swe.SUN, rsmi, geopos, 1013.25, 15.0, flags)
        if res == 0:
            rise = _utc_from_jd(float(tret[0]))
        else:
            notes.append(f"sunrise unavailable (ret={res})")
    except Exception as exc:
        notes.append(f"sunrise error: {exc}")
    try:
        rsmi = swe.CALC_SET | swe.BIT_DISC_CENTER
        res, tret = swe.rise_trans(jd0, swe.SUN, rsmi, geopos, 1013.25, 15.0, flags)
        if res == 0:
            set_ = _utc_from_jd(float(tret[0]))
        else:
            notes.append(f"sunset unavailable (ret={res})")
    except Exception as exc:
        notes.append(f"sunset error: {exc}")
    if rise and set_ and set_ <= rise:
        # Try next set after rise.
        try:
            rsmi = swe.CALC_SET | swe.BIT_DISC_CENTER
            res, tret = swe.rise_trans(
                jd_from_datetime(rise) + 1e-6, swe.SUN, rsmi, geopos, 1013.25, 15.0, flags
            )
            if res == 0:
                set_ = _utc_from_jd(float(tret[0]))
        except Exception as exc:
            notes.append(f"sunset re-search error: {exc}")
    return rise, set_, notes


def _body_rise_set(
    body_id: str,
    start_utc: datetime,
    latitude: float,
    longitude: float,
    altitude_m: float,
    warnings: list[str],
) -> dict[str, Any]:
    if body_id not in BODY_REGISTRY:
        return {"body_id": body_id, "error": "unknown body"}
    code = BODY_REGISTRY[body_id].code
    geopos = (longitude, latitude, altitude_m)
    jd0 = jd_from_datetime(start_utc)
    flags = swe.FLG_SWIEPH
    row: dict[str, Any] = {
        "body_id": body_id,
        "body_name": BODY_REGISTRY[body_id].name,
        "rise_utc": None,
        "set_utc": None,
        "method_key": "swe.rise_trans_disc_center",
    }
    try:
        res, tret = swe.rise_trans(
            jd0, code, swe.CALC_RISE | swe.BIT_DISC_CENTER, geopos, 1013.25, 15.0, flags
        )
        if res == 0:
            row["rise_utc"] = _iso_utc(_utc_from_jd(float(tret[0])))
        else:
            row["rise_error"] = f"ret={res}"
    except Exception as exc:
        row["rise_error"] = str(exc)
    try:
        res, tret = swe.rise_trans(
            jd0, code, swe.CALC_SET | swe.BIT_DISC_CENTER, geopos, 1013.25, 15.0, flags
        )
        if res == 0:
            row["set_utc"] = _iso_utc(_utc_from_jd(float(tret[0])))
        else:
            row["set_error"] = f"ret={res}"
    except Exception as exc:
        row["set_error"] = str(exc)
    return row


def _heliacal_events(
    *,
    body_ids: list[str],
    event_types: list[str],
    start_utc: datetime,
    latitude: float,
    longitude: float,
    altitude_m: float,
    observer_age: float,
    warnings: list[str],
    display_zone: ZoneInfo,
) -> list[dict[str, Any]]:
    geopos = (longitude, latitude, altitude_m)
    datm = (1013.25, 15.0, 40.0, 0.15)  # pressure hPa, temp C, RH, meteorological range km-ish
    dobs = (observer_age, 1.0, 0.0, 0.0, 0.0, 0.0)
    rows: list[dict[str, Any]] = []
    jd_start = jd_from_datetime(start_utc)
    for body_id in body_ids:
        object_name = HELIACAL_OBJECTS.get(body_id)
        if object_name is None:
            warnings.append(f"{body_id} 无 heliacal ObjectName 映射，已跳过。")
            continue
        for event_key in event_types:
            type_event = HELIACAL_EVENT_TYPES.get(event_key)
            if type_event is None:
                warnings.append(f"未知 heliacal event_type: {event_key}")
                continue
            try:
                result = swe.heliacal_ut(
                    jd_start,
                    geopos,
                    datm,
                    dobs,
                    object_name,
                    int(type_event),
                    swe.FLG_SWIEPH,
                )
                # pyswisseph may return tuple of JDs or (retflag, tret)
                if isinstance(result, tuple) and len(result) >= 1:
                    if isinstance(result[0], (list, tuple)):
                        jds = [float(x) for x in result[0] if isinstance(x, (int, float))]
                    else:
                        jds = [float(x) for x in result if isinstance(x, (int, float)) and math.isfinite(float(x))]
                else:
                    jds = []
                if not jds:
                    rows.append(
                        {
                            "id": f"{body_id}|{event_key}|none",
                            "body_id": body_id,
                            "body_name": PLANET_NAMES.get(body_id, body_id),
                            "event_type": event_key,
                            "exact_utc": None,
                            "exact_local": None,
                            "status": "not_found",
                            "method_key": "swe.heliacal_ut",
                        }
                    )
                    continue
                exact = _utc_from_jd(jds[0])
                rows.append(
                    {
                        "id": f"{body_id}|{event_key}|{_iso_utc(exact)}",
                        "body_id": body_id,
                        "body_name": PLANET_NAMES.get(body_id, body_id),
                        "event_type": event_key,
                        "exact_utc": _iso_utc(exact),
                        "exact_local": _iso_local(exact, display_zone),
                        "visibility_start_jd": jds[0] if len(jds) > 0 else None,
                        "optimum_jd": jds[1] if len(jds) > 1 else None,
                        "visibility_end_jd": jds[2] if len(jds) > 2 else None,
                        "status": "ok",
                        "method_key": "swe.heliacal_ut",
                        "observer_age": observer_age,
                        "atmosphere": {
                            "pressure_hpa": datm[0],
                            "temperature_c": datm[1],
                            "relative_humidity": datm[2],
                        },
                    }
                )
            except Exception as exc:
                warnings.append(f"{body_id} {event_key} heliacal 失败：{exc}")
                rows.append(
                    {
                        "id": f"{body_id}|{event_key}|error",
                        "body_id": body_id,
                        "body_name": PLANET_NAMES.get(body_id, body_id),
                        "event_type": event_key,
                        "exact_utc": None,
                        "exact_local": None,
                        "status": "error",
                        "error": str(exc),
                        "method_key": "swe.heliacal_ut",
                    }
                )
    return rows


def _planetary_hours(
    *,
    reference_utc: datetime,
    latitude: float,
    longitude: float,
    altitude_m: float,
    display_zone: ZoneInfo,
    warnings: list[str],
) -> dict[str, Any]:
    # Work in display zone local civil day.
    local = reference_utc.astimezone(display_zone)
    local_midnight = local.replace(hour=0, minute=0, second=0, microsecond=0)
    # Seed search from previous evening UTC to catch local sunrise.
    seed = local_midnight.astimezone(timezone.utc) - timedelta(hours=6)
    sunrise, sunset, notes = _sun_rise_set(seed, latitude, longitude, altitude_m, warnings)
    for note in notes:
        warnings.append(f"行星时太阳升落：{note}")
    if sunrise is None or sunset is None:
        return {
            "status": "unavailable",
            "reason": "missing_sunrise_or_sunset",
            "hours": [],
            "sunrise_utc": _iso_utc(sunrise),
            "sunset_utc": _iso_utc(sunset),
            "method_key": "unequal_planetary_hours_from_sun_rise_set",
        }

    # Next sunrise for night-hour end.
    next_seed = sunrise + timedelta(hours=12)
    next_sunrise, _, next_notes = _sun_rise_set(next_seed, latitude, longitude, altitude_m, warnings)
    for note in next_notes:
        if "sunrise" in note:
            warnings.append(f"行星时次日日出：{note}")
    if next_sunrise is None or next_sunrise <= sunset:
        return {
            "status": "unavailable",
            "reason": "missing_next_sunrise_polar_or_limit",
            "hours": [],
            "sunrise_utc": _iso_utc(sunrise),
            "sunset_utc": _iso_utc(sunset),
            "method_key": "unequal_planetary_hours_from_sun_rise_set",
        }

    day_len = (sunset - sunrise).total_seconds()
    night_len = (next_sunrise - sunset).total_seconds()
    if day_len <= 0 or night_len <= 0:
        return {
            "status": "unavailable",
            "reason": "non_positive_day_or_night_length",
            "hours": [],
            "sunrise_utc": _iso_utc(sunrise),
            "sunset_utc": _iso_utc(sunset),
            "method_key": "unequal_planetary_hours_from_sun_rise_set",
        }

    local_sunrise = sunrise.astimezone(display_zone)
    weekday = local_sunrise.weekday()  # Mon=0
    day_ruler = WEEKDAY_RULER[weekday]
    start_index = CHALDEAN_ORDER.index(day_ruler)
    day_hour = day_len / 12.0
    night_hour = night_len / 12.0
    hours: list[dict[str, Any]] = []
    for i in range(12):
        start = sunrise + timedelta(seconds=day_hour * i)
        end = sunrise + timedelta(seconds=day_hour * (i + 1))
        ruler = CHALDEAN_ORDER[(start_index + i) % 7]
        hours.append(
            {
                "hour_index": i + 1,
                "period": "day",
                "ruler_id": ruler,
                "ruler_name": PLANET_NAMES[ruler],
                "start_utc": _iso_utc(start),
                "end_utc": _iso_utc(end),
                "start_local": _iso_local(start, display_zone),
                "end_local": _iso_local(end, display_zone),
                "duration_minutes": round(day_hour / 60.0, 4),
            }
        )
    for i in range(12):
        start = sunset + timedelta(seconds=night_hour * i)
        end = sunset + timedelta(seconds=night_hour * (i + 1))
        ruler = CHALDEAN_ORDER[(start_index + 12 + i) % 7]
        hours.append(
            {
                "hour_index": i + 1,
                "period": "night",
                "ruler_id": ruler,
                "ruler_name": PLANET_NAMES[ruler],
                "start_utc": _iso_utc(start),
                "end_utc": _iso_utc(end),
                "start_local": _iso_local(start, display_zone),
                "end_local": _iso_local(end, display_zone),
                "duration_minutes": round(night_hour / 60.0, 4),
            }
        )

    current = None
    for hour in hours:
        start = datetime.fromisoformat(hour["start_utc"].replace("Z", "+00:00"))
        end = datetime.fromisoformat(hour["end_utc"].replace("Z", "+00:00"))
        if start <= reference_utc < end:
            current = hour
            break

    return {
        "status": "ok",
        "method_key": "unequal_planetary_hours_chaldean",
        "weekday_local": local_sunrise.strftime("%A"),
        "day_ruler_id": day_ruler,
        "day_ruler_name": PLANET_NAMES[day_ruler],
        "sunrise_utc": _iso_utc(sunrise),
        "sunset_utc": _iso_utc(sunset),
        "next_sunrise_utc": _iso_utc(next_sunrise),
        "sunrise_local": _iso_local(sunrise, display_zone),
        "sunset_local": _iso_local(sunset, display_zone),
        "next_sunrise_local": _iso_local(next_sunrise, display_zone),
        "day_hour_minutes": round(day_hour / 60.0, 4),
        "night_hour_minutes": round(night_hour / 60.0, 4),
        "current_hour": current,
        "hours": hours,
    }


def calculate_classical_visibility(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    moment = request.get("moment") or request.get("reference")
    reference_utc = _require_moment(moment, "moment")
    location = request.get("location")
    if not isinstance(location, dict):
        raise ValueError("location must be an object with latitude/longitude")
    for field in ("latitude", "longitude"):
        if field not in location:
            raise ValueError(f"location.{field} is required")
    latitude = float(location["latitude"])
    longitude = float(location["longitude"])
    if not (-90 <= latitude <= 90 and -180 <= longitude <= 180):
        raise ValueError("location coordinates out of range")
    altitude_m = float(location.get("altitude_m") or 0.0)
    display_timezone = str(
        request.get("display_timezone")
        or location.get("timezone")
        or "UTC"
    ).strip() or "UTC"
    try:
        display_zone = ZoneInfo(display_timezone)
    except Exception:
        display_zone = resolve_timezone(display_timezone)  # type: ignore[assignment]

    body_ids = request.get("body_ids") or DEFAULT_BODIES
    if not isinstance(body_ids, list) or not body_ids:
        raise ValueError("body_ids must be a non-empty array")
    event_types = request.get("heliacal_event_types") or DEFAULT_HELIACAL_EVENTS
    if not isinstance(event_types, list) or not event_types:
        raise ValueError("heliacal_event_types must be a non-empty array")
    observer_age = float(request.get("observer_age") or 36)
    include = set(request.get("include") or ["heliacal", "rise_set", "planetary_hours"])

    section_errors: dict[str, str] = {}
    heliacal: list[dict[str, Any]] = []
    rise_set: list[dict[str, Any]] = []
    planetary_hours: dict[str, Any] | None = None

    if "heliacal" in include:
        try:
            heliacal = _heliacal_events(
                body_ids=[str(b) for b in body_ids],
                event_types=[str(e) for e in event_types],
                start_utc=reference_utc,
                latitude=latitude,
                longitude=longitude,
                altitude_m=altitude_m,
                observer_age=observer_age,
                warnings=warnings,
                display_zone=display_zone,  # type: ignore[arg-type]
            )
        except Exception as exc:
            section_errors["heliacal"] = str(exc)
            warnings.append(f"heliacal 计算失败：{exc}")

    if "rise_set" in include:
        try:
            targets = list(dict.fromkeys(["SUN"] + [str(b) for b in body_ids]))
            for body_id in targets:
                row = _body_rise_set(
                    body_id, reference_utc, latitude, longitude, altitude_m, warnings
                )
                if row.get("rise_utc"):
                    dt = datetime.fromisoformat(row["rise_utc"].replace("Z", "+00:00"))
                    row["rise_local"] = _iso_local(dt, display_zone)  # type: ignore[arg-type]
                if row.get("set_utc"):
                    dt = datetime.fromisoformat(row["set_utc"].replace("Z", "+00:00"))
                    row["set_local"] = _iso_local(dt, display_zone)  # type: ignore[arg-type]
                rise_set.append(row)
        except Exception as exc:
            section_errors["rise_set"] = str(exc)
            warnings.append(f"升落计算失败：{exc}")

    if "planetary_hours" in include:
        try:
            planetary_hours = _planetary_hours(
                reference_utc=reference_utc,
                latitude=latitude,
                longitude=longitude,
                altitude_m=altitude_m,
                display_zone=display_zone,  # type: ignore[arg-type]
                warnings=warnings,
            )
            if planetary_hours.get("status") != "ok":
                section_errors["planetary_hours"] = str(planetary_hours.get("reason"))
                warnings.append(
                    f"行星时不可用：{planetary_hours.get('reason')}（可能极昼/极夜或升落缺失）"
                )
        except Exception as exc:
            section_errors["planetary_hours"] = str(exc)
            warnings.append(f"行星时计算失败：{exc}")
            planetary_hours = {"status": "error", "hours": [], "error": str(exc)}

    calculation_assumptions = [
        "heliacal 使用 swe.heliacal_ut，默认大气 1013.25 hPa / 15°C / RH 40%。",
        "地方升落使用 swe.rise_trans + BIT_DISC_CENTER（含折射默认）。",
        "行星时为日出至日落 12 个不等昼时 + 日落至次日日出 12 个不等夜时。",
        "行星时主星按迦勒底序，以当地日出 weekday 的日主起算。",
        "极区或升落失败时不生成伪造小时，写入 section_errors/warnings。",
        "结果为可复算时间与坐标事实，不含解释性论断。",
    ]

    return {
        "meta": {
            "mode": "classical_visibility",
            "method": METHOD,
            "schema_version": SCHEMA_VERSION,
            "reference_utc": _iso_utc(reference_utc),
            "display_timezone": display_timezone,
            "location": {
                "name": str(location.get("name") or ""),
                "latitude": latitude,
                "longitude": longitude,
                "altitude_m": altitude_m,
                "timezone": display_timezone,
            },
            "body_ids": [str(b) for b in body_ids],
            "heliacal_event_types": [str(e) for e in event_types],
            "include": sorted(include),
            "ephemeris": "Swiss Ephemeris",
        },
        "requested_config": {
            "moment": moment,
            "location": location,
            "body_ids": body_ids,
            "heliacal_event_types": event_types,
            "include": sorted(include),
            "observer_age": observer_age,
        },
        "effective_config": {
            "display_timezone": display_timezone,
            "body_ids": [str(b) for b in body_ids],
            "heliacal_event_types": [str(e) for e in event_types],
            "include": sorted(include),
            "observer_age": observer_age,
            "atmosphere_defaults": {"pressure_hpa": 1013.25, "temperature_c": 15.0, "rh": 40.0},
        },
        "heliacal_events": heliacal,
        "rise_set": rise_set,
        "planetary_hours": planetary_hours,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": section_errors or None,
        "calculation_assumptions": calculation_assumptions,
    }


__all__ = ["calculate_classical_visibility"]
