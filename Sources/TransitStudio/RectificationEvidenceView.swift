import Foundation
import SwiftUI

struct RectificationEvidenceWorkspace: View {
    let candidateTime: String
    let absoluteOffsetSeconds: Int
    let timeZone: TimeZone
    @Binding var response: RectificationEvidenceResponse?
    @Binding var isRunning: Bool
    @Binding var progress: Double
    @Binding var progressText: String
    let onCompute: ([RectificationEvidenceSourceEvent], Int) -> Void

    @State private var drafts: [RectificationEventDraft] = []

    private var timezoneText: String {
        GMTOffset.label(hours: Double(timeZone.secondsFromGMT()) / 3600.0)
    }

    private var validationMessage: String? {
        RectificationEventDraft.validationMessage(for: drafts)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                scopeCard
                eventsEditor
                runControls

                if let response {
                    RectificationEvidenceResults(response: response, displayTimeZone: timeZone)
                }
            }
            .padding(14)
        }
    }

    private var scopeCard: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            Text("当前候选的事件证据")
                .font(.headline)
            Text("候选时刻：\(candidateTime)（相对原始中心 \(signedSeconds(absoluteOffsetSeconds))）")
                .font(.caption.monospacedDigit())
            Text("本次请求只计算当前滑杆候选。主运动、行运、次限和太阳弧保持独立；命中数不是评分，也不会自动推荐出生时间。")
                .font(TS.Font.label)
                .foregroundStyle(.secondary)
            Text("方法边界：主运动仅为行星至四轴的正式几何子集；次限与 true solar arc 共享 day-for-year 太阳锚点，并非完全独立。")
                .font(TS.Font.detail)
                .foregroundStyle(.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
    }

    private var eventsEditor: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack {
                Text("人生事件窗口")
                    .font(.headline)
                Text("\(drafts.count)/20")
                    .font(TS.Font.detail)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    guard drafts.count < 20 else { return }
                    drafts.append(RectificationEventDraft.makeDefault(index: drafts.count + 1, timeZone: timeZone))
                    response = nil
                } label: {
                    Label("添加事件", systemImage: "plus")
                }
                .disabled(drafts.count >= 20 || isRunning)
            }

            if drafts.isEmpty {
                Text("请添加至少一个有明确起止时间和来源质量的事件窗口。后端不会替你猜测 ± 天数。")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }

            ForEach($drafts) { $draft in
                RectificationEventEditor(
                    draft: $draft,
                    timeZone: timeZone,
                    onDelete: {
                        drafts.removeAll { $0.id == draft.id }
                        response = nil
                    },
                    onChange: { response = nil }
                )
                .disabled(isRunning)
            }
        }
    }

    private var runControls: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            HStack {
                Button {
                    let events = drafts.map { $0.sourceEvent(timezone: timezoneText, timeZone: timeZone) }
                    onCompute(events, absoluteOffsetSeconds)
                } label: {
                    Label(isRunning ? "正在计算" : "计算当前候选证据", systemImage: "list.bullet.clipboard")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning || validationMessage != nil)

                if isRunning {
                    ProgressView(value: progress)
                        .frame(maxWidth: 220)
                    Text(progressText.isEmpty ? "正在计算事件证据" : progressText)
                        .font(TS.Font.detail)
                        .foregroundStyle(.secondary)
                }
            }
            if let validationMessage {
                Text(validationMessage)
                    .font(TS.Font.detail)
                    .foregroundStyle(.red)
            }
        }
    }

    private func signedSeconds(_ value: Int) -> String {
        "\(value >= 0 ? "+" : "")\(value)s"
    }
}

struct RectificationEventDraft: Identifiable, Equatable {
    let id: UUID
    var eventID: String
    var category: String
    var description: String
    var sourceQuality: String
    var confidence: Double
    var holdout: Bool
    var start: Date
    var end: Date

    static let sourceQualities = [
        ("documented_exact", "精确记录"),
        ("documented_day", "日期记录"),
        ("remembered_day", "记得日期"),
        ("remembered_period", "记得时期"),
        ("approximate", "大致时间"),
    ]

    static func makeDefault(index: Int, timeZone: TimeZone, now: Date = Date()) -> Self {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: now)
        return Self(
            id: UUID(),
            eventID: "event-\(index)",
            category: "unspecified",
            description: "",
            sourceQuality: "approximate",
            confidence: 1,
            holdout: false,
            start: start,
            end: calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        )
    }

    static func validationMessage(for drafts: [Self]) -> String? {
        guard !drafts.isEmpty else { return "至少需要一个事件窗口。" }
        let ids = drafts.map { $0.eventID.trimmingCharacters(in: .whitespacesAndNewlines) }
        if ids.contains(where: \.isEmpty) { return "每个事件都需要非空 ID。" }
        if Set(ids).count != ids.count { return "事件 ID 不能重复。" }
        if drafts.contains(where: { $0.end <= $0.start }) { return "每个事件的结束时间必须晚于开始时间。" }
        if drafts.contains(where: { !(0...1).contains($0.confidence) }) { return "事件置信度必须在 0 到 1 之间。" }
        return nil
    }

    func sourceEvent(timezone: String, timeZone: TimeZone) -> RectificationEvidenceSourceEvent {
        RectificationEvidenceSourceEvent(
            id: eventID.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "unspecified" : category,
            description: description,
            sourceQuality: sourceQuality,
            confidence: confidence,
            holdout: holdout,
            start: Self.moment(from: start, timezone: timezone, timeZone: timeZone),
            end: Self.moment(from: end, timezone: timezone, timeZone: timeZone)
        )
    }

    private static func moment(from date: Date, timezone: String, timeZone: TimeZone) -> ChartMoment {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return ChartMoment(
            year: parts.year ?? 2000,
            month: parts.month ?? 1,
            day: parts.day ?? 1,
            hour: parts.hour ?? 0,
            minute: parts.minute ?? 0,
            timezone: timezone,
            second: parts.second ?? 0
        )
    }
}

private struct RectificationEventEditor: View {
    @Binding var draft: RectificationEventDraft
    let timeZone: TimeZone
    let onDelete: () -> Void
    let onChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack {
                TextField("事件 ID", text: $draft.eventID)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                TextField("类别（如 career）", text: $draft.category)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                Picker("来源", selection: $draft.sourceQuality) {
                    ForEach(RectificationEventDraft.sourceQualities, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .frame(maxWidth: 150)
                Toggle("Holdout", isOn: $draft.holdout)
                    .toggleStyle(.checkbox)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            TextField("事件说明", text: $draft.description)
                .textFieldStyle(.roundedBorder)
            HStack {
                Text("开始")
                    .font(TS.Font.label)
                    .frame(width: 36, alignment: .trailing)
                DateTimeInput(date: $draft.start, timeZone: timeZone, showsSeconds: true)
                Text("结束")
                    .font(TS.Font.label)
                    .frame(width: 36, alignment: .trailing)
                DateTimeInput(date: $draft.end, timeZone: timeZone, showsSeconds: true)
            }
            HStack {
                Text("资料置信度")
                    .font(TS.Font.label)
                Slider(value: $draft.confidence, in: 0...1, step: 0.05)
                    .frame(maxWidth: 220)
                Text(String(format: "%.2f", draft.confidence))
                    .font(.caption.monospacedDigit())
                Text("仅记录资料质量，不参与后端评分")
                    .font(TS.Font.detail)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
        .onChange(of: draft) { _ in onChange() }
    }
}

private struct RectificationEvidenceResults: View {
    let response: RectificationEvidenceResponse
    let displayTimeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            HStack {
                Text("证据包结果")
                    .font(.title3.weight(.semibold))
                Text(response.schema.schemaID)
                    .font(TS.Font.detail.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("不自动选时")
                    .font(TS.Font.detail)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(Capsule())
            }

            if !response.warnings.isEmpty {
                EvidenceWarningBox(title: "全局警告", warnings: response.warnings)
            }

            ForEach(response.candidates) { candidate in
                candidateSection(candidate)
            }

            methodBoundaries
        }
    }

    private func candidateSection(_ candidate: RectificationEvidenceResponse.Candidate) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text("候选 · \(candidate.birthLocal)")
                .font(.headline.monospacedDigit())
            Text("包内偏移 \(candidate.offsetSeconds)s · 宫制 \(candidate.houseSystem) · 四轴输出保留 9 位小数（不代表验证精度） · 当前请求候选窗口 0 秒")
                .font(TS.Font.detail)
                .foregroundStyle(.secondary)

            if !candidate.warnings.isEmpty {
                EvidenceWarningBox(title: "候选警告（含绕极诊断）", warnings: candidate.warnings)
            }

            ForEach(candidate.evidenceByEvent) { event in
                eventSection(event)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
    }

    private func eventSection(_ event: RectificationEvidenceResponse.EventEvidence) -> some View {
        let source = response.events.first { $0.id == event.eventID }
        return VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack {
                Text(event.eventID)
                    .font(.headline)
                Text(event.eventCategory)
                    .font(TS.Font.detail)
                    .foregroundStyle(.secondary)
                if event.holdout {
                    Text("Holdout")
                        .font(TS.Font.detail)
                        .foregroundStyle(.purple)
                }
                Spacer()
                if let source {
                    Text("\(source.sourceQuality) · confidence \(source.confidence, specifier: "%.2f")")
                        .font(TS.Font.detail)
                        .foregroundStyle(.secondary)
                }
            }

            if let source {
                Text("窗口：\(momentText(source.start)) → \(momentText(source.end))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            PrimaryMotionEvidenceCard(family: event.primaryMotion)
            TimingEvidenceCard(title: "行运", family: event.families.transit, displayTimeZone: displayTimeZone)
            TimingEvidenceCard(title: "次限", family: event.families.secondaryProgression, displayTimeZone: displayTimeZone)
            TimingEvidenceCard(title: "太阳弧", family: event.families.solarArc, displayTimeZone: displayTimeZone)

            if let errors = event.sectionErrors, errors.displayText != "null" {
                Text("方法错误：\(errors.displayText)")
                    .font(TS.Font.detail)
                    .foregroundStyle(.red)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
    }

    private var methodBoundaries: some View {
        DisclosureGroup("方法与独立性边界") {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                ForEach(response.methodProfiles) { profile in
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(familyTitle(profile.family)) · \(profile.status)")
                            .font(.subheadline.weight(.semibold))
                        Text("独立性组：\(profile.independenceGroup) · 角色：\(profile.role)")
                            .font(TS.Font.detail)
                        if let note = profile.note { Text(note).font(TS.Font.detail).foregroundStyle(.secondary) }
                        if let excluded = profile.excludes, !excluded.isEmpty {
                            Text("不包含：\(excluded.joined(separator: "；"))")
                                .font(TS.Font.detail)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                ForEach(response.calculationAssumptions, id: \.self) { assumption in
                    Text("• \(assumption)")
                        .font(TS.Font.detail)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 8)
        }
    }

    private func familyTitle(_ family: String) -> String {
        switch family {
        case "primary_motion": return "主运动"
        case "transit": return "行运"
        case "secondary_progression": return "次限"
        case "solar_arc": return "太阳弧"
        default: return family
        }
    }

    private func momentText(_ moment: ChartMoment) -> String {
        String(format: "%04d-%02d-%02d %02d:%02d:%02d %@", moment.year, moment.month, moment.day, moment.hour, moment.minute, moment.second ?? 0, moment.timezone)
    }
}

private struct PrimaryMotionEvidenceCard: View {
    let family: RectificationEvidenceResponse.PrimaryMotionFamily

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            EvidenceFamilyHeader(
                title: "主运动",
                countText: "窗口命中 \(family.windowHitCount)",
                independenceGroup: family.independenceGroup,
                truncated: family.truncated
            )
            if family.evidence.isEmpty {
                Text("无可显示证据。")
                    .font(TS.Font.detail)
                    .foregroundStyle(.secondary)
            }
            ForEach(family.evidence) { row in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("\(row.promissor) → \(row.significatorID) · \(row.directionType)")
                            .font(.subheadline.weight(.medium))
                        if row.insideEventWindow {
                            Text("窗口内")
                                .font(TS.Font.detail)
                                .foregroundStyle(.green)
                        }
                    }
                    Text("精确时刻 \(row.eventDateTimeAfterBirth) · 距窗口 \(row.distanceToEventWindowDays, specifier: "%.6f") 天")
                        .font(.caption.monospacedDigit())
                    Text("弧 \(row.arcSigned, specifier: "%.9f")° · 年龄 \(row.ageYears, specifier: "%.9f") · key \(row.keyProfile) \(row.keyRateDegreesPerYear, specifier: "%.8f")°/年")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("几何：RA \(format(row.geometry.rightAscension)) · Dec \(format(row.geometry.declination)) · AD \(format(row.geometry.ascensionalDifference)) · \(row.geometry.coordinate ?? "—")")
                        .font(TS.Font.detail)
                        .foregroundStyle(.secondary)
                    if !row.completePrimaryDirectionsSuite {
                        Text("仅行星→四轴几何子集，不是完整 Placidus/Regiomontanus 主限。")
                            .font(TS.Font.detail)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .evidenceFamilyCard()
    }

    private func format(_ value: Double?) -> String {
        value.map { String(format: "%.9f°", $0) } ?? "绕极/不适用"
    }
}

private struct TimingEvidenceCard: View {
    let title: String
    let family: RectificationEvidenceResponse.TimingFamily
    let displayTimeZone: TimeZone

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            EvidenceFamilyHeader(
                title: title,
                countText: "精确命中 \(family.exactHitCount)",
                independenceGroup: family.independenceGroup,
                truncated: family.truncated
            )
            if family.evidence.isEmpty {
                Text("事件窗口内无 exact root。")
                    .font(TS.Font.detail)
                    .foregroundStyle(.secondary)
            }
            ForEach(family.evidence) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(row.movingPointName ?? row.movingPointID ?? "—") \(row.aspectName ?? row.aspectID ?? "相位") \(row.targetPointName ?? row.targetPointID ?? "—")")
                        .font(.subheadline.weight(.medium))
                    Text("精确时刻 \(localizedISO(row.exactUTC)) · 距窗口中点 \(row.distanceToEventMidpointDays, specifier: "%.6f") 天")
                        .font(.caption.monospacedDigit())
                    Text("motion \(row.motion ?? "—") · exact orb \(number(row.exactOrb))° / limit \(number(row.orbLimit))° · pass \(row.passIndexInWindow ?? 0)/\(row.passCountInWindow ?? 0)")
                        .font(TS.Font.detail)
                        .foregroundStyle(.secondary)
                    HStack {
                        if row.isWindowClipped {
                            Text("搜索窗口截断")
                                .font(TS.Font.detail)
                                .foregroundStyle(.orange)
                        }
                        Text(row.methodKey ?? "方法键未提供")
                            .font(TS.Font.detail.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .evidenceFamilyCard()
    }

    private func localizedISO(_ value: String) -> String {
        let parsers = [
            ISO8601DateFormatter.withFractionalSeconds,
            ISO8601DateFormatter.standard,
        ]
        guard let date = parsers.lazy.compactMap({ $0.date(from: value) }).first else { return value }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = displayTimeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    private func number(_ value: Double?) -> String {
        value.map { String(format: "%.6f", $0) } ?? "—"
    }
}

private struct EvidenceFamilyHeader: View {
    let title: String
    let countText: String
    let independenceGroup: String
    let truncated: Bool

    var body: some View {
        HStack {
            Text(title).font(.headline)
            Text(countText).font(TS.Font.label)
            Text("非评分").font(TS.Font.detail).foregroundStyle(.secondary)
            Spacer()
            Text(independenceGroup).font(TS.Font.detail.monospaced()).foregroundStyle(.secondary)
            if truncated {
                Text("显示已截断").font(TS.Font.detail).foregroundStyle(.orange)
            }
        }
    }
}

private struct EvidenceWarningBox: View {
    let title: String
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
            ForEach(warnings, id: \.self) { Text("• \($0)").font(TS.Font.detail) }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.chip))
    }
}

private extension View {
    func evidenceFamilyCard() -> some View {
        padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
    }
}

private extension RectificationJSONValue {
    var displayText: String {
        switch self {
        case .object(let value): return value.map { "\($0.key): \($0.value.displayText)" }.sorted().joined(separator: "；")
        case .array(let value): return value.map(\.displayText).joined(separator: "；")
        case .string(let value): return value
        case .number(let value): return String(value)
        case .bool(let value): return value ? "true" : "false"
        case .null: return "null"
        }
    }
}

private extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
