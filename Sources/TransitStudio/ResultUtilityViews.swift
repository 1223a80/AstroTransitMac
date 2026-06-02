import SwiftUI

struct RawJSONView<Value: Encodable>: View {
    let value: Value
    @State private var prettyJSON: String?
    @State private var hasGeneratedJSON = false

    var body: some View {
        Group {
            if let prettyJSON {
                TextEditor(text: .constant(prettyJSON))
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("切换到 JSON 页后生成完整 JSON。")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            guard !hasGeneratedJSON else {
                return
            }
            hasGeneratedJSON = true
            prettyJSON = makePrettyJSON()
        }
    }

    private func makePrettyJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var description: String?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            if let description {
                Text(description)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}
struct WarningList: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            if warnings.isEmpty {
                Label("没有警告", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                Text("警告")
                    .font(.headline)
                ForEach(warnings, id: \.self) { warning in
                    Text(warning)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

struct SectionErrorList: View {
    let errors: [String: String]

    private static let sectionLabels: [String: String] = [
        "primary_directions": "主限法",
        "circumambulations": "沿界推进",
        "prenatal_syzygy": "产前朔望",
        "almuten_figuris": "Almuten Figuris",
        "hyleg_alcocoden": "Hyleg/Alcocoden",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            Text("子模块错误")
                .font(.headline)
                .foregroundStyle(.red)

            ForEach(Array(errors.keys).sorted(), id: \.self) { key in
                let label = Self.sectionLabels[key] ?? key
                Text("\(label): \(errors[key] ?? "")")
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
