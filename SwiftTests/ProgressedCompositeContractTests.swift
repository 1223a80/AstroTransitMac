import Foundation
import Testing
@testable import TransitStudio

struct ProgressedCompositeContractTests {
    @Test func requestEncodesExactPersonReferenceAndPlanetPointSet() throws {
        let pointSet = ModernPointSet(
            bodyIDs: ["SUN", "MOON", "MERCURY"],
            includeNodes: false,
            nodeMode: "true_node",
            customAsteroids: [],
            angleIDs: [],
            houseCusps: [],
            lotIDs: []
        )
        let request = ProgressedCompositeRequest(
            personA: person("A", timezone: "Asia/Shanghai", latitude: 31.2304, longitude: 121.4737),
            personB: person("B", timezone: "America/New_York", latitude: 40.7128, longitude: -74.0060),
            reference: ChartMoment(year: 2026, month: 7, day: 13, hour: 12, minute: 0, timezone: "UTC"),
            pointSet: pointSet,
            zodiac: "tropical",
            nodeMode: "true_node",
            aspects: [AspectRequest(id: "conjunction", name: "合相", angle: 0, orb: 1)]
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let encodedPointSet = try #require(object["point_set"] as? [String: Any])

        #expect(object["mode"] as? String == "progressed_composite")
        #expect(object["person_a"] is [String: Any])
        #expect(object["person_b"] is [String: Any])
        #expect(object["reference"] is [String: Any])
        #expect(encodedPointSet["angle_ids"] as? [String] == [])
        #expect(encodedPointSet["house_cusps"] as? [Int] == [])
        #expect(encodedPointSet["lot_ids"] as? [String] == [])
    }

    @Test func decodesTraceReencodesAndExportsAllAuditScalars() throws {
        let result = try JSONDecoder().decode(
            ProgressedCompositeResult.self,
            from: Data(Self.fixtureJSON.utf8)
        )
        let progressed = try #require(result.progressedCompositePlanets.first)
        let trace = progressed.trace

        #expect(result.meta.method == "progress_each_person_then_midpoint")
        #expect(result.meta.schemaVersion == 1)
        #expect(result.meta.zodiac == "tropical")
        #expect(result.meta.personABirthUTC == "1990-01-01T04:00:00+00:00")
        #expect(result.meta.personBProgressedUTC == "1992-06-15T12:31:00+00:00")
        #expect(result.meta.personAAgeYears == 36.5)
        #expect(result.meta.personBAgeYears == 34.0)
        #expect(trace.personAInputLongitude == 10.0)
        #expect(trace.personBInputLongitude == 190.0)
        #expect(trace.compositeLongitude == 280.0)

        let json = TextExportBuilder.progressedCompositeJSON(result)
        let roundTripped = try JSONDecoder().decode(ProgressedCompositeResult.self, from: Data(json.utf8))
        let roundTrippedTrace = try #require(roundTripped.progressedCompositePlanets.first).trace
        #expect(roundTrippedTrace.personAInputLongitude == trace.personAInputLongitude)
        #expect(roundTrippedTrace.personBInputLongitude == trace.personBInputLongitude)
        #expect(roundTrippedTrace.compositeLongitude == trace.compositeLongitude)
        #expect(json.contains("\"person_a\""))
        #expect(json.contains("\"input_longitude\""))
        #expect(!json.contains("\"houses\""))
        #expect(!json.contains("\"angles\""))

        let markdown = MarkdownExportBuilder.progressedComposite(result)
        let csv = TextExportBuilder.csv(result)
        #expect(markdown.contains("progress_each_person_then_midpoint"))
        #expect(markdown.contains("1990-01-01T04:00:00+00:00"))
        #expect(markdown.contains("10.00000000"))
        #expect(markdown.contains("190.00000000"))
        #expect(markdown.contains("circular_midpoint"))
        #expect(csv.hasPrefix("row_type,body_id,name,longitude,degree_text,person_a_birth_utc"))
        #expect(csv.contains("person_a_input_longitude,person_b_input_longitude,composite_longitude"))
        #expect(csv.contains("person_a_age_years,person_b_age_years"))
        #expect(csv.contains("36.50000000,34.00000000"))
        #expect(csv.contains("zodiac,ephemeris,effective_point_ids,effective_node_mode,effective_custom_asteroids"))
        #expect(csv.contains("10.00000000,190.00000000,280.00000000"))
        #expect(csv.contains("trace_phase,midpoint_method"))
        #expect(csv.contains("progressed,circular_midpoint"))
        #expect(csv.contains("progressed_to_radix_aspect"))
    }

    @Test func rejectsMissingRequiredTraceOrResultArray() throws {
        var object = try #require(
            JSONSerialization.jsonObject(with: Data(Self.fixtureJSON.utf8))
                as? [String: Any]
        )
        var progressed = try #require(object["progressed_composite_planets"] as? [[String: Any]])
        progressed[0].removeValue(forKey: "trace")
        object["progressed_composite_planets"] = progressed
        let missingTrace = try JSONSerialization.data(withJSONObject: object)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ProgressedCompositeResult.self, from: missingTrace)
        }

        object = try #require(
            JSONSerialization.jsonObject(with: Data(Self.fixtureJSON.utf8))
                as? [String: Any]
        )
        object.removeValue(forKey: "radix_composite_planets")
        let missingArray = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(ProgressedCompositeResult.self, from: missingArray)
        }
    }

    private func person(_ name: String, timezone: String, latitude: Double, longitude: Double) -> PersonSettings {
        PersonSettings(
            name: name,
            moment: ChartMoment(year: 1990, month: 1, day: 1, hour: 12, minute: 0, timezone: timezone),
            latitude: latitude,
            longitude: longitude
        )
    }

    private static let fixtureJSON = #"""
    {
      "meta": {
        "schema_version": 1,
        "method": "progress_each_person_then_midpoint",
        "zodiac": "tropical",
        "person_a_birth_utc": "1990-01-01T04:00:00+00:00",
        "person_b_birth_utc": "1992-06-15T12:30:00+00:00",
        "person_a_progressed_utc": "1990-02-01T04:00:00+00:00",
        "person_b_progressed_utc": "1992-06-15T12:31:00+00:00",
        "person_a_age_years": 36.5,
        "person_b_age_years": 34.0,
        "reference_utc": "2026-07-13T04:00:00+00:00",
        "effective_point_set": {
          "body_ids": ["SUN"],
          "include_nodes": false,
          "node_mode": "true_node",
          "custom_asteroids": [],
          "angle_ids": [],
          "house_cusps": [],
          "lot_ids": []
        },
        "ephemeris": "Swiss Ephemeris"
      },
      "radix_composite_planets": [
        {
          "body_id": "SUN", "name": "太阳", "longitude": 100.0, "latitude": 0.0, "speed": 1.0, "sign": "巨蟹", "degree_text": "10°00'00\"",
          "trace": {
            "phase": "radix",
            "midpoint_method": "circular_midpoint",
            "reference_utc": "2026-07-13T04:00:00+00:00",
            "person_a": {
              "birth_utc": "1990-01-01T04:00:00+00:00",
              "progressed_utc": "1990-01-01T04:00:00+00:00",
              "input_longitude": 90.0
            },
            "person_b": {
              "birth_utc": "1992-06-15T12:30:00+00:00",
              "progressed_utc": "1992-06-15T12:30:00+00:00",
              "input_longitude": 110.0
            },
            "composite_longitude": 100.0
          }
        }
      ],
      "progressed_composite_planets": [
        {
          "body_id": "SUN", "name": "太阳", "longitude": 280.0, "latitude": 0.0, "speed": 1.0, "sign": "摩羯", "degree_text": "10°00'00\"",
          "trace": {
            "phase": "progressed",
            "midpoint_method": "circular_midpoint",
            "reference_utc": "2026-07-13T04:00:00+00:00",
            "person_a": {
              "birth_utc": "1990-01-01T04:00:00+00:00",
              "progressed_utc": "1990-02-01T04:00:00+00:00",
              "input_longitude": 10.0
            },
            "person_b": {
              "birth_utc": "1992-06-15T12:30:00+00:00",
              "progressed_utc": "1992-06-15T12:31:00+00:00",
              "input_longitude": 190.0
            },
            "composite_longitude": 280.0
          }
        }
      ],
      "progressed_to_radix_aspects": [
        {
          "id": "SUN|conjunction|SUN",
          "transit_body_id": "SUN",
          "transit_body_name": "太阳",
          "natal_body_id": "SUN",
          "natal_body_name": "太阳",
          "aspect_id": "conjunction",
          "aspect_name": "合相",
          "angle": 0.0,
          "separation": 0.0,
          "orb": 0.0
        }
      ],
      "warnings": [],
      "section_errors": null
    }
    """#
}
