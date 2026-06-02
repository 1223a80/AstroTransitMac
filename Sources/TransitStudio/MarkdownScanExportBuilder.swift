import Foundation

extension MarkdownExportBuilder {
    static func scan(_ result: ScanResult) -> String {
        var lines: [String] = [
            "# 窗口扫描",
            "",
            "## 元数据",
            "",
            "- 名称：\(result.meta.label)",
            "- 类型：\(result.meta.scanKind)",
            "- 开始 UTC：\(result.meta.startUTC)",
            "- 结束 UTC：\(result.meta.endUTC)",
            "- 星历：\(result.meta.ephemeris)",
            "- 目标数：\(result.meta.targetCount)",
            "",
            "## 命中",
            "",
            "| 等级 | 窗口 | 本地时间 | 行运 | 相位 | 角度 | 目标 | 目标位置 | 精确行运位置 | Orb | 阶段 | 方法 |",
            "| --- | --- | --- | --- | --- | ---: | --- | --- | --- | ---: | --- | --- |"
        ]

        if result.hits.isEmpty {
            lines.append("| - | - | - | - | - | - | - | - | - | - | - | - |")
        } else {
            lines += result.hits.map {
                "| \($0.priorityGrade ?? "") | \($0.window) | \($0.dateTimeLocal) | \($0.transitBodyName) | \($0.aspectName) | \($0.aspectAngle.map { degree($0, digits: 0) } ?? "") | \($0.targetName) | \($0.targetPosition ?? "") | \($0.exactTransitPosition ?? $0.transitPosition) | \($0.orb.map { degree($0, digits: 4) } ?? "") | \($0.phase ?? "") | \($0.exactMethod ?? "") |"
            }
        }

        lines += warnings(result.warnings)
        return lines.joined(separator: "\n")
    }
}
