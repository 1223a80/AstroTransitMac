import Foundation
import Testing
@testable import TransitStudio

struct ClassicalResultTests {

    @Test func decodeSampleClassicalResult() throws {
        let json = """
        {
            "meta": {
                "birth_utc": "1990-06-15T10:00:00+00:00",
                "reference_utc": "2025-01-01T10:00:00+00:00",
                "sect": "昼盘",
                "house_system": "Whole Sign",
                "zodiac": "Tropical",
                "bounds_system": "Egyptian",
                "triplicity_system": "Dorothean",
                "ephemeris": "Swiss Ephemeris"
            },
            "angles": [],
            "houses": [],
            "planets": [
                {
                    "id": "SUN",
                    "name": "太阳",
                    "longitude": 84.5,
                    "sign": "双子",
                    "degree_text": "24°30'00\\" 双子",
                    "house": 3,
                    "speed": 0.955,
                    "motion": "顺行",
                    "sect_status": "合昼派",
                    "domicile": "",
                    "exaltation": "",
                    "triplicity": "昼主",
                    "bound": "MERCURY",
                    "decan": "VENUS",
                    "solar_phase": "-",
                    "accidental": "果宫",
                    "score": 10,
                    "notes": [],
                    "score_breakdown": [
                        {"label": "sect", "score": 2, "value": "合昼派"}
                    ],
                    "bonification": [],
                    "maltreatment": []
                }
            ],
            "lots": [],
            "aspects": [],
            "receptions": [],
            "antiscia": [],
            "primary_directions": [],
            "circumambulations": [],
            "timing": {
                "profection": {
                    "age": 34,
                    "house": 11,
                    "sign": "水瓶",
                    "lord": "土星",
                    "lord_condition": "",
                    "start_local": "2024-01-01 12:00",
                    "end_local": "2025-01-01 12:00",
                    "activated_planets": [],
                    "logic_steps": []
                },
                "firdaria": {
                    "id": "firdaria-main",
                    "technique": "Firdaria",
                    "level": "主限",
                    "ruler": "月亮",
                    "start_local": "2020-01-01 12:00",
                    "end_local": "2029-01-01 12:00",
                    "notes": []
                },
                "decennials": {
                    "id": "decennials",
                    "technique": "Decennials",
                    "level": "主限",
                    "ruler": "太阳",
                    "start_local": "2020-01-01 12:00",
                    "end_local": "2029-01-01 12:00",
                    "notes": []
                },
                "zodiacal_releasing": [],
                "timeline": []
            },
            "planetary_returns": [
                {
                    "id": "sun",
                    "body_id": "SUN",
                    "body_name": "太阳",
                    "title": "Solar Return",
                    "no_hit_in_user_window": false,
                    "suggested_window": null,
                    "previous_return": {
                        "label": "previous_return",
                        "exact_local": "2024-06-15 12:00",
                        "exact_utc": "2024-06-15 04:00",
                        "ascendant": "白羊 00°00'00\\"",
                        "midheaven": "摩羯 00°00'00\\"",
                        "sect": "昼盘",
                        "house_system": "Whole Sign",
                        "angles": [],
                        "houses": [],
                        "planets": [],
                        "natal_cross_aspects": []
                    },
                    "current_cycle_return": {
                        "label": "current_cycle_return",
                        "exact_local": "2024-06-15 12:00",
                        "exact_utc": "2024-06-15 04:00",
                        "ascendant": "白羊 00°00'00\\"",
                        "midheaven": "摩羯 00°00'00\\"",
                        "sect": "昼盘",
                        "house_system": "Whole Sign",
                        "angles": [],
                        "houses": [],
                        "planets": [],
                        "natal_cross_aspects": []
                    },
                    "next_return": {
                        "label": "next_return",
                        "exact_local": "2025-06-15 12:00",
                        "exact_utc": "2025-06-15 04:00",
                        "ascendant": "白羊 00°00'00\\"",
                        "midheaven": "摩羯 00°00'00\\"",
                        "sect": "昼盘",
                        "house_system": "Whole Sign",
                        "angles": [],
                        "houses": [],
                        "planets": [],
                        "natal_cross_aspects": []
                    },
                    "search_start_local": "2024-06-13 12:00",
                    "search_end_local": "2025-06-17 12:00"
                }
            ],
            "warnings": []
        }
        """

        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(ClassicalResult.self, from: data)

        #expect(result.meta.sect == "昼盘")
        #expect(result.planets.count == 1)
        #expect(result.planets[0].name == "太阳")
        #expect(result.planets[0].score == 10)
        #expect(result.timing.profection.age == 34)
        #expect(result.timing.profection.lord == "土星")
        #expect(result.timing.firdaria.ruler == "月亮")
        #expect(result.planetaryReturns.first?.previousReturn?.label == "previous_return")
        #expect(result.planetaryReturns.first?.currentCycleReturn?.label == "current_cycle_return")
        #expect(result.planetaryReturns.first?.nextReturn?.label == "next_return")
    }

    @Test func planetRowDecoding() throws {
        let json = """
        {
            "id": "MARS",
            "name": "火星",
            "longitude": 15.5,
            "sign": "白羊",
            "degree_text": "15°30'00\\" 白羊",
            "house": 1,
            "speed": 0.524,
            "motion": "逆行",
            "sect_status": "违夜派",
            "domicile": "入庙",
            "exaltation": "",
            "triplicity": "夜主",
            "bound": "MARS",
            "decan": "MARS",
            "solar_phase": "可见",
            "accidental": "角宫",
            "score": 15,
            "notes": ["入庙", "夜主", "界主", "角宫"],
            "score_breakdown": [
                {"label": "domicile", "score": 5, "value": "入庙"},
                {"label": "triplicity", "score": 3, "value": "夜主"},
                {"label": "bound", "score": 2, "value": "界主"},
                {"label": "accidental", "score": 3, "value": "角宫"}
            ],
            "bonification": [],
            "maltreatment": []
        }
        """

        let data = json.data(using: .utf8)!
        let planet = try JSONDecoder().decode(ClassicalPlanetRow.self, from: data)

        #expect(planet.id == "MARS")
        #expect(planet.domicile == "入庙")
        #expect(planet.motion == "逆行")
        #expect(planet.score == 15)
    }
}
