import Testing
@testable import TransitStudio

@MainActor
struct AIStreamBufferTests {
    @Test func appendsStreamingDeltasAndRebuildsCurrentTextOnDemand() {
        let buffer = AIStreamBuffer()

        buffer.begin(key: "moment")
        buffer.append(textDelta: "第一段", reasoningDelta: "")
        buffer.append(textDelta: "第二段", reasoningDelta: "思考")

        #expect(buffer.activeKey == "moment")
        #expect(buffer.hasText)
        #expect(buffer.hasReasoning)
        #expect(buffer.textSegments.map(\.text) == ["第一段第二段"])
        #expect(buffer.reasoningSegments.map(\.text) == ["思考"])
        #expect(buffer.currentText() == "第一段第二段")
        #expect(buffer.currentReasoning() == "思考")
    }

    @Test func preservesRealNewlinesAcrossStreamingDeltas() {
        let buffer = AIStreamBuffer()

        buffer.begin(key: "moment")
        buffer.append(textDelta: "第一行\n\n第二", reasoningDelta: "")
        buffer.append(textDelta: "行", reasoningDelta: "")

        #expect(buffer.textSegments.map(\.text) == ["第一行", "", "第二行"])
        #expect(buffer.currentText() == "第一行\n\n第二行")
    }

    @Test func beginClearsPreviousStreamSegments() {
        let buffer = AIStreamBuffer()

        buffer.begin(key: "moment")
        buffer.append(textDelta: "旧文本", reasoningDelta: "旧思考")
        buffer.begin(key: "scan")

        #expect(buffer.activeKey == "scan")
        #expect(!buffer.hasText)
        #expect(!buffer.hasReasoning)
        #expect(buffer.textSegments.isEmpty)
        #expect(buffer.reasoningSegments.isEmpty)
        #expect(buffer.currentText().isEmpty)
        #expect(buffer.currentReasoning().isEmpty)
    }
}
