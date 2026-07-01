"""Extended Arabic Parts (Lots) for TransitStudio.

Implements 53 lots organized into core (7), life (25), career (12),
and spirit/relationship (10) groups.  Derived from Paulus, Bonatti,
Abu Ma'shar, and Lilly.

See ``docs/expansion-002/arabic-parts-expanded.md`` for the full formula table.
"""
from __future__ import annotations

from typing import Any

from astro_backend_classical_dignity import EXALTATION_RULERS
from astro_backend_core import BODY_REGISTRY, SIGN_RULERS, norm360, planet_name, zodiac_sign_index
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


def house_cusp_lon(house: int) -> float:
    """Whole Sign house cusp: 0 degrees of the sign at index (house-1)."""
    return (house - 1) * 30.0


def sign_ruler_lon(ruler_id: str, positions: dict[str, dict[str, Any]]) -> float:
    """Get the ecliptic longitude of a planet by its ID."""
    return positions[ruler_id]["longitude"]


def house_ruler_lon(house: int) -> float:
    """Get the home-position longitude of the ruler of a Whole Sign house.

    The ruler itself may be anywhere in the chart; this returns where it
    would fall if projected to 0° of the sign it rules (used for certain
    lot formulas that reference the house ruler by degree).
    For actual planet longitude, use sign_ruler_lon().
    """
    house_sign = (house - 1) % 12
    ruler_id = SIGN_RULERS[house_sign]
    return house_sign * 30.0 + 0.0  # 0° of the house sign


# ---------------------------------------------------------------------------
# Lot definitions: (lot_id, name, (day_formula_args), (night_formula_args), group, source)
# Each formula is (is_day, method_func, theme_1, theme_2) or None for direct.
# For simplicity we use a lambda-style approach at calc time.
# ---------------------------------------------------------------------------

def _day_night_simple(lot_id: str, name_eng: str, a: str, b: str, group: str, source: str):
    """Factory for lots using ASC + A - B (day) / ASC + B - A (night)."""
    def calc(asc, *pos, is_day):
        p_a = pos[0]
        p_b = pos[1]
        return lot_value(asc, p_a, p_b) if is_day else lot_value(asc, p_b, p_a)
    return (lot_id, name_eng, calc, (a, b), (b, a), group, source)


# Pre-computed extended lot definitions
# Structure: (lot_id, name, calc_fn, day_args, night_args, group, source)
# calc_fn receives (asc, *resolved_args, is_day=bool) → longitude
# day_args/night_args are tuples of arg-specifiers: ("planet:SUN", "lon:45.0", "house:8", etc.)


def _resolve(arg: str, positions: dict[str, dict[str, Any]], asc: float) -> float:
    """Resolve a lot argument specifier into a longitude."""
    if arg.startswith("planet:"):
        pid = arg.split(":", 1)[1]
        return positions[pid]["longitude"]
    if arg.startswith("lon:"):
        return float(arg.split(":", 1)[1])
    if arg.startswith("house:"):
        h = int(arg.split(":", 1)[1])
        return house_cusp_lon(h)
    if arg.startswith("exalt:"):
        return exaltation_lon(asc)
    if arg.startswith("self:"):
        return asc
    return 0.0


def _resolve_args(args: tuple, positions, asc) -> tuple[float, ...]:
    return tuple(_resolve(a, positions, asc) for a in args)


def _make_calc(day_a: str, day_b: str, night_a: str | None = None, night_b: str | None = None):
    """Create a calculator function for ASC + A - B formula."""
    if night_a is None:
        night_a = day_b
    if night_b is None:
        night_b = day_a
    def calc(asc, *pos, is_day):
        if is_day:
            a = _resolve(day_a, pos[0], asc) if len(pos) == 1 else pos[0]
            b = _resolve(day_b, pos[1], asc) if len(pos) == 2 else pos[1]
        else:
            a = _resolve(night_a, pos[0], asc) if len(pos) == 1 else pos[0]
            b = _resolve(night_b, pos[1], asc) if len(pos) == 2 else pos[1]
        return lot_value(asc, a, b)
    return calc


# Build the list of extended lot definitions
# Each: (lot_id, name_cn, name_en, day_formula_str, night_formula_str, group, source, calc_fn, day_args, night_args)

LOT_LIST: list[dict[str, Any]] = []

def reg(
    lot_id: str,
    name_cn: str,
    name_en: str,
    day_f: str,
    night_f: str,
    group: str,
    source: str,
    day_p1: str,
    day_p2: str,
    night_p1: str | None = None,
    night_p2: str | None = None,
    confidence: str = "medium",
):
    """Register one lot definition."""
    if night_p1 is None:
        night_p1 = day_p2
    if night_p2 is None:
        night_p2 = day_p1
    LOT_LIST.append({
        "lot_id": lot_id,
        "name_cn": name_cn,
        "name_en": name_en,
        "day_formula": day_f,
        "night_formula": night_f,
        "group": group,
        "source": source,
        "day_p1": day_p1,
        "day_p2": day_p2,
        "night_p1": night_p1,
        "night_p2": night_p2,
        "confidence": confidence,
    })


# ----- Core: 7 Hermetic lots (already in current code) -----
reg("fortune",    "福点",     "Fortune",     "ASC + Moon - Sun",  "ASC + Sun - Moon",   "core", "Paulus", "planet:MOON", "planet:SUN")
reg("spirit",     "精神点",   "Spirit",      "ASC + Sun - Moon",  "ASC + Moon - Sun",   "core", "Paulus", "planet:SUN", "planet:MOON")
reg("eros",       "爱欲点",   "Eros",        "ASC + Venus - Spirit", "ASC + Spirit - Venus", "core", "Paulus", "planet:VENUS", "spirit")
reg("necessity",  "必然点",   "Necessity",   "ASC + Fortune - Mercury", "ASC + Mercury - Fortune", "core", "Paulus", "fortune", "planet:MERCURY")
reg("courage",    "勇气点",   "Courage",     "ASC + Fortune - Mars", "ASC + Mars - Fortune", "core", "Paulus", "fortune", "planet:MARS")
reg("victory",    "胜利点",   "Victory",     "ASC + Jupiter - Spirit", "ASC + Spirit - Jupiter", "core", "Paulus", "planet:JUPITER", "spirit")
reg("nemesis",    "复仇点",   "Nemesis",     "ASC + Fortune - Saturn", "ASC + Saturn - Fortune", "core", "Paulus", "fortune", "planet:SATURN")

# ----- Life areas (25 lots) -----
reg("basis",      "基础点",   "Basis",       "ASC + Fortune - Spirit",  "ASC + Spirit - Fortune", "life", "Paulus", "fortune", "spirit", confidence="high")
reg("marriage",   "婚姻点",   "Marriage",    "ASC + Venus - Saturn",    "ASC + Saturn - Venus",   "life", "Bonatti", "planet:VENUS", "planet:SATURN",
    confidence="medium", night_p1="planet:SATURN", night_p2="planet:VENUS")
reg("father",     "父亲点",   "Father",      "ASC + Saturn - Sun",      "ASC + Sun - Saturn",     "life", "Lilly", "planet:SATURN", "planet:SUN")
reg("mother",     "母亲点",   "Mother",      "ASC + Moon - Venus",      "ASC + Venus - Moon",     "life", "Lilly", "planet:MOON", "planet:VENUS")
reg("siblings",   "兄弟点",   "Siblings",    "ASC + Jupiter - Saturn",  "ASC + Saturn - Jupiter", "life", "Bonatti", "planet:JUPITER", "planet:SATURN")
reg("friends",    "朋友点",   "Friends",     "ASC + Mercury - Moon",    "ASC + Moon - Mercury",   "life", "Lilly", "planet:MERCURY", "planet:MOON")
reg("enemies",    "敌人点",   "Enemies",     "ASC + Saturn - Mercury",  "ASC + Mercury - Saturn", "life", "Bonatti", "planet:SATURN", "planet:MERCURY")
reg("death",      "死亡点",   "Death",       "ASC + house:8 - Moon",    "ASC + Moon - house:8",   "life", "Bonatti", "house:8", "planet:MOON")
reg("illness",    "疾病点",   "Illness",     "ASC + Mars - Saturn",     "ASC + Saturn - Mars",    "life", "Bonatti", "planet:MARS", "planet:SATURN")
reg("acute_illness", "急病点", "Acute Illness", "ASC + Mars - Moon",   "ASC + Moon - Mars",      "life", "Lilly", "planet:MARS", "planet:MOON")
reg("travel",     "旅行点",   "Travel",      "ASC + house:9 - Jupiter", "ASC + Jupiter - house:9","life", "Bonatti", "house:9", "planet:JUPITER")
reg("captivity",  "牢狱点",   "Captivity",   "ASC + house:12 - Saturn", "ASC + Saturn - house:12","life", "Bonatti", "house:12", "planet:SATURN")
reg("debt",       "债务点",   "Debt",        "ASC + Saturn - Mercury",  "ASC + Mercury - Saturn", "life", "Lilly", "planet:SATURN", "planet:MERCURY")
reg("property",   "不动产点", "Property",    "ASC + house:4 - Saturn",  "ASC + Saturn - house:4",  "life", "Bonatti", "house:4", "planet:SATURN")
reg("inheritance","遗产点",   "Inheritance", "ASC + Moon - Saturn",     "ASC + Saturn - Moon",    "life", "Bonatti", "planet:MOON", "planet:SATURN")
reg("danger",     "危险点",   "Danger",      "ASC + Mercury - Saturn",  "ASC + Saturn - Mercury", "life", "Lilly", "planet:MERCURY", "planet:SATURN")
reg("peril",      "劫难点",   "Peril",       "ASC + house:8 - Saturn",  "ASC + Saturn - house:8",  "life", "Bonatti", "house:8", "planet:SATURN")
reg("lost_objects","失物点",  "Lost Objects","ASC + Moon - Mercury",    "ASC + Mercury - Moon",   "life", "Lilly", "planet:MOON", "planet:MERCURY")
reg("theft",      "盗窃点",   "Theft",       "ASC + Mars - Mercury",    "ASC + Mercury - Mars",   "life", "Bonatti", "planet:MARS", "planet:MERCURY")
reg("murder",     "谋杀点",   "Murder",      "ASC + Mercury - Saturn",  "ASC + Saturn - Mercury", "life", "Bonatti", "planet:MERCURY", "planet:SATURN")
reg("servants",   "仆役点",   "Servants",    "ASC + Mercury - Moon",    "ASC + Moon - Mercury",   "life", "Bonatti", "planet:MERCURY", "planet:MOON")
reg("return",     "归返点",   "Return",      "ASC + Mercury - Saturn",  "ASC + Saturn - Mercury", "life", "AbuMa'shar","planet:MERCURY","planet:SATURN")
reg("water_travel","水路旅行","Water Travel","ASC + lon:105 - Saturn",  "ASC + Saturn - lon:105",  "life", "Bonatti", "lon:105", "planet:SATURN")
reg("happiness",  "幸福点",   "Happiness",   "ASC + Jupiter - Venus",   "ASC + Venus - Jupiter",  "life", "Lilly", "planet:JUPITER", "planet:VENUS")

# ----- Career & status (12 lots) -----
reg("kingship",   "王权点",   "Kingship",    "ASC + Moon - Sun",        "ASC + Sun - Moon",       "career","Bonatti","planet:MOON","planet:SUN")
reg("honor",      "荣誉点",   "Honor",       "ASC + lon:19 - Sun",      "ASC + Sun - lon:19",     "career","Lilly", "lon:19", "planet:SUN")
reg("nobility",   "贵族点",   "Nobility",    "ASC + Jupiter - Moon",    "ASC + Moon - Jupiter",   "career","AbuMa'shar","planet:JUPITER","planet:MOON")
reg("profession", "职业点",   "Profession",  "ASC + Sun - Mercury",     "ASC + Mercury - Sun",    "career","Bonatti","planet:SUN","planet:MERCURY")
reg("magistery",  "权威点",   "Magistery",   "ASC + MC - Sun",          "ASC + Sun - MC",         "career","Bonatti","lon:0","planet:SUN")  # MC at 0° of 10th sign in Whole Sign
reg("dignity",    "尊荣点",   "Dignity",     "ASC + Sun - Saturn",      "ASC + Saturn - Sun",     "career","AbuMa'shar","planet:SUN","planet:SATURN")
reg("fame",       "名声点",   "Fame",        "ASC + Jupiter - Sun",     "ASC + Sun - Jupiter",    "career","Lilly", "planet:JUPITER", "planet:SUN")
reg("success",    "成功点",   "Success",     "ASC + Jupiter - Fortune", "ASC + Fortune - Jupiter","career","Bonatti","planet:JUPITER","fortune")
reg("commerce",   "商业点",   "Commerce",    "ASC + Mercury - Sun",     "ASC + Sun - Mercury",    "career","Lilly", "planet:MERCURY", "planet:SUN")
reg("justice",    "司法点",   "Justice",     "ASC + Jupiter - Mercury", "ASC + Mercury - Jupiter","career","Bonatti","planet:JUPITER","planet:MERCURY")
reg("speculation","投机点",   "Speculation", "ASC + Venus - Jupiter",   "ASC + Jupiter - Venus",  "career","Lilly", "planet:VENUS", "planet:JUPITER")
reg("boldness",   "勇敢点",   "Boldness",    "ASC + Mars - Moon",       "ASC + Moon - Mars",      "career","AbuMa'shar","planet:MARS","planet:MOON")

# ----- Spirit & relationship (10 lots) -----
reg("faith",      "信仰点",   "Faith",       "ASC + Mercury - Moon",    "ASC + Moon - Mercury",   "spirit","Lilly", "planet:MERCURY","planet:MOON")
reg("understanding","理解点","Understanding","ASC + Sun - Mercury",    "ASC + Mercury - Sun",    "spirit","AbuMa'shar","planet:SUN","planet:MERCURY")
reg("reason",     "理性点",   "Reason",      "ASC + Mercury - Moon",    "ASC + Moon - Mercury",   "spirit","Bonatti","planet:MERCURY","planet:MOON")
reg("love_concord","爱和点",  "Love & Concord","ASC + Jupiter - Venus", "ASC + Venus - Jupiter",  "spirit","Lilly", "planet:JUPITER","planet:VENUS")
reg("discord",    "纷争点",   "Discord",     "ASC + Mars - Jupiter",    "ASC + Jupiter - Mars",   "spirit","Bonatti","planet:MARS","planet:JUPITER")
reg("lawsuits",   "诉讼点",   "Lawsuits",    "ASC + Jupiter - Mars",    "ASC + Mars - Jupiter",   "spirit","Lilly", "planet:JUPITER","planet:MARS")
reg("secret_enemies","暗敌点","Secret Enemies","ASC + house:12 - Mercury","ASC + Mercury - house:12","spirit","Bonatti","house:12","planet:MERCURY")
reg("treachery",  "背叛点",   "Treachery",   "ASC + Saturn - Sun",      "ASC + Sun - Saturn",     "spirit","Lilly", "planet:SATURN","planet:SUN")
reg("praise",     "赞誉点",   "Praise",      "ASC + Venus - Jupiter",   "ASC + Jupiter - Venus",  "spirit","Bonatti","planet:VENUS","planet:JUPITER")
reg("piety",      "虔诚点",   "Piety",       "ASC + Jupiter - Mercury", "ASC + Mercury - Jupiter","spirit","AbuMa'shar","planet:JUPITER","planet:MERCURY")

# ----- Legacy experimental lots (adapted from previous code) -----
reg("exaltation_old","擢升度点","Exaltation","ASC + Sun - exalt:ASC","ASC + Moon - exalt:ASC","experimental","Hybrid","exalt:ASC","exalt:ASC")
reg("acquisition_old","获取点","Acquisition","ASC + Spirit - Fortune","ASC + Fortune - Spirit","experimental","Paulus","spirit","fortune")
reg("children_old","子女点(旧)","Children(Old)","ASC + Jupiter - Saturn","ASC + Saturn - Jupiter","experimental","Paulus","planet:JUPITER","planet:SATURN")


def _resolve_lot_ref(ref: str, computed: dict[str, float], positions, asc: float) -> float:
    """Resolve a reference that may be another lot's ID or a ``planet:``/``house:``/etc spec."""
    if ref in computed:
        return computed[ref]
    if ref.startswith("planet:"):
        pid = ref.split(":", 1)[1]
        return positions[pid]["longitude"]
    if ref.startswith("house:"):
        h = int(ref.split(":", 1)[1])
        return house_cusp_lon(h)
    if ref.startswith("lon:"):
        return float(ref.split(":", 1)[1])
    if ref.startswith("exalt:"):
        return exaltation_lon(asc)
    return 0.0


def _formula_text(day_p1: str, day_p2: str, night_p1: str, night_p2: str) -> tuple[str, str, str, str]:
    """Convert specifiers to human-readable formula text."""
    def fmt(spec: str) -> str:
        if spec.startswith("planet:"):
            pid = spec.split(":", 1)[1]
            return planet_name(pid) if planet_name(pid) != pid else pid
        if spec.startswith("house:"):
            return f"House{spec.split(':',1)[1]}"
        if spec.startswith("lon:"):
            return f"{spec.split(':',1)[1]}°"
        if spec.startswith("exalt:"):
            return "ExaltDeg(ASC)"
        if spec.startswith("fortune") or spec.startswith("spirit"):
            return spec.capitalize()
        return spec.capitalize()
    day_f = f"ASC + {fmt(day_p1)} - {fmt(day_p2)}"
    night_f = f"ASC + {fmt(night_p1)} - {fmt(night_p2)}"
    return day_f, night_f


def calculate_lots(
    angles: dict[str, float],
    positions: dict[str, dict[str, Any]],
    cusps: list[float],
    is_day: bool,
    mc: float | None = None,
) -> list[dict[str, Any]]:
    """Calculate all 53 Arabic Parts. Returns a list of dicts with point data.

    The first 7 lots have ``lot_group=main``, the rest are split into
    ``life``, ``career``, ``spirit``, and ``experimental`` groups.
    """
    asc = angles["ASC"]

    # Resolve MC for magistery lot
    mc_lon = mc if mc is not None else house_cusp_lon(10)

    # First pass: compute lots in order (dependencies: earlier lots feed later ones)
    computed: dict[str, float] = {}
    rows: list[dict[str, Any]] = []

    for lot_def in LOT_LIST:
        lid = lot_def["lot_id"]
        name_cn = lot_def["name_cn"]
        name_en = lot_def["name_en"]
        group = lot_def["group"]
        source = lot_def["source"]
        confidence = lot_def["confidence"]

        # Resolve arguments
        p1 = lot_def["day_p1"] if is_day else lot_def["night_p1"]
        p2 = lot_def["day_p2"] if is_day else lot_def["night_p2"]

        # Special handling for magistery (MC-based)
        if lid == "magistery":
            a = mc_lon
            b = _resolve_lot_ref(p2, computed, positions, asc)
            lon = lot_value(asc, a, b)
        else:
            a = _resolve_lot_ref(p1, computed, positions, asc)
            b = _resolve_lot_ref(p2, computed, positions, asc)
            lon = lot_value(asc, a, b)

        computed[lid] = lon

        day_f, night_f = _formula_text(
            lot_def["day_p1"], lot_def["day_p2"],
            lot_def["night_p1"], lot_def["night_p2"],
        )
        used_f = day_f if is_day else night_f
        formula_text = f"昼 {day_f}；夜 {night_f}"

        row = point_row(lid, name_cn, lon, cusps, formula_text, day_f, night_f, used_f)

        # Group and confidence
        row["lot_group"] = group
        row["confidence"] = confidence
        row["source_tradition"] = source

        # Special notes for positional lots
        if lid == "basis":
            row["formula_notes"] = "Paulus Basis: ASC+Fortune-Spirit(day), ASC+Spirit-Fortune(night)"
        elif lid == "marriage":
            row["formula_notes"] = "Day ASC+Venus-Saturn, night ASC+Saturn-Venus (Bonatti)"

        rows.append(row)

    return rows
