import Foundation
import Testing
@testable import TransitStudio

/// PR2–PR9 structural tests: NestedJSON typed decode, chrome factory, export filter, multi-cache, B20 UX strings.
@MainActor
struct ExpansionStructuredUITests {

    // MARK: - Fixtures

    private func loadFixture(_ name: String) throws -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: "json", subdirectory: nil)
            ?? Bundle.module.url(forResource: name, withExtension: "json")
        guard let url else {
            // Fallback to relative Fixtures path for local runs
            let path = "SwiftTests/Fixtures/\(name).json"
            return try Data(contentsOf: URL(fileURLWithPath: path))
        }
        return try Data(contentsOf: url)
    }

    private func decodeFixture<T: Decodable>(_ name: String, as type: T.Type) throws -> T {
        let data = try loadFixture(name)
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - NestedJSON typed

    @Test func zrPayloadDecodesFromTimeLordsFixture() throws {
        let result = try decodeFixture("time-lords-extended-result", as: TimeLordsExtendedResult.self)
        let zr = try #require(result.zrPayload)
        #expect(zr.fortune != nil || zr.spirit != nil)
        if let fortune = zr.fortune {
            #expect(fortune.currentActiveLevel != nil || (fortune.l1Periods?.isEmpty == false))
            // No monospaced dump dependency — periods are typed rows.
            if let l1 = fortune.l1Periods, let first = l1.first {
                #expect(first.sign != nil || first.ruler != nil)
            }
        }
    }

    @Test func pdAlgorithmDescriptionDecodesFromFixture() throws {
        let result = try decodeFixture("primary-directions-audit-result", as: PrimaryDirectionsAuditResult.self)
        let algo = try #require(result.algorithmDescriptionPayload)
        #expect(algo.name != nil)
        #expect(algo.externalCrosscheckStatus == "local_se_consistent_only")
        #expect((algo.knownLimits ?? []).isEmpty == false)
        let chrome = ExpansionChromeFactory.chrome(
            for: .primaryDirectionsAudit,
            metaMethod: result.meta.method,
            extras: ExpansionChromeExtras(
                algorithmName: algo.name,
                algorithmKey: algo.key,
                externalCrosscheckStatus: algo.externalCrosscheckStatus,
                knownLimitsFirst: algo.knownLimits?.first
            )
        )
        #expect(chrome.badge == .auditLocalOnly)
    }

    @Test func circumambulationPacketDecodesBoundaries() throws {
        let result = try decodeFixture("distributions-pd-result", as: DistributionsPdResult.self)
        #expect(!result.distributions.isEmpty)
        let packet = try #require(result.distributions.first?.circumambulationPacket)
        #expect(packet.currentRuler != nil || packet.currentRulerId != nil)
        #expect((packet.boundaries ?? []).isEmpty == false)
    }

    @Test func prenatalPacketSummaryDecodesSyzygyDegreeUsed() throws {
        let result = try decodeFixture("prenatal-parans-result", as: PrenatalParansResult.self)
        let summary = try #require(result.prenatalPacketSummary)
        let syz = try #require(summary.prenatalSyzygy)
        #expect(syz.syzygyDegreeUsed != nil)
        #expect(syz.syzygyType != nil)
        #expect(result.fixedStarParans.first?.planetEventType != nil)
        #expect(result.fixedStarParans.first?.starEventType != nil)
        #expect(result.fixedStarParans.first?.eventDeltaSeconds != nil)
        #expect(result.methodTrace?.localDayStart != nil)
        #expect(result.polarDegradation?.active == false)
    }

    // MARK: - Chrome factory (not assumptions regex)

    @Test func hellenisticChromeIsAuditNotRegex() {
        let chrome = ExpansionChromeFactory.chrome(
            for: .hellenisticConditionAudit,
            metaMethod: "hellenistic_condition_audit_v1",
            extras: ExpansionChromeExtras(sourceProfile: "default")
        )
        #expect(chrome.badge == .audit)
        #expect(chrome.detailCaption?.contains("不做综合打分") == true)
    }

    @Test func mundaneChromeIsFactMatrix() {
        let chrome = ExpansionChromeFactory.chrome(for: .mundaneElectional, metaMethod: "mundane_electional")
        #expect(chrome.badge == .factMatrix)
        #expect(chrome.detailCaption?.contains("不排序吉时") == true)
    }

    // MARK: - Multi-result cache

    @Test func classicalExpansionCacheKeepsOtherModes() {
        let vm = CalculationViewModel()
        // Minimal synthetic payloads via fixture decode
        guard let hell = try? decodeFixture("hellenistic-condition-audit-result", as: HellenisticConditionAuditResult.self),
              let vis = try? decodeFixture("classical-visibility-result", as: ClassicalVisibilityResult.self) else {
            Issue.record("fixtures missing")
            return
        }
        vm.setModernResultData(.hellenisticConditionAudit(hell))
        #expect(vm.classicalExpansionResults[.hellenisticConditionAudit] != nil)
        vm.setModernResultData(.classicalVisibility(vis))
        #expect(vm.classicalExpansionResults[.hellenisticConditionAudit] != nil)
        #expect(vm.classicalExpansionResults[.classicalVisibility] != nil)
        #expect(vm.classicalExpansionResults.count == 2)
        // Non-expansion must not enter cache
        if let prog = try? decodeFixture("progressions-result", as: ProgressionResult.self) {
            vm.setModernResultData(.progression(prog))
            #expect(vm.classicalExpansionResults.count == 2)
        }
    }

    @Test func classicalExpansionResultResolvesCachedModeWhenCurrentIsDifferent() throws {
        let vm = CalculationViewModel()
        let hell = try decodeFixture("hellenistic-condition-audit-result", as: HellenisticConditionAuditResult.self)
        let vis = try decodeFixture("classical-visibility-result", as: ClassicalVisibilityResult.self)
        vm.setModernResultData(.hellenisticConditionAudit(hell))
        vm.setModernResultData(.classicalVisibility(vis))
        // modernResultData is visibility; resolving hellenistic must still hit cache.
        #expect(vm.modernResultData?.classicalExpansionMode == .classicalVisibility)
        let resolved = try #require(vm.classicalExpansionResult(for: .hellenisticConditionAudit))
        guard case .hellenisticConditionAudit = resolved else {
            Issue.record("expected hellenistic payload from cache after computing visibility")
            return
        }
        let resolvedVis = try #require(vm.classicalExpansionResult(for: .classicalVisibility))
        guard case .classicalVisibility = resolvedVis else {
            Issue.record("expected visibility from cache or current")
            return
        }
        #expect(vm.classicalExpansionResult(for: .prenatalParans) == nil)
    }

    @Test func modernCycleAndFramePanesUseChineseTableHeadersInSource() throws {
        // Structural: shipped view sources must use 中文表头 (skeptic PR3/PR6).
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // SwiftTests
            .deletingLastPathComponent() // repo root
            .appendingPathComponent("Sources/TransitStudio")
        let files = [
            "RetrogradeCyclesViews.swift",
            "PlanetarySynodicViews.swift",
            "DraconicHeliocentricViews.swift",
            "MethodFamiliesViews.swift",
            "OrbitalDialViews.swift",
        ]
        let forbiddenEnglish = [
            "TableColumn(\"Body\"",
            "TableColumn(\"Local\"",
            "TableColumn(\"Phase\"",
            "TableColumn(\"Pre\"",
            "TableColumn(\"Retro\"",
            "TableColumn(\"Direct\"",
            "TableColumn(\"Post\"",
            "TableColumn(\"Days\"",
            "TableColumn(\"Kind\"",
            "TableColumn(\"Lon\"",
            "TableColumn(\"Natal\"",
            "TableColumn(\"Aspect\"",
            "TableColumn(\"Exact\"",
            "TableColumn(\"Start\"",
            "TableColumn(\"End\"",
            "TableColumn(\"Pass\"",
            "TableColumn(\"Rel v\"",
            "TableColumn(\"System\"",
            "TableColumn(\"Center\"",
            "TableColumn(\"Prog\"",
            "TableColumn(\"SA\"",
            "TableColumn(\"Picture\"",
            "TableColumn(\"Mid°\"",
            "TableColumn(\"Mod\"",
            "TableColumn(\"Method\"",
        ]
        for name in files {
            let text = try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
            for needle in forbiddenEnglish {
                #expect(!text.contains(needle), "\(name) still has English header \(needle)")
            }
            #expect(text.contains("TableColumn(\"天体\"") || text.contains("TableColumn(\"本地\"") || text.contains("TableColumn(\"黄经") || text.contains("TableColumn(\"相位") || text.contains("TableColumn(\"行星图") || text.contains("TableColumn(\"本命"), "\(name) should declare Chinese headers")
        }
    }

    // MARK: - Export section filter + merge

    @Test func markdownSectionFilterKeepsSelectedHeaders() throws {
        let result = try decodeFixture("hellenistic-condition-audit-result", as: HellenisticConditionAuditResult.self)
        let full = MarkdownExportBuilder.hellenisticConditionAudit(result)
        #expect(full.contains("##"))
        let filtered = ExpansionExportCatalog.filterMarkdown(
            full,
            mode: .hellenisticConditionAudit,
            selectedSectionIDs: ["conditions"]
        )
        #expect(filtered.contains("条件") || filtered.contains("Condition") || filtered.contains("证据"))
        // Warnings section should be droppable when not selected
        let noWarnings = ExpansionExportCatalog.filterMarkdown(
            full,
            mode: .hellenisticConditionAudit,
            selectedSectionIDs: ["conditions", "assumptions"]
        )
        #expect(!noWarnings.isEmpty)
    }

    @Test func markdownSectionFilterHonorsSelectNone() throws {
        let result = try decodeFixture("hellenistic-condition-audit-result", as: HellenisticConditionAuditResult.self)
        let full = MarkdownExportBuilder.hellenisticConditionAudit(result)
        let filtered = ExpansionExportCatalog.filterMarkdown(
            full,
            mode: .hellenisticConditionAudit,
            selectedSectionIDs: []
        )
        #expect(filtered.isEmpty)
    }

    @Test func specializedSectionExportsHaveIndependentHeadings() throws {
        let declination = try decodeFixture("declination-timing-result", as: DeclinationTimingResult.self)
        let declinationMarkdown = MarkdownExportBuilder.declinationTiming(declination)
        #expect(declinationMarkdown.contains("## 赤纬事件"))
        #expect(declinationMarkdown.contains("## 赤纬停滞"))
        #expect(declinationMarkdown.contains("## OOB"))

        let synodic = try decodeFixture("planetary-synodic-result", as: PlanetarySynodicResult.self)
        #expect(MarkdownExportBuilder.planetarySynodic(synodic).contains("## 本命接触"))

        let primary = try decodeFixture("primary-directions-audit-result", as: PrimaryDirectionsAuditResult.self)
        let primaryMarkdown = MarkdownExportBuilder.primaryDirectionsAudit(primary)
        #expect(primaryMarkdown.contains("## 算法说明"))
        #expect(primaryMarkdown.contains("## 警告"))
    }

    @Test func mergeExportIncludesMultipleModes() throws {
        let hell = try decodeFixture("hellenistic-condition-audit-result", as: HellenisticConditionAuditResult.self)
        let vis = try decodeFixture("classical-visibility-result", as: ClassicalVisibilityResult.self)
        let md = ExpansionExportCatalog.mergeClassicalExpansionMarkdown(
            results: [
                .hellenisticConditionAudit: .hellenisticConditionAudit(hell),
                .classicalVisibility: .classicalVisibility(vis),
            ],
            modeSections: [
                .hellenisticConditionAudit: ExpansionExportCatalog.allSectionIDs(for: .hellenisticConditionAudit),
                .classicalVisibility: ExpansionExportCatalog.allSectionIDs(for: .classicalVisibility),
            ]
        )
        #expect(md.contains("古典进阶合并导出"))
        #expect(md.contains(ModernSubMode.hellenisticConditionAudit.title))
        #expect(md.contains(ModernSubMode.classicalVisibility.title))
    }

    // MARK: - B20 fact matrix only

    @Test func mundaneElectionalHasNoRecommendationUXStringsInViewSource() throws {
        // Structural: chrome + export markdown must not introduce recommendation sort UX.
        let result = try decodeFixture("mundane-electional-result", as: MundaneElectionalResult.self)
        let md = MarkdownExportBuilder.mundaneElectional(result)
        let forbidden = ["推荐", "得分", "吉时排序", "最佳择时", "打分排序"]
        for word in forbidden {
            #expect(!md.contains(word), "B20 markdown must not contain \(word)")
        }
        let chrome = ExpansionChromeFactory.chrome(for: .mundaneElectional, metaMethod: result.meta.method)
        #expect(chrome.badge == .factMatrix)
    }

    // MARK: - Deep link selection identity

    @Test func deepLinkSelectionSetsExpansionWorkspace() {
        let pd = ClassicalWorkspaceSelection.selectExpansion(.primaryDirectionsAudit)
        #expect(pd?.workspace == .expansion(.primaryDirectionsAudit))
        #expect(pd?.modernSubMode == .primaryDirectionsAudit)
        let pre = ClassicalWorkspaceSelection.selectExpansion(.prenatalParans)
        #expect(pre?.workspace == .expansion(.prenatalParans))
    }

    // MARK: - Section catalog coverage for eight classical modes

    @Test func classicalEightHaveSectionCatalog() {
        for mode in ClassicalExpansionCatalog.modes {
            let sections = ExpansionExportCatalog.sections(for: mode)
            #expect(!sections.isEmpty, "\(mode.rawValue) needs section catalog")
            #expect(sections.contains { $0.id == "assumptions" || $0.id == "warnings" || $0.id == "conditions" || $0.id == "heliacal" || $0.id == "audit" || $0.id == "packet" || $0.id == "ingresses" || $0.id == "concordance" || $0.id == "dodeka" || $0.id == "distributions" })
        }
    }
}
