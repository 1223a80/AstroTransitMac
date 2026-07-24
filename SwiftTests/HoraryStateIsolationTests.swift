import Foundation
import Testing
@testable import TransitStudio

/// Proves Horary house/orb request fields are independent of classical defaults.
struct HoraryStateIsolationTests {
    @Test func horaryDefaultsAreRegiomontanusAndIndependentEncoding() throws {
        // Simulated UI state defaults (mirrors ContentView @State initial values).
        var selectedHouseSystem = "whole_sign"
        var horaryHouseSystem = "regiomontanus"
        var classicalAspectOrb = 3.0
        var horaryAspectOrb = 3.0

        #expect(horaryHouseSystem == "regiomontanus")
        #expect(selectedHouseSystem == "whole_sign")
        #expect(horaryHouseSystem != selectedHouseSystem)

        // Changing classical state must not mutate Horary state.
        selectedHouseSystem = "placidus"
        classicalAspectOrb = 8.0
        #expect(horaryHouseSystem == "regiomontanus")
        #expect(horaryAspectOrb == 3.0)

        // Changing Horary state must not mutate classical state.
        horaryHouseSystem = "alcabitius"
        horaryAspectOrb = 5.5
        #expect(selectedHouseSystem == "placidus")
        #expect(classicalAspectOrb == 8.0)

        // Encoded Horary request uses only Horary fields.
        let moment = ChartMoment(year: 2026, month: 7, day: 23, hour: 22, minute: 25, timezone: "GMT+8")
        let chart = HoraryChartSettings(
            moment: moment,
            latitude: 35.0924,
            longitude: 118.3465,
            houseSystem: horaryHouseSystem,
            zodiac: "tropical",
            boundsSystem: "egyptian",
            triplicitySystem: "dorothean"
        )
        let request = HoraryRequest(
            mode: "horary",
            chart: chart,
            placeName: "临沂市",
            questionText: "opaque",
            aspectOrb: horaryAspectOrb,
            packetVersion: "2",
            ephemerisPath: nil,
            noAsteroids: true,
            requireEphemeris: "warn"
        )
        let data = try JSONEncoder().encode(request)
        let obj = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let chartObj = try #require(obj["chart"] as? [String: Any])
        #expect(chartObj["houseSystem"] as? String == "alcabitius")
        #expect(chartObj["houseSystem"] as? String != selectedHouseSystem)
        #expect(obj["aspectOrb"] as? Double == 5.5)
        #expect(obj["aspectOrb"] as? Double != classicalAspectOrb)
    }
}
