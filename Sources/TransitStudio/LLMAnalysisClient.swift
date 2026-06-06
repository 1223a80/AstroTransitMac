import Foundation

enum LLMAnalysisError: LocalizedError {
    case invalidConfiguration(String)
    case invalidResponse
    case serviceError(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return message
        case .invalidResponse:
            return "API 返回内容无法解析。"
        case .serviceError(let message):
            return message
        case .emptyResponse:
            return "API 返回了空内容。"
        }
    }
}

/// A chunk of streaming content, carrying either or both of the visible
/// response text and the model's reasoning / chain-of-thought text.
struct StreamChunk: Sendable {
    let content: String
    let reasoning: String

    var isEmpty: Bool { content.isEmpty && reasoning.isEmpty }
}

struct LLMAnalysisClient {
    struct Configuration {
        let baseURL: String
        let model: String
        let apiKey: String
        /// Reasoning effort for models that support it.
        /// Empty string means "don't send" (effort disabled).
        /// Typical values: "", "low", "medium", "high", "max".
        /// Defaults to "max".
        let reasoningEffort: String

        init(baseURL: String, model: String, apiKey: String, reasoningEffort: String = "max") {
            self.baseURL = baseURL
            self.model = model
            self.apiKey = apiKey
            self.reasoningEffort = reasoningEffort
        }
    }

    // MARK: - Non-streaming (kept for testAPIKey)

    func analyze(
        title: String,
        structuredMarkdown: String,
        note: String,
        promptStyle: String = "general",
        customSystemPrompt: String? = nil,
        configuration: Configuration
    ) async throws -> String {
        let customPrompt = customSystemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let systemPrompt = customPrompt.isEmpty ? defaultPrompt(for: promptStyle) : customPrompt

        let userPrompt = """
        分析主题：\(title)

        用户备注：

        \(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "无" : note)

        结构化数据：

        \(structuredMarkdown)
        """

        return try await chat(configuration: configuration, systemPrompt: systemPrompt, userPrompt: userPrompt)
    }

    // MARK: - Streaming

    /// Streaming variant of `analyze`. Returns an `AsyncThrowingStream` that
    /// yields `StreamChunk` values as tokens arrive over SSE.
    func analyzeStreaming(
        title: String,
        structuredMarkdown: String,
        note: String,
        promptStyle: String = "general",
        customSystemPrompt: String? = nil,
        configuration: Configuration
    ) -> AsyncThrowingStream<StreamChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let customPrompt = customSystemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let systemPrompt = customPrompt.isEmpty ? defaultPrompt(for: promptStyle) : customPrompt

                    let userPrompt = """
                    分析主题：\(title)

                    用户备注：

                    \(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "无" : note)

                    结构化数据：

                    \(structuredMarkdown)
                    """

                    try await chatStreaming(
                        configuration: configuration,
                        systemPrompt: systemPrompt,
                        userPrompt: userPrompt,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Non-streaming prompt builder for natal-chart JSON.
    func analyzeNatalChart(chartJSON: String, configuration: Configuration) async throws -> String {
        let systemPrompt = """
        你是一名严谨的占星分析助手。基于用户提供的结构化本命盘 JSON 做分析，不要臆造 JSON 中没有的数据。
        输出中文 Markdown，优先解释结构、重点张力、行星状态、宫位/Lots、相位与接纳。明确区分事实、推断和不确定性。
        """

        let userPrompt = """
        请分析这份本命盘结构化数据：

        ```json
        \(chartJSON)
        ```
        """

        return try await chat(configuration: configuration, systemPrompt: systemPrompt, userPrompt: userPrompt)
    }

    // MARK: - Private

    private func defaultPrompt(for style: String) -> String {
        switch style {
        case "natal":
            return "你是一名严谨的本命盘分析助手。只基于输入数据分析性格结构、行星重点、宫位与相位证据。输出中文 Markdown，使用 ### 分节，不要臆造。"
        case "transit":
            return "你是一名严谨的行运分析助手。只基于输入的行运与本命相位分析时间点影响。输出中文 Markdown，使用 ### 分节，区分事实、推断和不确定性。"
        case "scan":
            return "你是一名严谨的行运窗口扫描分析助手。先按重要性筛选命中，再解释可能主题。输出中文 Markdown，使用 ### 分节，不要把低权重命中夸大。"
        case "classical":
            return "你是一名严谨的古典占星分析助手。基于昼夜盘、尊贵、宫位、Lots、接纳、年小限和法达做证据链分析。输出中文 Markdown，使用 ### 分节。"
        case "horary":
            return "你是一名严谨的 Horary 占星分析助手。先复述问题文本，再只基于输入的结构化 Horary 盘面信息分析盘面重点、宫位、行星状态、Lots、相位与接纳。输出中文 Markdown，使用 ### 分节，不要臆造。"
        default:
            return "你是一名严谨的占星分析助手。基于用户提供的结构化 Markdown 做分析，不要臆造输入中没有的数据。输出中文 Markdown，使用 ### 分节，明确区分事实、推断和不确定性。"
        }
    }

    /// Non-streaming chat completion.
    private func chat(configuration: Configuration, systemPrompt: String, userPrompt: String) async throws -> String {
        let body = try makeBody(configuration: configuration, systemPrompt: systemPrompt, userPrompt: userPrompt, stream: false)
        let request = try makeURLRequest(configuration: configuration, body: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMAnalysisError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let decoded = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw LLMAnalysisError.serviceError(decoded.error.message)
            }
            let fallback = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw LLMAnalysisError.serviceError(fallback?.isEmpty == false ? fallback! : "API 请求失败（HTTP \(httpResponse.statusCode)）。")
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw LLMAnalysisError.emptyResponse
        }
        return content
    }

    /// Streaming chat completion via SSE. Yields tokens into the continuation.
    private func chatStreaming(
        configuration: Configuration,
        systemPrompt: String,
        userPrompt: String,
        continuation: AsyncThrowingStream<StreamChunk, Error>.Continuation
    ) async throws {
        let body = try makeBody(configuration: configuration, systemPrompt: systemPrompt, userPrompt: userPrompt, stream: true)
        let request = try makeURLRequest(configuration: configuration, body: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMAnalysisError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            // Collect error body from bytes
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            if let decoded = try? JSONDecoder().decode(ErrorResponse.self, from: errorData) {
                throw LLMAnalysisError.serviceError(decoded.error.message)
            }
            let fallback = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw LLMAnalysisError.serviceError(fallback?.isEmpty == false ? fallback! : "API 请求失败（HTTP \(httpResponse.statusCode)）。")
        }

        // SSE parsing. Accumulate raw bytes so multibyte UTF-8 tokens are preserved.
        var currentLine = Data()
        for try await byte in bytes {
            if byte == 0x0A {
                if currentLine.last == 0x0D {
                    currentLine.removeLast()
                }
                let line = String(data: currentLine, encoding: .utf8) ?? ""
                currentLine.removeAll(keepingCapacity: true)
                if line.hasPrefix("data: ") {
                    let data = String(line.dropFirst(6))
                    if data == "[DONE]" {
                        break
                    }
                    guard let jsonData = data.data(using: .utf8) else { continue }
                    if let chunk = try? JSONDecoder().decode(StreamChunkResponse.self, from: jsonData) {
                        if let delta = chunk.choices?.first?.delta {
                            let content = delta.content ?? ""
                            let reasoning = delta.reasoningContent ?? ""
                            if !content.isEmpty || !reasoning.isEmpty {
                                continuation.yield(StreamChunk(content: content, reasoning: reasoning))
                            }
                        }
                    }
                }
                // Ignore empty lines and event: lines
            } else {
                currentLine.append(byte)
            }
        }

        continuation.finish()
    }

    // MARK: - Request Building

    private func makeURLRequest(configuration: Configuration, body: Data) throws -> URLRequest {
        let base = configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let apiKey = configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let baseURL = URL(string: base), !base.isEmpty else {
            throw LLMAnalysisError.invalidConfiguration("API Base URL 无效。")
        }
        guard !apiKey.isEmpty else {
            throw LLMAnalysisError.invalidConfiguration("API Key 不能为空。")
        }

        let endpoint = baseURL.appendingPathComponent("chat").appendingPathComponent("completions")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        return request
    }

    private func makeBody(configuration: Configuration, systemPrompt: String, userPrompt: String, stream: Bool) throws -> Data {
        try JSONEncoder().encode(ChatRequest(
            model: configuration.model.trimmingCharacters(in: .whitespacesAndNewlines),
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: userPrompt)
            ],
            temperature: 0.2,
            maxTokens: 4096,
            stream: stream,
            reasoningEffort: configuration.reasoningEffort.isEmpty ? nil : configuration.reasoningEffort
        ))
    }
}

// MARK: - Request / Response Structs

private struct ChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
    let maxTokens: Int
    let stream: Bool
    let reasoningEffort: String?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
        case stream
        case reasoningEffort = "reasoning_effort"
    }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let choices: [Choice]
}

/// SSE streaming chunk (OpenAI-compatible delta format).
private struct StreamChunkResponse: Decodable {
    struct Choice: Decodable {
        struct Delta: Decodable {
            let content: String?
            let reasoningContent: String?

            enum CodingKeys: String, CodingKey {
                case content
                case reasoningContent = "reasoning_content"
            }
        }

        let delta: Delta
    }

    let choices: [Choice]?
}

private struct ErrorResponse: Decodable {
    struct ErrorBody: Decodable {
        let message: String
    }

    let error: ErrorBody
}
