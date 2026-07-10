import Foundation

enum ScanWorkLimits {
    static let softWarning = 1_500_000
    static let confirmationRequired = 2_500_000
    static let maximum = 5_000_000
}

struct ScanWorkEstimate: Equatable {
    let workUnits: Int
    let stepUnits: Int
    let bodyCount: Int
    let targetCount: Int
    let exactAspectCount: Int

    var shouldWarn: Bool { workUnits > ScanWorkLimits.softWarning }
    var requiresConfirmation: Bool { workUnits > ScanWorkLimits.confirmationRequired }
    var isBlocked: Bool { workUnits > ScanWorkLimits.maximum }

    var formattedWorkUnits: String {
        Self.format(workUnits)
    }

    var warningText: String? {
        guard shouldWarn else { return nil }
        return "扫描计算量约 \(formattedWorkUnits)，可能耗时较长。"
    }

    var confirmationText: String {
        "预计计算量约 \(formattedWorkUnits)，超过 \(Self.format(ScanWorkLimits.confirmationRequired))。继续计算可能耗时较长，且仍可能触发 300 秒超时。"
    }

    var blockedText: String {
        "扫描窗口过大，预计计算量约 \(formattedWorkUnits)，上限 \(Self.format(ScanWorkLimits.maximum))。请缩短时间范围、减少天体/目标点/相位。"
    }

    static func format(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.2fM", Double(value) / 1_000_000.0)
        }
        if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000.0)
        }
        return "\(value)"
    }
}

struct ScanWorkConfirmation: Identifiable, Equatable {
    let id = UUID()
    let estimate: ScanWorkEstimate
}

enum ScanWorkEstimator {
    static func estimate(
        start: Date,
        end: Date,
        transitBodyIDs: [String],
        customAsteroids: [Int],
        moonFilter: String,
        scanKind: String,
        aspects: [AspectRequest],
        targetText: String
    ) -> ScanWorkEstimate {
        let bodyIDs = effectiveBodyIDs(
            transitBodyIDs: transitBodyIDs,
            customAsteroids: customAsteroids,
            moonFilter: moonFilter,
            scanKind: scanKind
        )
        let stepUnits = bodyIDs.reduce(0) { partial, bodyID in
            partial + estimatedSteps(start: start, end: end, bodyID: bodyID)
        }
        let targetCount = scanKind == "aspect" ? max(parsedTargetLineCount(targetText), 1) : 1
        let exactAspectCount = scanKind == "aspect" ? max(aspects.reduce(0) { $0 + exactLongitudeCount(for: $1.angle) }, 1) : 1
        return ScanWorkEstimate(
            workUnits: max(stepUnits * targetCount * exactAspectCount, 1),
            stepUnits: stepUnits,
            bodyCount: bodyIDs.count,
            targetCount: targetCount,
            exactAspectCount: exactAspectCount
        )
    }

    static func effectiveBodyIDs(
        transitBodyIDs: [String],
        customAsteroids: [Int],
        moonFilter: String,
        scanKind: String
    ) -> [String] {
        var bodyIDs = transitBodyIDs + customAsteroids.map { "AST:\($0)" }
        switch moonFilter {
        case "exclude":
            bodyIDs.removeAll { $0 == "MOON" }
        case "only":
            bodyIDs = bodyIDs.filter { $0 == "MOON" }
            if bodyIDs.isEmpty {
                bodyIDs = ["MOON"]
            }
        default:
            break
        }
        if scanKind == "station" {
            bodyIDs.removeAll { $0 == "SUN" || $0 == "MOON" }
        }
        return bodyIDs
    }

    static func estimatedSteps(start: Date, end: Date, bodyID: String) -> Int {
        let seconds = max(end.timeIntervalSince(start), 0)
        return Int(seconds / stepSeconds(for: bodyID)) + 1
    }

    static func stepSeconds(for bodyID: String) -> TimeInterval {
        if bodyID == "MOON" {
            return 60 * 60
        }
        if ["SUN", "MERCURY", "VENUS", "MARS"].contains(bodyID) {
            return 3 * 60 * 60
        }
        if [
            "JUPITER", "SATURN", "MEAN_NODE", "TRUE_NODE",
            "SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE", "CHIRON",
            "PHOLUS", "CERES", "PALLAS", "JUNO", "VESTA"
        ].contains(bodyID) || bodyID.hasPrefix("AST:") {
            return 12 * 60 * 60
        }
        return 2 * 24 * 60 * 60
    }

    static func exactLongitudeCount(for angle: Double) -> Int {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        let positive = normalized >= 0 ? normalized : normalized + 360
        if abs(positive) < 0.000_001 || abs(positive - 180) < 0.000_001 {
            return 1
        }
        return 2
    }

    static func parsedTargetLineCount(_ text: String) -> Int {
        text.split(separator: "\n", omittingEmptySubsequences: false).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmed.isEmpty && !trimmed.hasPrefix("#")
        }.count
    }
}
