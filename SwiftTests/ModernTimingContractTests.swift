import Foundation
import SwiftUI
import Testing
@testable import TransitStudio

@MainActor
struct ModernTimingContractTests {
    @Test func requestEncodesIndependentTechniqueContracts() throws {
        let request = ModernTimingRequest(
            birth: BirthSettings(
                moment: ChartMoment(year: 1990, month: 1, day: 1, hour: 12, minute: 0, timezone: "Asia/Shanghai"),
                latitude: 31.2304,
                longitude: 121.4737,
                houseSystem: "placidus",
                zodiac: "tropical",
                boundsSystem: "egyptian",
                triplicitySystem: "dorothean"
            ),
            start: ChartMoment(year: 2030, month: 1, day: 1, hour: 0, minute: 0, timezone: "UTC"),
            end: ChartMoment(year: 2031, month: 1, day: 1, hour: 0, minute: 0, timezone: "UTC"),
            displayTimezone: "Asia/Shanghai",
            targetPointSet: pointSet,
            techniques: [
                ModernTimingTechniqueRequest(
                    id: "transit",
                    movingBodyIDs: ["SATURN"],
                    eventTypes: ["aspect", "station"],
                    aspects: [AspectRequest(id: "conjunction", name: "合相", angle: 0, orb: 1)]
                )
            ],
            confirmedHeavyScan: true
        )

        let data = try JSONEncoder().encode(request)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let techniques = try #require(object["techniques"] as? [[String: Any]])

        #expect(object["mode"] as? String == "modern_timing")
        #expect(object["display_timezone"] as? String == "Asia/Shanghai")
        #expect(object["confirmed_heavy_scan"] as? Bool == true)
        let encodedPointSet = try #require(object["target_point_set"] as? [String: Any])
        #expect(encodedPointSet["lot_ids"] as? [String] == ["fortune", "fortune"])
        #expect(techniques.first?["moving_body_ids"] as? [String] == ["SATURN"])
        #expect(techniques.first?["event_types"] as? [String] == ["aspect", "station"])
    }

    @Test func decodesDynamicLifecycleAndNullableNonAspectFields() throws {
        let result = try decodedResult()
        let aspect = result.events[0]
        let station = result.events[1]

        #expect(result.meta.schemaVersion == 1)
        #expect(result.meta.estimatedWorkUnits == 42)
        #expect(aspect.groupID == "transit|SATURN|conjunction|ASC")
        #expect(aspect.enteringUTC == "2030-01-10T04:11:02Z")
        #expect(aspect.targetPointKind == "angle")
        #expect(aspect.passIndexInWindow == 2)
        #expect(aspect.passCountInWindow == 3)
        #expect(!aspect.isWindowClipped)

        #expect(station.eventType == "station")
        #expect(station.targetPointID == nil)
        #expect(station.aspectID == nil)
        #expect(station.orbLimit == nil)
        #expect(station.enteringUTC == nil)
        #expect(station.leavingUTC == nil)
        #expect(station.windowClippedStart)
        #expect(station.windowClippedEnd)
    }

    @Test func estimatorMatchesTechniqueEventFormulaAndTargetDeduplication() {
        let start = makeDate(year: 2030, month: 1, day: 1)
        let end = Calendar(identifier: .gregorian).date(byAdding: .day, value: 14, to: start)!
        let techniques = [
            ModernTimingTechniqueRequest(
                id: "transit",
                movingBodyIDs: ["SUN", "URANUS", "SUN"],
                eventTypes: ["aspect", "ingress", "station"],
                aspects: [
                    AspectRequest(id: "conjunction", name: "合相", angle: 0, orb: 1),
                    AspectRequest(id: "sextile", name: "六合", angle: 60, orb: 1),
                    AspectRequest(id: "opposition", name: "冲相", angle: 180, orb: 1),
                ]
            ),
            ModernTimingTechniqueRequest(
                id: "secondary_progression",
                movingBodyIDs: ["MOON", "SUN"],
                eventTypes: ["aspect", "moon_ingress", "lunation"],
                aspects: [AspectRequest(id: "square", name: "刑相", angle: 90, orb: 1)]
            ),
            ModernTimingTechniqueRequest(
                id: "solar_arc",
                movingBodyIDs: ["SUN"],
                eventTypes: ["station"],
                aspects: []
            ),
        ]

        let estimate = ModernTimingWorkEstimator.estimate(
            start: start,
            end: end,
            techniques: techniques,
            targetPointSet: pointSet
        )

        // Target set: SUN, MOON, TRUE/SOUTH_TRUE_NODE, AST:433, ASC,
        // HOUSE_CUSP:1 and FORTUNE. Duplicates collapse to eight targets.
        #expect(ModernTimingWorkEstimator.targetCount(for: pointSet) == 8)
        // Transit steps: SUN 113 + URANUS 8 = 121.
        // 121*8*4 aspect branches + 121 ingress + 121 station = 4114.
        #expect(estimate.techniques[0].workUnits == 4_114)
        // Progression: two bodies * 3 steps; 6*8*2 + 3 moon ingress +
        // 3 lunation = 102. Unsupported solar-arc station contributes zero.
        #expect(estimate.techniques[1].workUnits == 102)
        #expect(estimate.techniques[2].workUnits == 0)
        #expect(estimate.workUnits == 4_216)
        #expect(estimate.stepUnits == 130)
        #expect(estimate.aspectBranchCount == 6)
    }

    @Test func estimatorAspectBranchesAndThresholdsUseStrictBoundaries() {
        #expect(ModernTimingWorkEstimator.exactLongitudeBranchCount(for: 0) == 1)
        #expect(ModernTimingWorkEstimator.exactLongitudeBranchCount(for: 180) == 1)
        #expect(ModernTimingWorkEstimator.exactLongitudeBranchCount(for: 360) == 1)
        #expect(ModernTimingWorkEstimator.exactLongitudeBranchCount(for: 60) == 2)
        #expect(ModernTimingWorkEstimator.exactLongitudeBranchCount(for: -90) == 2)

        #expect(!workEstimate(1_500_000).shouldWarn)
        #expect(workEstimate(1_500_001).shouldWarn)
        #expect(!workEstimate(2_500_000).requiresConfirmation)
        #expect(workEstimate(2_500_001).requiresConfirmation)
        #expect(!workEstimate(5_000_000).isBlocked)
        #expect(workEstimate(5_000_001).isBlocked)

        let emptyTargets = ModernPointSet(
            bodyIDs: [],
            includeNodes: false,
            nodeMode: "true_node",
            customAsteroids: [],
            angleIDs: []
        )
        let emptyTargetEstimate = ModernTimingWorkEstimator.estimate(
            start: makeDate(year: 2030, month: 1, day: 1),
            end: makeDate(year: 2030, month: 1, day: 2),
            techniques: [
                ModernTimingTechniqueRequest(
                    id: "solar_arc",
                    movingBodyIDs: ["SUN"],
                    eventTypes: ["aspect"],
                    aspects: []
                )
            ],
            targetPointSet: emptyTargets
        )
        #expect(emptyTargetEstimate.targetCount == 0)
        #expect(emptyTargetEstimate.workUnits == 1)
    }

    @Test func estimatorCountsTwoBranchesPerUniqueMidpointAxis() {
        let midpointTargets = ModernPointSet(
            bodyIDs: ["SUN"],
            includeNodes: false,
            nodeMode: "true_node",
            customAsteroids: [],
            angleIDs: [],
            midpointPairs: [
                MidpointPairRequest(pointAID: "SUN", pointBID: "MOON"),
                MidpointPairRequest(pointAID: "MOON", pointBID: "SUN"),
                MidpointPairRequest(pointAID: "ASC", pointBID: "MC"),
            ]
        )

        // One ordinary SUN target plus two canonical axes × two branches.
        #expect(ModernTimingWorkEstimator.targetCount(for: midpointTargets) == 5)
    }

    @Test func estimatorMatchesRealBackendFixture() throws {
        let result = try realFixtureResult()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let start = try #require(formatter.date(from: result.meta.startUTC))
        let end = try #require(formatter.date(from: result.meta.endUTC))
        let estimate = ModernTimingWorkEstimator.estimate(
            start: start,
            end: end,
            techniques: result.meta.techniqueConfigs,
            targetPointSet: result.meta.effectivePointSet
        )
        #expect(estimate.workUnits == result.meta.estimatedWorkUnits)
    }

    @Test func timelineExportsKeepLifecyclePassAndClippedFacts() throws {
        let result = try decodedResult()
        let markdown = MarkdownExportBuilder.modernTiming(result)
        let csv = TextExportBuilder.csv(result)
        let json = TextExportBuilder.json(result)

        #expect(markdown.contains("# 综合预测时间线"))
        #expect(markdown.contains("2030-01"))
        #expect(markdown.contains("transit|SATURN|conjunction|ASC"))
        #expect(markdown.contains("2/3"))
        #expect(markdown.contains("生命周期被查询边界截断") || markdown.contains("lifecycle 在查询边界被截断"))
        #expect(csv.hasPrefix("source_type,event_type,moving_point,target_point,target_kind,aspect,orb_limit"))
        #expect(csv.contains("2030-01-15T03:15:22Z"))
        #expect(csv.contains(",2,3,0.00000000,transit_longitude_bisection"))
        #expect(csv.contains(",transit_station_bisection,"))
        #expect(csv.contains(",true,true"))
        #expect(json.contains("\"window_clipped_start\""))
        #expect(json.contains("\"entering_utc\""))
    }

    @Test func modernTimingTabDefaultsToTimeline() {
        let viewModel = CalculationViewModel()
        #expect(viewModel.modernTimingSelectedTab == "timeline")
    }

    @Test func modernTimingPaneDeclaresEveryRequiredTab() throws {
        var selection = "timeline"
        let pane = ModernTimingResultPane(
            result: try realFixtureResult(),
            selectedTab: Binding(
                get: { selection },
                set: { selection = $0 }
            )
        )
        #expect(pane.tabs.map(\.0) == ["timeline", "grouped", "calendar"])
        #expect(pane.moreTabs.map(\.0) == ["diagnostics", "json"])
    }

    @Test func calendarGroupsByDisplayTimezoneISOWeek() {
        #expect(
            ModernTimingCalendarView.weekKey(
                for: "2024-01-01T08:00:00.000+08:00",
                timeZoneIdentifier: "Asia/Shanghai"
            ) == "2024-W01"
        )
    }

    @Test func staleGenerationCannotCommitModernTimingResult() throws {
        let result = try realFixtureResult()
        let viewModel = CalculationViewModel()
        let staleGeneration = viewModel.beginRun(isStoppable: true)
        _ = viewModel.beginRun(isStoppable: true)

        #expect(!viewModel.commitModernTimingResult(result, generation: staleGeneration))
        #expect(viewModel.modernTimingResult == nil)
        #expect(viewModel.commitModernTimingResult(result, generation: viewModel.runGeneration))
        #expect(viewModel.modernTimingResult?.events.count == result.events.count)
    }

    private var pointSet: ModernPointSet {
        ModernPointSet(
            bodyIDs: ["SUN", "MOON", "SUN"],
            includeNodes: true,
            nodeMode: "true_node",
            customAsteroids: [433, 433],
            angleIDs: ["ASC", "ASC"],
            houseCusps: [1],
            lotIDs: ["fortune", "fortune"]
        )
    }

    private func decodedResult() throws -> ModernTimingResult {
        let json = #"""
        {
          "meta": {
            "schema_version": 1,
            "start_utc": "2030-01-01T00:00:00Z",
            "end_utc": "2030-02-01T00:00:00Z",
            "display_timezone": "Asia/Shanghai",
            "technique_ids": ["transit"],
            "technique_configs": [{
              "id": "transit",
              "moving_body_ids": ["SATURN"],
              "event_types": ["aspect", "station"],
              "aspects": [{"id": "conjunction", "name": "合相", "angle": 0.0, "orb": 1.0}]
            }],
            "target_count": 1,
            "estimated_work_units": 42,
            "ephemeris": "Swiss Ephemeris",
            "effective_point_set": {
              "body_ids": ["SUN"],
              "include_nodes": false,
              "node_mode": "true_node",
              "custom_asteroids": [],
              "angle_ids": ["ASC"],
              "house_cusps": [],
              "lot_ids": []
            }
          },
          "events": [
            {
              "id": "transit|SATURN|conjunction|ASC|20300115T031522Z",
              "group_id": "transit|SATURN|conjunction|ASC",
              "source_type": "transit",
              "event_type": "aspect",
              "moving_point_id": "SATURN",
              "moving_point_name": "土星",
              "target_point_id": "ASC",
              "target_point_name": "ASC",
              "target_point_kind": "angle",
              "aspect_id": "conjunction",
              "aspect_name": "合相",
              "aspect_angle": 0.0,
              "orb_limit": 1.0,
              "entering_utc": "2030-01-10T04:11:02Z",
              "exact_utc": "2030-01-15T03:15:22Z",
              "leaving_utc": "2030-01-20T08:02:41Z",
              "exact_local": "2030-01-15T11:15:22+08:00",
              "motion": "retrograde",
              "moving_longitude": 123.456,
              "target_longitude": 123.456,
              "exact_orb": 0.0,
              "pass_index_in_window": 2,
              "pass_count_in_window": 3,
              "window_clipped_start": false,
              "window_clipped_end": false,
              "method_key": "transit_longitude_bisection"
            },
            {
              "id": "transit|MERCURY|station|20300125T000000Z",
              "group_id": "transit|MERCURY|station",
              "source_type": "transit",
              "event_type": "station",
              "moving_point_id": "MERCURY",
              "moving_point_name": "水星",
              "target_point_id": null,
              "target_point_name": null,
              "target_point_kind": null,
              "aspect_id": null,
              "aspect_name": null,
              "aspect_angle": null,
              "orb_limit": null,
              "entering_utc": null,
              "exact_utc": "2030-01-25T00:00:00Z",
              "leaving_utc": null,
              "exact_local": "2030-01-25T08:00:00+08:00",
              "motion": "stationary",
              "moving_longitude": 300.0,
              "target_longitude": null,
              "exact_orb": null,
              "pass_index_in_window": 1,
              "pass_count_in_window": 1,
              "window_clipped_start": true,
              "window_clipped_end": true,
              "method_key": "transit_station_bisection"
            }
          ],
          "warnings": ["fixture warning"],
          "section_errors": null
        }
        """#
        return try JSONDecoder().decode(ModernTimingResult.self, from: Data(json.utf8))
    }

    private func realFixtureResult() throws -> ModernTimingResult {
        let url = try #require(
            Bundle.module.url(
                forResource: "modern-timing-result",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        return try JSONDecoder().decode(ModernTimingResult.self, from: Data(contentsOf: url))
    }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func workEstimate(_ workUnits: Int) -> ModernTimingWorkEstimate {
        ModernTimingWorkEstimate(
            workUnits: workUnits,
            stepUnits: 1,
            movingPointCount: 1,
            targetCount: 1,
            aspectBranchCount: 1,
            techniques: []
        )
    }
}
