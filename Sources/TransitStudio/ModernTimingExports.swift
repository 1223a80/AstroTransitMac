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
                        "| Event ID | Pass | 精确当地时间 | 进入 UTC | 精确 UTC | 离开 UTC | Motion | Exact orb | Clipped | 方法 |",
                        "| --- | ---: | --- | --- | --- | --- | --- | ---: | --- | --- |",
                    ]
                    for event in group.sorted(by: { $0.exactUTC < $1.exactUTC }) {
                        let clipped = [
                            event.windowClippedStart ? "start" : nil,
                            event.windowClippedEnd ? "end" : nil,
                        ].compactMap { $0 }.joined(separator: "+")
                        lines.append(
                            "| \(markdownCell(event.id)) | \(event.passIndexInWindow)/\(event.passCountInWindow) | \(markdownCell(event.exactLocal)) | \(markdownCell(event.enteringUTC ?? "")) | \(markdownCell(event.exactUTC)) | \(markdownCell(event.leavingUTC ?? "")) | \(markdownCell(event.motion)) | \(event.exactOrb.map { degree($0, digits: 6) } ?? "") | \(clipped) | \(markdownCell(event.methodKey)) |"
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

extension TextExportBuilder {
    static func csv(_ result: ModernTimingResult) -> String {
        let header = [
            "source_type", "event_type", "moving_point", "target_point", "target_kind", "aspect", "orb_limit",
            "entering_utc", "exact_utc", "leaving_utc", "exact_local", "motion",
            "pass_index_in_window", "pass_count_in_window",
            "exact_orb", "method_key",
            "id", "group_id", "moving_point_id", "target_point_id", "target_axis_branch", "aspect_id", "aspect_angle",
            "moving_longitude", "target_longitude", "window_clipped_start", "window_clipped_end",
        ]
        let rows = [header] + result.events.map { event in
            [
                event.sourceType,
                event.eventType,
                event.movingPointName,
                event.targetPointName ?? "",
                event.targetPointKind ?? "",
                event.aspectName ?? "",
                event.orbLimit.map(timingNumber) ?? "",
                event.enteringUTC ?? "",
                event.exactUTC,
                event.leavingUTC ?? "",
                event.exactLocal,
                event.motion,
                String(event.passIndexInWindow),
                String(event.passCountInWindow),
                event.exactOrb.map(timingNumber) ?? "",
                event.methodKey,
                event.id,
                event.groupID,
                event.movingPointID,
                event.targetPointID ?? "",
                event.targetAxisBranch ?? "",
                event.aspectID ?? "",
                event.aspectAngle.map(timingNumber) ?? "",
                timingNumber(event.movingLongitude),
                event.targetLongitude.map(timingNumber) ?? "",
                event.windowClippedStart ? "true" : "false",
                event.windowClippedEnd ? "true" : "false",
            ]
        }
        return rows.map { row in
            row.map(timingCSVEscape).joined(separator: ",")
        }.joined(separator: "\n")
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
