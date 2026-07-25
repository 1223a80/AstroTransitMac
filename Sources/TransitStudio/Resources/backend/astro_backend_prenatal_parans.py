"""Prenatal syzygy packet + fixed-star parans (B18). mode=prenatal_parans"""

from __future__ import annotations

from typing import Any

from astro_backend_classical_audit import calculate_prenatal_syzygy
from astro_backend_core import moment_to_jd, moment_to_local_datetime, set_zodiac_mode, swe
from astro_backend_ephemeris import build_houses, calculate_positions, house_rows, point_row, resolve_bodies
from astro_backend_fixed_stars import compute_star_positions

METHOD = "prenatal_parans_v1"


def calculate_prenatal_parans(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    birth = request["birth"]
    birth_dt = moment_to_local_datetime(birth["moment"])
    jd, birth_utc = moment_to_jd(birth["moment"])
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(str(zodiac), warnings)
    lat = float(birth["latitude"])
    lon = float(birth["longitude"])
    hs = birth.get("houseSystem", birth.get("house_system", "whole_sign"))

    syz = calculate_prenatal_syzygy(jd, birth_dt, warnings, sidereal=sidereal)
    # Build syzygy chart if we have jd
    syz_jd = syz.get("jd") or syz.get("julian_day") or syz.get("exact_jd")
    packet: dict[str, Any] = {"prenatal_syzygy": syz}
    section_errors: dict[str, str] = {}
    if syz_jd:
        try:
            specs = resolve_bodies(
                ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"], [], warnings
            )
            positions = calculate_positions(float(syz_jd), specs, warnings, sidereal=sidereal)
            cusps, angles, label = build_houses(float(syz_jd), lat, lon, hs, sidereal, warnings)
            packet["syzygy_chart"] = {
                "planets": positions,
                "angles": [
                    point_row(aid, aid, angles[aid], cusps)
                    for aid in ("ASC", "MC", "DSC", "IC")
                    if aid in angles
                ],
                "houses": house_rows(cusps),
                "house_system": label,
                "method_key": "syzygy_chart_from_exact_jd",
            }
        except Exception as exc:
            section_errors["syzygy_chart"] = str(exc)
            warnings.append(f"syzygy chart: {exc}")
    else:
        warnings.append("prenatal syzygy payload missing jd; chart packet limited")

    # Fixed-star parans: pair rise times within RA tolerance on birth day
    parans = []
    try:
        stars = compute_star_positions(jd, warnings=warnings, sidereal=sidereal)
        specs = resolve_bodies(["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"], [], warnings)
        planets = calculate_positions(jd, specs, warnings, sidereal=sidereal)
        geopos = (lon, lat, float(birth.get("altitude_m") or 0.0))
        # For each planet and star, get RA; paran proxy if |RA_p - RA_s| small (co-culmination proxy)
        for p in planets:
            try:
                flags = swe.FLG_SWIEPH | swe.FLG_EQUATORIAL
                code = resolve_bodies([p["body_id"]], [], warnings)[0].code
                eq, _ = swe.calc_ut(jd, code, flags)
                pra = float(eq[0])
            except Exception:
                continue
            for st in stars[:40]:
                sra = st.get("ra") or st.get("right_ascension")
                if sra is None:
                    continue
                dra = abs(((float(sra) - pra + 180) % 360) - 180)
                if dra <= float(request.get("paran_ra_orb_deg", 1.0)):
                    pdec = None
                    sdec = st.get("declination") or st.get("dec")
                    try:
                        pdec = float(eq[1]) if len(eq) > 1 else None
                    except Exception:
                        pdec = None
                    ecl_orb = None
                    also_ecliptic = False
                    try:
                        star_lon = st.get("longitude") or st.get("lon")
                        if star_lon is not None and p.get("longitude") is not None:
                            from astro_backend_core import signed_orb

                            ecl_orb = abs(signed_orb(float(p["longitude"]), float(star_lon)))
                            also_ecliptic = ecl_orb <= 1.0
                    except Exception:
                        pass
                    parans.append(
                        {
                            "planet_id": p["body_id"],
                            "planet_name": p["name"],
                            "star_name": st.get("name") or st.get("id"),
                            "planet_ra": round(pra, 6),
                            "star_ra": round(float(sra), 6),
                            "ra_delta_deg": round(dra, 6),
                            "planet_declination": round(pdec, 6) if pdec is not None else None,
                            "star_declination": round(float(sdec), 6) if sdec is not None else None,
                            "event_delta_seconds": None,
                            "also_ecliptic_conjunction": also_ecliptic,
                            "ecliptic_orb": round(ecl_orb, 6) if ecl_orb is not None else None,
                            "coordinate_epoch": "of_date",
                            "position_type": "apparent_equatorial",
                            "paran_class": "approximate_co_culmination",
                            "method_key": "fixed_star_ra_conjunction",
                            "method_key_legacy": "fixed_star_paran_ra_proxy_v1",
                            "proxy": True,
                            "full_paran": False,
                            "note": (
                                "RA co-culmination / fixed_star_ra_conjunction proxy only. "
                                "Not full rise/culmination/set/lower-culmination paran with time deltas."
                            ),
                        }
                    )
    except Exception as exc:
        section_errors["parans"] = str(exc)
        warnings.append(f"parans: {exc}")

    return {
        "meta": {
            "mode": "prenatal_parans",
            "method": METHOD,
            "schema_version": 1,
            "birth_utc": birth_utc,
            "paran_count": len(parans),
            "ephemeris": "Swiss Ephemeris",
        },
        "requested_config": {"paran_ra_orb_deg": request.get("paran_ra_orb_deg", 1.0)},
        "effective_config": {
            "paran_class": "co_culmination_ra_proxy",
            "method": METHOD,
        },
        "prenatal_packet": packet,
        "fixed_star_parans": parans,
        "warnings": list(dict.fromkeys(warnings)),
        "section_errors": section_errors or None,
        "calculation_assumptions": [
            "Prenatal syzygy from calculate_prenatal_syzygy; chart rebuilt at exact jd when available.",
            "Parans v1 use equatorial RA proximity as co-culmination proxy; not full rise/set pairing.",
            "Polar missing events surface as empty lists + warnings.",
        ],
    }


__all__ = ["calculate_prenatal_parans"]
