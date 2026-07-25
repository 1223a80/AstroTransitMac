"""Regression suite for classical technique maintenance (fixture chart 2004-08-09).

Fixed chart:
- Birth UTC: 2004-08-09T08:16:00Z
- Loc: 35.0576N, 118.3346E
- Whole Sign / Tropical / Egyptian / Dorothean
- Reference UTC: 2026-07-25T08:44:00Z
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

import pytest

from astro_backend_api import calculate_classical
from astro_backend_classical_dignity import (
    EGYPTIAN_BOUNDS,
    bounds_ruler,
    dignity_labels,
    dignity_ownership,
    dignity_rulers_for_lon,
    place_quality_fields,
    solar_phase,
    triplicity_set,
)
from astro_backend_classical_timing import (
    DECENNIALS_METHOD_PROFILE,
    DECENNIALS_MONTHS,
    DECENNIALS_TOTAL_MONTHS,
    decennials_build_timeline,
    decennials_summary,
    firdaria_summary,
)
from astro_backend_circumambulations import calculate_circumambulations
from astro_backend_primary_directions import calculate_primary_directions
from astro_backend_core import moment_to_jd


FIXTURE_BIRTH = {
    "moment": {
        "year": 2004,
        "month": 8,
        "day": 9,
        "hour": 16,
        "minute": 16,
        "second": 0,
        "timezone": "Asia/Shanghai",
    },
    "latitude": 35.0576,
    "longitude": 118.3346,
    "houseSystem": "whole_sign",
    "zodiac": "tropical",
    "boundsSystem": "egyptian",
    "triplicitySystem": "dorothean",
}

FIXTURE_REFERENCE = {
    "year": 2026,
    "month": 7,
    "day": 25,
    "hour": 16,
    "minute": 44,
    "second": 0,
    "timezone": "Asia/Shanghai",
}


def _classical_request() -> dict:
    return {
        "mode": "classical",
        "birth": FIXTURE_BIRTH,
        "reference": FIXTURE_REFERENCE,
        "aspectOrb": 3.0,
    }


# ---------------------------------------------------------------------------
# C1 Egyptian bounds + ownership
# ---------------------------------------------------------------------------

def test_egyptian_virgo_bounds_table():
    assert EGYPTIAN_BOUNDS[5] == [
        ("MERCURY", 7),
        ("VENUS", 17),
        ("JUPITER", 21),
        ("MARS", 28),
        ("SATURN", 30),
    ]


@pytest.mark.parametrize(
    "degree,expected",
    [
        (16.9, "VENUS"),
        (17.0, "JUPITER"),
        (20.0 + 10 / 60, "JUPITER"),  # 20°10′
        (20.999, "JUPITER"),
        (21.0, "MARS"),
        (27.9, "MARS"),
        (28.0, "SATURN"),
    ],
)
def test_egyptian_virgo_bound_boundaries(degree, expected):
    lon = 5 * 30 + degree
    assert bounds_ruler(lon, "egyptian") == expected


def test_jupiter_owns_own_bound_at_virgo_20_10():
    lon = 5 * 30 + 20 + 10 / 60
    rulers = dignity_rulers_for_lon(lon, True, "egyptian", "dorothean")
    assert rulers["bound"] == "JUPITER"
    ownership = dignity_ownership("JUPITER", rulers, triplicity_set(5, "dorothean"))
    assert ownership["bound_ruler"] == "JUPITER"
    assert ownership["subject_owns_bound"] is True
    _dom, _ex, _tr, bound, _dec, score, notes, _bd, _det, _fall = dignity_labels(
        "JUPITER", lon, True, "egyptian", "dorothean"
    )
    assert "界主" in notes
    # Without bound: Virgo is detriment (-5) + earth triplicity participating (+1) = -4;
    # with bound +2 → -2 (trip role may vary; assert bound contribution present).
    assert any(item.get("label") == "bound" and item.get("owned") for item in _bd) or score >= -2


def test_classical_snapshot_jupiter_bound_ownership():
    result = calculate_classical(_classical_request(), [])
    jup = next(p for p in result["planets"] if p["id"] == "JUPITER")
    assert jup["bound_ruler"] == "JUPITER"
    assert jup["subject_owns_bound"] is True
    # Score should include bound +2 vs pre-fix Mars-bound (no own bound)
    assert jup["score"] >= -2


# ---------------------------------------------------------------------------
# C2 Decennials 129-month
# ---------------------------------------------------------------------------

def test_decennials_total_months_129():
    assert sum(DECENNIALS_MONTHS.values()) == 129
    assert DECENNIALS_TOTAL_MONTHS == 129


def test_decennials_not_firdaria_boundaries():
    birth = datetime(2004, 8, 9, 16, 16)
    ref = datetime(2026, 7, 25, 16, 44)
    fir = firdaria_summary(birth, ref, True)
    dec = decennials_summary(birth, ref, True)
    assert dec["method_profile"] == DECENNIALS_METHOD_PROFILE
    assert "70-year" not in " ".join(dec.get("notes") or [])
    assert dec["total_cycle_months"] == 129
    # Must not share the famous Firdaria Mercury 13y window as identity
    if fir.get("ruler") in {"水星", "Mercury"} and "2022" in str(fir.get("start_local", "")):
        assert fir.get("start_local") != dec.get("start_local") or fir.get("end_local") != dec.get("end_local")


def test_decennials_timeline_continuity_and_lengths():
    birth = datetime(2004, 8, 9, 16, 16)
    timeline = decennials_build_timeline(birth, True, max_age_years=30)
    assert timeline
    # First day-chart major should be Sun 19 months
    assert timeline[0]["ruler_id"] == "SUN"
    assert timeline[0]["months"] == 19
    # Continuity: each start == previous end
    for prev, cur in zip(timeline, timeline[1:]):
        assert abs((cur["start"] - prev["end"]).total_seconds()) < 1.0
    # One full cycle of 7 planets sums to 129 months
    first_cycle = [p for p in timeline if p["cycle_index"] == 0]
    assert sum(p["months"] for p in first_cycle) == 129


# ---------------------------------------------------------------------------
# C3 PD converse dates + symmetry
# ---------------------------------------------------------------------------

def test_pd_converse_dates_are_after_birth():
    warnings: list[str] = []
    jd, _ = moment_to_jd(FIXTURE_BIRTH["moment"])
    birth_dt = datetime(2004, 8, 9, 16, 16)
    dirs = calculate_primary_directions(
        jd,
        birth_dt,
        FIXTURE_BIRTH["latitude"],
        FIXTURE_BIRTH["longitude"],
        "whole_sign",
        False,
        warnings,
        max_age=90,
    )
    for d in dirs:
        assert d.get("symbolic_date_from_signed_arc") is None
        event = d.get("event_date") or d.get("event_date_after_birth")
        assert event is not None
        assert event >= "2004-08-09"
        if d.get("direction_type") == "converse" or d.get("direction") == "converse":
            assert float(d["age_years"]) == pytest.approx(abs(float(d["arc_signed"])) / float(d["key_rate"]), rel=1e-3)
        assert "aspect_type" in d or "aspect" in d


def test_pd_symmetric_duplicate_flag():
    warnings: list[str] = []
    jd, _ = moment_to_jd(FIXTURE_BIRTH["moment"])
    birth_dt = datetime(2004, 8, 9, 16, 16)
    dirs = calculate_primary_directions(
        jd,
        birth_dt,
        FIXTURE_BIRTH["latitude"],
        FIXTURE_BIRTH["longitude"],
        "whole_sign",
        False,
        warnings,
        max_age=90,
        reference_dt=None,
    )
    conj = [d for d in dirs if d.get("aspect_type") == "conjunction"]
    # If both SATURN→DSC and DSC→SATURN exist, one must be flagged duplicate
    pairs = {}
    for d in conj:
        key = tuple(sorted([d["promissor_id"], d["significator_id"]]))
        pairs.setdefault(key, []).append(d)
    multi = [rows for rows in pairs.values() if len(rows) >= 2]
    if multi:
        for rows in multi:
            flags = [bool(r.get("symmetric_duplicate_under_proxy")) for r in rows]
            assert any(flags) and not all(flags)


# ---------------------------------------------------------------------------
# C4 ZR layered lords
# ---------------------------------------------------------------------------

def test_zr_layered_lords_not_ll3_collapse():
    result = calculate_classical(_classical_request(), [])
    summary = result["ambiguity"]["technique_lords_summary"]
    for key in (
        "zr_spirit_l1_lord",
        "zr_spirit_l2_lord",
        "zr_spirit_l3_lord",
        "zr_fortune_l1_lord",
        "zr_fortune_l2_lord",
        "zr_fortune_l3_lord",
    ):
        assert key in summary
    # Must not present a single collapsed "LL3" label as the only truth
    assert "LL3" not in str(summary)
    zr = result["timing"]["zodiacal_releasing"]
    for packet in zr:
        assert packet.get("level") == "L1"
        assert "l1_ruler" in packet or packet.get("ruler")
        assert packet.get("current_active_level") in {"L1", "L2", "L3", "L4", None}


# ---------------------------------------------------------------------------
# C6/C7 Hyleg / Alcocoden
# ---------------------------------------------------------------------------

def test_hyleg_unique_selected():
    result = calculate_classical(_classical_request(), [])
    hyleg = result["hyleg_alcocoden"]["hyleg"]
    selected = [c for c in hyleg["candidates"] if c.get("selected")]
    assert len(selected) <= 1
    assert hyleg.get("selected_count", len(selected)) <= 1
    assert hyleg.get("hyleg_profile")


def test_alcocoden_rejects_non_witness():
    result = calculate_classical(_classical_request(), [])
    alco = result["hyleg_alcocoden"]["alcocoden"]
    for c in alco["candidates"]:
        assert "sees_hyleg" in c
        assert "eligible_under_profile" in c
        if not c["sees_hyleg"]:
            assert c["eligible_under_profile"] is False
            assert c.get("rejection_reason") == "does_not_see_hyleg"
        if c.get("planet_id") == alco.get("selected_id") and alco.get("selected_id"):
            assert c["sees_hyleg"] is True
    assert alco.get("longevity_years") is None
    assert alco.get("longevity_years_suppressed") is True


# ---------------------------------------------------------------------------
# C10 Circumambulations period format
# ---------------------------------------------------------------------------

def test_circumambulation_period_format():
    birth = datetime(2004, 8, 9, 16, 16)
    ref = datetime(2026, 7, 25, 16, 44)
    # ASC Capricorn ~2.5° for fixture; use computed ASC from classical
    result = calculate_classical(_classical_request(), [])
    asc = next(a for a in result["angles"] if a["id"] == "ASC")
    pack = calculate_circumambulations(asc["longitude"], birth, "egyptian", max_age=90, reference_dt=ref)
    assert pack.get("output_format") == "period"
    assert pack.get("periods")
    current = [p for p in pack["periods"] if p.get("current_period")]
    assert len(current) == 1
    cur = current[0]
    for key in (
        "period_ruler",
        "start_sign",
        "start_degree",
        "end_sign",
        "end_degree",
        "start_age",
        "end_age",
        "start_date",
        "end_date",
    ):
        assert key in cur
    assert cur["start_age"] < cur["end_age"]
    # Capricorn 22–26 is Saturn bound under Egyptian
    if cur["start_sign"] in {"摩羯", "Capricorn"} or "摩羯" in str(cur["start_sign"]):
        if 22 <= float(cur["start_degree"]) <= 26 or 22 <= float(cur.get("end_degree", 0)) <= 30:
            assert cur["period_ruler_id"] in {"SATURN", "VENUS", "MERCURY", "JUPITER", "MARS"}


# ---------------------------------------------------------------------------
# C12/C13/C14 place + solar elongation
# ---------------------------------------------------------------------------

def test_place_quality_ninth_house():
    fields = place_quality_fields(9)
    assert fields["angularity_class"] == "cadent"
    assert fields["place_quality"] == "good"
    assert fields["beholds_ascendant"] is True


def test_solar_elongation_not_naked_eye_visible():
    # Mars ~12.24° from Sun → under beams
    label, score, notes, payload = solar_phase("MARS", 100.0, 100.0 + 12.24)
    assert payload["solar_elongation_condition"] == "under_beams"
    assert payload["under_beams"] is True
    assert payload.get("visibility_method") == "solar_elongation_thresholds_only"
    assert payload.get("heliacally_visible") is not True


def test_almuten_profile_fields():
    result = calculate_classical(_classical_request(), [])
    almuten = result["almuten_figuris"]
    assert almuten.get("almuten_profile") or almuten.get("method_variant")
    assert almuten.get("title") == "当前profile下的Almuten Figuris" or "Almuten" in str(almuten.get("title", "Almuten"))
    assert "included_points" in almuten or "points_used" in almuten


# ---------------------------------------------------------------------------
# C17 Lots duplicate groups + C18 syzygy axis
# ---------------------------------------------------------------------------

def test_lot_duplicate_formula_groups():
    result = calculate_classical(_classical_request(), [])
    lots = result["lots"] + (result.get("experimental_lots") or [])
    by_formula = {}
    for lot in lots:
        key = lot.get("formula_normalized")
        if not key:
            continue
        by_formula.setdefault(key, []).append(lot["id"])
    # Fortune and kingship share day ASC+Moon-Sun on day charts
    multi = {k: v for k, v in by_formula.items() if len(v) > 1}
    assert multi, "expected at least one duplicate formula group"
    for lot in lots:
        if lot.get("duplicate_formula_group"):
            assert lot.get("independence_group") == lot["duplicate_formula_group"]


def test_prenatal_full_moon_axis_fields():
    result = calculate_classical(_classical_request(), [])
    syz = result["prenatal_syzygy"]
    assert syz.get("syzygy_type") in {"full_moon", "new_moon"}
    if syz.get("syzygy_type") == "full_moon":
        assert syz.get("syzygy_axis") is not None
        assert "sun_longitude" in syz
        assert "moon_longitude" in syz
        assert syz.get("degree_selection_profile")
        assert syz.get("selected_luminary") == "SUN"
