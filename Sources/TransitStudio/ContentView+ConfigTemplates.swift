import SwiftUI

extension ContentView {
var momentConfigTemplateJSON: String {
        [
            "# MOMENT_CONFIG",
            "# 示例：按 KEY=VALUE；列表用英文逗号；可直接让 LLM 按此格式返回",
            "# 例如：TRANSIT_TIME=2026-05-05 12:00",
            "# 例如：NATAL_BODIES=SUN,MOON,VENUS",
            "# 例如：ASPECTS=conjunction,opposition,trine",
            "TRANSIT_TIME=\(dateTimeText(transitDate))",
            "NATAL_BODIES=\(sortedBodyIDs(selectedNatalBodies).joined(separator: ","))",
            "TRANSIT_BODIES=\(sortedBodyIDs(selectedTransitBodies).joined(separator: ","))",
            "ASPECTS=\(aspectOptions.filter { selectedAspects.contains($0.id) }.map(\.id).joined(separator: ","))",
            "CUSTOM_ASPECT_DEGREES=\(formatCustomAspectDegrees(parseCustomAspectDegrees(customAspectDegrees)))",
            "CUSTOM_ASTEROIDS=\(parseAsteroids(customAsteroids).map(String.init).joined(separator: ","))",
            "GLOBAL_ORB=\(String(format: "%.1f", globalOrb))"
        ].joined(separator: "\n")
    }

    var scanConfigTemplateJSON: String {
        [
            "# SCAN_CONFIG",
            "# 示例：按 KEY=VALUE；列表用英文逗号；CUSTOM_TARGETS 用 | 分隔多条目标",
            "# 例如：TARGET_VIRTUAL_POINTS=ASC,DSC,TRUE_NODE,SOUTH_TRUE_NODE",
            "# 例如：CUSTOM_TARGETS=Relationship Point = Libra 12°30 | Meeting Point = Scorpio 03°15",
            "# 例如：CUSTOM_ASTEROIDS=433,16",
            "SCAN_KIND=\(selectedScanKind)",
            "LABEL=\(scanWindowLabel)",
            "START=\(dateTimeText(scanStartDate))",
            "END=\(dateTimeText(scanEndDate))",
            "MOON_FILTER=\(scanMoonFilter)",
            "TRANSIT_BODIES=\(scanTransitBodyIDs().joined(separator: ","))",
            "TARGET_SOURCE=\(targetSource)",
            "TARGET_PLANETS=\(Array(selectedTargetPlanets).sorted().joined(separator: ","))",
            "TARGET_VIRTUAL_POINTS=\(Array(selectedTargetAngles).sorted().joined(separator: ","))",
            "TARGET_ASTEROIDS=\(Array(selectedTargetAsteroids).sorted().joined(separator: ","))",
            "TARGET_HOUSES=\(Array(selectedTargetHouses).sorted().map(String.init).joined(separator: ","))",
            "TARGET_LOTS=\(Array(selectedTargetLots).sorted().joined(separator: ","))",
            "CUSTOM_TARGETS=\(customLotTargetsText.replacingOccurrences(of: "\n", with: " | "))",
            "ASPECTS=\(aspectOptions.filter { selectedAspects.contains($0.id) }.map(\.id).joined(separator: ","))",
            "CUSTOM_ASPECT_DEGREES=\(formatCustomAspectDegrees(parseCustomAspectDegrees(customAspectDegrees)))",
            "CUSTOM_ASTEROIDS=\(parseAsteroids(customAsteroids).map(String.init).joined(separator: ","))"
        ].joined(separator: "\n")
    }

    func applyMomentConfigTemplate() {
        do {
            let values = try parseTemplateLines(momentConfigText)
            if let transitTime = values["TRANSIT_TIME"], let parsed = parseTemplateDate(transitTime) {
                transitDate = parsed
            }
            selectedNatalBodies = resolveBodySelection(parseList(values["NATAL_BODIES"]))
            selectedTransitBodies = resolveBodySelection(parseList(values["TRANSIT_BODIES"]))
            selectedAspects = resolveAspectSelection(parseList(values["ASPECTS"]))
            customAspectDegrees = formatCustomAspectDegrees(parseList(values["CUSTOM_ASPECT_DEGREES"]).compactMap(Double.init))
            customAsteroids = parseList(values["CUSTOM_ASTEROIDS"]).compactMap(Int.init).map(String.init).joined(separator: ", ")
            if let orb = values["GLOBAL_ORB"].flatMap(Double.init) {
                globalOrb = orb
            }
            calcVM.errorMessage = nil
        } catch {
            calcVM.errorMessage = "时间点模板解析失败：\(error.localizedDescription)"
        }
    }

    func applyScanConfigTemplate() {
        do {
            let values = try parseTemplateLines(scanConfigText)
            if let scanKind = values["SCAN_KIND"], ["aspect", "ingress", "station"].contains(scanKind) {
                selectedScanKind = scanKind
            }
            if let label = values["LABEL"] {
                scanWindowLabel = label
            }
            if let start = values["START"], let parsed = parseTemplateDate(start) {
                scanStartDate = parsed
            }
            if let end = values["END"], let parsed = parseTemplateDate(end) {
                scanEndDate = parsed
            }
            if let moonFilter = values["MOON_FILTER"], ["exclude", "include", "only"].contains(moonFilter) {
                scanMoonFilter = moonFilter
            }
            selectedTransitBodies = resolveBodySelection(parseList(values["TRANSIT_BODIES"]))
            if let source = values["TARGET_SOURCE"], ["natal", "custom"].contains(source) {
                targetSource = source
            }
            selectedTargetPlanets = resolveTargetSelection(parseList(values["TARGET_PLANETS"]), options: targetPlanetOptions)
            selectedTargetAngles = resolveTargetSelection(parseList(values["TARGET_VIRTUAL_POINTS"]), options: targetVirtualAndAngleOptions)
            selectedTargetAsteroids = resolveTargetSelection(parseList(values["TARGET_ASTEROIDS"]), options: targetAsteroidOptions)
            selectedTargetHouses = Set(parseList(values["TARGET_HOUSES"]).compactMap(Int.init))
            selectedTargetLots = resolveTargetSelection(parseList(values["TARGET_LOTS"]), options: targetLotOptions)
            customLotTargetsText = parseCustomTargets(values["CUSTOM_TARGETS"]).joined(separator: "\n")
            selectedAspects = resolveAspectSelection(parseList(values["ASPECTS"]))
            customAspectDegrees = formatCustomAspectDegrees(parseList(values["CUSTOM_ASPECT_DEGREES"]).compactMap(Double.init))
            customAsteroids = parseList(values["CUSTOM_ASTEROIDS"]).compactMap(Int.init).map(String.init).joined(separator: ", ")
            calcVM.errorMessage = nil
        } catch {
            calcVM.errorMessage = "窗口扫描模板解析失败：\(error.localizedDescription)"
        }
    }

    func resolveBodySelection(_ tokens: [String]) -> Set<String> {
        let byID = Dictionary(uniqueKeysWithValues: bodyOptions.map { ($0.id.lowercased(), $0.id) })
        let byName = Dictionary(uniqueKeysWithValues: bodyOptions.map { ($0.name.lowercased(), $0.id) })
        return Set(tokens.compactMap { token in
            let key = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return byID[key] ?? byName[key]
        })
    }

    func resolveAspectSelection(_ tokens: [String]) -> Set<String> {
        let byID = Dictionary(uniqueKeysWithValues: aspectOptions.map { ($0.id.lowercased(), $0.id) })
        let byName = Dictionary(uniqueKeysWithValues: aspectOptions.map { ($0.name.lowercased(), $0.id) })
        return Set(tokens.compactMap { token in
            let key = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return byID[key] ?? byName[key]
        })
    }

    func resolveTargetSelection(_ tokens: [String], options: [TargetPositionOption]) -> Set<String> {
        let byID = Dictionary(uniqueKeysWithValues: options.map { ($0.id.lowercased(), $0.id) })
        let byName = Dictionary(uniqueKeysWithValues: options.map { ($0.name.lowercased(), $0.id) })
        return Set(tokens.compactMap { token in
            let key = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return byID[key] ?? byName[key]
        })
    }

    func formatCustomAspectDegrees(_ values: [Double]) -> String {
        values.map(formatAspectDegree).joined(separator: ", ")
    }

    func parseTemplateLines(_ text: String) throws -> [String: String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "Template", code: 1, userInfo: [NSLocalizedDescriptionKey: "内容为空"])
        }

        var values: [String: String] = [:]
        for rawLine in trimmed.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }
            guard let index = line.firstIndex(of: "=") else {
                continue
            }
            let key = String(line[..<index]).trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            let value = String(line[line.index(after: index)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = value
        }
        return values
    }

    func parseList(_ value: String?) -> [String] {
        guard let value else {
            return []
        }
        return value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func parseCustomTargets(_ value: String?) -> [String] {
        guard let value else {
            return []
        }
        return value
            .split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

func parseTemplateDate(_ value: String) -> Date? {
        let formats = ["yyyy-MM-dd HH:mm", "yyyy/M/d H:mm", "yyyy/MM/dd HH:mm"]
        let formatter = DateFormatter()
        formatter.timeZone = selectedTimeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
    return nil
}

    // MARK: - Moment Presets

    var momentPresets: [MomentPreset] {
        guard let data = appState.momentPresetsJSON.data(using: .utf8),
              let presets = try? JSONDecoder().decode([MomentPreset].self, from: data)
        else {
            return []
        }
        return presets
    }

    func saveMomentPresets(_ presets: [MomentPreset]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(presets),
              let text = String(data: data, encoding: .utf8)
        else {
            return
        }
        appState.momentPresetsJSON = text
    }

    func saveMomentPreset() {
        let name = momentPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            calcVM.errorMessage = "预设名称不能为空。"
            return
        }

        let templateText = momentConfigTemplateJSON
        let preset = MomentPreset(
            id: UUID(uuidString: selectedMomentPresetID) ?? UUID(),
            name: name,
            templateText: templateText
        )

        var presets = momentPresets
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        saveMomentPresets(presets.sorted { $0.name.localizedCompare($1.name) == .orderedAscending })
        selectedMomentPresetID = preset.id.uuidString
        calcVM.errorMessage = nil
    }

    func loadSelectedMomentPreset() {
        guard let preset = momentPresets.first(where: { $0.id.uuidString == selectedMomentPresetID }) else {
            return
        }
        momentPresetName = preset.name
        momentConfigText = preset.templateText
        applyMomentConfigTemplate()
    }

    func deleteSelectedMomentPreset() {
        let presets = momentPresets.filter { $0.id.uuidString != selectedMomentPresetID }
        saveMomentPresets(presets)
        selectedMomentPresetID = presets.first?.id.uuidString ?? ""
        if let first = presets.first {
            momentPresetName = first.name
            momentConfigText = first.templateText
            applyMomentConfigTemplate()
        } else {
            momentPresetName = ""
            momentConfigText = ""
            transitDate = Date()
            selectedNatalBodies = []
            selectedTransitBodies = []
            selectedAspects = []
            customAspectDegrees = ""
            customAsteroids = ""
            globalOrb = 3.0
        }
    }

    // MARK: - Scan Presets

    var scanPresets: [ScanPreset] {
        guard let data = appState.scanPresetsJSON.data(using: .utf8),
              let presets = try? JSONDecoder().decode([ScanPreset].self, from: data)
        else {
            return []
        }
        return presets
    }

    func saveScanPresets(_ presets: [ScanPreset]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(presets),
              let text = String(data: data, encoding: .utf8)
        else {
            return
        }
        appState.scanPresetsJSON = text
    }

    func saveScanPreset() {
        let name = scanPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            calcVM.errorMessage = "预设名称不能为空。"
            return
        }

        let templateText = scanConfigTemplateJSON
        let preset = ScanPreset(
            id: UUID(uuidString: selectedScanPresetID) ?? UUID(),
            name: name,
            templateText: templateText
        )

        var presets = scanPresets
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
        } else {
            presets.append(preset)
        }
        saveScanPresets(presets.sorted { $0.name.localizedCompare($1.name) == .orderedAscending })
        selectedScanPresetID = preset.id.uuidString
        calcVM.errorMessage = nil
    }

    func loadSelectedScanPreset() {
        guard let preset = scanPresets.first(where: { $0.id.uuidString == selectedScanPresetID }) else {
            return
        }
        scanPresetName = preset.name
        scanConfigText = preset.templateText
        applyScanConfigTemplate()
    }

    func deleteSelectedScanPreset() {
        let presets = scanPresets.filter { $0.id.uuidString != selectedScanPresetID }
        saveScanPresets(presets)
        selectedScanPresetID = presets.first?.id.uuidString ?? ""
        if let first = presets.first {
            scanPresetName = first.name
            scanConfigText = first.templateText
            applyScanConfigTemplate()
        } else {
            scanPresetName = ""
            scanConfigText = ""
            selectedScanKind = "aspect"
            scanWindowLabel = ""
            scanStartDate = Self.fixedDate(year: 2026, month: 5, day: 1, hour: 0, minute: 0)
            scanEndDate = Self.fixedDate(year: 2026, month: 6, day: 30, hour: 23, minute: 59)
            scanMoonFilter = "exclude"
            selectedTransitBodies = []
            targetSource = "natal"
            selectedTargetPlanets = []
            selectedTargetAngles = []
            selectedTargetAsteroids = []
            selectedTargetHouses = []
            selectedTargetLots = []
            customLotTargetsText = ""
            selectedAspects = []
            customAspectDegrees = ""
            customAsteroids = ""
        }
    }
}
