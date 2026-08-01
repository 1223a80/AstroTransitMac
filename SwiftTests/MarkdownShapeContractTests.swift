import Foundation
import Testing
@testable import TransitStudio

/// 全模式 Markdown 输出「形状」契约。
///
/// 病根历史:Horary v2.1 的 `MarkdownExportBuilder.horary` 曾把每个 section 的原始
/// JSON 整行灌进 markdown(约 40 万 tokens、人不可读),而现有测试只断言
/// `contains(JSON 字段名)`,反而固化了错误形状。本测试对每个有 fixture 的模式
/// 统一锁定:输出必须是真 markdown(以 `#` 开头、含 `##` 节)、不得出现裸 JSON 行
/// 或 `- full: {` 内嵌、体积不得超过预算。
struct MarkdownShapeContractTests {

    private func fixtureData(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private func nakedJSONLines(in markdown: String) -> [String] {
        var inCodeBlock = false
        var matches: [String] = []

        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                inCodeBlock.toggle()
                continue
            }
            guard !inCodeBlock, !trimmed.isEmpty else { continue }

            var candidates: [String] = []
            if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                candidates.append(trimmed)
            }
            if trimmed.hasPrefix("- ") {
                candidates.append(String(trimmed.dropFirst(2)))
            }
            if let separator = trimmed.range(of: ": ") {
                candidates.append(String(trimmed[separator.upperBound...]))
            }

            let containsJSONContainer = candidates.contains { candidate in
                guard candidate.hasPrefix("{") || candidate.hasPrefix("["),
                      let data = candidate.data(using: .utf8),
                      let value = try? JSONSerialization.jsonObject(with: data) else {
                    return false
                }
                return value is [String: Any] || value is [Any]
            }
            if containsJSONContainer {
                matches.append(trimmed)
            }
        }

        return matches
    }

    private func assertMarkdownShape(_ md: String, mode: String) {
        #expect(md.hasPrefix("# "), "\(mode): markdown 必须以 `# ` 标题开头")
        // 允许两种节风格:二级标题(## x)、表格,或超过 10 行且含列表项的 markdown;
        // 纯文本堆砌(如单行 JSON)不放行。
        let hasSections = md.contains("## ")
        let hasTables = md.contains("| ")
        let hasList = md.components(separatedBy: "\n").count > 10 && md.contains("\n- ")
        #expect(hasSections || hasTables || hasList,
                "\(mode): 输出缺少 markdown 结构")
        // JSON dump 的对象/数组形态都要抓:整行、列表项、键值前缀。
        // 旧 horary dump 的实际形态是 `- {...}` 与 `- full: {...}`,仅匹配整行会放水。
        // ```json 代码块围栏内的 JSON 是合法 markdown(prenatal packet、ZR raw),豁免。
        let nakedJSON = nakedJSONLines(in: md)
        let fullDumps = nakedJSON.filter { $0.hasPrefix("- full: {") }
        #expect(nakedJSON.isEmpty, "\(mode): 出现裸 JSON 行 \(nakedJSON.prefix(2))")
        #expect(fullDumps.isEmpty, "\(mode): 出现 `- full: {` 内嵌 JSON 行")
        #expect(md.utf8.count < 100_000, "\(mode): markdown 体积超预算 \(md.utf8.count) bytes")
    }

    @Test func nakedJSONDetectionCoversObjectsArraysAndFences() {
        let dumps = """
        # Sample
        {"object": true}
        - [1, 2, 3]
        - full: {"nested": "value"}
        """
        #expect(nakedJSONLines(in: dumps).count == 3)

        let fenced = """
        # Sample
        ```json
        {"allowed": true}
        [1, 2, 3]
        ```
        """
        #expect(nakedJSONLines(in: fenced).isEmpty)
    }

    // MARK: - 核心模式

    @Test func horaryMarkdownShape() throws {
        let result = try JSONDecoder().decode(HoraryDataPacket.self, from: fixtureData("horary-result"))
        assertMarkdownShape(MarkdownExportBuilder.horary(result), mode: "horary")
    }

    @Test func vedicMarkdownShape() throws {
        let result = try JSONDecoder().decode(VedicResult.self, from: fixtureData("vedic-result"))
        assertMarkdownShape(MarkdownExportBuilder.vedic(result), mode: "vedic")
    }

    @Test func midpointMarkdownShape() throws {
        let result = try JSONDecoder().decode(MidpointResult.self, from: fixtureData("midpoint-result"))
        assertMarkdownShape(MarkdownExportBuilder.midpoint(result), mode: "midpoint")
    }

    @Test func modernTimingMarkdownShape() throws {
        let result = try JSONDecoder().decode(ModernTimingResult.self, from: fixtureData("modern-timing-result"))
        assertMarkdownShape(MarkdownExportBuilder.modernTiming(result), mode: "modernTiming")
    }

    @Test func progressedCompositeMarkdownShape() throws {
        let result = try JSONDecoder().decode(ProgressedCompositeResult.self, from: fixtureData("progressed-composite-result"))
        assertMarkdownShape(MarkdownExportBuilder.progressedComposite(result), mode: "progressedComposite")
    }

    @Test func compositeMarkdownShape() throws {
        let result = try JSONDecoder().decode(CompositeResult.self, from: fixtureData("composite-result"))
        assertMarkdownShape(
            MarkdownModernExportBuilder.compositeOrDavison(title: "Composite", result: result),
            mode: "composite"
        )
    }

    @Test func davisonMarkdownShape() throws {
        let result = try JSONDecoder().decode(DavisonResult.self, from: fixtureData("davison-result"))
        assertMarkdownShape(
            MarkdownModernExportBuilder.compositeOrDavison(title: "Davison", result: result),
            mode: "davison"
        )
    }

    @Test func progressionMarkdownShape() throws {
        let result = try JSONDecoder().decode(ProgressionResult.self, from: fixtureData("progressions-result"))
        assertMarkdownShape(MarkdownModernExportBuilder.progression(result), mode: "progressions")
    }

    @Test func relocationMarkdownShape() throws {
        let result = try JSONDecoder().decode(RelocationResult.self, from: fixtureData("relocation-result"))
        assertMarkdownShape(MarkdownExportBuilder.relocation(result), mode: "relocation")
    }

    @Test func prenatalParansMarkdownShape() throws {
        let result = try JSONDecoder().decode(PrenatalParansResult.self, from: fixtureData("prenatal-parans-result"))
        assertMarkdownShape(MarkdownExportBuilder.prenatalParans(result), mode: "prenatalParans")
    }

    @Test func retrogradeCyclesMarkdownShape() throws {
        let result = try JSONDecoder().decode(RetrogradeCyclesResult.self, from: fixtureData("retrograde-cycles-result"))
        assertMarkdownShape(MarkdownExportBuilder.retrogradeCycles(result), mode: "retrogradeCycles")
    }

    @Test func draconicHeliocentricMarkdownShape() throws {
        let result = try JSONDecoder().decode(DraconicHeliocentricResult.self, from: fixtureData("draconic-heliocentric-result"))
        assertMarkdownShape(MarkdownExportBuilder.draconicHeliocentric(result), mode: "draconicHeliocentric")
    }

    @Test func astrocartographyMarkdownShape() throws {
        let result = try JSONDecoder().decode(AstrocartographyResult.self, from: fixtureData("astrocartography-result"))
        assertMarkdownShape(MarkdownExportBuilder.astrocartography(result), mode: "astrocartography")
    }

    @Test func mundaneElectionalMarkdownShape() throws {
        let result = try JSONDecoder().decode(MundaneElectionalResult.self, from: fixtureData("mundane-electional-result"))
        assertMarkdownShape(MarkdownExportBuilder.mundaneElectional(result), mode: "mundaneElectional")
    }

    @Test func declinationTimingMarkdownShape() throws {
        let result = try JSONDecoder().decode(DeclinationTimingResult.self, from: fixtureData("declination-timing-result"))
        assertMarkdownShape(MarkdownExportBuilder.declinationTiming(result), mode: "declinationTiming")
    }

    // MARK: - 现代子模式

    @Test func synastryMarkdownShape() throws {
        let result = try JSONDecoder().decode(SynastryResult.self, from: fixtureData("synastry-result"))
        assertMarkdownShape(MarkdownModernExportBuilder.synastry(result), mode: "synastry")
    }

    @Test func solarArcMarkdownShape() throws {
        let result = try JSONDecoder().decode(SolarArcResult.self, from: fixtureData("solar-arc-result"))
        assertMarkdownShape(MarkdownModernExportBuilder.solarArc(result), mode: "solarArc")
    }

    @Test func harmonicMarkdownShape() throws {
        let result = try JSONDecoder().decode(HarmonicResult.self, from: fixtureData("harmonic-result"))
        assertMarkdownShape(MarkdownModernExportBuilder.harmonic(result), mode: "harmonic")
    }

    @Test func modernCyclesMarkdownShape() throws {
        let result = try JSONDecoder().decode(ModernCyclesResult.self, from: fixtureData("modern-cycles-result"))
        assertMarkdownShape(MarkdownExportBuilder.modernCycles(result), mode: "modernCycles")
    }

    @Test func modernReturnMarkdownShape() throws {
        let result = try JSONDecoder().decode(ModernReturnResult.self, from: fixtureData("modern-solar-return-result"))
        assertMarkdownShape(MarkdownModernExportBuilder.modernReturn(result), mode: "modernReturn")
    }

    @Test func modernLunarReturnMarkdownShape() throws {
        let result = try JSONDecoder().decode(ModernReturnResult.self, from: fixtureData("modern-lunar-return-result"))
        assertMarkdownShape(MarkdownModernExportBuilder.modernReturn(result), mode: "modernLunarReturn")
    }

    @Test func modernMercuryReturnMarkdownShape() throws {
        let result = try JSONDecoder().decode(ModernReturnResult.self, from: fixtureData("modern-mercury-return-result"))
        assertMarkdownShape(MarkdownModernExportBuilder.modernReturn(result), mode: "modernMercuryReturn")
    }

    @Test func modernTimingMidpointMarkdownShape() throws {
        let result = try JSONDecoder().decode(ModernTimingResult.self, from: fixtureData("modern-timing-midpoint-result"))
        assertMarkdownShape(MarkdownExportBuilder.modernTiming(result), mode: "modernTimingMidpoint")
    }

    @Test func modernTimingCompositeMarkdownShape() throws {
        let result = try JSONDecoder().decode(ModernTimingResult.self, from: fixtureData("modern-timing-composite-result"))
        assertMarkdownShape(MarkdownExportBuilder.modernTiming(result), mode: "modernTimingComposite")
    }

    @Test func modernTimingDavisonMarkdownShape() throws {
        let result = try JSONDecoder().decode(ModernTimingResult.self, from: fixtureData("modern-timing-davison-result"))
        assertMarkdownShape(MarkdownExportBuilder.modernTiming(result), mode: "modernTimingDavison")
    }

    @Test func localSpaceMarkdownShape() throws {
        let result = try JSONDecoder().decode(LocalSpaceResult.self, from: fixtureData("local-space-result"))
        assertMarkdownShape(MarkdownExportBuilder.localSpace(result), mode: "localSpace")
    }

    // MARK: - 古典进阶

    @Test func classicalDerivativesMarkdownShape() throws {
        let result = try JSONDecoder().decode(ClassicalDerivativesResult.self, from: fixtureData("classical-derivatives-result"))
        assertMarkdownShape(MarkdownExportBuilder.classicalDerivatives(result), mode: "classicalDerivatives")
    }

    @Test func classicalVisibilityMarkdownShape() throws {
        let result = try JSONDecoder().decode(ClassicalVisibilityResult.self, from: fixtureData("classical-visibility-result"))
        assertMarkdownShape(MarkdownExportBuilder.classicalVisibility(result), mode: "classicalVisibility")
    }

    @Test func timeLordsExtendedMarkdownShape() throws {
        let result = try JSONDecoder().decode(TimeLordsExtendedResult.self, from: fixtureData("time-lords-extended-result"))
        assertMarkdownShape(MarkdownExportBuilder.timeLordsExtended(result), mode: "timeLordsExtended")
    }

    @Test func primaryDirectionsAuditMarkdownShape() throws {
        let result = try JSONDecoder().decode(PrimaryDirectionsAuditResult.self, from: fixtureData("primary-directions-audit-result"))
        assertMarkdownShape(MarkdownExportBuilder.primaryDirectionsAudit(result), mode: "primaryDirectionsAudit")
    }

    @Test func methodFamiliesMarkdownShape() throws {
        let result = try JSONDecoder().decode(MethodFamiliesResult.self, from: fixtureData("method-families-result"))
        assertMarkdownShape(MarkdownExportBuilder.methodFamilies(result), mode: "methodFamilies")
    }

    @Test func distributionsPdMarkdownShape() throws {
        let result = try JSONDecoder().decode(DistributionsPdResult.self, from: fixtureData("distributions-pd-result"))
        assertMarkdownShape(MarkdownExportBuilder.distributionsPd(result), mode: "distributionsPd")
    }

    @Test func hellenisticConditionAuditMarkdownShape() throws {
        let result = try JSONDecoder().decode(HellenisticConditionAuditResult.self, from: fixtureData("hellenistic-condition-audit-result"))
        assertMarkdownShape(MarkdownExportBuilder.hellenisticConditionAudit(result), mode: "hellenisticConditionAudit")
    }

    @Test func orbitalDialMarkdownShape() throws {
        let result = try JSONDecoder().decode(OrbitalDialResult.self, from: fixtureData("orbital-dial-result"))
        assertMarkdownShape(MarkdownExportBuilder.orbitalDial(result), mode: "orbitalDial")
    }

    @Test func planetarySynodicMarkdownShape() throws {
        let result = try JSONDecoder().decode(PlanetarySynodicResult.self, from: fixtureData("planetary-synodic-result"))
        assertMarkdownShape(MarkdownExportBuilder.planetarySynodic(result), mode: "planetarySynodic")
    }

    // MARK: - 反向:JSON 导出不得伪装成 markdown

    @Test func jsonExportIsNotMarkdown() throws {
        let horary = try JSONDecoder().decode(HoraryDataPacket.self, from: fixtureData("horary-result"))
        let json = TextExportBuilder.json(horary)
        #expect(!json.hasPrefix("#"), "JSON 导出不应以 markdown 标题开头")
        #expect(json.contains("{"))
        #expect(json.contains("\"schema\""))

        let vedic = try JSONDecoder().decode(VedicResult.self, from: fixtureData("vedic-result"))
        let vedicJSON = TextExportBuilder.json(vedic)
        #expect(!vedicJSON.hasPrefix("#"))
    }
}
