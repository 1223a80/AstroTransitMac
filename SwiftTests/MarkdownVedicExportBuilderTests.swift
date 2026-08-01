import Foundation
import Testing
@testable import TransitStudio

/// Field-level content tests for the Vedic Markdown export, driven by the
/// real `vedic-result` fixture. Previously only shape-level assertions in
/// MarkdownShapeContractTests touched this builder.
struct MarkdownVedicExportBuilderTests {
    private func fixtureData(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Fixtures"
        ))
        return try Data(contentsOf: url)
    }

    private func decodedResult() throws -> VedicResult {
        try JSONDecoder().decode(VedicResult.self, from: fixtureData("vedic-result"))
    }

    @Test func fullExportContainsBasicInfoAndSettings() throws {
        let result = try decodedResult()
        let markdown = MarkdownVedicExportBuilder.export(result)

        #expect(markdown.hasPrefix("# 吠陀排盘 / Vedic Horoscope"))
        #expect(markdown.contains("## 基本信息"))
        #expect(markdown.contains("## 重要设置"))
        #expect(markdown.contains("- 出生本地时间: " + result.meta.birthLocal))
        #expect(markdown.contains("- 出生 UTC: " + result.meta.birthUtc))
        #expect(markdown.contains("- 经纬度: "))
        #expect(markdown.contains("- Ayanamsha: True Citra"))
        #expect(markdown.contains("- 黄道制: 恒星黄道"))
    }

    @Test func fullExportContainsPanchangaFacts() throws {
        let result = try decodedResult()
        let markdown = MarkdownVedicExportBuilder.export(result)

        #expect(markdown.contains("## 五支历 Panchanga (D1)"))
        let tithi = try #require(result.panchanga?.tithi)
        #expect(markdown.contains(tithi.nameZh))
        let nakshatra = try #require(result.panchanga?.nakshatra)
        #expect(markdown.contains(nakshatra.nameZh))
    }

    @Test func fullExportContainsDasaAndShadbalaSections() throws {
        let result = try decodedResult()
        let markdown = MarkdownVedicExportBuilder.export(result)

        #expect(markdown.contains("## Vimsottari Dasa"))
        #expect(markdown.contains("## Shadbala"))
        #expect(markdown.contains("## Yogas (D1)"))

        let dasas = try #require(result.vimshottari?.mahaDasas)
        if let first = dasas.first {
            #expect(markdown.contains(first.lord))
        }
    }

    @Test func sectionFilteringOnlyEmitsRequestedSections() throws {
        let result = try decodedResult()
        let onlyPanchanga = MarkdownVedicExportBuilder.export(result, sections: [.panchanga])

        #expect(onlyPanchanga.contains("## 五支历 Panchanga (D1)"))
        // Basic info/settings are always included; other sections are not.
        #expect(onlyPanchanga.contains("## 基本信息"))
        #expect(!onlyPanchanga.contains("## 星座索引表"))
        #expect(!onlyPanchanga.contains("## Vimsottari Dasa"))
        #expect(!onlyPanchanga.contains("## Rāśi 盘 (D1)"))

        let noPanchanga = MarkdownVedicExportBuilder.export(result, sections: [.signIndex])
        #expect(noPanchanga.contains("## 星座索引表"))
        #expect(!noPanchanga.contains("## 五支历 Panchanga (D1)"))
    }

    @Test func warningsSectionAppearsOnlyWhenWarningsExist() throws {
        let result = try decodedResult()
        let withWarnings = MarkdownVedicExportBuilder.export(result)
        // Fixture currently has no warnings; export must stay clean either way.
        if let warnings = result.warnings, !warnings.isEmpty {
            for warning in warnings {
                #expect(withWarnings.contains(warning))
            }
        } else {
            #expect(!withWarnings.contains("## 警告"))
        }
    }
}
