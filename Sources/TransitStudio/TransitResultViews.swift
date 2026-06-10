import SwiftUI

struct AspectTableView: View {
    var title = "行运对本命相位"
    var leftColumnTitle = "行运"
    var rightColumnTitle = "本命"
    let aspects: [AspectHit]

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text(title)
                .font(TS.Font.sectionTitle)

            if aspects.isEmpty {
                EmptyStateView(title: "没有命中相位", systemImage: "circle.dashed")
            } else {
                Table(aspects) {
                    TableColumn(leftColumnTitle) { Text($0.transitBodyName) }
                    TableColumn("相位") { Text($0.aspectName) }
                    TableColumn(rightColumnTitle) { Text($0.natalBodyName) }
                    TableColumn("角距") { Text(degree($0.separation)) }
                    TableColumn("容许") { Text(degree($0.orb)) }
                }
            }
        }
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
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            Text(title)
                .font(TS.Font.sectionTitle)

            Table(positions) {
                TableColumn("天体") { Text($0.name) }
                TableColumn("黄经") { Text($0.degreeText).monospacedDigit() }
                TableColumn("宫") { Text($0.house.map(String.init) ?? "") }
                TableColumn("黄纬") { Text(degree($0.latitude)).monospacedDigit() }
                TableColumn("速度") { Text(degree($0.speed) + "/日").monospacedDigit() }
            }
        }
    }

    private func degree(_ value: Double) -> String {
        String(format: "%.4f°", value)
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
