"""Tests for medieval deepening: triplicity rulers, kurios, profection+sr synthesis."""
from __future__ import annotations

from astro_backend_classical_medieval import (
    sect_light_triplicity_rulers,
    determine_kurios,
    profection_solar_return_synthesis,
)


class TestSectLightTriplicity:
    """Triplicity rulers of the sect light."""

    SAMPLE_PLANETS = [
        {"id": "SUN", "name": "太阳", "longitude": 100.0, "sign": "巨蟹", "house": 10, "score": 10, "score_label": "强", "accidental": "角宫"},
        {"id": "MOON", "name": "月亮", "longitude": 130.0, "sign": "狮子", "house": 1, "score": 5, "score_label": "中", "accidental": "角宫"},
        {"id": "MERCURY", "name": "水星", "longitude": 160.0, "sign": "处女", "house": 2, "score": 3, "score_label": "弱", "accidental": "续宫"},
        {"id": "VENUS", "name": "金星", "longitude": 190.0, "sign": "天秤", "house": 3, "score": 2, "score_label": "弱", "accidental": "续宫"},
        {"id": "MARS", "name": "火星", "longitude": 220.0, "sign": "天蝎", "house": 5, "score": 4, "score_label": "中", "accidental": "续宫"},
        {"id": "JUPITER", "name": "木星", "longitude": 250.0, "sign": "射手", "house": 8, "score": 1, "score_label": "弱", "accidental": "果宫"},
        {"id": "SATURN", "name": "土星", "longitude": 280.0, "sign": "摩羯", "house": 9, "score": 7, "score_label": "强", "accidental": "角宫"},
    ]

    def test_day_chart(self):
        # Sun in Cancer (water sign), day chart
        result = sect_light_triplicity_rulers(100.0, 130.0, True, 80.0, self.SAMPLE_PLANETS)
        assert result["sect_light"] == "SUN"
        assert result["light_sign"] == "巨蟹"
        assert len(result["rulers"]) == 3

    def test_night_chart(self):
        # Night chart → Sect Light = Moon
        result = sect_light_triplicity_rulers(100.0, 130.0, False, 80.0, self.SAMPLE_PLANETS)
        assert result["sect_light"] == "MOON"

    def test_ruler_order_night_chart(self):
        # Night: first ruler = night ruler of the element
        result = sect_light_triplicity_rulers(100.0, 130.0, False, 80.0, self.SAMPLE_PLANETS)
        first = result["rulers"][0]
        assert first["rank"] == 1
        assert first["label"] == "first"


class TestKurios:
    """Lord of the nativity determination."""

    SAMPLE_PLANETS = [
        {"id": "SUN", "name": "太阳", "longitude": 100.0, "house": 10, "score": 10, "score_label": "强", "accidental": "角宫"},
        {"id": "MOON", "name": "月亮", "longitude": 130.0, "house": 1, "score": 5, "score_label": "中", "accidental": "角宫"},
        {"id": "MERCURY", "name": "水星", "longitude": 160.0, "house": 2, "score": 3, "score_label": "弱", "accidental": "续宫"},
        {"id": "VENUS", "name": "金星", "longitude": 190.0, "house": 3, "score": 2, "score_label": "弱", "accidental": "续宫"},
        {"id": "MARS", "name": "火星", "longitude": 220.0, "house": 5, "score": 4, "score_label": "中", "accidental": "续宫"},
        {"id": "JUPITER", "name": "木星", "longitude": 250.0, "house": 8, "score": 1, "score_label": "弱", "accidental": "果宫"},
        {"id": "SATURN", "name": "土星", "longitude": 280.0, "house": 9, "score": 7, "score_label": "强", "accidental": "角宫"},
    ]

    def test_kurios_returns_primary(self):
        result = determine_kurios(
            80.0, True, None, None, None, self.SAMPLE_PLANETS
        )
        assert "primary" in result
        assert "candidates" in result
        assert len(result["candidates"]) > 0

    def test_kurios_with_triplicity(self):
        trip = {
            "rulers": [
                {"planet": "VENUS", "rank": 1, "label": "first", "house": 3, "score": 2, "score_label": "弱", "angular": False},
                {"planet": "MOON", "rank": 2, "label": "second", "house": 1, "score": 5, "score_label": "中", "angular": True},
            ]
        }
        result = determine_kurios(80.0, True, trip, None, None, self.SAMPLE_PLANETS)
        assert len(result["candidates"]) > 0

    def test_kurios_with_almuten(self):
        almuten = {"winner_id": "SATURN"}
        result = determine_kurios(80.0, True, None, almuten, None, self.SAMPLE_PLANETS)
        roles = [c["role"] for c in result["candidates"]]
        assert "Almuten Figuris" in roles


class TestProfectionSRSynthesis:
    """Profection + Solar Return synthesis."""

    def test_asc_signs_match(self):
        profection = {"lordId": "MARS", "lord": "火星", "profected_asc_lon": 80.0}
        snapshot = {
            "angles": [{"id": "ASC", "longitude": 83.0}],
            "planets": [],
        }
        result = profection_solar_return_synthesis(
            profection, snapshot, 80.0, [], True
        )
        assert result["asc_signs_match"] is True
        assert result["profection_asc_sign"] == "双子"
        assert result["solar_return_asc_sign"] == "双子"

    def test_asc_signs_dont_match(self):
        profection = {"lordId": "MARS", "lord": "火星", "profected_asc_lon": 80.0}
        snapshot = {
            "angles": [{"id": "ASC", "longitude": 120.0}],
            "planets": [],
        }
        result = profection_solar_return_synthesis(
            profection, snapshot, 80.0, [], True
        )
        assert result["asc_signs_match"] is False

    def test_lord_in_sr_detected(self):
        profection = {"lordId": "MARS", "lord": "火星", "profected_asc_lon": 80.0}
        snapshot = {
            "angles": [{"id": "ASC", "longitude": 120.0}],
            "planets": [
                {"id": "MARS", "name": "火星", "house": 10, "sign": "巨蟹", "score": 8, "score_label": "强", "accidental": "角宫", "motion": "顺行"},
            ],
        }
        result = profection_solar_return_synthesis(
            profection, snapshot, 80.0, [], True
        )
        assert result["lord_of_year_in_sr"]["present"] is True
        assert result["lord_of_year_in_sr"]["house"] == 10

    def test_summary_generated(self):
        profection = {"lordId": "SATURN", "lord": "土星", "profected_asc_lon": 80.0}
        snapshot = {
            "angles": [{"id": "ASC", "longitude": 83.0}],
            "planets": [],
        }
        result = profection_solar_return_synthesis(
            profection, snapshot, 80.0, [], True
        )
        assert len(result["summary_text"]) > 0
