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
    """Return (ruler_id, bound_start_degree, bound_end_degree) for the given degree in a sign."""
    prev = 0
    for ruler, upper in table[sign_idx]:
        if prev <= degree < upper or abs(degree - upper) < 0.0001:
            return ruler, prev, upper
        prev = upper
    return table[sign_idx][-1][0], prev, 30


def calculate_circumambulations(
    asc_lon: float,
    birth_dt: datetime,
    bounds_system: str,
    max_age: int = 120,
    reference_dt: datetime | None = None,
) -> dict[str, Any]:
    table = _bounds_table(bounds_system)
    boundaries: list[dict[str, Any]] = []
    asc_sign = zodiac_sign_index(asc_lon)
    asc_deg = asc_lon % 30.0

    for offset in range(12):
        sign_idx = (asc_sign + offset) % 12
        bounds = table[sign_idx]
        prev_upper = 0
        for ruler, upper in bounds:
            if offset == 0 and upper <= asc_deg:
                prev_upper = upper
                continue
            boundary_lon = sign_idx * 30.0 + upper
            arc = norm360(boundary_lon - asc_lon)
            age = arc / NAIBOD_RATE
            if age > max_age:
                continue
            event_dt = birth_dt + timedelta(days=age * DAYS_PER_YEAR)
            boundaries.append({
                "sign": SIGNS[sign_idx],
                "start_degree": prev_upper,
                "end_degree": upper,
                "ruler": planet_name(ruler),
                "ruler_id": ruler,
                "arc_value": round(arc, 4),
                "age_at_boundary": round(age, 2),
                "estimated_date": event_dt.strftime("%Y-%m-%d"),
            })
            prev_upper = upper

    boundaries.sort(key=lambda b: b["age_at_boundary"])

    if reference_dt is not None:
        ref_age_years = (reference_dt - birth_dt).total_seconds() / (DAYS_PER_YEAR * 86400)
        progressed_lon = norm360(asc_lon + ref_age_years * NAIBOD_RATE)
        progressed_sign = zodiac_sign_index(progressed_lon)
        progressed_deg = progressed_lon % 30.0
        current_ruler, bound_start_deg, bound_end_deg = _find_bound_for_degree(table, progressed_sign, progressed_deg)
        current_bound_name = planet_name(current_ruler)
        current_bound_info = f"{SIGNS[progressed_sign]} {progressed_deg:.1f}°"

        arc_start = norm360(progressed_sign * 30.0 + bound_start_deg - asc_lon)
        arc_end = norm360(progressed_sign * 30.0 + bound_end_deg - asc_lon)
        if bound_start_deg == 0 and progressed_sign == asc_sign:
            arc_start = 0.0
        age_start = arc_start / NAIBOD_RATE
        age_end = arc_end / NAIBOD_RATE
        bound_start_date = birth_dt + timedelta(days=age_start * DAYS_PER_YEAR)
        bound_end_date = birth_dt + timedelta(days=age_end * DAYS_PER_YEAR)
    else:
        ref_age_years = 0.0
        progressed_lon = asc_lon
        progressed_sign = asc_sign
        progressed_deg = asc_deg
        current_ruler, bound_start_deg, bound_end_deg = _find_bound_for_degree(table, asc_sign, asc_deg)
        current_bound_name = planet_name(current_ruler)
        current_bound_info = f"{SIGNS[asc_sign]} {asc_deg:.1f}°"
        bound_start_date = birth_dt
        bound_end_date = birth_dt

    for b in boundaries:
        b["is_current"] = (
            b["ruler_id"] == current_ruler
            and b["start_degree"] == bound_start_deg
            and b["end_degree"] == bound_end_deg
            and (reference_dt is not None)
        )

    return {
        "id": f"circumambulations-{bounds_system}",
        "system": BOUND_NAMES.get(bounds_system, bounds_system),
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
        "bound_start_date": bound_start_date.strftime("%Y-%m-%d") if reference_dt else "",
        "bound_end_date": bound_end_date.strftime("%Y-%m-%d") if reference_dt else "",
        "naibod_rate": NAIBOD_RATE,
        "boundaries": boundaries,
    }
