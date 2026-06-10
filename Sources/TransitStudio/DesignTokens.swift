import SwiftUI

// MARK: - Design Token System

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
        static let resultContent: CGFloat = 14
        static let cardInner: CGFloat = 8
        static let sectionGap: CGFloat = 16
        static let chipHorizontal: CGFloat = 10
        static let chipVertical: CGFloat = 4
    }

    // MARK: Corner Radius
    enum Radius {
        static let chip: CGFloat = 6
        static let card: CGFloat = 8
        static let tooltip: CGFloat = 10
    }

    // MARK: Typography
    enum Font {
        static let pageTitle: SwiftUI.Font = .title3.weight(.semibold)
        static let sectionTitle: SwiftUI.Font = .callout.weight(.semibold)
        static let body: SwiftUI.Font = .callout
        static let label: SwiftUI.Font = .caption
        static let detail: SwiftUI.Font = .caption2
        static let mono: SwiftUI.Font = .system(.callout, design: .monospaced)
        static let monoSmall: SwiftUI.Font = .system(.caption, design: .monospaced)
    }

    // MARK: Element Colors (astrology)
    enum ElementColor {
        static let fire = Color(red: 1.000, green: 0.353, blue: 0.322)
        static let earth = Color(red: 0.847, green: 0.545, blue: 0.204)
        static let air = Color(red: 0.200, green: 0.824, blue: 0.631)
        static let water = Color(red: 0.122, green: 0.561, blue: 1.000)
    }

    // MARK: Semantic Colors
    enum SemanticColor {
        static let accent = Color.accentColor
        static let accentSubtle = Color.accentColor.opacity(0.14)
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let cardBackground = Color(nsColor: .controlBackgroundColor)
        static let chipBackground = Color(nsColor: .controlBackgroundColor)
        static let chipSelectedBackground = Color.accentColor
        static let chipSelectedForeground = Color.white
        static let divider = Color(nsColor: .separatorColor)
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
        static let navigationRailExpanded: CGFloat = 178
        static let sidebarMinWidth: CGFloat = 320
        static let sidebarMaxWidth: CGFloat = 560
        static let sidebarDefaultWidth: CGFloat = 430
        static let sidebarCollapseThreshold: CGFloat = 260
    }
}
