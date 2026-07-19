"""Dodekatemoria, monomoiria, topical almutens. mode=classical_derivatives"""

from __future__ import annotations

from typing import Any

from astro_backend_classical import classical_snapshot
from astro_backend_classical_dignity import SIGN_RULERS as _  # noqa: F401
from astro_backend_classical_dignity import calc_dodekatemorion, dignity_rulers_for_lon
from astro_backend_core import (
    SIGN_RULERS,
    format_longitude,
    moment_to_jd,
    set_zodiac_mode,
    zodiac_sign_index,
)

METHOD = "classical_derivatives_v1"
SCHEMA = 1


def monomoiria_ruler(lon: float) -> str:
    """v1 profile: domicile ruler of the sign containing the degree."""
    return SIGN_RULERS[zodiac_sign_index(lon)]


def calculate_classical_derivatives(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    jd, birth_utc = moment_to_jd(birth["moment"])
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)
    hs = birth.get("houseSystem", birth.get("house_system", "whole_sign"))
    bounds = birth.get("boundsSystem", birth.get("bounds_system", "egyptian"))
    trip = birth.get("triplicitySystem", birth.get("triplicity_system", "dorothean")
    )
    snap = classical_snapshot(
        jd,
        float(birth["latitude"]),
        float(birth["longitude"]),
        hs,
        sidereal,
        bounds,
        trip,
        float(request.get("aspect_orb", 3)),
        warnings,
    )
    planets = snap["planets"]
    angles = snap["angles"]
    dodeka_rows: list[dict[str, Any]] = []
    mono_rows: list[dict[str, Any]] = []

    def add_source(source_id: str, name: str, kind: str, lon: float, house: Any) -> None:
        dlon, dsign_idx, ruler = calc_dodekatemorion(float(lon))
        sign, deg = format_longitude(float(dlon))
        dodeka_rows.append(
            {
                "source_id": source_id,
                "source_name": name,
                "source_kind": kind,
                "natal_longitude": round(float(lon), 9),
                "dodekatemorion_longitude": round(float(dlon), 9),
                "dodekatemorion_sign_index": int(dsign_idx),
                "dodekatemorion_ruler": ruler,
                "sign": sign,
                "degree_text": deg,
                "house": house,
                "method_key": "calc_dodekatemorion",
            }
        )
        mono_rows.append(
            {
                "source_id": source_id,
                "source_name": name,
                "source_kind": kind,
                "longitude": round(float(lon), 9),
                "degree_index": int(float(lon) % 30) + 1,
                "monomoiria_ruler": monomoiria_ruler(float(lon)),
                "method_profile": "sign_domicile_ruler_per_degree_v1",
                "method_key": "monomoiria_domicile_proxy",
            }
        )

    for p in planets:
        add_source(str(p.get("id")), str(p.get("name")), "planet", float(p["longitude"]), p.get("house"))
    for a in angles:
        add_source(str(a.get("id")), str(a.get("name")), "angle", float(a["longitude"]), a.get("house"))
    for lot in snap.get("lots") or []:
        if lot.get("longitude") is None:
            continue
        add_source(str(lot.get("id")), str(lot.get("name")), "lot", float(lot["longitude"]), lot.get("house"))

    topical: list[dict[str, Any]] = []
    for h in snap["houses"]:
        clon = float(h["cusp_longitude"])
        rulers = dignity_rulers_for_lon(clon, snap["is_day"], bounds, trip)
        scores: dict[str, int] = {}
        if isinstance(rulers, dict):
            for _label, ruler in rulers.items():
                if ruler:
                    scores[str(ruler)] = scores.get(str(ruler), 0) + 1
        if not scores:
            scores[SIGN_RULERS[zodiac_sign_index(clon)]] = 1
        winner = max(scores.items(), key=lambda kv: kv[1])
        topical.append(
            {
                "topic_id": f"house_{h['house']}",
                "topic_name": f"House {h['house']} cusp almuten",
                "longitude": round(clon, 9),
                "winner_id": winner[0],
                "winner_score": winner[1],
                "candidates": [
                    {"body_id": b, "score": s}
                    for b, s in sorted(scores.items(), key=lambda x: -x[1])
                ],
                "rulers_detail": rulers if isinstance(rulers, dict) else {},
                "method_key": "topical_almuten_essential_count_v1",
                "note": "Highest essential-dignity contribution count; not an interpretive judgment.",
            }
        )

    contacts: list[dict[str, Any]] = []
    for i, a in enumerate(dodeka_rows):
        for b in dodeka_rows[i + 1 :]:
            if a["sign"] == b["sign"]:
                contacts.append(
                    {
                        "a": a["source_id"],
                        "b": b["source_id"],
                        "relation": "same_sign",
                        "sign": a["sign"],
                        "method_key": "dodeka_sign_based_contact",
                    }
                )

    return {
        "meta": {
            "mode": "classical_derivatives",
            "method": METHOD,
            "schema_version": SCHEMA,
            "birth_utc": birth_utc,
            "ephemeris": "Swiss Ephemeris",
            "dodeka_count": len(dodeka_rows),
            "monomoiria_count": len(mono_rows),
            "topical_count": len(topical),
        },
        "requested_config": {"zodiac": zodiac},
        "effective_config": {
            "zodiac": zodiac,
            "house_system": hs,
            "bounds_system": bounds,
            "triplicity_system": trip,
            "method": METHOD,
            "monomoiria_profile": "sign_domicile_ruler_per_degree_v1",
        },
        "dodekatemoria": dodeka_rows,
        "dodekatemoria_contacts": contacts,
        "monomoiria": mono_rows,
        "topical_almutens": topical,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": None,
        "calculation_assumptions": [
            "Dodekatemorion uses shipped calc_dodekatemorion().",
            "Monomoiria v1 uses domicile ruler of the sign for each degree (explicit proxy profile).",
            "Topical almutens count essential dignity rulers on house cusps; winner is max count.",
            "结果为派生坐标与尊贵贡献事实，非解释结论。",
        ],
    }


__all__ = ["calculate_classical_derivatives"]
