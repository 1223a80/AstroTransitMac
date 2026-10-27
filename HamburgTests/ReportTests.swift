import Foundation
import Testing
import HamburgCore

struct ReportTests {
    private func chart() -> HamburgChart {
        let points = [
            ChartPoint(id: "SUN", kind: .planet, longitude: 280.37),
            ChartPoint(id: "MOON", kind: .planet, longitude: 223.32),
            ChartPoint(id: "ASC", kind: .angle, longitude: 17.616),
            ChartPoint(id: "MC", kind: .angle, longitude: 281.058),
        ]
        return HamburgChart.addingTransneptunians(
            to: points,
            julianDayUT: 2_451_545.0,
            backendCusps: [
                17.616, 52.155, 78.015, 101.3, 127.0, 155.0,
                197.616, 232.155, 258.015, 281.058, 307.0, 335.0,
            ],
            houseAssignment: .hamburg,
            includeAriesPoint: true,
            solar: SolarReference(
                longitude: 280.37,
                latitude: 0,
                distanceAU: SolarEphemeris.distanceAU(julianDay: 2_451_545.0)
            )
        )
    }

    private func options() -> HamburgOptions {
        var options = HamburgOptions()
        options.solarArcEnabled = false
        options.antisciaEnabled = true
        options.focusPointIDs = ["SUN", "MOON"]
        return options
    }

    @Test func reportRoundTripsThroughJSONWithSnakeCaseKeys() throws {
        let report = HamburgEngine(options: options()).report(chart: chart())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(report)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"julian_day_ut\""))
        #expect(json.contains("\"midpoint_orb\""))
        #expect(json.contains("\"dial_modulus\""))
        #expect(json.contains("\"antiscia\""))
        #expect(json.contains("\"orb_dial\""))

        let decoded = try JSONDecoder().decode(HamburgReport.self, from: data)
        #expect(decoded.meta.engine == "HamburgCore")
        #expect(decoded.meta.method == "hamburg_uranian_v1")
        #expect(decoded.positions.count == report.positions.count)
        #expect(decoded.midpoints.count == report.midpoints.count)
        #expect(decoded.trees.count == report.trees.count)
        #expect(decoded.pictures.count == report.pictures.count)
    }

    @Test func markdownContainsCoreSections() {
        let report = HamburgEngine(options: options()).report(chart: chart())
        let markdown = HamburgMarkdownRenderer.render(report)
        #expect(markdown.contains("# 汉堡占星 / 乌拉尼亚计算报告"))
        #expect(markdown.contains("## 星体位置"))
        #expect(markdown.contains("## 八颗 TNP"))
        #expect(markdown.contains("## 中点树"))
        #expect(markdown.contains("## 行星图像"))
        #expect(markdown.contains("## 映点"))
        #expect(markdown.contains("## 方法与来源"))
    }

    @Test func backendHouseAssignmentUsesProvidedCusps() {
        let chart = chart()
        #expect(HamburgHouses.house(for: 17.616, cusps: chart.backendCusps) == 1)
        #expect(HamburgHouses.house(for: 300, cusps: chart.backendCusps) == 10)
        let backendChart = HamburgChart(
            julianDayUT: 2_451_545.0,
            points: [ChartPoint(id: "SUN", kind: .planet, longitude: 300)],
            backendCusps: chart.backendCusps,
            houseAssignment: .backend,
            includeAriesPoint: false
        )
        #expect(backendChart.houseAssignment == .backend)
        #expect(backendChart.points.first?.house == 10)
    }

    @Test func missingReferenceIsReportedWhenSolarArcEnabled() throws {
        var options = options()
        options.solarArcEnabled = true
        let report = HamburgEngine(options: options).report(chart: chart())
        #expect(report.solarArc == nil)
        #expect(report.warnings.contains { $0.contains("no reference moment") })
    }

    @Test func duplicatePointIDsAreRejectedWithWarning() {
        let chart = HamburgChart(
            julianDayUT: 0,
            points: [
                ChartPoint(id: "SUN", kind: .planet, longitude: 1),
                ChartPoint(id: "SUN", kind: .planet, longitude: 2),
            ],
            includeAriesPoint: false
        )
        #expect(chart.points.count == 1)
        #expect(chart.warnings.contains { $0.contains("Duplicate point id SUN") })
    }

    @Test func tnpReportCarriesKeywordsAndNativeSource() throws {
        let report = HamburgEngine(options: options()).report(chart: chart())
        let cupido = try #require(report.positions.first { $0.id == "CUPIDO" })
        #expect(cupido.kind == ChartPoint.Kind.transneptunian.rawValue)
        #expect(cupido.source == ChartPoint.Source.nativeTNP.rawValue)
        #expect(!cupido.keywords.isEmpty)
        #expect(!cupido.keywordsZh.isEmpty)
    }

    @Test func optionsRoundTripWithPatchedDefaults() throws {
        var options = HamburgOptions()
        options.dialModulus = 45
        options.orbUnit = .dial
        options.pictureOrb = 0.5
        let data = try JSONEncoder().encode(options)
        let decoded = try JSONDecoder().decode(HamburgOptions.self, from: data)
        #expect(decoded.dialModulus == 45)
        #expect(decoded.orbUnit == .dial)
        #expect(decoded.pictureOrb == 0.5)

        let partial = try JSONDecoder().decode(
            HamburgOptions.self,
            from: Data("{\"dial_modulus\":90}".utf8)
        )
        #expect(partial.dialModulus == 90)
        #expect(partial.orbUnit == .zodiac)
    }
}
