import Foundation
import Testing
@testable import TransitStudio

/// Contract tests for the `scan` backend mode: real-output fixture decoding
/// and the Markdown scan export.
struct ScanResultTests {
    private func fixtureData(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        return try Data(contentsOf: url)
    }

    @Test func decodesRealScanFixtureFromBackendOutput() throws {
        let data = try fixtureData("scan-result")
        let result = try JSONDecoder().decode(ScanResult.self, from: data)

        #expect(result.meta.label == "May-Jun 2026")
        #expect(result.meta.scanKind == "aspect")
        #expect(result.meta.startUTC == "2026-04-30T16:00:00+00:00")
        #expect(result.meta.endUTC == "2026-06-30T15:59:00+00:00")
        #expect(result.meta.ephemeris == "Swiss Ephemeris")
        #expect(result.meta.targetCount == 14)

        // The real output produced 346 hits; decode must preserve all of them.
        #expect(result.hits.count == 346)
        #expect(result.warnings.isEmpty)

        let first = try #require(result.hits.first)
        #expect(!first.id.isEmpty)
        #expect(!first.window.isEmpty)
        #expect(!first.dateTimeLocal.isEmpty)
        #expect(!first.transitBodyID.isEmpty)
        #expect(!first.transitBodyName.isEmpty)
        #expect(!first.aspectID.isEmpty)
        #expect(!first.aspectName.isEmpty)
        #expect(first.targetLongitude >= 0 && first.targetLongitude < 360)
        #expect(first.transitLongitude >= 0 && first.transitLongitude < 360)
        #expect(!first.transitPosition.isEmpty)
        #expect(first.exactLongitude >= 0 && first.exactLongitude < 360)
    }

    @Test func nullableHitFieldsDecodeWhenMissingOrNull() throws {
        let data = Data(#"""
        {
          "meta": {
            "label": "Optional fields",
            "scan_kind": "aspect",
            "start_utc": "2026-01-01T00:00:00+00:00",
            "end_utc": "2026-01-02T00:00:00+00:00",
            "ephemeris": "Swiss Ephemeris",
            "target_count": 1
          },
          "hits": [
            {
              "id": "missing-optionals",
              "window": "test",
              "date_time_local": "2026-01-01 12:00",
              "transit_body_id": "SUN",
              "transit_body_name": "太阳",
              "aspect_id": "conjunction",
              "aspect_name": "合相",
              "target_name": "Natal Sun",
              "target_longitude": 10.0,
              "transit_longitude": 10.0,
              "transit_position": "10°00'00\" 白羊",
              "exact_longitude": 10.0
            },
            {
              "id": "null-optionals",
              "window": "test",
              "date_time_local": "2026-01-01 13:00",
              "transit_body_id": "MOON",
              "transit_body_name": "月亮",
              "aspect_id": "square",
              "aspect_name": "刑相",
              "aspect_angle": null,
              "target_name": "Natal Moon",
              "target_longitude": 20.0,
              "target_position": null,
              "transit_longitude": 110.0,
              "transit_position": "20°00'00\" 巨蟹",
              "exact_transit_position": null,
              "exact_longitude": 110.0,
              "orb": null,
              "phase": null,
              "scan_step": null,
              "exact_method": null,
              "max_orb": null,
              "priority_score": null,
              "priority_grade": null
            }
          ],
          "warnings": []
        }
        """#.utf8)
        let result = try JSONDecoder().decode(ScanResult.self, from: data)

        #expect(result.hits.count == 2)
        for hit in result.hits {
            #expect(hit.aspectAngle == nil)
            #expect(hit.targetPosition == nil)
            #expect(hit.exactTransitPosition == nil)
            #expect(hit.orb == nil)
            #expect(hit.phase == nil)
            #expect(hit.scanStep == nil)
            #expect(hit.exactMethod == nil)
            #expect(hit.maxOrb == nil)
            #expect(hit.priorityScore == nil)
            #expect(hit.priorityGrade == nil)
            #expect(hit.priorityGradeSortValue.isEmpty)
        }
    }

    @Test func markdownScanExportRendersMetadataAndEveryHitRow() throws {
        let data = try fixtureData("scan-result")
        let result = try JSONDecoder().decode(ScanResult.self, from: data)
        let markdown = MarkdownExportBuilder.scan(result)
        let lines = markdown.split(separator: "\n").map(String.init)

        #expect(markdown.hasPrefix("# 窗口扫描"))
        #expect(lines.contains("## 元数据"))
        #expect(lines.contains("## 命中"))
        #expect(lines.contains("- 名称：May-Jun 2026"))
        #expect(lines.contains("- 类型：aspect"))
        #expect(lines.contains("- 开始 UTC：2026-04-30T16:00:00+00:00"))
        #expect(lines.contains("- 目标数：14"))

        let header = "| 等级 | 窗口 | 本地时间 | 行运 | 相位 | 角度 | 目标 | 目标位置 | 精确行运位置 | Orb | 阶段 | 方法 |"
        #expect(lines.contains(header))

        // One table body row per hit, plus header and separator rows.
        let tableRows = lines.filter { $0.hasPrefix("| ") }
        #expect(tableRows.count == result.hits.count + 2)

        // No bare JSON dumps leak into the export.
        #expect(!markdown.contains("{\""))
        #expect(!markdown.contains("scan_kind"))
    }

    @Test func markdownScanExportRendersEmptyStateWhenNoHits() {
        let result = ScanResult(
            meta: ScanMeta(
                label: "Empty window",
                scanKind: "aspect",
                startUTC: "2026-01-01T00:00:00+00:00",
                endUTC: "2026-01-02T00:00:00+00:00",
                ephemeris: "Swiss Ephemeris",
                targetCount: 0
            ),
            hits: [],
            warnings: ["no targets configured"]
        )
        let markdown = MarkdownExportBuilder.scan(result)
        let lines = markdown.split(separator: "\n").map(String.init)

        #expect(markdown.hasPrefix("# 窗口扫描"))
        #expect(lines.contains("| - | - | - | - | - | - | - | - | - | - | - | - |"))
        #expect(lines.contains("## 警告"))
        #expect(lines.contains("- no targets configured"))
    }
}
