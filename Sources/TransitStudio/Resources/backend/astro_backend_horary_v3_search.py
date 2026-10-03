"""UTC event search and request-scoped ephemeris sampling for Horary v3."""
from __future__ import annotations

import math
from collections.abc import Callable
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_core import BODY_REGISTRY, jd_from_datetime, norm360
from astro_backend_ephemeris import calculate_values
from astro_backend_horary import crosses_zero
from astro_backend_horary_v3_config import ALGORITHM_VERSION, TimeWindow, utc_text

ROOT_TIME_TOLERANCE = timedelta(milliseconds=10)


class SampleUnavailable(RuntimeError):
    """The requested search cannot establish presence or absence of an event."""


@dataclass(frozen=True)
class RootSearch:
    roots: tuple[datetime, ...]
    window: TimeWindow
    step_hours: float
    status: str
    reason: str | None = None

    def payload(self) -> dict[str, Any]:
        return {
            **self.window.payload(), "status": self.status,
            "reason_code": self.reason, "root_count": len(self.roots),
            "max_step_hours": self.step_hours,
            "method": "sampled_sign_changes_with_bisection",
            "time_tolerance_seconds": ROOT_TIME_TOLERANCE.total_seconds(),
        }


def scan_roots(sample: Callable[[datetime], float], window: TimeWindow,
               step_hours: float = 6.0, *, angular: bool = True) -> RootSearch:
    """Search every sampled bracket, including a short final bracket.

    Coverage describes sampled sign changes, not an analytic completeness proof.
    Missing data invalidates the search instead of turning it into 'no events'.
    """
    if not math.isfinite(step_hours) or step_hours <= 0:
        raise ValueError("step_hours must be positive and finite")
    start = window.start.astimezone(timezone.utc)
    end = window.end.astimezone(timezone.utc)
    window = TimeWindow(start, end)
    roots: list[datetime] = []

    def value(t: datetime) -> float:
        v = sample(t)
        if v is None or not math.isfinite(v):
            raise SampleUnavailable("non_finite_or_missing_sample")
        return v

    def crossing(a: float, b: float) -> bool:
        return crosses_zero(a, b) if angular else (a == 0 or b == 0 or (a < 0) != (b < 0))

    def append(t: datetime) -> None:
        if not roots or t - roots[-1] > ROOT_TIME_TOLERANCE:
            roots.append(t)

    try:
        t, left = start, value(start)
        if left == 0:
            append(start)
        while t < end:
            following = min(t + timedelta(hours=step_hours), end)
            right = value(following)
            if crossing(left, right):
                if left == 0:
                    root = t
                elif right == 0:
                    root = following
                else:
                    a, b, fa = t, following, left
                    while b - a > ROOT_TIME_TOLERANCE:
                        mid = a + (b - a) / 2
                        fm = value(mid)
                        if fm == 0:
                            a = b = mid
                        elif crossing(fa, fm):
                            b = mid
                        else:
                            a, fa = mid, fm
                    root = a + (b - a) / 2
                append(root)
            t, left = following, right
    except SampleUnavailable as exc:
        return RootSearch(tuple(roots), window, step_hours, "unavailable", str(exc))
    return RootSearch(tuple(roots), window, step_hours, "found" if roots else "not_found_in_window")


class EphemerisSampler:
    """A cache lives for one request and one zodiac configuration only."""

    def __init__(self, sidereal: bool, warnings: list[str]):
        self.sidereal = sidereal
        self.warnings = warnings
        self.warning_keys: set[str] = set()
        self._values: dict[tuple[str, datetime], tuple[float, float] | None] = {}

    def position(self, body_id: str, instant: datetime) -> tuple[float, float]:
        key = body_id, instant.astimezone(timezone.utc)
        if key not in self._values:
            spec = BODY_REGISTRY[body_id]
            result = calculate_values(jd_from_datetime(key[1]), spec, self.warnings,
                                      self.warning_keys, sidereal=self.sidereal)
            self._values[key] = None if result is None else (
                norm360(result[0][0] + spec.longitude_offset), float(result[0][3]),
            )
        result = self._values[key]
        if result is None or not all(math.isfinite(v) for v in result):
            raise SampleUnavailable(f"ephemeris_unavailable:{body_id}")
        return result

    def longitude(self, body_id: str, instant: datetime) -> float:
        return self.position(body_id, instant)[0]

    def speed(self, body_id: str, instant: datetime) -> float:
        return self.position(body_id, instant)[1]


class EventLedger:
    def __init__(self, chart_time: datetime):
        self.chart_time = chart_time
        self._rows: dict[str, dict[str, Any]] = {}

    def add(self, event_type: str, instant: datetime, bodies: tuple[str, ...],
            rule_id: str, *, aspect_id: str | None = None,
            discriminator: str = "", **evidence: Any) -> dict[str, Any]:
        utc = instant.astimezone(timezone.utc)
        event_id = "|".join((event_type, *bodies, aspect_id or "", discriminator, utc_text(utc)))
        if event_id in self._rows:
            row = self._rows[event_id]
            row["rule_ids"] = sorted(set(row["rule_ids"]) | {rule_id})
            if "voc_rule_ids" in evidence:
                row["voc_rule_ids"] = sorted(set(row.get("voc_rule_ids", [])) | set(evidence["voc_rule_ids"]))
            return row
        row = {
            "id": event_id, "event_type": event_type, "body_ids": list(bodies),
            "aspect_id": aspect_id, "datetime_utc": utc_text(utc),
            "datetime_local": instant.astimezone(self.chart_time.tzinfo).isoformat(timespec="microseconds"),
            "offset_seconds_from_query": (utc - self.chart_time.astimezone(timezone.utc)).total_seconds(),
            "rule_id": rule_id, "rule_ids": [rule_id],
            "algorithm_version": ALGORITHM_VERSION, **evidence,
        }
        self._rows[event_id] = row
        return row

    def rows(self, window: TimeWindow | None = None) -> list[dict[str, Any]]:
        from astro_backend_horary_v3_config import parse_utc

        rows = self._rows.values()
        if window is not None:
            rows = [r for r in rows if window.contains(parse_utc(r["datetime_utc"]))]
        return sorted(rows, key=lambda r: (r["offset_seconds_from_query"], r["id"]))
