import Foundation

extension MarkdownExportBuilder {
    static func midpoint(_ result: MidpointResult) -> String {
        var lines: [String] = [
            "# Midpoints v1",
            "",
            "## 计算元数据",
            "",
            "- Schema：\(result.meta.schemaVersion)",
            "- 方法：\(result.meta.method)",
            "- Modulus：\(result.meta.modulus)°",
            "- Activation orb：\(degree(result.meta.activationOrb, digits: 6))",
            "- Opposite axis：\(result.meta.includeOppositeAxis ? "included" : "excluded")",
            "- Activation sources：\((result.meta.activationSources ?? []).joined(separator: ", "))",
            "- 出生 UTC：\(result.meta.birthUTC)",
            "- 参考 UTC：\(result.meta.referenceUTC ?? "—")",
            "- 星历：\(result.meta.ephemeris)",
            "",
            "## 中点轴",
            "",
        ]

        if result.axes.isEmpty {
            lines.append("没有中点轴。")
        } else {
            lines += [
                "| Axis ID | Point A ID | Point A | Point B ID | Point B | Direct | Direct longitude | Opposite | Opposite longitude |",
                "| --- | --- | --- | --- | --- | --- | ---: | --- | ---: |",
            ]
            for axis in result.axes.sorted(by: midpointAxisOrder) {
                lines.append(
                    "| \(midpointMarkdownCell(axis.id)) | \(midpointMarkdownCell(axis.pointAID)) | \(midpointMarkdownCell(axis.pointAName)) | \(midpointMarkdownCell(axis.pointBID)) | \(midpointMarkdownCell(axis.pointBName)) | \(midpointMarkdownCell(axis.midpointText)) | \(degree(axis.midpointLongitude, digits: 8)) | \(midpointMarkdownCell(axis.oppositeText)) | \(degree(axis.oppositeLongitude, digits: 8)) |"
                )
            }
        }

        lines += ["", "## 中点树", ""]
        if result.trees.isEmpty {
            lines.append("没有中点树。")
        } else {
            for tree in result.trees {
                lines += [
                    "### \(midpointMarkdownCell(tree.focusPointName)) (`\(tree.focusPointID)`)",
                    "",
                ]
                lines += midpointHitLines(tree.hits, emptyText: "当前 orb 内没有命中。")
                lines.append("")
            }
        }

        lines += ["", "## 单参考时点激活", ""]
        lines += midpointHitLines(
            result.snapshotActivations,
            emptyText: "未提供 reference 或当前 orb 内没有激活。"
        )
        lines += sectionErrorBlock(result.sectionErrors)
        lines += warnings(result.warnings)
        return lines.joined(separator: "\n")
    }

    private static func midpointHitLines(_ hits: [MidpointHit], emptyText: String) -> [String] {
        guard !hits.isEmpty else { return [emptyText] }
        var lines = [
            "| Source ID | Source | Focus ID | Axis ID | Branch | Hit longitude | Axis longitude | Separation | Orb | Source type | Reference UTC |",
            "| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- |",
        ]
        for hit in hits {
            lines.append(
                "| \(midpointMarkdownCell(hit.sourcePointID)) | \(midpointMarkdownCell(hit.sourcePointName)) | \(midpointMarkdownCell(hit.focusPointID ?? "")) | \(midpointMarkdownCell(hit.axisID)) | \(midpointMarkdownCell(hit.axisBranch)) | \(degree(hit.hitLongitude, digits: 8)) | \(degree(hit.axisLongitude, digits: 8)) | \(degree(hit.separation, digits: 8)) | \(degree(hit.orb, digits: 8)) | \(midpointMarkdownCell(hit.sourceType)) | \(midpointMarkdownCell(hit.referenceUTC ?? "")) |"
            )
        }
        return lines
    }

    private static func midpointAxisOrder(_ lhs: MidpointAxis, _ rhs: MidpointAxis) -> Bool {
        if lhs.midpointLongitude == rhs.midpointLongitude {
            return lhs.id < rhs.id
        }
        return lhs.midpointLongitude < rhs.midpointLongitude
    }

    private static func midpointMarkdownCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

extension TextExportBuilder {
    static func csv(_ result: MidpointResult) -> String {
        let header = [
            "section", "id", "focus_point_id", "focus_point_name",
            "source_point_id", "source_point_name", "axis_id",
            "point_a_id", "point_a_name", "point_b_id", "point_b_name",
            "direct_longitude", "opposite_longitude", "axis_branch",
            "hit_longitude", "axis_longitude", "separation", "orb",
            "source_type", "reference_utc",
        ]
        let axesByID = Dictionary(result.axes.map { ($0.id, $0) }) { first, _ in first }
        var rows: [[String]] = [header]

        rows += result.axes.sorted { lhs, rhs in
            if lhs.midpointLongitude == rhs.midpointLongitude { return lhs.id < rhs.id }
            return lhs.midpointLongitude < rhs.midpointLongitude
        }.map { axis in
            midpointCSVRow(section: "axis", id: axis.id, axis: axis)
        }

        for tree in result.trees {
            rows += tree.hits.map { hit in
                midpointCSVRow(
                    section: "tree_hit",
                    id: hit.id,
                    focusPointID: hit.focusPointID ?? tree.focusPointID,
                    focusPointName: hit.focusPointName ?? tree.focusPointName,
                    hit: hit,
                    axis: axesByID[hit.axisID]
                )
            }
        }

        rows += result.snapshotActivations.map { hit in
            midpointCSVRow(
                section: "snapshot_activation",
                id: hit.id,
                focusPointID: hit.focusPointID,
                focusPointName: hit.focusPointName,
                hit: hit,
                axis: axesByID[hit.axisID]
            )
        }

        return rows.map { row in
            row.map(midpointCSVEscape).joined(separator: ",")
        }.joined(separator: "\n")
    }

    private static func midpointCSVRow(
        section: String,
        id: String,
        focusPointID: String? = nil,
        focusPointName: String? = nil,
        hit: MidpointHit? = nil,
        axis: MidpointAxis?
    ) -> [String] {
        [
            section,
            id,
            focusPointID ?? "",
            focusPointName ?? "",
            hit?.sourcePointID ?? "",
            hit?.sourcePointName ?? "",
            hit?.axisID ?? axis?.id ?? "",
            axis?.pointAID ?? "",
            axis?.pointAName ?? "",
            axis?.pointBID ?? "",
            axis?.pointBName ?? "",
            axis.map { midpointCSVNumber($0.midpointLongitude) } ?? "",
            axis.map { midpointCSVNumber($0.oppositeLongitude) } ?? "",
            hit?.axisBranch ?? "",
            hit.map { midpointCSVNumber($0.hitLongitude) } ?? "",
            hit.map { midpointCSVNumber($0.axisLongitude) } ?? "",
            hit.map { midpointCSVNumber($0.separation) } ?? "",
            hit.map { midpointCSVNumber($0.orb) } ?? "",
            hit?.sourceType ?? "",
            hit?.referenceUTC ?? "",
        ]
    }

    private static func midpointCSVEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func midpointCSVNumber(_ value: Double) -> String {
        String(format: "%.8f", value)
    }
}
