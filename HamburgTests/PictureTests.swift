import Foundation
import Testing
import HamburgCore

struct PictureTests {
    private func chart() -> HamburgChart {
        let points = [
            ChartPoint(id: "A", kind: .custom, longitude: 0),
            ChartPoint(id: "B", kind: .custom, longitude: 10),
            ChartPoint(id: "C", kind: .custom, longitude: 90),
            ChartPoint(id: "D", kind: .custom, longitude: 170),
        ]
        return HamburgChart(
            julianDayUT: 2_451_545.0,
            points: points,
            includeAriesPoint: false
        )
    }

    private func options(dial: Double = 90, orb: Double = 0.01, maxPictures: Int = 100) -> HamburgOptions {
        var options = HamburgOptions()
        options.dialModulus = dial
        options.midpointOrb = orb
        options.pictureOrb = orb
        options.antisciaEnabled = false
        options.solarArcEnabled = false
        options.focusPointIDs = ["A"]
        options.maxPictures = maxPictures
        options.displayDials = [dial]
        return options
    }

    @Test func knownSumPictureIsCanonical() throws {
        let report = HamburgEngine(options: options()).report(chart: chart())
        let picture = try #require(report.pictures.first)
        #expect(picture.formula == "A + C = B + D")
        #expect(picture.left == ["A", "C"])
        #expect(picture.right == ["B", "D"])
        #expect(picture.orbDial < 1e-9)
        #expect(picture.dialLongitude == 0)
    }

    @Test func pictureDoesNotExistOn360Dial() {
        let report = HamburgEngine(options: options(dial: 360)).report(chart: chart())
        #expect(report.pictures.isEmpty)
    }

    @Test func picturesAreUniqueAndSorted() {
        let values = [
            ChartPoint(id: "A", kind: .custom, longitude: 0),
            ChartPoint(id: "B", kind: .custom, longitude: 30),
            ChartPoint(id: "C", kind: .custom, longitude: 60),
            ChartPoint(id: "D", kind: .custom, longitude: 90),
            ChartPoint(id: "E", kind: .custom, longitude: 120),
            ChartPoint(id: "F", kind: .custom, longitude: 150),
        ]
        let chart = HamburgChart(
            julianDayUT: 2_451_545.0,
            points: values,
            includeAriesPoint: false
        )
        let report = HamburgEngine(options: options(orb: 2.0)).report(chart: chart)
        #expect(!report.pictures.isEmpty)
        #expect(Set(report.pictures.map(\.id)).count == report.pictures.count)
        #expect(zip(report.pictures, report.pictures.dropFirst()).allSatisfy { pair in
            pair.0.orbDial <= pair.1.orbDial + 1e-12
        })
    }

    @Test func pictureListRespectsLimit() {
        let points = [0.0, 30.0, 60.0, 90.0, 120.0, 150.0].enumerated().map {
            ChartPoint(id: "P\($0.offset)", kind: .custom, longitude: $0.element)
        }
        let chart = HamburgChart(
            julianDayUT: 2_451_545.0,
            points: points,
            includeAriesPoint: false
        )
        let report = HamburgEngine(options: options(orb: 5, maxPictures: 1)).report(chart: chart)
        #expect(report.pictures.count <= 1)
        #expect(report.warnings.contains { $0.contains("truncated") })
    }
}
