import SwiftUI

extension ContentView {

    var appTopBar: some View {
        HStack(spacing: TS.Spacing.xl) {
            // 1. Brand block (compact)
            HStack(spacing: TS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(TS.SemanticColor.goldSoft)
                    Circle()
                        .strokeBorder(TS.SemanticColor.gold, lineWidth: 1.5)
                    Image(systemName: "sun.max")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TS.SemanticColor.goldDeep)
                }
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Transit")
                        .font(.system(.caption, design: .serif).weight(.semibold))
                        .foregroundStyle(TS.SemanticColor.ink)
                    Text("STUDIO")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(TS.SemanticColor.inkFaint)
                }
            }

            // 2. Profile capsule Menu
            Menu {
                ForEach(natalProfiles) { profile in
                    Button {
                        selectedNatalProfileID = profile.id.uuidString
                        loadSelectedNatalProfile()
                    } label: {
                        HStack {
                            Text(profile.name)
                            if profile.id.uuidString == selectedNatalProfileID {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                Divider()
                Button("管理档案…") {
                    isShowingAppSettingsPage = false
                    mode = .settings
                    if practiceMode == .modern {
                        modernSubMode = .natal
                    }
                }
            } label: {
                HStack(spacing: TS.Spacing.sm) {
                    if let profile = natalProfiles.first(where: { $0.id.uuidString == selectedNatalProfileID }) {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(TS.SemanticColor.gold)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(profile.name)
                                .font(.system(.caption, design: .serif).weight(.semibold))
                                .foregroundStyle(TS.SemanticColor.ink)
                            Text(capsuleProfileSummary(for: profile))
                                .font(TS.Font.monoSmall)
                                .foregroundStyle(TS.SemanticColor.inkSoft)
                        }
                    } else {
                        Text("未保存档案")
                            .font(TS.Font.label)
                            .foregroundStyle(TS.SemanticColor.inkFaint)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(TS.SemanticColor.inkFaint)
                }
                .padding(.horizontal, TS.Spacing.md)
                .padding(.vertical, TS.Spacing.sm)
                .background(TS.SemanticColor.card, in: RoundedRectangle(cornerRadius: TS.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: TS.Radius.card)
                        .strokeBorder(TS.SemanticColor.line, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            // 3. Practice mode segmented control
            HStack(spacing: 2) {
                practiceTopSegment(.classical)
                practiceTopSegment(.modern)
                practiceTopSegment(.vedic)
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: TS.Radius.card)
                    .fill(TS.SemanticColor.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: TS.Radius.card)
                            .strokeBorder(TS.SemanticColor.line, lineWidth: 1)
                    )
            )

            // 4. Run button
            Button {
                Task { await runCurrentMode() }
            } label: {
                HStack(spacing: TS.Spacing.md) {
                    if calcVM.isRunning {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    Text(calcVM.isRunning ? "计算中" : runButtonTitle)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(runDisabled || isShowingAppSettingsPage)
        }
        .padding(.horizontal, TS.Padding.sidebarContent)
        .frame(height: TS.Layout.topBarHeight)
        .background(TS.SemanticColor.paperRaised)
    }

    private func practiceTopSegment(_ mode: PracticeMode) -> some View {
        let isSelected = practiceMode == mode
        return Button {
            practiceModeBinding.wrappedValue = mode
        } label: {
            Text(mode.title)
                .font(.system(.caption, design: .serif).weight(isSelected ? .semibold : .regular))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .padding(.horizontal, TS.Spacing.md)
                .foregroundStyle(isSelected ? TS.SemanticColor.paper : TS.SemanticColor.inkSoft)
                .background(
                    RoundedRectangle(cornerRadius: TS.Radius.chip)
                        .fill(isSelected ? TS.SemanticColor.ink : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private func capsuleProfileSummary(for profile: NatalProfile) -> String {
        // Build "YYYY-MM-DD HH:mm UTC±N · latitude, longitude"
        let dateF = DateFormatter()
        dateF.dateFormat = "yyyy-MM-dd"
        dateF.timeZone = selectedTimeZone

        let timeF = DateFormatter()
        timeF.dateFormat = "HH:mm"
        timeF.timeZone = selectedTimeZone

        let datePart = dateF.string(from: natalDate)
        let timePart = timeF.string(from: natalDate)
        return "\(datePart) \(timePart) \(timezoneLabel) · \(birthLatitude), \(birthLongitude)"
    }
}
