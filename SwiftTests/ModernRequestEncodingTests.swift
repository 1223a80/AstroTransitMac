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

    private func encodedDictionary<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
