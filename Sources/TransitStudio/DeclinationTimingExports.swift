import Foundation

extension MarkdownExportBuilder {
    static func declinationTiming(_ result: DeclinationTimingResult) -> String {
        var lines: [String] = [
            "# 动态赤纬事件与 OOB 时间线",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Coordinate: `\(result.meta.coordinateKind ?? "declination")`",
            "- Window UTC: \(result.meta.startUTC ?? "") → \(result.meta.endUTC ?? "")",
            "- Display timezone: \(result.meta.displayTimezone ?? "")",
            "- Moving bodies: \((result.meta.movingBodyIDs ?? []).joined(separator: ", "))",
            "- Event types: \((result.meta.eventTypes ?? []).joined(separator: ", "))",
            "- Declination orb: \(result.meta.declinationOrb.map { String(format: "%.2f°" , $0) } ?? "")",
            "- OOB threshold method: \(result.meta.oobThresholdMethod ?? "")",
            "- Search: \(result.meta.searchMethod ?? "") / precision \(result.meta.searchPrecisionSeconds.map { String($0) } ?? "")s",
            "- Zodiac: \(result.meta.zodiac ?? "")",
            "- Ephemeris: \(result.meta.ephemeris ?? "")",
            "- Target count: \(result.meta.targetCount.map(String.init) ?? "")",
            "- Event count: \(result.meta.eventCount.map(String.init) ?? "\(result.events.count)")",
        ]

        if let sample = result.meta.oobThresholdSample {
            lines.append(
                "- OOB threshold sample: \(String(format: "%.6f°", sample)) (\(result.meta.oobThresholdSampleMethod ?? ""))"
            )
        }

        lines += ["", "## 事件表", ""]
        if result.events.isEmpty {
            lines.append("窗口内没有赤纬事件。")
        } else {
            lines += [
                "| 精确当地时间 | Pass | 移动点 | 事件 | 目标 | 赤纬° | 目标赤纬° | 赤纬速度 | 容许度 | 精确差 | OOB阈值 | 方法 |",
                "| --- | ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
            ]
            for event in result.events.sorted(by: { $0.exactUTC < $1.exactUTC }) {
                lines.append(
                    "| \(mdCell(event.exactLocal)) | \(event.passIndexInWindow)/\(event.passCountInWindow) | \(mdCell(event.movingPointName)) | \(mdCell(event.aspectName ?? event.eventType)) | \(mdCell(event.targetPointName ?? "—")) | \(fmt(event.movingDeclination)) | \(event.targetDeclination.map(fmt) ?? "—") | \(event.movingDeclinationSpeed.map(fmtSpeed) ?? "—") | \(event.orbLimit.map(fmt) ?? "—") | \(event.exactOrb.map(fmtOrb) ?? "—") | \(event.oobThreshold.map(fmt) ?? "—") | \(mdCell(event.methodKey)) |"
                )
            }
        }

        if let assumptions = result.calculationAssumptions, !assumptions.isEmpty {
            lines += ["", "## 计算假设", ""]
            for item in assumptions {
                lines.append("- \(item)")
            }
        }

        if let errors = result.sectionErrors, !errors.isEmpty {
            lines += ["", "## 未计算 / section_errors", ""]
            for key in errors.keys.sorted() {
                lines.append("- `\(key)`: \(errors[key] ?? "")")
            }
        } else {
            lines += ["", "## 未计算 / section_errors", "", "无。"]
        }

        if !result.warnings.isEmpty {
            lines += ["", "## 警告", ""]
            for warning in result.warnings {
                lines.append("- \(warning)")
            }
        } else {
            lines += ["", "## 警告", "", "无。"]
        }

        lines += [
            "",
            "> 本文仅输出可复算的时间与坐标事实，不包含吉凶解释。",
        ]
        return lines.joined(separator: "\n")
    }

    private static func mdCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func fmt(_ value: Double) -> String {
        String(format: "%.6f", value)
    }

    private static func fmtSpeed(_ value: Double) -> String {
        String(format: "%.8f", value)
    }

    private static func fmtOrb(_ value: Double) -> String {
        String(format: "%.8f", value)
    }
}

extension TextExportBuilder {
    static func declinationTimingJSON(_ result: DeclinationTimingResult) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(result),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    static func csv(_ result: DeclinationTimingResult) -> String {
        var rows: [String] = [
            "row_type,id,group_id,event_type,moving_point_id,moving_point_name,target_point_id,target_point_name,exact_utc,exact_local,entering_utc,leaving_utc,moving_declination,target_declination,moving_declination_speed,orb_limit,exact_orb,oob_threshold,threshold_method,pass_index,pass_count,method_key,window_clipped_start,window_clipped_end",
        ]
        for event in result.events {
            rows.append(
                [
                    "declination_event",
                    geoCSVEscape(event.id),
                    geoCSVEscape(event.groupID),
                    geoCSVEscape(event.eventType),
                    geoCSVEscape(event.movingPointID),
                    geoCSVEscape(event.movingPointName),
                    geoCSVEscape(event.targetPointID ?? ""),
                    geoCSVEscape(event.targetPointName ?? ""),
                    geoCSVEscape(event.exactUTC),
                    geoCSVEscape(event.exactLocal),
                    geoCSVEscape(event.enteringUTC ?? ""),
                    geoCSVEscape(event.leavingUTC ?? ""),
                    String(format: "%.9f", event.movingDeclination),
                    event.targetDeclination.map { String(format: "%.9f", $0) } ?? "",
                    event.movingDeclinationSpeed.map { String(format: "%.12f", $0) } ?? "",
                    event.orbLimit.map { String(format: "%.6f", $0) } ?? "",
                    event.exactOrb.map { String(format: "%.12f", $0) } ?? "",
                    event.oobThreshold.map { String(format: "%.9f", $0) } ?? "",
                    geoCSVEscape(event.thresholdMethod ?? ""),
                    "\(event.passIndexInWindow)",
                    "\(event.passCountInWindow)",
                    geoCSVEscape(event.methodKey),
                    event.windowClippedStart ? "true" : "false",
                    event.windowClippedEnd ? "true" : "false",
                ].joined(separator: ",")
            )
        }
        return rows.joined(separator: "\n")
    }

    // Reuse the private-style escape used by geo exports without duplicating visibility.
    fileprivate static func geoCSVEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
