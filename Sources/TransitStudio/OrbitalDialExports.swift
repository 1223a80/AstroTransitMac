import Foundation

extension MarkdownExportBuilder {
    static func orbitalDial(_ result: OrbitalDialResult) -> String {
        var lines = [
            "# orbital_dial",
            "",
            "## 输入与方法",
            "",
            "- Method: `\(result.meta.method)`",
            "- Modulus: \(result.meta.modulus.map(String.init) ?? "—")",
            "- Orbital points: \(result.orbitalPoints.count)",
            "- Dial pictures: \(result.dialPictures.count)",
            "",
            "## Orbital points",
            "",
            "| Body | Kind | Longitude | Center | System | Method |",
            "| --- | --- | ---: | --- | --- | --- |",
        ]
        for p in result.orbitalPoints {
            lines.append(
                "| \(p.bodyId ?? "") | \(p.pointKind ?? "") | \(p.longitude.map { String(format: "%.4f", $0) } ?? "") | \(p.coordinateCenter ?? "") | \(p.coordinateSystem ?? "") | \(p.methodKey ?? "") |"
            )
        }
        lines += ["", "## Dial pictures", "", "| Picture | Midpoint | Modulus | Method |", "| --- | ---: | ---: | --- |"]
        for p in result.dialPictures {
            lines.append("| \(p.picture ?? "") | \(p.midpointLongitude.map { String(format: "%.4f", $0) } ?? "") | \(p.modulus.map(String.init) ?? "") | \(p.methodKey ?? "") |")
        }
        if let a = result.calculationAssumptions, !a.isEmpty {
            lines += ["", "## 计算假设", ""] + a.map { "- \($0)" }
        }
        lines += ["", "> 事实输出，不含吉凶解释。"]
        return lines.joined(separator: "\n")
    }
}

extension TextExportBuilder {
    static func orbitalDialJSON(_ result: OrbitalDialResult) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(result), let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }

    static func csv(_ result: OrbitalDialResult) -> String {
        var rows = ["row_type,body_id,point_kind,longitude,coordinate_center,method_key"]
        for p in result.orbitalPoints {
            rows.append(
                "orbital_point,\(expansionCSVEscape(p.bodyId ?? "")),\(expansionCSVEscape(p.pointKind ?? "")),\(p.longitude.map { String($0) } ?? ""),\(expansionCSVEscape(p.coordinateCenter ?? "")),\(expansionCSVEscape(p.methodKey ?? ""))"
            )
        }
        for p in result.dialPictures {
            rows.append(
                "dial_picture,\(expansionCSVEscape(p.pointA ?? "")),\(expansionCSVEscape(p.picture ?? "")),\(p.midpointLongitude.map { String($0) } ?? ""),,\(expansionCSVEscape(p.methodKey ?? ""))"
            )
        }
        return rows.joined(separator: "\n")
    }
}
