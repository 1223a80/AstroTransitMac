import SwiftUI

/// Lightweight data surfaces for Horary v2.1 tabs (judgment-free lists).
struct HoraryEventsTimelineView: View {
    let result: HoraryDataPacket

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                Text("Events (\(result.events.count))")
                    .font(TS.Font.sectionTitle)
                ForEach(result.events.prefix(80)) { ev in
                    Text("\(ev.datetimeUtc ?? "-") | \(ev.eventType ?? "-") | \(ev.bodyIds.joined(separator: ",")) | \(ev.offsetSecondsFromQuery.map { String($0) } ?? "-")s")
                        .font(TS.Font.label)
                        .monospacedDigit()
                        .textSelection(.enabled)
                }
                if result.events.count > 80 {
                    Text("… \(result.events.count - 80) more in JSON")
                        .foregroundStyle(.secondary)
                }
                if result.eventGraph != nil {
                    Divider()
                    Text("event_graph present (full sequences in JSON / full Markdown)")
                        .font(TS.Font.label)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(TS.Padding.resultContent)
        }
    }
}

struct HoraryMoonDataView: View {
    let moon: HoraryV2JSONValue?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                Text("Moon index (full JSON)")
                    .font(TS.Font.sectionTitle)
                if let moon {
                    Text((moon.prettyJSON).prefix(8000))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text("null").foregroundStyle(.secondary)
                }
            }
            .padding(TS.Padding.resultContent)
        }
    }
}

struct HoraryJSONBlockView: View {
    let title: String
    let value: HoraryV2JSONValue?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                Text(title).font(TS.Font.sectionTitle)
                if let value {
                    Text(value.prettyJSON)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text("null / not present").foregroundStyle(.secondary)
                }
            }
            .padding(TS.Padding.resultContent)
        }
    }
}

struct HoraryVisibilityTableView: View {
    let rows: [HoraryV2EvidenceRow]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                ForEach(rows) { v in
                    Text(v.raw.prettyJSON.prefix(500))
                        .font(TS.Font.label)
                        .textSelection(.enabled)
                    Divider()
                }
            }
            .padding(TS.Padding.resultContent)
        }
    }
}
