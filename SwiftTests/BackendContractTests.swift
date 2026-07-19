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

    @Test func decodeRelationshipTimingFixturesFromRealOutput() throws {
        let fixtures = [
            ("modern-timing-composite-result", "composite", "composite_midpoint"),
            ("modern-timing-davison-result", "davison", "davison_midtime_midspace"),
        ]

        for (fixtureName, targetType, method) in fixtures {
            let result = try JSONDecoder().decode(
                ModernTimingResult.self,
                from: fixtureData(fixtureName)
            )

            #expect(result.meta.targetChartType == targetType)
            #expect(result.meta.targetChartMethod == method)
            #expect(result.meta.targetCount == 4)
            #expect(result.meta.effectivePointSet.angleIDs == ["ASC"])
            #expect(result.meta.effectivePointSet.houseCusps == [1])
            #expect(!result.events.isEmpty)
            #expect(result.events.allSatisfy { $0.targetChartType == targetType })
            #expect(result.events.allSatisfy { $0.targetChartMethod == method })
            #expect(result.sectionErrors == nil)

            let markdown = MarkdownExportBuilder.modernTiming(result)
            let csv = TextExportBuilder.csv(result)
            #expect(markdown.contains("目标盘类型：\(targetType)"))
            #expect(markdown.contains(method))
            #expect(csv.contains("target_chart_type,target_chart_method"))
            #expect(csv.contains("\(targetType),\(method)"))
        }
    }

    @Test func decodeProgressedCompositeFixtureFromRealOutput() throws {
        let data = try fixtureData("progressed-composite-result")
        let raw = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(raw["houses"] == nil)
        #expect(raw["angles"] == nil)

        let result = try JSONDecoder().decode(ProgressedCompositeResult.self, from: data)
        #expect(result.meta.method == "progress_each_person_then_midpoint")
        #expect(result.meta.personAAgeYears != nil)
        #expect(result.meta.personBAgeYears != nil)
        #expect(result.radixCompositePlanets.count == 12)
        #expect(result.progressedCompositePlanets.count == 12)
        #expect(!result.progressedToRadixAspects.isEmpty)
        #expect(result.progressedCompositePlanets.allSatisfy { planet in
            let trace = planet.trace
            return trace.phase == "progressed"
                && trace.midpointMethod == "circular_midpoint"
                && trace.compositeLongitude == planet.longitude
        })
        #expect(result.sectionErrors == nil)

        let markdown = MarkdownExportBuilder.progressedComposite(result)
        let csv = TextExportBuilder.csv(result)
        let json = TextExportBuilder.progressedCompositeJSON(result)
        #expect(markdown.contains("progress_each_person_then_midpoint"))
        #expect(markdown.contains("A age years"))
        #expect(markdown.contains("实际有效点"))
        #expect(csv.contains("person_a_age_years,person_b_age_years"))
        #expect(csv.contains("effective_point_ids"))
        #expect(csv.contains("progressed_to_radix_aspect"))
        #expect(json.contains("\"person_a_age_years\""))
        #expect(!json.contains("\"houses\""))
        #expect(!json.contains("\"angles\""))
    }

    @Test func decodeHarmonicResult() throws {
        let result = try JSONDecoder().decode(HarmonicResult.self, from: fixtureData("harmonic-result"))
        #expect(result.harmonicOrder == 4)
        #expect(!result.planets.isEmpty)
        #expect(!result.houses.isEmpty)
    }

    @Test func decodeRelocationFixtureFromRealOutput() throws {
        let result = try JSONDecoder().decode(RelocationResult.self, from: fixtureData("relocation-result"))
        #expect(result.meta.method == "same_birth_utc_new_location_houses")
        #expect(!result.natalChart.planets.isEmpty)
        #expect(result.natalChart.planets.count == result.relocatedChart.planets.count)
        for (natal, relocated) in zip(result.natalChart.planets, result.relocatedChart.planets) {
            #expect(natal.bodyID == relocated.bodyID)
            #expect(abs(natal.longitude - relocated.longitude) < 1e-9)
        }
        #expect(!result.planetHouseChanges.isEmpty)
        #expect(!result.relocatedAnglesInNatalHouses.isEmpty)
        let markdown = MarkdownExportBuilder.relocation(result)
        let csv = TextExportBuilder.csv(result)
        #expect(markdown.contains(result.meta.birthUTC))
        #expect(markdown.contains("London") || markdown.contains(result.meta.relocation.name ?? "London"))
        #expect(csv.contains("planet_house_change"))
        #expect(csv.contains(result.meta.birthUTC))
    }

    @Test func decodeModernCyclesFixtureFromRealOutput() throws {
        let result = try JSONDecoder().decode(ModernCyclesResult.self, from: fixtureData("modern-cycles-result"))
        #expect(result.meta.method == "swiss_ephemeris_cycles_v1")
        #expect(!result.events.isEmpty)
        let types = Set(result.events.map(\.cycleType))
        #expect(types.contains("new_moon"))
        #expect(types.contains("full_moon"))
        let lunationIDs = Set(result.events.filter { $0.cycleType == "new_moon" || $0.cycleType == "full_moon" }.map(\.id))
        let eclipseIDs = Set(result.events.filter { $0.cycleType.contains("eclipse") }.map(\.id))
        #expect(lunationIDs.isDisjoint(with: eclipseIDs))
        #expect(result.timingEvents?.isEmpty == false)
        let markdown = MarkdownExportBuilder.modernCycles(result)
        let csv = TextExportBuilder.csv(result)
        #expect(markdown.contains("Modern Cycles"))
        #expect(csv.contains("cycle_event"))
    }

    @Test func decodeDeclinationTimingFixtureFromRealOutput() throws {
        let result = try JSONDecoder().decode(
            DeclinationTimingResult.self,
            from: fixtureData("declination-timing-result")
        )
        #expect(result.meta.method == "declination_timing_v1")
        #expect(result.meta.coordinateKind == "declination")
        #expect(result.meta.oobThresholdMethod == "true_obliquity_at_event_time")
        #expect(!result.events.isEmpty)
        let types = Set(result.events.map(\.eventType))
        #expect(types.contains("parallel"))
        #expect(types.contains("contraparallel"))
        #expect(types.contains("declination_station"))
        #expect(types.contains("oob_entry") || types.contains("oob_exit"))
        #expect(result.events.contains { $0.passCountInWindow > 1 })
        #expect(result.events.allSatisfy { $0.exactUTC.hasSuffix("Z") })
        #expect(result.events.allSatisfy { $0.exactLocal.contains("+08:00") })
        #expect(result.calculationAssumptions?.isEmpty == false)
        #expect(result.requestedConfig != nil)
        #expect(result.effectiveConfig != nil)
        let markdown = MarkdownExportBuilder.declinationTiming(result)
        let csv = TextExportBuilder.csv(result)
        #expect(markdown.contains("动态赤纬事件"))
        #expect(markdown.contains("计算假设"))
        #expect(markdown.contains("警告"))
        #expect(markdown.contains("可复算的时间与坐标事实"))
        #expect(csv.contains("declination_event"))
        #expect(csv.contains("moving_declination"))
    }

    @Test func decodeAstrocartographyFixtureFromRealOutput() throws {
        let result = try JSONDecoder().decode(AstrocartographyResult.self, from: fixtureData("astrocartography-result"))
        #expect(result.meta.method.contains("acg"))
        #expect(result.meta.coordinateFrame == "tropical_true_of_date_physical_sky")
        #expect(!result.lines.isEmpty)
        #expect(result.lines.contains { $0.angleKind == "MC" && $0.longitude != nil })
        let markdown = MarkdownExportBuilder.astrocartography(result)
        #expect(markdown.contains("Astrocartography"))
        #expect(TextExportBuilder.csv(result).contains("acg_line"))
    }

    @Test func decodeLocalSpaceFixtureFromRealOutput() throws {
        let result = try JSONDecoder().decode(LocalSpaceResult.self, from: fixtureData("local-space-result"))
        #expect(result.meta.method.contains("local_space"))
        #expect(result.meta.coordinateFrame == "tropical_true_of_date_physical_sky")
        #expect(!result.directions.isEmpty)
        #expect(result.directions.allSatisfy { $0.azimuthDeg >= 0 })
        let markdown = MarkdownExportBuilder.localSpace(result)
        #expect(markdown.contains("Local Space"))
        #expect(TextExportBuilder.csv(result).contains("local_space_direction"))
    }

    @Test func decodeModernReturnFixtures() throws {
        let solar = try JSONDecoder().decode(ModernReturnResult.self, from: fixtureData("modern-solar-return-result"))
        #expect(solar.meta.returnBodyID == "SUN")
        #expect(solar.currentCycleReturn != nil)
        #expect(solar.previousReturn != nil)
        #expect(solar.nextReturn != nil)
        #expect(solar.currentCycleReturn?.chart?.planets.isEmpty == false)
        #expect(solar.currentCycleReturn?.chart?.declinationAspects != nil)
        #expect(solar.allCrossings?.isEmpty == false)
        #expect(solar.calculationAssumptions?.isEmpty == false)
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
        #expect(markdown.contains("计算假设"))
        let csv = TextExportBuilder.csv(solar)
        #expect(csv.contains("house_system_requested"))
        #expect(csv.contains("current_return"))

        let lunar = try JSONDecoder().decode(ModernReturnResult.self, from: fixtureData("modern-lunar-return-result"))
        #expect(lunar.meta.returnBodyID == "MOON")
        #expect(lunar.currentCycleReturn != nil)
        #expect(lunar.currentCycleReturn?.exactLocal.contains("+08:00") == true)

        let mercury = try JSONDecoder().decode(
            ModernReturnResult.self,
            from: fixtureData("modern-mercury-return-result")
        )
        #expect(mercury.meta.returnBodyID == "MERCURY")
        #expect(mercury.currentCycleReturn != nil)
        #expect(mercury.currentCycleReturn?.exactError ?? 1 < 1e-4)
        #expect(mercury.allCrossings?.isEmpty == false)
        let mercuryMarkdown = MarkdownModernExportBuilder.modernReturn(mercury)
        #expect(mercuryMarkdown.contains("MERCURY Return") || mercuryMarkdown.contains("Mercury") || mercuryMarkdown.contains("MERCURY"))
    }

    @Test func decodeRetrogradeCyclesFixtureFromRealOutput() throws {
        let result = try JSONDecoder().decode(
            RetrogradeCyclesResult.self,
            from: fixtureData("retrograde-cycles-result")
        )
        #expect(result.meta.method == "retrograde_shadow_from_true_stations_v1")
        #expect(!result.cycles.isEmpty)
        #expect(!result.stations.isEmpty)
        #expect(result.calculationAssumptions?.isEmpty == false)
        let mercury = result.cycles.filter { $0.bodyID == "MERCURY" }
        #expect(!mercury.isEmpty)
        #expect(mercury[0].shadowLongitudePre == mercury[0].directStationLongitude)
        #expect(mercury[0].shadowLongitudePost == mercury[0].retrogradeStationLongitude)
        let markdown = MarkdownExportBuilder.retrogradeCycles(result)
        let csv = TextExportBuilder.csv(result)
        #expect(markdown.contains("逆行周期"))
        #expect(markdown.contains("计算假设"))
        #expect(csv.contains("retrograde_cycle"))
        #expect(csv.contains("station"))
    }

    @Test func decodeClassicalVisibilityFixtureFromRealOutput() throws {
        let result = try JSONDecoder().decode(
            ClassicalVisibilityResult.self,
            from: fixtureData("classical-visibility-result")
        )
        #expect(result.meta.method == "classical_visibility_v1")
        #expect(!result.heliacalEvents.isEmpty)
        #expect(!result.riseSet.isEmpty)
        #expect(result.planetaryHours?.status == "ok")
        #expect((result.planetaryHours?.hours?.count ?? 0) == 24)
        #expect(result.calculationAssumptions?.isEmpty == false)
        let markdown = MarkdownExportBuilder.classicalVisibility(result)
        let csv = TextExportBuilder.csv(result)
        #expect(markdown.contains("行星时"))
        #expect(markdown.contains("计算假设"))
        #expect(csv.contains("heliacal") || csv.contains("planetary_hour"))
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
