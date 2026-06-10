import SwiftUI

struct AppNavigationRail: View {
    @Binding var isCollapsed: Bool
    @Binding var selectedPracticeMode: PracticeMode
    @Binding var selectedMode: CalculationMode
    @Binding var isShowingSettingsPage: Bool
    @Binding var modernSubMode: ModernSubMode

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            titleBlock
            practiceModePicker
            collapseButton
            Divider()
            modeButtons
            Spacer()
            settingsButton
        }
        .padding(.vertical, TS.Spacing.sm)
    }

    private var titleBlock: some View {
        HStack(spacing: TS.Spacing.md) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(TS.Font.pageTitle)
                .foregroundStyle(TS.SemanticColor.accent)
                .frame(width: 30, height: 30)
            if !isCollapsed {
                VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                    Text("Transit")
                        .font(TS.Font.sectionTitle)
                    Text("Studio")
                        .font(TS.Font.detail)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, TS.Padding.chipHorizontal)
        .padding(.top, TS.Spacing.md)
    }

    private var practiceModePicker: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            if !isCollapsed {
                Text("模式")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, TS.Padding.chipHorizontal)
            }

            VStack(spacing: TS.Spacing.xs) {
                practiceModeButton(for: .modern, icon: "sparkles")
                practiceModeButton(for: .classical, icon: "scroll")
                practiceModeButton(for: .vedic, icon: "sun.max")
            }
            .padding(.horizontal, TS.Spacing.md)
        }
    }

    private var collapseButton: some View {
        Button {
            isCollapsed.toggle()
        } label: {
            HStack(spacing: TS.Spacing.lg) {
                Image(systemName: isCollapsed ? "sidebar.left" : "sidebar.leading")
                    .frame(width: 28, height: 28)
                if !isCollapsed {
                    Text("收起")
                        .font(TS.Font.body)
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, TS.Padding.chipHorizontal)
    }

    private var modeButtons: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            if selectedPracticeMode == .modern {
                modernSubModeButtons
            } else if selectedPracticeMode == .classical {
                classicalModeButtons
            } else {
                vedicModeButtons
            }
            navigationButton(title: "时间点", icon: "clock", mode: .moment)
            navigationButton(title: "窗口扫描", icon: "calendar.badge.clock", mode: .scan)
        }
        .padding(.horizontal, TS.Spacing.md)
    }

    private var classicalModeButtons: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            navigationButton(title: "本命设置", icon: "person.crop.circle", mode: .settings)
            navigationButton(title: "Horary", icon: "questionmark.bubble", mode: .horary)
            navigationButton(title: "生时矫正", icon: "clock.arrow.circlepath", mode: .rectify)
        }
    }

    private var vedicModeButtons: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            navigationButton(title: "吠陀排盘", icon: "sun.max.circle", mode: .settings)
        }
    }

    private var modernSubModeButtons: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            ForEach(ModernSubMode.allCases) { subMode in
                modernNavButton(
                    title: subMode.title,
                    icon: subMode.icon,
                    subMode: subMode
                )
            }
        }
    }

    private var settingsButton: some View {
        navigationButton(title: "程序设置", icon: "gearshape", isSelected: isShowingSettingsPage) {
            isShowingSettingsPage = true
        }
        .padding(.horizontal, TS.Spacing.md)
        .padding(.bottom, TS.Padding.resultContent)
    }

    private func navigationButton(title: String, icon: String, mode: CalculationMode) -> some View {
        navigationButton(title: title, icon: icon, isSelected: !isShowingSettingsPage && selectedMode == mode) {
            isShowingSettingsPage = false
            selectedMode = mode
        }
    }

    private func modernNavButton(title: String, icon: String, subMode: ModernSubMode) -> some View {
        let isSelected = !isShowingSettingsPage && selectedMode == .settings && modernSubMode == subMode
        return Button {
            isShowingSettingsPage = false
            selectedMode = .settings
            modernSubMode = subMode
        } label: {
            HStack(spacing: TS.Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
                if !isCollapsed {
                    Text(subMode.title)
                        .font(TS.Font.body.weight(isSelected ? .semibold : .regular))
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? TS.Spacing.sm : TS.Padding.chipHorizontal)
            .padding(.vertical, TS.Spacing.md)
            .foregroundStyle(isSelected ? TS.SemanticColor.accent : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: TS.Radius.card)
                    .fill(isSelected ? TS.SemanticColor.accentSubtle : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(subMode.title)
    }

    private func navigationButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: TS.Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 28, height: 28)
                if !isCollapsed {
                    Text(title)
                        .font(TS.Font.body.weight(isSelected ? .semibold : .regular))
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? TS.Spacing.sm : TS.Padding.chipHorizontal)
            .padding(.vertical, TS.Spacing.md)
            .foregroundStyle(isSelected ? TS.SemanticColor.accent : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: TS.Radius.card)
                    .fill(isSelected ? TS.SemanticColor.accentSubtle : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func practiceModeButton(for mode: PracticeMode, icon: String) -> some View {
        let isSelected = selectedPracticeMode == mode

        return Button {
            isShowingSettingsPage = false
            selectedPracticeMode = mode
        } label: {
            HStack(spacing: TS.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                if !isCollapsed {
                    Text(mode.title)
                        .font(TS.Font.body.weight(isSelected ? .semibold : .regular))
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? TS.Spacing.sm : TS.Padding.chipHorizontal)
            .padding(.vertical, TS.Spacing.md)
            .foregroundStyle(isSelected ? TS.SemanticColor.accent : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: TS.Radius.card)
                    .fill(isSelected ? TS.SemanticColor.accentSubtle : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(mode.title)
    }
}
