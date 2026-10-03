"""Validated, request-local configuration for the Horary v3 pipeline."""
from __future__ import annotations

import copy
import math
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any

from astro_backend_constants import (
    ALL_BOUNDS_SYSTEMS, ALL_HOUSE_SYSTEMS, ALL_TRIPLICITY_SYSTEMS, ALL_ZODIACS,
)
from astro_backend_core import BODY_REGISTRY, CLASSICAL_BODY_IDS, moment_to_local_datetime

SCHEMA_VERSION = "3.0"
SCHEMA_ID = "horary-data-packet/3.0"
ALGORITHM_VERSION = "horary-v3-2026-10"
# Match the existing 400-day event-search horizon, rejecting instead of truncating.
MAX_EVENT_DAYS = 400.0


def number(name: str, value: Any, minimum: float | None = None,
           maximum: float | None = None) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"{name} must be a finite JSON number")
    try:
        result = float(value)
    except (ValueError, OverflowError) as exc:
        raise ValueError(f"{name} must be a finite JSON number") from exc
    if not math.isfinite(result):
        raise ValueError(f"{name} must be a finite JSON number")
    if minimum is not None and result < minimum:
        raise ValueError(f"{name} must be >= {minimum:g}")
    if maximum is not None and result > maximum:
        raise ValueError(f"{name} must be <= {maximum:g}")
    return result


def utc_text(value: datetime) -> str:
    return value.astimezone(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def parse_utc(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)


@dataclass(frozen=True)
class TimeWindow:
    start: datetime
    end: datetime

    def __post_init__(self) -> None:
        if self.start.utcoffset() is None or self.end.utcoffset() is None:
            raise ValueError("search windows require timezone-aware datetimes")
        if self.start > self.end:
            raise ValueError("search window start must not exceed end")

    def contains(self, instant: datetime) -> bool:
        return self.start <= instant <= self.end

    def payload(self) -> dict[str, str]:
        return {"start_utc": utc_text(self.start), "end_utc": utc_text(self.end)}


@dataclass(frozen=True)
class HoraryConfig:
    chart: dict[str, Any]
    local_time: datetime
    latitude: float
    longitude: float
    altitude_m: float
    house_system: str
    zodiac: str
    bounds_system: str
    triplicity_system: str
    body_ids: tuple[str, ...]
    aspect_orb: float
    declination_orb: float
    antiscia_orb: float
    node_mode: str
    past_days: float
    future_days: float
    question_text: str
    place_name: str
    ephemeris_path: str | None

    @property
    def instant(self) -> datetime:
        return self.local_time.astimezone(timezone.utc)

    @property
    def window(self) -> TimeWindow:
        return TimeWindow(self.instant - timedelta(days=self.past_days),
                          self.instant + timedelta(days=self.future_days))

    @classmethod
    def from_request(cls, request: dict[str, Any]) -> HoraryConfig:
        chart = copy.deepcopy(request.get("chart"))
        if not isinstance(chart, dict) or not isinstance(chart.get("moment"), dict):
            raise ValueError("chart.moment must be an object")
        moment = chart["moment"]
        for key in ("year", "month", "day", "hour", "minute"):
            if isinstance(moment.get(key), bool) or not isinstance(moment.get(key), int):
                raise ValueError(f"chart.moment.{key} must be an integer")
        if not isinstance(moment.get("timezone"), str) or not moment["timezone"].strip():
            raise ValueError("chart.moment.timezone must be a non-empty string")
        if "fold" in moment and (type(moment["fold"]) is not int or moment["fold"] not in (0, 1)):
            raise ValueError("chart.moment.fold must be 0 or 1")
        if moment.get("second") is not None and (type(moment["second"]) is not int or not 0 <= moment["second"] <= 59):
            raise ValueError("chart.moment.second must be an integer in [0, 59]")
        local_time = moment_to_local_datetime(moment)
        options = {}
        for key, default, allowed in (
            ("houseSystem", "regiomontanus", ALL_HOUSE_SYSTEMS),
            ("zodiac", "tropical", ALL_ZODIACS),
            ("boundsSystem", "egyptian", ALL_BOUNDS_SYSTEMS),
            ("triplicitySystem", "dorothean", ALL_TRIPLICITY_SYSTEMS),
        ):
            value = chart.get(key, default)
            if not isinstance(value, str) or value not in allowed:
                raise ValueError(f"chart.{key} must be one of: {', '.join(allowed)}")
            options[key] = value
            chart[key] = value
        ids = request.get("bodyIds", list(CLASSICAL_BODY_IDS))
        if not isinstance(ids, list) or any(not isinstance(b, str) or b not in BODY_REGISTRY for b in ids):
            raise ValueError("bodyIds must be an array of registered body IDs")
        if len(ids) != len(set(ids)):
            raise ValueError("bodyIds must not contain duplicates")
        if not {"SUN", "MOON"}.issubset(ids):
            raise ValueError("bodyIds must include SUN and MOON")
        node_mode = request.get("nodeMode", request.get("node_mode", "mean"))
        if not isinstance(node_mode, str) or node_mode not in {"mean", "true", "both"}:
            raise ValueError("nodeMode must be mean, true, or both")
        for key in ("questionText", "placeName"):
            if not isinstance(request.get(key, ""), str):
                raise ValueError(f"{key} must be a string")
        ephemeris = request.get("ephemerisPath")
        if ephemeris is None:
            ephemeris = request.get("ephemeris_path")
        if ephemeris is not None and not isinstance(ephemeris, str):
            raise ValueError("ephemerisPath must be a string")
        config = cls(
            chart=chart, local_time=local_time,
            latitude=number("chart.latitude", chart.get("latitude"), -90, 90),
            longitude=number("chart.longitude", chart.get("longitude"), -180, 180),
            altitude_m=number("altitudeM", request.get("altitudeM", chart.get("altitudeM", 0.0))),
            house_system=options["houseSystem"], zodiac=options["zodiac"],
            bounds_system=options["boundsSystem"], triplicity_system=options["triplicitySystem"],
            body_ids=tuple(ids), aspect_orb=number("aspectOrb", request.get("aspectOrb", 3.0), 0, 10),
            declination_orb=number("declinationOrb", request.get("declinationOrb", request.get("declination_orb", 1.0)), 0),
            antiscia_orb=number("antisciaOrb", request.get("antisciaOrb", request.get("antiscia_orb", 1.0)), 0),
            node_mode=node_mode,
            past_days=number("eventPastDays", request.get("eventPastDays", 4.0), 0, MAX_EVENT_DAYS),
            future_days=number("eventFutureDays", request.get("eventFutureDays", 30.0), 0, MAX_EVENT_DAYS),
            question_text=request.get("questionText", "").strip(), place_name=request.get("placeName", "").strip(),
            ephemeris_path=ephemeris,
        )
        try:
            # Body indices retain the existing station/sign-exit search horizons.
            config.instant - timedelta(days=max(config.past_days, 400))
            config.instant + timedelta(days=max(config.future_days, 1200))
        except OverflowError as exc:
            raise ValueError("chart.moment is too close to the supported datetime boundary") from exc
        return config

    def canonical_input(self) -> dict[str, Any]:
        return {
            "mode": "horary", "packetVersion": "3", "chart": self.chart,
            "questionText": self.question_text, "placeName": self.place_name,
            "bodyIds": list(self.body_ids), "aspectOrb": self.aspect_orb,
            "altitudeM": self.altitude_m, "eventPastDays": self.past_days,
            "eventFutureDays": self.future_days, "nodeMode": self.node_mode,
            "declinationOrb": self.declination_orb, "antisciaOrb": self.antiscia_orb,
            "ephemerisPath": self.ephemeris_path,
        }
