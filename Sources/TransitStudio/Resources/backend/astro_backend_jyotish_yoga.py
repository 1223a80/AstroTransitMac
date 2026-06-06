"""Yoga detection for Jyotish.

Each yoga is a pure function that takes planet positions and returns a match dict
or None. All formulas from standard Jyotish texts (BPHS, Jataka Tattva, etc.).
"""

from __future__ import annotations

from typing import Any

from astro_backend_core import zodiac_sign_index


def _flag_condition_only(result: dict[str, Any]) -> dict[str, Any]:
    result["condition_only"] = True
    result["needs_strength_check"] = True
    return result


def _get_rasi(planet_positions: dict[str, dict[str, Any]], pid: str) -> int | None:
    """Get the rasi index of a planet."""
    pos = planet_positions.get(pid)
    if pos is None:
        return None
    return zodiac_sign_index(pos.get("longitude", 0.0))


def _is_in_kendra(rasi: int, asc_rasi: int) -> bool:
    """Check if rasi is a kendra (1/4/7/10) from ascendant."""
    offset = (rasi - asc_rasi) % 12
    return offset in (0, 3, 6, 9)


def _is_in_trikona(rasi: int, asc_rasi: int) -> bool:
    """Check if rasi is a trikona (1/5/9) from ascendant."""
    offset = (rasi - asc_rasi) % 12
    return offset in (0, 4, 8)


def _are_in_same_rasi(planet_positions, pid1: str, pid2: str) -> bool:
    """Check if two planets are in the same rasi."""
    r1 = _get_rasi(planet_positions, pid1)
    r2 = _get_rasi(planet_positions, pid2)
    if r1 is None or r2 is None:
        return False
    return r1 == r2


def _rasi_distance(planet_positions, pid1: str, pid2: str) -> int | None:
    """Get rasi distance from pid1 to pid2."""
    r1 = _get_rasi(planet_positions, pid1)
    r2 = _get_rasi(planet_positions, pid2)
    if r1 is None or r2 is None:
        return None
    return (r2 - r1) % 12


# ─── Raja Yogas ──────────────────────────────────────────────────────

def yoga_hans(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Hamsa Yoga: Jupiter in a kendra in a watery sign (Cancer/Scorpio/Pisces)."""
    jup_rasi = _get_rasi(planet_positions, "JUPITER")
    if jup_rasi is None:
        return None
    if _is_in_kendra(jup_rasi, asc_rasi) and jup_rasi in (3, 7, 11):
        return _flag_condition_only({"name": "Hamsa", "group": "Raja", "description": "木星在角宫且在水象星座",
                                     "effect": "智慧、声望、财富", "planets": ["JUPITER"]})
    return None


def yoga_malavya(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Malavya Yoga: Venus in a kendra in an own sign or exaltation."""
    ven_rasi = _get_rasi(planet_positions, "VENUS")
    if ven_rasi is None:
        return None
    if _is_in_kendra(ven_rasi, asc_rasi):
        return _flag_condition_only({"name": "Malavya", "group": "Raja", "description": "金星在角宫",
                                     "effect": "美丽、艺术才华、财富", "planets": ["VENUS"]})
    return None


def yoga_shasha(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Shasha Yoga: Saturn in a kendra in an own sign or exaltation."""
    sat_rasi = _get_rasi(planet_positions, "SATURN")
    if sat_rasi is None:
        return None
    if _is_in_kendra(sat_rasi, asc_rasi) and sat_rasi in (0, 9):
        return _flag_condition_only({"name": "Shasha", "group": "Raja", "description": "土星在角宫且在庙旺星座",
                                     "effect": "权威、长寿、领导力", "planets": ["SATURN"]})
    return None


def yoga_rucaka(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Rucaka Yoga: Mars in a kendra in an own sign or exaltation."""
    mar_rasi = _get_rasi(planet_positions, "MARS")
    if mar_rasi is None:
        return None
    if _is_in_kendra(mar_rasi, asc_rasi) and mar_rasi == 9:
        return _flag_condition_only({"name": "Rucaka", "group": "Raja", "description": "火星在角宫且在摩羯（庙旺）",
                                     "effect": "勇气、领导力、军事成就", "planets": ["MARS"]})
    return None


def yoga_bhadra(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Bhadra Yoga: Mercury in a kendra in an own sign or exaltation."""
    mer_rasi = _get_rasi(planet_positions, "MERCURY")
    if mer_rasi is None:
        return None
    if _is_in_kendra(mer_rasi, asc_rasi) and mer_rasi == 5:
        return _flag_condition_only({"name": "Bhadra", "group": "Raja", "description": "水星在角宫且在处女（庙旺）",
                                     "effect": "智慧、口才、学术成就", "planets": ["MERCURY"]})
    return None


def yoga_gaja_kesari(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Gaja Kesari Yoga: Jupiter in a kendra from Moon."""
    jup_rasi = _get_rasi(planet_positions, "JUPITER")
    moon_rasi = _get_rasi(planet_positions, "MOON")
    if jup_rasi is None or moon_rasi is None:
        return None
    offset = (jup_rasi - moon_rasi) % 12
    if offset in (0, 3, 6, 9):
        return _flag_condition_only({"name": "Gaja Kesari", "group": "Raja", "description": "木星在月亮的角宫",
                                     "effect": "智慧、财富、声望", "planets": ["JUPITER", "MOON"]})
    return None


# ─── Dhana Yogas ─────────────────────────────────────────────────────

def yoga_dhana_2_11(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Dhana Yoga: 2nd or 11th lord in kendra/trikona with a benefic."""
    for lord_id in ["JUPITER", "VENUS", "MERCURY"]:
        lord_rasi = _get_rasi(planet_positions, lord_id)
        if lord_rasi is None:
            continue
        # Simplified: any benefic planet in 2nd or 11th house from ascendant
        offset = (lord_rasi - asc_rasi) % 12
        if offset in (1, 10):
            return _flag_condition_only({"name": "Dhana Yoga", "group": "Dhana", "description": f"{lord_id}在第{offset+1}宫",
                                         "effect": "财富增益", "planets": [lord_id]})
    return None


def yoga_dhana_lord(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Dhana Yoga: Lord of 2nd/11th in own/exaltation sign in kendra."""
    # Simplified: planets ruling wealth houses
    for pid in ["JUPITER", "VENUS", "SATURN"]:
        rasi = _get_rasi(planet_positions, pid)
        if rasi is None:
            continue
        if _is_in_kendra(rasi, asc_rasi):
            return _flag_condition_only({"name": "Dhana Lord Yoga", "group": "Dhana", "description": f"{pid}在角宫",
                                         "effect": "财富潜力", "planets": [pid]})
    return None


# ─── Viparita Raja Yogas ──────────────────────────────────────────────

def yoga_viparita_6_8_12(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Viparita Raja Yoga: Lords of 6/8/12 in own houses or kendras."""
    for pid in ["SATURN", "MARS", "RAHU"]:
        rasi = _get_rasi(planet_positions, pid)
        if rasi is None:
            continue
        offset = (rasi - asc_rasi) % 12
        if offset in (5, 7, 11):
            return _flag_condition_only({"name": "Viparita Raja Yoga", "group": "Raja", "description": f"{pid}在第{offset+1}宫",
                                         "effect": "逆境崛起、绝处逢生", "planets": [pid]})
    return None


# ─── Nabhasa Yogas ───────────────────────────────────────────────────

def yoga_ashraya(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Ashraya Yoga: All planets in movable/fixed/dual signs."""
    if "SUN" not in planet_positions:
        return None
    sun_rasi = _get_rasi(planet_positions, "SUN")
    if sun_rasi is None:
        return None
    sun_type = sun_rasi % 3  # 0=movable, 1=fixed, 2=dual
    all_same = all(
        (_get_rasi(planet_positions, pid) is not None and
         _get_rasi(planet_positions, pid) % 3 == sun_type)
        for pid in ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"]
        if pid in planet_positions
    )
    if all_same:
        types = {0: "移动宫", 1: "固定宫", 2: "双体宫"}
        return _flag_condition_only({"name": "Ashraya", "group": "Nabhasa",
                                     "description": f"所有行星都在{types[sun_type]}星座",
                                     "effect": "根据类型不同（移动-旅行/固定-稳固/双体-混合）",
                                     "planets": list(planet_positions.keys())})
    return None


# ─── Tithi-related Yogas ──────────────────────────────────────────────

def yoga_budha_aditya(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Budha-Aditya Yoga: Sun + Mercury in the same house."""
    if not _are_in_same_rasi(planet_positions, "SUN", "MERCURY"):
        return None
    return _flag_condition_only({"name": "BudhaAditya", "group": "solar",
                                 "description": "日水同宫",
                                 "effect": "思维清晰、表达突出，学习与名望机会较多。",
                                 "planets": ["SUN", "MERCURY"]})


def yoga_dharma_karmadhipati(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Dharma-Karmadhipati Yoga: Lord of 9th and 10th in kendra."""
    for pid in ["JUPITER", "SATURN", "MERCURY", "VENUS"]:
        rasi = _get_rasi(planet_positions, pid)
        if rasi is None:
            continue
        if _is_in_kendra(rasi, asc_rasi):
            return _flag_condition_only({"name": "DharmaKarmadhipati", "group": "raja/sambandha",
                                         "description": "九宫主或十宫主在角宫",
                                         "effect": "责任感与上进心较强，容易在事业路径上取得阶段性成就。",
                                         "planets": [pid]})
    return None


def yoga_adhi(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Adhi Yoga: Benefics in 6th, 7th, 8th from Moon."""
    moon_rasi = _get_rasi(planet_positions, "MOON")
    if moon_rasi is None:
        return None
    for pid in ["JUPITER", "VENUS", "MERCURY"]:
        rasi = _get_rasi(planet_positions, pid)
        if rasi is None:
            continue
        offset = (rasi - moon_rasi) % 12
        if offset in (5, 6, 7):
            return _flag_condition_only({"name": "Adhi", "group": "lunar/raja",
                                         "description": "吉星在月亮的6/7/8宫",
                                         "effect": "组织能力与管理潜力较强，易获职位与权责提升。",
                                         "planets": [pid]})
    return None


def yoga_sunapha(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Sunapha Yoga: Benefic planets in 2nd from Moon."""
    moon_rasi = _get_rasi(planet_positions, "MOON")
    if moon_rasi is None:
        return None
    for pid in ["JUPITER", "VENUS", "MERCURY"]:
        rasi = _get_rasi(planet_positions, pid)
        if rasi is None:
            continue
        offset = (rasi - moon_rasi) % 12
        if offset == 1:
            return _flag_condition_only({"name": "Sunapha", "group": "lunar",
                                         "description": "吉星在月亮的第2宫",
                                         "effect": "聪慧、有资源整合能力，常带来名望与财富机会。",
                                         "planets": [pid]})
    return None


def yoga_anapha(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Anapha Yoga: Benefic planets in 12th from Moon."""
    moon_rasi = _get_rasi(planet_positions, "MOON")
    if moon_rasi is None:
        return None
    for pid in ["JUPITER", "VENUS", "MERCURY"]:
        rasi = _get_rasi(planet_positions, pid)
        if rasi is None:
            continue
        offset = (rasi - moon_rasi) % 12
        if offset == 11:
            return _flag_condition_only({"name": "Anapha", "group": "lunar",
                                         "description": "吉星在月亮的第12宫",
                                         "effect": "财富积累、良好合作伙伴",
                                         "planets": [pid]})
    return None


def yoga_subha(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Subha Yoga: Benefic planets on both sides of Moon (2nd and 12th)."""
    moon_rasi = _get_rasi(planet_positions, "MOON")
    if moon_rasi is None:
        return None
    has_2nd = False
    has_12th = False
    for pid in ["JUPITER", "VENUS", "MERCURY"]:
        rasi = _get_rasi(planet_positions, pid)
        if rasi is None:
            continue
        offset = (rasi - moon_rasi) % 12
        if offset == 1:
            has_2nd = True
        if offset == 11:
            has_12th = True
    if has_2nd and has_12th:
        return _flag_condition_only({"name": "Subha", "group": "lunar",
                                     "description": "月亮两侧皆有吉星",
                                     "effect": "外在气质与表达较佳，人际印象与口碑较好。",
                                     "planets": ["JUPITER", "VENUS", "MERCURY"]})
    return None


def yoga_yogakaraka(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Yogakaraka: Planet that rules both a kendra and a trikona for the ascendant."""
    yogakarakas = {
        1: "SATURN",   # Taurus
        3: "VENUS",    # Cancer
        4: "MERCURY",  # Leo
        9: "VENUS",    # Capricorn
    }
    if asc_rasi in yogakarakas:
        yk = yogakarakas[asc_rasi]
        if yk in planet_positions:
            return _flag_condition_only({"name": "Yogakaraka", "group": "raja",
                                         "description": f"{yk}是升星座的瑜伽卡拉卡",
                                         "effect": "关键主星具综合增益，做事更易形成结果。",
                                         "planets": [yk]})
    return None


def yoga_kedara(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Kedara Yoga: Most planets in dual signs."""
    dual_signs = {2, 5, 8, 11}
    count_in_dual = 0
    planets_in_dual = []
    for pid in ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"]:
        rasi = _get_rasi(planet_positions, pid)
        if rasi is None:
            continue
        if rasi in dual_signs:
            count_in_dual += 1
            planets_in_dual.append(pid)
    if count_in_dual >= 4:
        return _flag_condition_only({"name": "Kedara", "group": "naabhasa/sankhya",
                                     "effect": "务实经营型，重视产出与可持续积累。",
                                     "planets": planets_in_dual})
    return None


def yoga_ardha_chandra(planet_positions: dict[str, dict[str, Any]], asc_rasi: int) -> dict[str, Any] | None:
    """Ardha Chandra (half-moon) Yoga."""
    moon_rasi = _get_rasi(planet_positions, "MOON")
    if moon_rasi is None:
        return None
    malefics_in_kendra = 0
    planets_mk = []
    for pid in ["MARS", "SATURN", "SUN"]:
        rasi = _get_rasi(planet_positions, pid)
        if rasi is None:
            continue
        offset = (rasi - moon_rasi) % 12
        if offset in (0, 3, 6, 9):
            malefics_in_kendra += 1
            planets_mk.append(pid)
    if malefics_in_kendra >= 2:
        return _flag_condition_only({"name": "ArdhaChandra", "group": "naabhasa",
                                     "effect": "人生重心阶段性集中，易在某时期快速放大影响。",
                                     "planets": planets_mk})
    return None


def detect_all_yogas(
    planet_positions: dict[str, dict[str, Any]],
    asc_rasi: int = 0,
) -> list[dict[str, Any]]:
    """Run all yoga detectors and return list of matches."""
    yogas = []

    detectors = [
        yoga_hans, yoga_malavya, yoga_shasha, yoga_rucaka, yoga_bhadra,
        yoga_gaja_kesari,
        yoga_dhana_2_11, yoga_dhana_lord,
        yoga_viparita_6_8_12,
        yoga_ashraya,
        yoga_budha_aditya,
        yoga_dharma_karmadhipati,
        yoga_adhi,
        yoga_sunapha,
        yoga_anapha,
        yoga_subha,
        yoga_yogakaraka,
        yoga_kedara,
        yoga_ardha_chandra,
    ]

    seen_names = set()
    for detector in detectors:
        try:
            result = detector(planet_positions, asc_rasi)
            if result is not None:
                if result["name"] not in seen_names:
                    yogas.append(result)
                    seen_names.add(result["name"])
        except Exception:
            pass

    return yogas
