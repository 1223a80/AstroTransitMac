import Foundation
import Testing
@testable import TransitStudio

struct RectifyResultTests {

    @Test func decodeRectifyResponse() throws {
        let json = """
        {
            "center_offset_index": 0,
            "total_candidates": 3,
            "window_seconds": 180,
            "window_minutes": 3,
            "candidates": [
                {
                    "offset_minutes": -1,
                    "offset_seconds": -60,
                    "birth_local": "1990-01-01 11:59",
                    "angles": {"ASC": {"longitude": 280.0}, "MC": {"longitude": 200.0}},
                    "planets_summary": [
                        {"id": "SUN", "name": "太阳", "longitude": 10.0, "sign": "摩羯", "house": 10}
                    ],
                    "primary_directions": [
                        {
                            "id": "pd-MARS-SUN-sextile",
                            "promissor": "火星",
                            "significator": "太阳",
                            "aspect_name": "六合",
                            "direction_type": "direct",
                            "age_from_abs_arc": 45.0,
                            "event_date_after_birth": "2035-01-01",
                            "note": "测试方向",
                            "tags": ["六合", "星体_SUN", "10宫", "direct"],
                            "houses_involved": [10, 7],
                            "shift_vs_center_days": 0.0
                        }
                    ]
                }
            ],
            "warnings": []
        }
        """

        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder().decode(RectifyResponse.self, from: data)

        #expect(result.totalCandidates == 3)
        #expect(result.windowMinutes == 3)
        #expect(result.candidates.count == 1)

        let first = result.candidates[0]
        #expect(first.offsetMinutes == -1)
        #expect(first.angles["ASC"]?.longitude == 280.0)
        #expect(first.planetsSummary?.count == 1)
        #expect(first.planetsSummary?[0].id == "SUN")
        #expect(first.primaryDirections.count == 1)
        #expect(first.primaryDirections[0].aspectName == "六合")
        #expect(first.primaryDirections[0].directionType == "direct")
        #expect(first.primaryDirections[0].tags.contains("direct"))
    }

    @Test func rectifyRequestEncoding() throws {
        let request = RectifyRequest(
            birthDate: "1990-01-01",
            centerTime: "12:00",
            timezone: "Asia/Shanghai",
            latitude: 31.2304,
            longitude: 121.4737,
            houseSystem: "whole_sign",
            zodiac: "tropical",
            boundsSystem: "egyptian",
            triplicitySystem: "dorothean",
            maxAge: 90,
            windowMinutes: 3,
            stepMinutes: 1
        )

        let data = try JSONEncoder().encode(request)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(dict["mode"] as? String == "rectify")
        #expect(dict["birth_date"] as? String == "1990-01-01")
        #expect(dict["center_time"] as? String == "12:00")
        #expect(dict["window_minutes"] as? Int == 3)
        #expect(dict["step_minutes"] as? Int == 1)
    }
}
