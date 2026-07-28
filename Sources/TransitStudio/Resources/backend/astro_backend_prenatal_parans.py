"""Prenatal syzygy packet + true fixed-star paran event pairs (B18)."""

from __future__ import annotations

from datetime import datetime, time, timedelta, timezone
from typing import Any

from astro_backend_classical_audit import calculate_prenatal_syzygy
from astro_backend_core import (
    jd_from_datetime,
    moment_to_jd,
    moment_to_local_datetime,
    set_zodiac_mode,
    signed_orb,
    swe,
)
from astro_backend_ephemeris import build_houses, calculate_positions, house_rows, point_row, resolve_bodies
from astro_backend_fixed_stars import compute_star_positions

METHOD = "prenatal_parans_v2"
EVENT_METHOD_KEY = "swiss_rise_trans_event_pair_v2"
LEGACY_METHOD_KEY = "fixed_star_paran_ra_proxy_v1"
DEFAULT_EVENT_ORB_SECONDS = 240.0
DEFAULT_RA_ORB_DEG = 1.0
_DAY_EDGE_EPSILON_DAYS = 1.0 / 864_000.0
_NEXT_EVENT_EPSILON_DAYS = 1.0 / 86_400.0

EVENT_SPECS: tuple[tuple[str, int], ...] = (
    ("rising", swe.CALC_RISE),
    ("culminating", swe.CALC_MTRANSIT),
    ("setting", swe.CALC_SET),
    ("lower_culminating", swe.CALC_ITRANSIT),
)


def _iso_utc(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _datetime_from_jd(jd: float) -> datetime:
    year, month, day, hour = swe.revjul(jd, swe.GREG_CAL)
    return datetime(year, month, day, tzinfo=timezone.utc) + timedelta(hours=hour)


def _local_civil_day(birth_dt: datetime) -> tuple[datetime, datetime]:
    zone = birth_dt.tzinfo
    if zone is None:
        raise ValueError("birth moment timezone is required for local paran events")
    start = datetime.combine(birth_dt.date(), time.min, tzinfo=zone)
    end = datetime.combine(birth_dt.date() + timedelta(days=1), time.min, tzinfo=zone)
    return start, end


def _event_rsmi(event_type: str, base_flag: int) -> int:
    if event_type in {"rising", "setting"}:
        return base_flag | swe.BIT_DISC_CENTER | swe.BIT_NO_REFRACTION
    return base_flag


def _collect_object_events(
    *,
    body: int | str,
    object_id: str,
    object_name: str,
    object_kind: str,
    start_jd: float,
    end_jd: float,
    geopos: tuple[float, float, float],
    display_zone: Any,
) -> tuple[list[dict[str, Any]], dict[str, Any] | None]:
    events: list[dict[str, Any]] = []
    unavailable: list[dict[str, str]] = []
    for event_type, base_flag in EVENT_SPECS:
        rsmi = _event_rsmi(event_type, base_flag)
        cursor = start_jd - _DAY_EDGE_EPSILON_DAYS
        event_count = 0
        while event_count < 3:
            try:
                result, times = swe.rise_trans(
                    cursor,
                    body,
                    rsmi,
                    geopos,
                    0.0,
                    0.0,
                    swe.FLG_SWIEPH,
                )
            except Exception as exc:
                unavailable.append({"event_type": event_type, "reason": f"swiss_error: {exc}"})
                break
            if result == -2:
                unavailable.append({"event_type": event_type, "reason": "circumpolar_event_unavailable"})
                break
            if result != 0 or not times or float(times[0]) <= 0:
                unavailable.append({"event_type": event_type, "reason": f"swiss_result_{result}"})
                break
            event_jd = float(times[0])
            if event_jd >= end_jd:
                if event_count == 0:
                    unavailable.append({"event_type": event_type, "reason": "no_event_in_local_civil_day"})
                break
            if event_jd >= start_jd:
                event_dt = _datetime_from_jd(event_jd)
                events.append(
                    {
                        "object_id": object_id,
                        "object_name": object_name,
                        "object_kind": object_kind,
                        "event_type": event_type,
                        "event_jd": event_jd,
                        "event_utc": _iso_utc(event_dt),
                        "event_local": event_dt.astimezone(display_zone).isoformat(timespec="milliseconds"),
                        "swiss_event_flag": base_flag,
                        "swiss_rsmi": rsmi,
                    }
                )
                event_count += 1
            cursor = event_jd + _NEXT_EVENT_EPSILON_DAYS
    events.sort(key=lambda row: (float(row["event_jd"]), str(row["event_type"])))
    if not unavailable:
        return events, None
    return events, {
        "object_id": object_id,
        "object_name": object_name,
        "object_kind": object_kind,
        "available_event_types": sorted({str(row["event_type"]) for row in events}),
        "unavailable_events": unavailable,
    }


def _pair_true_parans(
    *,
    planet_specs: list[Any],
    stars: list[dict[str, Any]],
    start_jd: float,
    end_jd: float,
    geopos: tuple[float, float, float],
    display_zone: Any,
    event_orb_seconds: float,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    object_events: dict[tuple[str, str], list[dict[str, Any]]] = {}
    diagnostics: list[dict[str, Any]] = []
    for spec in planet_specs:
        events, diagnostic = _collect_object_events(
            body=spec.code,
            object_id=spec.body_id,
            object_name=spec.name,
            object_kind="planet",
            start_jd=start_jd,
            end_jd=end_jd,
            geopos=geopos,
            display_zone=display_zone,
        )
        object_events[("planet", spec.body_id)] = events
        if diagnostic:
            diagnostics.append(diagnostic)
    for star in stars:
        star_id = str(star.get("swe_name") or star.get("name"))
        star_name = str(star.get("name") or star_id)
        events, diagnostic = _collect_object_events(
            body=star_id,
            object_id=star_id,
            object_name=star_name,
            object_kind="fixed_star",
            start_jd=start_jd,
            end_jd=end_jd,
            geopos=geopos,
            display_zone=display_zone,
        )
        object_events[("fixed_star", star_id)] = events
        if diagnostic:
            diagnostics.append(diagnostic)

    parans: list[dict[str, Any]] = []
    for spec in planet_specs:
        planet_events = object_events.get(("planet", spec.body_id), [])
        for star in stars:
            star_id = str(star.get("swe_name") or star.get("name"))
            star_name = str(star.get("name") or star_id)
            star_events = object_events.get(("fixed_star", star_id), [])
            for planet_event in planet_events:
                for star_event in star_events:
                    delta_seconds = abs(
                        (float(planet_event["event_jd"]) - float(star_event["event_jd"])) * 86_400.0
                    )
                    if delta_seconds > event_orb_seconds:
                        continue
                    parans.append(
                        {
                            "planet_id": spec.body_id,
                            "planet_name": spec.name,
                            "star_id": star_id,
                            "star_name": star_name,
                            "planet_event_type": planet_event["event_type"],
                            "star_event_type": star_event["event_type"],
                            "planet_event_utc": planet_event["event_utc"],
                            "planet_event_local": planet_event["event_local"],
                            "star_event_utc": star_event["event_utc"],
                            "star_event_local": star_event["event_local"],
                            "planet_event_jd": round(float(planet_event["event_jd"]), 9),
                            "star_event_jd": round(float(star_event["event_jd"]), 9),
                            "event_delta_seconds": round(delta_seconds, 3),
                            "event_orb_seconds": event_orb_seconds,
                            "paran_class": "local_horizon_meridian_event_pair",
                            "method_key": EVENT_METHOD_KEY,
                            "proxy": False,
                            "full_paran": True,
                            "method_trace": {
                                "provider": "Swiss Ephemeris",
                                "function": "swe.rise_trans",
                                "ephemeris_flags": ["FLG_SWIEPH"],
                                "planet_event_flag": planet_event["swiss_event_flag"],
                                "planet_rsmi": planet_event["swiss_rsmi"],
                                "star_event_flag": star_event["swiss_event_flag"],
                                "star_rsmi": star_event["swiss_rsmi"],
                                "rise_set_options": ["BIT_DISC_CENTER", "BIT_NO_REFRACTION"],
                                "pairing_rule": "absolute local-event time delta within event_orb_seconds",
                            },
                        }
                    )
    parans.sort(
        key=lambda row: (
            float(row["event_delta_seconds"]),
            str(row["planet_id"]),
            str(row["star_name"]),
            str(row["planet_event_type"]),
            str(row["star_event_type"]),
        )
    )
    return parans, diagnostics


def _legacy_ra_proxy_rows(
    *,
    jd: float,
    planets: list[dict[str, Any]],
    stars: list[dict[str, Any]],
    warnings: list[str],
    ra_orb_deg: float,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for planet in planets:
        try:
            code = resolve_bodies([planet["body_id"]], [], warnings)[0].code
            equatorial, _ = swe.calc_ut(jd, code, swe.FLG_SWIEPH | swe.FLG_EQUATORIAL)
            planet_ra = float(equatorial[0])
            planet_declination = float(equatorial[1])
        except Exception:
            continue
        for star in stars:
            star_ra = star.get("ra") or star.get("right_ascension")
            if star_ra is None:
                continue
            ra_delta = abs(((float(star_ra) - planet_ra + 180.0) % 360.0) - 180.0)
            if ra_delta > ra_orb_deg:
                continue
            star_declination = star.get("declination") or star.get("dec")
            star_longitude = star.get("longitude") or star.get("lon")
            ecliptic_orb = (
                abs(signed_orb(float(planet["longitude"]), float(star_longitude)))
                if star_longitude is not None and planet.get("longitude") is not None
                else None
            )
            rows.append(
                {
                    "planet_id": planet["body_id"],
                    "planet_name": planet["name"],
                    "star_id": star.get("swe_name") or star.get("name"),
                    "star_name": star.get("name") or star.get("id"),
                    "planet_ra": round(planet_ra, 6),
                    "star_ra": round(float(star_ra), 6),
                    "ra_delta_deg": round(ra_delta, 6),
                    "planet_declination": round(planet_declination, 6),
                    "star_declination": (
                        round(float(star_declination), 6) if star_declination is not None else None
                    ),
                    "event_delta_seconds": None,
                    "also_ecliptic_conjunction": ecliptic_orb is not None and ecliptic_orb <= 1.0,
                    "ecliptic_orb": round(ecliptic_orb, 6) if ecliptic_orb is not None else None,
                    "coordinate_epoch": "of_date",
                    "position_type": "apparent_equatorial",
                    "paran_class": "approximate_co_culmination_ra_proxy",
                    "method_key": "fixed_star_ra_conjunction",
                    "method_key_legacy": LEGACY_METHOD_KEY,
                    "proxy": True,
                    "full_paran": False,
                    "note": (
                        "Legacy RA co-culmination proxy retained for migration only; "
                        "use fixed_star_parans for true local event pairs."
                    ),
                }
            )
    rows.sort(key=lambda row: (float(row["ra_delta_deg"]), str(row["planet_id"]), str(row["star_name"])))
    return rows


def calculate_prenatal_parans(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    birth_dt = moment_to_local_datetime(birth["moment"])
    jd, birth_utc = moment_to_jd(birth["moment"])
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)
    lat = float(birth["latitude"])
    lon = float(birth["longitude"])
    altitude = float(birth.get("altitude_m") or 0.0)
    house_system = birth.get("houseSystem", birth.get("house_system", "whole_sign"))
    event_orb_seconds = float(request.get("paran_event_orb_seconds", DEFAULT_EVENT_ORB_SECONDS))
    ra_orb_deg = float(request.get("paran_ra_orb_deg", DEFAULT_RA_ORB_DEG))
    include_legacy = bool(request.get("include_legacy_paran_proxy", True))

    syzygy = calculate_prenatal_syzygy(jd, birth_dt, warnings, sidereal=sidereal)
    syzygy_jd = syzygy.get("jd") or syzygy.get("julian_day") or syzygy.get("exact_jd")
    packet: dict[str, Any] = {"prenatal_syzygy": syzygy}
    section_errors: dict[str, str] = {}
    if syzygy_jd:
        try:
            chart_specs = resolve_bodies(
                ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"], [], warnings
            )
            positions = calculate_positions(float(syzygy_jd), chart_specs, warnings, sidereal=sidereal)
            cusps, angles, label = build_houses(
                float(syzygy_jd), lat, lon, house_system, sidereal, warnings
            )
            packet["syzygy_chart"] = {
                "planets": positions,
                "angles": [
                    point_row(angle_id, angle_id, angles[angle_id], cusps)
                    for angle_id in ("ASC", "MC", "DSC", "IC")
                    if angle_id in angles
                ],
                "houses": house_rows(cusps),
                "house_system": label,
                "method_key": "syzygy_chart_from_exact_jd",
            }
        except Exception as exc:
            section_errors["syzygy_chart"] = str(exc)
            warnings.append(f"syzygy chart: {exc}")
    else:
        warnings.append("prenatal syzygy payload missing jd; chart packet limited")

    parans: list[dict[str, Any]] = []
    legacy_parans: list[dict[str, Any]] = []
    event_diagnostics: list[dict[str, Any]] = []
    local_start, local_end = _local_civil_day(birth_dt)
    start_jd = jd_from_datetime(local_start)
    end_jd = jd_from_datetime(local_end)
    geopos = (lon, lat, altitude)
    try:
        stars = compute_star_positions(jd, warnings=warnings, sidereal=sidereal)[:40]
        planet_specs = resolve_bodies(
            ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"], [], warnings
        )
        parans, event_diagnostics = _pair_true_parans(
            planet_specs=planet_specs,
            stars=stars,
            start_jd=start_jd,
            end_jd=end_jd,
            geopos=geopos,
            display_zone=birth_dt.tzinfo,
            event_orb_seconds=event_orb_seconds,
        )
        if include_legacy:
            planets = calculate_positions(jd, planet_specs, warnings, sidereal=sidereal)
            legacy_parans = _legacy_ra_proxy_rows(
                jd=jd,
                planets=planets,
                stars=stars,
                warnings=warnings,
                ra_orb_deg=ra_orb_deg,
            )
    except Exception as exc:
        section_errors["parans"] = str(exc)
        warnings.append(f"parans: {exc}")

    circumpolar_diagnostics = [
        row
        for row in event_diagnostics
        if any(
            item.get("event_type") in {"rising", "setting"}
            and item.get("reason") == "circumpolar_event_unavailable"
            for item in row.get("unavailable_events", [])
        )
    ]
    if circumpolar_diagnostics:
        warnings.append(
            "Polar/circumpolar degradation: unavailable rising/setting events were omitted; "
            "available meridian events were retained without fabrication."
        )

    method_trace = {
        "provider": "Swiss Ephemeris",
        "function": "swe.rise_trans",
        "event_flags": {
            "rising": "CALC_RISE",
            "culminating": "CALC_MTRANSIT",
            "setting": "CALC_SET",
            "lower_culminating": "CALC_ITRANSIT",
        },
        "rise_set_options": ["BIT_DISC_CENTER", "BIT_NO_REFRACTION"],
        "ephemeris_flags": ["FLG_SWIEPH"],
        "geopos": {"longitude": lon, "latitude": lat, "altitude_m": altitude},
        "local_day_basis": "birth-place local civil date",
        "local_day_start": local_start.isoformat(timespec="seconds"),
        "local_day_end": local_end.isoformat(timespec="seconds"),
        "utc_day_start": _iso_utc(local_start),
        "utc_day_end": _iso_utc(local_end),
        "pairing_rule": "absolute event time delta <= paran_event_orb_seconds",
    }
    return {
        "meta": {
            "mode": "prenatal_parans",
            "method": METHOD,
            "schema_version": 2,
            "birth_utc": birth_utc,
            "paran_count": len(parans),
            "legacy_paran_count": len(legacy_parans),
            "ephemeris": "Swiss Ephemeris",
        },
        "requested_config": {
            "paran_event_orb_seconds": request.get(
                "paran_event_orb_seconds", DEFAULT_EVENT_ORB_SECONDS
            ),
            "paran_ra_orb_deg": request.get("paran_ra_orb_deg", DEFAULT_RA_ORB_DEG),
            "include_legacy_paran_proxy": request.get("include_legacy_paran_proxy", True),
        },
        "effective_config": {
            "paran_class": "local_horizon_meridian_event_pair",
            "event_types": [event_type for event_type, _ in EVENT_SPECS],
            "event_orb_seconds": event_orb_seconds,
            "method": METHOD,
            "legacy_proxy_output": "legacy_fixed_star_parans" if include_legacy else "disabled",
        },
        "method_trace": method_trace,
        "prenatal_packet": packet,
        "fixed_star_parans": parans,
        "legacy_fixed_star_parans": legacy_parans,
        "event_diagnostics": event_diagnostics,
        "polar_degradation": {
            "active": bool(circumpolar_diagnostics),
            "strategy": "omit_unavailable_horizon_events_keep_available_meridian_events",
            "affected_object_count": len(circumpolar_diagnostics),
            "affected_objects": [
                {
                    "object_id": row["object_id"],
                    "object_name": row["object_name"],
                    "object_kind": row["object_kind"],
                }
                for row in circumpolar_diagnostics
            ],
        },
        "migration": {
            "from": "fixed_star_parans RA co-culmination proxy (schema v1)",
            "to": "fixed_star_parans true local event pairs (schema v2)",
            "legacy_output": "legacy_fixed_star_parans",
            "legacy_method_key": LEGACY_METHOD_KEY,
            "disable_legacy_request_key": "include_legacy_paran_proxy=false",
        },
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": section_errors or None,
        "calculation_assumptions": [
            "Prenatal syzygy from calculate_prenatal_syzygy; chart rebuilt at exact jd when available.",
            "True parans pair independently calculated local rising, upper-transit, setting, and lower-transit events.",
            "Rise/set use apparent-disc-center disabled refraction flags; meridian transits use their direct Swiss flags.",
            "Unavailable circumpolar horizon events are omitted; available culmination events remain eligible.",
            "legacy_fixed_star_parans is an RA proximity proxy retained only for schema-v1 migration.",
        ],
    }


__all__ = ["calculate_prenatal_parans"]
