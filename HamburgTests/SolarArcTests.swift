import Foundation
import Testing
import HamburgCore

struct SolarArcTests {
    private func chart(
        julianDay: Double,
        points: [(String, Double)]
    ) -> HamburgChart {
        HamburgChart(
            julianDayUT: julianDay,
            points: points.map {
                ChartPoint(
                    id: $0.0,
                    kind: ["ASC", "MC"].contains($0.0) ? .angle : .planet,
                    longitude: $0.1
                )
            },
            includeAriesPoint: false
        )
    }

    private func options(method: SolarArcMethod = .trueSun, rate: Double? = nil) -> HamburgOptions {
        var options = HamburgOptions()
        options.dialModulus = 360
        options.midpointOrb = 0.01
        options.pictureOrb = 0.01
        options.solarArcOrb = 0.01
        options.solarArcEnabled = true
        options.solarArcMethod = method
        options.solarArcRate = rate
        options.antisciaEnabled = false
        options.focusPointIDs = ["SUN"]
        options.displayDials = [360]
        return options
    }

    @Test func trueSolarArcMatchesReferenceArc() throws {
        let birth = Moment(year: 1990, month: 1, day: 1, hour: 12, minute: 0, timezone: "Asia/Shanghai")
        let reference = Moment(year: 2026, month: 6, day: 2, hour: 12, minute: 0, timezone: "Asia/Shanghai")
        let birthJD = try birth.julianDayUT
        let referenceJD = try reference.julianDayUT
        let report = HamburgEngine(options: options()).report(
            chart: chart(julianDay: birthJD, points: [
                ("SUN", 280.474427),
                ("MOON", 328.788629),
                ("ASC", 17.616017),
            ]),
            referenceJulianDay: referenceJD
        )
        let solarArc = try #require(report.solarArc)
        #expect(abs(solarArc.ageYears - 36.416931) < 0.001)
        #expect(abs(solarArc.arcDegrees - 37.049827) < 0.02)
        #expect(solarArc.directedPositions.count == 3)
        let directedSun = try #require(solarArc.directedPositions.first { $0.id == "SUN" })
        #expect(abs(Angle.signedSeparation(directedSun.longitude, 317.524254)) < 0.02)
    }

    @Test func customArcProducesExactPointContact() throws {
        let chart = chart(julianDay: 0, points: [("SUN", 0), ("MOON", 10)])
        let report = HamburgEngine(options: options(method: .custom, rate: 1.0)).report(
            chart: chart,
            referenceJulianDay: 3_652.422
        )
        let solarArc = try #require(report.solarArc)
        #expect(abs(solarArc.ageYears - 10) < 1e-9)
        #expect(abs(solarArc.arcDegrees - 10) < 1e-9)
        let hit = try #require(solarArc.pointHits.first { $0.formula == "SA(SUN) = MOON" })
        #expect(hit.orbDial < 1e-9)
        #expect(hit.direction == "direct")
    }

    @Test func naibodArcUsesMeanRate() throws {
        let report = HamburgEngine(options: options(method: .naibod)).report(
            chart: chart(julianDay: 0, points: [("SUN", 0), ("MOON", 10)]),
            referenceJulianDay: 3_652.422
        )
        let solarArc = try #require(report.solarArc)
        #expect(abs(solarArc.arcDegrees - 9.8564733) < 0.001)
    }

    @Test func converseDirectionsAreExplicit() throws {
        var options = options(method: .custom, rate: 1.0)
        options.includeConverseSolarArc = true
        let report = HamburgEngine(options: options).report(
            chart: chart(julianDay: 0, points: [("SUN", 0), ("MOON", 10)]),
            referenceJulianDay: 3_652.422
        )
        let solarArc = try #require(report.solarArc)
        #expect(solarArc.converseArcDegrees != nil)
        #expect(solarArc.directedPositions.contains { $0.direction == "converse" })
        #expect(solarArc.directedPositions.count == 4)
    }

    @Test func directedLongitudeWrapsAcrossZero() throws {
        let report = HamburgEngine(options: options(method: .custom, rate: 1.0)).report(
            chart: chart(julianDay: 0, points: [("SUN", 350), ("MOON", 10)]),
            referenceJulianDay: 7_304.844
        )
        let solarArc = try #require(report.solarArc)
        let directedSun = try #require(solarArc.directedPositions.first { $0.id == "SUN" })
        #expect(abs(Angle.signedSeparation(directedSun.longitude, 10)) < 1e-9)
    }

    @Test func referenceMomentAloneResolvesSolarArc() throws {
        let birth = Moment(year: 2000, month: 1, day: 1, hour: 12, minute: 0, timezone: "Asia/Shanghai")
        let reference = Moment(year: 2010, month: 1, day: 1, hour: 12, minute: 0, timezone: "Asia/Shanghai")
        let birthJD = try birth.julianDayUT
        let report = HamburgEngine(options: options()).report(
            chart: chart(julianDay: birthJD, points: [("SUN", 280), ("MOON", 10)]),
            referenceMoment: reference
        )
        #expect(report.solarArc != nil)
        #expect(report.meta.referenceUTC != nil)
    }
}
