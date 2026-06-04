import SwiftUI

struct AppNavigationRail: View {
    @Binding var isCollapsed: Bool
    @Binding var selectedPracticeMode: PracticeMode
    @Binding var selectedMode: CalculationMode
    @Binding var isShowingSettingsPage: Bool
    @Binding var modernSubMode: ModernSubMode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleBlock
            practiceModePicker
            collapseButton
            Divider()
            modeButtons
            Spacer()
            settingsButton
        }
    }

    private var titleBlock: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
            if !isCollapsed {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Transit")
                        .font(.headline)
                    Text("Studio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
    }

    private var practiceModePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !isCollapsed {
                Text("模式")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
            }

            VStack(spacing: 2) {
                practiceModeButton(for: .modern, icon: "sparkles")
                practiceModeButton(for: .classical, icon: "scroll")
                practiceModeButton(for: .vedic, icon: "sun.max")
            }
            .padding(.horizontal, 8)
        }
    }

    private var collapseButton: some View {
        Button {
            isCollapsed.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isCollapsed ? "sidebar.left" : "sidebar.leading")
                    .frame(width: 28, height: 28)
                if !isCollapsed {
                    Text("收起")
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
    }

    private var modeButtons: some View {
        VStack(alignment: .leading, spacing: 6) {
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
        .padding(.horizontal, 8)
    }

    private var classicalModeButtons: some View {
        VStack(alignment: .leading, spacing: 6) {
            navigationButton(title: "本命设置", icon: "person.crop.circle", mode: .settings)
            navigationButton(title: "Horary", icon: "questionmark.bubble", mode: .horary)
            navigationButton(title: "生时矫正", icon: "clock.arrow.circlepath", mode: .rectify)
        }
    }

    private var vedicModeButtons: some View {
        VStack(alignment: .leading, spacing: 6) {
            navigationButton(title: "吠陀排盘", icon: "sun.max.circle", mode: .settings)
        }
    }

    private var modernSubModeButtons: some View {
        VStack(alignment: .leading, spacing: 6) {
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
        .padding(.horizontal, 8)
        .padding(.bottom, 14)
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
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
                if !isCollapsed {
                    Text(subMode.title)
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? 4 : 10)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(subMode.title)
    }

    private func navigationButton(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 28, height: 28)
                if !isCollapsed {
                    Text(title)
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? 4 : 10)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
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
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                if !isCollapsed {
                    Text(mode.title)
                        .font(.callout.weight(isSelected ? .semibold : .regular))
                }
            }
            .frame(maxWidth: .infinity, alignment: isCollapsed ? .center : .leading)
            .padding(.horizontal, isCollapsed ? 4 : 10)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(mode.title)
    }
}
