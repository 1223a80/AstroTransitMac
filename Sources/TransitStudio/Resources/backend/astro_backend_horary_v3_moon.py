"""Lunar indices derived from the shared timeline, with explicit unknown states."""
from __future__ import annotations

import math
from datetime import timedelta
from typing import Any

from astro_backend_core import CLASSICAL_BODY_IDS, angular_separation, norm360, sign_degree
from astro_backend_horary import CLASSICAL_ANGLES
from astro_backend_horary_v2 import MEAN_SPEED
from astro_backend_horary_v3_config import ALGORITHM_VERSION, parse_utc, utc_text
from astro_backend_horary_v3_events import EventTimeline


def voc_interval(start: str | None, end: str | None) -> dict[str, Any]:
    duration, reason = None, None
    if start is None or end is None:
        reason = "interval_partial_missing_endpoint"
    elif parse_utc(start) > parse_utc(end):
        reason = "interval_start_after_end"
    else:
        duration = (parse_utc(end) - parse_utc(start)).total_seconds()
    return {"start_datetime_utc": start, "end_datetime_utc": end,
            "duration_seconds": duration, "complete": duration is not None, "reason_code": reason}


def build_moon_index(timeline: EventTimeline, bodies: dict[str, dict[str, Any]]) -> dict[str, Any]:
    at = timeline.config.instant
    moon, sun = bodies["MOON"], bodies["SUN"]
    moon_lon, sun_lon = moon["ecliptic"]["longitude_deg"], sun["ecliptic"]["longitude_deg"]
    rows = timeline.ledger.rows()
    ingresses = [r for r in rows if r["event_type"] == "sign_ingress" and r["body_ids"] == ["MOON"]]
    previous = [r for r in ingresses if parse_utc(r["datetime_utc"]) <= at]
    following = [r for r in ingresses if parse_utc(r["datetime_utc"]) > at]
    entry = parse_utc(previous[-1]["datetime_utc"]) if previous else None
    exit_time = parse_utc(following[0]["datetime_utc"]) if following else None
    next_exit = parse_utc(following[1]["datetime_utc"]) if len(following) > 1 else None
    aspects = [r for r in rows if r["event_type"] == "aspect_exact" and "MOON" in r["body_ids"]]
    relevant_coverage = [c for c in timeline.coverage if "|MOON|" in c["id"] and
                         c["id"].startswith(("sign_ingress|", "aspect_exact|"))]
    available = entry is not None and exit_time is not None and all(c["status"] != "unavailable" for c in relevant_coverage)

    def project(row: dict[str, Any]) -> dict[str, Any]:
        return {"target_id": next(b for b in row["body_ids"] if b != "MOON"),
                "aspect_id": row["aspect_id"], "datetime_utc": row["datetime_utc"],
                "datetime_local": row["datetime_local"], "source_event_id": row["id"]}

    past = [project(r) for r in aspects if entry is not None and entry <= parse_utc(r["datetime_utc"]) <= at]
    past.reverse()
    future = [project(r) for r in aspects if exit_time is not None and at < parse_utc(r["datetime_utc"]) <= exit_time]
    future_any = [project(r) for r in aspects if at < parse_utc(r["datetime_utc"]) <= at + timedelta(days=4)]
    after = [project(r) for r in aspects if exit_time is not None and next_exit is not None
             and exit_time < parse_utc(r["datetime_utc"]) <= next_exit]
    end = utc_text(exit_time) if exit_time else None
    rules = []
    for rule_id, pending, truncate in (
        ("voc.modern_exact_before_sign_exit.v1", future, True),
        ("voc.modern_exact_before_sign_exit.applying_completions.v1", future_any, False),
    ):
        value = not pending if available else None
        start = None
        if available:
            start = pending[-1]["datetime_utc"] if pending else past[0]["datetime_utc"] if past else utc_text(entry)
        interval = voc_interval(start, end)
        rule = {
            "rule_id": rule_id, "algorithm_version": ALGORITHM_VERSION, "value": value,
            "status": "evaluated" if available else "unavailable",
            "reason_code": None if available else "lunar_search_incomplete",
            "definition": {"counts_applying_only": truncate, "requires_exact_perfection": True,
                           "bodies": [b for b in CLASSICAL_BODY_IDS if b != "MOON"],
                           "aspects": list(CLASSICAL_ANGLES), "uses_aspect_orb_at_query": False,
                           "traditional_seven_only": True, "ptolemaic_only": True,
                           "sign_exit_truncation": truncate, "search_days": 4},
            "interval": interval,
            "evidence": {"future_exact_count_before_sign_exit": len(future),
                         "future_exact_count_any_window": len(future_any),
                         "past_exact_count_in_sign": len(past), "sign_exit_utc": end},
        }
        rules.append(rule)
        if available and interval["complete"]:
            for kind, stamp in (("start", start), ("end", end)):
                timeline.ledger.add(f"void_of_course_{kind}", parse_utc(stamp), ("MOON",), rule_id,
                                    voc_rule_ids=[rule_id])
    phase = norm360(moon_lon - sun_lon)
    return {
        "current_sign": moon["sign"], "ecliptic_latitude_deg": moon["ecliptic"]["latitude_deg"],
        "declination_deg": moon["equatorial"]["declination_deg"], "phase_angle_deg": round(phase, 6),
        "elongation_from_sun_deg": round(angular_separation(moon_lon, sun_lon), 6),
        "illumination_fraction": round((1 - math.cos(math.radians(phase))) / 2, 6),
        "age_days_approx": round(phase / (MEAN_SPEED["MOON"] - MEAN_SPEED["SUN"]), 6),
        "sign_exit": {"datetime_utc": end,
                      "datetime_local": exit_time.astimezone(timeline.config.local_time.tzinfo).isoformat() if exit_time else None,
                      "remaining_arc_deg": round(30 - sign_degree(moon_lon), 6),
                      "remaining_seconds": (exit_time - at).total_seconds() if exit_time else None,
                      "status": "found" if exit_time else "unavailable"},
        "past_exact_aspects_in_current_sign": past, "future_exact_aspects_in_current_sign": future,
        "last_exact_aspect_in_current_sign": past[0] if past else None,
        "next_exact_aspect_in_current_sign": future[0] if future else None,
        "aspects_in_next_sign": after, "void_of_course_rules": rules,
        "distance_to_north_node_deg": None,
        "search_coverage": relevant_coverage,
        "notes": {"age_method": "phase_angle / (mean_moon_speed - mean_sun_speed)",
                  "illumination_method": "(1 - cos(phase_angle)) / 2",
                  "source_event_ids_scope": "internal_lunar_search; may lie outside configured events window"},
    }
