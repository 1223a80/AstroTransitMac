import Foundation
import Testing
@testable import TransitStudio

struct ModernRequestEncodingTests {
    private let birth = BirthSettings(
        moment: ChartMoment(year: 1990, month: 1, day: 1, hour: 12, minute: 0, timezone: "Asia/Shanghai"),
        latitude: 31.2304,
        longitude: 121.4737,
        houseSystem: "placidus",
        zodiac: "sidereal_lahiri",
        boundsSystem: "egyptian",
        triplicitySystem: "dorothean"
    )

    private let reference = ChartMoment(year: 2026, month: 6, day: 2, hour: 12, minute: 0, timezone: "Asia/Shanghai")
    private let aspects = [
        AspectRequest(id: "conjunction", name: "合相", angle: 0, orb: 6)
    ]

    @Test func modernTimingNatalRequestKeepsTopLevelTargetAndOmitsTargetChart() throws {
        let pointSet = ModernPointSet(
            bodyIDs: ["SUN", "MOON"],
            includeNodes: false,
            nodeMode: "true_node",
            customAsteroids: [],
            angleIDs: ["ASC"]
        )
        let request = ModernTimingRequest(
            birth: birth,
            start: reference,
            end: ChartMoment(year: 2026, month: 7, day: 2, hour: 12, minute: 0, timezone: "Asia/Shanghai"),
            displayTimezone: "Asia/Shanghai",
            targetPointSet: pointSet,
            techniques: [ModernTimingTechniqueRequest(id: "transit", movingBodyIDs: ["SATURN"], eventTypes: ["aspect"], aspects: aspects)]
        )

        let dict = try encodedDictionary(request)

        #expect(dict["target_chart"] == nil)
        #expect(dict["target_point_set"] is [String: Any])
    }

    @Test func modernTimingRelationshipUsesNestedPointSetAndPreservesChartSettings() throws {
        let pointSet = ModernPointSet(
            bodyIDs: ["SUN", "MOON"],
            includeNodes: false,
            nodeMode: "true_node",
            customAsteroids: [],
            angleIDs: ["ASC", "MC"]
        )
        let personA = PersonSettings(name: "A", moment: birth.moment, latitude: birth.latitude, longitude: birth.longitude)
        let personB = PersonSettings(name: "B", moment: reference, latitude: 40.7128, longitude: -74.0060)
        let targetChart = ModernTimingTargetChart(
            type: "composite",
            personA: personA,
            personB: personB,
            pointSet: pointSet,
            houseSystem: "placidus",
            zodiac: "sidereal_lahiri"
        )
        let request = ModernTimingRequest(
            birth: birth,
            start: reference,
            end: ChartMoment(year: 2026, month: 7, day: 2, hour: 12, minute: 0, timezone: "Asia/Shanghai"),
            displayTimezone: "Asia/Shanghai",
            targetPointSet: nil,
            targetChart: targetChart,
            techniques: [ModernTimingTechniqueRequest(id: "transit", movingBodyIDs: ["SATURN"], eventTypes: ["aspect"], aspects: aspects)]
        )

        let dict = try encodedDictionary(request)
        let encodedTarget = try #require(dict["target_chart"] as? [String: Any])

        #expect(dict["target_point_set"] == nil)
        #expect(encodedTarget["type"] as? String == "composite")
        #expect(encodedTarget["person_a"] is [String: Any])
        #expect(encodedTarget["person_b"] is [String: Any])
        #expect(encodedTarget["house_system"] as? String == "placidus")
        #expect(encodedTarget["zodiac"] as? String == "sidereal_lahiri")
        #expect(encodedTarget["point_set"] is [String: Any])

        let defaultTargetChart = ModernTimingTargetChart(
            type: "davison",
            personA: personA,
            personB: personB,
            pointSet: pointSet
        )
        let defaultRequest = ModernTimingRequest(
            birth: birth,
            start: reference,
            end: reference,
            displayTimezone: "Asia/Shanghai",
            targetPointSet: nil,
            targetChart: defaultTargetChart,
            techniques: []
        )
        let defaultTarget = try #require(try encodedDictionary(defaultRequest)["target_chart"] as? [String: Any])
        #expect(defaultTarget["house_system"] == nil)
        #expect(defaultTarget["zodiac"] == nil)
    }

    @Test func progressionRequestEncodesTopLevelChartSettings() throws {
        let request = ProgressionRequest(
            mode: "progression",
            birth: birth,
            reference: reference,
            houseSystem: birth.houseSystem,
            zodiac: birth.zodiac,
            nodeMode: "true_node",
            aspects: aspects,
            ephemerisPath: nil,
            noAsteroids: false,
            requireEphemeris: "warn"
        )

        let dict = try encodedDictionary(request)

        #expect(dict["house_system"] as? String == "placidus")
        #expect(dict["zodiac"] as? String == "sidereal_lahiri")
    }

    @Test func solarArcRequestEncodesTopLevelChartSettings() throws {
        let request = SolarArcRequest(
            mode: "solar_arc",
            birth: birth,
            reference: reference,
            houseSystem: birth.houseSystem,
            zodiac: birth.zodiac,
            nodeMode: "true_node",
            aspects: aspects,
            patternsEnabled: false,
            ephemerisPath: nil,
            noAsteroids: false,
            requireEphemeris: "warn"
        )

        let dict = try encodedDictionary(request)

        #expect(dict["house_system"] as? String == "placidus")
        #expect(dict["zodiac"] as? String == "sidereal_lahiri")
    }

    @Test func harmonicRequestEncodesTopLevelChartSettings() throws {
        let request = HarmonicRequest(
            mode: "harmonic",
            birth: birth,
            harmonicOrder: 9,
            houseSystem: birth.houseSystem,
            zodiac: birth.zodiac,
            nodeMode: "true_node",
            aspects: aspects,
            ephemerisPath: nil,
            noAsteroids: false,
            requireEphemeris: "warn"
        )

        let dict = try encodedDictionary(request)

        #expect(dict["house_system"] as? String == "placidus")
        #expect(dict["zodiac"] as? String == "sidereal_lahiri")
    }

    @Test func modernReturnRequestEncodesExactReturnContract() throws {
        let request = ModernReturnRequest(
            returnBodyID: "MOON",
            birth: birth,
            reference: reference,
            locationSource: "birth",
            houseSystem: "placidus",
            zodiac: "sidereal_lahiri",
            nodeMode: "true_node",
            pointSet: ModernPointSet(
                bodyIDs: ["SUN", "MOON"],
                includeNodes: true,
                nodeMode: "true_node",
                customAsteroids: [],
                angleIDs: ["ASC", "MC"]
            ),
            aspects: aspects,
            precessionCorrection: "none",
            ephemerisPath: nil,
            noAsteroids: false,
            requireEphemeris: "warn"
        )

        let dict = try encodedDictionary(request)

        #expect(dict["mode"] as? String == "modern_return")
        #expect(dict["return_body_id"] as? String == "MOON")
        #expect(dict["location_source"] as? String == "birth")
        #expect(dict["precession_correction"] as? String == "none")
        #expect(dict["reference"] is [String: Any])
    }

    @Test func midpointRequestEncodesCanonicalPairFreeStandaloneContract() throws {
        let request = MidpointRequest(
            birth: birth,
            reference: nil,
            pointSet: ModernPointSet(
                bodyIDs: ["SUN", "MOON", "MARS"],
                includeNodes: false,
                nodeMode: "true_node",
                customAsteroids: [],
                angleIDs: ["ASC", "MC"]
            ),
            focusPointIDs: ["SUN", "MOON", "ASC", "MC"],
            activationSources: ["natal", "transit", "secondary_progression", "solar_arc"]
        )

        let dict = try encodedDictionary(request)

        #expect(dict["mode"] as? String == "midpoint")
        #expect(dict["reference"] == nil)
        #expect(dict["modulus"] as? Int == 360)
        #expect(dict["activation_orb"] as? Double == 1.0)
        #expect(dict["include_opposite_axis"] as? Bool == true)
        #expect(dict["focus_point_ids"] as? [String] == ["SUN", "MOON", "ASC", "MC"])
    }

    @Test func midpointPairRequestCanonicalizesEndpointOrder() throws {
        let pointSet = ModernPointSet(
            bodyIDs: [],
            includeNodes: false,
            nodeMode: "true_node",
            customAsteroids: [],
            angleIDs: [],
            midpointPairs: [MidpointPairRequest(pointAID: "SUN", pointBID: "MOON")]
        )
        let dict = try encodedDictionary(pointSet)
        let pairs = try #require(dict["midpoint_pairs"] as? [[String: Any]])

        #expect(pairs.first?["point_a_id"] as? String == "MOON")
        #expect(pairs.first?["point_b_id"] as? String == "SUN")
    }

    @Test func ordinaryPointSetOmitsMidpointPairsWhenUnused() throws {
        let pointSet = ModernPointSet(
            bodyIDs: ["SUN"],
            includeNodes: false,
            nodeMode: "true_node",
            customAsteroids: [],
            angleIDs: ["ASC"]
        )
        let dict = try encodedDictionary(pointSet)

        #expect(dict["midpoint_pairs"] == nil)
    }

    private func encodedDictionary<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
