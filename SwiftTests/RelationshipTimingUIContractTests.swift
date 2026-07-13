import Foundation
import Testing
@testable import TransitStudio

@MainActor
struct RelationshipTimingUIContractTests {
    @Test func nestedRelationshipPointSetWinsOverStaleNatalTimingControls() throws {
        let targetPointSet = ModernPointSet(
            bodyIDs: ["SUN", "SATURN"],
            includeNodes: false,
            nodeMode: "true_node",
            customAsteroids: [433],
            angleIDs: ["ASC"],
            houseCusps: [1],
            lotIDs: []
        )
        let personA = PersonSettings(
            name: "A",
            moment: ChartMoment(year: 1990, month: 1, day: 1, hour: 12, minute: 0, timezone: "Asia/Shanghai"),
            latitude: 31.2304,
            longitude: 121.4737
        )
        let personB = PersonSettings(
            name: "B",
            moment: ChartMoment(year: 1992, month: 6, day: 15, hour: 8, minute: 30, timezone: "America/New_York"),
            latitude: 40.7128,
            longitude: -74.0060
        )
        let target = ModernTimingTargetChart(
            type: "composite",
            personA: personA,
            personB: personB,
            pointSet: targetPointSet,
            houseSystem: "placidus",
            zodiac: "sidereal_lahiri"
        )

        let view = ContentView()

        let effectivePointSet = view.timingEffectiveTargetPointSet(for: target)
        #expect(effectivePointSet.customAsteroids == [433])
        #expect(effectivePointSet.angleIDs == ["ASC"])
        #expect(effectivePointSet.houseCusps == [1])
        #expect(effectivePointSet.lotIDs.isEmpty)

        let techniques = view.timingTechniqueRequests(for: target)
        #expect(techniques.map(\.id) == ["transit"])
        #expect(techniques.first?.eventTypes == ["aspect"])
    }

    @Test func relationshipTargetCarriesSnapshotChartSettings() throws {
        let target = ModernTimingTargetChart(
            type: "davison",
            personA: PersonSettings(
                name: "A",
                moment: ChartMoment(year: 1990, month: 1, day: 1, hour: 12, minute: 0, timezone: "Asia/Shanghai"),
                latitude: 31.2304,
                longitude: 121.4737
            ),
            personB: PersonSettings(
                name: "B",
                moment: ChartMoment(year: 1992, month: 6, day: 15, hour: 8, minute: 30, timezone: "America/New_York"),
                latitude: 40.7128,
                longitude: -74.0060
            ),
            pointSet: ModernPointSet(
                bodyIDs: ["SUN"],
                includeNodes: false,
                nodeMode: "true_node",
                customAsteroids: [],
                angleIDs: [],
                houseCusps: [],
                lotIDs: []
            ),
            houseSystem: "regiomontanus",
            zodiac: "tropical"
        )

        #expect(target.houseSystem == "regiomontanus")
        #expect(target.zodiac == "tropical")
        #expect(target.personA.moment.timezone == "Asia/Shanghai")
        #expect(target.personB.moment.timezone == "America/New_York")
    }

    @Test func progressedCompositeReferenceCanEncodeAnIndependentTimezone() {
        let view = ContentView()
        let date = ContentView.fixedDate(
            year: 2026,
            month: 7,
            day: 13,
            hour: 12,
            minute: 0,
            gmtOffset: 5.75
        )

        let personAMoment = view.makeMoment(from: date, gmtOffset: 8.0)
        let referenceMoment = view.makeMoment(from: date, gmtOffset: 5.75)

        #expect(personAMoment.timezone == "GMT+8")
        #expect(referenceMoment.timezone == "GMT+5:45")
        #expect(personAMoment.timezone != referenceMoment.timezone)
    }
}
