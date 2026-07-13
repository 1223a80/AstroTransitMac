import Foundation
import SwiftUI
import Testing
@testable import TransitStudio

@MainActor
struct MidpointContractTests {
    @Test func decodesFixedMidpointWireContractFromInlineJSON() throws {
        let result = try decodedResult()

        #expect(result.meta.schemaVersion == 1)
        #expect(result.meta.method == "circular_midpoint_axis_360")
        #expect(result.meta.modulus == 360)
        #expect(result.meta.includeOppositeAxis)
        #expect(result.meta.activationSources == ["natal", "transit"])
        #expect(result.meta.birthUTC == "1990-01-01T04:00:00Z")
        #expect(result.meta.referenceUTC == "2030-01-15T00:00:00Z")
        #expect(result.meta.ephemeris == "Swiss Ephemeris")
        #expect(result.meta.effectivePointSet.bodyIDs == ["SUN", "MOON"])

        let axis = try #require(result.axes.first)
        #expect(axis.id == "midpoint|MOON|SUN")
        #expect(axis.pointAID == "MOON")
        #expect(axis.pointBID == "SUN")
        #expect(axis.midpointLongitude == 0)
        #expect(axis.oppositeLongitude == 180)
        #expect(axis.trace.inputLongitudes == [350, 10])

        let treeHit = try #require(result.trees.first?.hits.first)
        #expect(treeHit.focusPointID == "ASC")
        #expect(treeHit.axisBranch == "direct")
        #expect(treeHit.referenceUTC == nil)

        let activation = try #require(result.snapshotActivations.first)
        #expect(activation.focusPointID == nil)
        #expect(activation.sourceType == "transit")
        #expect(activation.axisBranch == "opposite")
        #expect(activation.hitLongitude == 179.7)
        #expect(activation.axisLongitude == 180)
        #expect(activation.referenceUTC == "2030-01-15T00:00:00Z")
        #expect(result.sectionErrors?["solar_arc"] == "anchor unavailable")
    }

    @Test func paneDeclaresRequiredPrimaryAndMoreTabs() throws {
        var selection = "axes"
        let pane = MidpointResultPane(
            result: try decodedResult(),
            selectedTab: Binding(
                get: { selection },
                set: { selection = $0 }
            ),
            onSendAxesToTiming: { _ in }
        )

        #expect(pane.tabs.map(\.0) == ["axes", "trees", "activations"])
        #expect(pane.moreTabs.map(\.0) == ["diagnostics", "json"])
        #expect(pane.tabTitle == "中点轴")
    }

    @Test func markdownCSVAndJSONExportsPreserveAxisAndActivationFacts() throws {
        let result = try decodedResult()
        let markdown = MarkdownExportBuilder.midpoint(result)
        let csv = TextExportBuilder.csv(result)
        let json = TextExportBuilder.json(result)

        #expect(markdown.contains("# Midpoints v1"))
        #expect(markdown.contains("midpoint\\|MOON\\|SUN"))
        #expect(markdown.contains("## 中点树"))
        #expect(markdown.contains("## 单参考时点激活"))
        #expect(markdown.contains("transit"))
        #expect(markdown.contains("2030-01-15T00:00:00Z"))

        #expect(csv.hasPrefix("section,id,focus_point_id,focus_point_name,source_point_id,source_point_name,axis_id,point_a_id,point_a_name,point_b_id,point_b_name,direct_longitude,opposite_longitude,axis_branch"))
        #expect(csv.contains("axis,midpoint|MOON|SUN"))
        #expect(csv.contains(",MOON,月亮,SUN,太阳,0.00000000,180.00000000,"))
        #expect(csv.contains("snapshot_activation,activation-transit-mars-opposite"))
        #expect(csv.contains(",opposite,179.70000000,180.00000000,"))
        #expect(json.contains("\"snapshot_activations\""))
        #expect(json.contains("\"axis_branch\""))
        #expect(json.contains("\"effective_point_set\""))
        #expect(json.contains("\"input_longitudes\""))
    }

    private func decodedResult() throws -> MidpointResult {
        let json = #"""
        {
          "meta": {
            "schema_version": 1,
            "method": "circular_midpoint_axis_360",
            "modulus": 360,
            "activation_orb": 1.0,
            "include_opposite_axis": true,
            "activation_sources": ["natal", "transit"],
            "birth_utc": "1990-01-01T04:00:00Z",
            "reference_utc": "2030-01-15T00:00:00Z",
            "ephemeris": "Swiss Ephemeris",
            "effective_point_set": {
              "body_ids": ["SUN", "MOON"],
              "include_nodes": false,
              "node_mode": "true_node",
              "custom_asteroids": [],
              "angle_ids": ["ASC"],
              "house_cusps": [],
              "lot_ids": [],
              "resolved_body_ids": ["SUN", "MOON"]
            }
          },
          "axes": [
            {
              "id": "midpoint|MOON|SUN",
              "point_a_id": "MOON",
              "point_a_name": "月亮",
              "point_b_id": "SUN",
              "point_b_name": "太阳",
              "midpoint_longitude": 0.0,
              "opposite_longitude": 180.0,
              "midpoint_text": "白羊 00°00′00″",
              "opposite_text": "天秤 00°00′00″",
              "trace": {"input_longitudes": [350.0, 10.0]}
            }
          ],
          "trees": [
            {
              "focus_point_id": "ASC",
              "focus_point_name": "上升点",
              "hits": [
                {
                  "id": "tree-asc-direct",
                  "focus_point_id": "ASC",
                  "focus_point_name": "上升点",
                  "source_point_id": "ASC",
                  "source_point_name": "上升点",
                  "axis_id": "midpoint|MOON|SUN",
                  "axis_branch": "direct",
                  "hit_longitude": 0.4,
                  "axis_longitude": 0.0,
                  "separation": 0.4,
                  "orb": 0.4,
                  "source_type": "natal",
                  "reference_utc": null
                }
              ]
            }
          ],
          "snapshot_activations": [
            {
              "id": "activation-transit-mars-opposite",
              "focus_point_id": null,
              "focus_point_name": null,
              "source_point_id": "MARS",
              "source_point_name": "火星",
              "axis_id": "midpoint|MOON|SUN",
              "axis_branch": "opposite",
              "hit_longitude": 179.7,
              "axis_longitude": 180.0,
              "separation": 0.3,
              "orb": 0.3,
              "source_type": "transit",
              "reference_utc": "2030-01-15T00:00:00Z"
            }
          ],
          "warnings": ["inline fixture warning"],
          "section_errors": {"solar_arc": "anchor unavailable"}
        }
        """#
        return try JSONDecoder().decode(MidpointResult.self, from: Data(json.utf8))
    }
}
