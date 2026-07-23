import Foundation

// MARK: - Expansion Markdown section catalog (design §2.3 · PR8)

struct ExpansionMarkdownSection: Hashable, Identifiable {
    let id: String
    let title: String
    /// Substrings matched against `## ` headers in generated markdown.
    let headerMatchers: [String]

    init(id: String, title: String, headerMatchers: [String]? = nil) {
        self.id = id
        self.title = title
        self.headerMatchers = headerMatchers ?? [title]
    }
}

enum ExpansionExportCatalog {
    /// Per-mode section ids from design §2.3.
    static func sections(for mode: ModernSubMode) -> [ExpansionMarkdownSection] {
        switch mode {
        case .declinationTiming:
            return [
                .init(id: "events", title: "赤纬事件", headerMatchers: ["赤纬事件", "Events", "事件"]),
                .init(id: "stations", title: "赤纬停滞", headerMatchers: ["赤纬停滞", "Stations", "停滞"]),
                .init(id: "oob", title: "OOB", headerMatchers: ["OOB", "out of bounds", "越界"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设", "Assumptions"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors", "未计算"]),
            ]
        case .retrogradeCycles:
            return [
                .init(id: "cycles", title: "逆行周期", headerMatchers: ["逆行", "周期", "Cycles"]),
                .init(id: "stations", title: "站度", headerMatchers: ["站度", "Stations"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors"]),
            ]
        case .planetarySynodic:
            return [
                .init(id: "events", title: "相位事件", headerMatchers: ["相位", "事件", "Events"]),
                .init(id: "cycles", title: "会合周期", headerMatchers: ["会合", "周期", "Cycles"]),
                .init(id: "contacts", title: "本命接触", headerMatchers: ["本命接触", "Contacts"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors"]),
            ]
        case .classicalVisibility:
            return [
                .init(id: "heliacal", title: "偕日升降", headerMatchers: ["偕日", "heliacal"]),
                .init(id: "rise_set", title: "升落", headerMatchers: ["升落", "rise", "set"]),
                .init(id: "hours", title: "行星时", headerMatchers: ["行星时", "hour"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors"]),
            ]
        case .hellenisticConditionAudit:
            return [
                .init(id: "conditions", title: "条件证据", headerMatchers: ["条件", "证据", "Condition"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设", "输入与方法"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors", "未计算"]),
            ]
        case .classicalDerivatives:
            return [
                .init(id: "dodeka", title: "十二分盘", headerMatchers: ["十二分", "dodeka", "Dodekatemoria"]),
                .init(id: "monomoiria", title: "一度主", headerMatchers: ["一度", "monomoiria", "Monomoiria"]),
                .init(id: "topical", title: "主题 Almuten", headerMatchers: ["主题", "Almuten", "topical"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors"]),
            ]
        case .timeLordsExtended:
            return [
                .init(id: "concordance", title: "技法汇合", headerMatchers: ["concordance", "Concordance", "汇合", "Revolutions"]),
                .init(id: "daily", title: "日小限", headerMatchers: ["日小限", "Daily", "daily"]),
                .init(id: "zr", title: "ZR", headerMatchers: ["Zodiacal", "ZR", "Releasing"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设", "输入与方法"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors"]),
            ]
        case .methodFamilies:
            return [
                .init(id: "profiles", title: "次限角点", headerMatchers: ["次限", "profile", "Profiles", "progression"]),
                .init(id: "solar_arc", title: "太阳弧", headerMatchers: ["太阳弧", "solar arc", "Solar"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors"]),
            ]
        case .primaryDirectionsAudit:
            return [
                .init(id: "audit", title: "主限表", headerMatchers: ["主限", "Directions", "方向", "审计"]),
                .init(id: "algorithm", title: "算法说明", headerMatchers: ["Algorithm", "算法", "algorithm"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设", "输入与方法"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors"]),
            ]
        case .distributionsPd:
            return [
                .init(id: "distributions", title: "沿界", headerMatchers: ["沿界", "Distribution", "circumamb"]),
                .init(id: "pd_profiles", title: "主限多配置", headerMatchers: ["主限", "profile", "PD", "primary"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors"]),
            ]
        case .prenatalParans:
            return [
                .init(id: "packet", title: "朔望包", headerMatchers: ["朔望", "packet", "Prenatal", "syzygy"]),
                .init(id: "parans", title: "Parans 代理", headerMatchers: ["Paran", "恒星", "fixed star"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors"]),
            ]
        case .orbitalDial:
            return [
                .init(id: "dial", title: "轨道点", headerMatchers: ["轨道", "Dial", "nodes", "apsides"]),
                .init(id: "pictures", title: "行星图", headerMatchers: ["行星图", "picture", "Pictures"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors"]),
            ]
        case .mundaneElectional:
            return [
                .init(id: "ingresses", title: "入宫", headerMatchers: ["入宫", "Ingress", "ingress"]),
                .init(id: "candidates", title: "择时事实", headerMatchers: ["择时", "候选", "Candidate", "election"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors"]),
            ]
        case .draconicHeliocentric:
            return [
                .init(id: "draconic", title: "Draconic", headerMatchers: ["Draconic", "draconic"]),
                .init(id: "heliocentric", title: "日心", headerMatchers: ["日心", "heliocentric", "Heliocentric"]),
                .init(id: "compare", title: "对照", headerMatchers: ["对照", "compare", "Compare"]),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings", "section_errors"]),
            ]
        default:
            return [
                .init(id: "body", title: "正文", headerMatchers: []),
                .init(id: "assumptions", title: "计算假设", headerMatchers: ["计算假设", "假设"]),
                .init(id: "warnings", title: "警告", headerMatchers: ["警告", "Warnings"]),
            ]
        }
    }

    static func allSectionIDs(for mode: ModernSubMode) -> Set<String> {
        Set(sections(for: mode).map(\.id))
    }

    /// Full markdown for a stored expansion result (existing builders).
    static func fullMarkdown(mode: ModernSubMode, data: ModernResultData) -> String? {
        switch (mode, data) {
        case (.classicalVisibility, .classicalVisibility(let r)):
            return MarkdownExportBuilder.classicalVisibility(r)
        case (.hellenisticConditionAudit, .hellenisticConditionAudit(let r)):
            return MarkdownExportBuilder.hellenisticConditionAudit(r)
        case (.classicalDerivatives, .classicalDerivatives(let r)):
            return MarkdownExportBuilder.classicalDerivatives(r)
        case (.timeLordsExtended, .timeLordsExtended(let r)):
            return MarkdownExportBuilder.timeLordsExtended(r)
        case (.primaryDirectionsAudit, .primaryDirectionsAudit(let r)):
            return MarkdownExportBuilder.primaryDirectionsAudit(r)
        case (.distributionsPd, .distributionsPd(let r)):
            return MarkdownExportBuilder.distributionsPd(r)
        case (.prenatalParans, .prenatalParans(let r)):
            return MarkdownExportBuilder.prenatalParans(r)
        case (.mundaneElectional, .mundaneElectional(let r)):
            return MarkdownExportBuilder.mundaneElectional(r)
        case (.declinationTiming, .declinationTiming(let r)):
            return MarkdownExportBuilder.declinationTiming(r)
        case (.retrogradeCycles, .retrogradeCycles(let r)):
            return MarkdownExportBuilder.retrogradeCycles(r)
        case (.planetarySynodic, .planetarySynodic(let r)):
            return MarkdownExportBuilder.planetarySynodic(r)
        case (.draconicHeliocentric, .draconicHeliocentric(let r)):
            return MarkdownExportBuilder.draconicHeliocentric(r)
        case (.methodFamilies, .methodFamilies(let r)):
            return MarkdownExportBuilder.methodFamilies(r)
        case (.orbitalDial, .orbitalDial(let r)):
            return MarkdownExportBuilder.orbitalDial(r)
        default:
            return nil
        }
    }

    /// Filter full markdown to selected section ids (keeps H1 + matched H2 blocks).
    static func filterMarkdown(_ full: String, mode: ModernSubMode, selectedSectionIDs: Set<String>) -> String {
        let catalog = sections(for: mode)
        let selected = catalog.filter { selectedSectionIDs.contains($0.id) }
        if selected.isEmpty { return "" }
        if selected.count == catalog.count { return full }

        let lines = full.components(separatedBy: "\n")
        var blocks: [(header: String, body: [String])] = []
        var currentHeader = ""
        var currentBody: [String] = []
        var preamble: [String] = []
        var seenH2 = false

        func flush() {
            if seenH2 {
                blocks.append((currentHeader, currentBody))
            } else {
                preamble.append(contentsOf: currentBody)
            }
            currentBody = []
        }

        for line in lines {
            if line.hasPrefix("## ") {
                flush()
                seenH2 = true
                currentHeader = line
            } else {
                currentBody.append(line)
            }
        }
        flush()

        var out: [String] = preamble
        if out.last != "" { out.append("") }

        for block in blocks {
            let headerText = block.header
            let keep = selected.contains { section in
                section.headerMatchers.contains { matcher in
                    headerText.range(of: matcher, options: .caseInsensitive) != nil
                }
            }
            if keep {
                out.append(headerText)
                out.append(contentsOf: block.body)
            }
        }
        return out.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    /// Merge multiple classical-expansion mode results into one Markdown document.
    static func mergeClassicalExpansionMarkdown(
        results: [ModernSubMode: ModernResultData],
        modeSections: [ModernSubMode: Set<String>]
    ) -> String {
        var lines = ["# 古典进阶合并导出", ""]
        let ordered = ClassicalExpansionCatalog.modes.filter { results[$0] != nil }
        for mode in ordered {
            guard let data = results[mode] else { continue }
            let selected = modeSections[mode] ?? allSectionIDs(for: mode)
            guard !selected.isEmpty else { continue }
            guard let full = fullMarkdown(mode: mode, data: data) else { continue }
            let filtered = filterMarkdown(full, mode: mode, selectedSectionIDs: selected)
            lines.append("## \(mode.title)")
            lines.append("")
            // Demote internal H1 to H3 so mode title stays H2.
            let demoted = filtered
                .components(separatedBy: "\n")
                .map { line -> String in
                    if line.hasPrefix("# ") && !line.hasPrefix("## ") {
                        return "### " + line.dropFirst(2)
                    }
                    if line.hasPrefix("## ") {
                        return "###" + line.dropFirst(2)
                    }
                    return line
                }
                .joined(separator: "\n")
            lines.append(demoted.trimmingCharacters(in: .whitespacesAndNewlines))
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - ModernResultData ↔ expansion mode

extension ModernResultData {
    /// If this payload is one of the eight classical-expansion modes, return that mode.
    var classicalExpansionMode: ModernSubMode? {
        switch self {
        case .classicalVisibility: return .classicalVisibility
        case .hellenisticConditionAudit: return .hellenisticConditionAudit
        case .classicalDerivatives: return .classicalDerivatives
        case .timeLordsExtended: return .timeLordsExtended
        case .primaryDirectionsAudit: return .primaryDirectionsAudit
        case .distributionsPd: return .distributionsPd
        case .prenatalParans: return .prenatalParans
        case .mundaneElectional: return .mundaneElectional
        default: return nil
        }
    }
}
