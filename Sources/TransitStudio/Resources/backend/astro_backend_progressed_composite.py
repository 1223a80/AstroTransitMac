"""Progressed Composite calculations.

This module intentionally keeps the Progressed Composite definition separate
from ``astro_backend_composite``.  A Composite is not a chart with a birth
moment that can itself be progressed: each person's chart is progressed at
the same real-world reference first, and only then are same-body longitudes
midpointed.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from astro_backend_core import (
    circular_midpoint,
    format_longitude,
    jd_from_datetime,
    moment_to_jd,
    moment_to_local_datetime,
    set_zodiac_mode,
)
from astro_backend_ephemeris import calculate_positions, resolve_bodies
from astro_backend_modern_points import (
    DEFAULT_MODERN_BODY_IDS,
    finalize_point_set,
    resolve_point_set,
)
from astro_backend_progressions import _calc_progressed_dt
from astro_backend_scan import find_aspects


METHOD = "progress_each_person_then_midpoint"


def _utc_context(moment: Any, label: str) -> tuple[datetime, float, str]:
    """Return an aware UTC datetime, Julian Day, and canonical UTC string."""
    if not isinstance(moment, dict):
        raise ValueError(f"{label} must be an object with an exact moment")
    try:
        local_dt = moment_to_local_datetime(moment)
        utc_dt = local_dt.astimezone(timezone.utc)
        jd, utc_text = moment_to_jd(moment)
    except Exception as exc:
        raise ValueError(f"{label} is invalid: {exc}") from exc
    return utc_dt, jd, utc_text


def _reject_unsupported_point_set(raw: Any) -> None:
    """Reject v1 point-set sections that this mode must never calculate."""
    if raw is None:
        return
    if not isinstance(raw, dict):
        return

    # ``angle_ids`` and ``house_cusps`` are the established point-set names;
    # ``angles`` is also rejected defensively so an unrecognised alias cannot
    # silently slip through the shared resolver.
    for field in ("angle_ids", "angles", "house_cusps", "lot_ids", "midpoint_pairs"):
        value = raw.get(field)
        if value:
            raise ValueError(
                f"progressed_composite point_set.{field} must be empty in v1; "
                "only bodies, nodes, and custom asteroids are supported"
            )


def _position_map(
    jd: float,
    specs: list[Any],
    warnings: list[str],
    sidereal: bool,
) -> dict[str, dict[str, Any]]:
    rows = calculate_positions(jd, specs, warnings, sidereal=sidereal)
    return {str(row["body_id"]): row for row in rows if "body_id" in row}


def _midpoint_rows(
    specs: list[Any],
    person_a_positions: dict[str, dict[str, Any]],
    person_b_positions: dict[str, dict[str, Any]],
    *,
    phase: str,
    person_a_birth_utc: str,
    person_b_birth_utc: str,
    person_a_progressed_utc: str,
    person_b_progressed_utc: str,
    reference_utc: str,
) -> list[dict[str, Any]]:
    """Build rows only for same-named bodies available in both charts."""
    rows: list[dict[str, Any]] = []
    for spec in specs:
        body_id = spec.body_id
        person_a = person_a_positions.get(body_id)
        person_b = person_b_positions.get(body_id)
        if person_a is None or person_b is None:
            continue

        person_a_longitude = float(person_a["longitude"])
        person_b_longitude = float(person_b["longitude"])
        # Swiss Ephemeris can differ by a few ulps when the same four calls
        # are made in the opposite A/B order.  The contract is A/B symmetric,
        # so expose a stable JSON float while retaining full-precision inputs
        # in the trace for independent recomputation.
        composite_longitude = round(
            circular_midpoint(person_a_longitude, person_b_longitude),
            12,
        )
        sign, degree_text = format_longitude(composite_longitude)
        rows.append(
            {
                "body_id": body_id,
                "name": spec.name,
                "longitude": composite_longitude,
                "sign": sign,
                "degree_text": degree_text,
                "trace": {
                    "phase": phase,
                    "midpoint_method": "circular_midpoint",
                    "reference_utc": reference_utc,
                    "person_a": {
                        "birth_utc": person_a_birth_utc,
                        "progressed_utc": person_a_progressed_utc,
                        "input_longitude": person_a_longitude,
                    },
                    "person_b": {
                        "birth_utc": person_b_birth_utc,
                        "progressed_utc": person_b_progressed_utc,
                        "input_longitude": person_b_longitude,
                    },
                    "composite_longitude": composite_longitude,
                },
            }
        )
    return rows


def _ephemerides(*position_maps: dict[str, dict[str, Any]]) -> list[str]:
    return sorted(
        {
            str(row["_ephemeris"])
            for positions in position_maps
            for row in positions.values()
            if row.get("_ephemeris")
        }
    )


def calculate_progressed_composite(
    request: dict[str, Any],
    warnings: list[str],
) -> dict[str, Any]:
    """Calculate a v1 Progressed Composite using the fixed 5A method."""
    if not isinstance(request, dict):
        raise ValueError("progressed_composite request must be an object")

    person_a = request.get("person_a")
    person_b = request.get("person_b")
    if not isinstance(person_a, dict) or not isinstance(person_b, dict):
        raise ValueError("progressed_composite requires person_a and person_b objects")

    person_a_birth_dt, person_a_birth_jd, person_a_birth_utc = _utc_context(
        person_a.get("moment"), "person_a.moment"
    )
    person_b_birth_dt, person_b_birth_jd, person_b_birth_utc = _utc_context(
        person_b.get("moment"), "person_b.moment"
    )
    reference_dt, _, reference_utc = _utc_context(
        request.get("reference"), "reference"
    )

    person_a_progressed_dt, person_a_age_years = _calc_progressed_dt(
        person_a_birth_dt,
        reference_dt,
    )
    person_b_progressed_dt, person_b_age_years = _calc_progressed_dt(
        person_b_birth_dt,
        reference_dt,
    )
    person_a_progressed_utc = person_a_progressed_dt.astimezone(timezone.utc).isoformat()
    person_b_progressed_utc = person_b_progressed_dt.astimezone(timezone.utc).isoformat()

    # The zodiac is a chart-level setting.  Never inherit it from Person A:
    # doing so makes swapping the two people change the calculation mode.
    zodiac = request.get("zodiac") or "tropical"
    sidereal = set_zodiac_mode(str(zodiac), warnings)
    raw_point_set = request.get("point_set")
    _reject_unsupported_point_set(raw_point_set)
    # The nested point set is the authoritative modern contract.  Only
    # legacy callers that omit it may use the top-level fallback.
    if isinstance(raw_point_set, dict) and "node_mode" in raw_point_set:
        node_mode = raw_point_set["node_mode"]
    else:
        node_mode = request.get("node_mode", "true_node")
    point_set = resolve_point_set(
        raw_point_set,
        default_body_ids=DEFAULT_MODERN_BODY_IDS,
        default_include_nodes=True,
        default_angle_ids=(),
        node_mode=node_mode,
    )
    specs = resolve_bodies(
        list(point_set["resolved_body_ids"]),
        list(point_set["custom_asteroids"]),
        warnings,
    )

    section_errors: dict[str, str] = {}
    radix_composite_planets: list[dict[str, Any]] = []
    progressed_composite_planets: list[dict[str, Any]] = []
    natal_a_positions: dict[str, dict[str, Any]] = {}
    natal_b_positions: dict[str, dict[str, Any]] = {}
    progressed_a_positions: dict[str, dict[str, Any]] = {}
    progressed_b_positions: dict[str, dict[str, Any]] = {}

    # Keep radix and progressed sections independent.  A failure in one
    # calculation phase must not suppress the other phase's usable output.
    try:
        natal_a_positions = _position_map(
            person_a_birth_jd, specs, warnings, sidereal
        )
        natal_b_positions = _position_map(
            person_b_birth_jd, specs, warnings, sidereal
        )
        radix_composite_planets = _midpoint_rows(
            specs,
            natal_a_positions,
            natal_b_positions,
            phase="radix",
            person_a_birth_utc=person_a_birth_utc,
            person_b_birth_utc=person_b_birth_utc,
            person_a_progressed_utc=person_a_birth_utc,
            person_b_progressed_utc=person_b_birth_utc,
            reference_utc=reference_utc,
        )
    except Exception as exc:
        message = f"radix composite 计算失败：{exc}"
        warnings.append(message)
        section_errors["radix_composite_planets"] = str(exc)

    try:
        progressed_a_positions = _position_map(
            jd_from_datetime(person_a_progressed_dt), specs, warnings, sidereal
        )
        progressed_b_positions = _position_map(
            jd_from_datetime(person_b_progressed_dt), specs, warnings, sidereal
        )
        progressed_composite_planets = _midpoint_rows(
            specs,
            progressed_a_positions,
            progressed_b_positions,
            phase="progressed",
            person_a_birth_utc=person_a_birth_utc,
            person_b_birth_utc=person_b_birth_utc,
            person_a_progressed_utc=person_a_progressed_utc,
            person_b_progressed_utc=person_b_progressed_utc,
            reference_utc=reference_utc,
        )
    except Exception as exc:
        message = f"progressed composite 计算失败：{exc}"
        warnings.append(message)
        section_errors["progressed_composite_planets"] = str(exc)

    progressed_to_radix_aspects: list[dict[str, Any]] = []
    try:
        progressed_to_radix_aspects = find_aspects(
            progressed_composite_planets,
            radix_composite_planets,
            request.get("aspects", []),
        )
    except Exception as exc:
        message = f"Progressed→Radix 相位计算失败：{exc}"
        warnings.append(message)
        section_errors["progressed_to_radix_aspects"] = str(exc)

    ephemeris_names = _ephemerides(
        natal_a_positions,
        natal_b_positions,
        progressed_a_positions,
        progressed_b_positions,
    )
    available_body_ids = list(dict.fromkeys(
        row["body_id"]
        for row in radix_composite_planets + progressed_composite_planets
    ))
    effective_point_set = finalize_point_set(
        point_set,
        available_body_ids,
        warnings=warnings,
    )
    warnings[:] = list(dict.fromkeys(warnings))

    return {
        "meta": {
            "schema_version": 1,
            "method": METHOD,
            "zodiac": str(zodiac),
            "reference_utc": reference_utc,
            "person_a_birth_utc": person_a_birth_utc,
            "person_b_birth_utc": person_b_birth_utc,
            "person_a_progressed_utc": person_a_progressed_utc,
            "person_b_progressed_utc": person_b_progressed_utc,
            "person_a_age_years": person_a_age_years,
            "person_b_age_years": person_b_age_years,
            "ephemeris": ", ".join(ephemeris_names) if ephemeris_names else "unknown",
            "effective_point_set": effective_point_set,
        },
        "radix_composite_planets": radix_composite_planets,
        "progressed_composite_planets": progressed_composite_planets,
        "progressed_to_radix_aspects": progressed_to_radix_aspects,
        "warnings": warnings,
        "section_errors": section_errors if section_errors else None,
    }
