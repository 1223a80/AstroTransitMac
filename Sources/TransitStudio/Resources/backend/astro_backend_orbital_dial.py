"""Orbital nodes/apsides + dial/planetary pictures (B19). mode=orbital_dial"""

from __future__ import annotations

from typing import Any

from astro_backend_core import (
    circular_midpoint,
    format_longitude,
    moment_to_jd,
    set_zodiac_mode,
    swe,
)
from astro_backend_ephemeris import calculate_positions, resolve_bodies

METHOD = "orbital_dial_v1"


def calculate_orbital_dial(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    jd, birth_utc = moment_to_jd(birth["moment"])
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)
    body_ids = request.get("body_ids") or ["MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]
    modulus = int(request.get("modulus") or 90)
    if modulus not in (45, 90, 360):
        raise ValueError("modulus must be 45, 90, or 360")

    orbital_points = []
    for body_id in body_ids:
        specs = resolve_bodies([body_id], [], warnings)
        if not specs:
            continue
        spec = specs[0]
        try:
            # nod_aps_ut: default flags without FLG_HELCTR yield geocentric ecliptic positions
            # of orbital nodes/apsides (Swiss Ephemeris docs). Label coordinate_center accordingly.
            if hasattr(swe, "nod_aps_ut"):
                nod_flags = swe.FLG_SWIEPH
                if sidereal:
                    nod_flags |= swe.FLG_SIDEREAL
                ret = swe.nod_aps_ut(jd, spec.code, swe.NODBIT_MEAN, nod_flags)
                # typically (xnasc, xndsc, xperi, xaphe)
                if isinstance(ret, tuple) and len(ret) >= 4:
                    for label, arr in (
                        ("north_node", ret[0]),
                        ("south_node", ret[1]),
                        ("perihelion", ret[2]),
                        ("aphelion", ret[3]),
                    ):
                        lon = float(arr[0]) if hasattr(arr, "__getitem__") else float(arr)
                        sign, deg = format_longitude(lon)
                        orbital_points.append(
                            {
                                "body_id": body_id,
                                "point_kind": label,
                                "longitude": round(lon, 9),
                                "sign": sign,
                                "degree_text": deg,
                                "method_key": "swe.nod_aps_ut_mean",
                                "coordinate_center": "geocentric",
                                "coordinate_system": "sidereal_ecliptic" if sidereal else "tropical_ecliptic",
                                "node_method": "NODBIT_MEAN",
                                "se_flags": "FLG_SWIEPH" + ("|FLG_SIDEREAL" if sidereal else ""),
                            }
                        )
            else:
                warnings.append("nod_aps_ut unavailable")
        except Exception as exc:
            warnings.append(f"orbital points {body_id}: {exc}")

    # Dial / planetary pictures on geocentric positions
    specs = resolve_bodies(list(body_ids), [], warnings)
    positions = calculate_positions(jd, specs, warnings, sidereal=sidereal)
    dial_hits = []
    for i, a in enumerate(positions):
        for b in positions[i + 1 :]:
            mid = circular_midpoint(float(a["longitude"]), float(b["longitude"]))
            # fold to modulus
            folded = mid % modulus
            dial_hits.append(
                {
                    "point_a": a["body_id"],
                    "point_b": b["body_id"],
                    "midpoint_longitude": round(mid, 9),
                    "modulus": modulus,
                    "folded_position": round(folded, 9),
                    "picture": f"{a['body_id']}/{b['body_id']}",
                    "method_key": f"circular_midpoint_mod_{modulus}",
                }
            )
            # A = B/C style: C near circular midpoint(A,B)
            for c in positions:
                if c["body_id"] in {a["body_id"], b["body_id"]}:
                    continue
                target = mid
                orb = abs(((float(c["longitude"]) - target + 180) % 360) - 180)
                if orb <= float(request.get("picture_orb", 1.0)):
                    dial_hits.append(
                        {
                            "point_a": c["body_id"],
                            "point_b": a["body_id"],
                            "point_c": b["body_id"],
                            "picture": f"{c['body_id']} = {a['body_id']}/{b['body_id']}",
                            "orb": round(orb, 6),
                            "modulus": modulus,
                            "method_key": f"planetary_picture_mod_{modulus}",
                        }
                    )

    return {
        "meta": {
            "mode": "orbital_dial",
            "method": METHOD,
            "schema_version": 1,
            "birth_utc": birth_utc,
            "modulus": modulus,
            "orbital_point_count": len(orbital_points),
            "dial_hit_count": len(dial_hits),
            "ephemeris": "Swiss Ephemeris",
        },
        "requested_config": {
            "body_ids": body_ids,
            "modulus": request.get("modulus"),
            "picture_orb": request.get("picture_orb", 1.0),
        },
        "effective_config": {
            "modulus": modulus,
            "picture_orb": float(request.get("picture_orb", 1.0)),
            "method": METHOD,
        },
        "orbital_points": orbital_points,
        "dial_pictures": dial_hits,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": None,
        "calculation_assumptions": [
            f"Dial modulus={modulus} (45/90/360 allowed).",
            "Planetary pictures: C near circular_midpoint(A,B) within picture_orb.",
            "Orbital nodes/apsides from swe.nod_aps_ut(NODBIT_MEAN) without FLG_HELCTR → geocentric ecliptic.",
            "No Uranian hypothetical planets.",
        ],
    }


__all__ = ["calculate_orbital_dial"]
