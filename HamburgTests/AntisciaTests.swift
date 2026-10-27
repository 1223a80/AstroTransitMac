import Foundation
import Testing
import HamburgCore

struct AntisciaTests {
    private func chart(_ values: [(String, Double)]) -> HamburgChart {
        HamburgChart(
            julianDayUT: 2_451_545.0,
            points: values.map {
                ChartPoint(id: $0.0, kind: .planet, longitude: $0.1)
            },
            includeAriesPoint: false
        )
    }

    private func options(dial: Double = 360) -> HamburgOptions {
        var options = HamburgOptions()
        options.dialModulus = dial
        options.midpointOrb = 0.01
        options.pictureOrb = 0.01
        options.antisciaEnabled = true
        options.solarArcEnabled = false
        options.focusPointIDs = ["SUN"]
        options.displayDials = [dial]
        return options
    }

    @Test func antiscionAndContraAntiscionAreExact() throws {
        let report = HamburgEngine(options: options()).report(
            chart: chart([("SUN", 10), ("MOON", 170), ("MARS", 350)])
        )
        let antiscia = try #require(report.antiscia)
        #expect(antiscia.pointContacts.contains {
            $0.formula == "antiscion(SUN) = MOON" && $0.orbDial < 1e-9
        })
        #expect(antiscia.pointContacts.contains {
            $0.formula == "contra_antiscion(SUN) = MARS" && $0.orbDial < 1e-9
        })
        let sun = try #require(report.positions.first { $0.id == "SUN" })
        #expect(abs(Angle.signedSeparation(sun.antiscion ?? 0, 170)) < 1e-9)
        #expect(abs(Angle.signedSeparation(sun.contraAntiscion ?? 0, 350)) < 1e-9)
    }

    @Test func antiscionContactsNatalMidpoint() throws {
        let report = HamburgEngine(options: options()).report(
            chart: chart([("SUN", 10), ("MOON", 160), ("VENUS", 180)])
        )
        let antiscia = try #require(report.antiscia)
        #expect(antiscia.midpointContacts.contains {
            $0.formula == "antiscion(SUN) = MOON/VENUS" && $0.orbDial < 1e-9
        })
    }

    @Test func ninetyDegreeDialCollapsesAntiscionSquare() throws {
        let report = HamburgEngine(options: options(dial: 90)).report(
            chart: chart([("SUN", 10), ("MOON", 260)])
        )
        let antiscia = try #require(report.antiscia)
        let contact = try #require(antiscia.pointContacts.first {
            $0.formula == "antiscion(SUN) = MOON"
        })
        #expect(contact.orbDial < 1e-9)
        #expect(contact.orb < 1e-9)
    }

    @Test func zodiacPositionFormatsCarrySeconds() {
        let position = ZodiacPosition(longitude: 10 + 15.0 / 60 + 30.0 / 3600)
        #expect(position.sign == .aries)
        #expect(position.degrees == 10)
        #expect(position.minutes == 15)
        #expect(position.seconds == 30)
        #expect(position.text.contains("Aries"))

        let nextSign = ZodiacPosition(longitude: 29 + 59.0 / 60 + 59.6 / 3600)
        #expect(nextSign.sign == .taurus)
        #expect(nextSign.degrees == 0)
        #expect(nextSign.minutes == 0)
        #expect(nextSign.seconds == 0)

        let wrap = ZodiacPosition(longitude: 359.999999)
        #expect(wrap.sign == .aries)
        #expect(wrap.degrees == 0)
    }
}
