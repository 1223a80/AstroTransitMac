"""Shared exact planetary-return search primitives.

The classical and modern return modes intentionally keep different response
schemas, but they must not drift in their UTC bracketing and root refinement.
This module owns only the pure search step; each caller builds its own
snapshot and provenance envelope.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_scan import orb_at, refine_crossing


def search_return_exacts(
    *,
    body_spec: Any,
    target_longitude: float,
    start: datetime,
    end: datetime,
    step_hours: float,
    sidereal: bool,
    warnings: list[str],
    title: str,
    max_iterations: int = 20_000,
) -> list[datetime]:
    """Return all exact target-longitude crossings in ``[start, end]``.

    Search and refinement always use the supplied aware UTC timeline.  The
    caller is responsible for converting output to the display timezone and
    for assigning previous/current/next labels around its reference moment.
    """
    if start.tzinfo is None or end.tzinfo is None:
        raise ValueError("return search bounds must be timezone-aware")
    output_timezone = start.tzinfo
    search_start = start.astimezone(timezone.utc)
    search_end = end.astimezone(timezone.utc)
    warning_keys: set[str] = set()
    exacts: list[datetime] = []
    cursor = search_start
    first = orb_at(cursor, body_spec, target_longitude, warnings, warning_keys, sidereal=sidereal)
    iterations = 0
    while cursor < search_end and first is not None:
        iterations += 1
        if iterations > max_iterations:
            warnings.append(f"{title} 搜索迭代次数超过限制（{max_iterations}），结果可能不完整。")
            break
        next_cursor = min(cursor + timedelta(hours=step_hours), search_end)
        second = orb_at(next_cursor, body_spec, target_longitude, warnings, warning_keys, sidereal=sidereal)
        if second is None:
            break
        f1, _ = first
        f2, _ = second
        # orb_at is signed around the target; unwrap a one-step 360° jump
        # before applying the small-motion guard.
        delta = f2 - f1
        if delta > 180:
            f2 -= 360
        elif delta < -180:
            f2 += 360
        crossed = (f1 <= 0 <= f2) or (f1 >= 0 >= f2)
        if crossed and abs(f1 - f2) < 20:
            exact = refine_crossing(
                cursor,
                next_cursor,
                body_spec,
                target_longitude,
                warnings,
                warning_keys,
                sidereal=sidereal,
            )
            if not exacts or abs((exact - exacts[-1]).total_seconds()) > 0.5:
                exacts.append(exact)
        cursor = next_cursor
        first = second
    return [exact.astimezone(output_timezone) for exact in sorted(exacts)]
