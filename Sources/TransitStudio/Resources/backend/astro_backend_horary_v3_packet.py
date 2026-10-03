"""Serialization and cross-reference validation at the v3 pipeline boundary."""
from __future__ import annotations

import json
from typing import TYPE_CHECKING, Any

from astro_backend_core import SIGN_RULERS, planet_name, swe, zodiac_mode_label, zodiac_sign_index
from astro_backend_horary import CLASSICAL_ANGLES
from astro_backend_horary_v2 import (
    BODY_EN, CAZIMI_ORB_DEG, COMBUST_ORB_DEG, UNDER_BEAMS_ORB_DEG,
    _hash_payload, _house_span, _r, _sign_display, assert_no_forbidden_fields,
)
from astro_backend_horary_v3_config import ALGORITHM_VERSION, SCHEMA_ID, SCHEMA_VERSION, parse_utc

if TYPE_CHECKING:
    from astro_backend_horary_v3 import ChartContext


def assemble_packet(ctx: ChartContext, evidence: dict[str, Any]) -> dict[str, Any]:
    cfg = ctx.config
    fallback = ctx.actual_house_system != cfg.house_system
    calc_config = {
        "house_system": ctx.actual_house_system, "requested_house_system": cfg.house_system,
        "house_system_label": ctx.house_label, "zodiac": cfg.zodiac,
        "zodiac_label": zodiac_mode_label(cfg.zodiac), "sidereal": ctx.sidereal,
        "bounds_system": cfg.bounds_system, "triplicity_system": cfg.triplicity_system,
        "aspect_orb_deg": cfg.aspect_orb, "bodies": list(cfg.body_ids),
        "aspects_enabled": [{"aspect_id": key, "angle_deg": angle} for key, angle in CLASSICAL_ANGLES.items()],
        "coordinate_center": "geocentric", "position_type": "apparent",
        "event_window": {"past_days": cfg.past_days, "future_days": cfg.future_days},
        "event_time_basis": "UTC_elapsed_days", "event_scope": "sampled_geometric_crossings",
        "declination_orb_deg": cfg.declination_orb, "antiscia_orb_deg": cfg.antiscia_orb,
        "node_mode": cfg.node_mode, "altitude_m": cfg.altitude_m,
        "solar_thresholds": {"cazimi_deg": CAZIMI_ORB_DEG, "combust_deg": COMBUST_ORB_DEG, "under_beams_deg": UNDER_BEAMS_ORB_DEG},
        "longitude_sign_convention": "east_positive", "latitude_type": "geodetic",
        "numeric_precision": {"longitude_decimals": 8, "angle_decimals": 6, "event_time_tolerance_seconds": 0.01},
    }
    sun_lon = ctx.by_id["SUN"]["ecliptic"]["longitude_deg"]
    local = cfg.local_time
    time_location = {
        "local_datetime": local.isoformat(timespec="seconds"),
        "utc_datetime": cfg.instant.strftime("%Y-%m-%dT%H:%M:%SZ"), "utc_datetime_iso": cfg.instant.isoformat(),
        "timezone": cfg.chart["moment"]["timezone"], "utc_offset_seconds": int(local.utcoffset().total_seconds()),
        "dst_active": bool(local.dst() and local.dst().total_seconds()),
        "jd_ut": _r(ctx.jd_ut, 10), "jd_tt": _r(ctx.jd_ut + ctx.delta_t / 86400, 10) if ctx.delta_t is not None else None,
        "delta_t_seconds": _r(ctx.delta_t, 6), "delta_t_reason_code": None if ctx.delta_t is not None else "delta_t_unavailable",
        "sidereal_time_hours": _r(ctx.gst_hours, 8), "sidereal_time_reference": "Greenwich",
        "local_sidereal_time_hours": _r(ctx.armc / 15, 8), "armc_deg": _r(ctx.armc, 8),
        "obliquity_deg": _r(ctx.obliquity, 8), "latitude_deg": cfg.latitude, "longitude_deg": cfg.longitude,
        "longitude_sign_convention": "east_positive", "latitude_type": "geodetic", "altitude_m": cfg.altitude_m,
        "geocoding": {"source": "user_provided", "precision": "as_provided"},
        "sect": {"is_day": ctx.is_day, "rule_id": "sect.sun_above_horizon_by_asc_dsc_arc.v1",
                 "evidence": {"sun_longitude_deg": sun_lon, "asc_longitude_deg": _r(ctx.angles["ASC"]),
                              "dsc_longitude_deg": _r(ctx.angles["DSC"]) }},
    }
    house_rows = []
    for i, cusp in enumerate(ctx.cusps):
        ruler = SIGN_RULERS[zodiac_sign_index(cusp)]
        house_rows.append({"house": i + 1, "cusp_longitude_deg": _r(cusp), "span_deg": _r(_house_span(ctx.cusps, i), 6),
                           "sign": _sign_display(cusp), "domicile_ruler_id": ruler,
                           "domicile_ruler_en": BODY_EN.get(ruler, ruler), "domicile_ruler_zh": planet_name(ruler)})
    return {
        "schema": {"name": "horary-data-packet", "version": SCHEMA_VERSION, "schema_id": SCHEMA_ID},
        "question_metadata": {"question_text": cfg.question_text, "place_name": cfg.place_name},
        "calculation_config": calc_config,
        "provenance": {"engine_name": "TransitStudio.horary_v3", "engine_version": "3.0.0",
                       "algorithm_version": ALGORITHM_VERSION, "ephemeris_provider": "Swiss Ephemeris (pyswisseph)",
                       "ephemeris_version": swe.version, "input_hash_sha256": _hash_payload(cfg.canonical_input()),
                       "config_hash_sha256": _hash_payload(calc_config),
                       "precession_nutation": "Swiss Ephemeris defaults for FLG_SWIEPH",
                       "aberration_light_time": "Swiss Ephemeris defaults (included in SE positions)",
                       "shared_calculators": ["horary_v2 fact helpers", "horary_v2_aspects", "horary_v2_modules"]},
        "time_and_location": time_location,
        "houses": {"system": ctx.actual_house_system, "requested_system": cfg.house_system,
                   "system_label": ctx.house_label, "cusps": house_rows, "uses_ecliptic_longitude_for_body_houses": True,
                   "fallback_applied": fallback, "fallback_reason": "house_system_fallback_to_whole_sign" if fallback else None},
        "angles": {"points": [{"id": key, "longitude_deg": _r(value), "sign": _sign_display(value)}
                              for key, value in ctx.angles.items() if key != "ARMC"],
                   "armc": {"id": "ARMC", "longitude_deg": _r(ctx.armc), "unit": "degree",
                            "definition": "local_sidereal_time_deg = GST_hours*15 + geographic_longitude_east"}},
        **evidence,
        "validation": {"schema_id": SCHEMA_ID, "house_fallback_applied": fallback},
        "display": {"language_primary": "en_fields_zh_labels", "notes": "display fields are formatting only; numeric fields are authoritative"},
    }


def validate_packet(packet: dict[str, Any], warnings: list[str]) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []

    def issue(code: str, path: str) -> None:
        issues.append({"code": code, "path": path})

    forbidden = assert_no_forbidden_fields(packet)
    for path in forbidden:
        issue("forbidden_field", path)
    try:
        json.dumps(packet, allow_nan=False)
    except (TypeError, ValueError):
        issue("non_json_or_non_finite_value", "packet")
    events = packet["events"]
    ids = [e["id"] for e in events]
    event_ids = set(ids)
    if len(ids) != len(event_ids):
        issue("duplicate_event_id", "events")
    if events != sorted(events, key=lambda e: (e["offset_seconds_from_query"], e["id"])):
        issue("events_not_ordered", "events")
    candidate_ids = {c["id"] for c in packet["aspect_candidates"]}
    body_ids = {b["body_id"] for b in packet["bodies"]}
    at = parse_utc(packet["time_and_location"]["utc_datetime"])
    window = packet["event_search"]["window"]
    start, end = parse_utc(window["start_utc"]), parse_utc(window["end_utc"])
    for event in events:
        exact = parse_utc(event["datetime_utc"])
        if not start <= exact <= end:
            issue("event_outside_window", event["id"])
        if abs((exact - at).total_seconds() - event["offset_seconds_from_query"]) > 1e-6:
            issue("event_offset_mismatch", event["id"])
        if not set(event["body_ids"]).issubset(body_ids):
            issue("unknown_event_body", event["id"])
        if event.get("candidate_id") is not None and event["candidate_id"] not in candidate_ids:
            issue("unknown_aspect_candidate", event["id"])
        if not event.get("rule_ids") or event["rule_id"] not in event["rule_ids"]:
            issue("missing_event_rule", event["id"])
    graph = packet["event_graph"]
    for row in graph["per_body"]:
        for ref in row["ordered_event_ids"] + [row["previous_event_id"], row["next_event_id"]]:
            if ref is not None and ref not in event_ids:
                issue("dangling_event_reference", row["body_id"])
    for row in graph["aspect_candidate_sequences"]:
        for key in ("intervening_event_ids", "third_party_aspect_event_ids_before_exact", "house_change_event_ids_before_exact"):
            if not set(row[key]).issubset(event_ids):
                issue("dangling_event_reference", row["candidate_id"] + "." + key)
    for body in packet["bodies"]:
        for key, row in body["events_index"].items():
            if isinstance(row, dict) and row.get("event_id") and row["event_id"] not in event_ids:
                issue("dangling_body_event_reference", body["body_id"] + "." + key)
    for rule in packet["moon"]["void_of_course_rules"]:
        if rule["status"] == "unavailable" and rule["value"] is not None:
            issue("unknown_voc_has_value", rule["rule_id"])
    for item in issues:
        warnings.append(f"v3 invariant {item['code']}: {item['path']}")
    validation = packet["validation"]
    validation.update({
        "warnings": list(dict.fromkeys(warnings)), "forbidden_field_scan": "failed" if forbidden else "passed",
        "forbidden_fields_found": forbidden, "invariant_check": "failed" if issues else "passed",
        "invariant_issues": issues, "event_search_status": packet["event_search"]["status"],
        "body_count": len(packet["bodies"]), "aspect_count": len(packet["aspects"]),
        "aspect_candidate_count": len(packet["aspect_candidates"]),
        "aspects_in_display_orb_count": len(packet["aspects_in_display_orb"]),
        "event_count": len(events), "lot_count": len(packet["lots"]),
    })
    return issues
