import SwiftUI

/// Timeline strip for scan hits: events plotted on a horizontal time axis,
/// colored by aspect polarity (hard/soft) or gold for ingress/station events,
/// with the classic hits table below for detail work.
struct ScanTimelineView: View {
    let result: ScanResult

    private static let dateParser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private struct TimelinePoint: Identifiable {
        let id: String
        let date: Date
        let lane: Int
        let color: Color
        let tooltip: String
    }

    private var parsedHits: [(hit: ScanHit, date: Date)] {
        result.hits
            .compactMap { hit in
                Self.dateParser.date(from: hit.dateTimeLocal).map { (hit, $0) }
            }
            .sorted { $0.date < $1.date }
    }

    private var points: [TimelinePoint] {
        var lanesPerDay: [String: Int] = [:]
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "yyyy-MM-dd"
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")

        return parsedHits.map { entry in
            let dayKey = dayFormatter.string(from: entry.date)
            let lane = min(lanesPerDay[dayKey, default: 0], Self.maxLanes - 1)
            lanesPerDay[dayKey, default: 0] += 1

            let color: Color
            if result.meta.scanKind == "aspect" {
                color = AstroPalette.aspectColor(forID: entry.hit.aspectID)
            } else {
                color = TS.SemanticColor.gold
            }

            let orbText = entry.hit.orb.map { String(format: " orb %.3f°", $0) } ?? ""
            return TimelinePoint(
                id: entry.hit.id,
                date: entry.date,
                lane: lane,
                color: color,
                tooltip: "\(entry.hit.dateTimeLocal)  \(entry.hit.transitBodyName) \(entry.hit.aspectName) \(entry.hit.targetName)\(orbText)"
            )
        }
    }

    private static let maxLanes = 6
    private static let laneSpacing: CGFloat = 13
    private static let axisPadding: CGFloat = 10

    private var stripHeight: CGFloat {
        let usedLanes = (points.map(\.lane).max() ?? 0) + 1
        return CGFloat(usedLanes) * Self.laneSpacing + 42
    }

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.lg) {
            if points.isEmpty {
                if result.hits.isEmpty {
                    Text("窗口内没有命中事件。")
                        .font(TS.Font.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("命中时间无法解析，仅显示表格。")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            } else {
                timelineStrip
                legend
            }
            ScanTableView(hits: result.hits)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var timelineStrip: some View {
        let pts = points
        let start = pts.first!.date
        let end = pts.last!.date
        let span = max(end.timeIntervalSince(start), 1)

        return GeometryReader { geo in
            let usableWidth = geo.size.width - Self.axisPadding * 2
            let axisY = geo.size.height - 22

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(TS.SemanticColor.line)
                    .frame(width: geo.size.width, height: 1)
                    .position(x: geo.size.width / 2, y: axisY)

                ForEach(monthTicks(start: start, end: end), id: \.date) { tick in
                    let x = Self.axisPadding + usableWidth * CGFloat(tick.date.timeIntervalSince(start) / span)
                    Rectangle()
                        .fill(TS.SemanticColor.inkFaint)
                        .frame(width: 1, height: 6)
                        .position(x: x, y: axisY + 3)
                    Text(tick.label)
                        .font(TS.Font.monoSmall)
                        .foregroundStyle(TS.SemanticColor.inkFaint)
                        .position(x: x, y: axisY + 14)
                }

                HStack {
                    Text(shortDate(start))
                    Spacer(minLength: 0)
                    Text(shortDate(end))
                }
                .font(TS.Font.monoSmall)
                .foregroundStyle(TS.SemanticColor.inkSoft)
                .frame(width: geo.size.width)
                .position(x: geo.size.width / 2, y: axisY + 14)

                ForEach(pts) { point in
                    let x = Self.axisPadding + usableWidth * CGFloat(point.date.timeIntervalSince(start) / span)
                    let y = axisY - 12 - CGFloat(point.lane) * Self.laneSpacing
                    Circle()
                        .fill(point.color)
                        .frame(width: 9, height: 9)
                        .position(x: x, y: y)
                        .help(point.tooltip)
                }
            }
        }
        .frame(height: stripHeight)
        .padding(TS.Padding.cardInner)
        .background(TS.SemanticColor.cardBackground, in: RoundedRectangle(cornerRadius: TS.Radius.card))
    }

    private var legend: some View {
        HStack(spacing: TS.Spacing.xl) {
            legendItem(color: TS.SemanticColor.hardAspect, label: "硬相位")
            legendItem(color: TS.SemanticColor.softAspect, label: "软相位")
            legendItem(color: TS.SemanticColor.gold, label: "合相 / 入座 / 留")
            Spacer(minLength: 0)
            Text("\(result.hits.count) 个事件")
                .font(TS.Font.label)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: TS.Spacing.sm) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(TS.Font.label)
                .foregroundStyle(.secondary)
        }
    }

    private struct MonthTick {
        let date: Date
        let label: String
    }

    private func monthTicks(start: Date, end: Date) -> [MonthTick] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        var ticks: [MonthTick] = []
        var components = calendar.dateComponents([.year, .month], from: start)
        components.day = 1
        guard var cursor = calendar.date(from: components) else { return [] }
        if cursor < start {
            cursor = calendar.date(byAdding: .month, value: 1, to: cursor) ?? end
        }
        while cursor <= end {
            let month = calendar.component(.month, from: cursor)
            ticks.append(MonthTick(date: cursor, label: "\(month)月"))
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return ticks
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}
