import SwiftUI

struct ExportControls: View {
    private let markdownProvider: () -> String
    private let jsonProvider: () -> String
    private let csvProvider: () -> String
    var basename = "astro_export"

    init(
        markdown: @escaping () -> String,
        json: @escaping () -> String,
        csv: @escaping () -> String,
        basename: String = "astro_export"
    ) {
        self.markdownProvider = markdown
        self.jsonProvider = json
        self.csvProvider = csv
        self.basename = basename
    }

    var body: some View {
        HStack(spacing: 8) {
            CopyMarkdownButton(title: "复制 Markdown", textProvider: markdownProvider)
            CopyMarkdownButton(title: "复制 JSON", textProvider: jsonProvider)
            CopyMarkdownButton(title: "复制 CSV", textProvider: csvProvider)
            SaveTextButton(title: "保存 JSON", defaultFilename: "\(basename).json", textProvider: jsonProvider)
            SaveTextButton(title: "保存 CSV", defaultFilename: "\(basename).csv", textProvider: csvProvider)
        }
    }
}
