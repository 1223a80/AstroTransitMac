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

        // Vedic export sections
        case vedicRasi, vedicNavamsa, vedicNakshatra, vedicDasa
        case vedicShadbala, vedicYoga
        // NEW Vedic export sections
        case signIndex, panchanga, solarDay, vedicDivisional
        case moonChart, bhavaChart, planetRelationships
        case arudha, jaiminiKarakas, ashtakavarga

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
            case .vedicRasi: return "Rāśi 盘 (D1)"
            case .vedicNavamsa: return "Navāṃśa (D9)"
            case .vedicNakshatra: return "Nakṣatra 详情"
            case .vedicDasa: return "Daśā 时间线"
            case .vedicShadbala: return "Ṣaḍbala 评分"
            case .vedicYoga: return "Yōga 列表"
            case .signIndex: return "星座索引表"
            case .panchanga: return "五支历 Panchanga"
            case .solarDay: return "日出日落"
            case .vedicDivisional: return "分盘信息"
            case .moonChart: return "Moon Chart"
            case .bhavaChart: return "Bhava Chart"
            case .planetRelationships: return "星体敌友关系"
            case .arudha: return "Arudha"
            case .jaiminiKarakas: return "Jaimini Karakas"
            case .ashtakavarga: return "Ashtakavarga"
            }
        }

        static let timingSectionIDs: Set<ExportSection> = [.profection, .firdaria, .decennials, .zr, .returns, .timeline, .primaryDirections, .circumambulations]

        static let vedicSectionIDs: Set<ExportSection> = [.vedicRasi, .vedicNavamsa, .vedicNakshatra, .vedicDasa, .vedicShadbala, .vedicYoga, .signIndex, .panchanga, .solarDay, .vedicDivisional, .moonChart, .bhavaChart, .planetRelationships, .arudha, .jaiminiKarakas, .ashtakavarga]

        static let classicalSectionIDs: Set<ExportSection> = {
            var ids = Set(ExportSection.allCases)
            ids.subtract(vedicSectionIDs)
            return ids
        }()
    }
}

// MARK: - Vedic Export Facade

extension MarkdownExportBuilder {
    static func vedic(_ result: VedicResult) -> String {
        MarkdownVedicExportBuilder.export(result)
    }

    static func vedic(_ result: VedicResult, sections: Set<ExportSection>) -> String {
        MarkdownVedicExportBuilder.export(result, sections: sections)
    }
}
