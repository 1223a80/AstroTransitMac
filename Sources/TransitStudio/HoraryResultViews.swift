import SwiftUI

struct HoraryOverviewView: View {
    let result: HoraryDataPacket

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                HorarySectionCard(title: "Schema") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        Text(result.schema.schemaId).monospaced()
                        Text("engine \(result.provenance.engineName) \(result.provenance.engineVersion)")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                        Text("input_hash \(result.provenance.inputHashSha256)")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }

                HorarySectionCard(title: "Question Metadata") {
                    Text(result.questionMetadata.questionText.isEmpty ? "(empty)" : result.questionMetadata.questionText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }

                HorarySectionCard(title: "Time & Location") {
                    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
                        GridRow {
                            Text("Local").foregroundStyle(.secondary)
                            Text(result.timeAndLocation.localDatetime).monospacedDigit()
                        }
                        GridRow {
                            Text("UTC").foregroundStyle(.secondary)
                            Text(result.timeAndLocation.utcDatetime).textSelection(.enabled)
                        }
                        GridRow {
                            Text("Timezone").foregroundStyle(.secondary)
                            Text("\(result.timeAndLocation.timezone) (DST=\(result.timeAndLocation.dstActive ? "true" : "false"))")
                        }
                        GridRow {
                            Text("Coordinates").foregroundStyle(.secondary)
                            Text("\(result.timeAndLocation.latitudeDeg, specifier: "%.4f"), \(result.timeAndLocation.locationLongitudeDeg, specifier: "%.4f")")
                                .monospacedDigit()
                        }
                        GridRow {
                            Text("JD UT / TT").foregroundStyle(.secondary)
                            Text("\(result.timeAndLocation.jdUt.map { String($0) } ?? "-") / \(result.timeAndLocation.jdTt.map { String($0) } ?? "-")")
                                .monospacedDigit()
                        }
                        GridRow {
                            Text("Sect is_day").foregroundStyle(.secondary)
                            Text("\(result.timeAndLocation.sect.isDay ? "true" : "false") (\(result.timeAndLocation.sect.ruleId))")
                        }
                        if result.timeAndLocation.sect.evidence != nil {
                            GridRow {
                                Text("sect.evidence").foregroundStyle(.secondary)
                                Text("present").font(TS.Font.label)
                            }
                        }
                        if result.timeAndLocation.geocoding != nil {
                            GridRow {
                                Text("geocoding").foregroundStyle(.secondary)
                                Text("present").font(TS.Font.label)
                            }
                        }
                        GridRow {
                            Text("Config").foregroundStyle(.secondary)
                            Text("\(result.calculationConfig.houseSystem) / \(result.calculationConfig.zodiac) / orb \(result.calculationConfig.aspectOrbDeg)°")
                        }
                    }
                }

                HorarySectionCard(title: "Moon Index (neutral)") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        let moon = result.moon
                        Text("phase_angle: \(moon?.number("phase_angle_deg").map { String(format: "%.4f", $0) } ?? "-")°")
                        Text("illumination: \(moon?.number("illumination_fraction").map { String(format: "%.4f", $0) } ?? "-")")
                        let signExitUtc: String = {
                            guard let se = moon?["sign_exit"], case .object(let o) = se,
                                  case .string(let s) = o["datetime_utc"] ?? .null else { return "-" }
                            return s
                        }()
                        Text("sign_exit: \(signExitUtc)")
                        if let next = moon?["next_exact_aspect_in_current_sign"], case .object(let o) = next {
                            let aspectId = { if case .string(let s) = o["aspect_id"] ?? .null { return s }; return "?" }()
                            let targetId = { if case .string(let s) = o["target_id"] ?? .null { return s }; return "?" }()
                            let dt = { if case .string(let s) = o["datetime_utc"] ?? .null { return s }; return "-" }()
                            Text("next exact in sign: \(aspectId) \(targetId) @ \(dt)")
                                .monospacedDigit()
                        }
                        if case .array(let rules) = moon?["void_of_course_rules"] {
                            ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                                if case .object(let ro) = rule {
                                    let rid = { if case .string(let s) = ro["rule_id"] ?? .null { return s }; return "?" }()
                                    let val: String = {
                                        if case .bool(let b) = ro["value"] ?? .null { return String(b) }
                                        if case .string(let s) = ro["value"] ?? .null { return s }
                                        return "-"
                                    }()
                                    Text("VOC \(rid): \(val)")
                                        .font(TS.Font.label)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HorarySectionCard(title: "Bodies (summary)") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        ForEach(result.bodies) { body in
                            Text("\(body.bodyId): \(body.displayEn) H\(body.integerHouse) \(body.motionState) \(body.eclipticSpeed.map { String(format: "%.4f°/d", $0) } ?? "")")
                                .monospacedDigit()
                        }
                    }
                }

                HorarySectionCard(title: "Events (window)") {
                    if result.events.isEmpty {
                        Text("none").foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: TS.Spacing.sm) {
                            ForEach(result.events.prefix(24)) { ev in
                                Text("\(ev.datetimeUtc ?? "-") \(ev.eventType ?? "-") \(ev.bodyIds.joined(separator: ","))")
                                    .font(TS.Font.label)
                                    .monospacedDigit()
                            }
                            if result.events.count > 24 {
                                Text("… \(result.events.count - 24) more")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                HorarySectionCard(title: "Validation") {
                    VStack(alignment: .leading, spacing: TS.Spacing.md) {
                        Text("forbidden_field_scan: \(result.validation.forbiddenFieldScan ?? "-")")
                        Text("bodies/aspects/events/lots: \(result.bodies.count)/\(result.aspects.count)/\(result.events.count)/\(result.lots.count)")
                        if !result.validation.warnings.isEmpty {
                            ForEach(result.validation.warnings, id: \.self) { w in
                                Text(w).font(TS.Font.label).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.trailing, 8)
        }
    }
}

struct HoraryBodiesTableView: View {
    let bodies: [HoraryV2EvidenceRow]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                ForEach(bodies) { b in
                    VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                        Text("\(b.nameZh) (\(b.bodyId))")
                            .font(TS.Font.sectionTitle)
                        Text("\(b.displayZh) · H\(b.integerHouse)")
                            .monospacedDigit()
                        Text("lon \(b.eclipticLongitude) lat \(b.eclipticLatitude.map { String($0) } ?? "-") speed \(b.eclipticSpeed.map { String(format: "%.6f", $0) } ?? "-")")
                            .font(TS.Font.label)
                            .monospacedDigit()
                        Text("motion \(b.motionState) · events_index=\(b.eventsIndex == nil ? "no" : "yes") · accidental=\(b.accidental == nil ? "no" : "yes")")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
            }
            .padding(TS.Padding.resultContent)
        }
    }
}

struct HoraryDignitiesView: View {
    let dignities: [HoraryV2EvidenceRow]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                Text("Dignities are assignment facts only (no scores).")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
                ForEach(dignities) { d in
                    Text(d.raw.prettyJSON.prefix(240))
                        .font(TS.Font.label)
                        .textSelection(.enabled)
                    Divider()
                }
            }
            .padding(TS.Padding.resultContent)
        }
    }
}

struct HoraryAspectsDataView: View {
    let aspects: [HoraryV2EvidenceRow]
    let receptions: [HoraryV2EvidenceRow]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.xl) {
                Text("Aspect candidates / hits").font(TS.Font.sectionTitle)
                if aspects.isEmpty {
                    Text("none").foregroundStyle(.secondary)
                } else {
                    ForEach(aspects.prefix(80)) { a in
                        Text("\(a.bodyAId ?? "?") \(a.aspectId ?? "?") \(a.bodyBId ?? "?") orb \(a.absoluteOrbDeg.map { String(format: "%.3f", $0) } ?? "-") \(a.application ?? "-") next \(a.nextExact?.datetimeUtc ?? "-") within_display=\(a.withinDisplayOrb.map { String($0) } ?? "-")")
                            .font(TS.Font.label)
                            .monospacedDigit()
                            .textSelection(.enabled)
                    }
                }
                Text("Receptions").font(TS.Font.sectionTitle)
                ForEach(receptions.prefix(80)) { r in
                    if let kind = r.relationKind {
                        Text("\(r.id): \(kind) \(r.bodyAId ?? "?")-\(r.bodyBId ?? "?") exact=\(r.relationAtNextAspectExact != nil ? "yes" : "n/a")")
                            .font(TS.Font.label)
                    } else {
                        Text("\(r.receiverId ?? "?") → \(r.receivedBodyId ?? "?") via \(r.dignityType ?? "?")")
                            .font(TS.Font.label)
                    }
                }
            }
            .padding(TS.Padding.resultContent)
        }
    }
}

struct HoraryLotsDataView: View {
    let lots: [HoraryV2EvidenceRow]
    let angles: [HoraryV2AnglePoint]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                Text("Angles").font(TS.Font.sectionTitle)
                ForEach(angles) { a in
                    Text("\(a.id): \(a.sign.displayEn) (\(a.longitudeDeg))")
                        .monospacedDigit()
                }
                Text("Lots").font(TS.Font.sectionTitle).padding(.top, TS.Spacing.lg)
                ForEach(lots) { lot in
                    VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                        Text("\(lot.names.zh) / \(lot.names.en) (\(lot.id))")
                        Text("\(lot.sign.displayEn) H\(lot.house.integerHouse) · \(lot.formulaUsed ?? "") · sect=\(lot.sectUsed ?? "-")")
                            .font(TS.Font.label)
                            .foregroundStyle(.secondary)
                        if lot.inputPoints != nil {
                            Text("input_points present · intermediates present=\(lot.intermediates == nil ? "no" : "yes")")
                                .font(TS.Font.label)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(TS.Padding.resultContent)
        }
    }
}

struct HoraryHousesDataView: View {
    let houses: HoraryV2Houses

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                Text("\(houses.system) (\(houses.systemLabel)) fallback=\(houses.fallbackApplied ? "yes" : "no")")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
                ForEach(houses.cusps) { h in
                    Text("H\(h.house): \(h.sign.displayEn) cusp \(h.cuspLongitudeDeg) span \(h.spanDeg.map { String(format: "%.3f", $0) } ?? "-") ruler \(h.domicileRulerId)")
                        .monospacedDigit()
                }
            }
            .padding(TS.Padding.resultContent)
        }
    }
}

struct HoraryDiagnosticsView: View {
    let result: HoraryDataPacket

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.xl) {
            Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
                GridRow {
                    Text("Schema").foregroundStyle(.secondary)
                    Text(result.schema.schemaId).monospaced()
                }
                GridRow {
                    Text("Local").foregroundStyle(.secondary)
                    Text(result.timeAndLocation.localDatetime).monospacedDigit()
                }
                GridRow {
                    Text("UTC").foregroundStyle(.secondary)
                    Text(result.timeAndLocation.utcDatetime).textSelection(.enabled)
                }
                GridRow {
                    Text("Place").foregroundStyle(.secondary)
                    Text(result.questionMetadata.placeName)
                }
                GridRow {
                    Text("Ephemeris").foregroundStyle(.secondary)
                    Text("\(result.provenance.ephemerisProvider) \(result.provenance.ephemerisVersion)")
                        .textSelection(.enabled)
                }
                GridRow {
                    Text("Hashes").foregroundStyle(.secondary)
                    Text("in=\(result.provenance.inputHashSha256.prefix(12))… cfg=\(result.provenance.configHashSha256.prefix(12))…")
                        .font(TS.Font.label)
                        .textSelection(.enabled)
                }
            }

            WarningList(warnings: result.validation.warnings)
            Spacer()
        }
        .padding(TS.Padding.resultContent)
    }
}

private struct HorarySectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text(title)
                .font(TS.Font.sectionTitle)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(TS.Padding.cardInner)
        .background(TS.SemanticColor.cardBackground, in: RoundedRectangle(cornerRadius: TS.Radius.card))
    }
}
