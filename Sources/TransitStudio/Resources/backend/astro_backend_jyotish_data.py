"""Data tables and constants for Jyotish (Vedic) astrology calculations.

All data sourced from the Maitreya project (https://github.com/martin-pe/maitreya8)
by Martin Pettau, GPL-licensed, and cross-referenced against standard Jyotish texts.
"""

from __future__ import annotations

from typing import Any

# ─── Nakshatra Constants ─────────────────────────────────────────────

NAKSHATRA_LEN = 360.0 / 27.0   # 13°20'
PADA_LEN = NAKSHATRA_LEN / 4.0  # 3°20'

# Nakshatra lords in sequence (27 nakshatras, repeating every 9)
# Order: Ketu, Venus, Sun, Moon, Mars, Rahu, Jupiter, Saturn, Mercury
NAKSHATRA_LORD_IDS = [
    "KETU", "VENUS", "SUN", "MOON", "MARS", "RAHU", "JUPITER", "SATURN", "MERCURY",
    "KETU", "VENUS", "SUN", "MOON", "MARS", "RAHU", "JUPITER", "SATURN", "MERCURY",
    "KETU", "VENUS", "SUN", "MOON", "MARS", "RAHU", "JUPITER", "SATURN", "MERCURY",
]

# Nakshatra data: (start_longitude, name_zh, name_sa, lord_id)
# Start longitudes are in degrees from 0° Aries
NAKSHATRA_DATA: list[dict[str, Any]] = [
    {"index": 0,  "start": 0.0,           "name_zh": "阿湿毗尼",  "name_sa": "Ashvini",         "lord": "KETU"},
    {"index": 1,  "start": 13.3333333333,  "name_zh": "跋赖尼",   "name_sa": "Bharani",         "lord": "VENUS"},
    {"index": 2,  "start": 26.6666666667,  "name_zh": "鬼宿",     "name_sa": "Krittika",        "lord": "SUN"},
    {"index": 3,  "start": 40.0,           "name_zh": "罗希尼",   "name_sa": "Rohini",          "lord": "MOON"},
    {"index": 4,  "start": 53.3333333333,  "name_zh": "密伽尸罗", "name_sa": "Mrigashira",      "lord": "MARS"},
    {"index": 5,  "start": 66.6666666667,  "name_zh": "阿陀罗",   "name_sa": "Ardra",           "lord": "RAHU"},
    {"index": 6,  "start": 80.0,           "name_zh": "颇勒古尼", "name_sa": "Punarvasu",       "lord": "JUPITER"},
    {"index": 7,  "start": 93.3333333333,  "name_zh": "鬼宿",     "name_sa": "Pushya",          "lord": "SATURN"},
    {"index": 8,  "start": 106.6666666667, "name_zh": "阿沙莱沙", "name_sa": "Ashlesha",        "lord": "MERCURY"},
    {"index": 9,  "start": 120.0,          "name_zh": "摩伽",     "name_sa": "Magha",           "lord": "KETU"},
    {"index": 10, "start": 133.3333333333, "name_zh": "前颇勒古尼","name_sa": "Purva Phalguni",  "lord": "VENUS"},
    {"index": 11, "start": 146.6666666667, "name_zh": "后颇勒古尼","name_sa": "Uttara Phalguni", "lord": "SUN"},
    {"index": 12, "start": 160.0,          "name_zh": "诃斯塔",   "name_sa": "Hasta",           "lord": "MOON"},
    {"index": 13, "start": 173.3333333333, "name_zh": "质多罗",   "name_sa": "Chitra",          "lord": "MARS"},
    {"index": 14, "start": 186.6666666667, "name_zh": "萨伐蒂",   "name_sa": "Swati",           "lord": "RAHU"},
    {"index": 15, "start": 200.0,          "name_zh": "毗萨迦",   "name_sa": "Vishakha",        "lord": "JUPITER"},
    {"index": 16, "start": 213.3333333333, "name_zh": "阿奴罗陀",  "name_sa": "Anuradha",        "lord": "SATURN"},
    {"index": 17, "start": 226.6666666667, "name_zh": "阇耶瑟他",  "name_sa": "Jyeshtha",        "lord": "MERCURY"},
    {"index": 18, "start": 240.0,          "name_zh": "牟罗",     "name_sa": "Mula",            "lord": "KETU"},
    {"index": 19, "start": 253.3333333333, "name_zh": "前阿沙陀",  "name_sa": "Purva Ashadha",   "lord": "VENUS"},
    {"index": 20, "start": 266.6666666667, "name_zh": "后阿沙陀",  "name_sa": "Uttara Ashadha",  "lord": "SUN"},
    {"index": 21, "start": 280.0,          "name_zh": "室罗筏拏",  "name_sa": "Shravana",        "lord": "MOON"},
    {"index": 22, "start": 293.3333333333, "name_zh": "达尼什塔",  "name_sa": "Dhanishtha",      "lord": "MARS"},
    {"index": 23, "start": 306.6666666667, "name_zh": "舍多毗沙",  "name_sa": "Shatabhisha",     "lord": "RAHU"},
    {"index": 24, "start": 320.0,          "name_zh": "前跋达罗",  "name_sa": "Purva Bhadrapada","lord": "JUPITER"},
    {"index": 25, "start": 333.3333333333, "name_zh": "后跋达罗",  "name_sa": "Uttara Bhadrapada","lord": "SATURN"},
    {"index": 26, "start": 346.6666666667, "name_zh": "哩伐底",   "name_sa": "Revati",          "lord": "MERCURY"},
]

# Yoni map (28-nakshatra system, index 21=Abhijit) from Maitreya Nakshatra.cpp
_YONI_MAP_28 = [
    0, 3, 4, 7, 7, 9, 10, 4, 10,
    11, 11, 13, 1, 12, 1, 12, 8, 8,
    9, 5, 6, 6, 5, 2, 0, 2, 13, 3,
]
_YONI_MALE_28 = [
    True, True, False, True, False, False, False, True, True,
    True, False, True, False, False, True, True, False, True,
    True, True, True,
    False,  # Abhijit
    False, False, False, True, False, False,
]

YONI_NAMES = [
    ("Ashva", "马"), ("Mahisha", "水牛"), ("Simha", "狮"), ("Gaja", "象"),
    ("Mesha", "羊"), ("Vanara", "猴"), ("Nakula", "猫鼬"), ("Sarpa", "蛇"),
    ("Mriga", "鹿"), ("Shvana", "狗"), ("Marjara", "猫"), ("Mushaka", "鼠"),
    ("Vyaghra", "虎"), ("Go", "牛"),
]

# Gana map from Maitreya: 0=Deva, 1=Manushya, 2=Rakshasa
_GANA_MAP_27 = [
    0, 1, 2, 1, 0, 1, 0, 0, 2,
    2, 1, 1, 0, 2, 0, 2, 0, 2,
    2, 1, 1, 0, 2, 2, 1, 1, 0,
]
GANA_NAMES = {0: ("Deva", "天"), 1: ("Manushya", "人"), 2: ("Rakshasa", "罗刹")}

# Nadi map from Maitreya: 0=Aadi, 1=Madhya, 2=Antya
_NADI_MAP_27 = [
    0, 1, 2, 2, 1, 0, 0, 1, 2,
    2, 1, 0, 0, 1, 2, 2, 1, 0,
    0, 1, 2, 2, 1, 0, 0, 1, 2,
]
NADI_NAMES = {0: ("Aadi", "始"), 1: ("Madhya", "中"), 2: ("Antya", "终")}


def nakshatra_index_for_longitude(longitude: float) -> int:
    """Return the 0-based Nakshatra index (0-26) for a given longitude."""
    idx = int((longitude % 360.0) // NAKSHATRA_LEN)
    return min(idx, 26)


def nakshatra_for_longitude(longitude: float) -> dict[str, Any]:
    """Return full Nakshatra info for a given longitude."""
    idx = nakshatra_index_for_longitude(longitude)
    nak = NAKSHATRA_DATA[idx]
    lon_norm = longitude % 360.0
    offset = lon_norm - nak["start"]
    pada = int(offset // PADA_LEN) + 1
    pada = min(max(pada, 1), 4)

    return {
        "index": idx,
        "name_zh": nak["name_zh"],
        "name_sa": nak["name_sa"],
        "lord": nak["lord"],
        "pada": pada,
        "start_longitude": nak["start"],
        "end_longitude": nak["start"] + NAKSHATRA_LEN,
    }


def pada_for_longitude(longitude: float) -> int:
    """Return the pada (1-4) for a given longitude."""
    return nakshatra_for_longitude(longitude)["pada"]


def nakshatra_yoni(nak_index_27: int) -> dict[str, Any]:
    """Return Yoni info for a given 27-nakshatra index."""
    nak28 = nak_index_27 if nak_index_27 < 21 else nak_index_27 + 1
    yoni_id = _YONI_MAP_28[nak28]
    name_sa, name_zh = YONI_NAMES[yoni_id]
    is_male = _YONI_MALE_28[nak28]
    return {"id": yoni_id, "name_sa": name_sa, "name_zh": name_zh, "is_male": is_male}


def nakshatra_gana(nak_index_27: int) -> dict[str, Any]:
    """Return Gana info for a given 27-nakshatra index."""
    gana_id = _GANA_MAP_27[nak_index_27]
    name_sa, name_zh = GANA_NAMES[gana_id]
    return {"id": gana_id, "name_sa": name_sa, "name_zh": name_zh}


def nakshatra_nadi(nak_index_27: int) -> dict[str, Any]:
    """Return Nadi info for a given 27-nakshatra index."""
    nadi_id = _NADI_MAP_27[nak_index_27]
    name_sa, name_zh = NADI_NAMES[nadi_id]
    return {"id": nadi_id, "name_sa": name_sa, "name_zh": name_zh}


def nakshatra_tara(birth_nak_index: int, planet_nak_index: int) -> dict[str, Any]:
    """Return Tara relationship between birth nakshatra and planet nakshatra."""
    diff = (planet_nak_index - birth_nak_index) % 27
    tara = diff % 9
    names = ["Janma", "Sampat", "Vipat", "Kshema", "Pratyari",
             "Sadhaka", "Vadha", "Mahendra", "Mitra"]
    effects = ["出生", "丰盛", "灾难", "安乐", "敌对",
               "成就", "伤害", "伟大", "友好"]
    is_benefic = tara in (1, 3, 5, 7)
    return {"tara": tara, "name": names[tara], "effect": effects[tara], "is_benefic": is_benefic}


def nakshatra_rajju(nak_index_27: int) -> dict[str, Any]:
    """Return Rajju info for a given 27-nakshatra index. From Maitreya Nakshatra.cpp."""
    n1 = nak_index_27 % 9
    if n1 < 4:
        return {"type": "aroha", "sub_type": n1,
                "name_sa": ["Kantha", "Hridaya", "Nabhi", "Shira"][n1],
                "name_zh": ["颈", "心", "脐", "头"][n1]}
    elif n1 == 4:
        return {"type": "siro", "sub_type": 4, "name_sa": "Siro", "name_zh": "顶"}
    else:
        st = 8 - n1
        return {"type": "avaroha", "sub_type": st,
                "name_sa": ["Pada", "Janu", "Uru", "Guhya"][st],
                "name_zh": ["足", "膝", "股", "阴"][st]}


def nakshatra_details(longitude: float, moon_nak_index: int | None = None) -> dict[str, Any]:
    """Return comprehensive Nakshatra details for a planet at given longitude."""
    nak = nakshatra_for_longitude(longitude)
    idx = nak["index"]
    result: dict[str, Any] = {
        "nakshatra": nak,
        "yoni": nakshatra_yoni(idx),
        "gana": nakshatra_gana(idx),
        "nadi": nakshatra_nadi(idx),
        "rajju": nakshatra_rajju(idx),
    }
    if moon_nak_index is not None:
        result["tara"] = nakshatra_tara(moon_nak_index, idx)
    return result


# ─── Ayanamsha Mappings ──────────────────────────────────────────────

AYANAMSHA_MAP: dict[str, int] = {
    "lahiri": 1,
    "raman": 3,
    "krishnamurti": 5,
    "yukteshwar": 7,
    "pushya_paksha": 29,
    "revati": 28,
    "citra": 27,
    "suryasiddhanta": 21,
    "fagan_bradley": 0,
    "ss_revati": 25,
    "ss_citra": 26,
}

AYANAMSHA_NAMES: dict[str, str] = {
    "lahiri": "Lahiri",
    "raman": "Raman",
    "krishnamurti": "Krishnamurti",
    "yukteshwar": "Yukteshwar",
    "pushya_paksha": "True Pushya",
    "revati": "True Revati",
    "citra": "True Citra",
    "suryasiddhanta": "Surya Siddhanta",
    "fagan_bradley": "Fagan-Bradley",
    "ss_revati": "SS Revati",
    "ss_citra": "SS Citra",
}

DEFAULT_AYANAMSHA = "lahiri"


# ─── Vedic Planet Constants ──────────────────────────────────────────

VEDIC_PLANET_IDS = ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN", "RAHU", "KETU"]

VEDIC_PLANET_NAMES: dict[str, tuple[str, str]] = {
    "SUN": ("Surya", "太阳"),
    "MOON": ("Chandra", "月亮"),
    "MARS": ("Mangala", "火星"),
    "MERCURY": ("Budha", "水星"),
    "JUPITER": ("Brihaspati", "木星"),
    "VENUS": ("Shukra", "金星"),
    "SATURN": ("Shani", "土星"),
    "RAHU": ("Rahu", "罗睺"),
    "KETU": ("Ketu", "计都"),
}

# Exaltation (Uccha) degrees for each Graha from Maitreya ShadBala.cpp
# Order: SUN, MOON, MERCURY, VENUS, MARS, JUPITER, SATURN, RAHU, KETU
_exaltation_arr = [10.0, 33.0, 165.0, 357.0, 298.0, 95.0, 200.0, 75.0, 255.0]
UCCHA_DEGREES: dict[str, float] = {
    p: _exaltation_arr[i] for i, p in enumerate(VEDIC_PLANET_IDS)
}
NEECHA_DEGREES: dict[str, float] = {
    p: (UCCHA_DEGREES[p] + 180.0) % 360.0 for p in UCCHA_DEGREES
}

# Moolatrikona sign (index) for each planet
# This is the sign where the planet has special dignity (usually part of its own sign)
# Degree subdivisions to be added in V2
MOOLATRIKONA_RASI: dict[str, int] = {
    "SUN": 4,       # Leo (0-20°)
    "MOON": 1,      # Taurus (3-30°)
    "MARS": 0,      # Aries (0-12°)
    "MERCURY": 5,   # Virgo (0-15°)
    "JUPITER": 8,   # Sagittarius (0-10°)
    "VENUS": 6,     # Libra (0-15°)
    "SATURN": 10,   # Aquarius (0-20°)
}

# Natural (Naisargika) friendship table for the classical seven planets.
# -1=self, 0=friend, 1=neutral, 2=enemy
# Rahu/Ketu are intentionally excluded from this canonical table.
NAISARGIKA_FRIENDSHIP: dict[str, dict[str, int]] = {
    "SUN":     {"SUN": -1, "MOON": 0, "MARS": 0, "MERCURY": 1, "JUPITER": 0, "VENUS": 2, "SATURN": 2},
    "MOON":    {"SUN": 0, "MOON": -1, "MARS": 1, "MERCURY": 0, "JUPITER": 1, "VENUS": 1, "SATURN": 1},
    "MARS":    {"SUN": 0, "MOON": 0, "MARS": -1, "MERCURY": 2, "JUPITER": 0, "VENUS": 1, "SATURN": 1},
    "MERCURY": {"SUN": 0, "MOON": 2, "MARS": 1, "MERCURY": -1, "JUPITER": 1, "VENUS": 0, "SATURN": 1},
    "JUPITER": {"SUN": 0, "MOON": 0, "MARS": 0, "MERCURY": 2, "VENUS": 2, "SATURN": 1, "JUPITER": -1},
    "VENUS":   {"SUN": 2, "MOON": 2, "MARS": 1, "MERCURY": 0, "JUPITER": 1, "SATURN": 0, "VENUS": -1},
    "SATURN":  {"SUN": 2, "MOON": 2, "MARS": 2, "MERCURY": 0, "JUPITER": 1, "VENUS": 0, "SATURN": -1},
}

FRIENDSHIP_LABELS = {-1: "self", 0: "friend", 1: "neutral", 2: "enemy"}


def is_planet_friend(planet_a: str, planet_b: str) -> bool:
    """Return True if planet_a considers planet_b a friend."""
    return NAISARGIKA_FRIENDSHIP.get(planet_a, {}).get(planet_b, 1) == 0


def is_planet_enemy(planet_a: str, planet_b: str) -> bool:
    """Return True if planet_a considers planet_b an enemy."""
    return NAISARGIKA_FRIENDSHIP.get(planet_a, {}).get(planet_b, 1) == 2


# ─── Graha Drishti ───────────────────────────────────────────────────

# Every planet aspects 7th house. Special planets have additional aspects.
# offset = (target_rasi - source_rasi) % 12
GRAHA_DRISHTI: dict[str, list[dict[str, Any]]] = {
    "SUN":     [{"offset": 6, "strength": 1.0}],
    "MOON":    [{"offset": 6, "strength": 1.0}],
    "MARS":    [{"offset": 6, "strength": 1.0},
                {"offset": 3, "strength": 0.75},
                {"offset": 7, "strength": 0.75}],
    "MERCURY": [{"offset": 6, "strength": 1.0}],
    "JUPITER": [{"offset": 6, "strength": 1.0},
                {"offset": 4, "strength": 0.75},
                {"offset": 8, "strength": 0.75}],
    "VENUS":   [{"offset": 6, "strength": 1.0}],
    "SATURN":  [{"offset": 6, "strength": 1.0},
                {"offset": 2, "strength": 0.75},
                {"offset": 9, "strength": 0.75}],
    "RAHU":    [{"offset": 6, "strength": 1.0},
                {"offset": 4, "strength": 0.5},
                {"offset": 7, "strength": 0.5},
                {"offset": 2, "strength": 0.25},
                {"offset": 9, "strength": 0.25}],
    "KETU":    [{"offset": 6, "strength": 1.0},
                {"offset": 4, "strength": 0.5},
                {"offset": 7, "strength": 0.5},
                {"offset": 2, "strength": 0.25},
                {"offset": 9, "strength": 0.25}],
}


def get_graha_drishti(aspecting_planet: str, rasi_offset: int) -> float:
    """Return drishti strength (0.0-1.0) for planet aspecting a rasi at given offset."""
    for aspect in GRAHA_DRISHTI.get(aspecting_planet, []):
        if aspect["offset"] == rasi_offset:
            return aspect["strength"]
    return 0.0


# ─── Vimsottari Dasa ─────────────────────────────────────────────────

VIMSOTTARI_LORD_ORDER = ["KETU", "VENUS", "SUN", "MOON", "MARS", "RAHU", "JUPITER", "SATURN", "MERCURY"]

VIMSOTTARI_DURATIONS: dict[str, int] = {
    "KETU": 7,
    "VENUS": 20,
    "SUN": 6,
    "MOON": 10,
    "MARS": 7,
    "RAHU": 18,
    "JUPITER": 16,
    "SATURN": 19,
    "MERCURY": 17,
}

VIMSOTTARI_TOTAL = sum(VIMSOTTARI_DURATIONS.values())  # 120


def vimsottari_dasa_index_for_nakshatra(nak_index: int) -> int:
    """Return 0-based dasa lord index for a given Nakshatra index.
    Starting dasa lord is the nakshatra lord itself.
    """
    return VIMSOTTARI_LORD_ORDER.index(NAKSHATRA_LORD_IDS[nak_index])


def vimsottari_lord_for_nakshatra(nak_index: int) -> str:
    """Return dasa lord ID for a given Nakshatra index."""
    return VIMSOTTARI_LORD_ORDER[vimsottari_dasa_index_for_nakshatra(nak_index)]


# ─── Varga Definitions ───────────────────────────────────────────────

VARGA_DEFINITIONS: list[dict[str, Any]] = [
    {"id": "D1",  "num": 1,   "name_sa": "Rasi",          "name_zh": "本命盘"},
    {"id": "D2",  "num": 2,   "name_sa": "Hora",          "name_zh": "时盘"},
    {"id": "D3",  "num": 3,   "name_sa": "Drekkana",      "name_zh": "三分盘"},
    {"id": "D4",  "num": 4,   "name_sa": "Chaturthamsa",  "name_zh": "四分盘"},
    {"id": "D6",  "num": 6,   "name_sa": "Shashthamsa",   "name_zh": "六分盘"},
    {"id": "D7",  "num": 7,   "name_sa": "Saptamamsa",    "name_zh": "七分盘"},
    {"id": "D8",  "num": 8,   "name_sa": "Ashtamamsa",    "name_zh": "八分盘"},
    {"id": "D9",  "num": 9,   "name_sa": "Navamamsa",     "name_zh": "九分盘"},
    {"id": "D10", "num": 10,  "name_sa": "Dasamsa",       "name_zh": "十分盘"},
    {"id": "D12", "num": 12,  "name_sa": "Dvadasamsa",    "name_zh": "十二分盘"},
    {"id": "D16", "num": 16,  "name_sa": "Shodasamsa",    "name_zh": "十六分盘"},
    {"id": "D20", "num": 20,  "name_sa": "Vimsamsa",      "name_zh": "二十分盘"},
    {"id": "D24", "num": 24,  "name_sa": "Siddhamsa",     "name_zh": "二十四分盘"},
    {"id": "D27", "num": 27,  "name_sa": "Bhamsa",        "name_zh": "二十七分盘"},
    {"id": "D30", "num": 30,  "name_sa": "Trimsamsa",     "name_zh": "三十分盘"},
    {"id": "D40", "num": 40,  "name_sa": "Chatvarimsamsa","name_zh": "四十分盘"},
    {"id": "D45", "num": 45,  "name_sa": "Akshavedamsa",  "name_zh": "四十五分盘"},
    {"id": "D60", "num": 60,  "name_sa": "Shashtiamsa",   "name_zh": "六十分盘"},
]

# Varga groupings for Vimsopaka Bala
SHADVARGA_IDS = ["D1", "D2", "D3", "D9", "D12", "D30"]
SAPTAVARGA_IDS = SHADVARGA_IDS + ["D7"]
DASAVARGA_IDS = SAPTAVARGA_IDS + ["D10", "D16", "D60"]
SHODASAVARGA_IDS = ["D1", "D2", "D3", "D4", "D7", "D9", "D10", "D12",
                    "D16", "D20", "D24", "D27", "D30", "D40", "D45", "D60"]
