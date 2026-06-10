import SwiftUI

struct VedicAshtakavargaView: View {
    let data: VedicAshtakavarga

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                matrixSection(title: "SAV", valuesByRow: [("SAV", data.sav.rekha)])

                ForEach(data.bav.planets.sorted(by: { $0.key < $1.key }), id: \.key) { planetId, values in
                    matrixSection(title: "BAV · \(planetId)", valuesByRow: [(planetId, values)])
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TS.Padding.resultContent)
        }
    }

    private func matrixSection(title: String, valuesByRow: [(String, [Int])]) -> some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text(title)
                .font(TS.Font.sectionTitle)

            Grid(alignment: .center, horizontalSpacing: TS.Spacing.sm, verticalSpacing: TS.Spacing.sm) {
                GridRow {
                    Text("")
                        .frame(width: 60)
                    ForEach(1...12, id: \.self) { house in
                        Text("\(house)")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                            .frame(width: 36)
                    }
                    Text("总")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                        .frame(width: 36)
                }

                ForEach(valuesByRow, id: \.0) { label, values in
                    GridRow {
                        Text(label)
                            .font(TS.Font.body)
                            .frame(width: 60, alignment: .leading)

                        ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                            Text("\(value)")
                                .font(TS.Font.mono)
                                .monospacedDigit()
                                .frame(width: 36)
                                .background(value >= 5 ? TS.SemanticColor.accentSubtle : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: TS.Spacing.sm))
                        }

                        Text("\(values.reduce(0, +))")
                            .font(TS.Font.mono)
                            .monospacedDigit()
                            .fontWeight(.semibold)
                            .frame(width: 36)
                    }
                }
            }
        }
    }
}
