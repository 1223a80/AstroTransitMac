"""Backend-only birth-time rectification evidence packet.

The packet deliberately stops before application-layer ranking.  It evaluates
the same documented life-event windows for every candidate birth time and
returns method-separated evidence.  Consumers may compare candidates, but the
backend does not claim a unique or scientifically validated birth time.
"""

from __future__ import annotations

import json
import math
import sys
from copy import deepcopy
from datetime import datetime, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

from astro_backend_core import jd_from_datetime, moment_to_local_datetime, set_zodiac_mode
from astro_backend_ephemeris import build_houses
from astro_backend_modern_timing import calculate_modern_timing
from astro_backend_rectify_primary_motion import (
    KEY_RATES,
    PRIMARY_MOTION_ANGLE_PROFILE,
    calculate_primary_motion_to_angles,
)


SCHEMA = {
    "name": "rectification-evidence-packet",
    "version": "1.0",
    "schema_id": "rectification-evidence-packet/1.0",
}

EVENT_SOURCE_QUALITIES = {
    "documented_exact",
    "documented_day",
    "remembered_day",
    "remembered_period",
    "approximate",
}

DEFAULT_ASPECTS = [
    {"id": "conjunction", "name": "合相", "angle": 0.0, "orb": 1.0},
    {"id": "square", "name": "刑相", "angle": 90.0, "orb": 1.0},
    {"id": "opposition", "name": "冲相", "angle": 180.0, "orb": 1.0},
]

DEFAULT_TIMING_TECHNIQUES = [
    {
        "id": "transit",
        "moving_body_ids": ["JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO"],
        "event_types": ["aspect"],
        "aspects": DEFAULT_ASPECTS,
    },
    {
        "id": "secondary_progression",
        "moving_body_ids": ["SUN", "MOON"],
        "event_types": ["aspect"],
        "aspects": DEFAULT_ASPECTS,
    },
    {
        "id": "solar_arc",
        "moving_body_ids": [
            "SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN", "ASC", "MC",
        ],
        "event_types": ["aspect"],
        "aspects": DEFAULT_ASPECTS,
    },
]

METHOD_PROFILES = [
    PRIMARY_MOTION_ANGLE_PROFILE,
    {
        "profile_id": "transit_to_natal_angles_exact_root_v1",
        "family": "transit",
        "status": "formal_astronomical_timing",
        "role": "independent_corroboration",
        "independence_group": "transit",
        "note": "Swiss Ephemeris moving bodies; exact aspect roots inside the supplied event window.",
    },
    {
        "profile_id": "secondary_progression_day_for_year_to_angles_v1",
        "family": "secondary_progression",
        "status": "formal_named_profile",
        "role": "corroboration",
        "independence_group": "day_for_year",
        "note": "Day-for-year progressed bodies to candidate natal angles; does not include progressed angles.",
    },
    {
        "profile_id": "solar_arc_true_sun_to_angles_v1",
        "family": "solar_arc",
        "status": "formal_named_profile",
        "role": "corroboration",
        "independence_group": "day_for_year_solar_anchor",
        "note": "True solar arc from progressed Sun; partially dependent on day-for-year progression.",
    },
]


def _error(message: str, *, invalid: list[str] | None = None) -> dict[str, Any]:
    response: dict[str, Any] = {"error": message, "mode": "rectify_evidence"}
    if invalid:
        response["invalid"] = invalid
    return response


def _candidate_offsets(window_seconds: int, step_seconds: int) -> list[int]:
    if window_seconds < 0:
        raise ValueError("candidate_window_seconds must be non-negative")
    if step_seconds < 1:
        raise ValueError("candidate_step_seconds must be at least 1")
    last = (window_seconds // step_seconds) * step_seconds
    offsets = list(range(-last, last + 1, step_seconds))
    return offsets if offsets else [0]


def _moment_from_datetime(value: datetime, timezone_text: str) -> dict[str, Any]:
    return {
        "year": value.year,
        "month": value.month,
        "day": value.day,
        "hour": value.hour,
        "minute": value.minute,
        "second": value.second,
        "timezone": timezone_text,
        "fold": int(getattr(value, "fold", 0)),
    }


def _shift_birth_datetime(birth_dt: datetime, offset_seconds: int) -> datetime:
    """Shift absolute time, then convert back to the birth timezone."""
    return (birth_dt.astimezone(timezone.utc) + timedelta(seconds=offset_seconds)).astimezone(birth_dt.tzinfo)


def _event_distance_days(value: datetime, start: datetime, end: datetime) -> float:
    value_utc = value.astimezone(timezone.utc)
    start_utc = start.astimezone(timezone.utc)
    end_utc = end.astimezone(timezone.utc)
    if start_utc <= value_utc <= end_utc:
        return 0.0
    delta = start_utc - value_utc if value_utc < start_utc else value_utc - end_utc
    return delta.total_seconds() / 86400.0


def _normalize_events(raw_events: Any) -> tuple[list[dict[str, Any]], list[str]]:
    if not isinstance(raw_events, list) or not raw_events:
        raise ValueError("events must be a non-empty array")
    if len(raw_events) > 20:
        raise ValueError("events must contain at most 20 entries")

    normalized: list[dict[str, Any]] = []
    seen: set[str] = set()
    invalid: list[str] = []
    for index, raw in enumerate(raw_events):
        prefix = f"events[{index}]"
        if not isinstance(raw, dict):
            invalid.append(f"{prefix} must be an object")
            continue
        event_id = raw.get("id")
        if not isinstance(event_id, str) or not event_id.strip():
            invalid.append(f"{prefix}.id must be a non-empty string")
            continue
        event_id = event_id.strip()
        if event_id in seen:
            invalid.append(f"{prefix}.id is duplicated: {event_id}")
            continue
        seen.add(event_id)

        try:
            start = moment_to_local_datetime(raw["start"])
            end = moment_to_local_datetime(raw["end"])
        except KeyError as exc:
            invalid.append(f"{prefix} missing {exc.args[0]}")
            continue
        except (TypeError, ValueError, OverflowError) as exc:
            invalid.append(f"{prefix} time window is invalid: {exc}")
            continue
        if end <= start:
            invalid.append(f"{prefix}.end must be after start")
            continue

        quality = str(raw.get("source_quality") or "approximate")
        if quality not in EVENT_SOURCE_QUALITIES:
            invalid.append(f"{prefix}.source_quality is unknown: {quality}")
            continue
        confidence = raw.get("confidence", 1.0)
        if isinstance(confidence, bool) or not isinstance(confidence, (int, float)):
            invalid.append(f"{prefix}.confidence must be numeric")
            continue
        confidence = float(confidence)
        if not math.isfinite(confidence) or not 0.0 <= confidence <= 1.0:
            invalid.append(f"{prefix}.confidence must be finite and in [0, 1]")
            continue

        normalized.append(
            {
                "id": event_id,
                "category": str(raw.get("category") or "unspecified"),
                "description": str(raw.get("description") or ""),
                "source_quality": quality,
                "confidence": confidence,
                "holdout": bool(raw.get("holdout", False)),
                "start": raw["start"],
                "end": raw["end"],
                "_start_dt": start,
                "_end_dt": end,
            }
        )
    if invalid:
        raise ValueError("；".join(invalid))
    return normalized, invalid


def _validate_techniques(raw: Any) -> list[dict[str, Any]]:
    techniques = deepcopy(DEFAULT_TIMING_TECHNIQUES if raw is None else raw)
    if not isinstance(techniques, list):
        raise ValueError("timing_techniques must be an array")
    allowed = {"transit", "secondary_progression", "solar_arc"}
    seen_ids: set[str] = set()
    for index, technique in enumerate(techniques):
        if not isinstance(technique, dict):
            raise ValueError(f"timing_techniques[{index}] must be an object")
        technique_id = technique.get("id")
        if technique_id not in allowed:
            raise ValueError(f"timing_techniques[{index}].id is unsupported: {technique_id}")
        if technique_id in seen_ids:
            raise ValueError(f"timing_techniques[{index}].id is duplicated: {technique_id}")
        seen_ids.add(str(technique_id))
        if technique.get("event_types") != ["aspect"]:
            raise ValueError(
                f"timing_techniques[{index}].event_types must be exactly ['aspect'] "
                "in rectification evidence"
            )
        moving_body_ids = technique.get("moving_body_ids")
        if not isinstance(moving_body_ids, list) or not moving_body_ids or any(
            not isinstance(body_id, str) or not body_id for body_id in moving_body_ids
        ):
            raise ValueError(f"timing_techniques[{index}].moving_body_ids must be non-empty")
        aspects = technique.get("aspects")
        if not isinstance(aspects, list) or not aspects:
            raise ValueError(f"timing_techniques[{index}].aspects must be non-empty")
        for aspect_index, aspect in enumerate(aspects):
            if not isinstance(aspect, dict) or not isinstance(aspect.get("id"), str):
                raise ValueError(
                    f"timing_techniques[{index}].aspects[{aspect_index}] must have a string id"
                )
            try:
                angle = float(aspect["angle"])
                orb = float(aspect["orb"])
            except (KeyError, TypeError, ValueError) as exc:
                raise ValueError(
                    f"timing_techniques[{index}].aspects[{aspect_index}] "
                    "must have numeric angle and orb"
                ) from exc
            if not math.isfinite(angle) or not 0.0 <= angle <= 180.0:
                raise ValueError(
                    f"timing_techniques[{index}].aspects[{aspect_index}].angle "
                    "must be finite and in [0, 180]"
                )
            if not math.isfinite(orb) or orb < 0.0:
                raise ValueError(
                    f"timing_techniques[{index}].aspects[{aspect_index}].orb "
                    "must be finite and non-negative"
                )
    return techniques


def _public_event(event: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in event.items() if not key.startswith("_")}


def _primary_motion_evidence(
    directions_by_key: dict[str, list[dict[str, Any]]],
    event: dict[str, Any],
    max_rows: int,
) -> dict[str, Any]:
    start = event["_start_dt"]
    end = event["_end_dt"]
    rows: list[dict[str, Any]] = []
    for key_profile, directions in directions_by_key.items():
        for direction in directions:
            exact = datetime.fromisoformat(str(direction["event_datetime_after_birth"]))
            distance = _event_distance_days(exact, start, end)
            rows.append(
                {
                    **direction,
                    "event_id": event["id"],
                    "distance_to_event_window_days": round(distance, 6),
                    "inside_event_window": distance == 0.0,
                    "key_profile": key_profile,
                }
            )
    rows.sort(
        key=lambda row: (
            float(row["distance_to_event_window_days"]),
            float(row["age_years"]),
            str(row["id"]),
        )
    )
    return {
        "method_family": "primary_motion",
        "independence_group": "primary_motion",
        "window_hit_count": sum(bool(row["inside_event_window"]) for row in rows),
        "nearest_distance_days": rows[0]["distance_to_event_window_days"] if rows else None,
        "evidence": rows[:max_rows],
        "truncated": len(rows) > max_rows,
    }


def _timing_evidence(
    candidate_birth: dict[str, Any],
    event: dict[str, Any],
    techniques: list[dict[str, Any]],
    angle_ids: list[str],
    display_timezone: str,
    confirmed_heavy_scan: bool,
    warnings: list[str],
    max_rows: int,
) -> dict[str, Any]:
    request = {
        "mode": "modern_timing",
        "birth": candidate_birth,
        "start": event["start"],
        "end": event["end"],
        "display_timezone": display_timezone,
        "target_point_set": {
            "body_ids": [],
            "include_nodes": False,
            "node_mode": "true_node",
            "custom_asteroids": [],
            "angle_ids": angle_ids,
            "house_cusps": [],
            "lot_ids": [],
        },
        "techniques": techniques,
        "confirmed_heavy_scan": confirmed_heavy_scan,
    }
    result = calculate_modern_timing(request, warnings)
    midpoint = event["_start_dt"] + (event["_end_dt"] - event["_start_dt"]) / 2
    grouped: dict[str, list[dict[str, Any]]] = {
        "transit": [],
        "secondary_progression": [],
        "solar_arc": [],
    }
    for row in result.get("events", []):
        family = str(row.get("source_type") or "")
        if family not in grouped:
            continue
        exact = datetime.fromisoformat(str(row["exact_utc"]).replace("Z", "+00:00"))
        enriched = {
            **row,
            "event_id": event["id"],
            "distance_to_event_midpoint_days": round(
                abs((exact - midpoint.astimezone(timezone.utc)).total_seconds()) / 86400.0,
                6,
            ),
        }
        grouped[family].append(enriched)

    output: dict[str, Any] = {}
    independence = {
        "transit": "transit",
        "secondary_progression": "day_for_year",
        "solar_arc": "day_for_year_solar_anchor",
    }
    for family, rows in grouped.items():
        rows.sort(key=lambda row: (float(row["distance_to_event_midpoint_days"]), str(row["id"])))
        output[family] = {
            "method_family": family,
            "independence_group": independence[family],
            "exact_hit_count": len(rows),
            "evidence": rows[:max_rows],
            "truncated": len(rows) > max_rows,
        }
    return {
        "families": output,
        "timing_meta": result.get("meta"),
        "section_errors": result.get("section_errors"),
    }


def compute_rectification_evidence(request: dict[str, Any]) -> dict[str, Any]:
    """Compute method-separated evidence for every candidate and event window."""
    try:
        birth = request["birth"]
        if not isinstance(birth, dict):
            raise ValueError("birth must be an object")
        birth_moment = birth["moment"]
        birth_dt = moment_to_local_datetime(birth_moment)
        birth_timezone_text = str(birth_moment["timezone"])
        latitude = float(birth["latitude"])
        longitude = float(birth["longitude"])
        if not math.isfinite(latitude) or not -90.0 <= latitude <= 90.0:
            raise ValueError("birth.latitude must be finite and in [-90, 90]")
        if not math.isfinite(longitude) or not -180.0 <= longitude <= 180.0:
            raise ValueError("birth.longitude must be finite and in [-180, 180]")

        window_seconds = int(request.get("candidate_window_seconds", 1800))
        step_seconds = int(request.get("candidate_step_seconds", 60))
        offsets = _candidate_offsets(window_seconds, step_seconds)
        max_candidates = int(request.get("max_candidates", 121))
        if max_candidates < 1 or len(offsets) > max_candidates:
            raise ValueError(
                f"candidate grid has {len(offsets)} rows; max_candidates is {max_candidates}"
            )
        events, _ = _normalize_events(request["events"])
        techniques = _validate_techniques(request.get("timing_techniques"))
        enabled_families = {"primary_motion"} | {str(item["id"]) for item in techniques}
        angle_ids = list(dict.fromkeys(str(value).upper() for value in request.get(
            "target_angle_ids", ["ASC", "MC", "DSC", "IC"]
        )))
        if not angle_ids or any(value not in {"ASC", "MC", "DSC", "IC"} for value in angle_ids):
            raise ValueError("target_angle_ids must be a non-empty subset of ASC, MC, DSC, IC")
        primary_keys = list(dict.fromkeys(request.get("primary_direction_keys", ["naibod_mean"])))
        if not primary_keys or any(value not in KEY_RATES for value in primary_keys):
            raise ValueError(
                "primary_direction_keys must contain supported profiles: " + ", ".join(KEY_RATES)
            )
        max_age = float(request.get("max_age", 120.0))
        if not math.isfinite(max_age) or max_age < 0:
            raise ValueError("max_age must be finite and non-negative")
        max_rows = int(request.get("max_evidence_rows_per_family", 12))
        if not 1 <= max_rows <= 100:
            raise ValueError("max_evidence_rows_per_family must be in [1, 100]")
        display_timezone = str(request.get("display_timezone") or "")
        if not display_timezone:
            raise ValueError("display_timezone is required")
        ZoneInfo(display_timezone)
    except (KeyError, TypeError, ValueError, OverflowError) as exc:
        return _error(f"Invalid rectification evidence request: {exc}")

    warnings: list[str] = []
    zodiac = str(request.get("zodiac") or birth.get("zodiac", "tropical"))
    house_system = str(birth.get("houseSystem", birth.get("house_system", "placidus")))
    sidereal = set_zodiac_mode(zodiac, warnings)

    candidates: list[dict[str, Any]] = []
    total_work = max(len(offsets) * len(events), 1)
    completed = 0
    for offset_seconds in offsets:
        candidate_local = _shift_birth_datetime(birth_dt, offset_seconds)
        candidate_moment = _moment_from_datetime(candidate_local, birth_timezone_text)
        candidate_birth = deepcopy(birth)
        candidate_birth["moment"] = candidate_moment
        candidate_jd = jd_from_datetime(candidate_local)
        candidate_warnings: list[str] = []
        _, angles, house_label = build_houses(
            candidate_jd,
            latitude,
            longitude,
            house_system,
            sidereal,
            candidate_warnings,
        )

        directions_by_key = {
            key_profile: calculate_primary_motion_to_angles(
                candidate_jd,
                candidate_local,
                latitude,
                longitude,
                house_system,
                candidate_warnings,
                angle_ids=angle_ids,
                key_profile=key_profile,
                max_age=max_age,
            )
            for key_profile in primary_keys
        }

        evidence_by_event: list[dict[str, Any]] = []
        for event in events:
            primary = _primary_motion_evidence(directions_by_key, event, max_rows)
            timing = _timing_evidence(
                candidate_birth,
                event,
                techniques,
                angle_ids,
                display_timezone,
                bool(request.get("confirmed_heavy_scan", False)),
                candidate_warnings,
                max_rows,
            )
            evidence_by_event.append(
                {
                    "event_id": event["id"],
                    "event_category": event["category"],
                    "holdout": event["holdout"],
                    "primary_motion": primary,
                    **timing,
                }
            )
            completed += 1
            sys.stderr.write(
                json.dumps(
                    {
                        "progress": round(completed / total_work, 6),
                        "label": f"rectify_evidence:{offset_seconds}:{event['id']}",
                    },
                    ensure_ascii=False,
                )
                + "\n"
            )
            sys.stderr.flush()

        family_hit_counts: dict[str, int] = {family: 0 for family in (
            "primary_motion", "transit", "secondary_progression", "solar_arc"
        )}
        for packet in evidence_by_event:
            family_hit_counts["primary_motion"] += int(packet["primary_motion"]["window_hit_count"])
            for family, family_packet in packet["families"].items():
                family_hit_counts[family] += int(family_packet["exact_hit_count"])

        warnings.extend(candidate_warnings)
        candidates.append(
            {
                "offset_seconds": offset_seconds,
                "birth_local": candidate_local.isoformat(),
                "birth_utc": candidate_local.astimezone(timezone.utc).isoformat(),
                "house_system": house_label,
                "angles": {key: round(float(value), 9) for key, value in angles.items()},
                "family_hit_counts": family_hit_counts,
                "evidence_by_event": evidence_by_event,
                "warnings": list(dict.fromkeys(candidate_warnings)),
            }
        )

    return {
        "schema": SCHEMA,
        "meta": {
            "mode": "rectify_evidence",
            "candidate_count": len(candidates),
            "event_count": len(events),
            "zodiac": zodiac,
            "house_system_requested": house_system,
            "display_timezone": display_timezone,
            "scientific_validation": "not_established",
            "automatic_best_time": False,
        },
        "requested_config": {
            "reference_birth": deepcopy(birth),
            "candidate_window_seconds": window_seconds,
            "candidate_step_seconds": step_seconds,
            "max_candidates": max_candidates,
            "primary_direction_keys": primary_keys,
            "target_angle_ids": angle_ids,
            "max_age": max_age,
            "max_evidence_rows_per_family": max_rows,
            "confirmed_heavy_scan": bool(request.get("confirmed_heavy_scan", False)),
            "timing_technique_ids": [str(item["id"]) for item in techniques],
            "timing_techniques": deepcopy(techniques),
        },
        "method_profiles": [
            profile for profile in METHOD_PROFILES if profile["family"] in enabled_families
        ],
        "events": [_public_event(event) for event in events],
        "candidates": candidates,
        "warnings": list(dict.fromkeys(warnings)),
        "calculation_assumptions": [
            "The backend returns separated evidence and does not choose a unique birth time.",
            "Primary motion is limited to the documented planet-to-angle geometry subset.",
            "Transit, secondary progression, and solar arc evidence are exact aspect roots inside user-supplied event windows.",
            "Secondary progression and true solar arc are partially dependent through the day-for-year solar anchor.",
            "Astrological interpretation is not scientifically validated; method status describes calculation provenance only.",
        ],
    }


__all__ = [
    "DEFAULT_TIMING_TECHNIQUES",
    "EVENT_SOURCE_QUALITIES",
    "METHOD_PROFILES",
    "SCHEMA",
    "compute_rectification_evidence",
]
