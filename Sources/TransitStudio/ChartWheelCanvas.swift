import SwiftUI

struct ChartWheelCanvas: View {
    let data: ChartWheelData
    let geometry: ChartWheelGeometry
    let hoveredPointID: String?
    let selectedPointID: String?

    private var pointLayouts: [String: WheelPointLayout] {
        wheelPointLayouts(for: data.points, geometry: geometry)
    }

    private var uniqueAxisLongitudes: [Double] {
        var values: [Double] = []
        for longitude in data.axisLongitudes {
            let normalized = geometry.normalizedLongitude(longitude).truncatingRemainder(dividingBy: 180)
            if !values.contains(where: { geometry.shortestDistance($0, normalized) < 1 }) {
                values.append(normalized)
            }
        }
        return values
    }

    private var highlightID: String? {
        selectedPointID ?? hoveredPointID
    }

    var body: some View {
        Canvas { context, _ in
            drawDisk(in: &context)
            drawZodiacBand(in: &context)
            drawHouseBand(in: &context)
            drawHouseLines(in: &context)
            drawAxisLines(in: &context)
            drawAspects(in: &context)
            drawPoints(in: &context)
            drawCenter(in: &context)
        }
    }

    private func drawDisk(in context: inout GraphicsContext) {
        let haloRect = CGRect(
            x: geometry.center.x - geometry.outerRingOuter,
            y: geometry.center.y - geometry.outerRingOuter,
            width: geometry.outerRingOuter * 2,
            height: geometry.outerRingOuter * 2
        )
        context.fill(Path(ellipseIn: haloRect), with: .color(outerAuraGray))

        let zodiacBand = geometry.arcPath(
            from: 0,
            to: 360,
            innerRadius: geometry.zodiacBandInner,
            outerRadius: geometry.outerRingInner
        )
        context.fill(zodiacBand, with: .color(zodiacRingGray))

        let houseBand = geometry.arcPath(
            from: 0,
            to: 360,
            innerRadius: geometry.innerDiskRadius,
            outerRadius: geometry.zodiacBandInner
        )
        context.fill(houseBand, with: .color(signBandWhite))

        let diskRect = CGRect(
            x: geometry.center.x - geometry.innerDiskRadius,
            y: geometry.center.y - geometry.innerDiskRadius,
            width: geometry.innerDiskRadius * 2,
            height: geometry.innerDiskRadius * 2
        )
        context.fill(Path(ellipseIn: diskRect), with: .color(innerDiskGray))

        context.stroke(Path(ellipseIn: haloRect), with: .color(outerAuraGray.opacity(0.75)), lineWidth: 1.5)
        context.stroke(
            Path(ellipseIn: CGRect(
                x: geometry.center.x - geometry.zodiacBandInner,
                y: geometry.center.y - geometry.zodiacBandInner,
                width: geometry.zodiacBandInner * 2,
                height: geometry.zodiacBandInner * 2
            )),
            with: .color(lineGray.opacity(0.9)),
            lineWidth: 1
        )
        context.stroke(Path(ellipseIn: diskRect), with: .color(lineGray.opacity(0.65)), lineWidth: 1)
    }

    private func drawZodiacBand(in context: inout GraphicsContext) {
        for index in 0..<12 {
            let start = Double(index * 30)
            let end = Double((index + 1) * 30)
            let color = elementColors[elementForSign(index: index)] ?? secondaryText
            let segment = geometry.arcPath(
                from: start,
                to: end,
                innerRadius: geometry.zodiacBandInner,
                outerRadius: geometry.outerRingInner
            )
            context.fill(segment, with: .color(color.opacity(0.075)))

            let labelPoint = geometry.point(for: start + 15, at: geometry.signLabelRadius)
            context.draw(
                Text(signShortLabels[index])
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(color),
                at: labelPoint
            )
        }

        for index in 0..<12 {
            let longitude = Double(index * 30)
            let outerPoint = geometry.point(for: longitude, at: geometry.outerRingInner - 2)
            let innerPoint = geometry.point(for: longitude, at: geometry.zodiacBandInner + 6)
            var tick = Path()
            tick.move(to: outerPoint)
            tick.addLine(to: innerPoint)
            context.stroke(tick, with: .color(mainWhite.opacity(0.7)), lineWidth: 0.8)
        }
    }

    private func drawHouseBand(in context: inout GraphicsContext) {
        guard !data.houseCusps.isEmpty else { return }
        for (index, cusp) in data.houseCusps.enumerated() {
            let next = data.houseCusps[(index + 1) % data.houseCusps.count]
            let mid = geometry.midpointLongitude(from: cusp, to: next)
            let color = elementColors[elementForSign(index: Int(mid / 30) % 12)] ?? secondaryText
            let point = geometry.point(for: mid, at: geometry.houseNumberRadius)
            context.draw(
                Text("\(index + 1)")
                    .font(.system(size: 10.5, weight: .regular))
                    .foregroundColor(color.opacity(0.9)),
                at: point
            )
        }
    }

    private func drawHouseLines(in context: inout GraphicsContext) {
        for cusp in data.houseCusps {
            let path = geometry.radialPath(
                longitude: cusp,
                outerRadius: geometry.innerDiskRadius,
                innerRadius: 0
            )
            context.stroke(path, with: .color(lineGray.opacity(0.92)), lineWidth: 1)
        }
    }

    private func drawAxisLines(in context: inout GraphicsContext) {
        for longitude in uniqueAxisLongitudes {
            let path = geometry.axisPath(longitude: longitude, radius: geometry.outerRingInner)
            context.stroke(path, with: .color(strongLineGray.opacity(0.85)), lineWidth: 2.6)
        }
    }

    private func drawAspects(in context: inout GraphicsContext) {
        for aspect in data.aspects {
            guard let left = data.points.first(where: { $0.id == aspect.pointAID || normalizedBodyID(from: $0.id) == aspect.pointAID }),
                  let right = data.points.first(where: { $0.id == aspect.pointBID || normalizedBodyID(from: $0.id) == aspect.pointBID }),
                  let leftLayout = pointLayouts[left.id],
                  let rightLayout = pointLayouts[right.id]
            else { continue }

            let leftPoint = geometry.point(for: left.longitude, at: leftLayout.anchorRadius)
            let rightPoint = geometry.point(for: right.longitude, at: rightLayout.anchorRadius)
            let highlight = left.id == highlightID || right.id == highlightID
            let color = aspectLineColors[aspect.type] ?? accentCyan
            let opacity: Double = highlight ? 0.92 : (highlightID == nil ? 0.72 : 0.18)
            let lineWidth: CGFloat = highlight ? 1.9 : 1.15

            var path = Path()
            path.move(to: leftPoint)
            path.addLine(to: rightPoint)
            context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: lineWidth)
        }
    }

    private func drawPoints(in context: inout GraphicsContext) {
        let orderedPoints = data.points.sorted { pointDrawPriority($0) < pointDrawPriority($1) }
        for point in orderedPoints {
            guard let layout = pointLayouts[point.id] else { continue }

            let anchorPoint = geometry.point(for: point.longitude, at: layout.anchorRadius)
            let leaderPoint = geometry.point(for: point.longitude, at: layout.leaderRadius)
            let labelPointBase = geometry.point(for: point.longitude, at: layout.labelRadius)
            let labelPoint = CGPoint(
                x: labelPointBase.x + layout.textOffset.width,
                y: labelPointBase.y + layout.textOffset.height
            )
            let pointColor = wheelPointColor(point)
            let highlighted = point.id == hoveredPointID || point.id == selectedPointID

            var leader = Path()
            leader.move(to: anchorPoint)
            leader.addLine(to: leaderPoint)
            context.stroke(leader, with: .color(pointColor.opacity(highlighted ? 0.65 : 0.38)), lineWidth: highlighted ? 1.0 : 0.7)

            let anchorRadius: CGFloat = highlighted ? 4.2 : 3.6
            let anchorRect = CGRect(
                x: anchorPoint.x - anchorRadius,
                y: anchorPoint.y - anchorRadius,
                width: anchorRadius * 2,
                height: anchorRadius * 2
            )
            let anchorPath = Path(ellipseIn: anchorRect)
            context.fill(anchorPath, with: .color(mainWhite))
            context.stroke(anchorPath, with: .color(pointColor), lineWidth: highlighted ? 1.8 : 1.25)

            let fontSize: CGFloat
            switch point.type {
            case .angle: fontSize = highlighted ? 18 : 17
            case .planet: fontSize = highlighted ? 17 : 16
            case .lot: fontSize = highlighted ? 15 : 14
            }

            context.draw(
                Text(point.shortLabel)
                    .font(.system(size: fontSize, weight: .regular))
                    .foregroundColor(pointColor),
                at: labelPoint,
                anchor: layout.textAnchor
            )
        }
    }

    private func drawCenter(in context: inout GraphicsContext) {
        let radius: CGFloat = 3.2
        let rect = CGRect(
            x: geometry.center.x - radius,
            y: geometry.center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(Path(ellipseIn: rect), with: .color(strongLineGray.opacity(0.24)))
    }

    private func normalizedBodyID(from id: String) -> String {
        if id.hasPrefix("natal-") || id.hasPrefix("transit-") {
            return String(id.split(separator: "-").last ?? "")
        }
        return id
    }

    private func pointDrawPriority(_ point: ChartWheelData.WheelPoint) -> Int {
        switch point.type {
        case .lot: return 0
        case .planet: return point.isTransit ? 2 : 1
        case .angle: return 3
        }
    }
}
