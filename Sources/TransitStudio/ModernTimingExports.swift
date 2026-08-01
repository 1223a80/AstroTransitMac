import Foundation

extension MarkdownExportBuilder {
    static func modernTiming(_ result: ModernTimingResult) -> String {
        var lines: [String] = [
            "# 综合预测时间线",
            "",
            "## 查询窗口",
            "",
            "- 开始 UTC：\(result.meta.startUTC)",
            "- 结束 UTC：\(result.meta.endUTC)",
            "- 显示时区：\(result.meta.displayTimezone)",
            "- 技法：\(result.meta.techniqueIDs.joined(separator: ", "))",
            "- 目标点数：\(result.meta.targetCount)",
            "- 预计工作量：\(result.meta.estimatedWorkUnits)",
            "- 星历：\(result.meta.ephemeris)",
        ]

        if let targetChartType = result.meta.targetChartType {
            lines.append("- 目标盘类型：\(targetChartType)")
        }
        if let targetChartMethod = result.meta.targetChartMethod {
            lines.append("- 目标盘方法：\(targetChartMethod)")
        }

        if !result.meta.techniqueConfigs.isEmpty {
            lines += ["", "## 技法与相位配置", ""]
            for technique in result.meta.techniqueConfigs {
                lines.append(
                    "- \(technique.id)：移动点 \(technique.movingBodyIDs.joined(separator: ", "))；事件 \(technique.eventTypes.joined(separator: ", "))"
                )
                lines += technique.aspects.map { aspect in
                    "  - \(aspect.id) \(degree(aspect.angle, digits: 0)) / orb \(degree(aspect.orb, digits: 2))"
                }
            }
        }

        if result.events.contains(where: \.isWindowClipped) {
            lines += [
                "",
                "> lifecycle 在查询边界被截断的事件以空 entering/leaving 保留；空值不是查询边界时间。",
            ]
        }

        if result.events.isEmpty {
            lines += ["", "## 事件", "", "窗口内没有命中事件。"]
        } else {
            let monthGroups = Dictionary(grouping: result.events) { monthKey($0.exactLocal) }
            for month in monthGroups.keys.sorted() {
                lines += ["", "## \(month)", ""]
                let eventsInMonth = monthGroups[month, default: []]
                let signatureGroups = Dictionary(grouping: eventsInMonth, by: \.groupID)
                let sortedGroups = signatureGroups.values.sorted {
                    ($0.map(\.exactUTC).min() ?? "") < ($1.map(\.exactUTC).min() ?? "")
                }
                for group in sortedGroups {
                    guard let first = group.sorted(by: { $0.exactUTC < $1.exactUTC }).first else { continue }
                    lines += [
                        "### \(markdownCell(eventSummary(first)))",
                        "",
                        "`\(first.groupID)`",
                        "",
                        "| Event ID | Pass | 精确当地时间 | 进入 UTC | 精确 UTC | 离开 UTC | Motion | Exact orb | Target kind | Target longitude | Clipped | 方法 | 目标盘类型 | 目标盘方法 |",
                        "| --- | ---: | --- | --- | --- | --- | --- | ---: | --- | ---: | --- | --- | --- | --- |",
                    ]
                    for event in group.sorted(by: { $0.exactUTC < $1.exactUTC }) {
                        let clipped = [
                            event.windowClippedStart ? "start" : nil,
                            event.windowClippedEnd ? "end" : nil,
                        ].compactMap { $0 }.joined(separator: "+")
                        lines.append(
                            "| \(markdownCell(event.id)) | \(event.passIndexInWindow)/\(event.passCountInWindow) | \(markdownCell(event.exactLocal)) | \(markdownCell(event.enteringUTC ?? "")) | \(markdownCell(event.exactUTC)) | \(markdownCell(event.leavingUTC ?? "")) | \(markdownCell(event.motion)) | \(event.exactOrb.map { degree($0, digits: 6) } ?? "") | \(markdownCell(event.targetPointKind ?? "")) | \(event.targetLongitude.map { degree($0, digits: 8) } ?? "") | \(clipped) | \(markdownCell(event.methodKey)) | \(markdownCell(event.targetChartType ?? result.meta.targetChartType ?? "")) | \(markdownCell(event.targetChartMethod ?? result.meta.targetChartMethod ?? "")) |"
                        )
                    }
                    lines.append("")
                }
            }
        }

        lines += sectionErrorBlock(result.sectionErrors)
        lines += warnings(result.warnings)
        return lines.joined(separator: "\n")
    }

    private static func monthKey(_ localTimestamp: String) -> String {
        guard localTimestamp.count >= 7 else { return localTimestamp }
        return String(localTimestamp.prefix(7))
    }

    private static func eventSummary(_ event: ModernTimingEvent) -> String {
        var parts = [event.movingPointName]
        if let aspect = event.aspectName ?? event.aspectID {
            parts.append(aspect)
        } else {
            parts.append(event.eventType)
        }
        if let target = event.targetPointName ?? event.targetPointID {
            parts.append(target)
        }
        if let branch = event.targetAxisBranch {
            parts.append("[\(branch)]")
        }
        return "[\(event.sourceType)] " + parts.joined(separator: " ")
    }

    private static func markdownCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

private enum ModernTimingCSVColumn: String, CaseIterable {
    case sourceType = "source_type"
    case eventType = "event_type"
    case movingPoint = "moving_point"
    case targetPoint = "target_point"
    case targetKind = "target_kind"
    case aspect
    case orbLimit = "orb_limit"
    case enteringUTC = "entering_utc"
    case exactUTC = "exact_utc"
    case leavingUTC = "leaving_utc"
    case exactLocal = "exact_local"
    case motion
    case passIndexInWindow = "pass_index_in_window"
    case passCountInWindow = "pass_count_in_window"
    case exactOrb = "exact_orb"
    case methodKey = "method_key"
    case id
    case groupID = "group_id"
    case movingPointID = "moving_point_id"
    case targetPointID = "target_point_id"
    case targetAxisBranch = "target_axis_branch"
    case aspectID = "aspect_id"
    case aspectAngle = "aspect_angle"
    case movingLongitude = "moving_longitude"
    case targetLongitude = "target_longitude"
    case windowClippedStart = "window_clipped_start"
    case windowClippedEnd = "window_clipped_end"
    case targetChartType = "target_chart_type"
    case targetChartMethod = "target_chart_method"
}

private struct ModernTimingCSVRow {
    private static let columnIndexes = Dictionary(
        uniqueKeysWithValues: ModernTimingCSVColumn.allCases.enumerated().map { ($0.element, $0.offset) }
    )

    private var values = Array(repeating: "", count: ModernTimingCSVColumn.allCases.count)

    subscript(column: ModernTimingCSVColumn) -> String {
        get { values[Self.columnIndexes[column]!] }
        set { values[Self.columnIndexes[column]!] = newValue }
    }

    var fields: [String] { values }
}

extension TextExportBuilder {
    static func csv(_ result: ModernTimingResult) -> String {
        let header = ModernTimingCSVColumn.allCases.map(\.rawValue)
        var rows: [[String]] = [header]
        if result.meta.targetChartType != nil || result.meta.targetChartMethod != nil {
            var provenanceRow = ModernTimingCSVRow()
            provenanceRow[.sourceType] = "meta"
            provenanceRow[.eventType] = "target_chart"
            provenanceRow[.targetChartType] = result.meta.targetChartType ?? ""
            provenanceRow[.targetChartMethod] = result.meta.targetChartMethod ?? ""
            rows.append(provenanceRow.fields)
        }
        for event in result.events {
            rows.append(timingCSVRow(for: event, meta: result.meta).fields)
        }
        return rows.map { row in
            row.map(timingCSVEscape).joined(separator: ",")
        }.joined(separator: "\n")
    }

    private static func timingCSVRow(for event: ModernTimingEvent, meta: ModernTimingMeta) -> ModernTimingCSVRow {
        var row = ModernTimingCSVRow()
        row[.sourceType] = event.sourceType
        row[.eventType] = event.eventType
        row[.movingPoint] = event.movingPointName
        row[.targetPoint] = event.targetPointName ?? ""
        row[.targetKind] = event.targetPointKind ?? ""
        row[.aspect] = event.aspectName ?? ""
        row[.orbLimit] = event.orbLimit.map(timingNumber) ?? ""
        row[.enteringUTC] = event.enteringUTC ?? ""
        row[.exactUTC] = event.exactUTC
        row[.leavingUTC] = event.leavingUTC ?? ""
        row[.exactLocal] = event.exactLocal
        row[.motion] = event.motion
        row[.passIndexInWindow] = String(event.passIndexInWindow)
        row[.passCountInWindow] = String(event.passCountInWindow)
        row[.exactOrb] = event.exactOrb.map(timingNumber) ?? ""
        row[.methodKey] = event.methodKey
        row[.id] = event.id
        row[.groupID] = event.groupID
        row[.movingPointID] = event.movingPointID
        row[.targetPointID] = event.targetPointID ?? ""
        row[.targetAxisBranch] = event.targetAxisBranch ?? ""
        row[.aspectID] = event.aspectID ?? ""
        row[.aspectAngle] = event.aspectAngle.map(timingNumber) ?? ""
        row[.movingLongitude] = timingNumber(event.movingLongitude)
        row[.targetLongitude] = event.targetLongitude.map(timingNumber) ?? ""
        row[.windowClippedStart] = event.windowClippedStart ? "true" : "false"
        row[.windowClippedEnd] = event.windowClippedEnd ? "true" : "false"
        row[.targetChartType] = event.targetChartType ?? meta.targetChartType ?? ""
        row[.targetChartMethod] = event.targetChartMethod ?? meta.targetChartMethod ?? ""
        return row
    }

    private static func timingCSVEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func timingNumber(_ value: Double) -> String {
        String(format: "%.8f", value)
    }
}
