"""Horary v2.1 optional/structured modules: nodes, accidental, receptions, event graph,
planetary day/hour, considerations, declination, antiscia contacts, fixed stars, pheno.
"""
from __future__ import annotations

import math
from datetime import datetime, timedelta, timezone, tzinfo
from typing import Any

from astro_backend_classical_dignity import JOY_HOUSE, SIGN_ELEMENTS, SIGN_GENDER
from astro_backend_core import (
    BODY_REGISTRY,
    CLASSICAL_BODY_IDS,
    angular_separation,
    format_local,
    jd_from_datetime,
    norm360,
    planet_name,
    sign_degree,
    swe,
    zodiac_sign_index,
)
from astro_backend_ephemeris import body_longitude_at, body_speed_at, house_for_longitude
from astro_backend_fixed_stars import STAR_CATALOG, compute_star_positions
from astro_backend_horary import (
    MEAN_DAILY_SPEED_BY_BODY,
    body_exits_sign_before,
    next_sign_exit_for_body,
    station_speed_threshold,
)
from astro_backend_visibility import _planetary_hours

ALGORITHM = "horary-v2.1-modules-2026-07"
MEAN_SPEED = {
    "SUN": 0.9856, "MOON": 13.1764, "MERCURY": 1.383, "VENUS": 1.2,
    "MARS": 0.524, "JUPITER": 0.083, "SATURN": 0.033,
}
SIGN_MODE = ["cardinal", "fixed", "mutable"] * 4  # by sign index


def _r(v: float | None, d: int = 6) -> float | None:
    if v is None:
        return None
    return round(float(v), d)


def _utc(dt: datetime | None) -> str | None:
    if dt is None:
        return None
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def build_nodes(
    chart_dt: datetime,
    chart_jd: float,
    cusps: list[float],
    angles: dict[str, float],
    latitude: float,
    longitude: float,
    altitude_m: float,
    sidereal: bool,
    warnings: list[str],
    body_calc,
    node_mode: str = "mean",
) -> list[dict[str, Any]]:
    """Mean (default) and optional true nodes; south = north + 180."""
    rows: list[dict[str, Any]] = []
    modes = ["mean"]
    if node_mode in {"true", "both"}:
        modes.append("true")
    if node_mode == "true":
        modes = ["true"]

    id_map = {
        "mean": ("MEAN_NODE", "SOUTH_MEAN_NODE"),
        "true": ("TRUE_NODE", "SOUTH_TRUE_NODE"),
    }
    for mode in modes:
        north_id, south_id = id_map[mode]
        for bid, role in ((north_id, "north"), (south_id, "south")):
            if bid not in BODY_REGISTRY:
                continue
            row = body_calc(
                chart_jd, bid, cusps, angles, latitude, longitude, altitude_m, sidereal, warnings,
            )
            if row is None:
                continue
            row["node_mode"] = mode
            row["node_role"] = role
            row["south_derivation"] = "north_plus_180" if role == "south" else None
            row["participates_in_domicile_rulership"] = False
            row["participates_in_classical_dignities"] = False
            rows.append(row)
    rows.sort(key=lambda r: r["body_id"])
    return rows


def accidental_condition(
    body: dict[str, Any],
    is_day: bool,
    sun_lon: float,
    angles: dict[str, float],
    cusps: list[float],
) -> dict[str, Any]:
    bid = body["body_id"]
    lon = body["ecliptic"]["longitude_deg"]
    house = body["house"]["integer_house"]
    speed = body["ecliptic"].get("longitude_speed_deg_per_day") or 0.0
    mean = MEAN_SPEED.get(bid)
    if house in {1, 4, 7, 10}:
        house_class = "angular"
    elif house in {2, 5, 8, 11}:
        house_class = "succedent"
    else:
        house_class = "cadent"
    sign_idx = zodiac_sign_index(lon)
    mode = SIGN_MODE[sign_idx]
    joy = JOY_HOUSE.get(bid)
    in_joy = joy is not None and house == joy
    # oriental/occidental: planet rises before sun if west of sun in traditional sense
    sep_signed = ((lon - sun_lon + 180) % 360) - 180
    oriental = sep_signed < 0  # behind sun in zodiac often treated as oriental for inferior; documented rule
    approaching_sun = abs(sep_signed) < abs(((lon + speed - sun_lon + 180) % 360) - 180) if speed else False
    thr = station_speed_threshold(bid)
    station_proximity = None
    if thr is not None and thr > 0:
        station_proximity = abs(speed) / thr
    dist_angles = {
        k: _r(((lon - angles[k] + 180) % 360) - 180, 6)
        for k in ("ASC", "MC", "DSC", "IC")
        if k in angles
    }
    cusp_dist = [
        {
            "house": i + 1,
            "signed_distance_deg": _r(((lon - cusps[i] + 180) % 360) - 180, 6),
            "absolute_distance_deg": _r(min(abs(((lon - cusps[i] + 180) % 360) - 180), 360 - abs(((lon - cusps[i] + 180) % 360) - 180)), 6),
        }
        for i in range(12)
    ]
    angular_orb = 5.0
    near_angle = None
    for k, d in dist_angles.items():
        if d is not None and abs(d) <= angular_orb:
            near_angle = k
            break
    # Hayz components (evidence only)
    diurnal_planet = bid in {"SUN", "JUPITER", "SATURN"}
    nocturnal_planet = bid in {"MOON", "VENUS", "MARS"}
    above = body.get("horizontal", {}).get("above_horizon")
    hayz_parts = {
        "planet_sect_matches_chart": (diurnal_planet and is_day) or (nocturnal_planet and not is_day) or bid == "MERCURY",
        "hemisphere_matches_sect": (above is True and is_day) or (above is False and not is_day) if above is not None else None,
        "sign_gender_matches_sect": (SIGN_GENDER[sign_idx] == "masc" and is_day) or (SIGN_GENDER[sign_idx] == "fem" and not is_day),
    }
    return {
        "body_id": bid,
        "house_class": house_class,
        "house_class_rule_id": "accidental.house_class.angular_succedent_cadent.v1",
        "sign_mode": mode,
        "sign_mode_rule_id": "sign.modality.cardinal_fixed_mutable.v1",
        "distance_to_angles_signed_deg": dist_angles,
        "near_angle": {
            "angle_id": near_angle,
            "threshold_deg": angular_orb,
            "rule_id": "accidental.near_angle.orb5.v1",
        },
        "cusp_distances": cusp_dist,
        "joy_house": joy,
        "in_joy_house": in_joy,
        "joy_rule_id": "accidental.joy_house.traditional.v1",
        "oriental_occidental": "oriental" if oriental else "occidental",
        "oriental_rule_id": "solar.oriental_signed_ecliptic_offset.v1",
        "approaching_sun": approaching_sun,
        "speed_vs_mean": {
            "faster_than_mean": (abs(speed) > mean) if mean else None,
            "speed": _r(speed, 8),
            "mean": _r(mean, 8) if mean else None,
            "ratio": _r(abs(speed) / mean, 6) if mean and mean > 0 else None,
            "rule_id": "motion.speed_vs_mean.v1",
        },
        "station_proximity_ratio": _r(station_proximity, 6) if station_proximity is not None else None,
        "hayz_evidence": {
            **hayz_parts,
            "rule_id": "sect.hayz.components.v1",
            "algorithm_version": ALGORITHM,
            "note": "component facts only; no composite hayz boolean judgment required by consumers",
        },
        "algorithm_version": ALGORITHM,
    }


def _dignity_receiver_for_type(dig: dict[str, Any], dig_type: str) -> str | None:
    if dig_type == "domicile":
        return dig.get("domicile_ruler_id")
    if dig_type == "exaltation":
        return dig.get("exaltation_ruler_id")
    if dig_type == "triplicity":
        return (dig.get("triplicity") or {}).get("active_ruler_id")
    if dig_type == "bound":
        return (dig.get("bounds") or {}).get("ruler_id")
    if dig_type == "decan":
        return (dig.get("decan") or {}).get("ruler_id")
    if dig_type == "detriment":
        return dig.get("detriment_ruler_id")
    if dig_type == "fall":
        return dig.get("fall_ruler_id")
    return None


def _snapshot_body_at(
    dt: datetime,
    body_id: str,
    cusps: list[float],
    is_day: bool,
    bounds_system: str,
    triplicity_system: str,
    warnings: list[str],
    sidereal: bool,
) -> dict[str, Any] | None:
    from astro_backend_horary_v2 import _dignity_for_body  # local import avoids circular at module load

    if body_id not in BODY_REGISTRY:
        return None
    warning_keys: set[str] = set()
    lon_t = body_longitude_at(dt, BODY_REGISTRY[body_id], warnings, warning_keys, sidereal=sidereal)
    spd_t = body_speed_at(dt, BODY_REGISTRY[body_id], warnings, warning_keys, sidereal=sidereal)
    if lon_t is None:
        return None
    lon = lon_t[0]
    speed = spd_t[0] if spd_t else None
    house = house_for_longitude(lon, cusps) if cusps and len(cusps) == 12 else None
    dig = _dignity_for_body(body_id, lon, is_day, bounds_system, triplicity_system)
    return {
        "body_id": body_id,
        "datetime_utc": _utc(dt),
        "longitude_deg": _r(lon, 8),
        "speed_deg_per_day": _r(speed, 8) if speed is not None else None,
        "integer_house": house,
        "sign_index": dig.get("sign_index"),
        "domicile_ruler_id": dig.get("domicile_ruler_id"),
        "exaltation_ruler_id": dig.get("exaltation_ruler_id"),
        "bound_ruler_id": (dig.get("bounds") or {}).get("ruler_id"),
        "decan_ruler_id": (dig.get("decan") or {}).get("ruler_id"),
        "triplicity_active_ruler_id": (dig.get("triplicity") or {}).get("active_ruler_id"),
        "detriment_ruler_id": dig.get("detriment_ruler_id"),
        "fall_ruler_id": dig.get("fall_ruler_id"),
    }


def _earliest_next_exact(
    aspect_candidates: list[dict[str, Any]],
    candidate_ids: list[str],
) -> tuple[str | None, datetime | None, dict[str, Any] | None]:
    best_id = None
    best_dt = None
    best_c = None
    for cid in candidate_ids:
        c = next((x for x in aspect_candidates if x.get("id") == cid), None)
        if not c:
            continue
        utc = ((c.get("next_exact") or {}).get("datetime_utc"))
        if not utc:
            continue
        try:
            dt = datetime.strptime(utc, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        except ValueError:
            continue
        if best_dt is None or dt < best_dt:
            best_dt = dt
            best_id = cid
            best_c = c
    return best_id, best_dt, best_c


def full_reception_matrix(
    bodies: list[dict[str, Any]],
    dignities: list[dict[str, Any]],
    aspect_candidates: list[dict[str, Any]],
    chart_dt: datetime | None = None,
    cusps: list[float] | None = None,
    is_day: bool = True,
    bounds_system: str = "egyptian",
    triplicity_system: str = "dorothean",
    warnings: list[str] | None = None,
    sidereal: bool = False,
) -> list[dict[str, Any]]:
    warnings = warnings if warnings is not None else []
    dig_map = {d["body_id"]: d for d in dignities}
    body_ids = {b["body_id"] for b in bodies if b["body_id"] in dig_map}
    aspect_index = {c["id"]: c for c in aspect_candidates}
    # map pair -> candidate ids in orb or applying
    pair_aspects: dict[str, list[str]] = {}
    for c in aspect_candidates:
        pk = "|".join(sorted((c["body_a_id"], c["body_b_id"])))
        pair_aspects.setdefault(pk, []).append(c["id"])

    rows: list[dict[str, Any]] = []
    seen: set[str] = set()

    def emit(receiver: str, received: str, dig_type: str, dig: dict[str, Any]) -> None:
        if receiver not in body_ids or received not in body_ids:
            return
        if receiver == received and dig_type not in {"domicile", "exaltation", "bound", "decan", "triplicity"}:
            return
        key = f"{receiver}|{received}|{dig_type}"
        if key in seen:
            return
        seen.add(key)
        pk = "|".join(sorted((receiver, received)))
        rows.append({
            "id": key,
            "receiver_id": receiver,
            "received_body_id": received,
            "dignity_type": dig_type,
            "direction": "receiver_disposes_received",
            "related_aspect_candidate_ids": pair_aspects.get(pk, []),
            "sign_index": dig.get("sign_index"),
            "systems": dig.get("systems"),
            "rule_id": "reception.directed.v2",
            "algorithm_version": ALGORITHM,
        })

    for received, dig in dig_map.items():
        emit(dig["domicile_ruler_id"], received, "domicile", dig)
        if dig.get("exaltation_ruler_id"):
            emit(dig["exaltation_ruler_id"], received, "exaltation", dig)
        if dig["triplicity"].get("active_ruler_id"):
            emit(dig["triplicity"]["active_ruler_id"], received, "triplicity", dig)
        emit(dig["bounds"]["ruler_id"], received, "bound", dig)
        emit(dig["decan"]["ruler_id"], received, "decan", dig)
        # Always emit detriment/fall ruler relationship (who rules the detriment/fall place)
        if dig.get("detriment_ruler_id"):
            emit(dig["detriment_ruler_id"], received, "detriment", dig)
        if dig.get("fall_ruler_id"):
            emit(dig["fall_ruler_id"], received, "fall", dig)

    # Mutual / mixed reception flags as separate relation records (neutral)
    by_pair_types: dict[tuple[str, str], set[str]] = {}
    for r in rows:
        a, b = r["receiver_id"], r["received_body_id"]
        by_pair_types.setdefault((a, b), set()).add(r["dignity_type"])
    mutual_rows: list[dict[str, Any]] = []
    for (a, b), types_ab in list(by_pair_types.items()):
        # Self-directed dignity (e.g. Sun in Leo domicile) is not mutual reception.
        if a == b:
            continue
        types_ba = by_pair_types.get((b, a), set())
        if not types_ba:
            continue
        # Canonical order so mutual|A|B and mutual|B|A collapse to one row.
        lo, hi = (a, b) if a < b else (b, a)
        types_lo_hi = by_pair_types.get((lo, hi), set())
        types_hi_lo = by_pair_types.get((hi, lo), set())
        # mutual: each disposes the other by domicile or exaltation
        if ({"domicile", "exaltation"} & types_lo_hi) and ({"domicile", "exaltation"} & types_hi_lo):
            mid = f"mutual|{lo}|{hi}"
            if mid not in seen:
                seen.add(mid)
                mutual_rows.append({
                    "id": mid,
                    "body_a_id": lo,
                    "body_b_id": hi,
                    "relation_kind": "mutual_reception",
                    "a_to_b_types": sorted(types_lo_hi),
                    "b_to_a_types": sorted(types_hi_lo),
                    "rule_id": "reception.mutual.domicile_or_exaltation.v1",
                    "algorithm_version": ALGORITHM,
                })
        elif types_lo_hi and types_hi_lo:
            mid = f"mixed|{lo}|{hi}"
            if mid not in seen:
                seen.add(mid)
                mutual_rows.append({
                    "id": mid,
                    "body_a_id": lo,
                    "body_b_id": hi,
                    "relation_kind": "mixed_reception",
                    "a_to_b_types": sorted(types_lo_hi),
                    "b_to_a_types": sorted(types_hi_lo),
                    "rule_id": "reception.mixed.any_dignity_pair.v1",
                    "algorithm_version": ALGORITHM,
                })

    rows.sort(key=lambda r: r["id"])
    mutual_rows.sort(key=lambda r: r["id"])

    def _annotate_directed(r: dict[str, Any]) -> dict[str, Any]:
        r = dict(r)
        r["relation_at_query"] = True
        receiver = r.get("receiver_id")
        received = r.get("received_body_id")
        dig_type = r.get("dignity_type")
        cids = r.get("related_aspect_candidate_ids") or []
        if not chart_dt or not cusps or not receiver or not received or not dig_type:
            r["relation_at_next_aspect_exact"] = {
                "status": "not_evaluated",
                "reason_code": "missing_chart_context",
            }
            r["relation_changes_if_sign_exit_before_exact"] = {
                "status": "not_evaluated",
                "reason_code": "missing_chart_context",
            }
            return r

        cand_id, exact_dt, cand = _earliest_next_exact(aspect_candidates, cids)
        if exact_dt is None or cand is None:
            r["relation_at_next_aspect_exact"] = {
                "status": "no_related_future_exact",
                "reason_code": "no_next_exact_among_related_aspect_candidates",
                "related_aspect_candidate_ids": cids,
                "holds": None,
            }
            r["relation_changes_if_sign_exit_before_exact"] = {
                "status": "no_related_future_exact",
                "changes": None,
                "rule_id": "reception.pre_exact_sign_exit.v2",
            }
            return r

        if chart_dt.tzinfo and exact_dt.tzinfo is None:
            exact_local = exact_dt.replace(tzinfo=timezone.utc).astimezone(chart_dt.tzinfo)
        elif chart_dt.tzinfo:
            exact_local = exact_dt.astimezone(chart_dt.tzinfo)
        else:
            exact_local = exact_dt.replace(tzinfo=None)

        snap = _snapshot_body_at(
            exact_local, received, cusps, is_day, bounds_system, triplicity_system, warnings, sidereal,
        )
        holds = None
        if snap is not None:
            # rebuild dig-like view from snapshot fields
            dig_at = {
                "domicile_ruler_id": snap.get("domicile_ruler_id"),
                "exaltation_ruler_id": snap.get("exaltation_ruler_id"),
                "triplicity": {"active_ruler_id": snap.get("triplicity_active_ruler_id")},
                "bounds": {"ruler_id": snap.get("bound_ruler_id")},
                "decan": {"ruler_id": snap.get("decan_ruler_id")},
                "detriment_ruler_id": snap.get("detriment_ruler_id"),
                "fall_ruler_id": snap.get("fall_ruler_id"),
            }
            holds = _dignity_receiver_for_type(dig_at, dig_type) == receiver

        warning_keys: set[str] = set()
        received_exits = body_exits_sign_before(
            chart_dt, exact_local, received, warnings, warning_keys, sidereal=sidereal,
        )
        # compare sign index at query vs exact
        dig_query = dig_map.get(received) or {}
        sign_query = dig_query.get("sign_index")
        sign_exact = snap.get("sign_index") if snap else None
        changes = None
        if snap is not None and sign_query is not None and sign_exact is not None:
            changes = bool(received_exits or sign_query != sign_exact)
            if holds is not None and dig_type:
                # also explicit: receiver identity at exact differs from query relation
                query_receiver = _dignity_receiver_for_type(dig_query, dig_type)
                changes = changes or (query_receiver != _dignity_receiver_for_type({
                    "domicile_ruler_id": snap.get("domicile_ruler_id"),
                    "exaltation_ruler_id": snap.get("exaltation_ruler_id"),
                    "triplicity": {"active_ruler_id": snap.get("triplicity_active_ruler_id")},
                    "bounds": {"ruler_id": snap.get("bound_ruler_id")},
                    "decan": {"ruler_id": snap.get("decan_ruler_id")},
                    "detriment_ruler_id": snap.get("detriment_ruler_id"),
                    "fall_ruler_id": snap.get("fall_ruler_id"),
                }, dig_type))

        r["relation_at_next_aspect_exact"] = {
            "status": "evaluated",
            "candidate_id": cand_id,
            "exact_datetime_utc": _utc(exact_local),
            "holds": holds,
            "received_snapshot": snap,
            "rule_id": "reception.at_next_aspect_exact.v2",
            "algorithm_version": ALGORITHM,
        }
        r["relation_changes_if_sign_exit_before_exact"] = {
            "status": "evaluated",
            "changes": changes,
            "received_exits_sign_before_exact": received_exits,
            "sign_index_at_query": sign_query,
            "sign_index_at_exact": sign_exact,
            "rule_id": "reception.pre_exact_sign_exit.v2",
            "algorithm_version": ALGORITHM,
        }
        return r

    def _annotate_mutual(r: dict[str, Any]) -> dict[str, Any]:
        r = dict(r)
        r["relation_at_query"] = True
        a = r.get("body_a_id")
        b = r.get("body_b_id")
        pk = "|".join(sorted((a, b))) if a and b else ""
        cids = pair_aspects.get(pk, [])
        cand_id, exact_dt, cand = _earliest_next_exact(aspect_candidates, cids)
        if not chart_dt or not cusps or exact_dt is None:
            r["relation_at_next_aspect_exact"] = {
                "status": "no_related_future_exact" if exact_dt is None else "not_evaluated",
                "holds": None,
            }
            r["relation_changes_if_sign_exit_before_exact"] = {
                "status": "no_related_future_exact" if exact_dt is None else "not_evaluated",
                "changes": None,
                "rule_id": "reception.pre_exact_sign_exit.v2",
            }
            return r
        if chart_dt.tzinfo:
            exact_local = exact_dt.astimezone(chart_dt.tzinfo)
        else:
            exact_local = exact_dt.replace(tzinfo=None)
        snap_a = _snapshot_body_at(exact_local, a, cusps, is_day, bounds_system, triplicity_system, warnings, sidereal)
        snap_b = _snapshot_body_at(exact_local, b, cusps, is_day, bounds_system, triplicity_system, warnings, sidereal)
        # mutual domicile/exaltation at exact
        holds = None
        if snap_a and snap_b:
            a_types = set()
            b_types = set()
            if snap_a.get("domicile_ruler_id") == b:
                a_types.add("domicile")
            if snap_a.get("exaltation_ruler_id") == b:
                a_types.add("exaltation")
            if snap_b.get("domicile_ruler_id") == a:
                b_types.add("domicile")
            if snap_b.get("exaltation_ruler_id") == a:
                b_types.add("exaltation")
            if r.get("relation_kind") == "mutual_reception":
                holds = bool(a_types & {"domicile", "exaltation"}) and bool(b_types & {"domicile", "exaltation"})
            else:
                holds = bool(a_types or b_types)  # mixed: any dignity exchange at exact
        warning_keys: set[str] = set()
        a_exit = body_exits_sign_before(chart_dt, exact_local, a, warnings, warning_keys, sidereal=sidereal) if a else False
        b_exit = body_exits_sign_before(chart_dt, exact_local, b, warnings, warning_keys, sidereal=sidereal) if b else False
        r["relation_at_next_aspect_exact"] = {
            "status": "evaluated",
            "candidate_id": cand_id,
            "exact_datetime_utc": _utc(exact_local),
            "holds": holds,
            "body_a_snapshot": snap_a,
            "body_b_snapshot": snap_b,
            "rule_id": "reception.at_next_aspect_exact.v2",
        }
        r["relation_changes_if_sign_exit_before_exact"] = {
            "status": "evaluated",
            "changes": bool(a_exit or b_exit),
            "body_a_exits_sign_before_exact": a_exit,
            "body_b_exits_sign_before_exact": b_exit,
            "rule_id": "reception.pre_exact_sign_exit.v2",
        }
        return r

    annotated = [_annotate_directed(r) for r in rows] + [_annotate_mutual(r) for r in mutual_rows]
    return annotated


def event_graph(
    bodies: list[dict[str, Any]],
    events: list[dict[str, Any]],
    aspect_candidates: list[dict[str, Any]],
    chart_dt: datetime,
    cusps: list[float] | None = None,
    is_day: bool = True,
    bounds_system: str = "egyptian",
    triplicity_system: str = "dorothean",
    warnings: list[str] | None = None,
    sidereal: bool = False,
) -> dict[str, Any]:
    warnings = warnings if warnings is not None else []
    by_body: dict[str, list[dict[str, Any]]] = {}
    for ev in events:
        for bid in ev.get("body_ids") or []:
            by_body.setdefault(bid, []).append(ev)
    for bid in by_body:
        by_body[bid].sort(key=lambda e: e["offset_seconds_from_query"])

    per_body = []
    for body in bodies:
        bid = body["body_id"]
        seq = by_body.get(bid, [])
        past = [e for e in seq if e["offset_seconds_from_query"] < 0]
        future = [e for e in seq if e["offset_seconds_from_query"] >= 0]
        per_body.append({
            "body_id": bid,
            "previous_event_id": past[-1]["id"] if past else None,
            "next_event_id": future[0]["id"] if future else None,
            "ordered_event_ids": [e["id"] for e in seq],
        })
    per_body.sort(key=lambda r: r["body_id"])

    # Candidate sequencing: events before next exact + materialized exact snapshots
    cand_seq = []
    for c in aspect_candidates:
        nxt = (c.get("next_exact") or {}).get("datetime_utc")
        if not nxt:
            continue
        try:
            exact = datetime.strptime(nxt, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            if chart_dt.tzinfo:
                exact = exact.astimezone(chart_dt.tzinfo)
            off = int((exact.astimezone(timezone.utc) - chart_dt.astimezone(timezone.utc)).total_seconds())
        except ValueError:
            continue
        intervening = [
            e["id"]
            for e in events
            if 0 < e["offset_seconds_from_query"] < off
            and (c["body_a_id"] in e.get("body_ids", []) or c["body_b_id"] in e.get("body_ids", []))
        ]
        sa = next((b for b in bodies if b["body_id"] == c["body_a_id"]), None)
        sb = next((b for b in bodies if b["body_id"] == c["body_b_id"]), None)
        if sa and sb:
            va = abs(sa["ecliptic"].get("longitude_speed_deg_per_day") or 0)
            vb = abs(sb["ecliptic"].get("longitude_speed_deg_per_day") or 0)
            faster = c["body_a_id"] if va >= vb else c["body_b_id"]
            slower = c["body_b_id"] if va >= vb else c["body_a_id"]
        else:
            faster = c["body_a_id"]
            slower = c["body_b_id"]
        snap_a = {
            "body_id": c["body_a_id"],
            "longitude_deg": sa["ecliptic"]["longitude_deg"] if sa else None,
            "speed_deg_per_day": sa["ecliptic"].get("longitude_speed_deg_per_day") if sa else None,
            "integer_house": sa["house"]["integer_house"] if sa else None,
            "sign_index": sa["sign"]["sign_index"] if sa and sa.get("sign") else None,
        } if sa else None
        snap_b = {
            "body_id": c["body_b_id"],
            "longitude_deg": sb["ecliptic"]["longitude_deg"] if sb else None,
            "speed_deg_per_day": sb["ecliptic"].get("longitude_speed_deg_per_day") if sb else None,
            "integer_house": sb["house"]["integer_house"] if sb else None,
            "sign_index": sb["sign"]["sign_index"] if sb and sb.get("sign") else None,
        } if sb else None
        third_party = [
            e["id"] for e in events
            if 0 < e["offset_seconds_from_query"] < off
            and e.get("event_type") == "aspect_exact"
            and (
                (c["body_a_id"] in e.get("body_ids", []) and c["body_b_id"] not in e.get("body_ids", []))
                or (c["body_b_id"] in e.get("body_ids", []) and c["body_a_id"] not in e.get("body_ids", []))
            )
        ]
        house_changes = [
            e["id"] for e in events
            if 0 < e["offset_seconds_from_query"] < off
            and e.get("event_type") == "house_change"
            and (c["body_a_id"] in e.get("body_ids", []) or c["body_b_id"] in e.get("body_ids", []))
        ]
        exact_snap_a = exact_snap_b = None
        if cusps and len(cusps) == 12:
            exact_snap_a = _snapshot_body_at(
                exact, c["body_a_id"], cusps, is_day, bounds_system, triplicity_system, warnings, sidereal,
            )
            exact_snap_b = _snapshot_body_at(
                exact, c["body_b_id"], cusps, is_day, bounds_system, triplicity_system, warnings, sidereal,
            )
        cand_seq.append({
            "candidate_id": c["id"],
            "next_exact_utc": nxt,
            "faster_body_id": faster,
            "slower_body_id": slower,
            "intervening_event_ids": intervening,
            "third_party_aspect_event_ids_before_exact": third_party,
            "house_change_event_ids_before_exact": house_changes,
            "sign_exit_before_exact": c.get("sign_exit_before_exact"),
            "station_or_retrograde_before_exact": c.get("station_or_retrograde_before_exact"),
            "station_or_retrograde_evidence": c.get("station_or_retrograde_evidence"),
            "refranation_detected": c.get("refranation_detected"),
            "positions_at_query": {"body_a": snap_a, "body_b": snap_b},
            "positions_at_exact": {
                "status": "evaluated" if (exact_snap_a or exact_snap_b) else "unavailable",
                "exact_datetime_utc": nxt,
                "body_a": exact_snap_a,
                "body_b": exact_snap_b,
                "rule_id": "event_graph.positions_at_exact.v2",
            },
            "rule_id": "event_graph.candidate_sequence.v2",
        })
    cand_seq.sort(key=lambda r: r["candidate_id"])

    moon_seq = next((r for r in per_body if r["body_id"] == "MOON"), None)
    return {
        "per_body": per_body,
        "aspect_candidate_sequences": cand_seq,
        "moon_sequence": moon_seq,
        "algorithm_version": ALGORITHM,
        "note": "Facts for Translation/Collection/Prohibition/Frustration analysis; no conclusions emitted",
    }


def planetary_day_hour(
    chart_dt: datetime,
    latitude: float,
    longitude: float,
    altitude_m: float,
    warnings: list[str],
) -> dict[str, Any]:
    """Unequal planetary day/hour table for the chart moment.

    Display zone is the chart's own tzinfo: an IANA ``ZoneInfo`` when the
    moment was resolved from an IANA name, or a fixed-offset ``timezone`` for
    GMT±N labels (e.g. Swift's ``GMTOffset`` "GMT+8"). Both support
    ``.astimezone``; only a naive chart falls back to UTC.
    """
    ref_utc = chart_dt.astimezone(timezone.utc)
    display_zone: tzinfo = chart_dt.tzinfo if chart_dt.tzinfo is not None else timezone.utc

    raw = _planetary_hours(
        reference_utc=ref_utc,
        latitude=latitude,
        longitude=longitude,
        altitude_m=altitude_m,
        display_zone=display_zone,
        warnings=warnings,
    )
    raw["rule_id"] = "planetary_hours.unequal.chaldean.v1"
    raw["algorithm_version"] = ALGORITHM
    return raw


def considerations_evidence(
    angles: dict[str, float],
    bodies: list[dict[str, Any]],
    moon: dict[str, Any],
    planetary: dict[str, Any],
    houses: dict[str, Any],
) -> list[dict[str, Any]]:
    """Neutral pre-judgment facts — no radical=true/false."""
    out: list[dict[str, Any]] = []
    asc = angles.get("ASC")
    if asc is not None:
        deg = sign_degree(asc)
        out.append({
            "id": "asc_degree_in_sign",
            "fact_type": "asc_sign_degree",
            "value": _r(deg, 6),
            "early_threshold_deg": 3.0,
            "late_threshold_deg": 27.0,
            "is_below_early_threshold": deg < 3.0,
            "is_above_late_threshold": deg > 27.0,
            "rule_id": "consideration.asc_early_late.degree.v1",
            "algorithm_version": ALGORITHM,
        })
    for rule in moon.get("void_of_course_rules") or []:
        out.append({
            "id": f"voc|{rule['rule_id']}",
            "fact_type": "moon_voc_rule",
            "rule_id": rule["rule_id"],
            "value": rule.get("value"),
            "interval": rule.get("interval"),
            "algorithm_version": ALGORITHM,
        })
    moon_body = next((b for b in bodies if b["body_id"] == "MOON"), None)
    if moon_body:
        lon = moon_body["ecliptic"]["longitude_deg"]
        out.append({
            "id": "moon_via_combusta",
            "fact_type": "via_combusta",
            "in_interval": 195.0 <= lon < 225.0,
            "interval_deg": {"start": 195.0, "end": 225.0},
            "longitude_deg": _r(lon, 6),
            "rule_id": "via_combusta.libra15_scorpio15.v1",
            "algorithm_version": ALGORITHM,
        })
    sat = next((b for b in bodies if b["body_id"] == "SATURN"), None)
    if sat:
        out.append({
            "id": "saturn_house",
            "fact_type": "saturn_house_placement",
            "integer_house": sat["house"]["integer_house"],
            "in_seventh": sat["house"]["integer_house"] == 7,
            "distance_to_seventh_cusp_deg": next(
                (c["absolute_distance_deg"] for c in (sat.get("accidental") or {}).get("cusp_distances", []) if c["house"] == 7),
                None,
            ),
            "rule_id": "consideration.saturn_seventh.placement.v1",
            "algorithm_version": ALGORITHM,
        })
    # ASC ruler vs hour ruler same
    from astro_backend_core import SIGN_RULERS
    if asc is not None:
        asc_ruler = SIGN_RULERS[zodiac_sign_index(asc)]
        current = planetary.get("current_hour") or planetary.get("current")
        if isinstance(current, dict):
            hour_ruler = current.get("ruler_id")
        out.append({
            "id": "asc_ruler_vs_hour_ruler",
            "fact_type": "ruler_identity",
            "asc_ruler_id": asc_ruler,
            "hour_ruler_id": hour_ruler,
            # null when hour ruler unavailable — avoid false negative same_planet=False
            "same_planet": (None if hour_ruler is None else hour_ruler == asc_ruler),
            "rule_id": "consideration.asc_ruler_hour_ruler.identity.v1",
            "algorithm_version": ALGORITHM,
        })
    out.append({
        "id": "moon_sign_exit",
        "fact_type": "moon_approaching_sign_exit",
        "sign_exit": moon.get("sign_exit"),
        "rule_id": "consideration.moon_sign_exit.v1",
        "algorithm_version": ALGORITHM,
    })
    return out


def _declination_at(dt: datetime, body_id: str, warnings: list[str], sidereal: bool) -> float | None:
    """Equatorial declination at dt via Swiss Ephemeris."""
    if body_id not in BODY_REGISTRY:
        return None
    spec = BODY_REGISTRY[body_id]
    jd = jd_from_datetime(dt)
    flags = swe.FLG_SWIEPH | swe.FLG_EQUATORIAL
    if sidereal:
        flags |= swe.FLG_SIDEREAL
    try:
        values, _ = swe.calc_ut(jd, spec.code, flags)
        dec = float(values[1])
        if body_id in ("SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE"):
            dec = -dec
        return dec
    except Exception as exc:
        warnings.append(f"declination_at {body_id}: {exc}")
        return None


def _declination_root(
    chart_dt: datetime,
    left_id: str,
    right_id: str,
    kind: str,
    warnings: list[str],
    sidereal: bool,
    max_days: float,
    forward: bool,
) -> datetime | None:
    """Coarse search for parallel (da-db=0) or contra (da+db=0)."""
    step_h = 12
    direction = 1 if forward else -1
    t = chart_dt
    end = chart_dt + timedelta(days=max_days * direction)
    prev_t = t
    prev_val = None
    while (forward and t <= end) or (not forward and t >= end):
        da = _declination_at(t, left_id, warnings, sidereal)
        db = _declination_at(t, right_id, warnings, sidereal)
        if da is None or db is None:
            return None
        val = (da - db) if kind == "parallel" else (da + db)
        if prev_val is not None and ((prev_val < 0 <= val) or (prev_val > 0 >= val) or abs(val) < 1e-4):
            # refine
            a_t, b_t = prev_t, t
            for _ in range(24):
                mid = a_t + (b_t - a_t) / 2
                mda = _declination_at(mid, left_id, warnings, sidereal)
                mdb = _declination_at(mid, right_id, warnings, sidereal)
                if mda is None or mdb is None:
                    break
                mval = (mda - mdb) if kind == "parallel" else (mda + mdb)
                if abs(mval) < 1e-5:
                    return mid
                left_a = _declination_at(a_t, left_id, warnings, sidereal)
                left_b = _declination_at(a_t, right_id, warnings, sidereal)
                if left_a is None or left_b is None:
                    break
                lval = (left_a - left_b) if kind == "parallel" else (left_a + left_b)
                if (lval < 0 <= mval) or (lval > 0 >= mval):
                    b_t = mid
                else:
                    a_t = mid
            return a_t + (b_t - a_t) / 2
        prev_val = val
        prev_t = t
        t = t + timedelta(hours=step_h * direction)
    return None


def declination_parallels(
    bodies: list[dict[str, Any]],
    chart_dt: datetime | None = None,
    orb_deg: float = 1.0,
    warnings: list[str] | None = None,
    sidereal: bool = False,
    past_days: float = 30.0,
    future_days: float = 60.0,
) -> dict[str, Any] | list[dict[str, Any]]:
    warnings = warnings if warnings is not None else []
    rows = []
    ids = [b for b in bodies if b.get("equatorial", {}).get("declination_deg") is not None]
    for i, a in enumerate(ids):
        for b in ids[i + 1 :]:
            da = a["equatorial"]["declination_deg"]
            db = b["equatorial"]["declination_deg"]
            # crude declination speeds via ±6h sample when chart_dt provided
            app_par = app_con = "unknown"
            if chart_dt is not None:
                da2 = _declination_at(chart_dt + timedelta(hours=6), a["body_id"], warnings, sidereal)
                db2 = _declination_at(chart_dt + timedelta(hours=6), b["body_id"], warnings, sidereal)
                if da2 is not None and db2 is not None:
                    # parallel converges if |da-db| shrinks
                    now_p = abs(da - db)
                    fut_p = abs(da2 - db2)
                    app_par = "applying" if fut_p < now_p - 1e-6 else ("separating" if fut_p > now_p + 1e-6 else "stationary")
                    now_c = abs(da + db)
                    fut_c = abs(da2 + db2)
                    app_con = "applying" if fut_c < now_c - 1e-6 else ("separating" if fut_c > now_c + 1e-6 else "stationary")
            d_par = abs(da - db)
            d_contra = abs(da + db)
            for kind, dist, app in (
                ("parallel", d_par, app_par),
                ("contra_parallel", d_contra, app_con),
            ):
                prev_exact = next_exact = None
                if chart_dt is not None:
                    prev_exact = _declination_root(
                        chart_dt, a["body_id"], b["body_id"], kind, warnings, sidereal, past_days, forward=False,
                    )
                    next_exact = _declination_root(
                        chart_dt, a["body_id"], b["body_id"], kind, warnings, sidereal, future_days, forward=True,
                    )
                sign_exit_before = {"body_a": False, "body_b": False}
                station_before = False
                if chart_dt is not None and next_exact is not None:
                    warning_keys: set[str] = set()
                    exact_local = next_exact.astimezone(chart_dt.tzinfo) if chart_dt.tzinfo else next_exact.replace(tzinfo=None)
                    sign_exit_before = {
                        "body_a": body_exits_sign_before(
                            chart_dt, exact_local, a["body_id"], warnings, warning_keys, sidereal=sidereal,
                        ),
                        "body_b": body_exits_sign_before(
                            chart_dt, exact_local, b["body_id"], warnings, warning_keys, sidereal=sidereal,
                        ),
                    }
                    # reuse aspect station sampler via speed sign flips
                    from astro_backend_horary_v2_aspects import _station_or_retrograde_before_exact
                    station_before, _ = _station_or_retrograde_before_exact(
                        chart_dt, exact_local, a["body_id"], b["body_id"], warnings, warning_keys, sidereal,
                    )
                rows.append({
                    "id": f"{a['body_id']}|{b['body_id']}|{kind}",
                    "body_a_id": a["body_id"],
                    "body_b_id": b["body_id"],
                    "kind": kind,
                    "declination_a_deg": _r(da, 6),
                    "declination_b_deg": _r(db, 6),
                    "delta_deg": _r(dist, 6),
                    "orb_limit_deg": orb_deg,
                    "within_orb": dist <= orb_deg,
                    "application": app,
                    "previous_exact": {
                        "datetime_utc": _utc(prev_exact),
                        "datetime_local": format_local(prev_exact) if prev_exact else None,
                    } if prev_exact else None,
                    "next_exact": {
                        "datetime_utc": _utc(next_exact),
                        "datetime_local": format_local(next_exact) if next_exact else None,
                    } if next_exact else None,
                    "sign_exit_before_exact": sign_exit_before,
                    "station_or_retrograde_before_exact": station_before,
                    "rule_id": f"declination.{kind}.v2",
                    "algorithm_version": ALGORITHM,
                })
    rows.sort(key=lambda r: r["id"])

    # Moon declination contact sequence (prev/next vs other bodies)
    moon_seq: dict[str, Any] = {
        "body_id": "MOON",
        "previous_contacts": [],
        "next_contacts": [],
        "rule_id": "declination.moon_contact_sequence.v1",
    }
    moon_rows = [r for r in rows if "MOON" in (r["body_a_id"], r["body_b_id"])]
    prev_list = []
    next_list = []
    for r in moon_rows:
        other = r["body_b_id"] if r["body_a_id"] == "MOON" else r["body_a_id"]
        if r.get("previous_exact") and r["previous_exact"].get("datetime_utc"):
            prev_list.append({
                "target_id": other,
                "kind": r["kind"],
                "datetime_utc": r["previous_exact"]["datetime_utc"],
                "contact_id": r["id"],
            })
        if r.get("next_exact") and r["next_exact"].get("datetime_utc"):
            next_list.append({
                "target_id": other,
                "kind": r["kind"],
                "datetime_utc": r["next_exact"]["datetime_utc"],
                "contact_id": r["id"],
            })
    prev_list.sort(key=lambda x: x["datetime_utc"], reverse=True)
    next_list.sort(key=lambda x: x["datetime_utc"])
    moon_seq["previous_contacts"] = prev_list
    moon_seq["next_contacts"] = next_list
    moon_seq["last_contact"] = prev_list[0] if prev_list else None
    moon_seq["next_contact"] = next_list[0] if next_list else None

    # Return list for backward compat; moon sequence attached via wrapper by caller if needed.
    # Store on a synthetic attribute by returning dict when chart_dt provided.
    if chart_dt is not None:
        return {"contacts": rows, "moon_sequence": moon_seq}  # type: ignore[return-value]
    return rows


def antiscia_contacts(
    bodies: list[dict[str, Any]],
    angles: dict[str, float],
    cusps: list[float],
    lots: list[dict[str, Any]],
    orb_deg: float = 1.0,
) -> list[dict[str, Any]]:
    def ant(lon: float) -> float:
        return norm360(180.0 - lon)

    def contra(lon: float) -> float:
        return norm360(360.0 - lon)

    # Primary set: bodies + angles + nodes. Lots/cusps only retained when hit within orb
    # to keep packet size production-friendly.
    primary: list[tuple[str, str, float]] = []
    for b in bodies:
        primary.append((b["body_id"], "body", b["ecliptic"]["longitude_deg"]))
    for k, v in angles.items():
        if k in {"ASC", "MC", "DSC", "IC"}:
            primary.append((k, "angle", v))
    secondary: list[tuple[str, str, float]] = []
    for i, c in enumerate(cusps):
        secondary.append((f"CUSP_{i+1}", "cusp", c))
    for lot in lots:
        secondary.append((lot["id"], "lot", lot["longitude_deg"]))

    rows = []
    # Full matrix among primary points
    for i, (ida, ta, lona) in enumerate(primary):
        ant_a = ant(lona)
        contra_a = contra(lona)
        for idb, tb, lonb in primary[i + 1 :]:
            for kind, target in (("antiscia", ant_a), ("contra_antiscia", contra_a)):
                d = angular_separation(target, lonb)
                rows.append({
                    "id": f"{ida}|{idb}|{kind}",
                    "point_a_id": ida,
                    "point_a_type": ta,
                    "point_b_id": idb,
                    "point_b_type": tb,
                    "kind": kind,
                    "point_a_longitude_deg": _r(lona, 6),
                    "point_a_reflection_deg": _r(target, 6),
                    "point_b_longitude_deg": _r(lonb, 6),
                    "distance_deg": _r(d, 6),
                    "orb_limit_deg": orb_deg,
                    "within_orb": d <= orb_deg,
                    "rule_id": f"antiscia.contact.{kind}.v1",
                    "algorithm_version": ALGORITHM,
                })
        # Primary reflections vs secondary: only keep hits within orb
        for idb, tb, lonb in secondary:
            for kind, target in (("antiscia", ant_a), ("contra_antiscia", contra_a)):
                d = angular_separation(target, lonb)
                if d > orb_deg:
                    continue
                rows.append({
                    "id": f"{ida}|{idb}|{kind}",
                    "point_a_id": ida,
                    "point_a_type": ta,
                    "point_b_id": idb,
                    "point_b_type": tb,
                    "kind": kind,
                    "point_a_longitude_deg": _r(lona, 6),
                    "point_a_reflection_deg": _r(target, 6),
                    "point_b_longitude_deg": _r(lonb, 6),
                    "distance_deg": _r(d, 6),
                    "orb_limit_deg": orb_deg,
                    "within_orb": True,
                    "rule_id": f"antiscia.contact.{kind}.v1",
                    "algorithm_version": ALGORITHM,
                })
    rows.sort(key=lambda r: r["id"])
    return rows


def fixed_star_contacts(
    chart_jd: float,
    bodies: list[dict[str, Any]],
    angles: dict[str, float],
    sidereal: bool,
    warnings: list[str],
) -> dict[str, Any]:
    stars = compute_star_positions(chart_jd, STAR_CATALOG, warnings, sidereal=sidereal)
    contacts = []
    points = [(b["body_id"], "body", b["ecliptic"]["longitude_deg"]) for b in bodies]
    for k in ("ASC", "MC"):
        if k in angles:
            points.append((k, "angle", angles[k]))
    for star in stars:
        slon = star.get("longitude")
        if slon is None:
            continue
        orb = float(star.get("orb") or 1.0)
        for pid, ptype, plon in points:
            d = angular_separation(slon, plon)
            if d <= orb:
                contacts.append({
                    "id": f"star|{star.get('name')}|{pid}",
                    "star_name": star.get("name"),
                    "point_id": pid,
                    "point_type": ptype,
                    "distance_deg": _r(d, 6),
                    "orb_deg": orb,
                    "star_longitude_deg": _r(slon, 6),
                    "star_latitude_deg": _r(star.get("latitude"), 6),
                    "star_ra_deg": _r(star.get("ra") or star.get("right_ascension"), 6),
                    "star_declination_deg": _r(star.get("declination"), 6),
                    "magnitude": star.get("mag"),
                    "catalog_nature": star.get("nature"),
                    "rule_id": "fixed_star.conjunction.catalog_orb.v1",
                    "algorithm_version": ALGORITHM,
                })
    contacts.sort(key=lambda r: r["id"])
    star_rows = []
    for s in stars:
        star_rows.append({
            "name": s.get("name"),
            "longitude_deg": _r(s.get("longitude"), 6),
            "latitude_deg": _r(s.get("latitude"), 6),
            "ra_deg": _r(s.get("ra") or s.get("right_ascension"), 6),
            "declination_deg": _r(s.get("declination"), 6),
            "magnitude": s.get("mag"),
            "default_orb_deg": s.get("orb"),
            "catalog_keyword": s.get("keyword"),
            "source": "Swiss Ephemeris sefstars + STAR_CATALOG",
        })
    star_rows.sort(key=lambda r: r.get("name") or "")
    return {
        "catalog_version": "STAR_CATALOG.traditional_core.v1",
        "stars": star_rows,
        "contacts": contacts,
        "algorithm_version": ALGORITHM,
    }


def enrich_visibility_pheno(
    chart_jd: float,
    visibility_rows: list[dict[str, Any]],
    bodies: list[dict[str, Any]],
    warnings: list[str],
) -> list[dict[str, Any]]:
    by_id = {b["body_id"]: b for b in bodies}
    out = []
    for row in visibility_rows:
        bid = row["body_id"]
        enriched = dict(row)
        if bid == "SUN":
            out.append(enriched)
            continue
        if bid not in BODY_REGISTRY:
            out.append(enriched)
            continue
        try:
            code = BODY_REGISTRY[bid].code
            ph = swe.pheno_ut(chart_jd, code, swe.FLG_SWIEPH)
            # Swiss Ephemeris attr order:
            # [phase angle deg, illuminated fraction, elongation deg,
            #  apparent diameter deg, apparent magnitude].
            enriched["phase_angle_deg"] = _r(ph[0], 6)
            enriched["illumination_fraction"] = _r(ph[1], 6)
            enriched["angular_diameter_arcsec"] = _r(ph[3] * 3600.0, 6)
            enriched["apparent_magnitude"] = _r(ph[4], 4)
            enriched["solar_elongation_deg"] = _r(ph[2], 6)
            enriched["pheno_source"] = "swe.pheno_ut"
        except Exception as exc:
            enriched.setdefault("pheno_reason_code", "pheno_ut_failed")
            warnings.append(f"{bid} pheno_ut: {exc}")
        # visible remains null without atmosphere model
        if enriched.get("visible") is None:
            enriched["visible_reason_code"] = enriched.get("visible_reason_code") or "visibility_model_not_configured"
            enriched["visibility_model_id"] = None
        out.append(enriched)
    return out
