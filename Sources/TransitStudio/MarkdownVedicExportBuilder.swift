import Foundation

enum MarkdownVedicExportBuilder {
    static let allSections = MarkdownExportBuilder.ExportSection.vedicSectionIDs

    static func export(_ result: VedicResult) -> String {
        export(result, sections: allSections)
    }

    static func export(_ result: VedicResult, sections: Set<MarkdownExportBuilder.ExportSection>) -> String {
        var md = "# 吠陀排盘 / Vedic Horoscope\n\n"

        // Always include basic info and settings
        md += basicInfoSection(result)
        md += settingsSection(result)

        if sections.contains(.signIndex) {
            md += signIndexSection(result)
        }
        if sections.contains(.panchanga) {
            md += panchangaSection(result)
        }
        if sections.contains(.solarDay) {
            md += solarDaySection(result)
        }
        if sections.contains(.vedicDivisional) {
            md += divisionalSection(result)
        }
        if sections.contains(.moonChart) {
            md += moonChartSection(result)
        }
        if sections.contains(.bhavaChart) {
            md += bhavaChartSection(result)
        }
        if sections.contains(.vedicRasi) {
            md += rasiSection(result)
        }
        if sections.contains(.planetRelationships) {
            md += relationshipsSection(result)
        }
        if sections.contains(.arudha) {
            md += arudhaSection(result)
        }
        if sections.contains(.vedicYoga) {
            md += yogaSection(result)
        }
        if sections.contains(.jaiminiKarakas) {
            md += jaiminiSection(result)
        }
        if sections.contains(.ashtakavarga) {
            md += ashtakavargaSection(result)
        }
        if sections.contains(.vedicDasa) {
            md += dasaSection(result)
        }
        if sections.contains(.vedicShadbala) {
            md += shadbalaSection(result)
        }

        if let warnings = result.warnings, !warnings.isEmpty {
            md += warningsSection(warnings)
        }

        return md
    }

    // MARK: - Basic Info

    static func basicInfoSection(_ result: VedicResult) -> String {
        var md = "## 基本信息\n\n"
        md += "- 出生本地时间: \(result.meta.birthLocal)\n"
        md += "- 出生 UTC: \(result.meta.birthUtc)\n"
        if let ref = result.meta.referenceLocal {
            md += "- 参考本地时间: \(ref)\n"
        }
        if let refUtc = result.meta.referenceUtc {
            md += "- 参考 UTC: \(refUtc)\n"
        }
        md += "- 经纬度: \(result.meta.longitude), \(result.meta.latitude)\n"
        if let tz = result.meta.timezoneLabel {
            md += "- 时区: \(tz)\n"
        }
        if let utc = result.meta.utcOffsetText {
            md += "- UTC偏移: \(utc)\n"
        }
        md += "\n"
        return md
    }

    // MARK: - Settings

    static func settingsSection(_ result: VedicResult) -> String {
        var md = "## 重要设置\n\n"
        md += "- 黄道制: \(result.meta.zodiac == "sidereal" ? "恒星黄道" : "回归黄道")\n"
        if let sml = result.meta.siderealModeLabel {
            md += "- 岁差名: \(sml)\n"
        }
        if let av = result.meta.ayanamshaValue {
            md += "- 岁差值: \(String(format: "%.6f", av))\n"
        }
        if let nm = result.meta.nodeMode {
            md += "- 交点算法: \(nm)\n"
        }
        if let ppm = result.meta.planetPositionMode {
            md += "- 行星位置算法: \(ppm)\n"
        }
        md += "- 宫位制: \(result.meta.houseSystem)\n"
        md += "- 星历: \(result.meta.ephemeris)\n\n"
        return md
    }

    // MARK: - Sign Index

    static func signIndexSection(_ result: VedicResult) -> String {
        guard let table = result.meta.signIndexTable, !table.isEmpty else { return "" }
        var md = "## 星座索引表\n\n"
        let entries = table.map { "\($0.nameEn)(\($0.nameZh))" }.joined(separator: ", ")
        md += "\(entries)\n\n"
        return md
    }

    // MARK: - Panchanga

    static func panchangaSection(_ result: VedicResult) -> String {
        guard let p = result.panchanga else { return "" }
        var md = "## 五支历 Panchanga (D1)\n\n"
        md += "- Tithi: \(p.tithi.nameZh) [Index:\(p.tithi.index), Start:\(String(format: "%.2f", p.tithi.startLongitude)), End:\(String(format: "%.2f", p.tithi.endLongitude))]\n"
        md += "- Vara: \(p.vara.nameZh) [Index:\(p.vara.index), Start:\(String(format: "%.2f", p.vara.startLongitude)), End:\(String(format: "%.2f", p.vara.endLongitude))]\n"
        md += "- Nakshatra: \(p.nakshatra.nameZh) [Index:\(p.nakshatra.index), Start:\(String(format: "%.2f", p.nakshatra.startLongitude)), End:\(String(format: "%.2f", p.nakshatra.endLongitude))]\n"
        md += "- Yoga: \(p.yoga.nameZh) [Index:\(p.yoga.index), Start:\(String(format: "%.2f", p.yoga.startLongitude)), End:\(String(format: "%.2f", p.yoga.endLongitude))]\n"
        md += "- Karana: \(p.karana.nameZh) [Index:\(p.karana.index), Start:\(String(format: "%.2f", p.karana.startLongitude)), End:\(String(format: "%.2f", p.karana.endLongitude))]\n\n"
        return md
    }

    // MARK: - Solar Day

    static func solarDaySection(_ result: VedicResult) -> String {
        guard let sd = result.solarDay else { return "" }
        var md = "## 日出日落\n\n"
        md += "- 日出: \(sd.sunriseLocal ?? "-")\n"
        md += "- 日落: \(sd.sunsetLocal ?? "-")\n\n"
        return md
    }

    // MARK: - Divisional Charts

    static func divisionalSection(_ result: VedicResult) -> String {
        guard let charts = result.divisionalCharts, !charts.isEmpty else { return "" }
        var md = "## 分盘信息\n\n"

        let orderedDivisional = ["D1", "D2", "D3", "D4", "D7", "D9", "D10", "D12",
                                 "D16", "D20", "D24", "D27", "D30", "D40", "D45", "D60"]

        for divId in orderedDivisional {
            guard let chart = charts[divId] else { continue }
            md += "\(divId) (\(chart.chartName)):\n"
            md += "  主星:\n"

            // Sort planets by longitude
            let sortedPlanets = chart.planets.sorted { a, b in
                a.value.longitude < b.value.longitude
            }

            for (_, planet) in sortedPlanets {
                let signName = planet.vargaRasiSign
                let house = planet.house ?? 0
                let nak = planet.nakshatra
                let nakStr = nak.map { "\($0.nameSa) Pada:\($0.pada) Lord:\($0.lord)" } ?? ""
                md += "    - \(planet.name) 星座:\(signName) 宫位:\(house) 度数:\(planet.degreeText) \(nakStr)\n"
            }

            // Upagrahas and special lagnas for D1 and D9
            if let upas = chart.upagrahas, !upas.isEmpty {
                md += "  虚点(Upagrahas):\n"
                for upa in upas {
                    md += "    - \(upa.nameSa) 星座:\(upa.rasiName)\n"
                }
            }
            if let lagnas = chart.specialLagnas, !lagnas.isEmpty {
                md += "  其他Lagna:\n"
                for lagna in lagnas {
                    md += "    - \(lagna.nameSa) 星座:\(lagna.rasi)\n"
                }
            }
            md += "\n"
        }
        return md
    }

    // MARK: - Moon Chart

    static func moonChartSection(_ result: VedicResult) -> String {
        guard let mc = result.moonChart else { return "" }
        var md = "## Moon 盘 (Moon Chart)\n\n"
        md += "  主星:\n"
        for (pid, planet) in mc.planets.sorted(by: { $0.value.longitude < $1.value.longitude }) {
            let nak = planet.nakshatra
            let nakStr = nak.map { "\($0.nameSa) Pada:\($0.pada) Lord:\($0.lord)" } ?? ""
            md += "    - \(pid) 星座:\(planet.rasiName) 度数:\(planet.degreeText) \(nakStr)\n"
        }
        md += "\n"
        return md
    }

    // MARK: - Bhava Chart

    static func bhavaChartSection(_ result: VedicResult) -> String {
        guard let bc = result.bhavaChart else { return "" }
        var md = "## Bhava 盘 (Bhava Chart)\n\n"
        md += "  主星:\n"
        for (pid, planet) in bc.planets.sorted(by: { $0.value.longitude < $1.value.longitude }) {
            let nak = planet.nakshatra
            let nakStr = nak.map { "\($0.nameSa) Pada:\($0.pada) Lord:\($0.lord)" } ?? ""
            md += "    - \(pid) 星座:\(planet.rasiName) 宫位:\(planet.house ?? 0) 度数:\(planet.degreeText) \(nakStr)\n"
        }
        md += "\n"
        return md
    }

    // MARK: - Rasi Chart

    static func rasiSection(_ result: VedicResult) -> String {
        guard let chart = result.rasiChart else { return "" }
        var md = "## Rāśi 盘 (D1)\n\n"

        md += "### 角点\n\n"
        md += "| 点 | 经度 | 星座 | 宫位 |\n"
        md += "|---|---|---|---|\n"
        for angle in chart.angles {
            md += "| \(angle.name) | \(angle.degreeText) | \(angle.sign) | \(angle.house) |\n"
        }
        md += "\n"

        md += "### 宫位\n\n"
        md += "| 宫位 | 星座 | 宫头 | 主星 |\n"
        md += "|---|---|---|---|\n"
        for house in chart.houses {
            md += "| \(house.house) | \(house.sign) | \(house.cuspText) | \(house.ruler) |\n"
        }
        md += "\n"

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

    // MARK: - Planet Relationships

    static func relationshipsSection(_ result: VedicResult) -> String {
        guard let rel = result.planetRelationships else { return "" }
        var md = "## D1 星体敌友关系\n\n"

        // Naisargika
        md += "### 天然敌友 (Naisargika)\n\n"
        for (a, friends) in rel.naisargika.data.sorted(by: { $0.key < $1.key }) {
            let friendList = friends.filter { $0.value == 0 }.map(\.key).sorted().joined(separator: "/")
            let enemyList = friends.filter { $0.value == 2 }.map(\.key).sorted().joined(separator: "/")
            let neutralList = friends.filter { $0.value == 1 }.map(\.key).sorted().joined(separator: "/")
            md += "- \(a): 友(\(friendList)) 敌(\(enemyList)) 中(\(neutralList))\n"
        }
        md += "\n"

        // Compound
        md += "### 复合敌友\n\n"
        for (a, compounds) in rel.compound.data.sorted(by: { $0.key < $1.key }) {
            let parts = compounds.filter { $0.key != a }.sorted(by: { $0.key < $1.key }).map { b, val in
                let labels = rel.compound.labels ?? [:]
                let label = labels[String(val)] ?? "?"
                return "\(b)=\(label)"
            }
            md += "- \(a): \(parts.joined(separator: ", "))\n"
        }
        md += "\n"

        return md
    }

    // MARK: - Arudha

    static func arudhaSection(_ result: VedicResult) -> String {
        guard let arudha = result.arudha, !arudha.isEmpty else { return "" }
        var md = "## Arudha (D1)\n\n"
        for key in ["AL", "A2", "A3", "A4", "A5", "A6", "A7", "A8", "A9", "A10", "A11", "UL"] {
            guard let pada = arudha[key] else { continue }
            md += "- \(key): 星座:\(pada.rasiName) 宫位:\(pada.house)\n"
        }
        md += "\n"
        return md
    }

    // MARK: - Yogis

    static func yogaSection(_ result: VedicResult) -> String {
        guard let yogas = result.yogas, !yogas.isEmpty else { return "" }
        var md = "## Yogas (D1)\n\n"
        for yoga in yogas {
            let desc = yoga.description ?? yoga.effect
            var flags: [String] = []
            if yoga.conditionOnly == true { flags.append("condition only") }
            if yoga.needsStrengthCheck == true { flags.append("needs strength check") }
            let suffix = flags.isEmpty ? "" : " [" + flags.joined(separator: ", ") + "]"
            md += "- \(yoga.name) [\(yoga.group)]\(suffix): \(desc)\n"
        }
        md += "\n"
        return md
    }

    // MARK: - Jaimini

    static func jaiminiSection(_ result: VedicResult) -> String {
        guard let jk = result.jaiminiKarakas else { return "" }
        var md = "## Jaimini Karakas (D1)\n\n"
        for karaka in jk.charaKarakas {
            md += "- \(karaka.nameSa): \(karaka.planet) (degree \(String(format: "%.4f", karaka.longitudeInRasi)), effective \(String(format: "%.4f", karaka.effectiveLongitude)))\n"
        }
        md += "\n"
        return md
    }

    // MARK: - Ashtakavarga

    static func ashtakavargaSection(_ result: VedicResult) -> String {
        guard let av = result.ashtakavarga else { return "" }
        var md = "## Ashtakavarga (BAV + SAV)\n\n"

        // SAV header
        let rekha = av.sav.rekha
        md += "宫位:  " + (1...12).map { " \($0)" }.joined(separator: " ") + "\n"
        md += "SAV:  " + rekha.map { String(format: "%2d", $0) }.joined(separator: " ") + "\n"

        // BAV
        md += "BAV:\n"
        for pid in ["Asc", "Sun", "Moon", "Mars", "Mercury", "Jupiter", "Venus", "Saturn"] {
            let key = pid == "Asc" ? "ASC" : pid.uppercased()
            if let row = av.bav.planets[key] {
                md += "\(pid): " + row.map { String(format: "%2d", $0) }.joined(separator: " ") + "\n"
            }
        }
        md += "\n"
        return md
    }

    // MARK: - Dasa

    static func dasaSection(_ result: VedicResult) -> String {
        guard let v = result.vimshottari else { return "" }
        var md = "## Vimsottari Dasa\n\n"
        md += "出生 Nakshatra: \(v.birthNakshatra)\n\n"

        for period in v.mahaDasas {
            let isCurrent = period.lord == v.currentMahadasa?.lord
                && period.start == v.currentMahadasa?.start
            let marker = isCurrent ? " ← 当前" : ""
            md += "- \(period.lord) Mahadasha: \(period.start) 至 \(period.end)\(marker)\n"

            if let antardashas = period.antardashas, !antardashas.isEmpty {
                let adStr = antardashas.map { ad in
                    "\(ad.lord)(\(ad.start.prefix(10))-\(ad.end.prefix(10)))"
                }.joined(separator: "；")
                md += "  Antardasha: \(adStr)\n"
            }
        }
        md += "\n"

        if let yogini = result.yoginiDasa {
            md += "### Yogini Dasa\n\n"
            for period in yogini.yoginiDasas {
                let marker = period.yogini == yogini.currentYogini?.yogini ? " ← 当前" : ""
                md += "- \(period.yogini): \(period.start.prefix(10)) 至 \(period.end.prefix(10))\(marker)\n"
            }
            md += "\n"
        }

        if let at = result.ashtottariDasa {
            md += "### Ashtottari Dasa\n\n"
            for period in at.ashtottariDasas {
                let marker = period.lord == at.currentAshtottari?.lord ? " ← 当前" : ""
                md += "- \(period.lord): \(period.start.prefix(10)) 至 \(period.end.prefix(10))\(marker)\n"
            }
            md += "\n"
        }

        return md
    }

    // MARK: - Shadbala

    static func shadbalaSection(_ result: VedicResult) -> String {
        guard let sb = result.shadbala else { return "" }
        var md = "## Shadbala\n\n"
        for pid in ["SUN", "MOON", "MARS", "MERCURY", "JUPITER", "VENUS", "SATURN"] {
            guard let row = sb[pid] else { continue }
            if row.meetsRequired == nil || row.status == "incomplete" {
                md += "- \(pid): 总分 \(Int(row.shadbalaTotal)) / \(String(format: "%.2f", row.shadbalaRupas)) Rupas，当前实现不完整，禁止达标判断\n"
            } else {
                let meets = row.meetsRequired ?? false
                let meetsStr = meets ? "达标" : "未达标"
                md += "- \(pid): 总分 \(Int(row.shadbalaTotal)) / \(String(format: "%.2f", row.shadbalaRupas)) Rupas，要求 \(row.required) / \(String(format: "%.2f", row.requiredRupas ?? 0)) Rupas，\(meetsStr)\n"
            }
            md += "  分项: Sthana \(Int(row.sthanaBala)), Dig \(Int(row.digBala)), Kala \(Int(row.kalaBala)), Cheshta \(Int(row.cheshtaBala)), Naisargika \(Int(row.naisargikaBala)), Drik \(Int(row.drigBala))\n"
        }
        md += "\n"
        return md
    }

    // MARK: - Warnings

    static func warningsSection(_ warnings: [String]) -> String {
        var md = "## 警告\n\n"
        for w in warnings {
            md += "- \(w)\n"
        }
        md += "\n"
        return md
    }
}
