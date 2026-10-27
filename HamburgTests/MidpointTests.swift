import Foundation
import Testing
import HamburgCore

struct MidpointTests {
    private func makeChart(_ values: [(String, Double)], includeAries: Bool = false) -> HamburgChart {
        let points = values.map {
            ChartPoint(
                id: $0.0,
                kind: $0.0.contains("NODE") ? .node : .planet,
                longitude: $0.1,
                source: .user
            )
        }
        return HamburgChart(
            julianDayUT: 2_451_545.0,
            points: points,
            includeAriesPoint: includeAries
        )
    }

    private func options(dial: Double = 360, orb: Double = 0.1) -> HamburgOptions {
        var options = HamburgOptions()
        options.dialModulus = dial
        options.midpointOrb = orb
        options.pictureOrb = orb
        options.antisciaEnabled = false
        options.solarArcEnabled = false
        options.focusPointIDs = ["SUN"]
        options.displayDials = [360, dial]
        options.maxHitsPerTree = 50
        return options
    }

    @Test func circularMidpointAcrossZeroAndOpposition() {
        #expect(abs(Angle.midpoint(10, 30) - 20) < 1e-12)
        #expect(abs(Angle.midpoint(350, 10)) < 1e-12)
        #expect(abs(Angle.midpoint(0, 180) - 90) < 1e-12)
        #expect(abs(Angle.midpoint(180, 0) - 270) < 1e-12)
        #expect(abs(Angle.separation(359, 1) - 2) < 1e-12)
        #expect(abs(Angle.fold(370, modulus: 90) - 10) < 1e-12)
        #expect(abs(Angle.dialDistance(0, 90, modulus: 90)) < 1e-12)
        #expect(abs(Angle.dialDistance(0, 45, modulus: 90) - 45) < 1e-12)
    }

    @Test func dialProximityCollapsesHardAspects() {
        let exact = DialMath.proximity(longitude: 95, axis: 5, modulus: 90)
        #expect(exact.distance < 1e-12)
        #expect(exact.harmonic == 1)
        #expect(exact.branch == "opposite")

        let near = DialMath.proximity(longitude: 100, axis: 5, modulus: 90)
        #expect(abs(near.distance - 5) < 1e-12)
        #expect(near.harmonic == 1)

        let opposition = DialMath.proximity(longitude: 185, axis: 5, modulus: 90)
        #expect(opposition.distance < 1e-12)
        #expect(opposition.harmonic == 2)
        #expect(opposition.branch == "direct")
    }

    @Test func midpointTreeFindsExactAxis() throws {
        let chart = makeChart([("SUN", 10), ("MOON", 30), ("VENUS", 350), ("MARS", 100)])
        let report = HamburgEngine(options: options()).report(chart: chart)
        let tree = try #require(report.trees.first { $0.focus == "SUN" })
        let hit = try #require(tree.hits.first { $0.axisID == "midpoint|MOON|VENUS" })
        #expect(hit.formula == "SUN = MOON/VENUS")
        #expect(hit.orbDial < 1e-9)
        #expect(hit.harmonic == 0)
    }

    @Test func ninetyDegreeDialAcceptsSquareToMidpoint() throws {
        let chart = makeChart([("SUN", 100), ("MOON", 30), ("VENUS", 350), ("MARS", 200)])
        let report = HamburgEngine(options: options(dial: 90)).report(chart: chart)
        let tree = try #require(report.trees.first { $0.focus == "SUN" })
        let hit = try #require(tree.hits.first { $0.axisID == "midpoint|MOON|VENUS" })
        #expect(hit.harmonic == 1)
        #expect(hit.branch == "opposite")
        #expect(hit.orbDial < 1e-9)
    }

    @Test func axesAreCompleteAndCanonical() {
        let chart = makeChart([
            ("SUN", 0), ("MOON", 30), ("VENUS", 60), ("MARS", 90), ("JUPITER", 120),
        ])
        let report = HamburgEngine(options: options()).report(chart: chart)
        #expect(report.midpoints.count == 10)
        #expect(Set(report.midpoints.map(\.id)).count == 10)
        #expect(report.midpoints.allSatisfy { $0.pointA < $0.pointB })
        #expect(report.midpoints.allSatisfy { abs($0.direct - Angle.normalize($0.opposite - 180)) < 1e-9 })
    }

    @Test func hamburgHouseAssignmentUsesLibraStart() {
        #expect(HamburgHouses.house(for: 180, cusps: HamburgHouses.hamburgCusps) == 1)
        #expect(HamburgHouses.house(for: 179.999, cusps: HamburgHouses.hamburgCusps) == 12)
        #expect(HamburgHouses.house(for: 0, cusps: HamburgHouses.hamburgCusps) == 7)
        #expect(HamburgHouses.house(for: 210, cusps: HamburgHouses.hamburgCusps) == 2)
        #expect(HamburgHouses.house(for: 330, cusps: HamburgHouses.hamburgCusps) == 6)
    }

    @Test func nonDivisorDialFallsBackToNinety() {
        var options = HamburgOptions()
        options.dialModulus = 100
        let normalized = options.normalized()
        #expect(normalized.options.dialModulus == 90)
        #expect(normalized.warnings.contains { $0.contains("divide 360") })
    }
}
