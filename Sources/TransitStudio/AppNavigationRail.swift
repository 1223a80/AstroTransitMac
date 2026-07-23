import SwiftUI

struct AppNavigationRail: View {
    @Binding var isCollapsed: Bool
    @Binding var selectedPracticeMode: PracticeMode
    @Binding var selectedMode: CalculationMode
    @Binding var isShowingSettingsPage: Bool
    @Binding var modernSubMode: ModernSubMode
    @Binding var classicalSettingsWorkspace: ClassicalSettingsWorkspace

    /// Optional hooks so host can dual-write workspace + sub-mode with pure helpers.
    var onSelectClassicalNatal: (() -> Void)?
    var onSelectClassicalExpansion: ((ModernSubMode) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            collapseButton
            modeButtons
            Spacer(minLength: TS.Spacing.lg)
            settingsButton
        }
        .padding(.vertical, TS.Spacing.lg)
    }

    // MARK: Collapse

    private var collapseButton: some View {
        Button {
            isCollapsed.toggle()
        } label: {
            HStack(spacing: TS.Spacing.md) {
                Image(systemName: isCollapsed ? "chevron.right.2" : "chevron.left.2")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                if !isCollapsed {
                    Text("收起")
                        .font(TS.Font.label)
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(TS.SemanticColor.inkFaint)
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, TS.Padding.chipHorizontal + 4)
    }

    // MARK: Mode buttons

    private var modeButtons: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            groupLabel("星图")
            if selectedPracticeMode == .modern {
                modernSubModeButtons
            } else if selectedPracticeMode == .classical {
                classicalModeButtons
            } else {
                vedicModeButtons
            }

            groupLabel("行运")
                .padding(.top, TS.Spacing.sm)
            navigationButton(title: "时间点", icon: "clock", mode: .moment)
            navigationButton(title: "窗口扫描", icon: "calendar.badge.clock", mode: .scan)
        }
        .padding(.horizontal, TS.Spacing.md)
    }

    private func groupLabel(_ text: String) -> some View {
        Group {
            if isCollapsed {
                Rectangle()
                    .fill(TS.SemanticColor.line)
                    .frame(height: 1)
                    .padding(.horizontal, TS.Spacing.sm)
                    .padding(.vertical, TS.Spacing.sm)
            } else {
                Text(text.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(1.4)
                    .foregroundStyle(TS.SemanticColor.inkFaint)
                    .padding(.horizontal, TS.Padding.chipHorizontal)
                    .padding(.top, TS.Spacing.sm)
                    .padding(.bottom, TS.Spacing.xs)
            }
        }
    }

    private var classicalModeButtons: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            classicalNatalButton
            navigationButton(title: "Horary", icon: "questionmark.bubble", mode: .horary)
            navigationButton(title: "生时矫正", icon: "clock.arrow.circlepath", mode: .rectify)

            groupLabel("古典进阶")
                .padding(.top, TS.Spacing.sm)
            ForEach(ClassicalExpansionCatalog.modes) { subMode in
                classicalExpansionButton(subMode)
            }
        }
    }

    private var classicalNatalButton: some View {
        let isSelected = !isShowingSettingsPage
            && selectedMode == .settings
            && classicalSettingsWorkspace.isNatalChart
        return navButtonLabel(
            title: "本命设置",
            icon: "person.crop.circle",
            isSelected: isSelected
        ) {
            if let onSelectClassicalNatal {
                onSelectClassicalNatal()
            } else {
                let selection = ClassicalWorkspaceSelection.selectNatalChart()
                isShowingSettingsPage = selection.showSettingsPage
                selectedMode = selection.mode
                classicalSettingsWorkspace = selection.workspace
            }
        }
    }

    private func classicalExpansionButton(_ subMode: ModernSubMode) -> some View {
        let isSelected = !isShowingSettingsPage
            && selectedMode == .settings
            && classicalSettingsWorkspace.expansionMode == subMode
        return navButtonLabel(
            title: subMode.title,
            icon: subMode.icon,
            isSelected: isSelected
        ) {
            if let onSelectClassicalExpansion {
                onSelectClassicalExpansion(subMode)
            } else if let selection = ClassicalWorkspaceSelection.selectExpansion(subMode) {
                isShowingSettingsPage = selection.showSettingsPage
                selectedMode = selection.mode
                classicalSettingsWorkspace = selection.workspace
                if modernSubMode != selection.modernSubMode {
                    modernSubMode = selection.modernSubMode
                }
            }
        }
    }

    private var vedicModeButtons: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            navigationButton(title: "吠陀排盘", icon: "sun.max.circle", mode: .settings)
        }
    }

    private var modernSubModeButtons: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            // Modern rail excludes classical-expansion eight (D1 / KD4).
            ForEach(ClassicalExpansionCatalog.modernRailSubModes) { subMode in
                modernNavButton(title: subMode.title, icon: subMode.icon, subMode: subMode)
            }
        }
    }

    private var settingsButton: some View {
        navigationButton(title: "程序设置", icon: "gearshape", isSelected: isShowingSettingsPage) {
            isShowingSettingsPage = true
        }
        .padding(.horizontal, TS.Spacing.md)
        .padding(.bottom, TS.Spacing.xs)
    }

    // MARK: Nav button primitives

    private func navigationButton(title: String, icon: String, mode: CalculationMode) -> some View {
        navigationButton(title: title, icon: icon, isSelected: !isShowingSettingsPage && selectedMode == mode) {
            isShowingSettingsPage = false
            selectedMode = mode
        }
    }

    private func modernNavButton(title: String, icon: String, subMode: ModernSubMode) -> some View {
        let isSelected = !isShowingSettingsPage && selectedMode == .settings && modernSubMode == subMode
        return navButtonLabel(title: title, icon: icon, isSelected: isSelected) {
            isShowingSettingsPage = false
            selectedMode = .settings
            if modernSubMode != subMode {
                modernSubMode = subMode
            }
        }
    }

    private func navigationButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        navButtonLabel(title: title, icon: icon, isSelected: isSelected, action: action)
    }

    private func navButtonLabel(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: TS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 20, height: 20)
                if !isCollapsed {
                    Text(title)
                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? TS.Spacing.sm : TS.Padding.chipHorizontal)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? TS.SemanticColor.goldDeep : TS.SemanticColor.inkSoft)
            .background(
                RoundedRectangle(cornerRadius: TS.Radius.card)
                    .fill(isSelected ? TS.SemanticColor.goldSoft : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(title)
    }
}
