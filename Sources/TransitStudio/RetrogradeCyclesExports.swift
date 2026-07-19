import Foundation

extension MarkdownExportBuilder {
    static func retrogradeCycles(_ result: RetrogradeCyclesResult) -> String {
        var lines: [String] = [
            "# 逆行周期与阴影区",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Window UTC: \(result.meta.startUTC ?? "") → \(result.meta.endUTC ?? "")",
            "- Display timezone: \(result.meta.displayTimezone ?? "")",
            "- Bodies: \((result.meta.bodyIDs ?? []).joined(separator: ", "))",
            "- Cycles: \(result.meta.cycleCount.map(String.init) ?? "\(result.cycles.count)")",
            "- Stations: \(result.meta.stationCount.map(String.init) ?? "\(result.stations.count)")",
            "- Zodiac: \(result.meta.zodiac ?? "")",
            "",
            "## 逆行周期表",
            "",
        ]
        if result.cycles.isEmpty {
            lines.append("窗口内没有完整的逆行站配对周期。")
        } else {
            lines += [
                "| Body | Pre-shadow start | Retro station | Direct station | Post-shadow end | Lon retro | Lon direct | Days |",
                "| --- | --- | --- | --- | --- | ---: | ---: | ---: |",
            ]
            for cycle in result.cycles {
                lines.append(
                    "| \(cycle.bodyName ?? cycle.bodyID) | \(cycle.preShadowStartLocal ?? cycle.preShadowStartUTC ?? "—") | \(cycle.retrogradeStationLocal ?? cycle.retrogradeStationUTC ?? "—") | \(cycle.directStationLocal ?? cycle.directStationUTC ?? "—") | \(cycle.postShadowEndLocal ?? cycle.postShadowEndUTC ?? "—") | \(cycle.retrogradeStationLongitude.map { String(format: "%.6f", $0) } ?? "—") | \(cycle.directStationLongitude.map { String(format: "%.6f", $0) } ?? "—") | \(cycle.retrogradeDurationDays.map { String(format: "%.3f", $0) } ?? "—") |"
                )
            }
        }

        lines += ["", "## 站度表", ""]
        if result.stations.isEmpty {
            lines.append("窗口内没有站度。")
        } else {
            lines += [
                "| Local | Body | Kind | Longitude | Speed |",
                "| --- | --- | --- | ---: | ---: |",
            ]
            for station in result.stations {
                lines.append(
                    "| \(station.exactLocal ?? station.exactUTC) | \(station.bodyName ?? station.bodyID) | \(station.stationKind) | \(station.longitude.map { String(format: "%.6f", $0) } ?? "—") | \(station.speed.map { String(format: "%.8f", $0) } ?? "—") |"
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
        if result.warnings.isEmpty {
            lines += ["", "## 警告", "", "无。"]
        } else {
            lines += ["", "## 警告", ""]
            for warning in result.warnings {
                lines.append("- \(warning)")
            }
        }
        lines += ["", "> 本文仅输出可复算的时间与坐标事实，不包含解释性论断。"]
        return lines.joined(separator: "\n")
    }
}

extension TextExportBuilder {
    static func retrogradeCyclesJSON(_ result: RetrogradeCyclesResult) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(result),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    static func csv(_ result: RetrogradeCyclesResult) -> String {
        var rows = [
            "row_type,id,body_id,station_kind,exact_utc,longitude,speed,pre_shadow_start_utc,retro_station_utc,direct_station_utc,post_shadow_end_utc,lon_retro,lon_direct,duration_days,method_key",
        ]
        for station in result.stations {
            rows.append(
                [
                    "station",
                    csvEscape(station.id),
                    csvEscape(station.bodyID),
                    csvEscape(station.stationKind),
                    csvEscape(station.exactUTC),
                    station.longitude.map { String(format: "%.9f", $0) } ?? "",
                    station.speed.map { String(format: "%.12f", $0) } ?? "",
                    "", "", "", "", "", "", "",
                    csvEscape(station.methodKey ?? ""),
                ].joined(separator: ",")
            )
        }
        for cycle in result.cycles {
            rows.append(
                [
                    "retrograde_cycle",
                    csvEscape(cycle.id),
                    csvEscape(cycle.bodyID),
                    "",
                    "",
                    "",
                    "",
                    csvEscape(cycle.preShadowStartUTC ?? ""),
                    csvEscape(cycle.retrogradeStationUTC ?? ""),
                    csvEscape(cycle.directStationUTC ?? ""),
                    csvEscape(cycle.postShadowEndUTC ?? ""),
                    cycle.retrogradeStationLongitude.map { String(format: "%.9f", $0) } ?? "",
                    cycle.directStationLongitude.map { String(format: "%.9f", $0) } ?? "",
                    cycle.retrogradeDurationDays.map { String(format: "%.6f", $0) } ?? "",
                    csvEscape(cycle.methodKey ?? ""),
                ].joined(separator: ",")
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
