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
        VStack(spacing: TS.Spacing.lg) {
            Text("❧")
                .font(.system(size: 22, design: .serif))
                .foregroundStyle(TS.SemanticColor.line)
            ZStack {
                Circle()
                    .strokeBorder(TS.SemanticColor.line, lineWidth: 1)
                    .frame(width: 64, height: 64)
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(TS.SemanticColor.gold.opacity(0.7))
            }
            Text(title)
                .font(TS.Font.sectionTitle)
                .foregroundStyle(TS.SemanticColor.ink)
            if let description {
                Text(description)
                    .font(TS.Font.body)
                    .foregroundStyle(TS.SemanticColor.inkFaint)
                    .multilineTextAlignment(.center)
            }
            Text("❧")
                .font(.system(size: 22, design: .serif))
                .foregroundStyle(TS.SemanticColor.line)
                .rotationEffect(.degrees(180))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(TS.Spacing.xxl)
    }
}
struct WarningList: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Divider()

            if warnings.isEmpty {
                Label("没有警告", systemImage: "checkmark.circle")
                    .font(TS.Font.body)
                    .foregroundStyle(.secondary)
            } else {
                Text("警告")
                    .font(TS.Font.sectionTitle)
                ForEach(warnings, id: \.self) { warning in
                    Text(warning)
                        .font(TS.Font.body)
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
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Divider()

            Text("子模块错误")
                .font(TS.Font.sectionTitle)
                .foregroundStyle(TS.SemanticColor.error)

            ForEach(Array(errors.keys).sorted(), id: \.self) { key in
                let label = Self.sectionLabels[key] ?? key
                Text("\(label): \(errors[key] ?? "")")
                    .font(TS.Font.body)
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
