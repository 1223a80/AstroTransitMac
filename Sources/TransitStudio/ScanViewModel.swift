import SwiftUI

@MainActor
class ScanViewModel: ObservableObject {
    @Published var startDate = ContentView.fixedDate(year: 2026, month: 5, day: 1, hour: 0, minute: 0)
    @Published var endDate = ContentView.fixedDate(year: 2026, month: 6, day: 30, hour: 23, minute: 59)
    @Published var windowLabel = "May-Jun 2026"
    @Published var selectedKind = "aspect"
    @Published var moonFilter = "exclude"
    @Published var targetsText = ContentView.defaultScanTargets
    @Published var result: ScanResult?
    @Published var aiAnalysis = ""
    @Published var selectedTab = "hits"
    @Published var configText = ""
    @Published var presetName = ""
    @Published var selectedPresetID = ""
}
