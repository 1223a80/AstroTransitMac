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

// MARK: - Tab chip
struct TabChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TS.Font.label)
                .padding(.horizontal, TS.Padding.chipHorizontal)
                .padding(.vertical, TS.Padding.chipVertical)
                .background(isSelected ? TS.SemanticColor.chipSelectedBackground : TS.SemanticColor.chipBackground)
                .foregroundStyle(isSelected ? TS.SemanticColor.chipSelectedForeground : .primary)
                .clipShape(RoundedRectangle(cornerRadius: TS.Radius.chip))
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
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            // Single-line scrollable tab bar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TS.Spacing.sm) {
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

            // Title + export row
            HStack {
                Text(currentTabTitle)
                    .font(TS.Font.pageTitle)
                Spacer()
                if let classicalSectionPicker {
                    Button("导出 Markdown...") { classicalSectionPicker() }
                        .font(TS.Font.label)
                        .buttonStyle(.borderedProminent)
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
        }
    }

    private var moreMenu: some View {
        Menu {
            ForEach(moreTabs, id: \.id) { tab in
                Button(tab.title) { selection = tab.id }
            }
        } label: {
            Text("更多")
                .font(TS.Font.label)
                .padding(.horizontal, TS.Padding.chipHorizontal)
                .padding(.vertical, TS.Padding.chipVertical)
                .background(TS.SemanticColor.chipBackground)
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: TS.Radius.chip))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
