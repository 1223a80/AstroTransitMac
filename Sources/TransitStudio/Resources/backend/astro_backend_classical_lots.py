from __future__ import annotations

from typing import Any

from astro_backend_classical_dignity import EXALTATION_RULERS
from astro_backend_core import norm360, zodiac_sign_index
from astro_backend_ephemeris import point_row


def lot_value(asc: float, first: float, second: float) -> float:
    return norm360(asc + first - second)


def exaltation_lon(asc: float) -> float:
    asc_sign = zodiac_sign_index(asc)
    exalt_ruler = EXALTATION_RULERS.get(asc_sign)
    if exalt_ruler is None:
        return asc
    exalt_deg = {"SUN": 19, "MOON": 3, "MERCURY": 15, "VENUS": 27, "MARS": 28, "JUPITER": 15, "SATURN": 21}.get(exalt_ruler, 0)
    return asc_sign * 30.0 + exalt_deg


def calculate_lots(
    angles: dict[str, float],
    positions: dict[str, dict[str, Any]],
    cusps: list[float],
    is_day: bool,
) -> list[dict[str, Any]]:
    asc = angles["ASC"]
    sun = positions["SUN"]["longitude"]
    moon = positions["MOON"]["longitude"]
    mercury = positions["MERCURY"]["longitude"]
    venus = positions["VENUS"]["longitude"]
    mars = positions["MARS"]["longitude"]
    jupiter = positions["JUPITER"]["longitude"]
    saturn = positions["SATURN"]["longitude"]

    fortune = lot_value(asc, moon, sun) if is_day else lot_value(asc, sun, moon)
    spirit = lot_value(asc, sun, moon) if is_day else lot_value(asc, moon, sun)
    eros = lot_value(asc, venus, spirit) if is_day else lot_value(asc, spirit, venus)
    necessity = lot_value(asc, fortune, mercury) if is_day else lot_value(asc, mercury, fortune)
    courage = lot_value(asc, fortune, mars) if is_day else lot_value(asc, mars, fortune)
    victory = lot_value(asc, jupiter, spirit) if is_day else lot_value(asc, spirit, jupiter)
    nemesis = lot_value(asc, fortune, saturn) if is_day else lot_value(asc, saturn, fortune)
    basis = lot_value(asc, asc, moon) if is_day else lot_value(asc, asc, sun)
    exaltation = lot_value(asc, sun, exaltation_lon(asc)) if is_day else lot_value(asc, moon, exaltation_lon(asc))
    acquisition = lot_value(asc, spirit, fortune) if is_day else lot_value(asc, fortune, spirit)
    marriage_man = lot_value(asc, venus, asc) if is_day else lot_value(asc, asc, venus)
    children = lot_value(asc, jupiter, saturn) if is_day else lot_value(asc, saturn, jupiter)

    formula_pairs: dict[str, tuple[str, str]] = {
        "Fortune": ("ASC + Moon - Sun", "ASC + Sun - Moon"),
        "Spirit": ("ASC + Sun - Moon", "ASC + Moon - Sun"),
        "Eros": ("ASC + Venus - Spirit", "ASC + Spirit - Venus"),
        "Necessity": ("ASC + Fortune - Mercury", "ASC + Mercury - Fortune"),
        "Courage": ("ASC + Fortune - Mars", "ASC + Mars - Fortune"),
        "Victory": ("ASC + Jupiter - Spirit", "ASC + Spirit - Jupiter"),
        "Nemesis": ("ASC + Fortune - Saturn", "ASC + Saturn - Fortune"),
        "Basis": ("ASC + ASC - Moon", "ASC + ASC - Sun"),
        "Exaltation": ("ASC + Sun - Exaltation Degree", "ASC + Moon - Exaltation Degree"),
        "Acquisition": ("ASC + Spirit - Fortune", "ASC + Fortune - Spirit"),
        "Marriage": ("ASC + Venus - ASC", "ASC + ASC - Venus"),
        "Children": ("ASC + Jupiter - Saturn", "ASC + Saturn - Jupiter"),
    }

    main_ids = {"fortune", "spirit", "eros", "necessity", "courage", "victory", "nemesis"}

    lot_defs: list[dict[str, Any]] = [
        {"lot_id": "fortune", "name": "Fortune", "lon": fortune},
        {"lot_id": "spirit", "name": "Spirit", "lon": spirit},
        {"lot_id": "eros", "name": "Eros", "lon": eros},
        {"lot_id": "necessity", "name": "Necessity", "lon": necessity},
        {"lot_id": "courage", "name": "Courage", "lon": courage},
        {"lot_id": "victory", "name": "Victory", "lon": victory},
        {"lot_id": "nemesis", "name": "Nemesis", "lon": nemesis},
        {"lot_id": "basis", "name": "Basis", "lon": basis},
        {"lot_id": "exaltation", "name": "Exaltation", "lon": exaltation},
        {"lot_id": "acquisition", "name": "Acquisition", "lon": acquisition},
        {"lot_id": "marriage", "name": "Marriage", "lon": marriage_man},
        {"lot_id": "children", "name": "Children", "lon": children},
    ]

    marriage_note = "Day formula ASC+Venus-ASC always equals Venus position; formula may be incorrect for this tradition"

    rows: list[dict[str, Any]] = []
    for lot in lot_defs:
        name = lot["name"]
        day_f, night_f = formula_pairs[name]
        used = day_f if is_day else night_f
        formula_text = f"昼 {day_f}；夜 {night_f}"
        row = point_row(lot["lot_id"], name, lot["lon"], cusps, formula_text, day_f, night_f, used)
        if lot["lot_id"] in main_ids:
            row["confidence"] = "high"
            row["lot_group"] = "main"
        else:
            row["confidence"] = "low"
            row["lot_group"] = "experimental"
        row["source_tradition"] = "Hellenistic"
        row["method_variant"] = "standard_reverse_chaldaean"
        if lot["lot_id"] == "marriage":
            row["formula_notes"] = marriage_note
        elif lot["lot_id"] == "basis":
            row["formula_notes"] = "Day ASC+ASC-Moon, night ASC+ASC-Sun; attributed to Paulus Alexandrinus"
        elif lot["lot_id"] == "exaltation":
            row["formula_notes"] = "Uses exaltation degree of the Ascendant's exaltation ruler"
        elif lot["lot_id"] == "acquisition":
            row["formula_notes"] = "Day ASC+Spirit-Fortune, night ASC+Fortune-Spirit; Hermetic"
        elif lot["lot_id"] == "children":
            row["formula_notes"] = "Day ASC+Jupiter-Saturn, night ASC+Saturn-Jupiter; attributed to Paulus"
        rows.append(row)
    return rows
