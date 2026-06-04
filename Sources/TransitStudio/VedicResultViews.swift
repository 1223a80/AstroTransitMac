import SwiftUI

// MARK: - Vedic Overview View

struct VedicOverviewView: View {
    let result: VedicResult

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 12) {
                // Lagna Card
                if let asc = result.rasiChart?.angles.first(where: { $0.id == "ASC" }) {
                    InfoCard(title: "Lagna", value: asc.degreeText, subtitle: "\(asc.sign) 第\(asc.house)宫")
                }

                // Current Dasa
                if let cur = result.vimshottari?.currentMahadasa {
                    InfoCard(title: "当前主运", value: cur.lord, subtitle: "\(cur.start) - \(cur.end)")
                }

                // Yoga count
                if let yogas = result.yogas, !yogas.isEmpty {
                    InfoCard(title: "Yoga 匹配", value: "\(yogas.count)", subtitle: yogas.prefix(2).map(\.name).joined(separator: ", "))
                }

                // Strongest planet
                if let shadbala = result.shadbala {
                    let sorted = shadbala.sorted { $0.value.percent > $1.value.percent }
                    if let best = sorted.first {
                        InfoCard(title: "最强 Graha", value: best.key, subtitle: "\(best.value.percent)% Ṣaḍbala")
                    }
                }
            }
            .padding()

            // Birth details
            GroupBox("出生信息") {
                LabeledContent("日期", value: result.meta.birthLocal)
                LabeledContent("经纬度", value: "\(result.meta.latitude)° / \(result.meta.longitude)°")
                LabeledContent("Ayanāṃśa", value: result.meta.ayanamsha)
            }
            .padding(.horizontal)

            // Planet table
            if let planets = result.planets {
                GroupBox("行星 / Nakṣatra") {
                    ForEach(Array(planets.values.sorted { $0.longitude < $1.longitude })) { planet in
                        HStack {
                            Text(planet.name).frame(width: 60, alignment: .leading)
                            Text(planet.degreeText).font(.caption).frame(width: 100)
                            if let nak = planet.nakshatra?.nakshatra {
                                Text("\(nak.nameSa) pada \(nak.pada)").font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Lord: \(planet.nakshatra?.nakshatra.lord ?? "-")")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                        Divider()
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Info Card

struct InfoCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.weight(.semibold))
            Text(subtitle).font(.caption2).foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.08)))
    }
}

// MARK: - Dasa Timeline View

struct VedicDasaTimelineView: View {
    let dasa: VimsottariResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Birth nakshatra info
                HStack {
                    Text("出生 Nakṣatra").font(.caption).foregroundStyle(.secondary)
                    Text(dasa.birthNakshatra).fontWeight(.semibold)
                }
                .padding(.horizontal)

                Divider()

                LazyVStack(spacing: 0) {
                    ForEach(dasa.mahaDasas) { period in
                        let isCurrent = period.lord == dasa.currentMahadasa?.lord &&
                            period.start == dasa.currentMahadasa?.start
                        DasaPeriodRow(period: period, isCurrent: isCurrent)
                        Divider().padding(.leading)
                    }
                }
            }
            .padding()
        }
    }
}

struct DasaPeriodRow: View {
    let period: DasaPeriod
    let isCurrent: Bool

    var body: some View {
        HStack {
            // Color indicator based on lord
            RoundedRectangle(cornerRadius: 2)
                .fill(colorForLord(period.lord))
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(period.lord)
                    .fontWeight(isCurrent ? .bold : .regular)
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                Text("\(period.durationYears) 年").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.leading, 8)

            Spacer()

            Text(period.start.prefix(10))
                .font(.caption).foregroundStyle(.secondary)
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
            Text(period.end.prefix(10))
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isCurrent ? Color.accentColor.opacity(0.08) : Color.clear)
        .cornerRadius(6)
    }

    func colorForLord(_ lord: String) -> Color {
        switch lord {
        case "SUN": return .orange
        case "MOON": return .gray
        case "MARS": return .red
        case "MERCURY": return .green
        case "JUPITER": return .yellow
        case "VENUS": return .pink
        case "SATURN": return .blue
        case "RAHU": return .purple
        case "KETU": return .indigo
        default: return .brown
        }
    }
}

// MARK: - Shadbala View

struct VedicShadbalaView: View {
    let shadbala: [String: ShadbalaRow]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(Array(shadbala.keys.sorted()), id: \.self) { pid in
                    if let row = shadbala[pid] {
                        ShadbalaRowView(planetId: pid, row: row)
                    }
                }
            }
            .padding()
        }
    }
}

struct ShadbalaRowView: View {
    let planetId: String
    let row: ShadbalaRow

    var body: some View {
        GroupBox {
            HStack {
                Text(planetId).fontWeight(.semibold).frame(width: 80, alignment: .leading)
                ProgressView(value: min(row.percent / 100.0, 1.0))
                    .tint(row.percent >= 80 ? .green : row.percent >= 50 ? .orange : .red)
                Text("\(Int(row.percent))%").font(.caption).frame(width: 40)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sthāna \(Int(row.sthanaBala))").font(.caption2).foregroundStyle(.secondary)
                    Text("Dig \(Int(row.digBala))").font(.caption2).foregroundStyle(.secondary)
                    Text("Kāla \(Int(row.kalaBala))").font(.caption2).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ceṣṭa \(Int(row.cheshtaBala))").font(.caption2).foregroundStyle(.secondary)
                    Text("Naiṣargika \(Int(row.naisargikaBala))").font(.caption2).foregroundStyle(.secondary)
                    Text("Total \(Int(row.shadbalaTotal))v / \(row.required)r").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(row.shadbalaRupas, specifier: "%.1f") Rūpa")
                    .font(.title3).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Yoga View

struct VedicYogaListView: View {
    let yogas: [VedicYoga]

    var body: some View {
        List {
            ForEach(yogas) { yoga in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(yoga.name).fontWeight(.semibold)
                        TagView(yoga.group)
                    }
                    Text(yoga.description ?? yoga.effect).font(.caption).foregroundStyle(.secondary)
                    Text(yoga.effect).font(.caption2).foregroundStyle(.tertiary)
                    HStack(spacing: 2) {
                        ForEach(yoga.planets, id: \.self) { p in
                            Text(p).font(.caption2).padding(.horizontal, 4).padding(.vertical, 1)
                                .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct TagView: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).font(.caption2).padding(.horizontal, 6).padding(.vertical, 1)
            .background(
                Capsule().fill(
                    text == "Raja" ? Color.orange.opacity(0.2) :
                    text == "Dhana" ? Color.green.opacity(0.2) :
                    Color.blue.opacity(0.2)
                )
            )
            .foregroundStyle(.secondary)
    }
}

// MARK: - Navamsa Table

struct VedicNavamsaView: View {
    let navamsa: [String: VedicNavamsaPosition]

    var body: some View {
        List {
            ForEach(Array(navamsa.values.sorted { $0.bodyId < $1.bodyId })) { pos in
                HStack {
                    Text(pos.name).frame(width: 80, alignment: .leading)
                    Text("D9: \(pos.navamsaRasiName)").fontWeight(.medium)
                    Spacer()
                    Text("Rāśi \(pos.navamsaRasi)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
