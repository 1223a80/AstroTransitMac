import Foundation

private enum ProgressedCompositeExportSupport {
    static func number(_ value: Double) -> String {
        String(format: "%.8f", value)
    }

    static func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    static func markdownCell(_ value: String) -> String {
        value
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "\n", with: " ")
    }
}

extension MarkdownExportBuilder {
    static func progressedComposite(_ result: ProgressedCompositeResult) -> String {
        var lines: [String] = ["# Progressed Composite 推进组合盘", "", "## 计算来源", ""]
        if let schemaVersion = result.meta.schemaVersion {
            lines.append("- Schema version：\(schemaVersion)")
        }
        lines.append("- 方法：\(result.meta.method)")
        lines.append("- A birth UTC：\(result.meta.personABirthUTC)")
        lines.append("- B birth UTC：\(result.meta.personBBirthUTC)")
        lines.append("- A progressed UTC：\(result.meta.personAProgressedUTC)")
        lines.append("- B progressed UTC：\(result.meta.personBProgressedUTC)")
        if let ageYears = result.meta.personAAgeYears {
            lines.append("- A age years：\(ProgressedCompositeExportSupport.number(ageYears))")
        }
        if let ageYears = result.meta.personBAgeYears {
            lines.append("- B age years：\(ProgressedCompositeExportSupport.number(ageYears))")
        }
        lines.append("- reference UTC：\(result.meta.referenceUTC)")
        if let zodiac = result.meta.zodiac {
            lines.append("- 黄道：\(zodiac)")
        }
        if let ephemeris = result.meta.ephemeris {
            lines.append("- 星历：\(ephemeris)")
        }
        let effective = result.meta.effectivePointSet
        lines.append("- 请求行星点：\(effective.bodyIDs.joined(separator: ", "))")
        lines.append("- 实际有效点：\((effective.resolvedBodyIDs ?? effective.bodyIDs).joined(separator: ", "))")
        lines.append("- 节点：\(effective.includeNodes ? effective.nodeMode : "未包含")")
        lines.append("- 自定义小行星：\(effective.customAsteroids.map(String.init).joined(separator: ", "))")
        lines.append("- v1 排除：angles / houses / Lots / midpoint pairs")

        lines += ["", "## Radix Composite 行星", ""]
        if result.radixCompositePlanets.isEmpty {
            lines.append("无行星数据。")
        } else {
            lines += [
                "| Body ID | 天体 | A 输入黄经 | B 输入黄经 | Composite 黄经 | A birth UTC | B birth UTC | Phase | Midpoint method |",
                "| --- | --- | ---: | ---: | ---: | --- | --- | --- | --- |",
            ]
            for planet in result.radixCompositePlanets {
                let trace = planet.trace
                lines.append(
                    "| \(ProgressedCompositeExportSupport.markdownCell(planet.bodyID)) | \(ProgressedCompositeExportSupport.markdownCell(planet.name)) | \(degree(trace.personAInputLongitude, digits: 8)) | \(degree(trace.personBInputLongitude, digits: 8)) | \(degree(trace.compositeLongitude, digits: 8)) | \(ProgressedCompositeExportSupport.markdownCell(trace.personABirthUTC)) | \(ProgressedCompositeExportSupport.markdownCell(trace.personBBirthUTC)) | \(ProgressedCompositeExportSupport.markdownCell(trace.phase)) | \(ProgressedCompositeExportSupport.markdownCell(trace.midpointMethod)) |"
                )
            }
        }

        lines += ["", "## Progressed Composite 行星与 trace", ""]
        if result.progressedCompositePlanets.isEmpty {
            lines.append("无推进组合盘行星数据。")
        } else {
            lines += [
                "| Body ID | 天体 | A 输入黄经 | B 输入黄经 | Composite 黄经 | A birth UTC | B birth UTC | A progressed UTC | B progressed UTC | Phase | Midpoint method |",
                "| --- | --- | ---: | ---: | ---: | --- | --- | --- | --- | --- | --- |",
            ]
            for planet in result.progressedCompositePlanets {
                let trace = planet.trace
                lines.append(
                    "| \(ProgressedCompositeExportSupport.markdownCell(planet.bodyID)) | \(ProgressedCompositeExportSupport.markdownCell(planet.name)) | \(degree(trace.personAInputLongitude, digits: 8)) | \(degree(trace.personBInputLongitude, digits: 8)) | \(degree(trace.compositeLongitude, digits: 8)) | \(ProgressedCompositeExportSupport.markdownCell(trace.personABirthUTC)) | \(ProgressedCompositeExportSupport.markdownCell(trace.personBBirthUTC)) | \(ProgressedCompositeExportSupport.markdownCell(trace.personAProgressedUTC)) | \(ProgressedCompositeExportSupport.markdownCell(trace.personBProgressedUTC)) | \(ProgressedCompositeExportSupport.markdownCell(trace.phase)) | \(ProgressedCompositeExportSupport.markdownCell(trace.midpointMethod)) |"
                )
            }
        }

        lines += ["", "## Progressed → Radix 相位", ""]
        if result.progressedToRadixAspects.isEmpty {
            lines.append("无推进→本命组合盘相位。")
        } else {
            lines += [
                "| 推进行星 | 相位 | Radix 行星 | 分隔角 | 容许度 |",
                "| --- | --- | --- | ---: | ---: |",
            ]
            for aspect in result.progressedToRadixAspects {
                lines.append(
                    "| \(ProgressedCompositeExportSupport.markdownCell(aspect.transitBodyName)) | \(ProgressedCompositeExportSupport.markdownCell(aspect.aspectName)) | \(ProgressedCompositeExportSupport.markdownCell(aspect.natalBodyName)) | \(degree(aspect.separation, digits: 8)) | \(degree(aspect.orb, digits: 8)) |"
                )
            }
        }

        if let errors = result.sectionErrors, !errors.isEmpty {
            lines += ["", "## 分区错误", ""]
            for (key, value) in errors.sorted(by: { $0.key < $1.key }) {
                lines.append("- \(key)：\(value)")
            }
        }
        lines += warnings(result.warnings)
        return lines.joined(separator: "\n")
    }
}

extension TextExportBuilder {
    static func csv(_ result: ProgressedCompositeResult) -> String {
        let header = [
            "row_type", "body_id", "name", "longitude", "degree_text",
            "person_a_birth_utc", "person_b_birth_utc", "person_a_progressed_utc", "person_b_progressed_utc", "reference_utc",
            "person_a_age_years", "person_b_age_years",
            "person_a_input_longitude", "person_b_input_longitude", "composite_longitude",
            "aspect_id", "aspect_name", "other_body", "separation", "orb", "method", "trace_phase", "midpoint_method",
            "zodiac", "ephemeris", "effective_point_ids", "effective_node_mode", "effective_custom_asteroids",
            "diagnostic_key", "diagnostic_message",
        ]
        let meta = result.meta
        let effective = meta.effectivePointSet
        let emptyAuditTail = Array(repeating: "", count: 7)
        var rows: [[String]] = [header]
        rows.append([
            "meta", "", "", "", "",
            meta.personABirthUTC, meta.personBBirthUTC, meta.personAProgressedUTC, meta.personBProgressedUTC, meta.referenceUTC,
            meta.personAAgeYears.map(ProgressedCompositeExportSupport.number) ?? "",
            meta.personBAgeYears.map(ProgressedCompositeExportSupport.number) ?? "",
            "", "", "", "", "", "", "", "", meta.method, "", "",
            meta.zodiac ?? "", meta.ephemeris ?? "",
            (effective.resolvedBodyIDs ?? effective.bodyIDs).joined(separator: "|"),
            effective.includeNodes ? effective.nodeMode : "",
            effective.customAsteroids.map(String.init).joined(separator: "|"),
            "", "",
        ])

        for planet in result.radixCompositePlanets {
            let trace = planet.trace
            rows.append([
                "radix_composite_planet", planet.bodyID, planet.name,
                ProgressedCompositeExportSupport.number(planet.longitude), planet.degreeText,
                trace.personABirthUTC,
                trace.personBBirthUTC,
                trace.personAProgressedUTC,
                trace.personBProgressedUTC,
                trace.referenceUTC,
                meta.personAAgeYears.map(ProgressedCompositeExportSupport.number) ?? "",
                meta.personBAgeYears.map(ProgressedCompositeExportSupport.number) ?? "",
                ProgressedCompositeExportSupport.number(trace.personAInputLongitude),
                ProgressedCompositeExportSupport.number(trace.personBInputLongitude),
                ProgressedCompositeExportSupport.number(trace.compositeLongitude),
                "", "", "", "", "", meta.method, trace.phase, trace.midpointMethod,
            ] + emptyAuditTail)
        }

        for planet in result.progressedCompositePlanets {
            let trace = planet.trace
            rows.append([
                "progressed_composite_planet", planet.bodyID, planet.name,
                ProgressedCompositeExportSupport.number(planet.longitude), planet.degreeText,
                trace.personABirthUTC,
                trace.personBBirthUTC,
                trace.personAProgressedUTC,
                trace.personBProgressedUTC,
                trace.referenceUTC,
                meta.personAAgeYears.map(ProgressedCompositeExportSupport.number) ?? "",
                meta.personBAgeYears.map(ProgressedCompositeExportSupport.number) ?? "",
                ProgressedCompositeExportSupport.number(trace.personAInputLongitude),
                ProgressedCompositeExportSupport.number(trace.personBInputLongitude),
                ProgressedCompositeExportSupport.number(trace.compositeLongitude),
                "", "", "", "", "", meta.method, trace.phase, trace.midpointMethod,
            ] + emptyAuditTail)
        }

        rows += result.progressedToRadixAspects.map { aspect in
            [
                "progressed_to_radix_aspect", aspect.transitBodyID, aspect.transitBodyName,
                "", "",
                meta.personABirthUTC, meta.personBBirthUTC, meta.personAProgressedUTC, meta.personBProgressedUTC, meta.referenceUTC,
                meta.personAAgeYears.map(ProgressedCompositeExportSupport.number) ?? "",
                meta.personBAgeYears.map(ProgressedCompositeExportSupport.number) ?? "",
                "", "", "",
                aspect.aspectID, aspect.aspectName, aspect.natalBodyName,
                ProgressedCompositeExportSupport.number(aspect.separation),
                ProgressedCompositeExportSupport.number(aspect.orb),
                meta.method, "", "",
            ] + emptyAuditTail
        }

        for warning in result.warnings {
            var row = Array(repeating: "", count: header.count)
            row[0] = "diagnostic"
            row[header.count - 2] = "warning"
            row[header.count - 1] = warning
            rows.append(row)
        }
        for (key, message) in (result.sectionErrors ?? [:]).sorted(by: { $0.key < $1.key }) {
            var row = Array(repeating: "", count: header.count)
            row[0] = "diagnostic"
            row[header.count - 2] = "section_error:\(key)"
            row[header.count - 1] = message
            rows.append(row)
        }

        return rows.map { row in
            row.map(ProgressedCompositeExportSupport.csvEscape).joined(separator: ",")
        }.joined(separator: "\n")
    }

    /// Named facade for callers that want to make the dedicated JSON export
    /// explicit; the generic JSON encoder remains the source of truth.
    static func progressedCompositeJSON(_ result: ProgressedCompositeResult) -> String {
        json(result)
    }
}
