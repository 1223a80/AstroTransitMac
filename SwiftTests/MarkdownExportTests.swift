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
                {"id": "SUN", "name": "太阳", "longitude": 280.5, "sign": "摩羯", "degree_text": "10°30' 摩羯", "house": 10, "speed": 0.955, "motion": "顺行", "sect_status": "合昼派", "domicile": "", "exaltation": "", "triplicity": "昼主", "bound": "MERCURY", "decan": "VENUS", "solar_phase": "-", "accidental": "角宫", "score": 10, "notes": [], "score_breakdown": [], "bonification": [], "maltreatment": []}
            ],
            "lots": [],
            "aspects": [],
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
                {"body_id": "SUN", "name": "太阳", "longitude": 280.5, "latitude": 0.0, "speed": 0.955, "sign": "摩羯", "degree_text": "10°30' 摩羯", "house": 10}
            ],
            "transit_positions": [
                {"body_id": "MOON", "name": "月亮", "longitude": 44.5, "latitude": 0.0, "speed": 13.0, "sign": "金牛", "degree_text": "14°30' 金牛", "house": 2}
            ],
            "angles": [],
            "houses": [],
            "lots": [],
            "aspects": [],
            "warnings": []
        }
        """

        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder().decode(TransitResult.self, from: data)

        let md = MarkdownExportBuilder.moment(result)

        #expect(md.contains("## 本命位置"))
        #expect(md.contains("## 行运位置"))
        #expect(md.contains("太阳"))
        #expect(md.contains("月亮"))
    }
}
