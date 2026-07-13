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

    @Test func decodeModernTimingResult() throws {
        let result = try JSONDecoder().decode(
            ModernTimingResult.self,
            from: fixtureData("modern-timing-result")
        )

        #expect(result.meta.schemaVersion == 1)
        #expect(result.meta.techniqueIDs == ["transit", "secondary_progression", "solar_arc"])
        #expect(result.meta.techniqueConfigs.map(\.id) == result.meta.techniqueIDs)
        #expect(result.meta.techniqueConfigs.allSatisfy { !$0.aspects.isEmpty })
        #expect(Set(result.events.map(\.sourceType)) == Set(result.meta.techniqueIDs))
        #expect(result.events.contains(where: { $0.eventType == "station" }))
        #expect(result.events.contains(where: { $0.eventType == "ingress" }))
        let aspects = result.events.filter { $0.eventType == "aspect" }
        #expect(!aspects.isEmpty)
        #expect(aspects.allSatisfy {
            ($0.windowClippedStart ? $0.enteringUTC == nil : $0.enteringUTC != nil)
                && ($0.windowClippedEnd ? $0.leavingUTC == nil : $0.leavingUTC != nil)
        })
        #expect(result.events.allSatisfy { $0.exactUTC.contains("Z") })
        #expect(result.events.allSatisfy { $0.exactLocal.contains("+08:00") })
        #expect(result.events.contains(where: { $0.passCountInWindow > 1 }))
        #expect(result.events.allSatisfy { $0.targetAxisBranch == nil })
    }

    @Test func decodeMidpointResultFromRealOutput() throws {
        let result = try JSONDecoder().decode(
            MidpointResult.self,
            from: fixtureData("midpoint-result")
        )

        #expect(result.meta.schemaVersion == 1)
        #expect(result.meta.method == "circular_midpoint_axis_360")
        #expect(result.meta.modulus == 360)
        #expect(result.meta.activationSources == ["natal", "transit", "secondary_progression", "solar_arc"])
        #expect(result.axes.count == 15)
        #expect(Set(result.axes.map(\.id)).count == result.axes.count)
        #expect(result.axes.allSatisfy { $0.pointAID < $0.pointBID })
        #expect(Set(result.trees.map(\.focusPointID)) == Set(["SUN", "MOON", "ASC", "MC"]))
        let configuredSources = Set(result.meta.activationSources ?? [])
        let hitSources = Set(result.snapshotActivations.map(\.sourceType))
        #expect(!hitSources.isEmpty)
        #expect(hitSources.isSubset(of: configuredSources))
        #expect(result.snapshotActivations.allSatisfy { ["direct", "opposite"].contains($0.axisBranch) })
        #expect(result.sectionErrors == nil)

        let markdown = MarkdownExportBuilder.midpoint(result)
        let csv = TextExportBuilder.csv(result)
        #expect(markdown.contains("Direct longitude"))
        #expect(markdown.contains("Activation sources"))
        #expect(csv.contains("point_a_id,point_a_name,point_b_id,point_b_name"))
        #expect(csv.contains("snapshot_activation"))
    }

    @Test func decodeModernTimingMidpointTargetsFromRealOutput() throws {
        let result = try JSONDecoder().decode(
            ModernTimingResult.self,
            from: fixtureData("modern-timing-midpoint-result")
        )

        #expect(result.meta.targetCount == 2)
        #expect(result.meta.effectivePointSet.bodyIDs.isEmpty)
        #expect(result.meta.effectivePointSet.angleIDs.isEmpty)
        #expect(result.meta.effectivePointSet.midpointPairs?.map(\.axisID) == ["midpoint|MOON|SUN"])
        #expect(!result.events.isEmpty)
        #expect(result.events.allSatisfy { $0.targetPointID == "midpoint|MOON|SUN" })
        #expect(result.events.allSatisfy { $0.targetPointKind == "midpoint_axis" })
        #expect(Set(result.events.compactMap(\.targetAxisBranch)) == Set(["direct", "opposite"]))
        #expect(result.events.allSatisfy { event in
            guard let branch = event.targetAxisBranch else { return false }
            return event.groupID.hasSuffix("|\(branch)") && event.id.contains("|\(branch)|")
        })

        let markdown = MarkdownExportBuilder.modernTiming(result)
        let csv = TextExportBuilder.csv(result)
        #expect(markdown.contains("[direct]") && markdown.contains("[opposite]"))
        #expect(result.events.allSatisfy { markdown.contains($0.id.replacingOccurrences(of: "|", with: "\\|")) })
        #expect(csv.contains("target_point_id,target_axis_branch,aspect_id"))
        #expect(csv.contains("midpoint|MOON|SUN,direct"))
        #expect(csv.contains("midpoint|MOON|SUN,opposite"))
    }

    @Test func decodeHarmonicResult() throws {
        let result = try JSONDecoder().decode(HarmonicResult.self, from: fixtureData("harmonic-result"))
        #expect(result.harmonicOrder == 4)
        #expect(!result.planets.isEmpty)
        #expect(!result.houses.isEmpty)
    }

    @Test func decodeModernReturnFixtures() throws {
        let solar = try JSONDecoder().decode(ModernReturnResult.self, from: fixtureData("modern-solar-return-result"))
        #expect(solar.meta.returnBodyID == "SUN")
        #expect(solar.currentCycleReturn != nil)
        #expect(solar.previousReturn != nil)
        #expect(solar.nextReturn != nil)
        #expect(solar.currentCycleReturn?.chart?.planets.isEmpty == false)
        #expect(solar.currentCycleReturn?.chart?.declinationAspects != nil)
        if let chart = solar.currentCycleReturn?.chart {
            let wheel = ChartWheelData(modernReturnChart: chart, returnToNatalAspects: solar.currentCycleReturn?.returnToNatalAspects ?? [])
            #expect(wheel.points.contains { $0.id == "return-SUN" })
            #expect(wheel.points.contains { $0.id == "natal-SUN" })
            #expect(wheel.unresolvedAspectEndpoints.isEmpty)
        }
        let markdown = MarkdownModernExportBuilder.modernReturn(solar)
        #expect(markdown.contains("宫制 requested"))
        #expect(markdown.contains("Asia/Shanghai"))
        #expect(markdown.contains("求根误差"))
        let csv = TextExportBuilder.csv(solar)
        #expect(csv.contains("house_system_requested"))
        #expect(csv.contains("current_return"))

        let lunar = try JSONDecoder().decode(ModernReturnResult.self, from: fixtureData("modern-lunar-return-result"))
        #expect(lunar.meta.returnBodyID == "MOON")
        #expect(lunar.currentCycleReturn != nil)
        #expect(lunar.currentCycleReturn?.exactLocal.contains("+08:00") == true)
    }

    @Test func decodeHoraryResultFromRealOutput() throws {
        let result = try JSONDecoder().decode(HoraryResult.self, from: fixtureData("horary-result"))

        #expect(!result.planets.isEmpty)
        #expect(!result.houses.isEmpty)
        #expect(result.meta.aspectOrb == 3)

        let wheel = ChartWheelData(horaryResult: result)
        #expect(wheel.unresolvedAspectEndpoints.isEmpty)
        #expect(wheel.aspects.count == result.aspects.count)
        #expect(wheel.aspects.allSatisfy { ["合相", "冲相", "刑相", "拱相", "六合"].contains($0.type) })

        let markdown = MarkdownExportBuilder.horary(result)
        #expect(markdown.contains("Aspect orb: 3.0°"))
        #expect(markdown.contains(result.meta.zodiac))

        let csv = TextExportBuilder.csv(result)
        #expect(csv.contains("calculation_setting,aspect_orb,3.00000000"))
        #expect(csv.contains("lot_group") == false)
        #expect(csv.contains("experimental"))
    }
}
