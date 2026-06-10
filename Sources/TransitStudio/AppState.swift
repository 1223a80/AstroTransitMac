import SwiftUI

@MainActor
final class AppState: ObservableObject {
    private enum Key {
        static let pythonPath = "pythonPath"
        static let ephemerisPath = "ephemerisPath"
        static let noAsteroids = "noAsteroids"
        static let requireEphemeris = "requireEphemeris"
        static let autoDownloadAsteroids = "autoDownloadAsteroids"

        static let llmBaseURL = "llmBaseURL"
        static let llmModel = "llmModel"
        static let llmAPIKey = "llmAPIKey"
        static let savedLLMModels = "savedLLMModels"
        static let aiPromptStyle = "aiPromptStyle"
        static let aiPromptGeneral = "aiPromptGeneral"
        static let aiPromptNatal = "aiPromptNatal"
        static let aiPromptTransit = "aiPromptTransit"
        static let aiPromptScan = "aiPromptScan"
        static let aiPromptClassical = "aiPromptClassical"
        static let aiPromptHorary = "aiPromptHorary"
        static let aiNote = "aiNote"
        static let aiReasoningEffort = "aiReasoningEffort"

        static let natalProfilesJSON = "natalProfilesJSON"
        static let momentPresetsJSON = "momentPresetsJSON"
        static let scanPresetsJSON = "scanPresetsJSON"
        static let practiceModeStorage = "natalChartStyle"
    }

    private let defaults: UserDefaults

    @Published var pythonPath: String { didSet { defaults.set(pythonPath, forKey: Key.pythonPath) } }
    @Published var ephemerisPath: String { didSet { defaults.set(ephemerisPath, forKey: Key.ephemerisPath) } }
    @Published var noAsteroids: Bool { didSet { defaults.set(noAsteroids, forKey: Key.noAsteroids) } }
    @Published var requireEphemeris: String { didSet { defaults.set(requireEphemeris, forKey: Key.requireEphemeris) } }
    @Published var autoDownloadAsteroids: Bool { didSet { defaults.set(autoDownloadAsteroids, forKey: Key.autoDownloadAsteroids) } }

    @Published var llmBaseURL: String { didSet { defaults.set(llmBaseURL, forKey: Key.llmBaseURL) } }
    @Published var llmModel: String { didSet { defaults.set(llmModel, forKey: Key.llmModel) } }
    @Published var llmAPIKey: String { didSet { defaults.set(llmAPIKey, forKey: Key.llmAPIKey) } }
    @Published var savedLLMModels: String { didSet { defaults.set(savedLLMModels, forKey: Key.savedLLMModels) } }
    @Published var aiPromptStyle: String { didSet { defaults.set(aiPromptStyle, forKey: Key.aiPromptStyle) } }
    @Published var aiPromptGeneral: String { didSet { defaults.set(aiPromptGeneral, forKey: Key.aiPromptGeneral) } }
    @Published var aiPromptNatal: String { didSet { defaults.set(aiPromptNatal, forKey: Key.aiPromptNatal) } }
    @Published var aiPromptTransit: String { didSet { defaults.set(aiPromptTransit, forKey: Key.aiPromptTransit) } }
    @Published var aiPromptScan: String { didSet { defaults.set(aiPromptScan, forKey: Key.aiPromptScan) } }
    @Published var aiPromptClassical: String { didSet { defaults.set(aiPromptClassical, forKey: Key.aiPromptClassical) } }
    @Published var aiPromptHorary: String { didSet { defaults.set(aiPromptHorary, forKey: Key.aiPromptHorary) } }
    @Published var aiNote: String { didSet { defaults.set(aiNote, forKey: Key.aiNote) } }
    @Published var aiReasoningEffort: String { didSet { defaults.set(aiReasoningEffort, forKey: Key.aiReasoningEffort) } }

    @Published var natalProfilesJSON: String { didSet { defaults.set(natalProfilesJSON, forKey: Key.natalProfilesJSON) } }
    @Published var momentPresetsJSON: String { didSet { defaults.set(momentPresetsJSON, forKey: Key.momentPresetsJSON) } }
    @Published var scanPresetsJSON: String { didSet { defaults.set(scanPresetsJSON, forKey: Key.scanPresetsJSON) } }
    @Published var practiceModeStorage: String { didSet { defaults.set(practiceModeStorage, forKey: Key.practiceModeStorage) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        pythonPath = defaults.string(forKey: Key.pythonPath) ?? BackendClient.suggestedPythonPath()
        ephemerisPath = defaults.string(forKey: Key.ephemerisPath) ?? ""
        noAsteroids = defaults.object(forKey: Key.noAsteroids) as? Bool ?? false
        requireEphemeris = defaults.string(forKey: Key.requireEphemeris) ?? "warn"
        autoDownloadAsteroids = defaults.object(forKey: Key.autoDownloadAsteroids) as? Bool ?? true

        llmBaseURL = defaults.string(forKey: Key.llmBaseURL) ?? "https://open.bigmodel.cn/api/paas/v4"
        llmModel = defaults.string(forKey: Key.llmModel) ?? "glm-4.7-flash"
        llmAPIKey = defaults.string(forKey: Key.llmAPIKey) ?? ""
        savedLLMModels = defaults.string(forKey: Key.savedLLMModels) ?? "glm-4.7-flash"
        aiPromptStyle = defaults.string(forKey: Key.aiPromptStyle) ?? "general"
        aiPromptGeneral = defaults.string(forKey: Key.aiPromptGeneral) ?? AIPromptDefaults.text(for: "general")
        aiPromptNatal = defaults.string(forKey: Key.aiPromptNatal) ?? AIPromptDefaults.text(for: "natal")
        aiPromptTransit = defaults.string(forKey: Key.aiPromptTransit) ?? AIPromptDefaults.text(for: "transit")
        aiPromptScan = defaults.string(forKey: Key.aiPromptScan) ?? AIPromptDefaults.text(for: "scan")
        aiPromptClassical = defaults.string(forKey: Key.aiPromptClassical) ?? AIPromptDefaults.text(for: "classical")
        aiPromptHorary = defaults.string(forKey: Key.aiPromptHorary) ?? AIPromptDefaults.text(for: "horary")
        aiNote = defaults.string(forKey: Key.aiNote) ?? ""
        aiReasoningEffort = defaults.string(forKey: Key.aiReasoningEffort) ?? "max"

        natalProfilesJSON = defaults.string(forKey: Key.natalProfilesJSON) ?? ""
        momentPresetsJSON = defaults.string(forKey: Key.momentPresetsJSON) ?? ""
        scanPresetsJSON = defaults.string(forKey: Key.scanPresetsJSON) ?? ""
        practiceModeStorage = defaults.string(forKey: Key.practiceModeStorage) ?? PracticeMode.modern.rawValue
    }
}
