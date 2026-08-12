import Foundation
import Testing
@testable import TransitStudio

@Suite("Rectification evidence Swift contract")
struct RectificationEvidenceTests {
    @Test func requestEncodesCurrentCandidateAndEventWindow() throws {
        let event = RectificationEvidenceSourceEvent(
            id: "career-1",
            category: "career",
            description: "documented promotion",
            sourceQuality: "documented_day",
            confidence: 0.9,
            holdout: true,
            start: ChartMoment(year: 2025, month: 4, day: 14, hour: 0, minute: 0, timezone: "GMT+8", second: 1),
            end: ChartMoment(year: 2025, month: 4, day: 15, hour: 0, minute: 0, timezone: "GMT+8", second: 2)
        )
        let request = RectificationEvidenceRequest(
            birth: BirthSettings(
                moment: ChartMoment(year: 1990, month: 1, day: 1, hour: 12, minute: 0, timezone: "GMT+8", second: 7),
                latitude: 31.2304,
                longitude: 121.4737,
                houseSystem: "placidus",
                zodiac: "tropical",
                boundsSystem: "egyptian",
                triplicitySystem: "dorothean"
            ),
            events: [event],
            displayTimezone: "UTC",
            candidateWindowSeconds: 0,
            candidateStepSeconds: 1,
            maxCandidates: 1,
            primaryDirectionKeys: ["naibod_mean"],
            targetAngleIDs: ["ASC", "MC", "DSC", "IC"],
            maxAge: 120,
            maxEvidenceRowsPerFamily: 12,
            confirmedHeavyScan: false
        )

        let data = try JSONEncoder().encode(request)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["mode"] as? String == "rectify_evidence")
        #expect(json["candidate_window_seconds"] as? Int == 0)
        #expect(json["candidate_step_seconds"] as? Int == 1)
        #expect(json["max_candidates"] as? Int == 1)
        #expect(json["display_timezone"] as? String == "UTC")
        let birth = try #require(json["birth"] as? [String: Any])
        let moment = try #require(birth["moment"] as? [String: Any])
        #expect(moment["second"] as? Int == 7)
        let events = try #require(json["events"] as? [[String: Any]])
        #expect(events[0]["source_quality"] as? String == "documented_day")
        #expect(events[0]["holdout"] as? Bool == true)
    }

    @Test func responseDecodesMethodSeparatedEvidenceAndBoundaries() throws {
        let json = """
        {
          "schema":{"name":"rectification-evidence-packet","version":"1.0","schema_id":"rectification-evidence-packet/1.0"},
          "meta":{"mode":"rectify_evidence","candidate_count":1,"event_count":1,"zodiac":"tropical","house_system_requested":"placidus","display_timezone":"UTC","scientific_validation":"not_established","automatic_best_time":false},
          "requested_config":{"candidate_window_seconds":0,"candidate_step_seconds":1,"max_candidates":1,"primary_direction_keys":["naibod_mean"],"target_angle_ids":["ASC","MC","DSC","IC"],"max_age":120,"max_evidence_rows_per_family":12,"confirmed_heavy_scan":false,"timing_technique_ids":["transit","secondary_progression","solar_arc"]},
          "method_profiles":[{"profile_id":"primary_motion_planet_to_angles_v1","family":"primary_motion","status":"formal_geometry_subset","role":"fine_timing","independence_group":"primary_motion","includes":["planet-to-angle"],"excludes":["full Placidian suite"]}],
          "events":[{"id":"career-1","category":"career","description":"promotion","source_quality":"documented_day","confidence":0.9,"holdout":true,"start":{"year":2025,"month":4,"day":14,"hour":0,"minute":0,"second":0,"timezone":"GMT+8"},"end":{"year":2025,"month":4,"day":15,"hour":0,"minute":0,"second":0,"timezone":"GMT+8"}}],
          "candidates":[{
            "offset_seconds":0,"birth_local":"1990-01-01T12:00:07+08:00","birth_utc":"1990-01-01T04:00:07+00:00","house_system":"Placidus","angles":{"ASC":1.0,"MC":2.0,"DSC":181.0,"IC":182.0},
            "family_hit_counts":{"primary_motion":1,"transit":1,"secondary_progression":0,"solar_arc":0},"warnings":["SUN 对 ASC 的升降方向不可得：绕极状态。"],
            "evidence_by_event":[{
              "event_id":"career-1","event_category":"career","holdout":true,
              "primary_motion":{"method_family":"primary_motion","independence_group":"primary_motion","window_hit_count":1,"nearest_distance_days":0,"truncated":true,"evidence":[{
                "id":"pm-1","method_profile":"primary_motion_planet_to_angles_v1","method_family":"primary_motion","method_status":"formal_geometry_subset","independence_group":"primary_motion","key_profile":"naibod_mean","key_rate_deg_per_year":0.98564733,"promissor_id":"MOON","promissor":"月亮","significator_id":"ASC","significator":"ASC","aspect_type":"conjunction","direction_type":"direct","arc_signed":34.776930941,"arc_abs":34.776930941,"age_years":35.283341092,"event_datetime_after_birth":"2025-04-14T11:25:01.234793+08:00","event_date_after_birth":"2025-04-14","proxy":false,"complete_primary_directions_suite":false,"geometry":{"right_ascension":330.5,"declination":-10.8,"armc":282.0,"ascensional_difference":-6.6,"coordinate":"oblique_ascension","promissor_coordinate":337.2,"target_coordinate":12.0,"arc_sign_convention":"target_minus_promissor_shortest_arc"},"event_id":"career-1","distance_to_event_window_days":0,"inside_event_window":true
              }]},
              "families":{
                "transit":{"method_family":"transit","independence_group":"transit","exact_hit_count":1,"truncated":false,"evidence":[{"id":"t-1","source_type":"transit","exact_utc":"2025-04-14T04:00:00.123Z","exact_local":"2025-04-14T04:00:00.123+00:00","moving_point_id":"SATURN","moving_point_name":"土星","target_point_id":"ASC","target_point_name":"ASC","aspect_id":"square","aspect_name":"刑相","motion":"direct","exact_orb":0,"orb_limit":1,"pass_index_in_window":1,"pass_count_in_window":1,"window_clipped_start":true,"window_clipped_end":false,"method_key":"transit_aspect_root","event_id":"career-1","distance_to_event_midpoint_days":0.25}]},
                "secondary_progression":{"method_family":"secondary_progression","independence_group":"day_for_year","exact_hit_count":0,"truncated":false,"evidence":[]},
                "solar_arc":{"method_family":"solar_arc","independence_group":"day_for_year_solar_anchor","exact_hit_count":0,"truncated":false,"evidence":[]}
              },
              "timing_meta":{},"section_errors":{"solar_arc":"synthetic warning"}
            }]
          }],
          "warnings":[],
          "calculation_assumptions":["Separated evidence; no unique birth time."]
        }
        """

        let response = try JSONDecoder().decode(RectificationEvidenceResponse.self, from: Data(json.utf8))
        #expect(response.schema.schemaID == "rectification-evidence-packet/1.0")
        #expect(response.meta.automaticBestTime == false)
        #expect(response.meta.scientificValidation == "not_established")
        #expect(response.candidates.count == 1)
        let candidate = response.candidates[0]
        #expect(candidate.familyHitCounts.primaryMotion == 1)
        #expect(candidate.warnings[0].contains("绕极"))
        let event = candidate.evidenceByEvent[0]
        #expect(event.primaryMotion.truncated)
        #expect(event.primaryMotion.evidence[0].geometry.ascensionalDifference == -6.6)
        #expect(event.primaryMotion.evidence[0].completePrimaryDirectionsSuite == false)
        #expect(event.families.transit.independenceGroup == "transit")
        #expect(event.families.secondaryProgression.independenceGroup == "day_for_year")
        #expect(event.families.solarArc.independenceGroup == "day_for_year_solar_anchor")
        #expect(event.families.transit.evidence[0].isWindowClipped)
        #expect(event.sectionErrors != nil)

        let raw = try #require(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        #expect(raw["aggregate_score"] == nil)
        #expect(raw["best_candidate"] == nil)
        #expect(raw["rectified_birth_time"] == nil)
    }

    @Test func eventDraftValidationAndFractionalOffsetMoment() throws {
        let zone = try #require(TimeZone(secondsFromGMT: 5 * 3600 + 45 * 60))
        var draft = RectificationEventDraft.makeDefault(index: 1, timeZone: zone, now: Date(timeIntervalSince1970: 0))
        #expect(RectificationEventDraft.validationMessage(for: [draft]) == nil)
        draft.eventID = " "
        #expect(RectificationEventDraft.validationMessage(for: [draft]) == "每个事件都需要非空 ID。")
        draft.eventID = "event-1"
        let source = draft.sourceEvent(timezone: "GMT+5:45", timeZone: zone)
        #expect(source.start.hour == 0)
        #expect(source.start.minute == 0)
        #expect(source.start.timezone == "GMT+5:45")

        var duplicate = draft
        duplicate = RectificationEventDraft(
            id: UUID(), eventID: draft.eventID, category: draft.category,
            description: draft.description, sourceQuality: draft.sourceQuality,
            confidence: draft.confidence, holdout: draft.holdout,
            start: draft.start, end: draft.end
        )
        #expect(RectificationEventDraft.validationMessage(for: [draft, duplicate]) == "事件 ID 不能重复。")
    }

    @Test func evidenceProgressPreservesNestedAndPacketLabels() {
        let buffer = BackendProgressLineBuffer()
        let updates = buffer.append(Data("{\"progress\":0.5,\"label\":\"transit:SATURN\"}\n{\"progress\":1.0,\"label\":\"rectify_evidence:0:career-1\"}\n".utf8))
        #expect(updates == [
            BackendProgressUpdate(progress: 0.5, label: "transit:SATURN"),
            BackendProgressUpdate(progress: 1.0, label: "rectify_evidence:0:career-1"),
        ])
    }

    @Test func evidenceViewKeepsAllFamiliesVisibleWithoutRankingLanguage() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("Sources/TransitStudio/RectificationEvidenceView.swift"),
            encoding: .utf8
        )
        for required in ["主运动", "行运", "次限", "太阳弧", "显示已截断", "绕极", "方法与独立性边界", "非评分"] {
            #expect(source.contains(required), "evidence UI must expose \(required)")
        }
        for forbidden in ["aggregate_score", "best_candidate", "rectified_birth_time", "最佳候选", "推荐时间"] {
            #expect(!source.contains(forbidden), "evidence UI must not introduce ranking field/language \(forbidden)")
        }
    }
}
