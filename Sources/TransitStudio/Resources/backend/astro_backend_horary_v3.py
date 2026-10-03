"""Horary v3: validated configuration -> chart -> timeline -> evidence -> packet.

The v2.1 entry point is never invoked. Established fact calculators remain shared
with v2; their original rule and algorithm identifiers retain their provenance.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Any

from astro_backend_core import (
    angular_separation, jd_from_datetime, obliquity, set_zodiac_mode, swe,
)
from astro_backend_ephemeris import HOUSE_SYSTEMS, build_houses, longitude_in_interval
from astro_backend_horary_v2 import (
    _armc_degrees, _build_lots_v2, _delta_t_seconds, _dignity_for_body,
    _ensure_bundled_ephemeris_path, _full_body_calc, _optional_modules,
    _sidereal_time_hours, _visibility_for_bodies,
)
from astro_backend_horary_v2_aspects import build_aspect_candidates
from astro_backend_horary_v2_modules import (
    accidental_condition, antiscia_contacts, build_nodes, considerations_evidence,
    declination_parallels, enrich_visibility_pheno, event_graph,
    fixed_star_contacts, full_reception_matrix, planetary_day_hour,
)
from astro_backend_horary_v3_config import HoraryConfig, parse_utc
from astro_backend_horary_v3_events import EventTimeline
from astro_backend_horary_v3_moon import build_moon_index
from astro_backend_horary_v3_markdown import format_horary_v3_markdown
from astro_backend_horary_v3_search import EphemerisSampler


@dataclass
class ChartContext:
    config: HoraryConfig
    jd_ut: float
    sidereal: bool
    cusps: list[float]
    angles: dict[str, float]
    house_label: str
    actual_house_system: str
    is_day: bool
    bodies: list[dict[str, Any]]
    delta_t: float | None
    obliquity: float
    gst_hours: float
    armc: float

    @property
    def by_id(self) -> dict[str, dict[str, Any]]:
        return {row["body_id"]: row for row in self.bodies}

    @classmethod
    def calculate(cls, cfg: HoraryConfig, warnings: list[str]) -> ChartContext:
        if cfg.ephemeris_path:
            swe.set_ephe_path(cfg.ephemeris_path)
        else:
            _ensure_bundled_ephemeris_path()
        sidereal = set_zodiac_mode(cfg.zodiac, warnings)
        jd = jd_from_datetime(cfg.instant)
        cusps, angles, label = build_houses(jd, cfg.latitude, cfg.longitude, cfg.house_system, sidereal, warnings)
        actual_house = cfg.house_system if label == HOUSE_SYSTEMS[cfg.house_system][0] else "whole_sign"
        bodies = []
        for bid in cfg.body_ids:
            row = _full_body_calc(jd, bid, cusps, angles, cfg.latitude, cfg.longitude,
                                  cfg.altitude_m, sidereal, warnings)
            if row is None:
                if bid in {"SUN", "MOON"}:
                    raise ValueError(f"required body {bid} is unavailable")
                warnings.append(f"body {bid} unavailable; excluded from computed bodies")
                continue
            if not all(isinstance(row["ecliptic"][key], (int, float)) and math.isfinite(row["ecliptic"][key])
                       for key in ("longitude_deg", "longitude_speed_deg_per_day")):
                raise ValueError(f"body {bid} has invalid longitude or speed")
            row["precision"]["position_type"] = "apparent"
            bodies.append(row)
        sun = next(row for row in bodies if row["body_id"] == "SUN")
        is_day = longitude_in_interval(sun["ecliptic"]["longitude_deg"], angles["DSC"], angles["ASC"])
        delta_t = _delta_t_seconds(jd)
        if not math.isfinite(delta_t):
            warnings.append("delta_t_unavailable: jd_tt is null")
            delta_t = None
        return cls(cfg, jd, sidereal, cusps, angles, label, actual_house, is_day,
                   bodies, delta_t, obliquity(jd), _sidereal_time_hours(jd), _armc_degrees(jd, cfg.longitude))


def calculate_evidence(ctx: ChartContext, timeline: EventTimeline, warnings: list[str]) -> dict[str, Any]:
    cfg, bodies, by_id = ctx.config, ctx.bodies, ctx.by_id
    dignities = [_dignity_for_body(b["body_id"], b["ecliptic"]["longitude_deg"], ctx.is_day,
                                 cfg.bounds_system, cfg.triplicity_system) for b in bodies]
    sun_lon = by_id["SUN"]["ecliptic"]["longitude_deg"]
    for body in bodies:
        body["accidental"] = accidental_condition(body, ctx.is_day, sun_lon, ctx.angles, ctx.cusps)
    nodes = build_nodes(cfg.local_time, ctx.jd_ut, ctx.cusps, ctx.angles, cfg.latitude, cfg.longitude,
                        cfg.altitude_m, ctx.sidereal, warnings, _full_body_calc, node_mode=cfg.node_mode)
    for node in nodes:
        node["precision"]["position_type"] = "apparent"
    geometry, candidates = build_aspect_candidates(cfg.local_time, bodies, cfg.aspect_orb, warnings, ctx.sidereal,
                                                  event_past_days=cfg.past_days, event_future_days=cfg.future_days)
    for candidate in candidates:
        exact = candidate["next_exact"].get("datetime_utc")
        candidate["will_perfect_in_window"] = bool(exact and cfg.instant < parse_utc(exact) <= cfg.window.end)
    rule_context = dict(chart_dt=cfg.local_time, cusps=ctx.cusps, is_day=ctx.is_day,
                        bounds_system=cfg.bounds_system, triplicity_system=cfg.triplicity_system,
                        warnings=warnings, sidereal=ctx.sidereal)
    receptions = full_reception_matrix(bodies, dignities, candidates, **rule_context)
    lots = _build_lots_v2(ctx.angles, by_id, ctx.cusps, ctx.is_day, cfg.bounds_system, cfg.triplicity_system, warnings)
    moon = build_moon_index(timeline, by_id)
    north = next((n for n in nodes if n["body_id"] in {"MEAN_NODE", "TRUE_NODE"}), None)
    if north is not None:
        moon["distance_to_north_node_deg"] = round(angular_separation(
            by_id["MOON"]["ecliptic"]["longitude_deg"], north["ecliptic"]["longitude_deg"]), 6)
        moon["north_node_id_used"] = north["body_id"]
    events = timeline.configured_events([b["body_id"] for b in bodies])
    timeline.attach_body_indices(bodies)
    graph = event_graph(bodies, events, candidates, **rule_context)
    search_available = all(c["status"] != "unavailable" for c in timeline.coverage)
    for sequence in graph["aspect_candidate_sequences"]:
        sequence["coverage_status"] = (
            "sampled_through_exact" if search_available and cfg.window.contains(parse_utc(sequence["next_exact_utc"]))
            else "partial"
        )
    graph["event_source"] = "v3_geometric_timeline"
    planetary = planetary_day_hour(cfg.local_time, cfg.latitude, cfg.longitude, cfg.altitude_m, warnings)
    # Use the same instant comparisons for fixed offsets and DST-aware locations.
    for hour in planetary.get("hours") or []:
        if parse_utc(hour["start_utc"]) <= cfg.instant < parse_utc(hour["end_utc"]):
            planetary["current_hour"] = hour
            break
    unique = {b["body_id"]: b for b in bodies + nodes}
    declination = declination_parallels(list(unique.values()), chart_dt=cfg.local_time,
                                       orb_deg=cfg.declination_orb, warnings=warnings, sidereal=ctx.sidereal,
                                       past_days=cfg.past_days, future_days=cfg.future_days)
    visibility = _visibility_for_bodies(bodies, by_id["SUN"])
    for row in visibility:
        # Elongation is not a substitute for an unavailable physical phase angle.
        row["phase_angle_deg"] = None
    visibility = enrich_visibility_pheno(ctx.jd_ut, visibility, bodies, warnings)
    optional = _optional_modules(bodies, cfg.local_time, cfg.latitude, cfg.longitude, ctx.is_day)
    optional.update({
        "nodes": {"mode": cfg.node_mode, "bodies": nodes, "rule_id": "nodes.mean_default_true_optional.v1"},
        "antiscia_contacts": antiscia_contacts(list(unique.values()), ctx.angles, ctx.cusps, lots, orb_deg=cfg.antiscia_orb),
        "declination_contacts": declination["contacts"],
        "declination_moon_sequence": declination.get("moon_sequence"),
        "fixed_stars": fixed_star_contacts(ctx.jd_ut, bodies, ctx.angles, ctx.sidereal, warnings),
    })
    return {
        "bodies": bodies, "dignities": dignities, "pairwise_geometry": geometry,
        "aspects": candidates, "aspect_candidates": candidates,
        "aspects_in_display_orb": [c for c in candidates if c["within_display_orb"]],
        "display_orb_deg": cfg.aspect_orb, "receptions": receptions, "lots": lots,
        "events": events, "event_graph": graph, "moon": moon, "visibility": visibility,
        "planetary_day_hour": planetary,
        "considerations_evidence": considerations_evidence(ctx.angles, bodies, moon, planetary, {"cusps": ctx.cusps}),
        "nodes": optional["nodes"], "optional_modules": optional,
        "event_search": {"window": cfg.window.payload(), "coverage": timeline.coverage,
                         "status": "sampled" if search_available else "partial",
                         "scope": "geometric_events; candidate perfection eligibility is separate",
                         "house_frame": "fixed_query_chart_cusps"},
    }


def calculate_horary_v3(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    from astro_backend_horary_v3_packet import assemble_packet, validate_packet

    config = HoraryConfig.from_request(request)
    chart = ChartContext.calculate(config, warnings)
    timeline = EventTimeline(config, EphemerisSampler(chart.sidereal, warnings), chart.cusps)
    timeline.build([body["body_id"] for body in chart.bodies])
    evidence = calculate_evidence(chart, timeline, warnings)
    packet = assemble_packet(chart, evidence)
    validate_packet(packet, warnings)
    packet["display"]["reader_markdown"] = format_horary_v3_markdown(packet)
    return packet
