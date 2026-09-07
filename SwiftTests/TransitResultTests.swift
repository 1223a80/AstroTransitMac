import Foundation
import Testing
@testable import TransitStudio

struct TransitResultTests {

    @Test func positionStillRejectsMalformedSpeed() {
        let json = #"{"body_id":"SUN","name":"太阳","longitude":0,"latitude":0,"speed":"invalid","sign":"白羊","degree_text":"0°","house":1}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PositionRow.self, from: Data(json.utf8))
        }
    }

    @Test func unavailableSpeedDoesNotExportAsZero() throws {
        let json = #"{"body_id":"SUN","name":"太阳","longitude":0,"latitude":0,"speed":null,"sign":"白羊","degree_text":"0°","house":1}"#
        let position = try JSONDecoder().decode(PositionRow.self, from: Data(json.utf8))
        #expect(position.speed == nil)
        #expect(position.solarArcRateDegPerYear == nil)
        let section = MarkdownExportBuilder.positionSection("位置", [position]).joined(separator: "\n")
        #expect(section.contains("| — |"))
        #expect(!section.contains("/日"))
    }

    @Test func decodeTransitResult() throws {
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
                {"body_id": "SUN", "name": "太阳", "longitude": 44.5, "latitude": 0.0, "speed": 0.955, "sign": "金牛", "degree_text": "14°30' 金牛", "house": 2}
            ],
            "angles": [],
            "houses": [],
            "lots": [],
            "aspects": [
                {"id": "SUN|square|SUN|34.0", "transit_body_id": "SUN", "transit_body_name": "太阳", "natal_body_id": "SUN", "natal_body_name": "太阳", "aspect_id": "square", "aspect_name": "刑相", "angle": 90.0, "separation": 124.0, "orb": 34.0}
            ],
            "warnings": []
        }
        """

        let data = try #require(json.data(using: .utf8))
        let result = try JSONDecoder().decode(TransitResult.self, from: data)

        #expect(result.meta.natalUTC == "1990-01-01T04:00:00")
        #expect(result.meta.transitUTC == "2026-05-05T04:00:00")
        #expect(result.natalPositions.count == 1)
        #expect(result.transitPositions.count == 1)
        #expect(result.natalPositions[0].bodyID == "SUN")
        #expect(result.transitPositions[0].bodyID == "SUN")
        #expect(result.aspects.count == 1)
        #expect(result.aspects[0].aspectID == "square")
        #expect(result.warnings.isEmpty)
    }

    @Test func resultMetaDecoding() throws {
        let json = """
        {"natal_utc": "2020-01-01T00:00:00", "transit_utc": "2020-06-01T00:00:00", "ephemeris": "Swiss Ephemeris"}
        """
        let data = try #require(json.data(using: .utf8))
        let meta = try JSONDecoder().decode(ResultMeta.self, from: data)
        #expect(meta.natalUTC == "2020-01-01T00:00:00")
    }
}
