import SwiftUI

struct VedicJaiminiView: View {
    let karakas: VedicJaiminiKarakas?
    let arudha: [String: VedicArudhaPada]?

    private struct ArudhaRow: Identifiable {
        let key: String
        let rasiName: String
        let house: Int

        var id: String { key }
    }

    private var sortedArudha: [ArudhaRow] {
        (arudha ?? [:])
            .map { key, value in
                ArudhaRow(key: key, rasiName: value.rasiName, house: value.house)
            }
            .sorted { a, b in
            let numA = Int(a.key.dropFirst()) ?? 0
            let numB = Int(b.key.dropFirst()) ?? 0
            return numA < numB
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                if let karakas {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        Text("Chara Karaka")
                            .font(TS.Font.sectionTitle)

                        Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
                            ForEach(karakas.charaKarakas) { karaka in
                                GridRow {
                                    Text(karaka.nameZh)
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: TS.Spacing.md) {
                                        Text(karaka.planetName)
                                            .font(TS.Font.body)
                                        Text(String(format: "%.2f°", karaka.longitudeInRasi))
                                            .font(TS.Font.mono)
                                            .monospacedDigit()
                                    }
                                    .textSelection(.enabled)
                                }
                            }
                        }
                    }
                }

                if !sortedArudha.isEmpty {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        Text("Arudha Pada")
                            .font(TS.Font.sectionTitle)

                        Table(sortedArudha) {
                            TableColumn("Pada") { item in
                                Text(item.key)
                                    .font(TS.Font.body)
                            }
                            TableColumn("星座") { item in
                                Text(item.rasiName)
                                    .font(TS.Font.body)
                            }
                            TableColumn("宫位") { item in
                                Text("第 \(item.house) 宫")
                                    .font(TS.Font.monoSmall)
                                    .monospacedDigit()
                            }
                        }
                        .tsTableStyle()
                    }
                }

                if karakas == nil && sortedArudha.isEmpty {
                    EmptyStateView(
                        title: "无 Jaimini 数据",
                        systemImage: "circle.dashed",
                        description: "开启完整计算后可查看 Chara Karaka 与 Arudha。"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TS.Padding.resultContent)
        }
    }
}
