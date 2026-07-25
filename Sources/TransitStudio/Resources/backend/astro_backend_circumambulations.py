from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from astro_backend_classical import (
    EGYPTIAN_BOUNDS,
    PTOLEMAIC_BOUNDS,
    planet_name,
    zodiac_sign_index,
)
from astro_backend_core import (
    SIGNS,
    norm360,
)
from astro_backend_primary_directions import NAIBOD_RATE

BOUND_NAMES = {"egyptian": "Egyptian", "ptolemaic": "Ptolemaic"}
DAYS_PER_YEAR = 365.2425


def _bounds_table(system: str) -> dict[int, list[tuple[str, int]]]:
    return PTOLEMAIC_BOUNDS if system == "ptolemaic" else EGYPTIAN_BOUNDS


def _find_bound_for_degree(table: dict[int, list[tuple[str, int]]], sign_idx: int, degree: float) -> tuple[str, int, int]:
    """Return (ruler_id, bound_start_degree, bound_end_degree). Upper edge is exclusive."""
    prev = 0
    for ruler, upper in table[sign_idx]:
        if prev <= degree < upper:
            return ruler, prev, upper
        prev = upper
    return table[sign_idx][-1][0], prev if prev < 30 else table[sign_idx][-2][1] if len(table[sign_idx]) > 1 else 0, 30


def _periods_from_significator(
    sig_lon: float,
    birth_dt: datetime,
    bounds_system: str,
    max_age: int,
) -> list[dict[str, Any]]:
    """Build continuous bound periods from significator longitude using Naibod arc proxy."""
    table = _bounds_table(bounds_system)
    periods: list[dict[str, Any]] = []
    sig_sign = zodiac_sign_index(sig_lon)
    sig_deg = sig_lon % 30.0

    for offset in range(12):
        sign_idx = (sig_sign + offset) % 12
        bounds = table[sign_idx]
        prev_upper = 0
        for ruler, upper in bounds:
            start_deg = prev_upper
            end_deg = upper
            # Skip bounds entirely before significator in the starting sign.
            if offset == 0 and end_deg <= sig_deg:
                prev_upper = upper
                continue
            # Period start is max(bound start, significator) for first bound.
            period_start_deg = max(start_deg, sig_deg) if offset == 0 else start_deg
            start_lon = sign_idx * 30.0 + period_start_deg
            end_lon = sign_idx * 30.0 + end_deg
            start_arc = norm360(start_lon - sig_lon)
            end_arc = norm360(end_lon - sig_lon)
            if offset == 0 and period_start_deg <= sig_deg + 1e-9:
                start_arc = 0.0
            start_age = start_arc / NAIBOD_RATE
            end_age = end_arc / NAIBOD_RATE
            # max_age is exclusive upper on start_age (max_age=0 yields no periods).
            if start_age >= max_age:
                prev_upper = upper
                continue
            start_date = birth_dt + timedelta(days=start_age * DAYS_PER_YEAR)
            end_date = birth_dt + timedelta(days=end_age * DAYS_PER_YEAR)
            periods.append({
                "significator": "ASC",
                "bounds_profile": bounds_system,
                "period_ruler": planet_name(ruler),
                "period_ruler_id": ruler,
                "start_sign": SIGNS[sign_idx],
                "start_degree": round(period_start_deg, 4),
                "end_sign": SIGNS[sign_idx],
                "end_degree": round(end_deg, 4),
                "start_arc": round(start_arc, 4),
                "end_arc": round(end_arc, 4),
                "start_age": round(start_age, 4),
                "end_age": round(end_age, 4),
                "start_date": start_date.strftime("%Y-%m-%d"),
                "end_date": end_date.strftime("%Y-%m-%d"),
                "current_period": False,
                # Legacy boundary-style fields kept for older consumers.
                "sign": SIGNS[sign_idx],
                "ruler": planet_name(ruler),
                "ruler_id": ruler,
                "age_at_boundary": round(end_age, 2),
                "estimated_date": end_date.strftime("%Y-%m-%d"),
                "start_degree_legacy_boundary": start_deg,
                "end_degree_legacy_boundary": end_deg,
            })
            prev_upper = upper
    periods.sort(key=lambda p: p["start_age"])
    return periods


def calculate_circumambulations(
    asc_lon: float,
    birth_dt: datetime,
    bounds_system: str,
    max_age: int = 120,
    reference_dt: datetime | None = None,
    significator: str = "ASC",
) -> dict[str, Any]:
    """Circumambulation of significator through Egyptian/Ptolemaic bounds (Naibod arc proxy).

    Output is period-based: each row is a continuous interval ruled by one bound lord.
    Boundary-style tables that label end-degree as start of next ruler are not used.
    """
    periods = _periods_from_significator(asc_lon, birth_dt, bounds_system, max_age)
    for p in periods:
        p["significator"] = significator

    table = _bounds_table(bounds_system)
    if reference_dt is not None:
        ref_age_years = (reference_dt - birth_dt).total_seconds() / (DAYS_PER_YEAR * 86400)
        progressed_lon = norm360(asc_lon + ref_age_years * NAIBOD_RATE)
        progressed_sign = zodiac_sign_index(progressed_lon)
        progressed_deg = progressed_lon % 30.0
        current_ruler, bound_start_deg, bound_end_deg = _find_bound_for_degree(table, progressed_sign, progressed_deg)
        current_bound_name = planet_name(current_ruler)
        current_bound_info = f"{SIGNS[progressed_sign]} {progressed_deg:.1f}°"

        active = None
        for p in periods:
            if p["start_age"] <= ref_age_years < p["end_age"]:
                p["current_period"] = True
                active = p
                break
        if active is None:
            # Fallback to degree lookup
            for p in periods:
                if (
                    p["period_ruler_id"] == current_ruler
                    and p["start_sign"] == SIGNS[progressed_sign]
                    and p["start_degree"] <= progressed_deg < p["end_degree"]
                ):
                    p["current_period"] = True
                    active = p
                    break

        if active:
            bound_start_date = active["start_date"]
            bound_end_date = active["end_date"]
            bound_start_deg = active["start_degree"]
            bound_end_deg = active["end_degree"]
            current_ruler = active["period_ruler_id"]
            current_bound_name = active["period_ruler"]
        else:
            arc_start = norm360(progressed_sign * 30.0 + bound_start_deg - asc_lon)
            arc_end = norm360(progressed_sign * 30.0 + bound_end_deg - asc_lon)
            if bound_start_deg == 0 and progressed_sign == zodiac_sign_index(asc_lon):
                arc_start = 0.0
            bound_start_date = (birth_dt + timedelta(days=(arc_start / NAIBOD_RATE) * DAYS_PER_YEAR)).strftime("%Y-%m-%d")
            bound_end_date = (birth_dt + timedelta(days=(arc_end / NAIBOD_RATE) * DAYS_PER_YEAR)).strftime("%Y-%m-%d")
    else:
        ref_age_years = 0.0
        progressed_lon = asc_lon
        progressed_sign = zodiac_sign_index(asc_lon)
        progressed_deg = asc_lon % 30.0
        current_ruler, bound_start_deg, bound_end_deg = _find_bound_for_degree(table, progressed_sign, progressed_deg)
        current_bound_name = planet_name(current_ruler)
        current_bound_info = f"{SIGNS[progressed_sign]} {progressed_deg:.1f}°"
        bound_start_date = ""
        bound_end_date = ""
        if periods:
            periods[0]["current_period"] = True

    # Legacy "boundaries" list = period ends (for older UI). Prefer `periods`.
    boundaries = []
    for p in periods:
        boundaries.append({
            "sign": p["end_sign"],
            "start_degree": p["start_degree"],
            "end_degree": p["end_degree"],
            "ruler": p["period_ruler"],
            "ruler_id": p["period_ruler_id"],
            "arc_value": p["end_arc"],
            "age_at_boundary": p["end_age"],
            "estimated_date": p["end_date"],
            "is_current": p["current_period"],
            "note": "end of period (not start of next ruler)",
        })

    return {
        "id": f"circumambulations-{bounds_system}",
        "system": BOUND_NAMES.get(bounds_system, bounds_system),
        "bounds_profile": bounds_system,
        "significator": significator,
        "start_lon": round(asc_lon, 4),
        "current_ruler": current_bound_name,
        "current_ruler_id": current_ruler,
        "current_bound_info": current_bound_info,
        "current_directed_position": round(progressed_lon, 4),
        "bound_lord": current_bound_name,
        "bound_lord_id": current_ruler,
        "bound_sign": SIGNS[progressed_sign],
        "bound_start_degree": bound_start_deg,
        "bound_end_degree": bound_end_deg,
        "bound_start_date": bound_start_date if reference_dt else "",
        "bound_end_date": bound_end_date if reference_dt else "",
        "naibod_rate": NAIBOD_RATE,
        "periods": periods,
        "boundaries": boundaries,
        "output_format": "period",
        "method_note": "Period table: each row is [start, end) under one bound lord. Not a boundary-start table.",
    }
