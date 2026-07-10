import Foundation
import Testing
@testable import TransitStudio

/// Decodes real backend output captured from `Examples/sample-*-request.json`
/// runs. These fixtures guard the Swift <-> Python contract: if a backend
/// field is renamed or removed, the corresponding decode test fails instead
/// of the app showing a silently blank page.
///
/// To regenerate a fixture:
/// `python3 Sources/TransitStudio/Resources/backend/transit_calc.py \
///     < Examples/sample-<mode>-request.json > SwiftTests/Fixtures/<mode>-result.json`
struct BackendContractTests {

    private func fixtureData(_ name: String) throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
            "missing fixture \(name).json"
        )
        return try Data(contentsOf: url)
    }

    @Test func decodeVedicResult() throws {
        let result = try JSONDecoder().decode(VedicResult.self, from: fixtureData("vedic-result"))

        let planets = try #require(result.planets)
        #expect(!planets.isEmpty)
        let navamsa = try #require(result.navamsa)
        #expect(!navamsa.isEmpty)
        #expect(result.rasiChart != nil)
        #expect(result.vimshottari != nil)
        #expect(result.panchanga != nil)
        let divisionals = try #require(result.divisionalCharts)
        #expect(!divisionals.isEmpty)
        #expect(result.ashtakavarga != nil)
        #expect(result.shadbala?.isEmpty == false)
        #expect(result.jaiminiKarakas != nil)
        #expect(result.arudha?.isEmpty == false)
        #expect(result.planetRelationships != nil)
        #expect(result.moonChart != nil)
        #expect(result.bhavaChart != nil)
        #expect(result.meta.ayanamshaName?.isEmpty == false)
    }

    @Test func decodeSynastryResult() throws {
        let result = try JSONDecoder().decode(SynastryResult.self, from: fixtureData("synastry-result"))

        #expect(!result.personAPlanets.isEmpty)
        #expect(!result.personBPlanets.isEmpty)
        #expect(!result.crossAspects.isEmpty)
        #expect(!result.aInBHouses.isEmpty)
        #expect(!result.bInAHouses.isEmpty)
    }

    @Test func decodeCompositeResult() throws {
        let result = try JSONDecoder().decode(CompositeResult.self, from: fixtureData("composite-result"))
        #expect(!result.planets.isEmpty)
        #expect(result.meta.personAUTC?.isEmpty == false)
        #expect(result.meta.personBUTC?.isEmpty == false)
    }

    @Test func decodeDavisonResult() throws {
        let result = try JSONDecoder().decode(DavisonResult.self, from: fixtureData("davison-result"))
        #expect(!result.planets.isEmpty)
    }

    @Test func decodeProgressionResult() throws {
        let result = try JSONDecoder().decode(ProgressionResult.self, from: fixtureData("progressions-result"))

        #expect(!result.natalPlanets.isEmpty)
        #expect(!result.progressedPlanets.isEmpty)
        #expect(!result.progressedToNatalAspects.isEmpty)
    }

    @Test func decodeSolarArcResult() throws {
        let result = try JSONDecoder().decode(SolarArcResult.self, from: fixtureData("solar-arc-result"))

        #expect(!result.natalPlanets.isEmpty)
        #expect(!result.solarArcPlanets.isEmpty)
        #expect(result.arcValue != 0)
        #expect(result.solarArcPlanets.contains { $0.bodyID == "TRUE_NODE" })
        #expect(result.patterns?.isEmpty == false)
    }

    @Test func decodeHarmonicResult() throws {
        let result = try JSONDecoder().decode(HarmonicResult.self, from: fixtureData("harmonic-result"))
        #expect(result.harmonicOrder == 4)
        #expect(!result.planets.isEmpty)
        #expect(!result.houses.isEmpty)
    }

    @Test func decodeHoraryResultFromRealOutput() throws {
        let result = try JSONDecoder().decode(HoraryResult.self, from: fixtureData("horary-result"))

        #expect(!result.planets.isEmpty)
        #expect(!result.houses.isEmpty)
    }
}
