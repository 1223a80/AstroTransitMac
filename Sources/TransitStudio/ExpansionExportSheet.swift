import AppKit
import SwiftUI

/// Section multi-select export for a single expansion mode + optional merge of classical cache.
struct ExpansionExportSheet: View {
    let mode: ModernSubMode
    let currentData: ModernResultData?
    let classicalExpansionResults: [ModernSubMode: ModernResultData]
    let onDismiss: () -> Void

    @State private var selectedSections: Set<String>
    @State private var mergeEnabledModes: Set<ModernSubMode>
    @State private var mergeModeSections: [ModernSubMode: Set<String>]
    @State private var exportMerge: Bool = false

    init(
        mode: ModernSubMode,
        currentData: ModernResultData?,
        classicalExpansionResults: [ModernSubMode: ModernResultData],
        onDismiss: @escaping () -> Void
    ) {
        self.mode = mode
        self.currentData = currentData
        self.classicalExpansionResults = classicalExpansionResults
        self.onDismiss = onDismiss
        let all = ExpansionExportCatalog.allSectionIDs(for: mode)
        _selectedSections = State(initialValue: all)
        let cachedModes = Set(classicalExpansionResults.keys)
        _mergeEnabledModes = State(initialValue: cachedModes)
        var modeSecs: [ModernSubMode: Set<String>] = [:]
        for m in cachedModes {
            modeSecs[m] = ExpansionExportCatalog.allSectionIDs(for: m)
        }
        _mergeModeSections = State(initialValue: modeSecs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text(exportMerge ? "古典进阶合并导出" : "导出 Markdown 章节 · \(mode.title)")
                .font(TS.Font.sectionTitle)
                .padding(.top, 8)

            Picker("范围", selection: $exportMerge) {
                Text("当前模式").tag(false)
                Text("已计算的古典进阶合并").tag(true)
            }
            .pickerStyle(.segmented)
            .disabled(classicalExpansionResults.isEmpty && currentData?.classicalExpansionMode == nil)

            ScrollView {
                if exportMerge {
                    mergeTree
                } else {
                    currentModeSections
                }
            }

            HStack {
                Button("取消", action: onDismiss)
                Spacer()
                if !exportMerge {
                    Button("全选") { selectedSections = ExpansionExportCatalog.allSectionIDs(for: mode) }
                    Button("全不选") { selectedSections = [] }
                }
                Button("复制 Markdown") {
                    let md = buildMarkdown()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(md, forType: .string)
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(buildMarkdown().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(TS.Padding.sidebarContent)
        .frame(minWidth: 420, minHeight: 360)
    }

    private var currentModeSections: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
            ForEach(ExpansionExportCatalog.sections(for: mode)) { section in
                Toggle(isOn: Binding(
                    get: { selectedSections.contains(section.id) },
                    set: { on in
                        if on { selectedSections.insert(section.id) }
                        else { selectedSections.remove(section.id) }
                    }
                )) {
                    Text(section.title)
                }
                .toggleStyle(.checkbox)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var mergeTree: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            if classicalExpansionResults.isEmpty {
                Text("尚无已缓存的古典进阶结果。请先在古典轨运行进阶技法。")
                    .foregroundStyle(.secondary)
            }
            ForEach(ClassicalExpansionCatalog.modes.filter { classicalExpansionResults[$0] != nil }) { m in
                VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                    Toggle(isOn: Binding(
                        get: { mergeEnabledModes.contains(m) },
                        set: { on in
                            if on { mergeEnabledModes.insert(m) }
                            else { mergeEnabledModes.remove(m) }
                        }
                    )) {
                        Text(m.title).fontWeight(.semibold)
                    }
                    .toggleStyle(.checkbox)
                    if mergeEnabledModes.contains(m) {
                        ForEach(ExpansionExportCatalog.sections(for: m)) { section in
                            Toggle(isOn: Binding(
                                get: { mergeModeSections[m, default: []].contains(section.id) },
                                set: { on in
                                    var set = mergeModeSections[m, default: []]
                                    if on { set.insert(section.id) } else { set.remove(section.id) }
                                    mergeModeSections[m] = set
                                }
                            )) {
                                Text(section.title).font(TS.Font.label)
                            }
                            .toggleStyle(.checkbox)
                            .padding(.leading, TS.Spacing.xl)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func buildMarkdown() -> String {
        if exportMerge {
            var filtered: [ModernSubMode: ModernResultData] = [:]
            var sections: [ModernSubMode: Set<String>] = [:]
            for m in mergeEnabledModes {
                guard let data = classicalExpansionResults[m] else { continue }
                filtered[m] = data
                sections[m] = mergeModeSections[m] ?? ExpansionExportCatalog.allSectionIDs(for: m)
            }
            return ExpansionExportCatalog.mergeClassicalExpansionMarkdown(results: filtered, modeSections: sections)
        }
        guard let data = currentData ?? classicalExpansionResults[mode],
              let full = ExpansionExportCatalog.fullMarkdown(mode: mode, data: data) else {
            return ""
        }
        return ExpansionExportCatalog.filterMarkdown(full, mode: mode, selectedSectionIDs: selectedSections)
    }
}

/// Toolbar strip for classical-expansion result panes: section export + merge export.
struct ClassicalExpansionExportBar: View {
    let mode: ModernSubMode
    let hasCurrentResult: Bool
    let cachedCount: Int
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: TS.Spacing.md) {
            if hasCurrentResult || cachedCount > 0 {
                Button {
                    onExport()
                } label: {
                    Label(
                        cachedCount > 1 ? "导出章节 / 合并…" : "导出 Markdown 章节…",
                        systemImage: "doc.richtext"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            if cachedCount > 0 {
                Text("已缓存 \(cachedCount) 个进阶结果")
                    .font(TS.Font.label)
                    .foregroundStyle(TS.SemanticColor.inkFaint)
            }
            Spacer(minLength: 0)
        }
    }
}
