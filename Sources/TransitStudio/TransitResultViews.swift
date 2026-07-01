import SwiftUI

// MARK: - Almanac table primitives

/// A column header label with the gold underline used across result tables.
struct AlmanacTableHeader: View {
    let columns: [(title: String, alignment: Alignment, width: CGFloat?)]

    var body: some View {
        HStack(spacing: TS.Spacing.lg) {
            ForEach(columns.indices, id: \.self) { i in
                Text(columns[i].title.uppercased())
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(TS.SemanticColor.inkFaint)
                    .frame(width: columns[i].width, alignment: columns[i].alignment)
                    .frame(maxWidth: columns[i].width == nil ? .infinity : nil,
                           alignment: columns[i].alignment)
            }
        }
        .padding(.horizontal, TS.Spacing.md)
        .padding(.bottom, TS.Spacing.md)
        .overlay(alignment: .bottom) {
            Rectangle().fill(TS.SemanticColor.gold).frame(height: 1.5)
        }
    }
}

/// A zebra-free row with a soft bottom rule and gold hover wash.
private struct AlmanacRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, TS.Spacing.md)
            .padding(.vertical, 7)
            .overlay(alignment: .bottom) {
                Rectangle().fill(TS.SemanticColor.lineSoft).frame(height: 1)
            }
    }
}

/// An element-tinted sign pill (e.g. "狮 17°04′").
struct SignTag: View {
    let text: String
    let sign: String

    var body: some View {
        let color = AstroPalette.elementColor(forSign: sign)
        Text(text)
            .font(.system(.caption, design: .serif))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(color.opacity(0.13))
            )
    }
}

struct AspectTableView: View {
    var title = "行运对本命相位"
    var leftColumnTitle = "行运"
    var rightColumnTitle = "本命"
    let aspects: [AspectHit]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: TS.Spacing.md) {
                Text(title).font(TS.Font.sectionTitle)
                Text("\(aspects.count) 条").font(TS.Font.label).foregroundStyle(TS.SemanticColor.inkFaint)
            }

            if aspects.isEmpty {
                EmptyStateView(title: "没有命中相位", systemImage: "circle.dashed")
            } else {
                AlmanacTableHeader(columns: [
                    ("相位", .leading, 96),
                    (leftColumnTitle, .leading, nil),
                    (rightColumnTitle, .leading, nil),
                    ("角距", .trailing, 70),
                    ("容许", .trailing, 96),
                ])
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(aspects) { aspect in
                            AlmanacRow {
                                HStack(spacing: TS.Spacing.lg) {
                                    aspectCell(aspect)
                                    Text(aspect.transitBodyName)
                                        .font(TS.Font.serif)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(aspect.natalBodyName)
                                        .font(TS.Font.serif)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(degree(aspect.separation))
                                        .font(TS.Font.monoSmall).foregroundStyle(TS.SemanticColor.inkSoft)
                                        .frame(width: 70, alignment: .trailing)
                                    orbCell(aspect)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func aspectCell(_ aspect: AspectHit) -> some View {
        let color = AstroPalette.aspectColor(forID: aspect.aspectID)
        return HStack(spacing: TS.Spacing.md) {
            RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 3, height: 16)
            Text(aspect.aspectName)
                .font(TS.Font.serif)
                .foregroundStyle(TS.SemanticColor.ink)
        }
        .frame(width: 96, alignment: .leading)
    }

    private func orbCell(_ aspect: AspectHit) -> some View {
        let color = AstroPalette.aspectColor(forID: aspect.aspectID)
        let strength = AstroPalette.aspectStrength(orb: aspect.orb)
        return HStack(spacing: TS.Spacing.md) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(TS.SemanticColor.line).frame(height: 4)
                    Capsule().fill(color).frame(width: max(4, geo.size.width * strength), height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(width: 44, height: 16)
            Text(degree(aspect.orb))
                .font(TS.Font.monoSmall).foregroundStyle(TS.SemanticColor.inkFaint)
        }
        .frame(width: 96, alignment: .trailing)
    }

    private func degree(_ value: Double) -> String {
        String(format: "%.2f°", value)
    }
}

struct ScanTableView: View {
    let hits: [ScanHit]
    @State private var sortOrder = [KeyPathComparator(\ScanHit.dateTimeLocal, order: .forward)]

    var displayedHits: [ScanHit] {
        guard !sortOrder.isEmpty else {
            return hits.sorted { $0.dateTimeLocal < $1.dateTimeLocal }
        }
        return hits.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text("精确 Transit 命中")
                .font(TS.Font.sectionTitle)

            if hits.isEmpty {
                EmptyStateView(title: "没有命中", systemImage: "circle.dashed")
            } else {
                Table(displayedHits, sortOrder: $sortOrder) {
                    TableColumn("等级", value: \.priorityGradeSortValue) { Text($0.priorityGrade ?? "") }
                    TableColumn("窗口", value: \.window) { Text($0.window) }
                    TableColumn("本地时间", value: \.dateTimeLocal) { Text($0.dateTimeLocal).monospacedDigit() }
                    TableColumn("行运", value: \.transitBodyName) { Text($0.transitBodyName) }
                    TableColumn("相位", value: \.aspectName) { Text($0.aspectName) }
                    TableColumn("目标", value: \.targetName) { Text($0.targetName) }
                    TableColumn("目标位置") { Text($0.targetPosition ?? "").monospacedDigit() }
                    TableColumn("精确行运位置") { Text($0.exactTransitPosition ?? $0.transitPosition).monospacedDigit() }
                    TableColumn("Orb") { Text(degree($0.orb)).monospacedDigit() }
                    TableColumn("阶段") { Text($0.phase ?? "") }
                }
            }
        }
    }

    private func degree(_ value: Double?) -> String {
        guard let value else {
            return ""
        }
        return String(format: "%.4f°", value)
    }

}
struct PositionTableView: View {
    let title: String
    let positions: [PositionRow]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: TS.Spacing.md) {
                Text(title).font(TS.Font.sectionTitle)
                Text("\(positions.count) 项").font(TS.Font.label).foregroundStyle(TS.SemanticColor.inkFaint)
            }

            if positions.isEmpty {
                EmptyStateView(title: "无位置数据", systemImage: "circle.dashed")
            } else {
                AlmanacTableHeader(columns: [
                    ("天体", .leading, nil),
                    ("星座", .leading, 120),
                    ("黄经", .trailing, 84),
                    ("宫", .trailing, 36),
                    ("黄纬", .trailing, 80),
                    ("速度", .trailing, 88),
                ])
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(positions) { row in
                            AlmanacRow {
                                HStack(spacing: TS.Spacing.lg) {
                                    HStack(spacing: TS.Spacing.md) {
                                        Circle()
                                            .fill(AstroPalette.elementColor(forSign: row.sign))
                                            .frame(width: 6, height: 6)
                                        Text(row.name)
                                            .font(TS.Font.serif)
                                            .foregroundStyle(TS.SemanticColor.ink)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    SignTag(text: row.degreeText, sign: row.sign)
                                        .frame(width: 120, alignment: .leading)

                                    Text(String(format: "%.2f°", row.longitude))
                                        .font(TS.Font.monoSmall).foregroundStyle(TS.SemanticColor.inkSoft)
                                        .frame(width: 84, alignment: .trailing)

                                    Text(row.house.map(String.init) ?? "—")
                                        .font(TS.Font.monoSmall).foregroundStyle(TS.SemanticColor.inkSoft)
                                        .frame(width: 36, alignment: .trailing)

                                    Text(degree(row.latitude))
                                        .font(TS.Font.monoSmall).foregroundStyle(TS.SemanticColor.inkFaint)
                                        .frame(width: 80, alignment: .trailing)

                                    speedCell(row.speed)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func speedCell(_ speed: Double) -> some View {
        let retro = speed < 0
        HStack(spacing: 4) {
            if retro {
                Image(systemName: "arrow.uturn.left")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(TS.SemanticColor.hardAspect)
            }
            Text(String(format: "%.3f", speed))
                .font(TS.Font.monoSmall)
                .foregroundStyle(retro ? TS.SemanticColor.hardAspect : TS.SemanticColor.inkSoft)
        }
        .frame(width: 88, alignment: .trailing)
    }

    private func degree(_ value: Double) -> String {
        String(format: "%.3f°", value)
    }
}
struct DiagnosticsView: View {
    let result: TransitResult

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.xl) {
            Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
                GridRow {
                    Text("本命 UTC").foregroundStyle(.secondary)
                    Text(result.meta.natalUTC).textSelection(.enabled)
                }
                GridRow {
                    Text("行运 UTC").foregroundStyle(.secondary)
                    Text(result.meta.transitUTC).textSelection(.enabled)
                }
                GridRow {
                    Text("星历").foregroundStyle(.secondary)
                    Text(result.meta.ephemeris).textSelection(.enabled)
                }
            }

            WarningList(warnings: result.warnings)
            Spacer()
        }
        .padding(TS.Padding.resultContent)
    }
}

struct ScanDiagnosticsView: View {
    let result: ScanResult

    var gradeSummary: String {
        let counts = Dictionary(grouping: result.hits, by: { $0.priorityGrade ?? "-" })
            .map { "\($0.key): \($0.value.count)" }
            .sorted()
        return counts.joined(separator: " / ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.xl) {
            Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
                GridRow {
                    Text("窗口").foregroundStyle(.secondary)
                    Text(result.meta.label).textSelection(.enabled)
                }
                GridRow {
                    Text("类型").foregroundStyle(.secondary)
                    Text(result.meta.scanKind)
                }
                GridRow {
                    Text("开始 UTC").foregroundStyle(.secondary)
                    Text(result.meta.startUTC).textSelection(.enabled)
                }
                GridRow {
                    Text("结束 UTC").foregroundStyle(.secondary)
                    Text(result.meta.endUTC).textSelection(.enabled)
                }
                GridRow {
                    Text("目标数").foregroundStyle(.secondary)
                    Text("\(result.meta.targetCount)")
                }
                GridRow {
                    Text("星历").foregroundStyle(.secondary)
                    Text(result.meta.ephemeris).textSelection(.enabled)
                }
                GridRow {
                    Text("分级").foregroundStyle(.secondary)
                    Text(gradeSummary.isEmpty ? "-" : gradeSummary)
                }
            }

            WarningList(warnings: result.warnings)
            Spacer()
        }
        .padding(TS.Padding.resultContent)
    }
}
