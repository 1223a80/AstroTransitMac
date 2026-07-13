import Foundation
import SwiftUI

struct ModernTimingResultPane: View {
    let result: ModernTimingResult
    @Binding var selectedTab: String
    @State private var techniqueFilter = ""
    @State private var eventTypeFilter = ""
    @State private var movingPointFilter = ""
    @State private var targetKindFilter = ""
    @State private var aspectFilter = ""
    @State private var clippedFilter = "all"

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { MarkdownExportBuilder.modernTiming(result) },
                jsonProvider: { TextExportBuilder.json(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "modern_timing"
            )
            filterBar
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [
            ("timeline", "时间线"),
            ("grouped", "分组"),
            ("calendar", "日历"),
        ]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String {
        resultTabTitle(selectedTab, in: tabs, moreTabs)
    }

    private var filteredEvents: [ModernTimingEvent] {
        result.events.filter { event in
            if !techniqueFilter.isEmpty, event.sourceType != techniqueFilter { return false }
            if !eventTypeFilter.isEmpty, event.eventType != eventTypeFilter { return false }
            if !movingPointFilter.isEmpty, event.movingPointID != movingPointFilter { return false }
            if !targetKindFilter.isEmpty, event.targetPointKind != targetKindFilter { return false }
            if !aspectFilter.isEmpty, event.aspectID != aspectFilter { return false }
            if clippedFilter == "clipped", !event.isWindowClipped { return false }
            if clippedFilter == "unclipped", event.isWindowClipped { return false }
            return true
        }
    }

    private var filteredResult: ModernTimingResult {
        ModernTimingResult(
            meta: result.meta,
            events: filteredEvents,
            warnings: result.warnings,
            sectionErrors: result.sectionErrors
        )
    }

    private var techniqueOptions: [String] {
        Array(Set(result.events.map(\.sourceType))).sorted()
    }

    private var eventTypeOptions: [String] {
        Array(Set(result.events.map(\.eventType))).sorted()
    }

    private var movingPointOptions: [String] {
        Array(Set(result.events.map(\.movingPointID))).sorted()
    }

    private var targetKindOptions: [String] {
        Array(Set(result.events.compactMap(\.targetPointKind))).sorted()
    }

    private var aspectOptions: [String] {
        Array(Set(result.events.compactMap(\.aspectID))).sorted()
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TS.Spacing.md) {
                    timingFilterPicker("技法", selection: $techniqueFilter, options: techniqueOptions)
                    timingFilterPicker("事件", selection: $eventTypeFilter, options: eventTypeOptions)
                    timingFilterPicker("移动点", selection: $movingPointFilter, options: movingPointOptions)
                    timingFilterPicker("目标类型", selection: $targetKindFilter, options: targetKindOptions)
                    timingFilterPicker("相位", selection: $aspectFilter, options: aspectOptions)
                    Picker("截断", selection: $clippedFilter) {
                        Text("全部截断状态").tag("all")
                        Text("仅截断").tag("clipped")
                        Text("未截断").tag("unclipped")
                    }
                    .labelsHidden()
                    Text("\(filteredEvents.count) / \(result.events.count)")
                        .font(TS.Font.monoSmall)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("筛选只影响当前视图；Markdown / CSV / JSON 默认导出完整结果。")
                .font(TS.Font.label)
                .foregroundStyle(.secondary)
        }
    }

    private func timingFilterPicker(
        _ title: String,
        selection: Binding<String>,
        options: [String]
    ) -> some View {
        Picker(title, selection: selection) {
            Text("全部\(title)").tag("")
            ForEach(options, id: \.self) { option in
                Text(option).tag(option)
            }
        }
        .labelsHidden()
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "timeline":
            ModernTimingTimelineView(result: filteredResult)
        case "grouped":
            ModernTimingGroupedView(result: filteredResult)
        case "calendar":
            ModernTimingCalendarView(result: filteredResult)
        case "diagnostics":
            ModernTimingDiagnosticsView(result: result)
        case "json":
            RawJSONView(value: result)
        default:
            ModernTimingTimelineView(result: result)
        }
    }
}

struct ModernTimingTimelineView: View {
    let result: ModernTimingResult

    private var events: [ModernTimingEvent] {
        result.events.sorted { $0.exactUTC < $1.exactUTC }
    }

    var body: some View {
        if events.isEmpty {
            EmptyStateView(
                title: "窗口内没有命中事件",
                systemImage: "calendar.badge.checkmark",
                description: "这是合法空结果；可调整时间窗口、技法、目标点或相位配置。"
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: TS.Spacing.md) {
                    Text("\(events.count) 个事件 · \(result.meta.startUTC) — \(result.meta.endUTC)")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    ForEach(events) { event in
                        ModernTimingEventCard(event: event)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ModernTimingGroupedView: View {
    let result: ModernTimingResult

    private var groups: [ModernTimingEventGroup] {
        Dictionary(grouping: result.events, by: \.groupID)
            .map { ModernTimingEventGroup(id: $0.key, events: $0.value.sorted { $0.exactUTC < $1.exactUTC }) }
            .sorted { ($0.events.first?.exactUTC ?? "") < ($1.events.first?.exactUTC ?? "") }
    }

    var body: some View {
        if groups.isEmpty {
            EmptyStateView(title: "没有可分组事件", systemImage: "rectangle.3.group")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: TS.Spacing.lg) {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: TS.Spacing.md) {
                            if let first = group.events.first {
                                Text(ModernTimingLabels.summary(first))
                                    .font(TS.Font.sectionTitle)
                                Text(group.id)
                                    .font(TS.Font.monoSmall)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            ForEach(group.events) { event in
                                ModernTimingEventCard(event: event, compact: true)
                            }
                        }
                        .padding(TS.Padding.cardInner)
                        .background(
                            TS.SemanticColor.cardBackground,
                            in: RoundedRectangle(cornerRadius: TS.Radius.card)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: TS.Radius.card)
                                .strokeBorder(TS.SemanticColor.line, lineWidth: 1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ModernTimingCalendarView: View {
    let result: ModernTimingResult

    private var months: [ModernTimingMonthGroup] {
        Dictionary(grouping: result.events) { String($0.exactLocal.prefix(7)) }
            .map { month, events in
                let weeks = Dictionary(grouping: events) {
                    Self.weekKey(
                        for: $0.exactLocal,
                        timeZoneIdentifier: result.meta.displayTimezone
                    )
                }
                    .map { ModernTimingWeekGroup(id: $0.key, events: $0.value.sorted { $0.exactUTC < $1.exactUTC }) }
                    .sorted { $0.id < $1.id }
                return ModernTimingMonthGroup(id: month, weeks: weeks)
            }
            .sorted { $0.id < $1.id }
    }

    static func weekKey(for exactLocal: String, timeZoneIdentifier: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: exactLocal) else {
            return String(exactLocal.prefix(10))
        }
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let year = components.yearForWeekOfYear, let week = components.weekOfYear else {
            return String(exactLocal.prefix(10))
        }
        return String(format: "%04d-W%02d", year, week)
    }

    var body: some View {
        if months.isEmpty {
            EmptyStateView(title: "日历中没有事件", systemImage: "calendar")
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: TS.Spacing.xl) {
                    ForEach(months) { month in
                        VStack(alignment: .leading, spacing: TS.Spacing.md) {
                            Text(month.id)
                                .font(TS.Font.pageTitle)
                            ForEach(month.weeks) { week in
                                VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                                    Text(week.id)
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                    ForEach(week.events) { event in
                                        HStack(alignment: .firstTextBaseline, spacing: TS.Spacing.lg) {
                                            Text(ModernTimingLabels.localDateTime(event.exactLocal))
                                                .font(TS.Font.monoSmall)
                                                .monospacedDigit()
                                            Text(ModernTimingLabels.summary(event))
                                                .font(TS.Font.body)
                                            Spacer(minLength: 0)
                                            Text("\(event.passIndexInWindow)/\(event.passCountInWindow)")
                                                .font(TS.Font.monoSmall)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(TS.Padding.cardInner)
                                .background(
                                    TS.SemanticColor.cardBackground,
                                    in: RoundedRectangle(cornerRadius: TS.Radius.card)
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ModernTimingDiagnosticsView: View {
    let result: ModernTimingResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                Text("计算元数据").font(TS.Font.sectionTitle)
                Grid(alignment: .leading, horizontalSpacing: TS.Spacing.xl, verticalSpacing: TS.Spacing.sm) {
                    GridRow { Text("Schema").foregroundStyle(.secondary); Text("\(result.meta.schemaVersion)") }
                    GridRow { Text("技法").foregroundStyle(.secondary); Text(result.meta.techniqueIDs.joined(separator: ", ")) }
                    GridRow { Text("目标数").foregroundStyle(.secondary); Text("\(result.meta.targetCount)") }
                    GridRow { Text("工作量").foregroundStyle(.secondary); Text("\(result.meta.estimatedWorkUnits)") }
                    GridRow { Text("显示时区").foregroundStyle(.secondary); Text(result.meta.displayTimezone) }
                    GridRow { Text("星历").foregroundStyle(.secondary); Text(result.meta.ephemeris) }
                }
                ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ModernTimingEventCard: View {
    let event: ModernTimingEvent
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: TS.Spacing.md) {
                Text(ModernTimingLabels.source(event.sourceType))
                    .font(TS.Font.eyebrow)
                    .foregroundStyle(TS.SemanticColor.goldDeep)
                Text(ModernTimingLabels.summary(event))
                    .font(TS.Font.sectionTitle)
                Spacer(minLength: 0)
                Text("\(event.passIndexInWindow)/\(event.passCountInWindow)")
                    .font(TS.Font.monoSmall)
                    .foregroundStyle(.secondary)
            }
            Text(event.exactLocal)
                .font(TS.Font.mono)
                .monospacedDigit()
                .textSelection(.enabled)
            if !compact {
                Grid(alignment: .leading, horizontalSpacing: TS.Spacing.xl, verticalSpacing: TS.Spacing.xs) {
                    GridRow { Text("进入").foregroundStyle(.secondary); Text(lifecycleValue(event.enteringUTC, clipped: event.windowClippedStart)) }
                    GridRow { Text("精确").foregroundStyle(.secondary); Text(event.exactUTC) }
                    GridRow { Text("离开").foregroundStyle(.secondary); Text(lifecycleValue(event.leavingUTC, clipped: event.windowClippedEnd)) }
                    GridRow { Text("运动").foregroundStyle(.secondary); Text(event.motion) }
                    GridRow { Text("方法").foregroundStyle(.secondary); Text(event.methodKey) }
                }
                .font(TS.Font.monoSmall)
                .textSelection(.enabled)
            }
            if event.isWindowClipped {
                Label("生命周期被查询边界截断", systemImage: "scissors")
                    .font(TS.Font.label)
                    .foregroundStyle(TS.SemanticColor.warning)
            }
        }
        .padding(TS.Padding.cardInner)
        .background(TS.SemanticColor.cardBackground, in: RoundedRectangle(cornerRadius: TS.Radius.card))
        .overlay {
            RoundedRectangle(cornerRadius: TS.Radius.card)
                .strokeBorder(TS.SemanticColor.line, lineWidth: 1)
        }
    }

    private func lifecycleValue(_ value: String?, clipped: Bool) -> String {
        value ?? (clipped ? "窗口外（截断）" : "—")
    }
}

private struct ModernTimingEventGroup: Identifiable {
    let id: String
    let events: [ModernTimingEvent]
}

private struct ModernTimingMonthGroup: Identifiable {
    let id: String
    let weeks: [ModernTimingWeekGroup]
}

private struct ModernTimingWeekGroup: Identifiable {
    let id: String
    let events: [ModernTimingEvent]
}

private enum ModernTimingLabels {
    static func source(_ sourceType: String) -> String {
        switch sourceType {
        case "transit": return "行运"
        case "secondary_progression": return "次限推进"
        case "solar_arc": return "太阳弧"
        default: return sourceType
        }
    }

    static func summary(_ event: ModernTimingEvent) -> String {
        var parts = [event.movingPointName]
        if let aspect = event.aspectName ?? event.aspectID {
            parts.append(aspect)
        } else {
            parts.append(eventType(event.eventType))
        }
        if let target = event.targetPointName ?? event.targetPointID {
            parts.append(target)
        }
        return parts.joined(separator: " ")
    }

    static func eventType(_ eventType: String) -> String {
        switch eventType {
        case "aspect": return "相位"
        case "ingress": return "入座"
        case "station": return "留"
        case "moon_ingress": return "推进月亮入座"
        case "lunation": return "推进月相"
        default: return eventType
        }
    }

    static func localDateTime(_ exactLocal: String) -> String {
        guard exactLocal.count >= 16 else { return exactLocal }
        return String(exactLocal.prefix(16)).replacingOccurrences(of: "T", with: " ")
    }
}
