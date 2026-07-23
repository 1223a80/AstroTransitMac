import Foundation
import Testing
@testable import TransitStudio

/// PR1 acceptance: classical expansion catalog, selection identity, clamp, gate routing, icons.
struct ClassicalWorkspaceTests {

    // MARK: - Catalog / IA

    @Test func classicalExpansionCatalogIsFrozenEight() {
        let expected: [ModernSubMode] = [
            .classicalVisibility,
            .hellenisticConditionAudit,
            .classicalDerivatives,
            .timeLordsExtended,
            .primaryDirectionsAudit,
            .distributionsPd,
            .prenatalParans,
            .mundaneElectional,
        ]
        #expect(ClassicalExpansionCatalog.modes == expected)
        #expect(ClassicalExpansionCatalog.modes.count == 8)
        for mode in expected {
            #expect(ClassicalExpansionCatalog.contains(mode))
        }
        // Modern-only modes must not be in classical expansion.
        for mode: ModernSubMode in [
            .natal, .declinationTiming, .retrogradeCycles, .planetarySynodic,
            .draconicHeliocentric, .methodFamilies, .orbitalDial, .modernCycles,
        ] {
            #expect(!ClassicalExpansionCatalog.contains(mode))
        }
    }

    @Test func modernRailExcludesClassicalEight() {
        let rail = ClassicalExpansionCatalog.modernRailSubModes
        for mode in ClassicalExpansionCatalog.modes {
            #expect(!rail.contains(mode), "modern rail must not list \(mode.rawValue)")
        }
        #expect(rail.contains(.natal))
        #expect(rail.contains(.orbitalDial))
        #expect(rail.contains(.declinationTiming))
        #expect(rail.count == ModernSubMode.allCases.count - 8)
    }

    @Test func classicalExpansionChineseTitlesMatchModernSubMode() {
        #expect(ModernSubMode.classicalVisibility.title == "可见相位/行星时")
        #expect(ModernSubMode.hellenisticConditionAudit.title == "希腊状态审计")
        #expect(ModernSubMode.classicalDerivatives.title == "派生盘/尊贵")
        #expect(ModernSubMode.timeLordsExtended.title == "时间主扩展")
        #expect(ModernSubMode.primaryDirectionsAudit.title == "主限审计")
        #expect(ModernSubMode.distributionsPd.title == "沿界/主限扩展")
        #expect(ModernSubMode.prenatalParans.title == "产前朔望/Parans")
        #expect(ModernSubMode.mundaneElectional.title == "世俗/择时事实")
    }

    // MARK: - Icons (D5 / §1.3)

    @Test func classicalEightIconsAreUniqueAndNotSharedStar() {
        let icons = ClassicalExpansionCatalog.modes.map(\.icon)
        #expect(Set(icons).count == icons.count, "eight expansion icons must be unique")
        for icon in icons {
            #expect(icon != "star", "expansion modes must not share star icon")
        }
        #expect(ModernSubMode.classicalVisibility.icon == "eye")
        #expect(ModernSubMode.hellenisticConditionAudit.icon == "list.bullet.rectangle")
        #expect(ModernSubMode.classicalDerivatives.icon == "square.split.2x1")
        #expect(ModernSubMode.timeLordsExtended.icon == "hourglass")
        #expect(ModernSubMode.primaryDirectionsAudit.icon == "arrow.up.right.circle")
        #expect(ModernSubMode.distributionsPd.icon == "rectangle.split.3x1")
        #expect(ModernSubMode.prenatalParans.icon == "sparkles")
        #expect(ModernSubMode.mundaneElectional.icon == "building.columns")
    }

    @Test func orbitalDialIconIsNotMidpointIcon() {
        #expect(ModernSubMode.orbitalDial.icon == "circle.dotted")
        #expect(ModernSubMode.midpoint.icon == "circle.grid.cross")
        #expect(ModernSubMode.orbitalDial.icon != ModernSubMode.midpoint.icon)
    }

    // MARK: - Selection identity

    @Test func selectNatalChartForcesNatalWorkspaceIgnoringResidualSubMode() {
        // Residual modernSubMode is not part of the selection return — gates use workspace only.
        let selection = ClassicalWorkspaceSelection.selectNatalChart()
        #expect(selection.workspace == .natalChart)
        #expect(selection.mode == .settings)
        #expect(selection.showSettingsPage == false)
        // Gate route must be natal even if workspace was previously expansion.
        #expect(ClassicalSettingsGate.route(workspace: selection.workspace) == .natalChart)
    }

    @Test func selectExpansionDualWritesWorkspaceAndSubMode() {
        let selection = ClassicalWorkspaceSelection.selectExpansion(.hellenisticConditionAudit)
        #expect(selection != nil)
        #expect(selection?.workspace == .expansion(.hellenisticConditionAudit))
        #expect(selection?.modernSubMode == .hellenisticConditionAudit)
        #expect(selection?.mode == .settings)
        #expect(selection?.showSettingsPage == false)
        #expect(
            ClassicalSettingsGate.route(workspace: selection!.workspace)
                == .expansion(.hellenisticConditionAudit)
        )
    }

    @Test func selectExpansionRejectsNonClassicalModes() {
        #expect(ClassicalWorkspaceSelection.selectExpansion(.natal) == nil)
        #expect(ClassicalWorkspaceSelection.selectExpansion(.orbitalDial) == nil)
        #expect(ClassicalWorkspaceSelection.selectExpansion(.declinationTiming) == nil)
    }

    @Test func natalSelectionAfterExpansionDoesNotDependOnResidualSubMode() {
        // Simulate: user picked expansion (subMode left as hellenistic), then natal.
        let residualModernSubMode = ModernSubMode.hellenisticConditionAudit
        var workspace = ClassicalSettingsWorkspace.expansion(.hellenisticConditionAudit)
        let natal = ClassicalWorkspaceSelection.selectNatalChart()
        workspace = natal.workspace
        // Residual modernSubMode may still be hellenistic — gates must ignore it.
        #expect(residualModernSubMode == .hellenisticConditionAudit)
        #expect(ClassicalSettingsGate.route(workspace: workspace) == .natalChart)
        #expect(ModernSubModeChrome.classicalSettingsRunTitle(workspace: workspace) == "古典排盘")
        #expect(ModernSubModeChrome.classicalSettingsAIAvailable(workspace: workspace))
        // Expansion run title must not equal 古典排盘.
        let expansionTitle = ModernSubModeChrome.classicalSettingsRunTitle(
            workspace: .expansion(.hellenisticConditionAudit)
        )
        #expect(expansionTitle == "计算希腊状态审计")
        #expect(expansionTitle != "古典排盘")
        #expect(!ModernSubModeChrome.classicalSettingsAIAvailable(
            workspace: .expansion(.hellenisticConditionAudit)
        ))
    }

    // MARK: - Clamp / practice transition

    @Test func clampClassicalEightToNatal() {
        for mode in ClassicalExpansionCatalog.modes {
            #expect(ClassicalExpansionCatalog.clampForNonClassicalPractice(mode) == .natal)
        }
        #expect(ClassicalExpansionCatalog.clampForNonClassicalPractice(.natal) == .natal)
        #expect(ClassicalExpansionCatalog.clampForNonClassicalPractice(.orbitalDial) == .orbitalDial)
        #expect(ClassicalExpansionCatalog.clampForNonClassicalPractice(.synastry) == .synastry)
    }

    @Test func switchToModernClampsClassicalEight() {
        let result = PracticeModeTransition.apply(
            from: .classical,
            to: .modern,
            modernSubMode: .primaryDirectionsAudit,
            calculationMode: .settings,
            workspace: .expansion(.primaryDirectionsAudit)
        )
        #expect(result.modernSubMode == .natal)
        // No orphan expansion title after clamp.
        #expect(!ClassicalExpansionCatalog.contains(result.modernSubMode))
        #expect(ModernSubModeChrome.runButtonTitle(result.modernSubMode) == "现代排盘")
    }

    @Test func switchToClassicalDefaultsWorkspaceToNatalChart() {
        let result = PracticeModeTransition.apply(
            from: .modern,
            to: .classical,
            modernSubMode: .synastry,
            calculationMode: .settings,
            workspace: .expansion(.classicalVisibility)
        )
        #expect(result.classicalSettingsWorkspace == .natalChart)
        #expect(ClassicalSettingsGate.route(workspace: result.classicalSettingsWorkspace) == .natalChart)
    }

    @Test func switchClassicalHoraryToModernLandsOnSettingsNatal() {
        let result = PracticeModeTransition.apply(
            from: .classical,
            to: .modern,
            modernSubMode: .hellenisticConditionAudit,
            calculationMode: .horary,
            workspace: .natalChart
        )
        #expect(result.calculationMode == .settings)
        #expect(result.modernSubMode == .natal)
    }

    @Test func switchToVedicClampsClassicalEight() {
        let result = PracticeModeTransition.apply(
            from: .classical,
            to: .vedic,
            modernSubMode: .mundaneElectional,
            calculationMode: .settings,
            workspace: .expansion(.mundaneElectional)
        )
        #expect(result.modernSubMode == .natal)
    }

    // MARK: - Gate route defense

    @Test func expansionGateRouteRejectsNonCatalogModes() {
        // If somehow workspace holds a non-catalog mode, fall back to natal.
        let bogus = ClassicalSettingsWorkspace.expansion(.natal)
        #expect(ClassicalSettingsGate.route(workspace: bogus) == .natalChart)
    }
}
