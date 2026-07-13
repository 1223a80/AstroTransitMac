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
    @EnvironmentObject var appState: AppState
    @State var mode: CalculationMode = .settings
    @StateObject var calcVM = CalculationViewModel()
    @StateObject var aiVM = AIAnalysisViewModel()
    @State var natalDate = Self.fixedDate(year: 1990, month: 1, day: 1, hour: 12, minute: 0)
    @State var transitDate = Date()
    @State var horaryDate = Date()
    @State var scanStartDate = Self.fixedDate(year: 2026, month: 5, day: 1, hour: 0, minute: 0)
    @State var scanEndDate = Self.fixedDate(year: 2026, month: 6, day: 30, hour: 23, minute: 59)
    @State var classicalReferenceDate = Date()
    @State var scanWindowLabel = "May-Jun 2026"
    @State var selectedScanKind = "aspect"
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
    @State var gmtOffset = 8.0
    @State var birthLatitude = "31.2304"
    @State var birthLongitude = "121.4737"
    @State var horaryPlaceName = "当前提问地点"
    @State var horaryLatitude = "31.2304"
    @State var horaryLongitude = "121.4737"
    @State var horaryGmtOffset = 8.0
    @State var horaryQuestionText = ""
    @StateObject var currentLocationManager = CurrentLocationManager()
    @State var selectedHouseSystem = "whole_sign"
    @State var selectedZodiac = "tropical"
    @State var selectedBoundsSystem = "egyptian"
    @State var selectedTriplicitySystem = "dorothean"
    @State var classicalAspectOrb = 3.0
    @State var swissephStatus = "正在检测 pyswisseph..."
    @State var selectedNatalBodies = Set(bodyOptions.filter(\.isDefault).map(\.id))
    @State var selectedTransitBodies = Set(bodyOptions.filter(\.isDefault).map(\.id))
    @State var selectedAspects = Set(aspectOptions.filter(\.isDefault).map(\.id))
    @State var customAspectDegrees = ""
    @State var customAsteroids = ""
    @State var globalOrb = 3.0
    @State var momentPresetName = ""
    @State var selectedMomentPresetID = ""
    @State var scanPresetName = ""
    @State var selectedScanPresetID = ""
    @State var isNavigationCollapsed = false
    @State var isMiddleSidebarCollapsed = false
    @State var isShowingAppSettingsPage = false
    @State var middleSidebarWidth: CGFloat = 430
    @State var middleSidebarLastExpandedWidth: CGFloat = 430
    @State var middleSidebarDragStartWidth: CGFloat?
    @State var collapsedSections: Set<String> = []
    @State var momentConfigText = ""
    @State var scanConfigText = ""
    @State var showClassicalExportSheet = false
    @State var classicalExportSections: Set<MarkdownExportBuilder.ExportSection> = Set(MarkdownExportBuilder.ExportSection.classicalSectionIDs)

    @State var isParamDrawerPinned = false
    @State var isAIPanelOpen = false
    @State var pendingScanConfirmation: ScanWorkConfirmation?

    @State var modernSubMode = ModernSubMode.natal
    @State var modernPersonBDate = Self.fixedDate(year: 1992, month: 6, day: 15, hour: 8, minute: 30, gmtOffset: -5)
    @State var modernPersonBLatitude = "40.7128"
    @State var modernPersonBLongitude = "-74.0060"
    @State var modernPersonBGmtOffset = -5.0
    @State var modernNodeMode = "true_node"
    @State var modernHarmonicOrder = 4
    @State var modernReturnBodyID = "SUN"
    @State var modernReturnLocationSource = "birth"
    @State var modernReturnLocationName = "Shanghai"
    @State var modernReturnLocationLatitude = "31.2304"
    @State var modernReturnLocationLongitude = "121.4737"
    @State var modernReturnLocationTimezone = "Asia/Shanghai"

    // Vedic astrology state
    @State var vedicAyanamsha = "lahiri"
    @State var vedicFullMode = false
    @State var showVedicExportSheet = false
    @State var vedicExportSections: Set<MarkdownExportBuilder.ExportSection> = Set(MarkdownExportBuilder.ExportSection.vedicSectionIDs)

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

    static func fixedDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, gmtOffset: Double? = nil) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = gmtOffset.map { GMTOffset.timeZone(hours: $0) } ?? .current
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
        VStack(spacing: 0) {
            appTopBar
            Rectangle().fill(TS.SemanticColor.line).frame(height: 1)
            HStack(spacing: 0) {
            AppNavigationRail(
                isCollapsed: $isNavigationCollapsed,
                selectedPracticeMode: practiceModeBinding,
                selectedMode: $mode,
                isShowingSettingsPage: $isShowingAppSettingsPage,
                modernSubMode: $modernSubMode
            )
                .frame(width: isNavigationCollapsed ? TS.Layout.navigationRailCollapsed : TS.Layout.navigationRailExpanded)
                .background(TS.SemanticColor.paperRaised)

            divider

            if !isShowingAppSettingsPage {
                if isMiddleSidebarCollapsed {
                    collapsedMiddleSidebarToggle
                } else {
                    middleSidebarColumn
                    divider
                }
            }

            resultsPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isShowingAppSettingsPage {
                divider
                aiPanelColumn
            }
            }
            .background(TS.SemanticColor.paper)

            Rectangle().fill(TS.SemanticColor.line).frame(height: 1)
            statusBar
        }
        .task(id: appState.pythonPath) {
            swissephStatus = await BackendClient.swissephStatus(pythonPath: appState.pythonPath)
        }
        .onAppear {
            if selectedNatalProfileID.isEmpty, let first = natalProfiles.first {
                selectedNatalProfileID = first.id.uuidString
                // Populate the form from the saved profile so the fields match
                // the profile capsule instead of showing hardcoded defaults.
                loadSelectedNatalProfile()
            }
        }
        .onChange(of: modernSubMode) { newValue in
            calcVM.resetModernSelectedTab(for: newValue)
        }
        .onChange(of: rectifyInputHash) { _ in
            if mode == .rectify, calcVM.isRunning {
                calcVM.currentRunTask?.cancel()
                calcVM.invalidateActiveRun()
                calcVM.isRunning = false
                finishProgress(cancelled: true)
            }
            calcVM.invalidateRectifyResults()
        }
        .alert(item: $pendingScanConfirmation) { confirmation in
            Alert(
                title: Text("扫描计算量较大"),
                message: Text(confirmation.estimate.confirmationText),
                primaryButton: .destructive(Text("仍然计算")) {
                    pendingScanConfirmation = nil
                    startRunTask(confirmedHeavyScan: true)
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
        .preferredColorScheme(appState.preferredScheme)
        .tint(TS.SemanticColor.gold)
        .environmentObject(calcVM)
        .environmentObject(aiVM)
        .environmentObject(aiVM.streamBuffer)
    }

    var divider: some View {
        Rectangle()
            .fill(TS.SemanticColor.line)
            .frame(width: 1)
            .frame(maxHeight: .infinity)
    }

    var statusBar: some View {
        HStack(spacing: TS.Spacing.xl) {
            HStack(spacing: TS.Spacing.sm) {
                Circle()
                    .fill(swissephStatus.hasPrefix("已") ? TS.SemanticColor.success : TS.SemanticColor.warning)
                    .frame(width: 6, height: 6)
                Text(swissephStatus)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: TS.Spacing.md)
            if practiceMode != .vedic {
                Text("\(houseSystemLabel) · \(zodiacLabel)")
            } else {
                Text("Sidereal · \(vedicAyanamsha.capitalized)")
            }
        }
        .font(TS.Font.monoSmall)
        .foregroundStyle(TS.SemanticColor.inkFaint)
        .padding(.horizontal, TS.Padding.sidebarContent)
        .padding(.vertical, TS.Spacing.sm)
        .background(TS.SemanticColor.paperRaised)
    }

    var practiceMode: PracticeMode {
        get { PracticeMode(rawValue: appState.practiceModeStorage) ?? .modern }
        nonmutating set { appState.practiceModeStorage = newValue.rawValue }
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
