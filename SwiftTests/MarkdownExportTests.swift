import Foundation
import Testing
@testable import TransitStudio

struct MarkdownExportTests {

    @Test func classicalResultMarkdown() throws {
        let json = """
        {
            "meta": {
                "birth_utc": "1990-01-01T04:00:00",
                "reference_utc": "2026-05-05T04:00:00",
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
                {"id": "SUN", "name": "太阳", "longitude": 280.5, "declination": -23.1, "out_of_bounds": false, "sign": "摩羯", "degree_text": "10°30' 摩羯", "house": 10, "speed": 0.955, "motion": "顺行", "sect_status": "合昼派", "domicile": "", "exaltation": "", "triplicity": "昼主", "bound": "MERCURY", "decan": "VENUS", "solar_phase": "-", "accidental": "角宫", "score": 10, "notes": [], "score_breakdown": [], "bonification": [], "maltreatment": []}
            ],
            "lots": [],
            "aspects": [],
            "declination_aspects": [
                {"body1": "SUN", "body2": "MOON", "type": "parallel", "diff": 0.4, "declination1": -23.1, "declination2": -22.7}
            ],
            "natal_star_conjunctions": [
                {"planet": "SUN", "star": "Sirius", "star_mag": -1.46, "star_nature": "Mars/Jupiter", "star_keyword": "honor", "orb": 0.42}
            ],
            "receptions": [],
            "antiscia": [],
            "primary_directions": [],
            "circumambulations": [],
            "timing": {
                "profection": {"age": 36, "house": 1, "sign": "白羊", "lord": "火星", "lord_condition": "", "start_local": "", "end_local": "", "activated_planets": [], "logic_steps": []},
                "firdaria": {"id": "firdaria-main", "technique": "Firdaria", "level": "主限", "ruler": "月亮", "start_local": "", "end_local": "", "notes": []},
                "decennials": {"id": "decennials", "technique": "Decennials", "level": "主限", "ruler": "太阳", "start_local": "", "end_local": "", "notes": []},
                "zodiacal_releasing": [],
                "timeline": []
            },
            "planetary_returns": [],
            "prenatal_syzygy": null,
            "almuten_figuris": null,
            "hyleg_alcocoden": null,
            "medieval": {
                "sect_light_triplicity": {
                    "sect_light": "SUN",
                    "sect_light_name": "太阳",
                    "light_sign": "摩羯",
                    "light_sign_index": 9,
                    "light_longitude": 280.5,
                    "triplicity_system": "dorothean",
                    "rulers": [
                        {"planet": "VENUS", "planet_name": "金星", "rank": 1, "label": "昼主", "house": 10, "score": 8, "score_label": "强", "angular": true}
                    ]
                },
                "kurios": {
                    "method": "weighted",
                    "primary": {"planet": "SUN", "planet_name": "太阳", "score": 18, "role": "sect light", "natal_house": 10, "natal_score_label": "强"},
                    "candidates": [
                        {"planet": "SUN", "planet_name": "太阳", "role": "sect light", "base_weight": 10, "modifier": 8, "score": 18, "modifiers": ["角宫"], "natal_house": 10, "natal_score_label": "强"}
                    ]
                },
                "profection_sr_synthesis": {
                    "profection_asc_sign": "白羊",
                    "solar_return_asc_sign": "白羊",
                    "asc_signs_match": true,
                    "lord_of_year_in_sr": {"present": true, "planet": "MARS", "planet_name": "火星", "house": 1, "house_label": "第1宫", "sign": "白羊", "score": 6, "score_label": "中", "retrograde": false, "angular": true},
                    "sr_highlights": {"asc_ruler": "火星", "asc_ruler_house": 1, "mc_ruler": "土星", "mc_ruler_house": 10, "stellium_sign": "白羊"},
                    "summary_text": "年主在返照盘角宫。"
                }
            },
            "warnings": []
        }
        """

        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder().decode(ClassicalResult.self, from: data)

        let md = MarkdownExportBuilder.classical(result)

        #expect(md.contains("## 七政状态"))
        #expect(md.contains("## 宫位"))
        #expect(md.contains("## 相位"))
        #expect(md.contains("## 接纳"))
        #expect(md.contains("赤纬"))
        #expect(md.contains("## 赤纬相位"))
        #expect(md.contains("## 固定星合相"))
        #expect(md.contains("Sirius"))
        #expect(md.contains("## 中世纪深化"))
        #expect(md.contains("Kurios"))
        #expect(md.contains("年主与 Solar Return"))
        #expect(md.contains("### 返照"))
        #expect(md.contains("太阳"))
    }

    @Test func classicalActiveOverviewSectionStaysDiagnostic() throws {
        let json = """
        {
            "meta": {
                "birth_utc": "1990-01-01T04:00:00",
                "reference_utc": "2026-05-05T04:00:00",
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
                {"id": "SUN", "name": "太阳", "longitude": 280.5, "sign": "摩羯", "degree_text": "10°30' 摩羯", "house": 10, "speed": 0.955, "motion": "顺行", "sect_status": "合昼派", "domicile": "", "exaltation": "", "triplicity": "昼主", "bound": "MERCURY", "decan": "VENUS", "solar_phase": "-", "accidental": "角宫", "score": 10, "notes": [], "score_breakdown": [], "bonification": [], "maltreatment": []}
            ],
            "lots": [],
            "aspects": [],
            "receptions": [],
            "antiscia": [],
            "primary_directions": [],
            "circumambulations": [],
            "timing": {
                "profection": {"age": 36, "house": 1, "sign": "白羊", "lord": "火星", "lord_condition": "", "start_local": "2026-01-01", "end_local": "2027-01-01", "activated_planets": [], "logic_steps": []},
                "firdaria": {"id": "firdaria-main", "technique": "Firdaria", "level": "主限", "ruler": "月亮", "start_local": "2026-01-01", "end_local": "2027-01-01", "notes": []},
                "decennials": {"id": "decennials", "technique": "Decennials", "level": "主限", "ruler": "太阳", "start_local": "2026-01-01", "end_local": "2027-01-01", "notes": []},
                "zodiacal_releasing": [],
                "timeline": []
            },
            "planetary_returns": [],
            "prenatal_syzygy": null,
            "almuten_figuris": null,
            "hyleg_alcocoden": null,
            "ambiguity": {
                "technique_rulers": {
                    "Annual Profection": "火星",
                    "Firdaria": "月亮"
                },
                "conflicting_signals": ["主技法主星不一致"],
                "confidence": "中"
            },
            "warnings": [],
            "calculation_assumptions": {
                "naibod_rate": 0.9856,
                "lunar_return_is_next_after_reference": true,
                "return_schema": "previous_return/current_cycle_return/next_return"
            }
        }
        """

        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder().decode(ClassicalResult.self, from: data)

        let md = MarkdownExportBuilder.classical(result, sections: [.activeOverview])

        #expect(md.contains("## 当前激活技法总览"))
        #expect(md.contains("### 技法主星汇总"))
        #expect(md.contains("- 置信度：中"))
        #expect(md.contains("### 计算假设"))
        #expect(md.contains("- naibod_rate：0.9856"))
        #expect(md.contains("- lunar_return_is_next_after_reference：true"))
        #expect(!md.contains("## 时间技法"))
    }

    @Test func transitResultMarkdown() throws {
        let json = """
        {
            "meta": {
                "natal_utc": "1990-01-01T04:00:00",
                "transit_utc": "2026-05-05T04:00:00",
                "ephemeris": "Swiss Ephemeris"
            },
            "natal_positions": [
                {"body_id": "SUN", "name": "太阳", "longitude": 280.5, "latitude": 0.0, "declination": -23.1, "out_of_bounds": false, "speed": 0.955, "sign": "摩羯", "degree_text": "10°30' 摩羯", "house": 10}
            ],
            "transit_positions": [
                {"body_id": "MOON", "name": "月亮", "longitude": 44.5, "latitude": 0.0, "declination": 24.2, "out_of_bounds": true, "speed": 13.0, "sign": "金牛", "degree_text": "14°30' 金牛", "house": 2}
            ],
            "angles": [],
            "houses": [],
            "lots": [],
            "aspects": [],
            "declination_aspects": [
                {"body1": "natal_SUN", "body2": "transit_MOON", "type": "contraparallel", "diff": 1.1, "declination1": -23.1, "declination2": 24.2}
            ],
            "natal_star_conjunctions": [
                {"planet": "SUN", "star": "Sirius", "star_mag": -1.46, "star_nature": "Mars/Jupiter", "star_keyword": "honor", "orb": 0.42}
            ],
            "transit_star_conjunctions": [
                {"planet": "MOON", "star": "Aldebaran", "star_mag": 0.87, "star_nature": "Mars", "star_keyword": "watcher", "orb": 0.31}
            ],
            "warnings": []
        }
        """

        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder().decode(TransitResult.self, from: data)

        let md = MarkdownExportBuilder.moment(result)

        #expect(md.contains("## 本命位置"))
        #expect(md.contains("## 行运位置"))
        #expect(md.contains("出界"))
        #expect(md.contains("## 赤纬相位"))
        #expect(md.contains("反平行"))
        #expect(md.contains("## 本命固定星合相"))
        #expect(md.contains("## 行运固定星合相"))
        #expect(md.contains("Aldebaran"))
        #expect(md.contains("太阳"))
        #expect(md.contains("月亮"))
    }
}
