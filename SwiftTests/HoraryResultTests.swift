import Foundation
import Testing
@testable import TransitStudio

struct HoraryResultTests {
    @Test func jsonValuePrettyJSONIsReadableJSON() throws {
        // Structured value: stable key order, JSON-like braces, no enum reflection.
        let v = HoraryV2JSONValue.object([
            "b": .number(2.5),
            "a": .array([.string("x"), .bool(true)]),
            "c": .null,
            "d": .string("quote\"backslash\\newline\n"),
            "key\"newline\n": .string("value"),
        ])
        let text = v.prettyJSON
        #expect(text.hasPrefix("{\n"))
        #expect(text.contains("\"a\": [\n"))
        #expect(text.contains("\"b\": 2.5"))
        #expect(text.contains("null"))
        #expect(text.contains("\"d\": \"quote\\\"backslash\\\\newline\\n\""))
        #expect(text.contains("\"key\\\"newline\\n\": \"value\""))
        #expect(!text.contains("HoraryV2JSONValue"))
        #expect(text.range(of: "\"a\"")!.lowerBound < text.range(of: "\"b\"")!.lowerBound)
        let reparsed = try #require(
            JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any]
        )
        #expect(reparsed["key\"newline\n"] as? String == "value")

        // Fixture-backed value: description must render JSON, not enum debug text.
        let fixtureURL = Bundle.module.url(forResource: "horary-result", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "horary-result", withExtension: "json")
        let url = try #require(fixtureURL)
        let data = try Data(contentsOf: url)
        let result = try JSONDecoder().decode(HoraryDataPacket.self, from: data)
        let moon = try #require(result.moon)
        let described = String(describing: moon)
        #expect(described.hasPrefix("{"))
        #expect(!described.contains("object("))
        #expect(!described.contains("HoraryV2JSONValue"))
    }

    @Test func decodeHoraryDataPacketV2() throws {
        let fixtureURL = Bundle.module.url(forResource: "horary-result", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "horary-result", withExtension: "json")
        let url = try #require(fixtureURL)
        let data = try Data(contentsOf: url)
        let result = try JSONDecoder().decode(HoraryDataPacket.self, from: data)

        #expect(result.schema.schemaId.hasPrefix("horary-data-packet/2."))
        #expect(result.bodies.count == 7)
        #expect(result.houses.cusps.count == 12)
        #expect(result.validation.forbiddenFieldScan == "passed")
        #expect(!result.provenance.inputHashSha256.isEmpty)

        let markdown = MarkdownExportBuilder.horary(result)
        #expect(markdown.contains("horary-data-packet/2."))
        #expect(markdown.hasPrefix("# Horary 数据报告"))
        #expect(!markdown.contains("# Horary 分析提示词"))
        #expect(!markdown.contains(AIPromptDefaults.text(for: "horary")))
        #expect(markdown.contains("| 天体 | 位置 | 宫位 | 运动 |"))
        #expect(markdown.contains("| UTC | 类型 | 天体 | 相位 |"))
        #expect(markdown.contains("no_related_future_exact"))
        #expect(!markdown.contains("\"aspect_candidates\":"))
        #expect(!markdown.lowercased().contains("machine summary"))
        #expect(!markdown.lowercased().contains("significator candidates"))

        let wheel = ChartWheelData(horaryResult: result)
        #expect(wheel.points.contains(where: { $0.id == "SUN" || $0.id.contains("SUN") }))
        #expect(wheel.houseCusps.count == 12)
        #expect(wheel.aspects.count == (result.aspectsInDisplayOrb?.count ?? 0))
        #expect(result.aspectsInDisplayOrb?.allSatisfy {
            ($0.absoluteOrbDeg ?? .infinity) <= (result.displayOrbDeg ?? 0)
        } == true)
    }

    @Test func markdownAndCsvAreDataOnly() throws {
        let fixtureURL = Bundle.module.url(forResource: "horary-result", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "horary-result", withExtension: "json")
        let url = try #require(fixtureURL)
        let data = try Data(contentsOf: url)
        let result = try JSONDecoder().decode(HoraryDataPacket.self, from: data)
        let markdown = MarkdownExportBuilder.horary(result, prompt: "CUSTOM HORARY PROMPT")
        let dataOnlyMarkdown = MarkdownExportBuilder.horary(result, prompt: "  \n")
        let csv = TextExportBuilder.csv(result)
        #expect(markdown.hasPrefix("# Horary 分析提示词"))
        #expect(markdown.contains("CUSTOM HORARY PROMPT"))
        #expect(!markdown.contains(AIPromptDefaults.text(for: "horary")))
        #expect(dataOnlyMarkdown.hasPrefix("# Horary 数据报告"))
        #expect(!dataOnlyMarkdown.contains("# Horary 分析提示词"))
        #expect(markdown.utf8.count < 100_000)
        #expect(markdown.utf8.count < data.count / 10)
        #expect(!markdown.contains("{\""))
        #expect(markdown.contains("完整、无损的 v2.1 证据包请使用 JSON 导出"))
        #expect(csv.contains("schema"))
        #expect(!csv.contains("machine_summary"))
        #expect(!csv.contains("significator_candidate"))
        #expect(!csv.contains("advanced_candidate"))
        // CSV must not silently drop top-level v2 evidence sections (parity with Markdown/JSON).
        for section in [
            "pairwise_geometry", "event_graph", "nodes", "planetary_day_hour",
            "considerations_evidence", "optional_modules", "moon",
        ] {
            #expect(csv.contains(section), "CSV missing section \(section)")
        }
        // Moon content is more than a present/null flag.
        #expect(csv.contains("\"phase_angle_deg\"") || csv.contains("void_of_course") || csv.contains("sign_exit"))
        #expect(csv.contains("\"longitude_decimals\""))
        #expect(csv.contains("\"angle_decimals\""))
    }

    @Test func evidenceRowIdIsStable() throws {
        let fixtureURL = Bundle.module.url(forResource: "horary-result", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "horary-result", withExtension: "json")
        let url = try #require(fixtureURL)
        let data = try Data(contentsOf: url)
        let result = try JSONDecoder().decode(HoraryDataPacket.self, from: data)
        #expect(!result.bodies.isEmpty)
        let first = result.bodies[0].id
        let second = result.bodies[0].id
        #expect(first == second)
        #expect(first == (result.bodies[0].string("body_id") ?? first))
        #expect(!first.isEmpty)
        #expect(!first.contains("-") || first.count < 40 || first == result.bodies[0].string("id") ?? "")
        // Prefer body_id over random UUID (UUIDs contain hyphens and are 36 chars).
        if result.bodies[0].string("id") == nil {
            #expect(first == result.bodies[0].string("body_id"))
        }
    }

    @Test func jsonSwiftRoundTripPreservesEvidenceKeys() throws {
        let fixtureURL = Bundle.module.url(forResource: "horary-result", withExtension: "json", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "horary-result", withExtension: "json")
        let url = try #require(fixtureURL)
        let raw = try Data(contentsOf: url)
        let sourceObj = try #require(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        let decoded = try JSONDecoder().decode(HoraryDataPacket.self, from: raw)
        let reencoded = try JSONEncoder().encode(decoded)
        let obj = try #require(JSONSerialization.jsonObject(with: reencoded) as? [String: Any])

        // Deep key-walk: every source path in the canonical packet must survive
        // decode→encode, including typed UI projections such as houses/angles.
        for (root, src) in sourceObj {
            let dst = obj[root]
            #expect(dst != nil, "missing root after round-trip: \(root)")
            if let dst {
                let missing = deepMissingKeys(source: src, dest: dst, path: root)
                #expect(missing.isEmpty, "lost keys: \(missing.prefix(20))")
            }
        }

        // Explicit fidelity anchors (skeptic gates)
        let tl = try #require(obj["time_and_location"] as? [String: Any])
        #expect(tl["geocoding"] != nil)
        let sect = try #require(tl["sect"] as? [String: Any])
        #expect(sect["evidence"] != nil)
        let prov = try #require(obj["provenance"] as? [String: Any])
        #expect(prov["aberration_light_time"] != nil)
        #expect(prov["precession_nutation"] != nil)
        let cfg = try #require(obj["calculation_config"] as? [String: Any])
        #expect(cfg["numeric_precision"] != nil)
        #expect(cfg["aspects_enabled"] != nil)
        let houses = try #require(obj["houses"] as? [String: Any])
        let cusps = try #require(houses["cusps"] as? [[String: Any]])
        #expect(cusps.first?["domicile_ruler_en"] != nil)
        #expect(cusps.first?["domicile_ruler_zh"] != nil)
        let angles = try #require(obj["angles"] as? [String: Any])
        let armc = try #require(angles["armc"] as? [String: Any])
        #expect(armc["unit"] != nil)
        #expect(armc["definition"] != nil)
        let validation = try #require(obj["validation"] as? [String: Any])
        #expect(validation["aspect_candidate_count"] != nil)
        #expect(validation["aspects_in_display_orb_count"] != nil)
        let display = try #require(obj["display"] as? [String: Any])
        #expect(display["notes"] != nil)

        // Reception exact/pre-exit evidence must survive
        let recs = try #require(obj["receptions"] as? [[String: Any]])
        let withExact = recs.filter { $0["relation_at_next_aspect_exact"] != nil }
        #expect(!withExact.isEmpty)
        #expect(withExact.contains { ($0["relation_at_next_aspect_exact"] as? [String: Any])?["status"] != nil })
        #expect(recs.contains { $0["relation_changes_if_sign_exit_before_exact"] != nil })

        // Lots input_points / intermediates / pre-normalize
        let lots = try #require(obj["lots"] as? [[String: Any]])
        #expect(lots.contains { $0["input_points"] != nil })
        #expect(lots.contains { $0["intermediates"] != nil })
        #expect(lots.contains { $0["longitude_before_normalize_deg"] != nil })

        let bodies = try #require(obj["bodies"] as? [[String: Any]])
        let moon = try #require(bodies.first { ($0["body_id"] as? String) == "MOON" })
        let idx = try #require(moon["events_index"] as? [String: Any])
        #expect(idx["previous_house_change"] != nil)
        #expect((idx["previous_house_change"] as? [String: Any])?["event_id"] != nil
            || (idx["previous_house_change"] as? NSNull) == nil)

        let md = MarkdownExportBuilder.horary(decoded)
        #expect(md.contains("## 接纳"))
        #expect(md.contains("## Lots"))
        #expect(md.contains("## 月亮进程与 VOC"))
        #expect(md.contains("## 行星日与行星时"))
        #expect(md.contains("## 月交点"))
        #expect(md.contains("## 可选模块重点"))
        #expect(md.contains("## 数据校验"))
        #expect(md.contains("完整、无损的 v2.1 证据包请使用 JSON 导出"))
        #expect(md.utf8.count < raw.count / 10)
        #expect(!md.contains("(full evidence)"))
        #expect(!md.contains("{\""))
        #expect(!md.lowercased().contains("machine summary"))
    }

    /// Returns paths present in source but missing (or wrong JSON type class) in dest.
    private func deepMissingKeys(source: Any, dest: Any, path: String) -> [String] {
        var missing: [String] = []
        if let sDict = source as? [String: Any] {
            guard let dDict = dest as? [String: Any] else {
                return [path + " (expected object)"]
            }
            for (k, sv) in sDict {
                let p = path + "." + k
                guard let dv = dDict[k] else {
                    missing.append(p)
                    continue
                }
                missing.append(contentsOf: deepMissingKeys(source: sv, dest: dv, path: p))
            }
        } else if let sArr = source as? [Any] {
            guard let dArr = dest as? [Any] else {
                return [path + " (expected array)"]
            }
            // Compare by index for arrays of objects with id when possible
            let n = min(sArr.count, dArr.count)
            for i in 0..<n {
                missing.append(contentsOf: deepMissingKeys(source: sArr[i], dest: dArr[i], path: "\(path)[\(i)]"))
            }
            if sArr.count > dArr.count {
                missing.append("\(path) (array shortened \(sArr.count)->\(dArr.count))")
            }
        }
        // scalars: presence is enough
        return missing
    }
}
