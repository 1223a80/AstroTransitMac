import SwiftUI

@MainActor
class HoraryViewModel: ObservableObject {
    @Published var date = Date()
    @Published var placeName = "当前提问地点"
    @Published var latitude = "31.2304"
    @Published var longitude = "121.4737"
    @Published var questionText = ""
    @Published var result: HoraryResult?
    @Published var aiAnalysis = ""
    @Published var selectedTab = "overview"
}
