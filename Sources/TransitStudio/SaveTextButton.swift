import AppKit
import SwiftUI

struct SaveTextButton: View {
    private let textProvider: () -> String
    let title: String
    let defaultFilename: String

    @State private var saved = false

    init(text: String, title: String, defaultFilename: String) {
        self.textProvider = { text }
        self.title = title
        self.defaultFilename = defaultFilename
    }

    init(title: String, defaultFilename: String, textProvider: @escaping () -> String) {
        self.textProvider = textProvider
        self.title = title
        self.defaultFilename = defaultFilename
    }

    var body: some View {
        Button {
            save()
        } label: {
            Label(saved ? "已保存" : title, systemImage: saved ? "checkmark" : "square.and.arrow.down")
        }
    }

    private func save() {
        let text = textProvider()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultFilename
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                return
            }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                saved = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await MainActor.run {
                        saved = false
                    }
                }
            } catch {
                saved = false
            }
        }
    }
}
