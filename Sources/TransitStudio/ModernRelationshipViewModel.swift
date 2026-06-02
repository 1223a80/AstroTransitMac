import SwiftUI

@MainActor
class ModernRelationshipViewModel: ObservableObject {
    @Published var resultData: ModernResultData?
    @Published var personBDate = ContentView.fixedDate(year: 1992, month: 6, day: 15, hour: 8, minute: 30)
    @Published var personBLatitude = "40.7128"
    @Published var personBLongitude = "-74.0060"
    @Published var nodeMode = "true_node"
    @Published var harmonicOrder = 4
    @Published var aiAnalysis = ""
    @Published var selectedTab = "planets"
    @Published var natalSelectedTab = "natal_positions"
}
