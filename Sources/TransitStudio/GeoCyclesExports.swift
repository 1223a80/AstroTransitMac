import Foundation

// MARK: - Relocation export

extension MarkdownExportBuilder {
    static func relocation(_ result: RelocationResult) -> String {
        var lines: [String] = []
        lines.append("# Relocation Chart")
        lines.append("")
        lines.append("- Method: `\(result.meta.method)`")
        lines.append("- Birth UTC: \(result.meta.birthUTC)")
        lines.append("- Relocation local: \(result.meta.relocationLocal)")
        lines.append(
            "- Birth place: \(result.meta.birthPlace.name ?? "") "
                + "(\(result.meta.birthPlace.latitude), \(result.meta.birthPlace.longitude)) "
                + "tz=\(result.meta.birthPlace.timezone ?? "")"
        )
        lines.append(
            "- Relocation: \(result.meta.relocation.name ?? "") "
                + "(\(result.meta.relocation.latitude), \(result.meta.relocation.longitude)) "
                + "tz=\(result.meta.relocation.timezone ?? "")"
        )
        lines.append(
            "- House system requested: \(result.meta.houseSystemRequested ?? "") "
                + "/ natal effective: \(result.meta.houseSystemEffectiveNatal ?? "") "
                + "/ relocated effective: \(result.meta.houseSystemEffectiveRelocated ?? "")"
        )
        lines.append("- Zodiac: \(result.meta.zodiac ?? "")")
        lines.append("")
        lines.append("## Relocated planets")
        lines.append("| Body | Lon | Natal house | Relocated house | Changed |")
        lines.append("|---|---:|---:|---:|---|")
        for row in result.planetHouseChanges {
            let planet = result.relocatedChart.planets.first { $0.bodyID == row.bodyID }
            let lon = planet.map { String(format: "%.6f", $0.longitude) } ?? ""
            lines.append(
                "| \(row.name) | \(lon) | \(row.natalHouse) | \(row.relocatedHouse) | \(row.changed ? "yes" : "no") |"
            )
        }
        lines.append("")
        lines.append("## Relocated angles")
        for angle in result.relocatedChart.angles {
            lines.append("- \(angle.name): \(angle.degreeText) (house \(angle.house))")
        }
        lines.append("")
        lines.append("## Overlays")
        lines.append("### Relocated angles in natal houses")
        for row in result.relocatedAnglesInNatalHouses {
            lines.append("- \(row.name ?? row.angleID ?? "?"): house \(row.house)")
        }
        lines.append("### Natal angles in relocated houses")
        for row in result.natalAnglesInRelocatedHouses {
            lines.append("- \(row.name ?? row.angleID ?? "?"): house \(row.house)")
        }
        if !result.warnings.isEmpty {
            lines.append("")
            lines.append("## Warnings")
            for warning in result.warnings {
                lines.append("- \(warning)")
            }
        }
        return lines.joined(separator: "\n")
    }

    static func modernCycles(_ result: ModernCyclesResult) -> String {
        var lines: [String] = []
        lines.append("# Modern Cycles")
        lines.append("")
        lines.append("- Method: `\(result.meta.method)`")
        lines.append("- Window: \(result.meta.startUTC ?? "") → \(result.meta.endUTC ?? "")")
        lines.append("- Visibility: \(result.meta.visibility ?? "global")")
        lines.append("- Types: \((result.meta.cycleTypes ?? []).joined(separator: ", "))")
        lines.append("")
        lines.append("| ID | Type | Maximum UTC | Sep° | Eclipse | Visible@loc | Contacts |")
        lines.append("|---|---|---|---:|---|---|---:|")
        for event in result.events {
            let sep = event.separationDeg.map { String(format: "%.4f", $0) } ?? ""
            let visible: String
            if let value = event.visibleAtLocation {
                visible = value ? "yes" : "no"
            } else {
                visible = "—"
            }
            lines.append(
                "| \(event.id) | \(event.cycleType) | \(event.maximumUTC) | \(sep) | "
                    + "\(event.eclipseType ?? "") | \(visible) | \(event.contacts?.count ?? 0) |"
            )
        }
        if !result.warnings.isEmpty {
            lines.append("")
            lines.append("## Warnings")
            for warning in result.warnings {
                lines.append("- \(warning)")
            }
        }
        return lines.joined(separator: "\n")
    }

    static func astrocartography(_ result: AstrocartographyResult) -> String {
        var lines: [String] = []
        lines.append("# Astrocartography")
        lines.append("")
        lines.append("- Method: `\(result.meta.method)`")
        lines.append("- Moment UTC: \(result.meta.momentUTC ?? "")")
        lines.append("- Coordinate frame: \(result.meta.coordinateFrame ?? "")")
        if let unverified = result.meta.unverified, !unverified.isEmpty {
            lines.append("- Unverified: \(unverified.joined(separator: ", "))")
        }
        lines.append("")
        for line in result.lines {
            let lon = line.longitude.map { String(format: "%.6f", $0) } ?? "curve"
            let samples = line.points?.count ?? 0
            lines.append("- \(line.id): \(line.angleKind) lon=\(lon) samples=\(samples) method=\(line.methodKey ?? "")")
        }
        return lines.joined(separator: "\n")
    }

    static func localSpace(_ result: LocalSpaceResult) -> String {
        var lines: [String] = []
        lines.append("# Local Space")
        lines.append("")
        lines.append("- Method: `\(result.meta.method)`")
        lines.append("- Moment UTC: \(result.meta.momentUTC ?? "")")
        lines.append("- Coordinate frame: \(result.meta.coordinateFrame ?? "")")
        if let location = result.meta.location {
            lines.append(
                "- Observer: \(location.name ?? "") (\(location.latitude), \(location.longitude))"
            )
        }
        if let unverified = result.meta.unverified, !unverified.isEmpty {
            lines.append("- Unverified: \(unverified.joined(separator: ", "))")
        }
        lines.append("")
        for direction in result.directions {
            lines.append(
                String(
                    format: "- %@: az=%.4f° alt=%@",
                    direction.bodyID,
                    direction.azimuthDeg,
                    direction.altitudeDeg.map { String(format: "%.4f°", $0) } ?? "—"
                )
            )
        }
        return lines.joined(separator: "\n")
    }
}

extension TextExportBuilder {
    static func relocationJSON(_ result: RelocationResult) -> String {
        json(result)
    }

    static func modernCyclesJSON(_ result: ModernCyclesResult) -> String {
        json(result)
    }

    static func astrocartographyJSON(_ result: AstrocartographyResult) -> String {
        json(result)
    }

    static func localSpaceJSON(_ result: LocalSpaceResult) -> String {
        json(result)
    }

    static func csv(_ result: RelocationResult) -> String {
        var rows: [String] = [
            "row_type,body_id,name,longitude,natal_house,relocated_house,changed,birth_utc,birth_place,relocation_place,house_requested,house_effective_natal,house_effective_relocated",
        ]
        let birthUTC = geoCSVEscape(result.meta.birthUTC)
        let birthPlace = geoCSVEscape(
            "\(result.meta.birthPlace.name ?? "")|\(result.meta.birthPlace.latitude)|\(result.meta.birthPlace.longitude)|\(result.meta.birthPlace.timezone ?? "")"
        )
        let relocPlace = geoCSVEscape(
            "\(result.meta.relocation.name ?? "")|\(result.meta.relocation.latitude)|\(result.meta.relocation.longitude)|\(result.meta.relocation.timezone ?? "")"
        )
        for row in result.planetHouseChanges {
            let lon = result.relocatedChart.planets.first { $0.bodyID == row.bodyID }?.longitude ?? 0
            rows.append(
                [
                    "planet_house_change",
                    geoCSVEscape(row.bodyID),
                    geoCSVEscape(row.name),
                    String(format: "%.8f", lon),
                    "\(row.natalHouse)",
                    "\(row.relocatedHouse)",
                    row.changed ? "true" : "false",
                    birthUTC,
                    birthPlace,
                    relocPlace,
                    geoCSVEscape(result.meta.houseSystemRequested ?? ""),
                    geoCSVEscape(result.meta.houseSystemEffectiveNatal ?? ""),
                    geoCSVEscape(result.meta.houseSystemEffectiveRelocated ?? ""),
                ].joined(separator: ",")
            )
        }
        for angle in result.relocatedChart.angles {
            rows.append(
                [
                    "relocated_angle",
                    geoCSVEscape(angle.id),
                    geoCSVEscape(angle.name),
                    String(format: "%.8f", angle.longitude),
                    "",
                    "\(angle.house)",
                    "",
                    birthUTC,
                    birthPlace,
                    relocPlace,
                    geoCSVEscape(result.meta.houseSystemRequested ?? ""),
                    geoCSVEscape(result.meta.houseSystemEffectiveNatal ?? ""),
                    geoCSVEscape(result.meta.houseSystemEffectiveRelocated ?? ""),
                ].joined(separator: ",")
            )
        }
        return rows.joined(separator: "\n")
    }

    static func csv(_ result: ModernCyclesResult) -> String {
        var rows: [String] = [
            "row_type,id,cycle_type,maximum_utc,separation_deg,eclipse_type,global_event,visible_at_location,contact_body,contact_aspect,contact_exact_utc",
        ]
        for event in result.events {
            let base = [
                "cycle_event",
                geoCSVEscape(event.id),
                geoCSVEscape(event.cycleType),
                geoCSVEscape(event.maximumUTC),
                event.separationDeg.map { String(format: "%.8f", $0) } ?? "",
                geoCSVEscape(event.eclipseType ?? ""),
                event.globalEvent.map { $0 ? "true" : "false" } ?? "",
                event.visibleAtLocation.map { $0 ? "true" : "false" } ?? "",
                "",
                "",
                "",
            ]
            if let contacts = event.contacts, !contacts.isEmpty {
                for contact in contacts {
                    var row = base
                    row[8] = geoCSVEscape(contact.bodyID)
                    row[9] = geoCSVEscape(contact.aspectID ?? "")
                    row[10] = geoCSVEscape(contact.exactUTC)
                    rows.append(row.joined(separator: ","))
                }
            } else {
                rows.append(base.joined(separator: ","))
            }
        }
        return rows.joined(separator: "\n")
    }

    static func csv(_ result: AstrocartographyResult) -> String {
        var rows: [String] = ["row_type,id,body_id,angle_kind,geometry,longitude,sample_count,method_key"]
        for line in result.lines {
            rows.append(
                [
                    "acg_line",
                    geoCSVEscape(line.id),
                    geoCSVEscape(line.bodyID),
                    geoCSVEscape(line.angleKind),
                    geoCSVEscape(line.geometry ?? ""),
                    line.longitude.map { String(format: "%.8f", $0) } ?? "",
                    "\(line.points?.count ?? 0)",
                    geoCSVEscape(line.methodKey ?? ""),
                ].joined(separator: ",")
            )
        }
        return rows.joined(separator: "\n")
    }

    static func csv(_ result: LocalSpaceResult) -> String {
        var rows: [String] = ["row_type,id,body_id,azimuth_deg,altitude_deg,method_key"]
        for direction in result.directions {
            rows.append(
                [
                    "local_space_direction",
                    geoCSVEscape(direction.id),
                    geoCSVEscape(direction.bodyID),
                    String(format: "%.8f", direction.azimuthDeg),
                    direction.altitudeDeg.map { String(format: "%.8f", $0) } ?? "",
                    geoCSVEscape(direction.methodKey ?? ""),
                ].joined(separator: ",")
            )
        }
        return rows.joined(separator: "\n")
    }

    fileprivate static func geoCSVEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
