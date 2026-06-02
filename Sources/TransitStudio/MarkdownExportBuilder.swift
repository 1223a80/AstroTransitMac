import Foundation

enum MarkdownExportBuilder {
    enum ExportSection: String, CaseIterable, Identifiable {
        case angles, houses, planets, scoreSummary, triplicitySummary
        case lots, aspects, receptions
        case antiscia, primaryDirections, circumambulations
        case activeOverview, profection, firdaria, decennials, zr
        case returns, timeline
        case almuten, hyleg, prenatalSyzygy
        case warnings

        var id: String { rawValue }

        var label: String {
            switch self {
            case .angles: return "角点"
            case .houses: return "宫位"
            case .planets: return "星体状态"
            case .scoreSummary: return "评分汇总"
            case .triplicitySummary: return "三分主汇总"
            case .lots: return "Lots"
            case .aspects: return "相位"
            case .receptions: return "接纳"
            case .antiscia: return "映点"
            case .primaryDirections: return "主限法"
            case .circumambulations: return "沿界推进"
            case .activeOverview: return "活跃概要"
            case .profection: return "小限"
            case .firdaria: return "Firdaria"
            case .decennials: return "Decennials"
            case .zr: return "Zodiacal Releasing"
            case .returns: return "返照盘"
            case .timeline: return "时间线"
            case .almuten: return "Almuten"
            case .hyleg: return "Hyleg/Alcocoden"
            case .prenatalSyzygy: return "产前朔望"
            case .warnings: return "警告"
            }
        }

        static let timingSectionIDs: Set<ExportSection> = [.profection, .firdaria, .decennials, .zr, .returns, .timeline, .primaryDirections, .circumambulations]
    }
}
