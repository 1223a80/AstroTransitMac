import Foundation
import SwiftUI

struct MidpointResultPane: View {
    let result: MidpointResult
    @Binding var selectedTab: String
    let onSendAxesToTiming: ([String]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            ResultPaneToolbar(
                selection: $selectedTab,
                tabs: tabs,
                moreTabs: moreTabs,
                currentTabTitle: tabTitle,
                markdownProvider: { MarkdownExportBuilder.midpoint(result) },
                jsonProvider: { TextExportBuilder.json(result) },
                csvProvider: { TextExportBuilder.csv(result) },
                basename: "midpoints"
            )
            selectedResultView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(TS.Padding.resultContent)
    }

    var tabs: [(String, String)] {
        [
            ("axes", "中点轴"),
            ("trees", "中点树"),
            ("activations", "激活"),
        ]
    }

    var moreTabs: [(String, String)] {
        [("diagnostics", "诊断"), ("json", "JSON")]
    }

    var tabTitle: String {
        resultTabTitle(selectedTab, in: tabs, moreTabs)
    }

    @ViewBuilder
    var selectedResultView: some View {
        switch selectedTab {
        case "axes":
            MidpointAxesView(axes: result.axes, onSendAxesToTiming: onSendAxesToTiming)
        case "trees":
            MidpointTreesView(
                trees: result.trees,
                onSendAxesToTiming: onSendAxesToTiming
            )
        case "activations":
            MidpointActivationsView(
                hits: result.snapshotActivations,
                onSendAxesToTiming: onSendAxesToTiming
            )
        case "diagnostics":
            MidpointDiagnosticsView(result: result)
        case "json":
            RawJSONView(value: result)
        default:
            MidpointAxesView(axes: result.axes, onSendAxesToTiming: onSendAxesToTiming)
        }
    }
}

struct MidpointAxesView: View {
    let axes: [MidpointAxis]
    let onSendAxesToTiming: ([String]) -> Void

    @State private var pointASearch = ""
    @State private var pointBSearch = ""
    @State private var sortAscending = true
    @State private var selectedAxisIDs = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack(spacing: TS.Spacing.md) {
                TextField("搜索 Point A", text: $pointASearch)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                TextField("搜索 Point B", text: $pointBSearch)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 180)
                Button {
                    sortAscending.toggle()
                } label: {
                    Label(
                        sortAscending ? "Midpoint 升序" : "Midpoint 降序",
                        systemImage: sortAscending ? "arrow.up" : "arrow.down"
                    )
                }
                .buttonStyle(.bordered)
                Spacer(minLength: 0)
                Text("\(filteredAxes.count) / \(axes.count)")
                    .font(TS.Font.monoSmall)
                    .foregroundStyle(.secondary)
                Button("全选筛选结果") {
                    selectedAxisIDs = Set(filteredAxes.map(\.id))
                }
                .disabled(filteredAxes.isEmpty)
                Button("清空") {
                    selectedAxisIDs.removeAll()
                }
                .disabled(selectedAxisIDs.isEmpty)
                Button("发送至综合时间线") {
                    onSendAxesToTiming(selectedAxisIDs.sorted())
                }
                .buttonStyle(.borderedProminent)
                .tint(TS.SemanticColor.gold)
                .disabled(selectedAxisIDs.isEmpty)
            }

            if filteredAxes.isEmpty {
                EmptyStateView(
                    title: axes.isEmpty ? "没有中点轴" : "没有匹配的中点轴",
                    systemImage: "circle.grid.cross",
                    description: axes.isEmpty ? "当前有效点集不足以生成中点轴。" : "请调整 Point A / Point B 搜索条件。"
                )
            } else {
                Table(filteredAxes, selection: $selectedAxisIDs) {
                    TableColumn("Point A") { axis in
                        midpointPointLabel(name: axis.pointAName, id: axis.pointAID)
                    }
                    TableColumn("Point B") { axis in
                        midpointPointLabel(name: axis.pointBName, id: axis.pointBID)
                    }
                    TableColumn("Direct") { axis in
                        midpointLongitudeLabel(text: axis.midpointText, longitude: axis.midpointLongitude)
                    }
                    TableColumn("Opposite") { axis in
                        midpointLongitudeLabel(text: axis.oppositeText, longitude: axis.oppositeLongitude)
                    }
                    TableColumn("Axis ID", value: \.id)
                }
                .tsTableStyle()
            }
        }
    }

    var filteredAxes: [MidpointAxis] {
        axes
            .filter { axis in
                matches(pointASearch, id: axis.pointAID, name: axis.pointAName)
                    && matches(pointBSearch, id: axis.pointBID, name: axis.pointBName)
            }
            .sorted { lhs, rhs in
                if lhs.midpointLongitude == rhs.midpointLongitude {
                    return lhs.id < rhs.id
                }
                return sortAscending
                    ? lhs.midpointLongitude < rhs.midpointLongitude
                    : lhs.midpointLongitude > rhs.midpointLongitude
            }
    }

    private func matches(_ query: String, id: String, name: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return id.localizedCaseInsensitiveContains(trimmed)
            || name.localizedCaseInsensitiveContains(trimmed)
    }

    private func midpointPointLabel(name: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.xs) {
            Text(name)
            Text(id)
                .font(TS.Font.monoSmall)
                .foregroundStyle(.secondary)
        }
    }

    private func midpointLongitudeLabel(text: String, longitude: Double) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.xs) {
            Text(text)
            Text(String(format: "%.6f°", longitude))
                .font(TS.Font.monoSmall)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

struct MidpointTreesView: View {
    let trees: [MidpointTree]
    let onSendAxesToTiming: ([String]) -> Void
    @State private var selectedFocusPointID: String

    init(trees: [MidpointTree], onSendAxesToTiming: @escaping ([String]) -> Void) {
        self.trees = trees
        self.onSendAxesToTiming = onSendAxesToTiming
        _selectedFocusPointID = State(initialValue: trees.first?.focusPointID ?? "")
    }

    var body: some View {
        if trees.isEmpty {
            EmptyStateView(
                title: "没有中点树",
                systemImage: "point.3.filled.connected.trianglepath.dotted",
                description: "请选择至少一个可用的 focus point 后重新计算。"
            )
        } else {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                HStack(spacing: TS.Spacing.md) {
                    Text("Focus")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                    Picker("Focus", selection: $selectedFocusPointID) {
                        ForEach(trees) { tree in
                            Text("\(tree.focusPointName) · \(tree.focusPointID)")
                                .tag(tree.focusPointID)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 260)
                    Spacer(minLength: 0)
                    Text("\(selectedTree?.hits.count ?? 0) hits")
                        .font(TS.Font.monoSmall)
                        .foregroundStyle(.secondary)
                    Button("扫描当前 Focus 命中轴") {
                        let axisIDs = Array(Set(selectedTree?.hits.map(\.axisID) ?? [])).sorted()
                        onSendAxesToTiming(axisIDs)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TS.SemanticColor.gold)
                    .disabled(selectedTree?.hits.isEmpty != false)
                }

                if let tree = selectedTree {
                    MidpointHitTable(
                        hits: tree.hits,
                        emptyTitle: "该 focus 没有中点命中",
                        emptyDescription: "当前 activation orb 内没有 natal 或动态激活。"
                    )
                }
            }
        }
    }

    private var selectedTree: MidpointTree? {
        trees.first(where: { $0.focusPointID == selectedFocusPointID }) ?? trees.first
    }
}

struct MidpointActivationsView: View {
    let hits: [MidpointHit]
    let onSendAxesToTiming: ([String]) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack {
                Text("单参考时点激活")
                    .font(TS.Font.sectionTitle)
                Spacer(minLength: 0)
                Button("在综合时间线扫描这些轴") {
                    onSendAxesToTiming(Array(Set(hits.map(\.axisID))).sorted())
                }
                .buttonStyle(.borderedProminent)
                .tint(TS.SemanticColor.gold)
                .disabled(hits.isEmpty)
            }
            MidpointHitTable(
                hits: hits,
                emptyTitle: "参考时点没有激活",
                emptyDescription: "未提供 reference 或当前 activation orb 内没有命中。"
            )
        }
    }
}

private struct MidpointHitTable: View {
    let hits: [MidpointHit]
    let emptyTitle: String
    let emptyDescription: String

    var body: some View {
        if hits.isEmpty {
            EmptyStateView(
                title: emptyTitle,
                systemImage: "scope",
                description: emptyDescription
            )
        } else {
            Table(hits) {
                TableColumn("Source") { hit in
                    VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                        Text(hit.sourcePointName)
                        Text(hit.sourcePointID)
                            .font(TS.Font.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                }
                TableColumn("来源") { hit in
                    Text(hit.sourceType)
                        .font(TS.Font.monoSmall)
                }
                TableColumn("Axis") { hit in
                    Text(hit.axisID)
                        .font(TS.Font.monoSmall)
                        .textSelection(.enabled)
                }
                TableColumn("Branch") { hit in
                    Text(hit.axisBranch)
                        .font(TS.Font.monoSmall)
                }
                TableColumn("Hit") { hit in
                    Text(String(format: "%.6f°", hit.hitLongitude))
                        .monospacedDigit()
                }
                TableColumn("Axis lon") { hit in
                    Text(String(format: "%.6f°", hit.axisLongitude))
                        .monospacedDigit()
                }
                TableColumn("Separation") { hit in
                    Text(String(format: "%.6f°", hit.separation))
                        .monospacedDigit()
                }
                TableColumn("Orb") { hit in
                    Text(String(format: "%.6f°", hit.orb))
                        .monospacedDigit()
                }
                TableColumn("Reference UTC") { hit in
                    Text(hit.referenceUTC ?? "—")
                        .font(TS.Font.monoSmall)
                        .monospacedDigit()
                        .textSelection(.enabled)
                }
            }
            .tsTableStyle()
        }
    }
}

struct MidpointDiagnosticsView: View {
    let result: MidpointResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.lg) {
                Text("计算元数据")
                    .font(TS.Font.sectionTitle)
                Grid(alignment: .leading, horizontalSpacing: TS.Spacing.xl, verticalSpacing: TS.Spacing.sm) {
                    GridRow { Text("Schema").foregroundStyle(.secondary); Text("\(result.meta.schemaVersion)") }
                    GridRow { Text("方法").foregroundStyle(.secondary); Text(result.meta.method) }
                    GridRow { Text("Modulus").foregroundStyle(.secondary); Text("\(result.meta.modulus)°") }
                    GridRow { Text("Activation orb").foregroundStyle(.secondary); Text(String(format: "%.6f°", result.meta.activationOrb)) }
                    GridRow { Text("Opposite axis").foregroundStyle(.secondary); Text(result.meta.includeOppositeAxis ? "是" : "否") }
                    GridRow { Text("Activation sources").foregroundStyle(.secondary); Text((result.meta.activationSources ?? []).joined(separator: ", ")) }
                    GridRow { Text("出生 UTC").foregroundStyle(.secondary); Text(result.meta.birthUTC) }
                    GridRow { Text("参考 UTC").foregroundStyle(.secondary); Text(result.meta.referenceUTC ?? "—") }
                    GridRow { Text("星历").foregroundStyle(.secondary); Text(result.meta.ephemeris) }
                    GridRow { Text("轴 / 树 / 激活").foregroundStyle(.secondary); Text("\(result.axes.count) / \(result.trees.count) / \(result.snapshotActivations.count)") }
                }
                .font(TS.Font.body)
                .textSelection(.enabled)
                ModernDiagnosticsView(warnings: result.warnings, sectionErrors: result.sectionErrors)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
