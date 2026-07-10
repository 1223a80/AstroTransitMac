import SwiftUI

// MARK: - Vedic Overview View

struct VedicOverviewView: View {
    let result: VedicResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: TS.Spacing.lg) {
                    if let asc = result.rasiChart?.angles.first(where: { $0.id == "ASC" }) {
                        InfoCard(title: "Lagna", value: asc.degreeText, subtitle: "\(asc.sign) 第\(asc.house)宫")
                    }

                    if let cur = result.vimshottari?.currentMahadasa {
                        InfoCard(title: "当前主运", value: cur.lord, subtitle: "\(cur.start) - \(cur.end)")
                    }

                    if let yogas = result.yogas, !yogas.isEmpty {
                        InfoCard(title: "Yoga 匹配", value: "\(yogas.count)", subtitle: yogas.prefix(2).map(\.name).joined(separator: ", "))
                    }

                    if let shadbala = result.shadbala {
                        let sorted = shadbala.filter { $0.value.isComplete == true }.sorted { $0.value.percent > $1.value.percent }
                        if let best = sorted.first {
                            InfoCard(title: "最强 Graha", value: best.key, subtitle: "\(best.value.percent)% Ṣaḍbala")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: TS.Spacing.md) {
                    Text("出生信息")
                        .font(TS.Font.sectionTitle)

                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
                        GridRow {
                            Text("日期")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                            Text(result.meta.birthLocal)
                                .font(TS.Font.mono)
                                .textSelection(.enabled)
                        }
                        GridRow {
                            Text("UTC")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                            Text(result.meta.birthUtc)
                                .font(TS.Font.mono)
                                .textSelection(.enabled)
                        }
                        if let timezone = result.meta.timezoneLabel {
                            GridRow {
                                Text("时区")
                                    .font(TS.Font.label)
                                    .foregroundStyle(.secondary)
                                Text(timezone)
                                    .font(TS.Font.body)
                                    .textSelection(.enabled)
                            }
                        }
                        GridRow {
                            Text("经纬度")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                            Text("\(result.meta.latitude)° / \(result.meta.longitude)°")
                                .font(TS.Font.mono)
                                .monospacedDigit()
                                .textSelection(.enabled)
                        }
                        GridRow {
                            Text("Ayanamsha")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                            Text(result.meta.ayanamshaName ?? result.meta.ayanamsha)
                                .font(TS.Font.body)
                                .textSelection(.enabled)
                        }
                    }
                }

                if let planets = result.planets, !planets.isEmpty {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        Text("行星 / Nakshatra")
                            .font(TS.Font.sectionTitle)

                        Table(planets.values.sorted { $0.longitude < $1.longitude }) {
                            TableColumn("行星") { planet in
                                Text(planet.name)
                                    .font(TS.Font.body)
                            }
                            TableColumn("位置") { planet in
                                Text(planet.degreeText)
                                    .font(TS.Font.monoSmall)
                                    .monospacedDigit()
                            }
                            TableColumn("Nakshatra") { planet in
                                Text(planet.nakshatra.map { "\($0.nakshatra.nameSa) pada \($0.nakshatra.pada)" } ?? "-")
                                    .font(TS.Font.label)
                                    .foregroundStyle(.secondary)
                            }
                            TableColumn("Lord") { planet in
                                Text(planet.nakshatra?.nakshatra.lord ?? "-")
                                    .font(TS.Font.label)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tsTableStyle()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TS.Padding.resultContent)
        }
    }
}

// MARK: - Info Card

struct InfoCard: View {
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        VStack(spacing: TS.Spacing.sm) {
            Text(title).font(TS.Font.label).foregroundStyle(.secondary)
            Text(value).font(TS.Font.pageTitle)
            Text(subtitle).font(TS.Font.detail).foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .padding(TS.Padding.cardInner)
        .background(TS.SemanticColor.cardBackground, in: RoundedRectangle(cornerRadius: TS.Radius.card))
    }
}

// MARK: - Dasa Timeline View

struct VedicDasaTimelineView: View {
    let dasa: VimsottariResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
                    GridRow {
                        Text("出生 Nakshatra")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                        Text(dasa.birthNakshatra)
                            .font(TS.Font.body)
                            .textSelection(.enabled)
                    }
                }
                if let lord = dasa.birthNakshatraLord, let balance = dasa.dashaBalance {
                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
                        GridRow {
                            Text("起始主运")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                        Text("\(lord) 余额 \(balance.years)Y\(balance.months)M\(balance.days)D")
                                .font(TS.Font.body)
                                .textSelection(.enabled)
                        }
                    }
                }

                LazyVStack(spacing: 0) {
                    ForEach(dasa.mahaDasas) { period in
                        let isCurrent = period.lord == dasa.currentMahadasa?.lord &&
                            period.start == dasa.currentMahadasa?.start
                        DasaPeriodRow(period: period, isCurrent: isCurrent)
                        Divider().padding(.leading, TS.Spacing.xl)
                    }
                }
            }
            .padding(TS.Padding.resultContent)
        }
    }
}

struct DasaPeriodRow: View {
    let period: DasaPeriod
    let isCurrent: Bool

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: TS.Spacing.xs)
                .fill(colorForLord(period.lord))
                .frame(width: TS.Spacing.sm, height: 32)

            VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                Text(period.lord)
                    .font(TS.Font.body)
                    .fontWeight(isCurrent ? .bold : .regular)
                    .foregroundStyle(isCurrent ? TS.SemanticColor.accent : .primary)
                Text("\(period.durationYears) 年").font(TS.Font.detail).foregroundStyle(.secondary)
            }
            .padding(.leading, TS.Spacing.md)

            Spacer()

            Text(period.start.prefix(10))
                .font(TS.Font.monoSmall).foregroundStyle(.secondary)
            Image(systemName: "arrow.right").font(TS.Font.detail).foregroundStyle(.tertiary)
            Text(period.end.prefix(10))
                .font(TS.Font.monoSmall).foregroundStyle(.secondary)
        }
        .padding(.vertical, TS.Spacing.sm)
        .padding(.horizontal, TS.Spacing.md)
        .background(isCurrent ? TS.SemanticColor.accentSubtle : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.chip))
    }

    private func colorForLord(_ lord: String) -> Color {
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
            LazyVStack(spacing: TS.Spacing.md) {
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
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack {
                Text(planetId).fontWeight(.semibold).frame(width: 80, alignment: .leading)
                ProgressView(value: min(row.percent / 100.0, 1.0))
                    .tint(row.percent >= 80 ? .green : row.percent >= 50 ? .orange : .red)
                Text("\(Int(row.percent))%").font(TS.Font.label).frame(width: 40)
            }

            HStack(spacing: TS.Spacing.lg) {
                VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                    Text("Sthāna \(Int(row.sthanaBala))").font(TS.Font.detail).foregroundStyle(.secondary)
                    Text("Dig \(Int(row.digBala))").font(TS.Font.detail).foregroundStyle(.secondary)
                    Text("Kāla \(Int(row.kalaBala))").font(TS.Font.detail).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                    Text("Ceṣṭa \(Int(row.cheshtaBala))").font(TS.Font.detail).foregroundStyle(.secondary)
                    Text("Naiṣargika \(Int(row.naisargikaBala))").font(TS.Font.detail).foregroundStyle(.secondary)
                    Text("Total \(Int(row.shadbalaTotal))v / \(row.required)r").font(TS.Font.detail).foregroundStyle(.secondary)
                    if row.isComplete == false {
                        Text("Incomplete").font(TS.Font.detail).foregroundStyle(.orange)
                    }
                }
                Spacer()
                Text("\(row.shadbalaRupas, specifier: "%.1f") Rūpa")
                    .font(TS.Font.body).foregroundStyle(.secondary)
            }
        }
        .padding(TS.Padding.cardInner)
        .background(TS.SemanticColor.cardBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.card))
    }
}

// MARK: - Yoga View

struct VedicYogaListView: View {
    let yogas: [VedicYoga]

    var body: some View {
        List {
            ForEach(yogas) { yoga in
                VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                    HStack {
                        Text(yoga.name).fontWeight(.semibold)
                        TagView(yoga.group)
                        if yoga.conditionOnly == true {
                            TagView("condition only")
                        }
                        if yoga.needsStrengthCheck == true {
                            TagView("needs check")
                        }
                    }
                    Text(yoga.description ?? yoga.effect).font(TS.Font.label).foregroundStyle(.secondary)
                    Text(yoga.effect).font(TS.Font.detail).foregroundStyle(.tertiary)
                    HStack(spacing: TS.Spacing.xs) {
                        ForEach(yoga.planets, id: \.self) { p in
                            Text(p).font(TS.Font.detail).padding(.horizontal, TS.Spacing.sm).padding(.vertical, 1)
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
        Text(text).font(TS.Font.detail).padding(.horizontal, 6).padding(.vertical, 1)
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
        Table(navamsa.values.sorted { $0.bodyId < $1.bodyId }) {
            TableColumn("行星") { pos in
                Text(pos.name)
                    .font(TS.Font.body)
            }
            TableColumn("Navamsa") { pos in
                Text(pos.navamsaRasiName)
                    .font(TS.Font.body)
            }
            TableColumn("Rasi") { pos in
                Text("\(pos.navamsaRasi)")
                    .font(TS.Font.monoSmall)
                    .monospacedDigit()
            }
        }
        .tsTableStyle()
    }
}

// MARK: - Dasa Container (Vimshottari / Yogini / Ashtottari)

struct VedicDasaContainerView: View {
    let vimshottari: VimsottariResult?
    let yogini: YoginiDasaResult?
    let ashtottari: AshtottariDasaResult?

    @State private var selectedSystem = "vimshottari"

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Picker("大运系统", selection: $selectedSystem) {
                Text("Vimśottarī").tag("vimshottari")
                if yogini != nil { Text("Yoginī").tag("yogini") }
                if ashtottari != nil { Text("Aṣṭottarī").tag("ashtottari") }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, TS.Padding.resultContent)

            switch selectedSystem {
            case "vimshottari":
                if let dasa = vimshottari {
                    VedicDasaTimelineView(dasa: dasa)
                } else {
                    EmptyStateView(title: "无 Vimśottarī 数据", systemImage: "timeline.selection")
                }
            case "yogini":
                if let dasa = yogini {
                    yoginiView(dasa)
                } else {
                    EmptyStateView(title: "无 Yoginī 数据", systemImage: "timeline.selection")
                }
            case "ashtottari":
                if let dasa = ashtottari {
                    ashtottariView(dasa)
                } else {
                    EmptyStateView(title: "无 Aṣṭottarī 数据", systemImage: "timeline.selection")
                }
            default:
                EmptyView()
            }
        }
    }

    private func yoginiView(_ dasa: YoginiDasaResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                if let current = dasa.currentYogini {
                    Text("当前 Yoginī: \(current.yogini)")
                        .font(TS.Font.sectionTitle)
                    Text("\(current.start) - \(current.end)")
                        .font(TS.Font.mono)
                        .foregroundStyle(.secondary)
                }

                ForEach(dasa.yoginiDasas) { period in
                    DasaTimelineLiteRow(
                        label: period.yogini,
                        detail: "\(period.durationYears) 年",
                        startDate: period.start,
                        endDate: period.end,
                        color: .purple,
                        isCurrent: period.yogini == dasa.currentYogini?.yogini && period.start == dasa.currentYogini?.start
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TS.Padding.resultContent)
        }
    }

    private func ashtottariView(_ dasa: AshtottariDasaResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                if let current = dasa.currentAshtottari {
                    Text("当前 Aṣṭottarī: \(current.lord)")
                        .font(TS.Font.sectionTitle)
                    Text("\(current.start) - \(current.end)")
                        .font(TS.Font.mono)
                        .foregroundStyle(.secondary)
                }

                ForEach(dasa.ashtottariDasas) { period in
                    DasaTimelineLiteRow(
                        label: period.lord,
                        detail: "\(period.durationYears) 年",
                        startDate: period.start,
                        endDate: period.end,
                        color: .indigo,
                        isCurrent: period.lord == dasa.currentAshtottari?.lord && period.start == dasa.currentAshtottari?.start
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TS.Padding.resultContent)
        }
    }
}

private struct DasaTimelineLiteRow: View {
    let label: String
    let detail: String
    let startDate: String
    let endDate: String
    let color: Color
    let isCurrent: Bool

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: TS.Spacing.xs)
                .fill(color)
                .frame(width: TS.Spacing.sm, height: 32)

            VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                Text(label)
                    .font(TS.Font.body)
                    .fontWeight(isCurrent ? .bold : .regular)
                    .foregroundStyle(isCurrent ? TS.SemanticColor.accent : .primary)
                Text(detail)
                    .font(TS.Font.detail)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, TS.Spacing.md)

            Spacer()

            Text(startDate)
                .font(TS.Font.monoSmall)
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(TS.Font.detail)
                .foregroundStyle(.tertiary)
            Text(endDate)
                .font(TS.Font.monoSmall)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, TS.Spacing.sm)
        .padding(.horizontal, TS.Spacing.md)
        .background(isCurrent ? TS.SemanticColor.accentSubtle : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.chip))
    }
}
