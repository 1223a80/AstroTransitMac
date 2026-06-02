import SwiftUI

// MARK: - Palette

let pageBackground = Color(red: 0.987, green: 0.989, blue: 0.992)
let mainWhite = Color.white
let outerAuraGray = Color(red: 0.925, green: 0.928, blue: 0.929)
let zodiacRingGray = Color(red: 0.918, green: 0.920, blue: 0.922)
let signBandWhite = Color(red: 0.995, green: 0.996, blue: 0.997)
let innerDiskGray = Color(red: 0.955, green: 0.958, blue: 0.960)
let lineGray = Color(red: 0.804, green: 0.808, blue: 0.812)
let strongLineGray = Color(red: 0.580, green: 0.584, blue: 0.588)
let accentCyan = Color(red: 0.271, green: 0.796, blue: 0.918)
let primaryText = Color(red: 0.196, green: 0.204, blue: 0.216)
let secondaryText = Color(red: 0.478, green: 0.486, blue: 0.494)

let fireColor = Color(red: 1.000, green: 0.353, blue: 0.322)
let earthColor = Color(red: 0.847, green: 0.545, blue: 0.204)
let airColor = Color(red: 0.200, green: 0.824, blue: 0.631)
let waterColor = Color(red: 0.122, green: 0.561, blue: 1.000)
let lotTextGray = Color(red: 0.500, green: 0.504, blue: 0.510)

let elementColors: [WheelElement: Color] = [
    .fire: fireColor, .earth: earthColor, .air: airColor, .water: waterColor
]

let aspectLineColors: [String: Color] = [
    "合相": Color(red: 0.462, green: 0.383, blue: 0.930),
    "冲相": fireColor,
    "刑相": fireColor.opacity(0.88),
    "拱相": waterColor,
    "六合": airColor,
    "半刑": earthColor.opacity(0.85),
    "补十二分相": earthColor.opacity(0.65),
]

// MARK: - Geometry

struct ChartWheelGeometry {
    let center: CGPoint
    let radius: CGFloat

    let outerRingOuter: CGFloat
    let outerRingInner: CGFloat
    let zodiacBandInner: CGFloat
    let signLabelRadius: CGFloat
    let houseNumberRadius: CGFloat
    let innerDiskRadius: CGFloat
    let natalPointRadius: CGFloat
    let transitPointRadius: CGFloat

    init(size: CGSize) {
        let available = min(size.width, size.height)
        center = CGPoint(x: size.width / 2, y: size.height / 2)
        radius = available / 2 - 26

        outerRingOuter = radius
        outerRingInner = radius - 14
        zodiacBandInner = radius - 42
        signLabelRadius = radius - 22
        houseNumberRadius = radius - 52
        innerDiskRadius = radius - 60
        natalPointRadius = innerDiskRadius - 34
        transitPointRadius = natalPointRadius + 12
    }

    func angle(for longitude: Double) -> Angle {
        Angle(degrees: 90 - longitude)
    }

    func point(for longitude: Double, at radius: CGFloat) -> CGPoint {
        let radians = angle(for: longitude).radians
        return CGPoint(
            x: center.x + radius * CGFloat(cos(radians)),
            y: center.y - radius * CGFloat(sin(radians))
        )
    }

    func normalizedLongitude(_ longitude: Double) -> Double {
        let value = longitude.truncatingRemainder(dividingBy: 360)
        return value >= 0 ? value : value + 360
    }

    func shortestDistance(_ a: Double, _ b: Double) -> Double {
        let raw = abs(normalizedLongitude(a) - normalizedLongitude(b))
        return min(raw, 360 - raw)
    }

    func midpointLongitude(from start: Double, to end: Double) -> Double {
        let startNorm = normalizedLongitude(start)
        let endNorm = normalizedLongitude(end)
        let delta = ((endNorm - startNorm + 540).truncatingRemainder(dividingBy: 360)) - 180
        return normalizedLongitude(startNorm + delta / 2)
    }

    func axisPath(longitude: Double, radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: point(for: longitude, at: radius))
        path.addLine(to: point(for: longitude + 180, at: radius))
        return path
    }

    func radialPath(longitude: Double, outerRadius: CGFloat, innerRadius: CGFloat) -> Path {
        var path = Path()
        path.move(to: point(for: longitude, at: outerRadius))
        path.addLine(to: point(for: longitude, at: innerRadius))
        return path
    }

    func arcPath(from startLon: Double, to endLon: Double, innerRadius: CGFloat, outerRadius: CGFloat) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: angle(for: endLon),
            endAngle: angle(for: startLon),
            clockwise: true
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: angle(for: startLon),
            endAngle: angle(for: endLon),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Point Layout

struct WheelPointLayout {
    let anchorRadius: CGFloat
    let leaderRadius: CGFloat
    let labelRadius: CGFloat
    let textAnchor: UnitPoint
    let textOffset: CGSize
}

func wheelPointLayouts(for points: [ChartWheelData.WheelPoint], geometry: ChartWheelGeometry) -> [String: WheelPointLayout] {
    guard !points.isEmpty else { return [:] }

    let sorted = points.sorted { geometry.normalizedLongitude($0.longitude) < geometry.normalizedLongitude($1.longitude) }
    var groups: [[ChartWheelData.WheelPoint]] = []

    for point in sorted {
        guard var lastGroup = groups.popLast() else {
            groups.append([point])
            continue
        }

        if let lastPoint = lastGroup.last,
           geometry.shortestDistance(lastPoint.longitude, point.longitude) < 10 {
            lastGroup.append(point)
            groups.append(lastGroup)
        } else {
            groups.append(lastGroup)
            groups.append([point])
        }
    }

    if groups.count > 1,
       let firstGroup = groups.first,
       let lastGroup = groups.last,
       let firstPoint = firstGroup.first,
       let lastPoint = lastGroup.last,
       geometry.shortestDistance(firstPoint.longitude, lastPoint.longitude) < 10 {
        var merged = lastGroup
        merged.append(contentsOf: firstGroup)
        groups.removeLast()
        groups.removeFirst()
        groups.insert(merged, at: 0)
    }

    var layouts: [String: WheelPointLayout] = [:]
    for group in groups {
        let ordered = group.sorted {
            pointLayoutPriority($0) == pointLayoutPriority($1)
                ? geometry.normalizedLongitude($0.longitude) < geometry.normalizedLongitude($1.longitude)
                : pointLayoutPriority($0) < pointLayoutPriority($1)
        }

        for (index, point) in ordered.enumerated() {
            let lane = CGFloat(index)
            let baseRadius = point.isTransit ? geometry.transitPointRadius : geometry.natalPointRadius
            let laneStep: CGFloat = point.type == .lot ? 14 : 11
            let anchorRadius = baseRadius + lane * laneStep
            let leaderRadius = anchorRadius + 10
            let labelRadius = leaderRadius + 10
            let radians = geometry.angle(for: point.longitude).radians
            let cosine = cos(radians)
            let sine = sin(radians)

            let anchor: UnitPoint
            let offset: CGSize
            if cosine > 0.35 {
                anchor = .leading
                offset = CGSize(width: 8, height: 0)
            } else if cosine < -0.35 {
                anchor = .trailing
                offset = CGSize(width: -8, height: 0)
            } else if sine > 0 {
                anchor = .center
                offset = CGSize(width: 0, height: -10)
            } else {
                anchor = .center
                offset = CGSize(width: 0, height: 10)
            }

            layouts[point.id] = WheelPointLayout(
                anchorRadius: anchorRadius,
                leaderRadius: leaderRadius,
                labelRadius: labelRadius,
                textAnchor: anchor,
                textOffset: offset
            )
        }
    }

    return layouts
}

private func pointLayoutPriority(_ point: ChartWheelData.WheelPoint) -> Int {
    switch point.type {
    case .angle: return 0
    case .planet: return point.isTransit ? 2 : 1
    case .lot: return 3
    }
}

// MARK: - Styling Helpers

func wheelPointColor(_ point: ChartWheelData.WheelPoint) -> Color {
    if point.id.hasPrefix("natal-") || point.id.hasPrefix("transit-") {
        return wheelPointColor(forRawID: String(point.id.split(separator: "-").last ?? ""), type: point.type, isTransit: point.isTransit)
    }
    return wheelPointColor(forRawID: point.id, type: point.type, isTransit: point.isTransit)
}

private func wheelPointColor(forRawID rawID: String, type: ChartWheelData.PointType, isTransit: Bool) -> Color {
    let base: Color
    switch rawID {
    case "SUN", "MARS", "JUPITER", "ASC":
        base = fireColor
    case "MOON", "TRUE_NODE", "MEAN_NODE", "NORTH_NODE":
        base = waterColor
    case "MERCURY":
        base = airColor
    case "VENUS", "SATURN", "MC", "IC", "DSC":
        base = earthColor
    case "fortune", "spirit", "eros", "necessity", "courage", "victory", "nemesis", "basis", "acquisition", "marriage", "children", "exaltation":
        base = lotTextGray
    default:
        base = type == .lot ? lotTextGray : secondaryText
    }

    return isTransit ? base.opacity(0.92) : base
}
