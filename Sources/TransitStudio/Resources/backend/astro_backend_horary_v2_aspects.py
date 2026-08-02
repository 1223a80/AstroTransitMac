"""Horary v2 aspect candidates: compute independent of display orb filter.

All classical-body pairs × Ptolemaic aspects produce candidates.
``display_orb_deg`` only sets ``within_display_orb``; it never gates root search.
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from astro_backend_classical import CLASSICAL_ASPECTS, applying_label, signed_aspect_orb
from astro_backend_core import angular_separation, format_local, norm360
from astro_backend_core import BODY_REGISTRY
from astro_backend_ephemeris import body_speed_at
from astro_backend_horary import (
    ASPECT_NAMES,
    CLASSICAL_ANGLES,
    application_continuity_interruption,
    body_exits_sign_before,
    exact_datetime_result_for_signature,
    next_exact_for_pair,
    previous_exact_for_pair,
)


def _station_or_retrograde_before_exact(
    chart_dt: datetime,
    exact_dt: datetime,
    left_id: str,
    right_id: str,
    warnings: list[str],
    warning_keys: set[str],
    sidereal: bool,
) -> tuple[bool, dict[str, Any]]:
    """Sample speed signs between chart and exact; True if either body stations or flips direction."""
    from datetime import timedelta

    evidence: dict[str, Any] = {
        "body_a": left_id,
        "body_b": right_id,
        "samples": [],
        "rule_id": "aspect.station_or_retrograde_before_exact.speed_sign_sample.v1",
        "algorithm_version": ALGORITHM_VERSION,
    }
    if exact_dt <= chart_dt:
        evidence["reason_code"] = "exact_not_after_chart"
        return False, evidence

    span = (exact_dt - chart_dt).total_seconds()
    # up to 12 samples along the interval
    steps = max(2, min(12, int(span / 86400.0) + 2))
    flipped = False
    for body_id in (left_id, right_id):
        if body_id in {"SUN", "MOON"}:
            continue
        spec = BODY_REGISTRY.get(body_id)
        if spec is None:
            continue
        prev_sign = None
        body_samples = []
        for i in range(steps + 1):
            t = chart_dt + (exact_dt - chart_dt) * (i / steps)
            sp = body_speed_at(t, spec, warnings, warning_keys, sidereal=sidereal)
            if sp is None:
                continue
            speed = sp[0]
            sign = 0 if abs(speed) < 1e-6 else (1 if speed > 0 else -1)
            body_samples.append({"offset_s": int((t - chart_dt).total_seconds()), "speed": round(speed, 8), "sign": sign})
            if prev_sign is not None and sign != 0 and prev_sign != 0 and sign != prev_sign:
                flipped = True
            if sign != 0:
                prev_sign = sign
        evidence["samples"].append({"body_id": body_id, "points": body_samples})
    evidence["detected"] = flipped
    return flipped, evidence

ALGORITHM_VERSION = "horary-v2.1-aspects-2026-07"
ASPECT_EN = {
    "合相": "conjunction",
    "六合": "sextile",
    "刑相": "square",
    "拱相": "trine",
    "冲相": "opposition",
}


def _r(v: float | None, digits: int = 8) -> float | None:
    if v is None:
        return None
    return round(float(v), digits)


def pair_key(a: str, b: str) -> str:
    left, right = sorted((a, b))
    return f"{left}|{right}"


def application_state(
    lon_a: float,
    spd_a: float,
    lon_b: float,
    spd_b: float,
    angle: float,
) -> tuple[str, dict[str, Any]]:
    signed = signed_aspect_orb(lon_a, lon_b, angle)
    rel = spd_a - spd_b
    if abs(signed) < 1e-9:
        label = "applying"
        zh = "入相"
    elif abs(rel) < 1e-12:
        label = "separating"
        zh = "离相"
    else:
        zh = "入相" if signed * rel < 0 else "离相"
        label = "applying" if zh == "入相" else "separating"
    return label, {
        "signed_orb_deg": _r(signed, 8),
        "absolute_orb_deg": _r(abs(signed), 8),
        "relative_speed_deg_per_day": _r(rel, 8),
        "method": "signed_orb_times_relative_speed",
        "label_zh": zh,
        "rule_id": "application.signed_orb_relative_speed.v1",
        "algorithm_version": ALGORITHM_VERSION,
    }


def build_aspect_candidates(
    chart_dt: datetime,
    bodies: list[dict[str, Any]],
    display_orb_deg: float,
    warnings: list[str],
    sidereal: bool,
    event_past_days: float = 4.0,
    event_future_days: float = 30.0,
    body_filter: set[str] | None = None,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """Return (pairwise_geometry, aspect_candidates).

    ``aspect_candidates`` includes every pair×Ptolemaic aspect for dynamic bodies,
    regardless of whether absolute orb is within ``display_orb_deg``.
    """
    dyn = [
        b
        for b in bodies
        if b["body_id"] not in {"ASC", "MC", "DSC", "IC"}
        and (body_filter is None or b["body_id"] in body_filter)
    ]
    # Prefer classical seven for Ptolemaic perfection search; include nodes if present
    # but only classical seven for full 5-aspect matrix by default.
    ids = [b["body_id"] for b in dyn]
    by_id = {b["body_id"]: b for b in dyn}
    classical = [i for i in ids if i in {"SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"}]
    search_ids = classical if classical else ids

    geometry_rows: list[dict[str, Any]] = []
    candidates: list[dict[str, Any]] = []
    warning_keys: set[str] = set()

    for i, left_id in enumerate(search_ids):
        for right_id in search_ids[i + 1 :]:
            left = by_id[left_id]
            right = by_id[right_id]
            lon_a = float(left["ecliptic"]["longitude_deg"])
            lon_b = float(right["ecliptic"]["longitude_deg"])
            spd_a = float(left["ecliptic"].get("longitude_speed_deg_per_day") or 0.0)
            spd_b = float(right["ecliptic"].get("longitude_speed_deg_per_day") or 0.0)
            raw_sep = norm360(lon_b - lon_a)
            min_sep = angular_separation(lon_a, lon_b)
            rel_speed = spd_a - spd_b

            nearest = None
            nearest_delta = None
            for zh_name, angle in CLASSICAL_ASPECTS.items():
                delta = abs(min_sep - angle)
                if nearest_delta is None or delta < nearest_delta:
                    nearest_delta = delta
                    app_lab, app_ev = application_state(lon_a, spd_a, lon_b, spd_b, angle)
                    nearest = {
                        "aspect_id": ASPECT_EN[zh_name],
                        "aspect_angle_deg": angle,
                        "delta_to_aspect_deg": _r(delta, 8),
                        "within_display_orb": delta <= display_orb_deg,
                        "application": app_lab,
                    }

            # Converging uses true relative motion on nearest aspect — NOT display orb.
            if nearest is not None:
                motion = "converging" if nearest["application"] == "applying" else "diverging"
            else:
                motion = "unknown"

            geometry_rows.append({
                "id": pair_key(left_id, right_id),
                "entity_types": ["body", "body"],
                "body_a_id": left_id,
                "body_b_id": right_id,
                "raw_separation_deg": _r(raw_sep, 8),
                "minimum_separation_deg": _r(min_sep, 8),
                "relative_speed_deg_per_day": _r(rel_speed, 8),
                "motion_direction": motion,
                "deltas_to_aspect_angles": [
                    {
                        "aspect_id": ASPECT_EN[name],
                        "angle_deg": ang,
                        "delta_deg": _r(abs(min_sep - ang), 8),
                    }
                    for name, ang in sorted(CLASSICAL_ASPECTS.items(), key=lambda kv: kv[1])
                ],
                "nearest_aspect": nearest,
                "display_orb_deg": display_orb_deg,
                "geometry_type": "zodiacal",
                "algorithm_version": ALGORITHM_VERSION,
            })

            fake_a = {"id": left_id, "name": left.get("names", {}).get("zh", left_id), "longitude": lon_a, "speed": spd_a}
            fake_b = {"id": right_id, "name": right.get("names", {}).get("zh", right_id), "longitude": lon_b, "speed": spd_b}

            for zh_name, angle in CLASSICAL_ASPECTS.items():
                abs_orb = abs(min_sep - angle)
                app_lab, app_ev = application_state(lon_a, spd_a, lon_b, spd_b, angle)
                # Always attempt root for applying candidates; also for separating store previous.
                signature = (zh_name, "degree", abs_orb, app_ev["label_zh"], "degree-based aspect")
                exact_dt, reason = exact_datetime_result_for_signature(
                    chart_dt, fake_a, fake_b, signature, warnings, sidereal=sidereal,
                )
                # When separating at chart, still try next root without applying
                # gate for event timeline — but validate it the same way applying
                # roots are: sign exit and application continuity (refranation).
                if exact_dt is None and app_lab == "separating":
                    nxt = next_exact_for_pair(
                        chart_dt, left_id, right_id, angle, warnings, warning_keys,
                        max_days=int(event_future_days) + 1, step_hours=6, sidereal=sidereal,
                    )
                    if nxt is None:
                        reason = reason or "no_future_root"
                    else:
                        interruption = application_continuity_interruption(
                            chart_dt, nxt, fake_a, fake_b, angle,
                            warnings, warning_keys, sidereal,
                        )
                        if interruption is not None:
                            reason = interruption
                        elif body_exits_sign_before(
                            chart_dt, nxt, left_id, warnings, warning_keys, sidereal=sidereal
                        ) or body_exits_sign_before(
                            chart_dt, nxt, right_id, warnings, warning_keys, sidereal=sidereal
                        ):
                            reason = "sign exit before perfection while separating"
                        else:
                            exact_dt = nxt
                            reason = "future_root_found_while_separating_at_query"

                prev_exact = previous_exact_for_pair(
                    chart_dt, left_id, right_id, angle, warnings, warning_keys,
                    max_days=int(event_past_days) + 1, step_hours=6, sidereal=sidereal,
                )
                left_exit = right_exit = False
                station_before = False
                station_evidence: dict[str, Any] = {
                    "body_a": None,
                    "body_b": None,
                    "rule_id": "aspect.station_or_retrograde_before_exact.speed_sign_sample.v1",
                }
                if exact_dt is not None:
                    left_exit = body_exits_sign_before(
                        chart_dt, exact_dt, left_id, warnings, warning_keys, sidereal=sidereal
                    )
                    right_exit = body_exits_sign_before(
                        chart_dt, exact_dt, right_id, warnings, warning_keys, sidereal=sidereal
                    )
                    station_before, station_evidence = _station_or_retrograde_before_exact(
                        chart_dt, exact_dt, left_id, right_id, warnings, warning_keys, sidereal,
                    )
                refranation = bool(reason and str(reason).startswith("refranation"))
                aspect_id = ASPECT_EN[zh_name]
                within = abs_orb <= display_orb_deg
                # Degrees to exact (signed toward aspect)
                signed = app_ev["signed_orb_deg"]
                candidates.append({
                    "id": f"{pair_key(left_id, right_id)}|{aspect_id}",
                    "entity_types": ["body", "body"],
                    "body_a_id": left_id,
                    "body_b_id": right_id,
                    "aspect_id": aspect_id,
                    "aspect_angle_deg": angle,
                    "signed_orb_deg": signed,
                    "absolute_orb_deg": _r(abs_orb, 8),
                    "orb_deg": _r(abs_orb, 8),  # alias for consumers
                    "relative_speed_deg_per_day": app_ev["relative_speed_deg_per_day"],
                    "display_orb_deg": display_orb_deg,
                    "within_display_orb": within,
                    "within_orb": within,  # legacy alias = display filter only
                    "application": app_lab,
                    "application_evidence": app_ev,
                    "degrees_to_exact": signed,
                    "previous_exact": {
                        "datetime_local": format_local(prev_exact) if prev_exact else None,
                        "datetime_utc": prev_exact.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if prev_exact else None,
                    } if prev_exact else None,
                    "next_exact": {
                        "datetime_local": format_local(exact_dt) if exact_dt else None,
                        "datetime_utc": exact_dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ") if exact_dt else None,
                        "root_status": "found" if exact_dt else "not_found",
                        "root_reason": reason,
                    },
                    "sign_exit_before_exact": {"body_a": left_exit, "body_b": right_exit},
                    "station_or_retrograde_before_exact": station_before,
                    "station_or_retrograde_evidence": station_evidence,
                    "refranation_detected": refranation,
                    "will_perfect_in_window": False,  # filled below
                    "geometry_type": "zodiacal",
                    "rule_id": "aspect.ptolemaic.candidate.v2",
                    "algorithm_version": ALGORITHM_VERSION,
                })

    # Fix will_perfect_in_window more carefully
    from datetime import timedelta
    window_end = chart_dt + timedelta(days=event_future_days)
    for c in candidates:
        ne = c.get("next_exact") or {}
        utc = ne.get("datetime_utc")
        perfect = False
        if utc:
            try:
                exact = datetime.strptime(utc, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
                if chart_dt.tzinfo:
                    exact = exact.astimezone(chart_dt.tzinfo)
                perfect = chart_dt < exact <= window_end
            except ValueError:
                perfect = False
        c["will_perfect_in_window"] = perfect

    geometry_rows.sort(key=lambda r: r["id"])
    candidates.sort(key=lambda r: r["id"])
    return geometry_rows, candidates


def aspect_exact_events_from_candidates(
    chart_dt: datetime,
    candidates: list[dict[str, Any]],
    past_days: float,
    future_days: float,
) -> list[dict[str, Any]]:
    """Build aspect_exact events from full candidates (not display-filtered)."""
    from datetime import timedelta

    window_start = chart_dt - timedelta(days=past_days)
    window_end = chart_dt + timedelta(days=future_days)
    events: list[dict[str, Any]] = []
    for c in candidates:
        for key in ("previous_exact", "next_exact"):
            info = c.get(key)
            if not info or not info.get("datetime_utc"):
                continue
            try:
                exact = datetime.strptime(info["datetime_utc"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
                if chart_dt.tzinfo:
                    exact = exact.astimezone(chart_dt.tzinfo)
            except ValueError:
                continue
            if not (window_start <= exact <= window_end):
                continue
            utc = exact.astimezone(timezone.utc)
            chart_utc = chart_dt.astimezone(timezone.utc)
            events.append({
                "id": f"aspect_exact|{c['body_a_id']}|{c['body_b_id']}|{c['aspect_id']}|{utc.strftime('%Y%m%dT%H%M%SZ')}",
                "event_type": "aspect_exact",
                "body_ids": [c["body_a_id"], c["body_b_id"]],
                "aspect_id": c["aspect_id"],
                "datetime_utc": utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "datetime_local": format_local(exact),
                "offset_seconds_from_query": int((utc - chart_utc).total_seconds()),
                "candidate_id": c["id"],
                "within_display_orb_at_query": c.get("within_display_orb"),
                "application_at_query": c.get("application"),
                "rule_id": "event.aspect_exact.from_candidates.v2",
                "algorithm_version": ALGORITHM_VERSION,
                "in_configured_window": True,
            })
    # unique by id
    uniq = {e["id"]: e for e in events}
    return sorted(uniq.values(), key=lambda e: (e["offset_seconds_from_query"], e["id"]))
