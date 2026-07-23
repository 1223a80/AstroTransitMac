import Foundation

// MARK: - Classical Settings Workspace (B7–B20 IA · PR1)

/// Classical practice under CalculationMode.settings is either the natal chart
/// workspace or one of the eight frozen classical-expansion sub-modes.
/// Gates (Run / Results / Sidebar / chrome / AI) must branch on this value only —
/// residual `modernSubMode` alone is not authoritative under classical practice.
enum ClassicalSettingsWorkspace: Equatable, Hashable {
    case natalChart
    case expansion(ModernSubMode)

    var isNatalChart: Bool {
        if case .natalChart = self { return true }
        return false
    }

    var expansionMode: ModernSubMode? {
        if case .expansion(let mode) = self { return mode }
        return nil
    }
}

// MARK: - Frozen eight classical-expansion modes + modern rail filter

enum ClassicalExpansionCatalog {
    /// Frozen classical-expansion set (KD4). Must not appear on the modern rail.
    static let modes: [ModernSubMode] = [
        .classicalVisibility,
        .hellenisticConditionAudit,
        .classicalDerivatives,
        .timeLordsExtended,
        .primaryDirectionsAudit,
        .distributionsPd,
        .prenatalParans,
        .mundaneElectional,
    ]

    static let modeSet: Set<ModernSubMode> = Set(modes)

    static func contains(_ mode: ModernSubMode) -> Bool {
        modeSet.contains(mode)
    }

    /// Modern practice rail source: all ModernSubMode cases except classical eight.
    static var modernRailSubModes: [ModernSubMode] {
        ModernSubMode.allCases.filter { !modeSet.contains($0) }
    }

    /// Clamp classical eight keys to natal so modern/vedic UI never shows orphan expansion chrome.
    static func clampForNonClassicalPractice(_ mode: ModernSubMode) -> ModernSubMode {
        modeSet.contains(mode) ? .natal : mode
    }

    /// Validate expansion payload — only the frozen eight are legal.
    static func expansionWorkspace(for mode: ModernSubMode) -> ClassicalSettingsWorkspace? {
        guard modeSet.contains(mode) else { return nil }
        return .expansion(mode)
    }
}

// MARK: - Selection identity helpers (pure, unit-testable)

enum ClassicalWorkspaceSelection {
    /// Pointing at 「本命设置」 forces natalChart regardless of residual modernSubMode.
    static func selectNatalChart() -> (
        workspace: ClassicalSettingsWorkspace,
        mode: CalculationMode,
        showSettingsPage: Bool
    ) {
        (.natalChart, .settings, false)
    }

    /// Pointing at a classical-expansion leaf dual-writes workspace + modernSubMode.
    static func selectExpansion(_ mode: ModernSubMode) -> (
        workspace: ClassicalSettingsWorkspace,
        modernSubMode: ModernSubMode,
        mode: CalculationMode,
        showSettingsPage: Bool
    )? {
        guard ClassicalExpansionCatalog.contains(mode) else { return nil }
        return (.expansion(mode), mode, .settings, false)
    }
}

// MARK: - Practice-mode transition (KD3 / Q1)

struct PracticeModeTransitionResult: Equatable {
    var modernSubMode: ModernSubMode
    var classicalSettingsWorkspace: ClassicalSettingsWorkspace
    /// When non-nil, replace ContentView.mode (e.g. horary/rectify → modern lands on settings).
    var calculationMode: CalculationMode?
}

enum PracticeModeTransition {
    /// Pure rules for top-bar practice switches. Result memory is intentionally not touched.
    static func apply(
        from previous: PracticeMode,
        to next: PracticeMode,
        modernSubMode: ModernSubMode,
        calculationMode: CalculationMode,
        workspace: ClassicalSettingsWorkspace
    ) -> PracticeModeTransitionResult {
        var result = PracticeModeTransitionResult(
            modernSubMode: modernSubMode,
            classicalSettingsWorkspace: workspace,
            calculationMode: nil
        )

        switch next {
        case .modern:
            result.modernSubMode = ClassicalExpansionCatalog.clampForNonClassicalPractice(modernSubMode)
            // Horary / rectify under classical (or any) → modern: land on settings + natal.
            if calculationMode == .horary || calculationMode == .rectify {
                result.calculationMode = .settings
                result.modernSubMode = .natal
            }
        case .classical:
            // Safe default: natal chart workspace (user re-picks expansion leaf).
            result.classicalSettingsWorkspace = .natalChart
        case .vedic:
            result.modernSubMode = ClassicalExpansionCatalog.clampForNonClassicalPractice(modernSubMode)
        }

        // Silence unused previous (kept for future transition-specific rules / call-site clarity).
        _ = previous
        return result
    }
}

// MARK: - Gate routing (what classical+settings should do)

enum ClassicalSettingsGateRoute: Equatable {
    case natalChart
    case expansion(ModernSubMode)
}

enum ClassicalSettingsGate {
    /// Resolve gate route from workspace only (ignores residual modernSubMode for natal).
    static func route(workspace: ClassicalSettingsWorkspace) -> ClassicalSettingsGateRoute {
        switch workspace {
        case .natalChart:
            return .natalChart
        case .expansion(let mode):
            // Defense-in-depth: unknown expansion falls back to natal chart.
            if ClassicalExpansionCatalog.contains(mode) {
                return .expansion(mode)
            }
            return .natalChart
        }
    }
}

// MARK: - Run chrome titles (shared modern + classical expansion)

enum ModernSubModeChrome {
    /// Top-bar run button title for a modern / classical-expansion sub-mode.
    static func runButtonTitle(_ subMode: ModernSubMode) -> String {
        switch subMode {
        case .natal: return "现代排盘"
        case .synastry: return "计算合盘"
        case .composite: return "计算组合盘"
        case .davison: return "计算戴维森盘"
        case .progression: return "计算次限推进"
        case .solarArc: return "计算太阳弧"
        case .harmonic: return "计算调和盘"
        case .returnChart: return "计算返照盘"
        case .midpoint: return "计算中点"
        case .progressedComposite: return "计算推进组合盘"
        case .relocation: return "计算迁移盘"
        case .modernCycles: return "扫描朔望食相"
        case .declinationTiming: return "计算赤纬事件"
        case .retrogradeCycles: return "扫描逆行阴影"
        case .classicalVisibility: return "计算可见相位/行星时"
        case .planetarySynodic: return "扫描会合周期"
        case .hellenisticConditionAudit: return "计算希腊状态审计"
        case .draconicHeliocentric: return "计算 Draconic/日心"
        case .classicalDerivatives: return "计算派生盘/尊贵"
        case .timeLordsExtended: return "计算时间主扩展"
        case .methodFamilies: return "计算推运方法族"
        case .primaryDirectionsAudit: return "计算主限审计"
        case .distributionsPd: return "计算沿界/主限扩展"
        case .prenatalParans: return "计算产前朔望/Parans"
        case .orbitalDial: return "计算轨道点/Dial"
        case .mundaneElectional: return "计算世俗/择时"
        case .astrocartography: return "计算天体地图线"
        case .localSpace: return "计算 Local Space"
        }
    }

    /// Classical settings run title: natal chart vs expansion (workspace-driven).
    static func classicalSettingsRunTitle(workspace: ClassicalSettingsWorkspace) -> String {
        switch ClassicalSettingsGate.route(workspace: workspace) {
        case .natalChart:
            return "古典排盘"
        case .expansion(let mode):
            return runButtonTitle(mode)
        }
    }

    /// Whether classical+settings AI panel is available (only natal chart).
    static func classicalSettingsAIAvailable(workspace: ClassicalSettingsWorkspace) -> Bool {
        if case .natalChart = ClassicalSettingsGate.route(workspace: workspace) {
            return true
        }
        return false
    }
}
