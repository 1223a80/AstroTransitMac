import Foundation
import Testing
@testable import TransitStudio

struct ScanWorkEstimatorTests {
    @Test func estimateMatchesBackendStepAndAspectRules() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let end = makeDate(year: 2026, month: 1, day: 2)
        let aspects = [
            AspectRequest(id: "conjunction", name: "合相", angle: 0, orb: 0),
            AspectRequest(id: "sextile", name: "六合", angle: 60, orb: 0),
            AspectRequest(id: "opposition", name: "冲相", angle: 180, orb: 0),
        ]

        let estimate = ScanWorkEstimator.estimate(
            start: start,
            end: end,
            transitBodyIDs: ["SUN", "MOON", "MERCURY", "JUPITER", "URANUS"],
            customAsteroids: [433],
            moonFilter: "exclude",
            scanKind: "aspect",
            aspects: aspects,
            targetText: "A = Aries 00°00\n# ignored\n\nB = Taurus 00°00"
        )

        #expect(estimate.bodyCount == 5)
        #expect(estimate.stepUnits == 25)
        #expect(estimate.targetCount == 2)
        #expect(estimate.exactAspectCount == 4)
        #expect(estimate.workUnits == 200)
    }

    @Test func stationEstimateExcludesSunAndMoon() {
        let start = makeDate(year: 2026, month: 1, day: 1)
        let end = makeDate(year: 2026, month: 1, day: 2)

        let estimate = ScanWorkEstimator.estimate(
            start: start,
            end: end,
            transitBodyIDs: ["SUN", "MOON", "MARS"],
            customAsteroids: [],
            moonFilter: "include",
            scanKind: "station",
            aspects: [],
            targetText: ""
        )

        #expect(estimate.bodyCount == 1)
        #expect(estimate.stepUnits == 9)
        #expect(estimate.workUnits == 9)
    }

    @Test func thresholdsClassifyHeavyScans() {
        #expect(ScanWorkLimits.confirmationRequired == 5_000_000)
        #expect(ScanWorkLimits.maximum == 15_000_000)
        #expect(!ScanWorkEstimate(workUnits: 1_500_000, stepUnits: 1, bodyCount: 1, targetCount: 1, exactAspectCount: 1).shouldWarn)
        #expect(ScanWorkEstimate(workUnits: 1_500_001, stepUnits: 1, bodyCount: 1, targetCount: 1, exactAspectCount: 1).shouldWarn)
        #expect(!ScanWorkEstimate(workUnits: 5_000_000, stepUnits: 1, bodyCount: 1, targetCount: 1, exactAspectCount: 1).requiresConfirmation)
        #expect(ScanWorkEstimate(workUnits: 5_000_001, stepUnits: 1, bodyCount: 1, targetCount: 1, exactAspectCount: 1).requiresConfirmation)
        #expect(!ScanWorkEstimate(workUnits: 15_000_000, stepUnits: 1, bodyCount: 1, targetCount: 1, exactAspectCount: 1).isBlocked)
        #expect(ScanWorkEstimate(workUnits: 15_000_001, stepUnits: 1, bodyCount: 1, targetCount: 1, exactAspectCount: 1).isBlocked)
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
