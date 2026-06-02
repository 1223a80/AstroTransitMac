import SwiftUI

extension ContentView {
func selectedAspectRequests(orb: Double) -> [AspectRequest] {
        let builtinRequests = aspectOptions
            .filter { selectedAspects.contains($0.id) }
            .map { AspectRequest(id: $0.id, name: $0.name, angle: $0.angle, orb: orb) }
        let builtinAngles = Set(builtinRequests.map { aspectKey($0.angle) })
        let customRequests = parseCustomAspectDegrees(customAspectDegrees)
            .filter { !builtinAngles.contains(aspectKey($0)) }
            .map {
                AspectRequest(
                    id: "custom_\(aspectKey($0))",
                    name: "自定义 \(formatAspectDegree($0))",
                    angle: $0,
                    orb: orb
                )
            }
        return builtinRequests + customRequests
    }

    func parseCustomAspectDegrees(_ text: String) -> [Double] {
        var seen = Set<String>()
        return text
            .split { character in
                character == "," || character == "，" || character == " " || character == "\n" || character == "\t" || character == ";"
            }
            .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0 >= 0 && $0 <= 180 }
            .filter { value in
                let key = aspectKey(value)
                guard !seen.contains(key) else {
                    return false
                }
                seen.insert(key)
                return true
            }
    }

    func aspectKey(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    func formatAspectDegree(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))°"
        }
        return String(format: "%.2f°", value)
    }

    func makeMoment(from date: Date) -> ChartMoment {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = selectedTimeZone
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

        return ChartMoment(
            year: components.year ?? 2000,
            month: components.month ?? 1,
            day: components.day ?? 1,
            hour: components.hour ?? 0,
            minute: components.minute ?? 0,
            timezone: timezoneLabel
        )
    }

    func makeBirthSettingsIfValid() -> BirthSettings? {
        guard let latitude = parseDouble(birthLatitude), let longitude = parseDouble(birthLongitude) else {
            return nil
        }
        return BirthSettings(
            moment: makeMoment(from: natalDate),
            latitude: latitude,
            longitude: longitude,
            houseSystem: selectedHouseSystem,
            zodiac: selectedZodiac,
            boundsSystem: selectedBoundsSystem,
            triplicitySystem: selectedTriplicitySystem
        )
    }

    var selectedTimeZone: TimeZone {
        TimeZone(secondsFromGMT: gmtOffset * 3600) ?? .current
    }

    var timezoneLabel: String {
        gmtOffset >= 0 ? "GMT+\(gmtOffset)" : "GMT\(gmtOffset)"
    }

    func dateTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = selectedTimeZone
        return formatter.string(from: date)
    }
    func sortedBodyIDs(_ ids: Set<String>) -> [String] {
        bodyOptions
            .map(\.id)
            .filter { ids.contains($0) }
    }

    func scanTransitBodyIDs() -> [String] {
        switch scanMoonFilter {
        case "exclude":
            return sortedBodyIDs(selectedTransitBodies).filter { $0 != "MOON" }
        case "only":
            return ["MOON"]
        default:
            return sortedBodyIDs(selectedTransitBodies)
        }
    }

    func estimatedScanWork() -> Int {
        let bodyCount = max(scanTransitBodyIDs().count + parseAsteroids(customAsteroids).count, 1)
        let aspectCount = selectedScanKind == "aspect" ? max(selectedAspectRequests(orb: 0).count, 1) : 1
        let targetCount = selectedScanKind == "aspect"
            ? max(resolvedScanTargetText().split(separator: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count, 1)
            : 1
        return max(bodyCount * aspectCount * targetCount, 1)
    }
    func parseAsteroids(_ text: String) -> [Int] {
        text
            .split { character in
                character == "," || character == " " || character == "\n" || character == "\t" || character == ";"
            }
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0 > 0 }
    }

func parseDouble(_ text: String) -> Double? {
    Double(text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
}
}
