import SwiftUI

// MARK: - Design Token System
//
// "Celestial Almanac" theme — a fixed warm-parchment palette with a single
// gold accent and serif display type. The app intentionally does NOT follow
// the system light/dark appearance: it keeps its own crafted character.
// All values are expressed as fixed colors so the look is stable regardless
// of the macOS appearance setting.

enum TS {

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

    // MARK: Element Colors (astrology) — retuned for the parchment background
    enum ElementColor {
        static let fire = Color(red: 0.757, green: 0.294, blue: 0.227)   // #C14B3A
        static let earth = Color(red: 0.604, green: 0.463, blue: 0.212)  // #9A7636
        static let air = Color(red: 0.247, green: 0.541, blue: 0.471)    // #3F8A78
        static let water = Color(red: 0.239, green: 0.435, blue: 0.682)  // #3D6FAE
    }

    // MARK: Semantic Colors — fixed "almanac" palette
    enum SemanticColor {
        // Surfaces
        static let paper = Color(red: 0.961, green: 0.937, blue: 0.890)        // #F5EFE3
        static let paperRaised = Color(red: 0.925, green: 0.898, blue: 0.835)  // #ECE5D5
        static let card = Color(red: 0.984, green: 0.973, blue: 0.945)         // #FBF8F1

        // Ink (text)
        static let ink = Color(red: 0.169, green: 0.149, blue: 0.125)          // #2B2620
        static let inkSoft = Color(red: 0.420, green: 0.388, blue: 0.341)      // #6B6357
        static let inkFaint = Color(red: 0.612, green: 0.576, blue: 0.522)     // #9C9385

        // Lines
        static let line = Color(red: 0.886, green: 0.851, blue: 0.780)         // #E2D9C7
        static let lineSoft = Color(red: 0.925, green: 0.894, blue: 0.831)     // #ECE4D4

        // Gold accent
        static let gold = Color(red: 0.710, green: 0.525, blue: 0.184)         // #B5862F
        static let goldDeep = Color(red: 0.541, green: 0.392, blue: 0.125)     // #8A6420
        static let goldSoft = Color(red: 0.941, green: 0.894, blue: 0.776)     // #F0E4C6

        // Aspect polarity
        static let hardAspect = Color(red: 0.690, green: 0.322, blue: 0.290)   // #B0524A
        static let softAspect = Color(red: 0.290, green: 0.490, blue: 0.431)   // #4A7D6E

        // Status
        static let success = Color(red: 0.290, green: 0.490, blue: 0.431)
        static let warning = Color(red: 0.757, green: 0.494, blue: 0.180)
        static let error = Color(red: 0.690, green: 0.255, blue: 0.220)

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
