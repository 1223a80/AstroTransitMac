import SwiftUI

struct PickerOption: Identifiable {
    let id: String
    let title: String
}

struct TargetPositionOption: Identifiable, Hashable {
    let id: String
    let name: String
    let longitude: Double
}

struct ContentView: View {
    @State var mode: CalculationMode = .settings
    @AppStorage("natalChartStyle") var practiceModeStorage = PracticeMode.modern.rawValue
    @State var natalDate = Self.fixedDate(year: 1990, month: 1, day: 1, hour: 12, minute: 0)
    @State var transitDate = Date()
    @State var horaryDate = Date()
    @State var scanStartDate = Self.fixedDate(year: 2026, month: 5, day: 1, hour: 0, minute: 0)
    @State var scanEndDate = Self.fixedDate(year: 2026, month: 6, day: 30, hour: 23, minute: 59)
    @State var classicalReferenceDate = Date()
    @State var scanWindowLabel = "May-Jun 2026"
    @State var selectedScanKind = "aspect"
    @AppStorage("natalProfilesJSON") var natalProfilesJSON = ""
    @State var natalProfileName = "我的本命盘"
    @State var selectedNatalProfileID = ""
    @State var targetSource = "natal"
    @State var selectedTargetAngles = Set<String>()
    @State var selectedTargetPlanets = Set<String>()
    @State var selectedTargetAsteroids = Set<String>()
    @State var selectedTargetHouses = Set<Int>()
    @State var selectedTargetLots = Set<String>()
    @State var customLotTargetsText = ""
    @State var scanMoonFilter = "exclude"
    @State var scanTargetsText = Self.defaultScanTargets
    @State var gmtOffset = 8
    @State var birthLatitude = "31.2304"
    @State var birthLongitude = "121.4737"
    @State var horaryPlaceName = "当前提问地点"
    @State var horaryLatitude = "31.2304"
    @State var horaryLongitude = "121.4737"
    @State var horaryQuestionText = ""
    @StateObject var currentLocationManager = CurrentLocationManager()
    @State var selectedHouseSystem = "whole_sign"
    @State var selectedZodiac = "tropical"
    @State var selectedBoundsSystem = "egyptian"
    @State var selectedTriplicitySystem = "dorothean"
    @State var classicalAspectOrb = 3.0
    @AppStorage("pythonPath") var pythonPath = BackendClient.suggestedPythonPath()
    @State var swissephStatus = "正在检测 pyswisseph..."
    @AppStorage("ephemerisPath") var ephemerisPath = ""
    @AppStorage("noAsteroids") var noAsteroids = false
    @AppStorage("requireEphemeris") var requireEphemeris = "warn"
    @AppStorage("autoDownloadAsteroids") var autoDownloadAsteroids = true
    @State var selectedNatalBodies = Set(bodyOptions.filter(\.isDefault).map(\.id))
    @State var selectedTransitBodies = Set(bodyOptions.filter(\.isDefault).map(\.id))
    @State var selectedAspects = Set(aspectOptions.filter(\.isDefault).map(\.id))
    @State var customAspectDegrees = ""
    @State var customAsteroids = ""
    @State var globalOrb = 3.0
    @AppStorage("llmBaseURL") var llmBaseURL = "https://open.bigmodel.cn/api/paas/v4"
    @AppStorage("llmModel") var llmModel = "glm-4.7-flash"
    @AppStorage("llmAPIKey") var llmAPIKey = ""
    @AppStorage("aiPromptStyle") var aiPromptStyle = "general"
    @AppStorage("aiPromptGeneral") var aiPromptGeneral = AIPromptDefaults.text(for: "general")
    @AppStorage("aiPromptNatal") var aiPromptNatal = AIPromptDefaults.text(for: "natal")
    @AppStorage("aiPromptTransit") var aiPromptTransit = AIPromptDefaults.text(for: "transit")
    @AppStorage("aiPromptScan") var aiPromptScan = AIPromptDefaults.text(for: "scan")
    @AppStorage("aiPromptClassical") var aiPromptClassical = AIPromptDefaults.text(for: "classical")
    @AppStorage("aiPromptHorary") var aiPromptHorary = AIPromptDefaults.text(for: "horary")
    @AppStorage("aiNote") var aiNote = ""
    @AppStorage("momentPresetsJSON") var momentPresetsJSON = ""
    @AppStorage("scanPresetsJSON") var scanPresetsJSON = ""
    @State var momentPresetName = ""
    @State var selectedMomentPresetID = ""
    @State var scanPresetName = ""
    @State var selectedScanPresetID = ""
    @State var momentAIAnalysis = ""
    @State var scanAIAnalysis = ""
    @State var classicalAIAnalysis = ""
    @State var horaryAIAnalysis = ""
    @State var isAnalyzingAI = false
    @State var isRunning = false
    @State var isNavigationCollapsed = false
    @State var isMiddleSidebarCollapsed = false
    @State var isShowingAppSettingsPage = false
    @State var middleSidebarWidth: CGFloat = 430
    @State var middleSidebarLastExpandedWidth: CGFloat = 430
    @State var middleSidebarDragStartWidth: CGFloat?
    @State var calculationProgress: Double?
    @State var calculationProgressText = ""
    @State var asteroidPreparationMessage = ""
    @State var progressTask: Task<Void, Never>?
    @State var errorMessage: String?
    @State var momentResult: TransitResult?
    @State var fullNatalResult: TransitResult?
    @State var scanResult: ScanResult?
    @State var classicalResult: ClassicalResult?
    @State var horaryResult: HoraryResult?
    @State var rectifyResponse: RectifyResponse?
    @State var rectifyLevel2Response: RectifyResponse?
    @State var rectifyLevel3Response: RectifyResponse?
    @State var rectifyS1Index = 0
    @State var rectifyS2Index = 0
    @State var rectifyActiveLevel = 1
    @State var collapsedSections: Set<String> = []
    @State var rectifyLevel2Gen = 0
    @State var rectifyLevel3Gen = 0
    @State var rectifyLevel3ResponseID = 0
    @State var momentConfigText = ""
    @State var scanConfigText = ""
    @State var classicalSelectedTab = "planets"
    @State var showClassicalExportSheet = false
    @State var classicalExportSections: Set<MarkdownExportBuilder.ExportSection> = Set(MarkdownExportBuilder.ExportSection.allCases)
    @State var horarySelectedTab = "overview"
    @State var modernNatalSelectedTab = "natal_positions"
    @State var momentSelectedTab = "aspects"
    @State var scanSelectedTab = "hits"

    @State var modernSubMode = ModernSubMode.natal
    @State var modernResultData: ModernResultData?
    @State var modernPersonBDate = Self.fixedDate(year: 1992, month: 6, day: 15, hour: 8, minute: 30)
    @State var modernPersonBLatitude = "40.7128"
    @State var modernPersonBLongitude = "-74.0060"
    @State var modernNodeMode = "true_node"
    @State var modernHarmonicOrder = 4
    @State var modernAIAnalysis = ""
    @State var modernSelectedTab = "planets"

    // Vedic astrology state
    @State var vedicResult: VedicResult?
    @State var vedicAyanamsha = "lahiri"
    @State var vedicSelectedTab = "overview"
    @State var vedicFullMode = false

    static let houseSystemOptions = [
        PickerOption(id: "whole_sign", title: "Whole Sign"),
        PickerOption(id: "placidus", title: "Placidus"),
        PickerOption(id: "porphyry", title: "Porphyry"),
        PickerOption(id: "regiomontanus", title: "Regiomontanus"),
        PickerOption(id: "alcabitius", title: "Alcabitius"),
        PickerOption(id: "equal", title: "Equal")
    ]

    static let zodiacOptions = [
        PickerOption(id: "tropical", title: "Tropical"),
        PickerOption(id: "sidereal_lahiri", title: "Lahiri Sidereal"),
        PickerOption(id: "sidereal_raman", title: "Raman Sidereal"),
        PickerOption(id: "sidereal_krishnamurti", title: "Krishnamurti Sidereal"),
        PickerOption(id: "sidereal_yukteshwar", title: "Yukteshwar Sidereal"),
    ]

    static let ayanamshaOptions = [
        PickerOption(id: "lahiri", title: "Lahiri"),
        PickerOption(id: "raman", title: "Raman"),
        PickerOption(id: "krishnamurti", title: "Krishnamurti"),
        PickerOption(id: "yukteshwar", title: "Yukteshwar"),
        PickerOption(id: "suryasiddhanta", title: "Surya Siddhanta"),
    ]

    static let boundsOptions = [
        PickerOption(id: "egyptian", title: "Egyptian"),
        PickerOption(id: "ptolemaic", title: "Ptolemaic")
    ]

    static let triplicityOptions = [
        PickerOption(id: "dorothean", title: "Dorothean"),
        PickerOption(id: "ptolemaic", title: "Ptolemaic")
    ]

    static let scanKindOptions = [
        PickerOption(id: "aspect", title: "精确相位"),
        PickerOption(id: "ingress", title: "进入星座"),
        PickerOption(id: "station", title: "顺逆停滞")
    ]

    static let moonFilterOptions = [
        PickerOption(id: "exclude", title: "默认隐藏月亮"),
        PickerOption(id: "include", title: "包含月亮"),
        PickerOption(id: "only", title: "只看月亮")
    ]

    static let targetSourceOptions = [
        PickerOption(id: "natal", title: "本命盘"),
        PickerOption(id: "custom", title: "自定义")
    ]

    static let nodeModeOptions = [
        PickerOption(id: "true_node", title: "真节点"),
        PickerOption(id: "mean_node", title: "平节点"),
    ]

    static func fixedDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? Date()
    }

    static let defaultScanTargets = """
    Natal ASC = Capricorn 02°34
    Natal DSC = Cancer 02°34
    Natal Sun = Leo 17°04
    Natal Moon = Taurus 02°50
    Natal Mercury = Virgo 08°45
    Natal Venus = Cancer 01°39
    Natal Mars = Leo 29°18
    Natal Jupiter = Virgo 20°10
    Natal Saturn = Cancer 20°50
    Natal 5th Cusp = Taurus 18°43
    Natal 7th Cusp = Cancer 02°34
    Lot of Eros = Aries 17°25
    Love Point = Scorpio 17°10
    Victory Point = Cancer 05°56
    """

    var body: some View {
        HStack(spacing: 0) {
            AppNavigationRail(
                isCollapsed: $isNavigationCollapsed,
                selectedPracticeMode: practiceModeBinding,
                selectedMode: $mode,
                isShowingSettingsPage: $isShowingAppSettingsPage,
                modernSubMode: $modernSubMode
            )
                .frame(width: isNavigationCollapsed ? 72 : 178)
                .background(.regularMaterial)

            Divider()

            if !isShowingAppSettingsPage {
                if isMiddleSidebarCollapsed {
                    collapsedMiddleSidebarToggle
                } else {
                    middleSidebarColumn
                    Divider()
                }
            }

            resultsPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: pythonPath) {
            swissephStatus = await BackendClient.swissephStatus(pythonPath: pythonPath)
        }
        .onAppear {
            if selectedNatalProfileID.isEmpty, let first = natalProfiles.first {
                selectedNatalProfileID = first.id.uuidString
            }
        }
        .tint(.accentColor)
    }

    var practiceMode: PracticeMode {
        get { PracticeMode(rawValue: practiceModeStorage) ?? .modern }
        nonmutating set { practiceModeStorage = newValue.rawValue }
    }

    var practiceModeBinding: Binding<PracticeMode> {
        Binding(
            get: { practiceMode },
            set: { newValue in
                practiceMode = newValue
                isShowingAppSettingsPage = false
            }
        )
    }


}
