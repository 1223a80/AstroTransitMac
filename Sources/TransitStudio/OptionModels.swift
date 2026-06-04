import Foundation

enum PracticeMode: String, CaseIterable, Identifiable {
    case modern
    case classical
    case vedic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .modern:
            return "现代"
        case .classical:
            return "古典"
        case .vedic:
            return "吠陀"
        }
    }
}

enum CalculationMode: String, CaseIterable, Identifiable {
    case settings
    case horary
    case moment
    case scan
    case rectify

    var id: String { rawValue }

    var title: String {
        switch self {
        case .settings:
            return "本命设置"
        case .horary:
            return "Horary"
        case .moment:
            return "时间点"
        case .scan:
            return "窗口扫描"
        case .rectify:
            return "生时矫正"
        }
    }
}

enum BodyGroup: String, CaseIterable, Identifiable {
    case planets
    case minorBodies
    case virtualPoints

    var id: String { rawValue }

    var title: String {
        switch self {
        case .planets:
            return "行星"
        case .minorBodies:
            return "小行星"
        case .virtualPoints:
            return "虚点 / 轴点"
        }
    }
}

struct BodyOption: Identifiable, Hashable {
    let id: String
    let name: String
    let group: BodyGroup
    let isDefault: Bool
}

let bodyOptions: [BodyOption] = [
    BodyOption(id: "SUN", name: "太阳", group: .planets, isDefault: true),
    BodyOption(id: "MOON", name: "月亮", group: .planets, isDefault: true),
    BodyOption(id: "MERCURY", name: "水星", group: .planets, isDefault: true),
    BodyOption(id: "VENUS", name: "金星", group: .planets, isDefault: true),
    BodyOption(id: "MARS", name: "火星", group: .planets, isDefault: true),
    BodyOption(id: "JUPITER", name: "木星", group: .planets, isDefault: true),
    BodyOption(id: "SATURN", name: "土星", group: .planets, isDefault: true),
    BodyOption(id: "URANUS", name: "天王星", group: .planets, isDefault: true),
    BodyOption(id: "NEPTUNE", name: "海王星", group: .planets, isDefault: true),
    BodyOption(id: "PLUTO", name: "冥王星", group: .planets, isDefault: true),
    BodyOption(id: "CHIRON", name: "凯龙星", group: .minorBodies, isDefault: false),
    BodyOption(id: "CERES", name: "谷神星", group: .minorBodies, isDefault: false),
    BodyOption(id: "PALLAS", name: "智神星", group: .minorBodies, isDefault: false),
    BodyOption(id: "JUNO", name: "婚神星", group: .minorBodies, isDefault: false),
    BodyOption(id: "VESTA", name: "灶神星", group: .minorBodies, isDefault: false),
    BodyOption(id: "PHOLUS", name: "人龙星", group: .minorBodies, isDefault: false),
    BodyOption(id: "MEAN_NODE", name: "北交点 平", group: .virtualPoints, isDefault: false),
    BodyOption(id: "TRUE_NODE", name: "北交点 真", group: .virtualPoints, isDefault: false),
    BodyOption(id: "SOUTH_MEAN_NODE", name: "南交点 平", group: .virtualPoints, isDefault: false),
    BodyOption(id: "SOUTH_TRUE_NODE", name: "南交点 真", group: .virtualPoints, isDefault: false),
    BodyOption(id: "MEAN_LILITH", name: "Lilith 平", group: .virtualPoints, isDefault: false),
    BodyOption(id: "OSCU_LILITH", name: "Lilith 真", group: .virtualPoints, isDefault: false)
]

struct AspectOption: Identifiable, Hashable {
    let id: String
    let name: String
    let angle: Double
    let isDefault: Bool
}

let aspectOptions: [AspectOption] = [
    AspectOption(id: "conjunction", name: "合相", angle: 0, isDefault: true),
    AspectOption(id: "opposition", name: "冲相", angle: 180, isDefault: true),
    AspectOption(id: "trine", name: "拱相", angle: 120, isDefault: true),
    AspectOption(id: "square", name: "刑相", angle: 90, isDefault: true),
    AspectOption(id: "sextile", name: "六合", angle: 60, isDefault: true),
    AspectOption(id: "quincunx", name: "梅花", angle: 150, isDefault: false),
    AspectOption(id: "semisextile", name: "半六合", angle: 30, isDefault: false),
    AspectOption(id: "semisquare", name: "半刑", angle: 45, isDefault: false),
    AspectOption(id: "sesquisquare", name: "补八分相", angle: 135, isDefault: false),
    AspectOption(id: "quintile", name: "五分相", angle: 72, isDefault: false),
    AspectOption(id: "biquintile", name: "倍五分相", angle: 144, isDefault: false)
]
