from __future__ import annotations

from datetime import datetime, timedelta

from astro_backend_api import calculate_classical
from astro_backend_classical import (
    add_years_approx,
    angular_separation,
    bounds_ruler,
    decan_ruler,
    dignity_rulers_for_lon,
    format_longitude,
    norm360,
    planet_name,
    sign_degree,
    zodiac_sign_index,
    completed_age,
    PLANETARY_YEARS,
    SIGN_RULERS,
    EGYPTIAN_BOUNDS,
    PTOLEMAIC_BOUNDS,
    FACE_ORDER,
    ZR_PERIOD_YEARS,
    FIRDARIA_SEQUENCE_DAY,
    FIRDARIA_SEQUENCE_NIGHT,
    firdaria_sub_periods,
    firdaria_summary,
    return_search_bounds,
    RETURN_CONFIG,
    JOY_HOUSE,
    SIGN_GENDER,
    TRIPLICITY_RULERS,
    SIGN_ELEMENTS,
    EXALTATION_RULERS,
    triplicity_set,
    dignity_labels,
    profection_summary,
    monthly_profection,
    _zr_walk,
    _detect_loosing_of_bond,
    zodiacal_releasing_summary,
    timing_timeline,
    hayz_status,
    joy_status,
    sect_status,
    solar_phase,
    motion_label,
    house_strength,
    lot_value,
)

class TestZodiacMath:
    def test_norm360(self) -> None:
        assert norm360(0) == 0.0
        assert norm360(360) == 0.0
        assert norm360(400) == 40.0
        assert norm360(-10) == 350.0

    def test_sign_index(self) -> None:
        assert zodiac_sign_index(0) == 0
        assert zodiac_sign_index(30) == 1
        assert zodiac_sign_index(359.9) == 11

    def test_sign_degree(self) -> None:
        assert abs(sign_degree(45) - 15) < 0.01
        assert abs(sign_degree(0) - 0) < 0.01
        assert abs(sign_degree(359) - 29) < 0.01

    def test_angular_separation(self) -> None:
        assert abs(angular_separation(10, 20) - 10) < 0.01
        assert abs(angular_separation(350, 10) - 20) < 0.01
        assert abs(angular_separation(0, 180) - 180) < 0.01

    def test_format_longitude(self) -> None:
        sign, text = format_longitude(0)
        assert sign == "\u767d\u7f8a"
        assert "00\u00b0" in text


class TestDignities:
    def test_domicile_ruler(self) -> None:
        rulers = dignity_rulers_for_lon(0, True, "egyptian", "dorothean")
        assert rulers["domicile"] == "MARS"

    def test_exaltation_ruler(self) -> None:
        rulers = dignity_rulers_for_lon(0, True, "egyptian", "dorothean")
        assert rulers["exaltation"] == "SUN"

    def test_triplicity_day(self) -> None:
        rulers = dignity_rulers_for_lon(0, True, "egyptian", "dorothean")
        assert rulers["triplicity"] == "SUN"

    def test_triplicity_night(self) -> None:
        rulers = dignity_rulers_for_lon(0, False, "egyptian", "dorothean")
        assert rulers["triplicity"] == "JUPITER"

    def test_bounds_egyptian_aries(self) -> None:
        assert bounds_ruler(2, "egyptian") == "JUPITER"
        assert bounds_ruler(10, "egyptian") == "VENUS"
        assert bounds_ruler(20, "egyptian") == "MERCURY"
        assert bounds_ruler(25, "egyptian") == "MARS"
        assert bounds_ruler(29, "egyptian") == "SATURN"

    def test_bounds_ptolemaic_aries(self) -> None:
        assert bounds_ruler(2, "ptolemaic") == "JUPITER"
        assert bounds_ruler(27, "ptolemaic") == "MARS"
        assert bounds_ruler(29, "ptolemaic") == "SATURN"

    def test_decan_ruler_first_decan_aries(self) -> None:
        assert decan_ruler(5) == "MARS"

    def test_decan_ruler_second_decan(self) -> None:
        assert decan_ruler(15) == "SUN"

    def test_triplicity_set_fire(self) -> None:
        fire = triplicity_set(0, "dorothean")
        assert fire == ("SUN", "JUPITER", "SATURN")

    def test_dignity_labels_sun_in_aries(self) -> None:
        domicile, exaltation, triplicity, bound, decan, score, notes, breakdown, det, fall = dignity_labels(
            "SUN", 5, True, "egyptian", "dorothean"
        )
        assert exaltation == "\u65fa"
        assert score > 0


class TestPlanetaryYears:
    def test_years_exist(self) -> None:
        assert PLANETARY_YEARS["SUN"] == 19
        assert PLANETARY_YEARS["MOON"] == 25
        assert PLANETARY_YEARS["MERCURY"] == 20
        assert PLANETARY_YEARS["VENUS"] == 8
        assert PLANETARY_YEARS["MARS"] == 15
        assert PLANETARY_YEARS["JUPITER"] == 12
        assert PLANETARY_YEARS["SATURN"] == 30


class TestZRPeriodYears:
    def test_zr_period_years(self) -> None:
        assert ZR_PERIOD_YEARS[0] == 15
        assert ZR_PERIOD_YEARS[11] == 12
        assert len(ZR_PERIOD_YEARS) == 12


class TestFirdaria:
    def test_day_sequence(self) -> None:
        assert FIRDARIA_SEQUENCE_DAY[0] == ("SUN", 10)
        assert FIRDARIA_SEQUENCE_DAY[4] == ("SATURN", 11)

    def test_night_sequence(self) -> None:
        assert FIRDARIA_SEQUENCE_NIGHT[0] == ("MOON", 9)
        assert FIRDARIA_SEQUENCE_NIGHT[4] == ("SUN", 10)

    def test_sub_periods(self) -> None:
        start = datetime(1990, 1, 1)
        subs = firdaria_sub_periods("SUN", start, 10, True)
        assert len(subs) == 8
        assert subs[0]["ruler"] != "SUN"
        assert all("start_local" in s for s in subs)
        assert all("end_local" in s for s in subs)
        assert all("fraction" in s for s in subs)

    def test_firdaria_summary_day(self) -> None:
        birth = datetime(1990, 1, 1)
        ref = datetime(1995, 1, 1)
        summary = firdaria_summary(birth, ref, True)
        assert summary["technique"] == "Firdaria"
        assert "ruler" in summary
        assert "sub_periods" in summary


class TestTimeline:
    def test_timing_timeline(self) -> None:
        profection = {
            "start_local": "2020-01-01 12:00",
            "end_local": "2021-01-01 12:00",
        }
        firdaria = {
            "id": "firdaria-main",
            "technique": "Firdaria",
            "level": "\u4e3b\u9650",
            "start_local": "2020-01-01 12:00",
            "end_local": "2030-01-01 12:00",
        }
        decennials = {
            "id": "decennials-main",
            "technique": "Decennials",
            "level": "\u4e3b\u9650",
            "start_local": "2020-01-01 12:00",
            "end_local": "2030-01-01 12:00",
        }
        zr = [
            {
                "id": "zr-fortune",
                "technique": "ZR Fortune",
                "level": "L1",
                "start_local": "2020-01-01 12:00",
                "end_local": "2020-12-31 12:00",
            }
        ]
        returns = [
            {
                "id": "sun",
                "body_id": "SUN",
                "title": "Solar Return",
                "current_cycle_return": {
                    "exact_local": "2020-06-15 12:00",
                },
                "search_start_local": "2020-06-13 12:00",
                "search_end_local": "2020-06-17 12:00",
            }
        ]
        timeline = timing_timeline(profection, firdaria, decennials, zr, returns)
        assert len(timeline) > 0
        assert any(item["kind"] == "event" for item in timeline)
        assert any(item["kind"] == "period" for item in timeline)


class TestSectHayzJoy:
    def test_sect_sun_day(self) -> None:
        status, score, _, _ = sect_status("SUN", True, 0, 0)
        assert score == 2
        assert "\u5408" in status

    def test_sect_moon_night(self) -> None:
        status, score, _, _ = sect_status("MOON", False, 0, 0)
        assert score == 2
        assert "\u5408" in status

    def test_joy(self) -> None:
        label, score, _, _ = joy_status("SUN", 9)
        assert label == "\u559c\u4e50"
        assert score == 1

        label2, score2, _, _ = joy_status("SUN", 1)
        assert label2 == ""
        assert score2 == 0


class TestSolarPhase:
    def test_phase_visible(self) -> None:
        phase, _, _, _ = solar_phase("VENUS", 50, 100)
        assert phase == "\u53ef\u89c1"

    def test_phase_sun(self) -> None:
        phase, _, _, _ = solar_phase("SUN", 0, 0)
        assert phase == "-"


class TestMotion:
    def test_motion_direct(self) -> None:
        label, score, _, _ = motion_label("MARS", 0.5)
        assert label == "\u987a\u884c"
        assert score == 0

    def test_motion_retrograde(self) -> None:
        label, score, _, _ = motion_label("MARS", -0.5)
        assert label == "\u9006\u884c"
        assert score == -3


class TestHouseStrength:
    def test_angular(self) -> None:
        assert house_strength(1) == "\u89d2\u5bab"
        assert house_strength(7) == "\u89d2\u5bab"

    def test_succedent(self) -> None:
        assert house_strength(2) == "\u7eed\u5bab"

    def test_cadent(self) -> None:
        assert house_strength(3) == "\u679c\u5bab"


class TestReturnSearchBounds:
    def test_annual_return(self) -> None:
        birth = datetime(1990, 6, 15, 12, 0)
        ref = datetime(2020, 1, 1, 12, 0)
        start, end = return_search_bounds("SUN", birth, ref)
        assert start < end
        assert start.month == 6

    def test_nearest_return(self) -> None:
        birth = datetime(1990, 1, 1, 12, 0)
        ref = datetime(2020, 1, 1, 12, 0)
        start, end = return_search_bounds("MOON", birth, ref)
        assert start < end


class TestLoosingOfBond:
    def test_ordinary_opposition_entry_is_not_loosing_bond(self) -> None:
        l1_periods = [
            {"sign": "\u5904\u5973", "sign_index": 5, "start_local": "2020-01-01 12:00", "end_local": "2020-06-01 12:00"},
            {"sign": "\u5929\u79e4", "sign_index": 6, "start_local": "2020-06-01 12:00", "end_local": "2020-12-01 12:00", "is_active": True},
        ]
        ref = datetime(2020, 7, 1, 12, 0)
        lob, detail, level = _detect_loosing_of_bond(0, l1_periods, ref)
        assert not lob
        assert detail == ""
        assert level == ""

    def test_actual_jump_to_loosening_point_is_loosing_bond(self) -> None:
        l1_periods = [
            {"sign": "\u53cc\u9c7c", "sign_index": 11, "start_local": "2020-01-01 12:00", "end_local": "2020-06-01 12:00"},
            {"sign": "\u5929\u79e4", "sign_index": 6, "start_local": "2020-06-01 12:00", "end_local": "2020-12-01 12:00", "is_active": True},
        ]
        ref = datetime(2020, 7, 1, 12, 0)
        lob, detail, level = _detect_loosing_of_bond(0, l1_periods, ref)
        assert lob
        assert "\u8df3\u81f3" in detail
        assert level == "L1"

    def test_named_ordinary_next_sign_transitions_are_not_loosing_bond(self) -> None:
        ref = datetime(2020, 7, 1, 12, 0)
        leo_virgo = [
            {"sign": "\u72ee\u5b50", "sign_index": 4, "start_local": "2020-01-01 12:00", "end_local": "2020-06-01 12:00"},
            {"sign": "\u5904\u5973", "sign_index": 5, "start_local": "2020-06-01 12:00", "end_local": "2020-12-01 12:00", "is_active": True},
        ]
        pisces_aries = [
            {"sign": "\u53cc\u9c7c", "sign_index": 11, "start_local": "2020-01-01 12:00", "end_local": "2020-06-01 12:00"},
            {"sign": "\u767d\u7f8a", "sign_index": 0, "start_local": "2020-06-01 12:00", "end_local": "2020-12-01 12:00", "is_active": True},
        ]
        assert not _detect_loosing_of_bond(4, leo_virgo, ref)[0]
        assert not _detect_loosing_of_bond(11, pisces_aries, ref)[0]


class TestLotValue:
    def test_simple_lot(self) -> None:
        result = lot_value(0, 30, 60)
        assert result == 330.0


class TestCompletedAge:
    def test_age_basic(self) -> None:
        birth = datetime(1990, 1, 1)
        ref = datetime(2020, 1, 1)
        assert completed_age(birth, ref) == 30

    def test_age_before_birthday(self) -> None:
        birth = datetime(1990, 6, 15)
        ref = datetime(2020, 1, 1)
        assert completed_age(birth, ref) == 29


class TestDodekatemorion:
    def test_asc_0_cap(self) -> None:
        from astro_backend_classical import calc_dodekatemorion
        lon, sign_idx, ruler = calc_dodekatemorion(270.0)
        assert sign_idx == 9
        assert ruler == "土星"

    def test_sun_10_aries(self) -> None:
        from astro_backend_classical import calc_dodekatemorion
        lon, sign_idx, ruler = calc_dodekatemorion(10.0)
        assert sign_idx == 4
        assert ruler == "太阳"


class TestPrenatalSyzygy:
    def test_basic(self) -> None:
        from astro_backend_classical import calculate_prenatal_syzygy
        result = calculate_prenatal_syzygy(2447893.0, datetime(1990, 1, 1, 12, 0), [], False)
        assert result["syzygy_type"] in ("new_moon", "full_moon")
        assert result["longitude"] > 0
        assert result["sign"] is not None

    def test_full_moon_uses_swiss_ephemeris_positions(self) -> None:
        import swisseph as swe
        from astro_backend_classical import calculate_prenatal_syzygy

        birth_jd = swe.julday(2004, 8, 1, 0.0, swe.GREG_CAL)
        result = calculate_prenatal_syzygy(birth_jd, datetime(2004, 8, 1, 0, 0), [], False)
        assert result["syzygy_type"] == "full_moon"
        assert result["exact_utc"] == "2004-07-31 18:05"
        assert result["sun_position"] > 0
        assert result["moon_position"] > 0
        assert "Sun degree" in result["syzygy_degree_used"]
        assert "Swiss Ephemeris" in result["ephemeris"]


class TestAlmutenFiguris:
    def test_basic(self) -> None:
        from astro_backend_classical import calculate_almuten_figuris
        angles = {"ASC": 280.0, "MC": 200.0, "DSC": 100.0, "IC": 20.0}
        positions = {
            "SUN": {"longitude": 10.0, "name": "太阳", "score": 0},
            "MOON": {"longitude": 30.0, "name": "月亮", "score": 0},
            "MERCURY": {"longitude": 50.0, "name": "水星", "score": 0},
            "VENUS": {"longitude": 70.0, "name": "金星", "score": 0},
            "MARS": {"longitude": 90.0, "name": "火星", "score": 0},
            "JUPITER": {"longitude": 110.0, "name": "木星", "score": 0},
            "SATURN": {"longitude": 130.0, "name": "土星", "score": 0},
        }
        syzygy = {"longitude": 50.0}
        result = calculate_almuten_figuris(angles, positions, 30.0, syzygy, True, "egyptian", "dorothean")
        assert result["winner"] is not None
        assert len(result.get("score_table", [])) > 0


class TestHylegAlcocoden:
    def test_basic(self) -> None:
        from astro_backend_classical import calculate_hyleg_alcocoden
        angles = {"ASC": 280.0, "MC": 200.0, "DSC": 100.0, "IC": 20.0}
        positions = {
            "SUN": {"longitude": 290.0, "name": "太阳", "score": 3},
            "MOON": {"longitude": 30.0, "name": "月亮", "score": 2},
            "MERCURY": {"longitude": 50.0, "name": "水星", "score": 1},
            "VENUS": {"longitude": 70.0, "name": "金星", "score": 4},
            "MARS": {"longitude": 90.0, "name": "火星", "score": 1},
            "JUPITER": {"longitude": 110.0, "name": "木星", "score": 5},
            "SATURN": {"longitude": 130.0, "name": "土星", "score": 2},
        }
        cusps = [280.0, 310.0, 340.0, 10.0, 40.0, 70.0, 100.0, 130.0, 160.0, 190.0, 220.0, 250.0]
        result = calculate_hyleg_alcocoden(0, angles, positions, 30.0, 50.0, cusps, True, "egyptian", "dorothean", [])
        hyleg = result.get("hyleg", {})
        assert isinstance(hyleg.get("candidates"), list)
        assert all(candidate["reason"] for candidate in hyleg["candidates"])
        alc = result.get("alcocoden", {})
        assert isinstance(alc.get("candidates"), list)
        assert {candidate["planet_id"] for candidate in alc["candidates"]} == {"SATURN", "MERCURY", "MARS", "JUPITER", "VENUS"}
        assert "longevity_years" not in result


class TestCircumambulations:
    def test_find_bound_first_degree_aries_egyptian(self) -> None:
        from astro_backend_circumambulations import _find_bound_for_degree
        from astro_backend_classical import EGYPTIAN_BOUNDS
        ruler, start, end = _find_bound_for_degree(EGYPTIAN_BOUNDS, 0, 0.0)
        assert ruler == "JUPITER"
        assert start == 0
        assert end == 6

    def test_find_bound_mid_degree_aries_egyptian(self) -> None:
        from astro_backend_circumambulations import _find_bound_for_degree
        from astro_backend_classical import EGYPTIAN_BOUNDS
        ruler, start, end = _find_bound_for_degree(EGYPTIAN_BOUNDS, 0, 14.0)
        assert ruler == "VENUS"
        assert start == 6
        assert end == 14

    def test_find_bound_last_degree_aries_egyptian(self) -> None:
        from astro_backend_circumambulations import _find_bound_for_degree
        from astro_backend_classical import EGYPTIAN_BOUNDS
        ruler, start, end = _find_bound_for_degree(EGYPTIAN_BOUNDS, 0, 29.9)
        assert ruler == "SATURN"
        assert start == 26

    def test_circumambulations_max_age_zero(self) -> None:
        from astro_backend_circumambulations import calculate_circumambulations
        from datetime import datetime
        result = calculate_circumambulations(280.0, datetime(1990, 1, 1, 12, 0), "egyptian", max_age=0)
        assert len(result["boundaries"]) == 0
        assert result["current_ruler_id"] is not None

    def test_circumambulations_with_reference(self) -> None:
        from astro_backend_circumambulations import calculate_circumambulations
        from datetime import datetime
        birth = datetime(1990, 1, 1, 12, 0)
        ref = datetime(2026, 5, 5, 12, 0)
        result = calculate_circumambulations(280.0, birth, "egyptian", max_age=90, reference_dt=ref)
        assert len(result["boundaries"]) > 0
        assert "bound_start_date" in result
        assert result["bound_start_date"]

    def test_bounds_table_egyptian(self) -> None:
        from astro_backend_circumambulations import _bounds_table
        assert _bounds_table("egyptian") is not _bounds_table("ptolemaic")

    def test_bounds_table_ptolemaic(self) -> None:
        from astro_backend_circumambulations import _bounds_table
        assert _bounds_table("ptolemaic") is not None


class TestPrimaryDirections:
    def test_obliquity_j2000(self) -> None:
        from astro_backend_primary_directions import obliquity
        obl = obliquity(2451545.0)
        assert abs(obl - 23.439291) < 0.001

    def test_right_ascension_zero(self) -> None:
        from astro_backend_primary_directions import right_ascension
        ra = right_ascension(0.0, 23.439291)
        assert abs(ra) < 0.001

    def test_right_ascension_90(self) -> None:
        from astro_backend_primary_directions import right_ascension
        ra = right_ascension(90.0, 23.439291)
        assert abs(ra - 90.0) < 0.001

    def test_declination_at_equator(self) -> None:
        from astro_backend_primary_directions import declination
        dec = declination(0.0, 23.439291)
        assert abs(dec) < 0.001

    def test_declination_at_90(self) -> None:
        from astro_backend_primary_directions import declination
        dec = declination(90.0, 23.439291)
        assert abs(dec - 23.439291) < 0.001

    def test_ascensional_difference_at_equator(self) -> None:
        from astro_backend_primary_directions import ascensional_difference
        ad = ascensional_difference(0.0, 23.439291, 0.0)
        assert abs(ad) < 0.001

    def test_ascensional_difference_nonzero(self) -> None:
        from astro_backend_primary_directions import ascensional_difference
        ad = ascensional_difference(90.0, 23.439291, 40.0)
        assert ad != 0.0

    def test_semi_arc_diurnal(self) -> None:
        from astro_backend_primary_directions import semi_arc
        arc = semi_arc(90.0, 23.439291, 40.0, True)
        assert 0 < arc < 360

    def test_semi_arc_nocturnal(self) -> None:
        from astro_backend_primary_directions import semi_arc
        arc = semi_arc(90.0, 23.439291, 40.0, False)
        assert arc != 0

    def test_meridian_distance(self) -> None:
        from astro_backend_primary_directions import meridian_distance
        assert meridian_distance(100.0, 50.0) == 50.0
        assert meridian_distance(10.0, 350.0) == 20.0


class TestTimingEdges:
    def test_timing_timeline_empty(self) -> None:
        from astro_backend_classical import timing_timeline
        empty_profection = {"start_local": "", "end_local": ""}
        empty_firdaria = {"id": "", "technique": "", "level": "", "start_local": "", "end_local": ""}
        empty_decennials = {"id": "", "technique": "", "level": "", "start_local": "", "end_local": ""}
        result = timing_timeline(empty_profection, empty_firdaria, empty_decennials, [], [])
        assert len(result) >= 3

    def test_timing_timeline_only_profection(self) -> None:
        from astro_backend_classical import timing_timeline
        profection = {
            "start_local": "2026-01-01 12:00",
            "end_local": "2027-01-01 12:00",
        }
        empty_firdaria = {"id": "", "technique": "", "level": "", "start_local": "", "end_local": ""}
        empty_decennials = {"id": "", "technique": "", "level": "", "start_local": "", "end_local": ""}
        result = timing_timeline(profection, empty_firdaria, empty_decennials, [], [])
        assert len(result) > 0
        assert any(item["kind"] == "period" for item in result)


class TestLots:
    def test_lot_value_zero(self) -> None:
        from astro_backend_classical import lot_value
        result = lot_value(0.0, 0.0, 0.0)
        assert result == 0.0

    def test_lot_value_standard(self) -> None:
        from astro_backend_classical import lot_value
        result = lot_value(100.0, 50.0, 200.0)
        assert result > 0


class TestReturnSearchBounds:
    def test_moon_returns_with_birth_before_window(self) -> None:
        from astro_backend_classical import return_search_bounds
        from datetime import datetime
        birth = datetime(1990, 1, 1, 12, 0)
        ref = datetime(2026, 1, 1, 12, 0)
        start, end = return_search_bounds("MOON", birth, ref)
        assert start < end
        assert start.year >= 1990


class TestProfection:
    def test_profection_at_age_zero(self) -> None:
        from astro_backend_classical import profection_summary
        from datetime import datetime
        birth = datetime(1990, 1, 1, 12, 0)
        ref = datetime(1990, 1, 1, 12, 0)
        result = profection_summary(birth, ref, 280.0, [])
        assert result["age"] == 0
        assert result["house"] == 1


class TestPlanetNotes:
    def test_notes_included_in_response(self) -> None:
        from astro_backend_classical import classical_snapshot
        from datetime import datetime
        import swisseph as swe

        birth_jd = swe.julday(1990, 1, 1, 12.0, swe.GREG_CAL)
        snapshot = classical_snapshot(
            birth_jd, 31.23, 121.47, "whole_sign", False, "egyptian", "dorothean", 3.0, [],
        )
        planets = snapshot["planets"]
        assert len(planets) == 7
        any_with_notes = any(
            len(p.get("notes", [])) > 0
            for p in planets
        )
        assert any_with_notes, "expected at least one planet to have non-empty notes"


class TestClassicalOutputAuditFixes:
    def test_birthday_transition_ignores_same_day_alignment(
        self, sample_classical_request: dict[str, object]
    ) -> None:
        warnings: list[str] = []
        result = calculate_classical(sample_classical_request, warnings)
        assert result["birthday_transition"] is None

    def test_birthday_transition_detects_prior_calendar_day_solar_return(
        self, sample_classical_request: dict[str, object]
    ) -> None:
        request = {
            **sample_classical_request,
            "birth": {
                **sample_classical_request["birth"],
                "moment": {
                    **sample_classical_request["birth"]["moment"],
                    "hour": 0,
                    "minute": 0,
                },
            },
            "reference": {
                **sample_classical_request["reference"],
                "month": 1,
                "day": 1,
                "hour": 12,
                "minute": 0,
            },
        }
        warnings: list[str] = []
        result = calculate_classical(request, warnings)
        transition = result["birthday_transition"]
        assert transition is not None
        assert transition["detected"] is True
        assert transition["current_solar_return"].startswith("2025-12-31")

    def test_timeline_includes_multiple_return_snapshots_per_body(
        self, sample_classical_request: dict[str, object]
    ) -> None:
        warnings: list[str] = []
        result = calculate_classical(sample_classical_request, warnings)
        return_titles = [
            item["title"]
            for item in result["timing"]["timeline"]
            if "Return" in item["title"]
        ]
        assert any(title.startswith("Current Saturn Return") for title in return_titles)
        assert any(title.startswith("Previous Saturn Return") for title in return_titles)
        assert any(title.startswith("Next Solar Return") for title in return_titles)

    def test_invalid_return_mode_falls_back_to_full(
        self, sample_classical_request: dict[str, object]
    ) -> None:
        request = {**sample_classical_request, "returnMode": "bogus"}
        warnings: list[str] = []
        result = calculate_classical(request, warnings)
        assert len(result["planetary_returns"]) == 7
