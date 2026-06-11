import Testing
@testable import TransitStudio

struct LLMAnalysisClientTests {
    @Test func deepSeekV4UsesMaximumOutputBudget() {
        let config = LLMAnalysisClient.Configuration(
            baseURL: "https://api.deepseek.com",
            model: "deepseek-v4-flash",
            apiKey: "test",
            reasoningEffort: "max"
        )

        #expect(LLMAnalysisClient.resolvedMaxTokens(for: config) == 384_000)
        #expect(LLMAnalysisClient.resolvedThinkingType(for: config) == "enabled")
    }

    @Test func deepSeekThinkingCanBeExplicitlyDisabled() {
        let config = LLMAnalysisClient.Configuration(
            baseURL: "https://api.deepseek.com",
            model: "deepseek-v4-pro",
            apiKey: "test",
            reasoningEffort: ""
        )

        #expect(LLMAnalysisClient.resolvedMaxTokens(for: config) == 384_000)
        #expect(LLMAnalysisClient.resolvedThinkingType(for: config) == "disabled")
    }

    @Test func nonDeepSeekProviderKeepsConservativeOutputBudget() {
        let config = LLMAnalysisClient.Configuration(
            baseURL: "https://example.com/v1",
            model: "other-model",
            apiKey: "test",
            reasoningEffort: "max"
        )

        #expect(LLMAnalysisClient.resolvedMaxTokens(for: config) == 4096)
        #expect(LLMAnalysisClient.resolvedThinkingType(for: config) == nil)
    }
}
