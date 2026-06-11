import Foundation
import Testing
@testable import TransitStudio

@MainActor
struct AppStateTests {
    @Test func defaultLLMSettingsUseDeepSeekV4() {
        let suiteName = "TransitStudioTests.AppState.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let state = AppState(defaults: defaults)

        #expect(state.llmBaseURL == "https://api.deepseek.com")
        #expect(state.llmModel == "deepseek-v4-flash")
        #expect(state.savedLLMModels.contains("deepseek-v4-flash"))
        #expect(state.savedLLMModels.contains("deepseek-v4-pro"))
        #expect(state.aiReasoningEffort == "max")
    }
}
