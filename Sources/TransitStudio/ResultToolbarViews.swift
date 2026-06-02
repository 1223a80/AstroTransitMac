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
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Result Pane Toolbar (rows of HStacks + export row)
struct ResultPaneToolbar: View {
    @Binding var selection: String
    let tabRows: [[(id: String, title: String)]]
    let moreTabs: [(id: String, title: String)]
    let currentTabTitle: String
    let markdownProvider: () -> String
    let jsonProvider: () -> String
    let csvProvider: () -> String
    var basename = "astro_export"
    var classicalSectionPicker: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(tabRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.id) { tab in
                        TabChip(
                            title: tab.title,
                            isSelected: selection == tab.id,
                            action: { selection = tab.id }
                        )
                    }
                }
            }

            if !moreTabs.isEmpty {
                HStack(spacing: 6) {
                    Menu {
                        ForEach(moreTabs, id: \.id) { tab in
                            Button(tab.title) {
                                selection = tab.id
                            }
                        }
                    } label: {
                        Text("更多")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }

            HStack {
                Text(currentTabTitle)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if let classicalSectionPicker {
                    Button("导出 Markdown...") { classicalSectionPicker() }
                        .font(.caption)
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
}
