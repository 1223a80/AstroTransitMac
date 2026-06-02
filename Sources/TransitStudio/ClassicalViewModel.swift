import SwiftUI

@MainActor
class ClassicalViewModel: ObservableObject {
    @Published var referenceDate = Date()
    @Published var aspectOrb = 3.0
    @Published var result: ClassicalResult?
    @Published var aiAnalysis = ""
    @Published var selectedTab = "planets"
    @Published var showExportSheet = false
    @Published var exportSections: Set<MarkdownExportBuilder.ExportSection> = Set(MarkdownExportBuilder.ExportSection.allCases)
}
