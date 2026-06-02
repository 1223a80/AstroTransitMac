import SwiftUI

@MainActor
class MomentViewModel: ObservableObject {
    @Published var transitDate = Date()
    @Published var selectedTargetAngles = Set<String>()
    @Published var selectedTargetPlanets = Set<String>()
    @Published var selectedTargetAsteroids = Set<String>()
    @Published var selectedTargetHouses = Set<Int>()
    @Published var selectedTargetLots = Set<String>()
    @Published var customLotTargetsText = ""
    @Published var result: TransitResult?
    @Published var aiAnalysis = ""
    @Published var configText = ""
    @Published var presetName = ""
    @Published var selectedPresetID = ""
    @Published var selectedTab = "aspects"
}
