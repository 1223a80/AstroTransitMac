import SwiftUI

struct VedicPanchangaView: View {
    let panchanga: VedicPanchanga
    let solarDay: VedicSolarDay?

    private var items: [(label: String, item: VedicPanchangaItem)] {
        [
            ("Tithi", panchanga.tithi),
            ("Vara", panchanga.vara),
            ("Nakshatra", panchanga.nakshatra),
            ("Yoga", panchanga.yoga),
            ("Karana", panchanga.karana),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    Text("五支信息")
                        .font(TS.Font.sectionTitle)

                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
                        ForEach(items, id: \.label) { entry in
                            GridRow {
                                Text(entry.label)
                                    .font(TS.Font.label)
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                                    Text(entry.item.nameZh)
                                        .font(TS.Font.body)
                                    Text(entry.item.nameSa)
                                        .font(TS.Font.detail)
                                        .foregroundStyle(.secondary)
                                    if let lord = entry.item.lord, !lord.isEmpty {
                                        Text("主星: \(lord)")
                                            .font(TS.Font.detail)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let paksha = entry.item.paksha, !paksha.isEmpty {
                                        Text("Paksha: \(paksha)")
                                            .font(TS.Font.detail)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .textSelection(.enabled)
                            }
                        }
                    }
                }

                if let solarDay {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        Text("日出 / 日落")
                            .font(TS.Font.sectionTitle)

                        Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
                            GridRow {
                                Text("日出")
                                    .font(TS.Font.label)
                                    .foregroundStyle(.secondary)
                                Text(solarDay.sunriseLocal ?? "-")
                                    .font(TS.Font.mono)
                                    .textSelection(.enabled)
                            }
                            GridRow {
                                Text("日落")
                                    .font(TS.Font.label)
                                    .foregroundStyle(.secondary)
                                Text(solarDay.sunsetLocal ?? "-")
                                    .font(TS.Font.mono)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TS.Padding.resultContent)
        }
    }
}
