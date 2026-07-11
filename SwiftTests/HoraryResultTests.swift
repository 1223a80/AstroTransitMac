import Foundation
import Testing
@testable import TransitStudio

struct HoraryResultTests {

    @Test func decodeHoraryResult() throws {
        let json = """
        {
            "meta": {
                "asked_local": "2026-05-05 12:00",
                "asked_utc": "2026-05-05T04:00:00",
                "place_name": "Shanghai",
                "latitude": 31.2304,
                "longitude": 121.4737,
                "sect": "day chart",
                "sun_horizon_status": "above",
                "house_system": "Whole Sign",
                "zodiac": "Tropical",
                "bounds_system": "Egyptian",
                "triplicity_system": "Dorothean",
                "aspect_orb": 3.5,
                "ephemeris": "Swiss Ephemeris"
            },
            "question_text": "感情",
            "machine_summary": ["Moon 位于第 5 宫", "Moon 将于 2026-05-06 离开当前星座"],
            "radicality_flags": [
                {"id": "asc_early", "label": "ASC 早度", "severity": "caution"}
            ],
            "moon_voc_criterion": "no applying Ptolemaic aspect to classical planets before sign exit",
            "house_rulers": [
                {"house": 1, "sign": "白羊", "ruler": "MARS"}
            ],
            "significator_candidates": [
                {"id": "querent", "role": "Querent", "planet": "火星", "source": "1H ruler", "position": "0° 白羊", "house": 1, "condition": "顺行, score 10", "planet_id": "MARS"},
                {"id": "moon", "role": "Moon", "planet": "月亮", "source": "General significator", "position": "0° 金牛", "house": 2, "condition": "顺行, score 8", "planet_id": "MOON"},
                {"id": "matter", "role": "Matter / Outcome", "planet": "金星", "source": "7H ruler", "position": "0° 天秤", "house": 7, "condition": "顺行, score 5", "planet_id": "VENUS"},
                {"id": "natural", "role": "Natural significator", "planet": "金星", "source": "Natural ruler", "position": "0° 天秤", "house": 7, "condition": "顺行, score 5", "planet_id": "VENUS"}
            ],
            "key_significator_links": [
                {"id": "MARS|VENUS|link", "pair": "Querent ruler – Matter ruler", "aspect": "sextile", "type": "degree", "orb": 2.0, "applying": "applying", "perfects_before_sign_exit": true, "next_perfection": "2026-05-06 14:00", "perfection_reason": "degree perfection", "reception": ""}
            ],
            "degree_based_key_aspects": [],
            "planetary_speeds": [
                {"id": "MARS", "planet": "火星", "speed": 0.524, "speed_state": "顺行", "station": false}
            ],
            "solar_condition": [
                {"id": "MARS", "planet": "火星", "condition": "可见", "distance_from_sun": 80.0}
            ],
            "negative_receptions": [],
            "lots_summary": [
                {"id": "fortune", "lot": "福点", "position": "20° 双子", "house": 5, "ruler": "MERCURY", "ruler_condition": "", "key_notes": ""}
            ],
            "advanced_candidates": [
                {"id": "translation", "type": "Translation of Light", "status": "not detected", "details": "缺少关键象征星", "planets": [], "exact_time": null},
                {"id": "collection", "type": "Collection of Light", "status": "not detected", "details": "缺少关键象征星", "planets": [], "exact_time": null},
                {"id": "prohibition", "type": "Prohibition", "status": "not evaluated", "details": "缺少关键象征星", "planets": [], "exact_time": null},
                {"id": "frustration", "type": "Frustration", "status": "detected", "details": "第三方先成相", "planets": ["火星", "金星", "土星"], "exact_time": "2026-05-06 12:34", "frustrated_planet": "火星", "frustrating_planet": "土星"}
            ],
            "moon_storyline": {
                "current_position": "0° 金牛",
                "current_house": 2,
                "last_aspect": null,
                "last_aspect_time": "",
                "next_aspect": null,
                "next_aspect_time": "",
                "upcoming_aspects": [],
                "before_sign_exit_aspects": [],
                "voc": true,
                "sign_exit_local": "2026-05-06 14:00",
                "next_sign": "双子",
                "next_sign_ingress_time": "2026-05-06 14:00",
                "first_after_ingress": null,
                "first_after_ingress_time": ""
            },
            "angles": [],
            "houses": [],
            "planets": [],
            "lots": [],
            "aspects": [],
            "receptions": [],
            "warnings": []
        }
        """

        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder().decode(HoraryResult.self, from: data)

        #expect(result.meta.askedLocal == "2026-05-05 12:00")
        #expect(result.meta.aspectOrb == 3.5)
        #expect(result.questionText == "感情")
        #expect(result.machineSummary.count == 2)
        #expect(result.radicalityFlags.count == 1)
        #expect(result.radicalityFlags[0].id == "asc_early")
        #expect(result.moonVocCriterion == "no applying Ptolemaic aspect to classical planets before sign exit")
        #expect(result.significatorCandidates.count == 4)
        #expect(result.keySignificatorLinks.count == 1)
        #expect(result.planetarySpeeds.count == 1)
        #expect(result.solarCondition.count == 1)
        #expect(result.lotsSummary.count == 1)
        #expect(result.advancedCandidates.count == 4)
        #expect(result.advancedCandidates.last?.frustratingPlanet == "土星")
        #expect(result.advancedCandidates.last?.exactTime == "2026-05-06 12:34")
        #expect(result.moonStoryline.voc == true)
        #expect(result.moonStoryline.currentHouse == 2)
    }
}
