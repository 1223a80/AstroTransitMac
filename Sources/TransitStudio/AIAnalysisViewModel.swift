import SwiftUI

/// Hot streaming text, observed only by `AIAnalysisView`. Kept outside the
/// per-mode @Published storage so token updates don't invalidate the whole
/// ContentView tree.
@MainActor
final class AIStreamBuffer: ObservableObject {
    struct Segment: Identifiable, Equatable {
        let id: Int
        var text: String
    }

    /// Stream key of the analysis currently receiving tokens; nil when idle.
    @Published private(set) var activeKey: String?

    /// Increments when segments change. Segment arrays are kept out of
    /// @Published storage so appending a delta does not copy the whole history.
    @Published private(set) var revision = 0

    private(set) var textSegments: [Segment] = []
    private(set) var reasoningSegments: [Segment] = []
    private(set) var hasText = false
    private(set) var hasReasoning = false

    private var nextSegmentID = 0
    private var currentTextSegmentIndex: Int?
    private var currentReasoningSegmentIndex: Int?

    func begin(key: String) {
        textSegments.removeAll(keepingCapacity: true)
        reasoningSegments.removeAll(keepingCapacity: true)
        hasText = false
        hasReasoning = false
        nextSegmentID = 0
        currentTextSegmentIndex = nil
        currentReasoningSegmentIndex = nil
        activeKey = key
        revision &+= 1
    }

    func append(textDelta: String, reasoningDelta: String) {
        var changed = false
        if !textDelta.isEmpty {
            appendDisplayDelta(textDelta, to: &textSegments, currentIndex: &currentTextSegmentIndex)
            hasText = hasText || !textDelta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            changed = true
        }
        if !reasoningDelta.isEmpty {
            appendDisplayDelta(reasoningDelta, to: &reasoningSegments, currentIndex: &currentReasoningSegmentIndex)
            hasReasoning = hasReasoning || !reasoningDelta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            changed = true
        }
        if changed {
            revision &+= 1
        }
    }

    func finish() {
        activeKey = nil
    }

    func currentText() -> String {
        textSegments.map(\.text).joined(separator: "\n")
    }

    func currentReasoning() -> String {
        reasoningSegments.map(\.text).joined(separator: "\n")
    }

    private func appendDisplayDelta(_ delta: String, to segments: inout [Segment], currentIndex: inout Int?) {
        var start = delta.startIndex
        while start < delta.endIndex {
            if let newline = delta[start...].firstIndex(of: "\n") {
                appendDisplayPiece(String(delta[start..<newline]), to: &segments, currentIndex: &currentIndex)
                startDisplaySegment(in: &segments, currentIndex: &currentIndex)
                start = delta.index(after: newline)
            } else {
                appendDisplayPiece(String(delta[start..<delta.endIndex]), to: &segments, currentIndex: &currentIndex)
                start = delta.endIndex
            }
        }
    }

    private func appendDisplayPiece(_ piece: String, to segments: inout [Segment], currentIndex: inout Int?) {
        guard !piece.isEmpty else {
            return
        }
        if let index = currentIndex, segments.indices.contains(index) {
            segments[index].text += piece
        } else {
            segments.append(Segment(id: nextSegmentID, text: piece))
            nextSegmentID += 1
            currentIndex = segments.count - 1
        }
    }

    private func startDisplaySegment(in segments: inout [Segment], currentIndex: inout Int?) {
        segments.append(Segment(id: nextSegmentID, text: ""))
        nextSegmentID += 1
        currentIndex = segments.count - 1
    }
}

@MainActor
final class AIAnalysisViewModel: ObservableObject {
    @Published var isAnalyzing = false
    let streamBuffer = AIStreamBuffer()

    // MARK: - Analysis results by mode
    @Published var momentAnalysis = ""
    @Published var momentReasoning = ""
    @Published var scanAnalysis = ""
    @Published var scanReasoning = ""
    @Published var classicalAnalysis = ""
    @Published var classicalReasoning = ""
    @Published var horaryAnalysis = ""
    @Published var horaryReasoning = ""
    @Published var vedicAnalysis = ""
    @Published var vedicReasoning = ""

    // MARK: - Modern sub-mode analysis
    @Published var modernAnalysisByMode: [String: String] = [:]
    @Published var modernReasoningByMode: [String: String] = [:]
}
