# 任务书 01：颜色令牌动态化 + 深空 Dark Mode（1.2.0 / 36）

> 先读 `00-overview.md` 的全局强约束。本期只做"换肤能力"，**不改任何布局**。
> 目标：浅色外观下 app 与现在**逐像素一致**；深色外观下呈现"深空夜色"配色；程序设置里可选外观。

## 允许改动的文件（超出即停）

- `Sources/TransitStudio/DesignTokens.swift`
- `Sources/TransitStudio/ChartWheelGeometry.swift`
- `Sources/TransitStudio/ChartWheelView.swift`（仅第 4 节的兜底刷新，如需要）
- `Sources/TransitStudio/AppState.swift`
- `Sources/TransitStudio/ContentView.swift`（仅删 `.preferredColorScheme(.light)` 改为绑定设置，一处）
- `Sources/TransitStudio/AppSettingsView.swift`（仅新增"界面"设置 tab）
- `CHANGELOG.md`、`PLANS.md`、`package_app.sh`（版本号两行）

## 1. DesignTokens.swift：动态颜色 helper + 深色值

### 1.1 新增 helper

在 `enum TS` 内（`Spacing` 之前）加入，并在文件顶部 `import SwiftUI` 之后加 `import AppKit`：

```swift
/// Appearance-aware color: parchment palette in light, deep-space in dark.
static func dyn(_ lr: Double, _ lg: Double, _ lb: Double,
                _ dr: Double, _ dg: Double, _ db: Double) -> Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: dr, green: dg, blue: db, alpha: 1)
            : NSColor(srgbRed: lr, green: lg, blue: lb, alpha: 1)
    })
}
```

### 1.2 SemanticColor 全部换成 `dyn`

浅色三元组**必须原样保留现值**（保证浅色外观零变化），深色三元组按下表。示例：

```swift
static let paper = TS.dyn(0.961, 0.937, 0.890,  0.078, 0.086, 0.122)
```

| Token | 浅色（保持现值） | 深色 sRGB | 深色 hex（备查） |
|-------|------------------|-----------|------------------|
| paper | 0.961, 0.937, 0.890 | 0.078, 0.086, 0.122 | #14161F |
| paperRaised | 0.925, 0.898, 0.835 | 0.106, 0.118, 0.165 | #1B1E2A |
| card | 0.984, 0.973, 0.945 | 0.118, 0.133, 0.188 | #1E2230 |
| ink | 0.169, 0.149, 0.125 | 0.910, 0.894, 0.847 | #E8E4D8 |
| inkSoft | 0.420, 0.388, 0.341 | 0.604, 0.592, 0.659 | #9A97A8 |
| inkFaint | 0.612, 0.576, 0.522 | 0.431, 0.416, 0.478 | #6E6A7A |
| line | 0.886, 0.851, 0.780 | 0.180, 0.200, 0.267 | #2E3344 |
| lineSoft | 0.925, 0.894, 0.831 | 0.149, 0.169, 0.227 | #262B3A |
| gold | 0.710, 0.525, 0.184 | 0.831, 0.663, 0.306 | #D4A94E |
| goldDeep | 0.541, 0.392, 0.125 | 0.878, 0.737, 0.420 | #E0BC6B |
| goldSoft | 0.941, 0.894, 0.776 | 0.227, 0.196, 0.133 | #3A3222 |
| hardAspect | 0.690, 0.322, 0.290 | 0.878, 0.478, 0.416 | #E07A6A |
| softAspect | 0.290, 0.490, 0.431 | 0.373, 0.722, 0.627 | #5FB8A0 |
| success | 0.290, 0.490, 0.431 | 0.373, 0.722, 0.627 | #5FB8A0 |
| warning | 0.757, 0.494, 0.180 | 0.878, 0.643, 0.361 | #E0A45C |
| error | 0.690, 0.255, 0.220 | 0.878, 0.467, 0.416 | #E0776A |

`accent`、`accentSubtle`、`cardBackground` 等 Back-compat 别名**保持别名写法不动**（它们引用上面的 token，自动变动态）。

### 1.3 ElementColor 换成 `dyn`

| Token | 浅色（保持现值） | 深色 sRGB | 深色 hex |
|-------|------------------|-----------|----------|
| fire | 0.757, 0.294, 0.227 | 0.878, 0.416, 0.333 | #E06A55 |
| earth | 0.604, 0.463, 0.212 | 0.788, 0.627, 0.353 | #C9A05A |
| air | 0.247, 0.541, 0.471 | 0.373, 0.722, 0.627 | #5FB8A0 |
| water | 0.239, 0.435, 0.682 | 0.416, 0.608, 0.847 | #6A9BD8 |

文件头部那段 "intentionally does NOT follow the system light/dark appearance" 的注释已过时，改写为说明"浅色=羊皮纸、深色=深空夜色、由程序设置控制"。

## 2. ChartWheelGeometry.swift：星盘图配色动态化

现文件第 10–30 行是 19 个固定 `Color(red:...)` 常量。处理规则：

**A. 与 TS token 数值相同的，直接改为引用 token**（浅色值一致，深色自动跟随）：

| 常量 | 改为 |
|------|------|
| pageBackground | `TS.SemanticColor.paper` |
| signBandWhite | `TS.SemanticColor.card` |
| accentCyan | `TS.SemanticColor.gold` |
| goldLine | `TS.SemanticColor.gold` |
| primaryText | `TS.SemanticColor.ink` |
| secondaryText | `TS.SemanticColor.inkSoft` |
| lotTextGray | `TS.SemanticColor.inkFaint` |
| hardAspectColor | `TS.SemanticColor.hardAspect` |
| softAspectColor | `TS.SemanticColor.softAspect` |
| fireColor / earthColor / airColor / waterColor | `TS.ElementColor.fire / .earth / .air / .water` |

**B. 星盘图特有的，用 `TS.dyn`（浅色保持现值）**：

| 常量 | 浅色（保持现值） | 深色 sRGB | 深色 hex |
|------|------------------|-----------|----------|
| mainWhite | 0.996, 0.988, 0.969 | 0.137, 0.153, 0.208 | #232735 |
| outerAuraGray | 0.925, 0.890, 0.816 | 0.098, 0.110, 0.153 | #191C27 |
| zodiacRingGray | 0.937, 0.902, 0.827 | 0.118, 0.133, 0.188 | #1E2230 |
| innerDiskGray | 0.953, 0.918, 0.847 | 0.106, 0.118, 0.165 | #1B1E2A |
| lineGray | 0.839, 0.784, 0.675 | 0.180, 0.200, 0.267 | #2E3344 |
| strongLineGray | 0.420, 0.388, 0.341 | 0.604, 0.592, 0.659 | #9A97A8 |

常量名一律**不改**（避免波及调用处）。

## 3. AppState.swift：外观设置项

按现有模式新增（Key、@Published、init 三处）：

- `Key.appearance = "appAppearance"`
- `@Published var appearance: String { didSet { defaults.set(appearance, forKey: Key.appearance) } }`
- init：`appearance = defaults.string(forKey: Key.appearance) ?? "system"`

取值只有 `"system"` / `"light"` / `"dark"`。再加一个 computed：

```swift
var preferredScheme: ColorScheme? {
    switch appearance {
    case "light": return .light
    case "dark": return .dark
    default: return nil
    }
}
```

（AppState.swift 需要 `ColorScheme`，已 `import SwiftUI`，无需新增 import。）

## 4. ContentView.swift + 星盘刷新兜底

- 把 `ContentView.swift` 第 202 行 `.preferredColorScheme(.light)` 改为 `.preferredColorScheme(appState.preferredScheme)`。
- 手测时若"外观切换后星盘图（Canvas）不立即变色、要重新计算才变"：在 `ChartWheelView` 顶层加 `@Environment(\.colorScheme) private var colorScheme`，并在其最外层视图上追加 `.id(colorScheme)` 强制重建。若手测正常刷新则**不要加**。

## 5. AppSettingsView.swift：新增"界面"tab

在 `TabView` 里**第一个位置**新增：

```swift
settingsPage { interfaceSettings }
    .tabItem { Label("界面", systemImage: "paintbrush") }
```

`interfaceSettings` 参考现有 `pythonSettings` 的写法：`settingsTitle("外观", subtitle: "浅色为羊皮纸主题，深色为深空夜色主题。")` + 一个 `Picker`（segmented），选项为 跟随系统 / 浅色 / 深色，绑定 `$appState.appearance`（id 分别为 `system` / `light` / `dark`）。

## 6. 禁止修 / 不要动

- `WheelTooltip.swift` 的 `.shadow(color: .black.opacity(0.06)...)` 保持不动。
- 不改任何布局、字体、间距 token。
- 不把 `Opacity`、`Layout`、`Font`、`Padding`、`Radius` 动态化。
- `AstroPalette` 的映射逻辑不动（它引用的颜色变动态即可）。
- 不动 `dist/`、`Sources/TransitStudio/Resources/` 下任何文件。

## 7. 验收标准（DoD）

1. `bash check_vibe_changes.sh` 全绿。
2. 浅色外观（设置为"浅色"或系统为浅色）：界面与改动前无可见差异。
3. 设置切"深色"：主界面、侧栏、结果表格、星盘图全部变为深空配色，无残留大块浅色面；文字可读。
4. 设置切"跟随系统"：随系统外观切换而变化。
5. 外观选择重启 app 后保持。
6. `CHANGELOG.md` 顶部新增条目、`PLANS.md` 更新状态、`package_app.sh` 版本改为 `1.2.0` / `36`。
