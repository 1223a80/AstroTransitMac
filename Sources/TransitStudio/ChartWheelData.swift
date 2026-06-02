import Foundation

enum WheelElement: CaseIterable {
    case fire, earth, air, water
}

func elementForSign(index: Int) -> WheelElement {
    switch index % 12 {
    case 0, 4, 8: return .fire
    case 1, 5, 9: return .earth
    case 2, 6, 10: return .air
    default: return .water
    }
}

let signShortLabels = ["羊", "牛", "双", "蟹", "狮", "处", "秤", "蝎", "射", "摩", "瓶", "鱼"]

let planetShortLabels: [String: String] = [
    "SUN": "日", "MOON": "月", "MERCURY": "水", "VENUS": "金",
    "MARS": "火", "JUPITER": "木", "SATURN": "土",
    "URANUS": "天", "NEPTUNE": "海", "PLUTO": "冥",
    "CHIRON": "凯", "CERES": "谷", "PALLAS": "智", "JUNO": "婚", "VESTA": "灶",
    "MEAN_NODE": "北", "TRUE_NODE": "北", "SOUTH_MEAN_NODE": "南", "SOUTH_TRUE_NODE": "南",
]

let angleShortLabels: [String: String] = [
    "ASC": "升", "MC": "顶", "DSC": "降", "IC": "底",
]

let lotShortLabels: [String: String] = [
    "fortune": "福", "spirit": "神", "eros": "爱",
    "necessity": "需", "courage": "勇", "victory": "胜",
    "nemesis": "报", "basis": "基",
]

struct ChartWheelData {
    enum PointType { case planet, angle, lot }

    struct WheelPoint: Identifiable {
        let id: String
        let name: String
        let shortLabel: String
        let longitude: Double
        let house: Int
        let sign: String
        let signIndex: Int
        let degreeText: String
        let element: WheelElement
        let type: PointType
        let isTransit: Bool
    }

    struct WheelAspect: Identifiable {
        let id: String
        let pointAID: String
        let pointBID: String
        let type: String
    }

    let points: [WheelPoint]
    let houseCusps: [Double]
    let axisLongitudes: [Double]
    let aspects: [WheelAspect]
}

extension ChartWheelData {
    init(classicalResult: ClassicalResult) {
        var pts: [WheelPoint] = []
        for p in classicalResult.planets {
            let signIdx = Int(p.longitude / 30) % 12
            pts.append(WheelPoint(
                id: p.id, name: p.name, shortLabel: planetShortLabels[p.id] ?? String(p.name.prefix(1)),
                longitude: p.longitude, house: p.house, sign: p.sign, signIndex: signIdx,
                degreeText: p.degreeText, element: elementForSign(index: signIdx),
                type: .planet, isTransit: false
            ))
        }
        for a in classicalResult.angles {
            let signIdx = Int(a.longitude / 30) % 12
            pts.append(WheelPoint(
                id: a.id, name: a.name, shortLabel: angleShortLabels[a.id] ?? String(a.name.prefix(1)),
                longitude: a.longitude, house: a.house, sign: a.sign, signIndex: signIdx,
                degreeText: a.degreeText, element: elementForSign(index: signIdx),
                type: .angle, isTransit: false
            ))
        }
        for l in classicalResult.lots {
            let signIdx = Int(l.longitude / 30) % 12
            pts.append(WheelPoint(
                id: l.id, name: l.name, shortLabel: lotShortLabels[l.id] ?? String(l.name.prefix(1)),
                longitude: l.longitude, house: l.house, sign: l.sign, signIndex: signIdx,
                degreeText: l.degreeText, element: elementForSign(index: signIdx),
                type: .lot, isTransit: false
            ))
        }
        self.points = pts
        self.houseCusps = classicalResult.houses.map(\.cuspLongitude)
        self.axisLongitudes = classicalResult.angles.map(\.longitude)
        self.aspects = classicalResult.aspects.map { a in
            WheelAspect(id: "\(a.bodyA)-\(a.bodyB)", pointAID: a.bodyA, pointBID: a.bodyB, type: a.aspect)
        }
    }

    init(transitResult: TransitResult) {
        var pts: [WheelPoint] = []
        for p in transitResult.natalPositions {
            let signIdx = Int(p.longitude / 30) % 12
            pts.append(WheelPoint(
                id: "natal-\(p.bodyID)", name: p.name,
                shortLabel: planetShortLabels[p.bodyID] ?? String(p.name.prefix(1)),
                longitude: p.longitude, house: p.house ?? 0, sign: p.sign, signIndex: signIdx,
                degreeText: p.degreeText, element: elementForSign(index: signIdx),
                type: .planet, isTransit: false
            ))
        }
        for p in transitResult.transitPositions {
            let signIdx = Int(p.longitude / 30) % 12
            pts.append(WheelPoint(
                id: "transit-\(p.bodyID)", name: p.name,
                shortLabel: planetShortLabels[p.bodyID] ?? String(p.name.prefix(1)),
                longitude: p.longitude, house: p.house ?? 0, sign: p.sign, signIndex: signIdx,
                degreeText: p.degreeText, element: elementForSign(index: signIdx),
                type: .planet, isTransit: true
            ))
        }
        let houseCusps = transitResult.houses?.map(\.cuspLongitude) ?? (0..<12).map { Double($0 * 30) }
        self.points = pts
        self.houseCusps = houseCusps
        self.axisLongitudes = transitResult.angles?.map(\.longitude) ?? [houseCusps[0], houseCusps[3], houseCusps[6], houseCusps[9]]
        self.aspects = transitResult.aspects.map { a in
            WheelAspect(
                id: "\(a.transitBodyID)-\(a.aspectID)-\(a.natalBodyID)",
                pointAID: "transit-\(a.transitBodyID)",
                pointBID: "natal-\(a.natalBodyID)",
                type: a.aspectName
            )
        }
    }

    init(natalResult: TransitResult) {
        var pts: [WheelPoint] = []
        for p in natalResult.natalPositions {
            let signIdx = Int(p.longitude / 30) % 12
            pts.append(WheelPoint(
                id: p.bodyID, name: p.name,
                shortLabel: planetShortLabels[p.bodyID] ?? String(p.name.prefix(1)),
                longitude: p.longitude, house: p.house ?? 0, sign: p.sign, signIndex: signIdx,
                degreeText: p.degreeText, element: elementForSign(index: signIdx),
                type: .planet, isTransit: false
            ))
        }
        if let angles = natalResult.angles {
            for a in angles {
                let signIdx = Int(a.longitude / 30) % 12
                pts.append(WheelPoint(
                    id: a.id, name: a.name,
                    shortLabel: angleShortLabels[a.id] ?? String(a.name.prefix(1)),
                    longitude: a.longitude, house: a.house ?? 0, sign: a.sign, signIndex: signIdx,
                    degreeText: a.degreeText, element: elementForSign(index: signIdx),
                    type: .angle, isTransit: false
                ))
            }
        }
        let houseCusps = natalResult.houses?.map(\.cuspLongitude) ?? (0..<12).map { Double($0 * 30) }
        self.points = pts
        self.houseCusps = houseCusps
        self.axisLongitudes = natalResult.angles?.map(\.longitude) ?? [houseCusps[0], houseCusps[3], houseCusps[6], houseCusps[9]]
        self.aspects = natalResult.aspects.map { a in
            WheelAspect(
                id: "\(a.transitBodyID)-\(a.aspectID)-\(a.natalBodyID)",
                pointAID: a.transitBodyID,
                pointBID: a.natalBodyID,
                type: a.aspectName
            )
        }
    }

    init(horaryResult: HoraryResult) {
        var pts: [WheelPoint] = []
        for p in horaryResult.planets {
            let signIdx = Int(p.longitude / 30) % 12
            pts.append(WheelPoint(
                id: p.id, name: p.name, shortLabel: planetShortLabels[p.id] ?? String(p.name.prefix(1)),
                longitude: p.longitude, house: p.house, sign: p.sign, signIndex: signIdx,
                degreeText: p.degreeText, element: elementForSign(index: signIdx),
                type: .planet, isTransit: false
            ))
        }
        for a in horaryResult.angles {
            let signIdx = Int(a.longitude / 30) % 12
            pts.append(WheelPoint(
                id: a.id, name: a.name, shortLabel: angleShortLabels[a.id] ?? String(a.name.prefix(1)),
                longitude: a.longitude, house: a.house, sign: a.sign, signIndex: signIdx,
                degreeText: a.degreeText, element: elementForSign(index: signIdx),
                type: .angle, isTransit: false
            ))
        }
        self.points = pts
        self.houseCusps = horaryResult.houses.map(\.cuspLongitude)
        self.axisLongitudes = horaryResult.angles.map(\.longitude)
        self.aspects = horaryResult.aspects.map { a in
            WheelAspect(id: "\(a.bodyA)-\(a.bodyB)", pointAID: a.bodyA, pointBID: a.bodyB, type: a.aspect)
        }
    }
}
