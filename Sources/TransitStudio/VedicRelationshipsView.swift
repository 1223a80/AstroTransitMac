import SwiftUI

struct VedicRelationshipsView: View {
    let relationships: VedicRelationships

    @State private var selectedSection = "compound"

    private struct RelationshipRow: Identifiable {
        let source: String
        let target: String
        let label: String
        let value: Int

        var id: String { "\(source)-\(target)" }
    }

    private var sectionData: (data: [String: [String: Int]], labels: [String: String]?) {
        switch selectedSection {
        case "naisargika":
            return (relationships.naisargika.data, relationships.naisargika.labels)
        case "temporary":
            return (relationships.temporary.data, relationships.temporary.labels)
        default:
            return (relationships.compound.data, relationships.compound.labels)
        }
    }

    private var rows: [RelationshipRow] {
        let labels = sectionData.labels ?? [:]
        var builtRows: [RelationshipRow] = []
        for source in sectionData.data.keys.sorted() {
            guard let targets = sectionData.data[source] else { continue }
            for target in targets.keys.sorted() {
                guard let value = targets[target] else { continue }
                builtRows.append(
                    RelationshipRow(
                        source: labels[source] ?? source,
                        target: labels[target] ?? target,
                        label: relationshipLabel(value),
                        value: value
                    )
                )
            }
        }
        return builtRows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Picker("关系类型", selection: $selectedSection) {
                Text("综合关系").tag("compound")
                Text("自然友谊").tag("naisargika")
                Text("临时友谊").tag("temporary")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, TS.Padding.resultContent)

            if rows.isEmpty {
                EmptyStateView(
                    title: "无行星关系数据",
                    systemImage: "circle.dashed",
                    description: "当前结果没有返回可显示的关系矩阵。"
                )
            } else {
                Table(rows) {
                    TableColumn("来源") { row in
                        Text(row.source)
                            .font(TS.Font.body)
                    }
                    TableColumn("目标") { row in
                        Text(row.target)
                            .font(TS.Font.body)
                    }
                    TableColumn("等级") { row in
                        Text(row.label)
                            .font(TS.Font.label)
                            .foregroundStyle(relationshipColor(row.value))
                    }
                    TableColumn("值") { row in
                        Text("\(row.value)")
                            .font(TS.Font.monoSmall)
                            .monospacedDigit()
                    }
                }
            }
        }
    }

    private func relationshipLabel(_ value: Int) -> String {
        switch value {
        case let value where value > 0:
            return "友"
        case let value where value < 0:
            return "敌"
        default:
            return "中性"
        }
    }

    private func relationshipColor(_ value: Int) -> Color {
        switch value {
        case let value where value > 0:
            return TS.SemanticColor.success
        case let value where value < 0:
            return TS.SemanticColor.error
        default:
            return .secondary
        }
    }
}
