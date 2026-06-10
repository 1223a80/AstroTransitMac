import SwiftUI

@MainActor
final class CalculationViewModel: ObservableObject {
    // MARK: - Run State
    @Published var isRunning = false
    @Published var calculationProgress: Double?
    @Published var calculationProgressText = ""
    @Published var asteroidPreparationMessage = ""
    var progressTask: Task<Void, Never>?
    @Published var errorMessage: String?

    // MARK: - Results
    @Published var momentResult: TransitResult?
    @Published var fullNatalResult: TransitResult?
    @Published var scanResult: ScanResult?
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

    // MARK: - Tab Selection
    @Published var classicalSelectedTab = "planets"
    @Published var horarySelectedTab = "overview"
    @Published var modernNatalSelectedTab = "natal_positions"
    @Published var momentSelectedTab = "aspects"
    @Published var scanSelectedTab = "hits"
    @Published var vedicSelectedTab = "overview"
    @Published var modernSelectedTab = "planets"
}
