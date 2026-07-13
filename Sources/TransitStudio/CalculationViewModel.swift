import SwiftUI

@MainActor
final class CalculationViewModel: ObservableObject {
    // MARK: - Run State
    @Published var isRunning = false
    @Published var calculationProgress: Double?
    @Published var calculationProgressText = ""
    @Published var asteroidPreparationMessage = ""
    var progressTask: Task<Void, Never>?
    var currentRunTask: Task<Void, Never>?
    /// Whether the *active tracked task* may be cancelled via the top-bar stop
    /// button. Captured at task start so switching pages mid-run does not
    /// enable/disable stop incorrectly (e.g. scan → rectify, or rectify → scan).
    private(set) var currentRunIsStoppable = false
    /// Bumped when a run starts or is force-stopped so only the active run
    /// may clear `currentRunTask` / `isRunning` or write terminal errors.
    private(set) var runGeneration = 0
    @Published var errorMessage: String?
    @Published var warningMessage: String?

    @discardableResult
    func beginRun(isStoppable: Bool = false) -> Int {
        runGeneration += 1
        currentRunIsStoppable = isStoppable
        return runGeneration
    }

    func isCurrentRun(_ generation: Int) -> Bool {
        generation == runGeneration
    }

    func clearRunTaskIfCurrent(_ generation: Int) {
        guard isCurrentRun(generation) else { return }
        currentRunTask = nil
        currentRunIsStoppable = false
    }

    @discardableResult
    func commitModernTimingResult(_ result: ModernTimingResult, generation: Int) -> Bool {
        guard isCurrentRun(generation) else { return false }
        modernTimingResult = result
        modernTimingSelectedTab = "timeline"
        return true
    }

    /// Cancel-path invalidation: drop task ownership and stoppability without
    /// waiting for the cancelled task's defer cleanup.
    func invalidateActiveRun() {
        runGeneration += 1
        currentRunTask = nil
        currentRunIsStoppable = false
    }

    // MARK: - Results
    @Published var modernNatalResult: TransitResult?
    @Published var momentResult: TransitResult?
    @Published var fullNatalResult: TransitResult?
    @Published var scanResult: ScanResult?
    @Published var modernTimingResult: ModernTimingResult?
    @Published var classicalResult: ClassicalResult?
    @Published var horaryResult: HoraryResult?
    @Published var rectifyResponse: RectifyResponse?
    @Published var rectifyLevel2Response: RectifyResponse?
    @Published var rectifyLevel3Response: RectifyResponse?
    @Published var vedicResult: VedicResult?
    @Published var modernResultData: ModernResultData?

    // MARK: - Rectify State
    @Published var rectifyS1Index = 0
    @Published var rectifyS2Index = 0
    @Published var rectifyActiveLevel = 1
    @Published var rectifyLevel2Gen = 0
    @Published var rectifyLevel3Gen = 0
    @Published var rectifyLevel3ResponseID = 0
    var rectifyLevel2Task: Task<Void, Never>?
    var rectifyLevel3Task: Task<Void, Never>?

    func invalidateRectifyResults() {
        rectifyLevel2Task?.cancel()
        rectifyLevel3Task?.cancel()
        rectifyLevel2Task = nil
        rectifyLevel3Task = nil
        rectifyLevel2Gen += 1
        rectifyLevel3Gen += 1
        rectifyResponse = nil
        rectifyLevel2Response = nil
        rectifyLevel3Response = nil
        rectifyActiveLevel = 1
        rectifyS1Index = 0
        rectifyS2Index = 0
    }

    // MARK: - Tab Selection
    @Published var classicalSelectedTab = "planets"
    @Published var horarySelectedTab = "overview"
    @Published var modernNatalSelectedTab = "natal_positions"
    @Published var momentSelectedTab = "aspects"
    @Published var scanSelectedTab = "timeline"
    @Published var modernTimingSelectedTab = "timeline"
    @Published var vedicSelectedTab = "overview"
    @Published var modernSelectedTab = ModernSubMode.synastry.defaultResultTab

    func resetModernSelectedTab(for subMode: ModernSubMode) {
        modernSelectedTab = subMode.defaultResultTab
    }
}
