import Foundation

extension MarkdownExportBuilder {
    static func classicalVisibility(_ result: ClassicalVisibilityResult) -> String {
        var lines: [String] = [
            "# 古典可见相位与行星时",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Reference UTC: \(result.meta.referenceUTC ?? "")",
            "- Display timezone: \(result.meta.displayTimezone ?? "")",
            "- Location: \(result.meta.location?.name ?? "") (\(result.meta.location?.latitude ?? 0), \(result.meta.location?.longitude ?? 0))",
            "- Bodies: \((result.meta.bodyIDs ?? []).joined(separator: ", "))",
            "- Include: \((result.meta.include ?? []).joined(separator: ", "))",
            "",
            "## Heliacal 事件",
            "",
        ]
        if result.heliacalEvents.isEmpty {
            lines.append("无 heliacal 事件或未请求该段落。")
        } else {
            lines += [
                "| Body | Event | Status | Exact local | Method |",
                "| --- | --- | --- | --- | --- |",
            ]
            for event in result.heliacalEvents {
                lines.append(
                    "| \(event.bodyName ?? event.bodyID) | \(event.eventType) | \(event.status ?? "") | \(event.exactLocal ?? event.exactUTC ?? "—") | \(event.methodKey ?? "") |"
                )
            }
        }

        lines += ["", "## 地方升落", ""]
        if result.riseSet.isEmpty {
            lines.append("无升落结果或未请求该段落。")
        } else {
            lines += [
                "| Body | Rise local | Set local |",
                "| --- | --- | --- |",
            ]
            for row in result.riseSet {
                lines.append(
                    "| \(row.bodyName ?? row.bodyID) | \(row.riseLocal ?? row.riseUTC ?? "—") | \(row.setLocal ?? row.setUTC ?? "—") |"
                )
            }
        }

        lines += ["", "## 行星时（不等时）", ""]
        if let hours = result.planetaryHours {
            lines.append("- Status: \(hours.status ?? "")")
            lines.append("- Day ruler: \(hours.dayRulerName ?? hours.dayRulerID ?? "")")
            lines.append("- Sunrise: \(hours.sunriseLocal ?? hours.sunriseUTC ?? "—")")
            lines.append("- Sunset: \(hours.sunsetLocal ?? hours.sunsetUTC ?? "—")")
            lines.append("- Day hour minutes: \(hours.dayHourMinutes.map { String(format: "%.2f", $0) } ?? "—")")
            lines.append("- Night hour minutes: \(hours.nightHourMinutes.map { String(format: "%.2f", $0) } ?? "—")")
            if let current = hours.currentHour {
                lines.append("- Current hour: \(current.period) #\(current.hourIndex) \(current.rulerName ?? current.rulerID)")
            }
            if let rows = hours.hours, !rows.isEmpty {
                lines += [
                    "",
                    "| Period | # | Ruler | Start local | End local | Minutes |",
                    "| --- | ---: | --- | --- | --- | ---: |",
                ]
                for row in rows {
                    lines.append(
                        "| \(row.period) | \(row.hourIndex) | \(row.rulerName ?? row.rulerID) | \(row.startLocal ?? row.startUTC) | \(row.endLocal ?? row.endUTC) | \(row.durationMinutes.map { String(format: "%.2f", $0) } ?? "—") |"
                    )
                }
            } else if hours.status != "ok" {
                lines.append("- 未生成小时表：\(hours.reason ?? hours.status ?? "unavailable")")
            }
        } else {
            lines.append("未请求行星时。")
        }

        if let assumptions = result.calculationAssumptions, !assumptions.isEmpty {
            lines += ["", "## 计算假设", ""]
            for item in assumptions { lines.append("- \(item)") }
        }
        if let errors = result.sectionErrors, !errors.isEmpty {
            lines += ["", "## 未计算 / section_errors", ""]
            for key in errors.keys.sorted() {
                lines.append("- `\(key)`: \(errors[key] ?? "")")
            }
        } else {
            lines += ["", "## 未计算 / section_errors", "", "无。"]
        }
        if result.warnings.isEmpty {
            lines += ["", "## 警告", "", "无。"]
        } else {
            lines += ["", "## 警告", ""]
            for warning in result.warnings { lines.append("- \(warning)") }
        }
        lines += ["", "> 本文仅输出可复算的时间与坐标事实，不包含解释性论断。"]
        return lines.joined(separator: "\n")
    }
}

extension TextExportBuilder {
    static func classicalVisibilityJSON(_ result: ClassicalVisibilityResult) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(result), let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    static func csv(_ result: ClassicalVisibilityResult) -> String {
        var rows = ["row_type,id,body_id,event_type,status,exact_utc,rise_utc,set_utc,period,hour_index,ruler_id,start_utc,end_utc,duration_minutes"]
        for event in result.heliacalEvents {
            rows.append(
                ["heliacal", csvEscape(event.id), csvEscape(event.bodyID), csvEscape(event.eventType), csvEscape(event.status ?? ""), csvEscape(event.exactUTC ?? ""), "", "", "", "", "", "", "", ""].joined(separator: ",")
            )
        }
        for row in result.riseSet {
            rows.append(
                ["rise_set", csvEscape(row.bodyID), csvEscape(row.bodyID), "", "", "", csvEscape(row.riseUTC ?? ""), csvEscape(row.setUTC ?? ""), "", "", "", "", "", ""].joined(separator: ",")
            )
        }
        for hour in result.planetaryHours?.hours ?? [] {
            rows.append(
                ["planetary_hour", csvEscape(hour.id), "", "", "", "", "", "", csvEscape(hour.period), "\(hour.hourIndex)", csvEscape(hour.rulerID), csvEscape(hour.startUTC), csvEscape(hour.endUTC), hour.durationMinutes.map { String(format: "%.4f", $0) } ?? ""].joined(separator: ",")
            )
        }
        return rows.joined(separator: "\n")
    }

    fileprivate static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
