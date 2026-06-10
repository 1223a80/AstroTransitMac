# 模块 01：Design Tokens

> **依赖**：无  
> **风险**：低（纯新增文件，不修改现有代码）  
> **产出**：`Sources/TransitStudio/DesignTokens.swift`

## 目标

建立全局设计 token 体系，替代目前散乱的硬编码值（245 处字体声明、99 处 padding、212 处 spacing）。本模块只**创建** token 文件，不修改现有 View——后续模块在各自重构时逐步采用。

## 当前问题

| 类别 | 现状 | 问题 |
|------|------|------|
| 字体 | 51% 用 `.caption`，`.body` 仅 3 次 | 文字层级混乱，表格内容用 caption 太小 |
| 间距 | padding 值 1-24 无规律，14 最常见 | 无法统一调整 |
| 颜色 | `.secondary` 用了 263 次，自定义 RGB 散在 ChartWheelGeometry | 没有语义化色彩 |
| 圆角 | 2/4/6/8/10 五种值混用 | 无层级 |

## 实现规范

### 文件结构

创建 `Sources/TransitStudio/DesignTokens.swift`，使用 `enum` 命名空间（无实例化开销）：

```swift
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
```

### 迁移指南

本模块**不做任何迁移**。后续模块在重构各自文件时，按以下映射表替换：

| 旧写法 | 新写法 |
|--------|--------|
| `.font(.caption)` | `.font(TS.Font.label)` |
| `.font(.caption2)` | `.font(TS.Font.detail)` |
| `.font(.callout)` | `.font(TS.Font.body)` |
| `.font(.headline)` | `.font(TS.Font.sectionTitle)` |
| `.font(.callout.weight(.semibold))` | `.font(TS.Font.sectionTitle)` |
| `.font(.title3.weight(.semibold))` | `.font(TS.Font.pageTitle)` |
| `.padding(14)` | `.padding(TS.Padding.resultContent)` |
| `.padding(18)` | `.padding(TS.Padding.sidebarContent)` |
| `.padding(.horizontal, 10)` | `.padding(.horizontal, TS.Padding.chipHorizontal)` |
| `.clipShape(RoundedRectangle(cornerRadius: 6))` | `.clipShape(RoundedRectangle(cornerRadius: TS.Radius.chip))` |
| `Color(nsColor: .controlBackgroundColor)` | `TS.SemanticColor.cardBackground` |
| `Color.accentColor.opacity(0.14)` | `TS.SemanticColor.accentSubtle` |

### 关于 ChartWheelGeometry 颜色

`ChartWheelGeometry.swift` 中的 14 个颜色常量（`pageBackground`、`fireColor` 等）**不在本模块范围内**。它们服务于 Canvas 绘图的特殊场景，保持不动。`TS.ElementColor` 只用于 UI 层的四元素色彩展示。

## 验证

```bash
swift build
```

纯新增文件，只需 build 通过即可。

## 不要做的事

- ❌ 不要在本模块中修改任何现有 `.swift` 文件
- ❌ 不要把 ChartWheel 的颜色搬到 DesignTokens 里
- ❌ 不要加 View extension（`.tsFont()` 之类）——直接用 `TS.Font.xxx` 足够清晰
