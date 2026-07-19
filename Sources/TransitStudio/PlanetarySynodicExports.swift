import Foundation

extension MarkdownExportBuilder {
    static func planetarySynodic(_ result: PlanetarySynodicResult) -> String {
        var lines: [String] = [
            "# 行星会合周期",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Pair: \(result.meta.pair?.bodyA ?? "") / \(result.meta.pair?.bodyB ?? "")",
            "- Window: \(result.meta.startUTC ?? "") → \(result.meta.endUTC ?? "")",
            "- Events: \(result.meta.eventCount.map(String.init) ?? "\(result.events.count)")",
            "- Cycles: \(result.meta.cycleCount.map(String.init) ?? "\(result.cycles.count)")",
            "",
            "## 相位事件",
            "",
        ]
        if result.events.isEmpty {
            lines.append("窗口内没有相位事件。")
        } else {
            lines += [
                "| Local | Pass | Phase | A lon | B lon | Rel speed | Exact orb | Contacts |",
                "| --- | ---: | --- | ---: | ---: | ---: | ---: | ---: |",
            ]
            for event in result.events {
                lines.append(
                    "| \(event.exactLocal ?? event.exactUTC) | \(event.passIndexInWindow.map(String.init) ?? "")/\(event.passCountInWindow.map(String.init) ?? "") | \(event.phaseName ?? event.phaseID ?? "") | \(event.longitudeA.map { String(format: "%.4f", $0) } ?? "—") | \(event.longitudeB.map { String(format: "%.4f", $0) } ?? "—") | \(event.relativeSpeed.map { String(format: "%.6f", $0) } ?? "—") | \(event.exactOrb.map { String(format: "%.8f", $0) } ?? "—") | \(event.natalContacts?.count ?? 0) |"
                )
            }
        }
        lines += ["", "## 会合周期", ""]
        if result.cycles.isEmpty {
            lines.append("窗口内不足以界定完整合相周期。")
        } else {
            lines += [
                "| Start | End | Days |",
                "| --- | --- | ---: |",
            ]
            for cycle in result.cycles {
                lines.append(
                    "| \(cycle.startLocal ?? cycle.startUTC ?? "—") | \(cycle.endLocal ?? cycle.endUTC ?? "—") | \(cycle.durationDays.map { String(format: "%.3f", $0) } ?? "—") |"
                )
            }
        }
        if let assumptions = result.calculationAssumptions, !assumptions.isEmpty {
            lines += ["", "## 计算假设", ""]
            for item in assumptions { lines.append("- \(item)") }
        }
        if let errors = result.sectionErrors, !errors.isEmpty {
            lines += ["", "## 未计算 / section_errors", ""]
            for key in errors.keys.sorted() { lines.append("- `\(key)`: \(errors[key] ?? "")") }
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
    static func planetarySynodicJSON(_ result: PlanetarySynodicResult) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(result), let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    static func csv(_ result: PlanetarySynodicResult) -> String {
        var rows = [
            "row_type,id,phase_id,exact_utc,longitude_a,longitude_b,relative_speed,exact_orb,pass_index,pass_count,contact_count,start_utc,end_utc,duration_days",
        ]
        for event in result.events {
            let lonA = event.longitudeA.map { String(format: "%.9f", $0) } ?? ""
            let lonB = event.longitudeB.map { String(format: "%.9f", $0) } ?? ""
            let rel = event.relativeSpeed.map { String(format: "%.12f", $0) } ?? ""
            let orb = event.exactOrb.map { String(format: "%.12f", $0) } ?? ""
            let passIndex = event.passIndexInWindow.map(String.init) ?? ""
            let passCount = event.passCountInWindow.map(String.init) ?? ""
            let contactCount = String(event.natalContacts?.count ?? 0)
            let fields = [
                "phase_event",
                csvEscape(event.id),
                csvEscape(event.phaseID ?? ""),
                csvEscape(event.exactUTC),
                lonA,
                lonB,
                rel,
                orb,
                passIndex,
                passCount,
                contactCount,
                "",
                "",
                "",
            ]
            rows.append(fields.joined(separator: ","))
        }
        for cycle in result.cycles {
            let duration = cycle.durationDays.map { String(format: "%.6f", $0) } ?? ""
            let fields = [
                "synodic_cycle",
                csvEscape(cycle.id),
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                "",
                csvEscape(cycle.startUTC ?? ""),
                csvEscape(cycle.endUTC ?? ""),
                duration,
            ]
            rows.append(fields.joined(separator: ","))
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
