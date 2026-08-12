"""Auditable primary-motion directions to the four natal angles.

This module intentionally implements only the geometrically well-defined
planet-to-angle subset of primary directions.  It is not labelled as a full
Placidian or Regiomontanian suite: directions to non-angular significators,
mundane/zodiacal aspect construction, under-the-pole variants, and converse
recomputation require separate method profiles and external reference tables.

The subset is useful for birth-time research because ASC/MC/DSC/IC are the
chart factors that move materially when the candidate birth time changes.
"""

from __future__ import annotations

import math
from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_core import BODY_REGISTRY, CLASSICAL_BODY_IDS, jd_from_datetime, norm360, planet_name
from astro_backend_ephemeris import build_houses, calculate_positions, obliquity_deg


NAIBOD_MEAN_RATE = 0.98564733
KEY_RATES: dict[str, float] = {
    "naibod_mean": NAIBOD_MEAN_RATE,
    "one_degree_per_year": 1.0,
}

PRIMARY_MOTION_ANGLE_PROFILE: dict[str, Any] = {
    "profile_id": "primary_motion_planet_to_angles_v1",
    "family": "primary_motion",
    "status": "formal_geometry_subset",
    "role": "fine_timing",
    "independence_group": "primary_motion",
    "includes": [
        "planet-to-MC/IC conjunction by right ascension",
        "planet-to-ASC/DSC conjunction by oblique ascension/descension",
        "planetary ecliptic latitude in RA/declination conversion",
        "circumpolar rise/set diagnostics",
    ],
    "excludes": [
        "non-angular significators",
        "mundane or zodiacal aspects",
        "under-the-pole directions",
        "full Placidian or Regiomontanian primary directions",
        "a separately recomputed converse system",
    ],
}

ANGLE_IDS = ("ASC", "MC", "DSC", "IC")


def _signed_shortest_arc(target: float, source: float) -> float:
    """Return target-source in the signed -180..+180 interval."""
    value = (target - source + 180.0) % 360.0 - 180.0
    # Keep the positive convention deterministic at the exactly-opposite case.
    return 180.0 if math.isclose(value, -180.0, abs_tol=1e-12) else value


def equatorial_coordinates(
    longitude: float,
    latitude: float,
    obliquity: float,
) -> tuple[float, float]:
    """Convert ecliptic longitude/latitude to right ascension/declination.

    All arguments and return values are degrees.  Unlike the legacy rectify
    proxy, this conversion retains the body's ecliptic latitude.
    """
    lon = math.radians(longitude)
    lat = math.radians(latitude)
    eps = math.radians(obliquity)

    x = math.cos(lat) * math.cos(lon)
    y = math.cos(lat) * math.sin(lon) * math.cos(eps) - math.sin(lat) * math.sin(eps)
    z = math.cos(lat) * math.sin(lon) * math.sin(eps) + math.sin(lat) * math.cos(eps)

    ra = norm360(math.degrees(math.atan2(y, x)))
    decl = math.degrees(math.asin(max(-1.0, min(1.0, z))))
    return ra, decl


def ascensional_difference(declination: float, geographic_latitude: float) -> float | None:
    """Return ascensional difference, or ``None`` for a circumpolar body."""
    value = math.tan(math.radians(geographic_latitude)) * math.tan(math.radians(declination))
    if not math.isfinite(value) or abs(value) > 1.0:
        return None
    return math.degrees(math.asin(value))


def primary_motion_arc_to_angle(
    right_ascension: float,
    declination: float,
    geographic_latitude: float,
    armc: float,
    angle_id: str,
) -> tuple[float, dict[str, Any]] | None:
    """Calculate a planet's signed primary-motion arc to a cardinal angle.

    The sign convention is ``target_axis_coordinate - promissor_coordinate``.
    Its sign labels the direction branch; event age always uses the absolute
    arc and therefore remains after birth for both branches.
    """
    angle = angle_id.upper()
    if angle not in ANGLE_IDS:
        raise ValueError(f"unsupported primary-motion angle: {angle_id}")

    armc = norm360(armc)
    ra = norm360(right_ascension)
    diagnostics: dict[str, Any] = {
        "right_ascension": round(ra, 9),
        "declination": round(declination, 9),
        "armc": round(armc, 9),
    }

    if angle == "MC":
        source = ra
        target = armc
        coordinate = "right_ascension"
    elif angle == "IC":
        source = ra
        target = norm360(armc + 180.0)
        coordinate = "right_ascension"
    else:
        ad = ascensional_difference(declination, geographic_latitude)
        if ad is None:
            return None
        diagnostics["ascensional_difference"] = round(ad, 9)
        if angle == "ASC":
            source = norm360(ra - ad)  # oblique ascension
            target = norm360(armc + 90.0)
            coordinate = "oblique_ascension"
        else:
            source = norm360(ra + ad)  # oblique descension
            target = norm360(armc + 270.0)
            coordinate = "oblique_descension"

    arc = _signed_shortest_arc(target, source)
    diagnostics.update(
        {
            "coordinate": coordinate,
            "promissor_coordinate": round(source, 9),
            "target_coordinate": round(target, 9),
            "arc_sign_convention": "target_minus_promissor_shortest_arc",
        }
    )
    return arc, diagnostics


def _event_datetime(birth_dt: datetime, age_years: float) -> datetime:
    # Treat the symbolic day count as elapsed time.  Adding directly in a
    # ZoneInfo wall clock would insert/remove a DST hour across long spans.
    return (
        birth_dt.astimezone(timezone.utc) + timedelta(days=age_years * 365.2425)
    ).astimezone(birth_dt.tzinfo)


def calculate_primary_motion_to_angles(
    birth_jd: float,
    birth_dt: datetime,
    geographic_latitude: float,
    geographic_longitude: float,
    house_system: str,
    warnings: list[str],
    *,
    body_ids: list[str] | None = None,
    angle_ids: list[str] | None = None,
    key_profile: str = "naibod_mean",
    max_age: float = 120.0,
) -> list[dict[str, Any]]:
    """Return high-precision planet-to-angle primary-motion directions."""
    if key_profile not in KEY_RATES:
        raise ValueError(f"unsupported primary direction key_profile: {key_profile}")
    key_rate = KEY_RATES[key_profile]
    selected_bodies = list(dict.fromkeys(body_ids or list(CLASSICAL_BODY_IDS)))
    selected_angles = list(dict.fromkeys(angle.upper() for angle in (angle_ids or list(ANGLE_IDS))))
    unknown_bodies = [body_id for body_id in selected_bodies if body_id not in BODY_REGISTRY]
    unknown_angles = [angle for angle in selected_angles if angle not in ANGLE_IDS]
    if unknown_bodies:
        raise ValueError(f"unsupported primary-motion bodies: {', '.join(unknown_bodies)}")
    if unknown_angles:
        raise ValueError(f"unsupported primary-motion angles: {', '.join(unknown_angles)}")
    if not math.isfinite(max_age) or max_age < 0:
        raise ValueError("max_age must be a finite non-negative number")

    # Primary motion is an equatorial/terrestrial geometry.  Use tropical
    # physical longitudes even when the interpretive chart is sidereal.
    specs = [BODY_REGISTRY[body_id] for body_id in selected_bodies]
    positions = calculate_positions(birth_jd, specs, warnings, sidereal=False)
    _, angles, _ = build_houses(
        birth_jd,
        geographic_latitude,
        geographic_longitude,
        house_system,
        False,
        warnings,
    )
    armc = angles.get("ARMC")
    if armc is None:
        raise RuntimeError("ARMC is required for primary-motion directions")
    eps = obliquity_deg(birth_jd)

    rows: list[dict[str, Any]] = []
    circumpolar_seen: set[str] = set()
    for position in positions:
        body_id = str(position["body_id"])
        ecliptic_latitude = float(position.get("latitude") or 0.0)
        ra, decl = equatorial_coordinates(
            float(position["longitude"]),
            ecliptic_latitude,
            eps,
        )
        for angle_id in selected_angles:
            calculated = primary_motion_arc_to_angle(
                ra,
                decl,
                geographic_latitude,
                float(armc),
                angle_id,
            )
            if calculated is None:
                warning_key = f"{body_id}:{angle_id}"
                if warning_key not in circumpolar_seen:
                    warnings.append(
                        f"{body_id} 对 {angle_id} 的升降方向不可得：该赤纬在出生纬度下为绕极状态。"
                    )
                    circumpolar_seen.add(warning_key)
                continue

            arc_signed, diagnostics = calculated
            age_years = abs(arc_signed) / key_rate
            if age_years > max_age:
                continue
            event_dt = _event_datetime(birth_dt, age_years)
            rows.append(
                {
                    "id": f"pm-angle-{key_profile}-{body_id}-{angle_id}",
                    "method_profile": PRIMARY_MOTION_ANGLE_PROFILE["profile_id"],
                    "method_family": "primary_motion",
                    "method_status": PRIMARY_MOTION_ANGLE_PROFILE["status"],
                    "independence_group": "primary_motion",
                    "key_profile": key_profile,
                    "key_rate_deg_per_year": key_rate,
                    "promissor_id": body_id,
                    "promissor": planet_name(body_id),
                    "significator_id": angle_id,
                    "significator": angle_id,
                    "aspect_type": "conjunction",
                    "direction_type": "direct" if arc_signed >= 0 else "converse_label",
                    "arc_signed": round(arc_signed, 9),
                    "arc_abs": round(abs(arc_signed), 9),
                    "age_years": round(age_years, 9),
                    "event_datetime_after_birth": event_dt.isoformat(),
                    "event_date_after_birth": event_dt.strftime("%Y-%m-%d"),
                    "proxy": False,
                    "complete_primary_directions_suite": False,
                    "geometry": diagnostics,
                }
            )

    rows.sort(key=lambda row: (float(row["age_years"]), str(row["id"])))
    return rows


__all__ = [
    "ANGLE_IDS",
    "KEY_RATES",
    "NAIBOD_MEAN_RATE",
    "PRIMARY_MOTION_ANGLE_PROFILE",
    "ascensional_difference",
    "calculate_primary_motion_to_angles",
    "equatorial_coordinates",
    "primary_motion_arc_to_angle",
]
