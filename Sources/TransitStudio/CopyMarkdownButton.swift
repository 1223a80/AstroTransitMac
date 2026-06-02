import AppKit
import SwiftUI

struct CopyMarkdownButton: View {
    private let textProvider: () -> String
    var title = "复制 Markdown"

    @State private var copied = false

    init(markdown: String, title: String = "复制 Markdown") {
        self.textProvider = { markdown }
        self.title = title
    }

    init(title: String = "复制 Markdown", textProvider: @escaping () -> String) {
        self.textProvider = textProvider
        self.title = title
    }

    var body: some View {
        Button {
            let markdown = textProvider()
            guard !markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(markdown, forType: .string)
            copied = true
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    copied = false
                }
            }
        } label: {
            Label(copied ? "已复制" : title, systemImage: copied ? "checkmark" : "doc.on.doc")
        }
    }
}
