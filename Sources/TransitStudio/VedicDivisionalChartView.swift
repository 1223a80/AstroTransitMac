import SwiftUI

struct VedicDivisionalChartView: View {
    let charts: [String: VedicDivisionalChart]
    @State private var selectedChart = ""

    private var sortedKeys: [String] {
        charts.keys.sorted { a, b in
            let numA = Int(a.dropFirst()) ?? 0
            let numB = Int(b.dropFirst()) ?? 0
            return numA < numB
        }
    }

    private var selectedChartData: VedicDivisionalChart? {
        charts[selectedChart]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Picker("分割图", selection: $selectedChart) {
                ForEach(sortedKeys, id: \.self) { key in
                    Text(key).tag(key)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TS.Padding.resultContent)

            if let chart = selectedChartData {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    Text(chart.chartName)
                        .font(TS.Font.sectionTitle)
                        .padding(.horizontal, TS.Padding.resultContent)

                    Table(chart.planets.values.sorted { $0.bodyId < $1.bodyId }) {
                        TableColumn("行星") { planet in
                            Text(planet.name)
                                .font(TS.Font.body)
                        }
                        TableColumn("星座") { planet in
                            Text(planet.vargaRasiSign)
                                .font(TS.Font.body)
                        }
                        TableColumn("度数") { planet in
                            Text(planet.degreeText)
                                .font(TS.Font.monoSmall)
                                .monospacedDigit()
                        }
                        TableColumn("宫位") { planet in
                            Text(planet.house.map { "第 \($0) 宫" } ?? "-")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                        }
                        TableColumn("Nakshatra") { planet in
                            Text(planet.nakshatra.map { "\($0.nameSa) pada \($0.pada)" } ?? "-")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                EmptyStateView(
                    title: "没有可显示的分割图",
                    systemImage: "square.grid.3x3",
                    description: "当前结果未返回 divisional chart 数据。"
                )
            }
        }
        .task(id: sortedKeys.joined(separator: ",")) {
            if selectedChart.isEmpty || !sortedKeys.contains(selectedChart) {
                selectedChart = sortedKeys.first ?? ""
            }
        }
    }
}
