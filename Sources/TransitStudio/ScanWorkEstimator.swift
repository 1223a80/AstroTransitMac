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

// MARK: - Modern Timing Work Estimate

/// B3 keeps its estimator separate from legacy scan so adding techniques or
/// adapter steps cannot change `mode=scan` estimates.
enum ModernTimingWorkLimits {
    static let softWarning = ScanWorkLimits.softWarning
    static let confirmationRequired = ScanWorkLimits.confirmationRequired
    static let maximum = ScanWorkLimits.maximum
}

struct ModernTimingTechniqueWorkEstimate: Equatable {
    let techniqueID: String
    let workUnits: Int
    let stepUnits: Int
    let movingPointCount: Int
    let targetCount: Int
    let aspectBranchCount: Int
}

struct ModernTimingWorkEstimate: Equatable {
    let workUnits: Int
    let stepUnits: Int
    let movingPointCount: Int
    let targetCount: Int
    let aspectBranchCount: Int
    let techniques: [ModernTimingTechniqueWorkEstimate]

    var shouldWarn: Bool { workUnits > ModernTimingWorkLimits.softWarning }
    var requiresConfirmation: Bool { workUnits > ModernTimingWorkLimits.confirmationRequired }
    var isBlocked: Bool { workUnits > ModernTimingWorkLimits.maximum }

    var formattedWorkUnits: String {
        ScanWorkEstimate.format(workUnits)
    }

    var warningText: String? {
        guard shouldWarn else { return nil }
        return "综合时间线计算量约 \(formattedWorkUnits)，可能耗时较长。"
    }

    var confirmationText: String {
        "预计综合时间线计算量约 \(formattedWorkUnits)，超过 \(ScanWorkEstimate.format(ModernTimingWorkLimits.confirmationRequired))。继续计算可能耗时较长，且仍可能触发 300 秒超时。"
    }

    var blockedText: String {
        "综合时间线窗口过大，预计计算量约 \(formattedWorkUnits)，上限 \(ScanWorkEstimate.format(ModernTimingWorkLimits.maximum))。请缩短时间范围、减少技法/移动体/目标点/相位。"
    }
}

struct ModernTimingWorkConfirmation: Identifiable, Equatable {
    let id = UUID()
    let estimate: ModernTimingWorkEstimate
}

enum HeavyWorkConfirmation: Identifiable, Equatable {
    case scan(ScanWorkEstimate)
    case modernTiming(ModernTimingWorkEstimate)

    var id: String {
        switch self {
        case .scan(let estimate): return "scan-\(estimate.workUnits)"
        case .modernTiming(let estimate): return "modern-timing-\(estimate.workUnits)"
        }
    }

    var title: String {
        switch self {
        case .scan: return "扫描计算量较大"
        case .modernTiming: return "综合时间线计算量较大"
        }
    }

    var confirmationText: String {
        switch self {
        case .scan(let estimate): return estimate.confirmationText
        case .modernTiming(let estimate): return estimate.confirmationText
        }
    }
}

enum ModernTimingWorkEstimator {
    /// Preferred entry point: derives the de-duplicated target count from the
    /// same point-set dimensions used by the B3 backend.
    static func estimate(
        start: Date,
        end: Date,
        techniques: [ModernTimingTechniqueRequest],
        targetPointSet: ModernPointSet
    ) -> ModernTimingWorkEstimate {
        estimate(
            start: start,
            end: end,
            techniques: techniques,
            targetCount: targetCount(for: targetPointSet)
        )
    }

    /// Mirrors the B3 backend estimate technique-by-technique. Aspect work is
    /// target/branch dependent; ingress, station, progressed Moon ingress and
    /// progressed lunation add their own adapter-step work only when enabled.
    static func estimate(
        start: Date,
        end: Date,
        techniques: [ModernTimingTechniqueRequest],
        targetCount: Int
    ) -> ModernTimingWorkEstimate {
        let normalizedTargetCount = max(targetCount, 0)
        let effectiveTargetCount = max(normalizedTargetCount, 1)
        let techniqueEstimates = techniques.map { technique in
            var seenMovingIDs = Set<String>()
            let movingBodyIDs = technique.movingBodyIDs.filter { seenMovingIDs.insert($0).inserted }
            let stepsByMovingPoint = movingBodyIDs.map { bodyID in
                (
                    bodyID,
                    estimatedSteps(
                        start: start,
                        end: end,
                        techniqueID: technique.id,
                        bodyID: bodyID
                    )
                )
            }
            let stepUnits = stepsByMovingPoint.reduce(0) {
                saturatingAdd($0, $1.1)
            }
            let eventTypes = Set(technique.eventTypes)
            let configuredBranches = technique.aspects.reduce(0) { partial, aspect in
                saturatingAdd(partial, exactLongitudeBranchCount(for: aspect.angle))
            }
            let branches = eventTypes.contains("aspect") ? max(configuredBranches, 1) : 0
            var workUnits = 0

            if eventTypes.contains("aspect") {
                workUnits = saturatingAdd(
                    workUnits,
                    saturatingMultiply(
                        saturatingMultiply(stepUnits, effectiveTargetCount),
                        branches
                    )
                )
            }

            if technique.id == "transit" {
                if eventTypes.contains("ingress") {
                    workUnits = saturatingAdd(workUnits, stepUnits)
                }
                if eventTypes.contains("station") {
                    workUnits = saturatingAdd(workUnits, stepUnits)
                }
            } else if technique.id == "secondary_progression" {
                if eventTypes.contains("moon_ingress"),
                   let moonSteps = stepsByMovingPoint.first(where: { $0.0 == "MOON" })?.1 {
                    workUnits = saturatingAdd(workUnits, moonSteps)
                }
                if eventTypes.contains("lunation") {
                    workUnits = saturatingAdd(
                        workUnits,
                        estimatedSteps(
                            start: start,
                            end: end,
                            techniqueID: technique.id,
                            bodyID: "MOON"
                        )
                    )
                }
            }

            return ModernTimingTechniqueWorkEstimate(
                techniqueID: technique.id,
                workUnits: workUnits,
                stepUnits: stepUnits,
                movingPointCount: movingBodyIDs.count,
                targetCount: normalizedTargetCount,
                aspectBranchCount: branches
            )
        }

        return ModernTimingWorkEstimate(
            workUnits: max(techniqueEstimates.reduce(0) { saturatingAdd($0, $1.workUnits) }, 1),
            stepUnits: techniqueEstimates.reduce(0) { saturatingAdd($0, $1.stepUnits) },
            movingPointCount: techniqueEstimates.reduce(0) { saturatingAdd($0, $1.movingPointCount) },
            targetCount: normalizedTargetCount,
            aspectBranchCount: techniqueEstimates.reduce(0) { saturatingAdd($0, $1.aspectBranchCount) },
            techniques: techniqueEstimates
        )
    }

    static func targetCount(for pointSet: ModernPointSet) -> Int {
        var targetIDs = Set(pointSet.bodyIDs)

        if pointSet.includeNodes {
            switch pointSet.nodeMode {
            case "mean_node":
                targetIDs.formUnion(["MEAN_NODE", "SOUTH_MEAN_NODE"])
            default:
                targetIDs.formUnion(["TRUE_NODE", "SOUTH_TRUE_NODE"])
            }
        }

        targetIDs.formUnion(pointSet.customAsteroids.map { "AST:\($0)" })
        targetIDs.formUnion(pointSet.angleIDs)
        targetIDs.formUnion(pointSet.houseCusps.map { "HOUSE_CUSP:\($0)" })
        targetIDs.formUnion(pointSet.lotIDs)
        return targetIDs.count
    }

    static func estimatedSteps(
        start: Date,
        end: Date,
        techniqueID: String,
        bodyID: String
    ) -> Int {
        let seconds = max(end.timeIntervalSince(start), 0)
        return Int(seconds / stepSeconds(for: techniqueID, bodyID: bodyID)) + 1
    }

    /// Transit keeps the proven body-specific scan cadence. Progression and
    /// solar arc use the backend's fixed seven-day adapter cadence.
    static func stepSeconds(for techniqueID: String, bodyID: String) -> TimeInterval {
        switch techniqueID {
        case "transit":
            return ScanWorkEstimator.stepSeconds(for: bodyID)
        case "secondary_progression", "solar_arc":
            return 7 * 24 * 60 * 60
        default:
            return 7 * 24 * 60 * 60
        }
    }

    static func exactLongitudeBranchCount(for angle: Double) -> Int {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        let positive = normalized >= 0 ? normalized : normalized + 360
        if abs(positive) < 0.000_001 || abs(positive - 180) < 0.000_001 {
            return 1
        }
        return 2
    }

    private static func saturatingAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? Int.max : value
    }

    private static func saturatingMultiply(_ lhs: Int, _ rhs: Int) -> Int {
        let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        return overflow ? Int.max : value
    }
}
