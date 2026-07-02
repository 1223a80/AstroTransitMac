import Foundation

extension MarkdownExportBuilder {
    static func warnings(_ rows: [String]) -> [String] {
        guard !rows.isEmpty else {
            return []
        }
        return ["", "## 警告", ""] + rows.map { "- \($0)" }
    }

    static func degree(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f°", value)
    }

    static func sectionErrorBlock(_ sectionErrors: [String: String]?) -> [String] {
        guard let errors = sectionErrors, !errors.isEmpty else { return [] }
        let labels: [String: String] = [
            "primary_directions": "主限法",
            "circumambulations": "沿界推进",
            "prenatal_syzygy": "产前朔望",
            "almuten_figuris": "Almuten Figuris",
            "hyleg_alcocoden": "Hyleg/Alcocoden",
            "medieval": "中世纪深化",
        ]
        var lines: [String] = ["", "## 子模块错误", ""]
        for key in errors.keys.sorted() {
            let label = labels[key] ?? key
            lines.append("- **\(label)**: \(errors[key] ?? "")")
        }
        return lines
    }
}
