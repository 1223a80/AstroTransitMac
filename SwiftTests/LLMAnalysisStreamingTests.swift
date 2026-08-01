import Foundation
import Testing
@testable import TransitStudio

/// Intercepts URLSession requests in-process so `analyzeStreaming` can be
/// exercised against synthetic SSE payloads without a network.
final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

/// SSE streaming parse tests for LLMAnalysisClient. Serialized because
/// URLProtocol registration is process-global.
@Suite(.serialized)
struct LLMAnalysisStreamingTests {
    private func makeConfiguration() -> LLMAnalysisClient.Configuration {
        .init(
            baseURL: "https://mock.example/v1",
            model: "test-model",
            apiKey: "test-key",
            reasoningEffort: "max"
        )
    }

    private func withMockSSE(
        body: String,
        statusCode: Int = 200,
        _ operation: () async throws -> Void
    ) async throws {
        URLProtocol.registerClass(MockURLProtocol.self)
        defer { URLProtocol.unregisterClass(MockURLProtocol.self) }
        MockURLProtocol.handler = { request in
            #expect(request.url?.path == "/v1/chat/completions")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
            let response = HTTPURLResponse(
                url: try #require(request.url),
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/event-stream"]
            )!
            return (response, Data(body.utf8))
        }
        try await operation()
        MockURLProtocol.handler = nil
    }

    private func collectChunks(
        _ client: LLMAnalysisClient,
        configuration: LLMAnalysisClient.Configuration
    ) async throws -> [StreamChunk] {
        var chunks: [StreamChunk] = []
        for try await chunk in client.analyzeStreaming(
            title: "测试主题",
            structuredMarkdown: "结构化数据",
            note: "",
            configuration: configuration
        ) {
            chunks.append(chunk)
        }
        return chunks
    }

    @Test func streamsContentAndReasoningDeltasUntilDone() async throws {
        try await withMockSSE(body: """
        event: message_start
        data: {"choices":[{"delta":{"content":"你好","reasoning_content":"思考中"}}]}

        data: {"choices":[{"delta":{"content":"世界"}}]}

        data: [DONE]
        """) {
            let chunks = try await collectChunks(LLMAnalysisClient(), configuration: makeConfiguration())
            #expect(chunks.count == 2)
            #expect(chunks[0].content == "你好")
            #expect(chunks[0].reasoning == "思考中")
            #expect(chunks[1].content == "世界")
            #expect(chunks[1].reasoning.isEmpty)
            #expect(!chunks[0].isEmpty)
        }
    }

    @Test func ignoresEmptyDeltaAndEventOnlyLines() async throws {
        try await withMockSSE(body: """
        : comment line
        event: ping
        data: {"choices":[{"delta":{}}]}

        data: {"choices":[{"delta":{"content":""}}]}

        data: [DONE]
        """) {
            let chunks = try await collectChunks(LLMAnalysisClient(), configuration: makeConfiguration())
            #expect(chunks.isEmpty)
        }
    }

    @Test func emptyStreamFinishesWithoutError() async throws {
        try await withMockSSE(body: "event: keepalive\n\n") {
            let chunks = try await collectChunks(LLMAnalysisClient(), configuration: makeConfiguration())
            #expect(chunks.isEmpty)
        }
    }

    @Test func finishReasonLengthThrowsTruncatedError() async throws {
        try await withMockSSE(body: """
        data: {"choices":[{"delta":{"content":"半截"}}]}

        data: {"choices":[{"delta":{},"finish_reason":"length"}]}
        """) {
            await #expect(throws: LLMAnalysisError.self) {
                _ = try await collectChunks(LLMAnalysisClient(), configuration: makeConfiguration())
            }
        }
    }

    @Test func nonSuccessStatusThrowsServiceErrorWithDecodedMessage() async throws {
        try await withMockSSE(
            body: #"{"error":{"message":"Invalid API key"}}"#,
            statusCode: 401
        ) {
            do {
                _ = try await collectChunks(LLMAnalysisClient(), configuration: makeConfiguration())
                Issue.record("expected serviceError to be thrown")
            } catch let error as LLMAnalysisError {
                guard case .serviceError(let message) = error else {
                    Issue.record("expected serviceError, got \(error)")
                    return
                }
                #expect(message == "Invalid API key")
            }
        }
    }

    @Test func nonSuccessStatusFallsBackToRawBodyWhenNotJSON() async throws {
        try await withMockSSE(body: "upstream exploded", statusCode: 502) {
            do {
                _ = try await collectChunks(LLMAnalysisClient(), configuration: makeConfiguration())
                Issue.record("expected serviceError to be thrown")
            } catch let error as LLMAnalysisError {
                guard case .serviceError(let message) = error else {
                    Issue.record("expected serviceError, got \(error)")
                    return
                }
                #expect(message == "upstream exploded")
            }
        }
    }

    @Test func malformedJSONDataLinesAreSkipped() async throws {
        try await withMockSSE(body: """
        data: not-json

        data: {"choices":[{"delta":{"content":"幸存"}}]}

        data: [DONE]
        """) {
            let chunks = try await collectChunks(LLMAnalysisClient(), configuration: makeConfiguration())
            #expect(chunks.count == 1)
            #expect(chunks[0].content == "幸存")
        }
    }
}
