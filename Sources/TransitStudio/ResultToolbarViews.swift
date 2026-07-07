import SwiftUI

// MARK: - Export Menu
struct ExportMenu: View {
    let markdownProvider: () -> String
    let jsonProvider: () -> String
    let csvProvider: () -> String
    var basename = "astro_export"

    var body: some View {
        Menu {
            CopyMarkdownButton(title: "复制 JSON", textProvider: jsonProvider)
            CopyMarkdownButton(title: "复制 CSV", textProvider: csvProvider)
            Divider()
            SaveTextButton(title: "保存 JSON", defaultFilename: "\(basename).json", textProvider: jsonProvider)
            SaveTextButton(title: "保存 CSV", defaultFilename: "\(basename).csv", textProvider: csvProvider)
        } label: {
            Label("导出", systemImage: "square.and.arrow.up")
        }
    }
}

// MARK: - Underline tab
struct TabChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(title)
                    .font(TS.Font.serifTab.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? TS.SemanticColor.ink : TS.SemanticColor.inkFaint)
                Rectangle()
                    .fill(isSelected ? TS.SemanticColor.gold : Color.clear)
                    .frame(height: 2)
            }
            .padding(.horizontal, TS.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Resolves the toolbar title for the selected tab from the same tab lists
/// that feed the toolbar, so the title can never drift from the definitions.
func resultTabTitle(_ selection: String, in groups: [(id: String, title: String)]...) -> String {
    for group in groups {
        if let match = group.first(where: { $0.id == selection }) {
            return match.title
        }
    }
    return ""
}

// MARK: - Vertical Section Nav (TOC-style section list for dense panes)
struct VerticalSectionNav: View {
    @Binding var selection: String
    let sections: [(id: String, title: String)]
    var secondarySections: [(id: String, title: String)] = []

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                ForEach(sections, id: \.id) { section in
                    navItem(section)
                }
                if !secondarySections.isEmpty {
                    Rectangle()
                        .fill(TS.SemanticColor.line)
                        .frame(height: 1)
                        .padding(.vertical, TS.Spacing.sm)
                        .padding(.horizontal, TS.Spacing.sm)
                    ForEach(secondarySections, id: \.id) { section in
                        navItem(section)
                    }
                }
            }
        }
        .frame(width: 116, alignment: .topLeading)
    }

    private func navItem(_ section: (id: String, title: String)) -> some View {
        let isSelected = selection == section.id
        return Button {
            selection = section.id
        } label: {
            Text(section.title)
                .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? TS.SemanticColor.goldDeep : TS.SemanticColor.inkSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, TS.Spacing.md)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: TS.Radius.chip)
                        .fill(isSelected ? TS.SemanticColor.goldSoft : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Result Pane Toolbar (single-line scrollable tabs + export row)
struct ResultPaneToolbar: View {
    @Binding var selection: String
    let tabs: [(id: String, title: String)]
    let moreTabs: [(id: String, title: String)]
    let currentTabTitle: String
    let markdownProvider: () -> String
    let jsonProvider: () -> String
    let csvProvider: () -> String
    var basename = "astro_export"
    var classicalSectionPicker: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: TS.Spacing.md) {
            // Single-line scrollable underline tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.id) { tab in
                        TabChip(
                            title: tab.title,
                            isSelected: selection == tab.id,
                            action: { selection = tab.id }
                        )
                    }

                    if !moreTabs.isEmpty {
                        moreMenu
                    }
                }
            }

            Spacer(minLength: TS.Spacing.md)

            // Export actions
            if let classicalSectionPicker {
                Button("导出 Markdown…") { classicalSectionPicker() }
                    .font(TS.Font.label)
                    .buttonStyle(.borderedProminent)
                    .tint(TS.SemanticColor.gold)
                    .controlSize(.small)
            } else {
                CopyMarkdownButton(title: "复制 Markdown", textProvider: markdownProvider)
            }
            ExportMenu(
                markdownProvider: markdownProvider,
                jsonProvider: jsonProvider,
                csvProvider: csvProvider,
                basename: basename
            )
        }
        .padding(.bottom, TS.Spacing.sm)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(TS.SemanticColor.line)
                .frame(height: 1)
        }
    }

    private var moreMenu: some View {
        Menu {
            ForEach(moreTabs, id: \.id) { tab in
                Button(tab.title) { selection = tab.id }
            }
        } label: {
            HStack(spacing: 3) {
                Text("更多")
                    .font(TS.Font.serifTab)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .foregroundStyle(TS.SemanticColor.inkFaint)
            .padding(.horizontal, TS.Spacing.md)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
