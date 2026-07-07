import SwiftUI

// MARK: - Upagrahas

struct VedicUpagrahaView: View {
    let upagrahas: [VedicUpagraha]

    var body: some View {
        Table(upagrahas.sorted { $0.id < $1.id }) {
            TableColumn("名称") { item in
                Text(item.nameZh)
                    .font(TS.Font.body)
            }
            TableColumn("星座") { item in
                Text(item.rasiName)
                    .font(TS.Font.body)
            }
            TableColumn("度数") { item in
                Text(item.degreeText)
                    .font(TS.Font.monoSmall)
                    .monospacedDigit()
            }
            TableColumn("Nakshatra") { item in
                Text(item.nakshatra.map { "\($0.nameSa) pada \($0.pada)" } ?? "-")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
            }
        }
        .tsTableStyle()
    }
}

// MARK: - Special Lagnas

struct VedicSpecialLagnaView: View {
    let lagnas: [VedicSpecialLagna]

    var body: some View {
        Table(lagnas.sorted { $0.id < $1.id }) {
            TableColumn("名称") { item in
                Text(item.nameZh)
                    .font(TS.Font.body)
            }
            TableColumn("Rasi") { item in
                Text("\(item.rasi)")
                    .font(TS.Font.monoSmall)
                    .monospacedDigit()
            }
            TableColumn("度数") { item in
                Text(item.degreeText ?? "-")
                    .font(TS.Font.monoSmall)
                    .monospacedDigit()
            }
            TableColumn("Nakshatra") { item in
                Text(item.nakshatra.map { "\($0.nameSa) pada \($0.pada)" } ?? "-")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
            }
        }
        .tsTableStyle()
    }
}

// MARK: - Derived Chart (Moon / Bhava)

struct VedicDerivedChartView: View {
    let title: String
    let chart: VedicDerivedChart

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text(title)
                .font(TS.Font.sectionTitle)
                .padding(.horizontal, TS.Padding.resultContent)

            Table(chart.planets.values.sorted { $0.bodyId < $1.bodyId }) {
                TableColumn("行星") { planet in
                    Text(planet.name)
                        .font(TS.Font.body)
                }
                TableColumn("星座") { planet in
                    Text(planet.rasiName)
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
            .tsTableStyle()
        }
    }
}
