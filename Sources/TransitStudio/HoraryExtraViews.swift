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
                    Text(String(describing: moon).prefix(8000))
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
                    Text(pretty(value))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                } else {
                    Text("null / not present").foregroundStyle(.secondary)
                }
            }
            .padding(TS.Padding.resultContent)
        }
    }

    private func pretty(_ v: HoraryV2JSONValue, indent: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indent)
        switch v {
        case .null: return "null"
        case .bool(let b): return String(b)
        case .number(let n): return String(n)
        case .string(let s): return "\"\(s)\""
        case .array(let arr):
            if arr.isEmpty { return "[]" }
            let body = arr.prefix(40).map { pretty($0, indent: indent + 1) }.joined(separator: ",\n\(pad)  ")
            let more = arr.count > 40 ? "\n\(pad)  … +\(arr.count - 40) items" : ""
            return "[\n\(pad)  \(body)\(more)\n\(pad)]"
        case .object(let obj):
            let keys = obj.keys.sorted()
            let body = keys.prefix(60).map { k in "\(k): \(pretty(obj[k]!, indent: indent + 1))" }.joined(separator: ",\n\(pad)  ")
            let more = keys.count > 60 ? "\n\(pad)  … +\(keys.count - 60) keys" : ""
            return "{\n\(pad)  \(body)\(more)\n\(pad)}"
        }
    }
}

struct HoraryVisibilityTableView: View {
    let rows: [HoraryV2EvidenceRow]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                ForEach(rows) { v in
                    Text(String(describing: v.raw).prefix(500))
                        .font(TS.Font.label)
                        .textSelection(.enabled)
                    Divider()
                }
            }
            .padding(TS.Padding.resultContent)
        }
    }
}
