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

    @Test func nullableHitFieldsDecodeAsOptionalTypes() throws {
        let data = try fixtureData("scan-result")
        let result = try JSONDecoder().decode(ScanResult.self, from: data)

        // These fields are optional in the wire contract; decoding must not
        // crash on missing values and must map null to nil.
        for hit in result.hits {
            _ = hit.aspectAngle
            _ = hit.targetPosition
            _ = hit.exactTransitPosition
            _ = hit.orb
            _ = hit.phase
            _ = hit.scanStep
            _ = hit.exactMethod
            _ = hit.maxOrb
            _ = hit.priorityScore
            _ = hit.priorityGrade
        }

        // Every hit must carry its identity and the two sort/grade helpers.
        let ids = Set(result.hits.map(\.id))
        #expect(ids.count == result.hits.count)
        #expect(result.hits.allSatisfy { $0.priorityGradeSortValue == ($0.priorityGrade ?? "") })
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
