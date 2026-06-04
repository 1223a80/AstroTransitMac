import Foundation

enum MarkdownVedicExportBuilder {
    static let allSections = MarkdownExportBuilder.ExportSection.vedicSectionIDs

    static func export(_ result: VedicResult) -> String {
        export(result, sections: allSections)
    }

    static func export(_ result: VedicResult, sections: Set<MarkdownExportBuilder.ExportSection>) -> String {
        var md = "# 吠陀排盘 / Vedic Horoscope\n\n"
        md += "## 基本信息\n\n"
        md += "- 出生时间: \(result.meta.birthLocal)\n"
        md += "- 经纬度: \(result.meta.latitude)°, \(result.meta.longitude)°\n"
        md += "- Ayanāṃśa: \(result.meta.ayanamsha)\n"
        md += "- 宫位制: \(result.meta.houseSystem)\n\n"

        if sections.contains(.vedicRasi) {
            md += rasiSection(result)
        }
        if sections.contains(.vedicNavamsa) {
            md += navamsaSection(result)
        }
        if sections.contains(.vedicNakshatra) {
            md += nakshatraSection(result)
        }
        if sections.contains(.vedicDasa) {
            md += dasaSection(result)
        }
        if sections.contains(.vedicShadbala) {
            md += shadbalaSection(result)
        }
        if sections.contains(.vedicYoga) {
            md += yogaSection(result)
        }

        if let warnings = result.warnings, !warnings.isEmpty {
            md += "\n## 警告\n\n"
            for w in warnings {
                md += "- \(w)\n"
            }
        }

        return md
    }

    // MARK: - Rasi Chart

    static func rasiSection(_ result: VedicResult) -> String {
        guard let chart = result.rasiChart else { return "" }
        var md = "\n## Rāśi 盘 (D1)\n\n"

        // Angles
        md += "### 角点\n\n"
        md += "| 点 | 经度 | 星座 | 宫位 |\n"
        md += "|---|---|---|---|\n"
        for angle in chart.angles {
            md += "| \(angle.name) | \(angle.degreeText) | \(angle.sign) | \(angle.house) |\n"
        }
        md += "\n"

        // Houses
        md += "### 宫位\n\n"
        md += "| 宫位 | 星座 | 宫头 | 主星 |\n"
        md += "|---|---|---|---|\n"
        for house in chart.houses {
            md += "| \(house.house) | \(house.sign) | \(house.cuspText) | \(house.ruler) |\n"
        }
        md += "\n"

        // Planets — house from rasi_chart.planets, nakshatra from result.planets
        if let planets = result.planets {
            let chartPlanets = chart.planets
            md += "### 行星\n\n"
            md += "| 行星 | 经度 | 星座 | 宫位 | Nakṣatra | Pada | 主星 |\n"
            md += "|---|---|---|---|---|---|---|\n"
            for (pid, planet) in planets.sorted(by: { $0.value.longitude < $1.value.longitude }) {
                let nak = planet.nakshatra?.nakshatra
                let nakName = nak?.nameSa ?? "-"
                let pada = nak.map { "\($0.pada)" } ?? "-"
                let lord = nak?.lord ?? "-"
                let house = chartPlanets[pid]?.house ?? planet.house ?? 0
                md += "| \(pid) | \(planet.degreeText) | \(planet.sign) | \(house) | \(nakName) | \(pada) | \(lord) |\n"
            }
            md += "\n"
        }

        return md
    }

    // MARK: - Navamsa

    static func navamsaSection(_ result: VedicResult) -> String {
        guard let navamsa = result.navamsa else { return "" }
        var md = "\n## Navāṃśa (D9)\n\n"
        md += "| 行星 | D9 星座 |\n"
        md += "|---|---|\n"
        for (pid, pos) in navamsa.sorted(by: { $0.key < $1.key }) {
            md += "| \(pos.name) | \(pos.navamsaRasiName) |\n"
        }
        md += "\n"
        return md
    }

    // MARK: - Nakshatra

    static func nakshatraSection(_ result: VedicResult) -> String {
        guard let planets = result.planets else { return "" }
        var md = "\n## Nakṣatra 详情\n\n"
        md += "| 行星 | Nakṣatra | Pada | Lord | Yoni | Gaṇa | Nāḍī |\n"
        md += "|---|---|---|---|---|---|---|\n"

        for (pid, planet) in planets.sorted(by: { $0.value.longitude < $1.value.longitude }) {
            guard let details = planet.nakshatra else { continue }
            let nak = details.nakshatra
            let yoni = details.yoni?.nameZh ?? "-"
            let gana = details.gana?.nameZh ?? "-"
            let nadi = details.nadi?.nameZh ?? "-"
            md += "| \(pid) | \(nak.nameSa) | \(nak.pada) | \(nak.lord) | \(yoni) | \(gana) | \(nadi) |\n"
        }
        md += "\n"
        return md
    }

    // MARK: - Dasa

    static func dasaSection(_ result: VedicResult) -> String {
        guard let v = result.vimshottari else { return "" }
        var md = "\n## Vimśottarī Daśā\n\n"
        md += "出生 Nakṣatra: \(v.birthNakshatra)\n\n"

        md += "| 主星 | 起 | 止 | 年数 |\n"
        md += "|---|---|---|---|\n"
        for period in v.mahaDasas {
            let isCurrent = period.lord == v.currentMahadasa?.lord
                && period.start == v.currentMahadasa?.start
            let marker = isCurrent ? " ← 当前" : ""
            md += "| \(period.lord) | \(period.start.prefix(10)) | \(period.end.prefix(10)) | \(period.durationYears)\(marker) |\n"
        }
        md += "\n"

        // Yogini
        if let yogini = result.yoginiDasa {
            md += "### Yoginī Daśā\n\n"
            md += "| Yoginī | 起 | 止 |\n"
            md += "|---|---|---|\n"
            for period in yogini.yoginiDasas {
                let marker = period.yogini == yogini.currentYogini?.yogini ? " ← 当前" : ""
                md += "| \(period.yogini) | \(period.start.prefix(10)) | \(period.end.prefix(10))\(marker) |\n"
            }
            md += "\n"
        }

        // Ashtottari
        if let at = result.ashtottariDasa {
            md += "### Aṣṭottarī Daśā\n\n"
            md += "| 主星 | 起 | 止 |\n"
            md += "|---|---|---|\n"
            for period in at.ashtottariDasas {
                let marker = period.lord == at.currentAshtottari?.lord ? " ← 当前" : ""
                md += "| \(period.lord) | \(period.start.prefix(10)) | \(period.end.prefix(10))\(marker) |\n"
            }
            md += "\n"
        }

        return md
    }

    // MARK: - Shadbala

    static func shadbalaSection(_ result: VedicResult) -> String {
        guard let sb = result.shadbala else { return "" }
        var md = "\n## Ṣaḍbala 六力评分\n\n"
        md += "| 行星 | Sthāna | Dig | Kāla | Ceṣṭa | Naiṣargika | Dṛg | 总分 | Rūpa | 达标% |\n"
        md += "|---|---|---|---|---|---|---|---|---|---|\n"

        for pid in ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"] {
            guard let row = sb[pid] else { continue }
            md += "| \(pid) | \(Int(row.sthanaBala)) | \(Int(row.digBala)) | \(Int(row.kalaBala)) | \(Int(row.cheshtaBala)) | \(Int(row.naisargikaBala)) | \(Int(row.drigBala)) | \(Int(row.shadbalaTotal)) | \(String(format: "%.1f", row.shadbalaRupas)) | \(Int(row.percent))% |\n"
        }
        md += "\n"

        return md
    }

    // MARK: - Yoga

    static func yogaSection(_ result: VedicResult) -> String {
        guard let yogas = result.yogas, !yogas.isEmpty else { return "" }
        var md = "\n## Yōga 匹配\n\n"
        for yoga in yogas {
            md += "- **\(yoga.name)** (\(yoga.group)): \(yoga.description)\n"
            md += "  - 效应: \(yoga.effect)\n"
            md += "  - 行星: \(yoga.planets.joined(separator: ", "))\n\n"
        }
        return md
    }
}
