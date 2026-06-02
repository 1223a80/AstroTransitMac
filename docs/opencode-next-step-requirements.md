# 下一步需求文档

## ✅ 已完成：时间点 / 窗口扫描预设管理

> 该功能已于 2026-05 实现。以下 §1-10 为历史需求记录，代码位置：
> - [ContentView+ConfigTemplates.swift:193](https://github.com/anomalyco/AstroTransitMac/Sources/TransitStudio/ContentView+ConfigTemplates.swift#L193)
> - [ContentView+SidebarSections.swift:49](https://github.com/anomalyco/AstroTransitMac/Sources/TransitStudio/ContentView+SidebarSections.swift#L49)
> - [RequestModels.swift:104](https://github.com/anomalyco/AstroTransitMac/Sources/TransitStudio/RequestModels.swift#L104)

### 1. 背景

当前项目已经具备这些能力：

- 本命盘资料可保存、载入、删除。
- `时间点` 与 `窗口扫描` 页面都支持把当前选择导出为行式模板文本。
- 用户也可以把模板文本粘贴回编辑区，再通过"解析回填"恢复 UI 选择。
- 结果区已经支持 Markdown / JSON / CSV 导出。

当前缺口也很明确：

- `时间点模板` 和 `扫描模板` 只是临时文本，没有持久化预设。
- 用户反复使用同一组行运体、相位、目标点时，需要手动复制粘贴，成本高。
- 现有代码已经有模板生成和模板解析逻辑，不应该再发明一套新的配置协议。

这次任务的目标，是在不改后端接口的前提下，为 `时间点` 和 `窗口扫描` 增加本地预设管理。

### 2. 目标

让用户可以在 app 内：

- 保存当前 `时间点` 配置为命名预设。
- 保存当前 `扫描` 配置为命名预设。
- 载入、更新、删除预设。
- 重启 app 后仍能看到这些预设。

### 3. 范围

本次只做本地预设管理，范围限定如下：

- 为 `时间点` 和 `窗口扫描` 分别维护独立的预设列表。
- 预设内容直接复用现有模板文本格式。
- 保存时，以当前 UI 状态生成模板文本后存入预设。
- 载入时，把预设文本写回编辑区，并复用现有"解析回填"逻辑恢复 UI。
- 存储方式沿用当前项目风格，使用本地持久化方案，优先参考现有 `natalProfilesJSON` 的做法。

### 4. 非目标

本次不要做这些事：

- 不修改 Python 后端。
- 不修改现有请求 JSON 结构。
- 不引入数据库、Core Data、SwiftData、iCloud 同步。
- 不重做侧边栏布局。
- 不顺手扩展成"任意模式通用预设中心"。
- 不补一个新的模板语法。

### 5. 功能需求

#### 5.1 时间点预设

- 在 `时间点模板` 区块中增加预设名称输入与预设操作区。
- 用户可以保存当前时间点配置为一个命名预设。
- 如果当前选中了已有预设，保存应更新该预设，而不是重复新增。
- 用户可以从列表中选择一个时间点预设并载入。
- 用户可以删除当前选中的时间点预设。

#### 5.2 窗口扫描预设

- 在 `扫描模板` 区块中增加预设名称输入与预设操作区。
- 用户可以保存当前扫描配置为一个命名预设。
- 如果当前选中了已有预设，保存应更新该预设，而不是重复新增。
- 用户可以从列表中选择一个扫描预设并载入。
- 用户可以删除当前选中的扫描预设。

#### 5.3 预设内容

时间点预设至少应保存这些由现有模板已覆盖的信息：

- 行运时间
- 本命天体
- 行运天体
- 相位
- 自定义相位角度
- 自定义小行星
- 全局容许度

扫描预设至少应保存这些由现有模板已覆盖的信息：

- 扫描类型
- 标签
- 开始 / 结束时间
- 月亮过滤方式
- 扫描行运体
- 目标来源
- 目标行星 / 虚点 / 小行星 / 宫位 / Lots
- 自定义目标文本
- 相位
- 自定义相位角度
- 自定义小行星

#### 5.4 持久化与异常处理

- 预设重启后必须保留。
- 预设名称不能为空。
- 同一类型预设若同名，允许覆盖更新，但行为要一致、明确。
- 若某条预设文本损坏，载入时应走现有错误提示路径，不允许崩溃。

### 6. 交互要求

- 交互风格保持和当前 SwiftUI 界面一致，不要额外做复杂弹窗流程。
- 现有"复制参考格式"和"解析回填"按钮要保留。
- 预设操作应放在模板区附近，不要分散到设置页。
- 当没有选中预设时，`载入` / `删除` 这类操作应有合理禁用态。
- 成功保存后，当前选中项应切到刚保存的预设。

### 7. 实现约束

实现时请优先复用已有代码和模式：

- 参考 `ContentView+ConfigTemplates.swift`
- 参考 `ContentView+NatalProfiles.swift`
- 参考 `ContentView+SidebarSections.swift`
- 参考 `ContentView.swift`
- 新增的数据模型可以放在现有请求 / 选项模型附近，但不要打散到无关文件。

明确约束：

- 不要复制一份新的模板解析器。
- 不要把预设拆成大量零散字段存储。
- 优先把"模板文本"作为预设主体，减少双份状态。

### 8. 验收标准

满足以下条件才算完成：

1. 可以保存一个时间点预设，关闭并重新打开 app 后仍能看到它。
2. 可以保存一个扫描预设，关闭并重新打开 app 后仍能看到它。
3. 载入时间点预设后，相关 UI 控件能被正确回填。
4. 载入扫描预设后，相关 UI 控件能被正确回填。
5. 更新已有预设不会生成重复垃圾数据。
6. 删除预设后，列表和当前选中状态会同步刷新。
7. 现有"复制参考格式"和"解析回填"功能不回归。
8. `swift build` 可以通过。

### 9. 建议验证步骤

实现完成后，至少做这些验证：

1. 在 `时间点` 页保存一个预设，修改选择，再载入，确认回填正确。
2. 在 `窗口扫描` 页保存一个预设，修改选择，再载入，确认回填正确。
3. 重启 app，确认两类预设都还在。
4. 删除预设后，确认列表、输入框、选中状态没有残留异常。
5. 跑一次 `swift build`，确认没有编译错误。

### 10. 交付要求

交付时应包含：

- 实际代码修改
- 简短变更说明
- 明确列出验证结果
- 如果有未完成项或权衡，必须直说
- 每次修改完代码后，都要在项目根目录的 `CHANGELOG.md` 追加简短修改说明；如果文件不存在，先创建它。

---

## 11. 图形星盘 (Chart Wheel)

### 11.1 背景

当前所有结果以表格+文本呈现，缺少直观的圆形盘面展示。用户在古典/本命/行运/卜卦/扫描模式看到的都是文本表。图形盘面可以一眼看到星体布局、宫位分布、相位关系，大幅提升视觉体验。

### 11.2 目标

- 在每个结果模式的标签栏增加「星盘图」Tab
- 渲染圆形星盘，包含：黄道12宫环、宫位分割、行星符号、四轴、相位连线
- 交互：悬停/点击行星显示详情
- 零第三方依赖，零后端修改

### 11.3 技术方案

macOS 13+ 的 `Canvas` + `GraphicsContext` API 实现全部绘制。不引入第三方库。

**模块结构（4 文件拆分，避免单文件热点）：**

```
Sources/TransitStudio/
  ChartWheelData.swift         — 数据模型 + 适配器 (~100 行)
    ChartWheelData { points, houseCusps, aspects }
    WheelPoint { id, name, longitude, house, sign, type }
    WheelAspect { bodyA, bodyB, type, color }
    init(classicalResult:), init(transitResult:), init(horaryResult:)

  ChartWheelGeometry.swift     — 几何计算 (~150 行)
    longitude → polar coordinate (cx, cy, 角度从顶部顺时针)
    宫弧线分段、相位弦计算、标签位置偏移
    ringBoundingRects, houseArcPaths, aspectLinePoints

  ChartWheelCanvas.swift       — Canvas 绘制层 (~350 行)
    基于 GraphicsContext 绘制：
      ├─ ZodiacRing     — 12 色段 + 星座符号 + 刻度线
      ├─ HouseRing      — 宫位分割线 + 宫号
      ├─ PlanetLayer    — Unicode 符号 + 名称标签
      ├─ AspectLayer    — 相位连线（按相位类型着色）
      └─ SelectionLayer — 当前 hover/选中高亮

  ChartWheelInteraction.swift  — 交互状态管理 (~100 行)
    hoveredPointID, selectedPointID
    onHover / onTap 回调
    Tooltip overlay 视图
```

**坐标系映射：** `longitude 0-360° → Canvas 坐标`，Canvas 中心为 (cx, cy)，角度从顶部顺时针：`angle = 90° - longitude`

**行星符号：** 使用 Unicode（☉ ☽ ☿ ♀ ♂ ♃ ♄）+ 自定义 Path

**配色：** `@Environment(\.colorScheme)` 自适应浅色/深色模式

### 11.4 范围

| 模式 | 数据来源 | Tab 插入 |
|------|---------|----------|
| classical | `ClassicalResult.planets + .angles + .lots + .aspects` | `tabRows` 加 ("wheel", "星盘图") |
| modern natal | `TransitResult.natalPositions + .aspects` | 同上 |
| moment | `TransitResult.natalPositions + .transitPositions + .aspects` | 同上 |
| horary | `HoraryResult.planets + .angles + .aspects` | 同上 |

### 11.5 非目标

- 不做实时动画（不随时间自动刷新盘面）
- 初期不做拖拽旋转（固定视角，后续可加）
- 不做盘面导出为图片（后续可加）
- 不引入 SVG/D3 等 Web 技术
- 不修改 Python 后端
- 不依赖外部字体或图片资源

### 11.6 数据需求

```swift
struct ChartWheelData {
    struct WheelPoint {
        let id: String
        let name: String          // 显示名称
        let longitude: Double     // 0-360°，决定盘面角度
        let house: Int            // 宫位号
        let sign: String          // 星座名
        let type: PointType       // .planet / .angle / .lot / .houseCusp
    }
    let points: [WheelPoint]      // 所有盘面点
    let houseCusps: [Double]      // 12 宫黄经
    let aspects: [WheelAspect]    // 可选相位线
}
```

### 11.7 交互要求

- 鼠标 hover 到行星符号时显示 tooltip（名称 + 位置 + 宫位）
- 点击行星高亮其所有相位连线
- 支持滚轮缩放（可选）

### 11.8 实现约束

- 新代码按 4 文件拆分（Data / Geometry / Canvas / Interaction），严禁合入单文件
- 每个文件职责单一，单文件不超过 350 行
- `ChartWheelData` 只做数据适配，不涉及几何或绘制
- `ChartWheelCanvas` 只接收 `GraphicsContext` + 纯数据参数，不持有可变状态
- `ChartWheelInteraction` 负责所有 `@State` / `@Gesture` 逻辑
- 公共入口视图 `ChartWheelView` 组合以上 4 个模块
- 不修改 Python 后端
- 不引入新依赖

### 11.9 验收标准

1. 在 classical 模式 Tab 栏中看到「星盘图」Tab，点击后显示完整的圆形星盘
2. 在 modern natal、moment、horary 模式中同样可用
3. 盘面包含：星座环（12色段+符号+刻度）、宫位分割线、行星符号+名称、四轴标注
4. 行星位置与表格数据一致（经度映射到盘面对应位置）
5. hover 行星时显示 tooltip
6. 浅色/深色模式下显示正常
7. `swift build` 通过

### 11.10 验证步骤

1. 切换 classical → 点击星盘图 Tab → 确认盘面渲染
2. 对比盘面行星位置与「行星状态」Tab 的经度数据
3. 切换 moment → 确认双方行星均显示
4. 切换 horary → 确认正常
5. 切换浅色/深色模式
6. `swift build`

---

## 12. 经典模式时间技法分离

### 12.1 背景

当前经典模式排盘一次输出全部数据（本命 + 时间技法），导出也是一次全量 Markdown。用户需要：
- 排盘后只改参考时间就重新计算时间技法，不重新算本命
- 导出时只选择需要的技法条目，不要一次倒出全部

### 12.2 目标

- 保留现有排盘按钮行为（一次全算，向后兼容）
- 追加「更新时间技法」按钮，单独重新计算时间技法部分
- 导出时弹窗选择要包含的 section

### 12.3 工作流

```
① 设置本命盘 + 参考时间 → [排盘] → 全套数据（与现在完全一致）
② 更改参考时间 → [更新时间技法] → 重新计算时间技法，本命数据不变
③ [导出] → 弹窗勾选 section → 生成所选 Markdown
```

### 12.4 改动范围

| 改动 | 文件 | 行数 | 说明 |
|------|------|------|------|
| 追加「更新时间技法」按钮+DatePicker | `ContentView+ResultsPanes.swift` | ~30 | 时间技法 tab 上方 |
| `runClassicalTiming()` | `ContentView+RunActions.swift` | ~30 | 调后端、替换 `classicalResult` 的 timing 字段 |
| 分段导出弹窗 | `MarkdownExportBuilder.swift` + `ExportControls.swift` | ~80 | 暴露各 section 方法；导出口弹窗 checklist |
| 后端 | 不变 | 0 | 不做任何后端修改 |
| **合计** | | **~140行** | |

### 12.5 实现约束

- 每次「更新时间技法」调用完整后端接口（不拆 endpoint），Swift 层面只保留新的 timing 数据
- `classicalResult` 整体替换，但 natal 部分不变所以用户无感
- 不修改 `ClassicalResultModels.swift`
- 不修改侧边栏布局

### 12.6 导出弹窗交互

```
📋 选择导出内容
┌──────────────────────────┐
│ ☑ 星体状态               │
│ ☑ 宫位                   │
│ ☑ 相位/接纳              │
│ ☐ 评分明细               │
│ ─── 时间技法 ───          │
│ ☑ 小限                   │
│ ☑ Firdaria               │
│ ☑ Decennials             │
│ ☑ ZR                     │
│ ☑ 返照盘                 │
│ ☑ 主限法                 │
│ ☐ 沿界推进               │
│ ☐ 时间线                 │
│ ─── 诊断 ───              │
│ ☑ 活跃概要               │
│ ☐ 警告                   │
├──────────────────────────┤
│          [导出 Markdown] │
└──────────────────────────┘
```

诊断组中的「活跃概要」聚合当前激活技法摘要、Ambiguity 与 calculation assumptions。

### 12.7 验收标准

1. 首次排盘行为与现版本完全一致
2. 更改参考时间后点击「更新时间技法」，时间技法数据更新
3. 本命数据（行星、宫位、相位等）在更新时间技法后不变
4. 点导出弹出 section 选择列表
5. 勾选后导出的 Markdown 只包含选中的 section
6. `swift build` 通过

### 12.8 验证步骤

1. 经典模式排盘 → 确认所有数据正常显示
2. 改参考时间 → 点击「更新时间技法」 → 确认时间技法更新
3. 对比行星状态 Tab，确认本命数据未变
4. 点击导出 → 取消勾选某些 section → 确认生成的 Markdown 不含对应内容
5. `swift build`
