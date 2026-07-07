import SwiftUI
import AppKit

// MARK: - Design Token System
//
// Two skins: "Celestial Almanac" (light = warm parchment) and
// "Deep Space Night" (dark = deep navy-grey). The active appearance is
// controlled by the user in Settings → 界面.

enum TS {

    // MARK: Dynamic Color Helper
    /// Appearance-aware color: parchment palette in light, deep-space in dark.
    static func dyn(_ lr: Double, _ lg: Double, _ lb: Double,
                    _ dr: Double, _ dg: Double, _ db: Double) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(srgbRed: dr, green: dg, blue: db, alpha: 1)
                : NSColor(srgbRed: lr, green: lg, blue: lb, alpha: 1)
        })
    }

    // MARK: Spacing (4pt base grid)
    enum Spacing {
        static let xs: CGFloat = 2
        static let sm: CGFloat = 4
        static let md: CGFloat = 8
        static let lg: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
    }

    // MARK: Semantic Padding
    enum Padding {
        static let sidebarContent: CGFloat = 18
        static let resultContent: CGFloat = 18
        static let cardInner: CGFloat = 10
        static let sectionGap: CGFloat = 16
        static let chipHorizontal: CGFloat = 11
        static let chipVertical: CGFloat = 4
    }

    // MARK: Corner Radius
    enum Radius {
        static let chip: CGFloat = 7
        static let card: CGFloat = 9
        static let pill: CGFloat = 14
        static let tooltip: CGFloat = 10
    }

    // MARK: Typography
    //
    // Display/titles/tabs use a serif (New York on macOS via `.serif`) for the
    // "almanac" character; data uses monospaced for tabular alignment.
    enum Font {
        static let pageTitle: SwiftUI.Font = .system(.title3, design: .serif).weight(.semibold)
        static let sectionTitle: SwiftUI.Font = .system(.callout, design: .serif).weight(.semibold)
        static let serif: SwiftUI.Font = .system(.body, design: .serif)
        static let serifTab: SwiftUI.Font = .system(.callout, design: .serif)
        static let body: SwiftUI.Font = .callout
        static let label: SwiftUI.Font = .caption
        static let eyebrow: SwiftUI.Font = .system(size: 10, weight: .semibold)
        static let detail: SwiftUI.Font = .caption2
        static let mono: SwiftUI.Font = .system(.callout, design: .monospaced)
        static let monoSmall: SwiftUI.Font = .system(.caption, design: .monospaced)
    }

    // MARK: Element Colors (astrology) — dynamic light/dark
    enum ElementColor {
        static let fire = TS.dyn(0.757, 0.294, 0.227,  0.878, 0.416, 0.333)
        static let earth = TS.dyn(0.604, 0.463, 0.212,  0.788, 0.627, 0.353)
        static let air = TS.dyn(0.247, 0.541, 0.471,  0.373, 0.722, 0.627)
        static let water = TS.dyn(0.239, 0.435, 0.682,  0.416, 0.608, 0.847)
    }

    // MARK: Semantic Colors — dynamic light/dark
    enum SemanticColor {
        // Surfaces
        static let paper = TS.dyn(0.961, 0.937, 0.890,  0.078, 0.086, 0.122)
        static let paperRaised = TS.dyn(0.925, 0.898, 0.835,  0.106, 0.118, 0.165)
        static let card = TS.dyn(0.984, 0.973, 0.945,  0.118, 0.133, 0.188)

        // Ink (text)
        static let ink = TS.dyn(0.169, 0.149, 0.125,  0.910, 0.894, 0.847)
        static let inkSoft = TS.dyn(0.420, 0.388, 0.341,  0.604, 0.592, 0.659)
        static let inkFaint = TS.dyn(0.612, 0.576, 0.522,  0.431, 0.416, 0.478)

        // Lines
        static let line = TS.dyn(0.886, 0.851, 0.780,  0.180, 0.200, 0.267)
        static let lineSoft = TS.dyn(0.925, 0.894, 0.831,  0.149, 0.169, 0.227)

        // Gold accent
        static let gold = TS.dyn(0.710, 0.525, 0.184,  0.831, 0.663, 0.306)
        static let goldDeep = TS.dyn(0.541, 0.392, 0.125,  0.878, 0.737, 0.420)
        static let goldSoft = TS.dyn(0.941, 0.894, 0.776,  0.227, 0.196, 0.133)

        // Aspect polarity
        static let hardAspect = TS.dyn(0.690, 0.322, 0.290,  0.878, 0.478, 0.416)
        static let softAspect = TS.dyn(0.290, 0.490, 0.431,  0.373, 0.722, 0.627)

        // Status
        static let success = TS.dyn(0.290, 0.490, 0.431,  0.373, 0.722, 0.627)
        static let warning = TS.dyn(0.757, 0.494, 0.180,  0.878, 0.643, 0.361)
        static let error = TS.dyn(0.690, 0.255, 0.220,  0.878, 0.467, 0.416)

        // Back-compat aliases (kept so existing call sites keep compiling)
        static let accent = gold
        static let accentSubtle = goldSoft
        static let cardBackground = card
        static let chipBackground = paper
        static let chipSelectedBackground = ink
        static let chipSelectedForeground = paper
        static let divider = line
    }

    // MARK: Opacity
    enum Opacity {
        static let disabled: CGFloat = 0.5
        static let subtle: CGFloat = 0.14
        static let muted: CGFloat = 0.06
        static let aspectHighlight: CGFloat = 0.92
        static let aspectDim: CGFloat = 0.18
    }

    // MARK: Layout
    enum Layout {
        static let navigationRailCollapsed: CGFloat = 72
        static let navigationRailExpanded: CGFloat = 188
        static let sidebarMinWidth: CGFloat = 300
        static let sidebarMaxWidth: CGFloat = 560
        static let sidebarDefaultWidth: CGFloat = 410
        static let sidebarCollapseThreshold: CGFloat = 260
    }
}

// MARK: - Astrology Semantic Palette
//
// Maps domain values (zodiac sign, aspect kind) to the themed colors so the
// table/aspect views can tint rows consistently.
enum AstroPalette {

    /// Sign names emitted by the backend are Chinese (see SIGNS in
    /// astro_backend_core.py). Map each to its classical element color.
    static func elementColor(forSign sign: String) -> Color {
        let key = sign.trimmingCharacters(in: .whitespaces)
        switch key {
        case "白羊", "狮子", "射手", "牡羊":
            return TS.ElementColor.fire
        case "金牛", "处女", "摩羯":
            return TS.ElementColor.earth
        case "双子", "天秤", "水瓶":
            return TS.ElementColor.air
        case "巨蟹", "天蝎", "双鱼":
            return TS.ElementColor.water
        default:
            // Fall back to a leading English-name match for non-tropical output.
            let lower = key.lowercased()
            if lower.hasPrefix("ari") || lower.hasPrefix("leo") || lower.hasPrefix("sag") { return TS.ElementColor.fire }
            if lower.hasPrefix("tau") || lower.hasPrefix("vir") || lower.hasPrefix("cap") { return TS.ElementColor.earth }
            if lower.hasPrefix("gem") || lower.hasPrefix("lib") || lower.hasPrefix("aqu") { return TS.ElementColor.air }
            if lower.hasPrefix("can") || lower.hasPrefix("sco") || lower.hasPrefix("pis") { return TS.ElementColor.water }
            return TS.SemanticColor.inkFaint
        }
    }

    /// Hard / soft / neutral classification for an aspect id.
    static func aspectColor(forID aspectID: String) -> Color {
        switch aspectID {
        case "square", "opposition", "semisquare", "sesquisquare", "quincunx":
            return TS.SemanticColor.hardAspect
        case "trine", "sextile", "semisextile":
            return TS.SemanticColor.softAspect
        default:
            return TS.SemanticColor.gold
        }
    }

    /// 0...1 strength for an aspect given its orb (tighter = stronger).
    static func aspectStrength(orb: Double, maxOrb: Double = 8) -> Double {
        let clamped = max(0, min(orb, maxOrb))
        return 1 - clamped / maxOrb
    }
}
