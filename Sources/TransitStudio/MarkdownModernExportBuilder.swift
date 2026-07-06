import Foundation

enum MarkdownModernExportBuilder {
    static func synastry(_ result: SynastryResult) -> String {
        var lines: [String] = ["# Synastry 合盘"]
        lines.append(contentsOf: metaLines(result.meta))
        lines.append("")
        lines.append("## A 本命行星")
        lines.append(contentsOf: MarkdownExportBuilder.positionSection("A", result.personAPlanets))
        lines.append("")
        lines.append("## B 本命行星")
        lines.append(contentsOf: MarkdownExportBuilder.positionSection("B", result.personBPlanets))
        lines.append("")
        lines.append("## 跨盘相位")
        if result.crossAspects.isEmpty {
            lines.append("无跨盘相位。")
        } else {
            lines.append("| A天体 | 相位 | B天体 | 角度 | 容许度 |")
            lines.append("|-------|------|-------|------|--------|")
            for asp in result.crossAspects {
                lines.append("| \(asp.transitBodyName) | \(asp.aspectName) | \(asp.natalBodyName) | \(MarkdownExportBuilder.degree(asp.separation, digits: 2)) | \(MarkdownExportBuilder.degree(asp.orb, digits: 2)) |")
            }
        }
        lines.append("")
        lines.append("## A落入B宫")
        lines.append(contentsOf: housePlacementLines(result.aInBHouses))
        lines.append("")
        lines.append("## B落入A宫")
        lines.append(contentsOf: housePlacementLines(result.bInAHouses))
        lines.append(contentsOf: MarkdownExportBuilder.warnings(result.warnings))
        return lines.joined(separator: "\n")
    }

    static func compositeOrDavison(title: String, result: some ChartResultFields) -> String {
        compositeOrDavisonContent(title: title, meta: result.meta, planets: result.planets, aspects: result.aspects, patterns: result.patterns, warnings: result.warnings)
    }

    private static func compositeOrDavisonContent(
        title: String, meta: ModernMeta, planets: [PositionRow],
        aspects: [AspectHit], patterns: [PatternResult]?, warnings: [String]
    ) -> String {
        var lines: [String] = ["# \(title) 盘"]
        lines.append(contentsOf: metaLines(meta))
        lines.append("")
        lines.append("## 行星位置")
        lines.append(contentsOf: MarkdownExportBuilder.positionSection(title, planets))
        lines.append("")
        lines.append("## 相位")
        if aspects.isEmpty {
            lines.append("无相位。")
        } else {
            lines.append("| 天体A | 相位 | 天体B | 分隔角 | 容许度 |")
            lines.append("|-------|------|-------|--------|--------|")
            for asp in aspects {
                lines.append("| \(asp.transitBodyName) | \(asp.aspectName) | \(asp.natalBodyName) | \(MarkdownExportBuilder.degree(asp.separation, digits: 2)) | \(MarkdownExportBuilder.degree(asp.orb, digits: 2)) |")
            }
        }
        if let p = patterns, !p.isEmpty {
            lines.append("")
            lines.append("## 图形模式")
            for pt in p {
                lines.append("- **\(pt.typeName)**（\(pt.confidence)）：\(pt.members.joined(separator: ", "))")
            }
        }
        lines.append(contentsOf: MarkdownExportBuilder.warnings(warnings))
        return lines.joined(separator: "\n")
    }

    static func progression(_ result: ProgressionResult) -> String {
        var lines: [String] = ["# 次限推进"]
        lines.append(contentsOf: metaLines(result.meta))
        lines.append("")
        lines.append("## 本命盘")
        lines.append(contentsOf: MarkdownExportBuilder.positionSection("本命", result.natalPlanets))
        lines.append("")
        lines.append("## 次限推进盘")
        lines.append(contentsOf: MarkdownExportBuilder.positionSection("推进", result.progressedPlanets))
        if let lunation = result.progressedLunation {
            lines.append("")
            lines.append("## 推进月相")
            lines.append("- 日月夹角：\(MarkdownExportBuilder.degree(lunation.sunMoonSeparation, digits: 2))")
            lines.append("- 最近相位角：\(MarkdownExportBuilder.degree(lunation.phaseAngle, digits: 0))")
            lines.append("- 月相：\(lunation.phaseName)")
        }
        if !result.progressedToNatalAspects.isEmpty {
            lines.append("")
            lines.append("## 推进→本命相位")
            lines.append("| 推进天体 | 相位 | 本命天体 | 分隔角 | 容许度 |")
            lines.append("|----------|------|----------|--------|--------|")
            for asp in result.progressedToNatalAspects {
                lines.append("| \(asp.transitBodyName) | \(asp.aspectName) | \(asp.natalBodyName) | \(MarkdownExportBuilder.degree(asp.separation, digits: 2)) | \(MarkdownExportBuilder.degree(asp.orb, digits: 2)) |")
            }
        }
        lines.append(contentsOf: MarkdownExportBuilder.warnings(result.warnings))
        return lines.joined(separator: "\n")
    }

    static func solarArc(_ result: SolarArcResult) -> String {
        var lines: [String] = ["# Solar Arc 推运"]
        lines.append(contentsOf: metaLines(result.meta))
        lines.append("")
        lines.append("**Arc: \(MarkdownExportBuilder.degree(result.arcValue, digits: 4))**")
        lines.append("")
        lines.append("## 本命盘")
        lines.append(contentsOf: MarkdownExportBuilder.positionSection("本命", result.natalPlanets))
        lines.append("")
        lines.append("## Solar Arc 盘")
        lines.append(contentsOf: MarkdownExportBuilder.positionSection("SA", result.solarArcPlanets))
        if !result.solarArcToNatalAspects.isEmpty {
            lines.append("")
            lines.append("## SA→本命相位")
            lines.append("| SA天体 | 相位 | 本命天体 | 分隔角 | 容许度 |")
            lines.append("|--------|------|----------|--------|--------|")
            for asp in result.solarArcToNatalAspects {
                lines.append("| \(asp.transitBodyName) | \(asp.aspectName) | \(asp.natalBodyName) | \(MarkdownExportBuilder.degree(asp.separation, digits: 2)) | \(MarkdownExportBuilder.degree(asp.orb, digits: 2)) |")
            }
        }
        if let patterns = result.patterns, !patterns.isEmpty {
            lines.append("")
            lines.append("## 图形模式")
            for p in patterns {
                lines.append("- **\(p.typeName)**（\(p.confidence)）：\(p.members.joined(separator: ", "))")
            }
        }
        lines.append(contentsOf: MarkdownExportBuilder.warnings(result.warnings))
        return lines.joined(separator: "\n")
    }

    static func harmonic(_ result: HarmonicResult) -> String {
        var lines: [String] = ["# Harmonic 调和盘"]
        lines.append(contentsOf: metaLines(result.meta))
        lines.append("")
        lines.append("## 调和盘位置")
        lines.append(contentsOf: MarkdownExportBuilder.positionSection("H\(result.harmonicOrder)", result.planets))
        if !result.aspects.isEmpty {
            lines.append("")
            lines.append("## 调和盘相位")
            lines.append("| 天体A | 相位 | 天体B | 分隔角 | 容许度 |")
            lines.append("|-------|------|-------|--------|--------|")
            for asp in result.aspects {
                lines.append("| \(asp.transitBodyName) | \(asp.aspectName) | \(asp.natalBodyName) | \(MarkdownExportBuilder.degree(asp.separation, digits: 2)) | \(MarkdownExportBuilder.degree(asp.orb, digits: 2)) |")
            }
        }
        lines.append(contentsOf: MarkdownExportBuilder.warnings(result.warnings))
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    static func metaLines(_ meta: ModernMeta) -> [String] {
        var lines: [String] = []
        lines.append("- 方法：\(meta.method)")
        if let eph = meta.ephemeris { lines.append("- 星历：\(eph)") }
        return lines
    }

    static func housePlacementLines(_ placements: [HousePlacement]) -> [String] {
        if placements.isEmpty { return ["无数据。"] }
        var lines: [String] = ["| 天体 | 宫位 |", "|------|------|"]
        for p in placements {
            lines.append("| \(p.bodyName) | \(p.house) |")
        }
        return lines
    }
}
