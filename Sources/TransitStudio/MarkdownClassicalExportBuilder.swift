import Foundation

extension MarkdownExportBuilder {
    static func classical(_ result: ClassicalResult) -> String {
        var lines: [String] = [
            "# 本命盘 / 古典分析",
            "",
            "## 元数据",
            "",
            "- 出生 UTC：\(result.meta.birthUTC)",
            "- 参考 UTC：\(result.meta.referenceUTC)",
            "- 昼夜：\(result.meta.sect)",
            "- 宫制：\(result.meta.houseSystem)",
            "- 黄道：\(result.meta.zodiac)",
            "- 界：\(result.meta.boundsSystem)",
            "- 三分主：\(result.meta.triplicitySystem)",
            "- 星历：\(result.meta.ephemeris)",
            ""
        ]

        lines += pointSection("角点", result.angles)
        lines += houseSection(result.houses)
        lines += planetSection(result.planets)
        lines += scoreSummarySection(result.planets)
        lines += triplicitySummarySection(result.planets)
        lines += pointSection("Lots", result.lots)
        lines += classicalAspectSection(result.aspects)
        let bodyNames = classicalBodyNameLookup(result.planets)
        if let declinationAspects = result.declinationAspects {
            lines += declinationAspectSection(declinationAspects, names: bodyNames)
        }
        lines += receptionSection(result.receptions)
        if let starConjunctions = result.natalStarConjunctions {
            lines += fixedStarSection("固定星合相", starConjunctions, names: bodyNames)
        }
        if let antiscia = result.antiscia, !antiscia.isEmpty {
            lines += antisciaSection(antiscia)
        }
        if let pd = result.primaryDirections, !pd.isEmpty {
            lines += primaryDirectionSection(pd)
        }
        if let circ = result.circumambulations, !circ.isEmpty {
            lines += circumambulationSection(circ)
        }
        lines += activeOverviewSection(result)
        lines += timingSection(result.timing, planetaryReturns: result.planetaryReturns)
        lines += timelineTableSection(result.timing.timeline)
        if let almuten = result.almutenFiguris {
            lines += almutenSection(almuten)
        }
        if let hyleg = result.hylegAlcocoden {
            lines += hylegSection(hyleg)
        }
        if let syzygy = result.prenatalSyzygy {
            lines += prenatalSyzygySection(syzygy)
        }
        if let medieval = result.medieval {
            lines += medievalSection(medieval)
        }
        lines += warnings(result.warnings)
        lines += sectionErrorBlock(result.sectionErrors)
        return lines.joined(separator: "\n")
    }

    static func classical(_ result: ClassicalResult, sections: Set<ExportSection>) -> String {
        var lines: [String] = [
            "# 本命盘 / 古典分析",
            "",
            "## 元数据",
            "",
            "- 出生 UTC：\(result.meta.birthUTC)",
            "- 参考 UTC：\(result.meta.referenceUTC)",
            "- 昼夜：\(result.meta.sect)",
            "- 宫制：\(result.meta.houseSystem)",
            "- 黄道：\(result.meta.zodiac)",
            "- 界：\(result.meta.boundsSystem)",
            "- 三分主：\(result.meta.triplicitySystem)",
            "- 星历：\(result.meta.ephemeris)",
            ""
        ]

        if sections.contains(.angles) { lines += pointSection("角点", result.angles) }
        if sections.contains(.houses) { lines += houseSection(result.houses) }
        if sections.contains(.planets) { lines += planetSection(result.planets) }
        if sections.contains(.scoreSummary) { lines += scoreSummarySection(result.planets) }
        if sections.contains(.triplicitySummary) { lines += triplicitySummarySection(result.planets) }
        if sections.contains(.lots) { lines += pointSection("Lots", result.lots) }
        if sections.contains(.aspects) { lines += classicalAspectSection(result.aspects) }
        let bodyNames = classicalBodyNameLookup(result.planets)
        if sections.contains(.declinationAspects), let da = result.declinationAspects {
            lines += declinationAspectSection(da, names: bodyNames)
        }
        if sections.contains(.receptions) { lines += receptionSection(result.receptions) }
        if sections.contains(.fixedStars), let stars = result.natalStarConjunctions {
            lines += fixedStarSection("固定星合相", stars, names: bodyNames)
        }
        if sections.contains(.antiscia), let a = result.antiscia, !a.isEmpty { lines += antisciaSection(a) }
        if sections.contains(.primaryDirections), let pd = result.primaryDirections, !pd.isEmpty { lines += primaryDirectionSection(pd) }
        if sections.contains(.circumambulations), let circ = result.circumambulations, !circ.isEmpty { lines += circumambulationSection(circ) }
        if sections.contains(.activeOverview) { lines += activeOverviewSection(result) }
        if sections.intersection([.profection, .firdaria, .decennials, .zr, .returns, .timeline]).count > 1 {
            lines += timingSection(result.timing, planetaryReturns: result.planetaryReturns)
        } else {
            if sections.contains(.profection) { lines += timingSubsection("profections", result.timing, result.planetaryReturns) }
            if sections.contains(.firdaria) { lines += timingSubsection("firdaria", result.timing, result.planetaryReturns) }
            if sections.contains(.decennials) { lines += timingSubsection("decennials", result.timing, result.planetaryReturns) }
            if sections.contains(.zr) { lines += timingSubsection("zr", result.timing, result.planetaryReturns) }
            if sections.contains(.returns) { lines += timingSubsection("returns", result.timing, result.planetaryReturns) }
        }
        if sections.contains(.timeline) { lines += timelineTableSection(result.timing.timeline) }
        if sections.contains(.almuten), let a = result.almutenFiguris { lines += almutenSection(a) }
        if sections.contains(.hyleg), let h = result.hylegAlcocoden { lines += hylegSection(h) }
        if sections.contains(.prenatalSyzygy), let s = result.prenatalSyzygy { lines += prenatalSyzygySection(s) }
        if sections.contains(.medieval), let medieval = result.medieval { lines += medievalSection(medieval) }
        if sections.contains(.warnings) {
            lines += warnings(result.warnings)
            lines += sectionErrorBlock(result.sectionErrors)
        }
        return lines.joined(separator: "\n")
    }
}
