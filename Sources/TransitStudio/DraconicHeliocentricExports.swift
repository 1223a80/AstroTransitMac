import Foundation

extension MarkdownExportBuilder {
    static func draconicHeliocentric(_ result: DraconicHeliocentricResult) -> String {
        var lines = ["# Draconic 与日心对照", "", "## 输入与方法", "",
            "- Method: `\(result.meta.method)`",
            "- Birth UTC: \(result.meta.birthUTC ?? "")",
            "- Node mode: \(result.meta.nodeMode ?? "")",
            "- Draconic shift: \(result.meta.draconicShiftDeg.map { String(format: "%.6f°", $0) } ?? "")",
            "", "## Draconic 行星", ""]
        for p in result.draconic?.planets ?? [] {
            lines.append("- \(p.name ?? p.bodyID): \(String(format: "%.6f", p.longitude)) [\(p.coordinateSystem ?? "")]")
        }
        lines += ["", "## 日心行星", ""]
        for p in result.heliocentric?.planets ?? [] {
            lines.append("- \(p.name ?? p.bodyID): \(String(format: "%.6f", p.longitude)) center=\(p.coordinateCenter ?? "")")
        }
        lines += ["", "## 地心 vs 日心", "", "| Body | Geo | Helio | Δ |", "| --- | ---: | ---: | ---: |"]
        for row in result.geoHelioComparison ?? [] {
            lines.append("| \(row.name ?? row.bodyID) | \(row.geocentricLongitude.map { String(format: "%.4f", $0) } ?? "—") | \(row.heliocentricLongitude.map { String(format: "%.4f", $0) } ?? "—") | \(row.deltaDeg.map { String(format: "%.4f", $0) } ?? "—") |")
        }
        if let a = result.calculationAssumptions, !a.isEmpty {
            lines += ["", "## 计算假设", ""] + a.map { "- \($0)" }
        }
        lines += ["", "## 警告", ""] + (result.warnings.isEmpty ? ["无。"] : result.warnings.map { "- \($0)" })
        lines += ["", "> 坐标事实输出，不含解释。"]
        return lines.joined(separator: "\n")
    }
}

extension TextExportBuilder {
    static func draconicHeliocentricJSON(_ result: DraconicHeliocentricResult) -> String {
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let d = try? e.encode(result), let s = String(data: d, encoding: .utf8) else { return "{}" }
        return s
    }
    static func csv(_ result: DraconicHeliocentricResult) -> String {
        var rows = ["row_type,body_id,longitude,coordinate_center,coordinate_system,delta_deg"]
        for p in result.draconic?.planets ?? [] {
            rows.append("draconic,\(p.bodyID),\(String(format: "%.9f", p.longitude)),\(p.coordinateCenter ?? ""),\(p.coordinateSystem ?? ""),")
        }
        for p in result.heliocentric?.planets ?? [] {
            rows.append("heliocentric,\(p.bodyID),\(String(format: "%.9f", p.longitude)),\(p.coordinateCenter ?? ""),\(p.coordinateSystem ?? ""),")
        }
        for c in result.geoHelioComparison ?? [] {
            rows.append("comparison,\(c.bodyID),,,,\(c.deltaDeg.map { String(format: "%.6f", $0) } ?? "")")
        }
        return rows.joined(separator: "\n")
    }
}
