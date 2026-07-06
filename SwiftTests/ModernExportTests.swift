import Foundation
import Testing
@testable import TransitStudio

/// Guards the modern-mode export paths: Composite/Davison markdown must not be
/// empty, and every "保存 CSV" output must be a comma-separated table instead
/// of raw JSON. Fixtures are the same real backend outputs used by
/// BackendContractTests.
struct ModernExportTests {

    private func fixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
            "missing fixture \(name).json"
        )
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }

    private func expectCSVTable(_ csv: String, header: String, minRows: Int) {
        let lines = csv.split(separator: "\n")
        #expect(lines.first.map(String.init) == header)
        #expect(lines.count >= minRows)
        #expect(!csv.hasPrefix("{"), "CSV export must not be JSON")
    }

    private let modernHeader = "section,name,longitude,degree_text,latitude,speed,aspect_or_house,other,separation,orb"

    @Test func compositeExports() throws {
        let result = try fixture("composite-result", as: CompositeResult.self)

        let markdown = MarkdownModernExportBuilder.compositeOrDavison(title: "Composite", result: result)
        #expect(markdown.contains("# Composite 盘"))
        #expect(markdown.contains("## 行星位置"))

        let json = TextExportBuilder.json(result)
        #expect(json.contains("\"planets\""))

        expectCSVTable(TextExportBuilder.csv(result), header: modernHeader, minRows: 1 + result.planets.count)
    }

    @Test func davisonExports() throws {
        let result = try fixture("davison-result", as: DavisonResult.self)

        let markdown = MarkdownModernExportBuilder.compositeOrDavison(title: "Davison", result: result)
        #expect(markdown.contains("# Davison 盘"))

        let json = TextExportBuilder.json(result)
        #expect(json.contains("\"planets\""))

        expectCSVTable(TextExportBuilder.csv(result), header: modernHeader, minRows: 1 + result.planets.count)
    }

    @Test func synastryCSV() throws {
        let result = try fixture("synastry-result", as: SynastryResult.self)
        let csv = TextExportBuilder.csv(result)
        expectCSVTable(csv, header: modernHeader, minRows: 1 + result.personAPlanets.count + result.personBPlanets.count + result.crossAspects.count)
        #expect(csv.contains("cross_aspect,"))
    }

    @Test func progressionCSV() throws {
        let result = try fixture("progressions-result", as: ProgressionResult.self)
        let csv = TextExportBuilder.csv(result)
        expectCSVTable(csv, header: modernHeader, minRows: 1 + result.natalPlanets.count + result.progressedPlanets.count)
        #expect(csv.contains("prog_to_natal_aspect,"))
    }

    @Test func solarArcCSV() throws {
        let result = try fixture("solar-arc-result", as: SolarArcResult.self)
        let csv = TextExportBuilder.csv(result)
        expectCSVTable(csv, header: modernHeader, minRows: 2 + result.natalPlanets.count + result.solarArcPlanets.count)
        #expect(csv.contains("arc_value,"))
    }

    @Test func harmonicCSV() throws {
        let planets = try fixture("composite-result", as: CompositeResult.self).planets
        let result = HarmonicResult(
            meta: ModernMeta(method: "harmonic", personAUTC: nil, personBUTC: nil, natalUTC: nil, progressedUTC: nil, ephemeris: nil),
            planets: planets,
            angles: [],
            houses: [],
            housesExperimental: nil,
            aspects: [],
            warnings: [],
            harmonicOrder: 5,
            sectionErrors: nil
        )
        let csv = TextExportBuilder.csv(result)
        expectCSVTable(csv, header: modernHeader, minRows: 2 + planets.count)
        #expect(csv.contains("harmonic_order,H5"))
    }
}
