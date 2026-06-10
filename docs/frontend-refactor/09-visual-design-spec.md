# 模块 09：视觉设计规范

> 本文档定义 TransitStudio 前端所有 View 的视觉模板。
> 便宜 Agent 写新 View 时**必须套用对应模板**，不要自己发明布局。
> Opus 最终审查时会以本规范为基准评判。

---

## 设计原则

1. **macOS 原生优先** — 用系统控件（Table, Picker, GroupBox），不造轮子
2. **信息层级清晰** — 每个 View 只有 3 层文字：标题 / 正文 / 辅助
3. **留白大于装饰** — 用间距而非边框/阴影制造层次
4. **数值用等宽** — 所有度数、日期、分数用 `.monospacedDigit()`
5. **空状态有交代** — 任何可能为空的区域用 `EmptyStateView`
6. **可选中** — 所有用户可能想复制的文字加 `.textSelection(.enabled)`

---

## Typography 层级

| 语义角色 | Token | 用在哪 |
|----------|-------|--------|
| 页面标题 | `TS.Font.pageTitle` (.title3.semibold) | 每个 tab 内容区最顶部，最多 1 个 |
| 区块标题 | `TS.Font.sectionTitle` (.callout.semibold) | GroupBox 替代标题、卡片分组标题 |
| 正文 | `TS.Font.body` (.callout) | 主要数据文字 |
| 标签 | `TS.Font.label` (.caption) | 表头、字段名、辅助说明 |
| 细节 | `TS.Font.detail` (.caption2) | 次要信息、副标题 |
| 等宽 | `TS.Font.mono` (.callout monospaced) | 度数、日期、经纬度 |
| 等宽小 | `TS.Font.monoSmall` (.caption monospaced) | 表格内数值 |

**规则**：一个 View 的 body 中最多出现 3 种字体层级。如果你发现自己用了 4 种以上，说明信息层级有问题。

---

## 间距规则

| 场景 | Token | 值 |
|------|-------|----|
| 同一组内元素间距 | `TS.Spacing.sm` | 4pt |
| 行内元素间距 | `TS.Spacing.md` | 8pt |
| 区块内行间距 | `TS.Spacing.lg` | 12pt |
| 区块与区块之间 | `TS.Spacing.xl` | 16pt |
| 页面内容 padding | `TS.Padding.resultContent` | 14pt |
| 侧边栏内容 padding | `TS.Padding.sidebarContent` | 18pt |
| 卡片内 padding | `TS.Padding.cardInner` | 8pt |

---

## 颜色用法

| 用途 | 颜色 | 说明 |
|------|------|------|
| 标签/辅助文字 | `.foregroundStyle(.secondary)` | 最常用，所有非主要文字 |
| 第三级文字 | `.foregroundStyle(.tertiary)` | 极少用，仅副标题 |
| 强调当前项 | `TS.SemanticColor.accent` | 选中 tab、当前 Dasa 行星名 |
| 强调背景 | `TS.SemanticColor.accentSubtle` | 选中行背景 (.opacity(0.14)) |
| 卡片背景 | `TS.SemanticColor.cardBackground` | InfoCard、chip 底色 |
| 警告 | `TS.SemanticColor.warning` | birthdayTransition 卡片 |
| 错误 | `TS.SemanticColor.error` | SectionErrorList |
| 行星色 | 按 lord 名查表 | Sun=orange, Moon=gray, Mars=red, Mercury=green, Jupiter=yellow, Venus=pink, Saturn=blue, Rahu=purple, Ketu=indigo |

---

## 7 个组件模板

每个新 View 必须从以下模板中选一个作为骨架。

### 模板 A：统计卡片网格（InfoCard Grid）

**适用于**：Overview 页面顶部的摘要统计

```swift
// 已有组件 InfoCard（VedicResultViews.swift:75），直接复用
// 容器用 LazyVGrid adaptive 布局

LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: TS.Spacing.lg) {
    InfoCard(title: "标签", value: "主值", subtitle: "副标题")
    InfoCard(title: "标签", value: "主值", subtitle: "副标题")
    // ...
}
.padding(TS.Padding.resultContent)
```

**规范**：
- InfoCard 最小宽度 160pt，自动换行
- 网格间距用 `TS.Spacing.lg` (12pt)
- 一个 Overview 页面最多放 2 行 InfoCard（6-8 个）

### 模板 B：数据表格（Data Table）

**适用于**：行星位置、相位列表、宫位表等结构化列表

```swift
VStack(alignment: .leading, spacing: TS.Spacing.lg) {
    Text("表格标题")
        .font(TS.Font.sectionTitle)

    if items.isEmpty {
        EmptyStateView(title: "无数据", systemImage: "circle.dashed")
    } else {
        Table(items) {
            TableColumn("列名") { Text($0.field) }
            TableColumn("数值") { Text($0.value).monospacedDigit() }
            // 数值列一律 .monospacedDigit()
        }
    }
}
```

**规范**：
- 用 SwiftUI `Table`，不要用 `ForEach + HStack` 模拟表格
- 数值列 `.monospacedDigit()`
- 度数格式：`String(format: "%.2f°", value)` 或 `String(format: "%.4f°", value)`
- 空状态必须用 `EmptyStateView`

### 模板 C：键值详情区（Key-Value Section）

**适用于**：元数据、诊断信息、配置展示

```swift
VStack(alignment: .leading, spacing: TS.Spacing.xl) {
    Text("区块标题")
        .font(TS.Font.sectionTitle)

    Grid(alignment: .leading, horizontalSpacing: TS.Spacing.lg, verticalSpacing: TS.Spacing.md) {
        GridRow {
            Text("标签").foregroundStyle(.secondary).font(TS.Font.label)
            Text("值").font(TS.Font.body).textSelection(.enabled)
        }
        GridRow {
            Text("日期").foregroundStyle(.secondary).font(TS.Font.label)
            Text("2026-01-01 12:00").font(TS.Font.mono).textSelection(.enabled)
        }
        // ...
    }
}
```

**规范**：
- 用 `Grid` + `GridRow`，不要用 `HStack` 手动对齐
- 左列是标签（`.secondary` + `TS.Font.label`），右列是值
- 日期/数值用 `TS.Font.mono`
- 右列文字加 `.textSelection(.enabled)`

### 模板 D：时间轴行（Timeline Row）

**适用于**：Dasa 周期、Firdaria、事件列表

```swift
struct TimelineItemRow: View {
    let label: String
    let detail: String
    let startDate: String
    let endDate: String
    let color: Color
    let isCurrent: Bool

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 32)

            VStack(alignment: .leading, spacing: TS.Spacing.xs) {
                Text(label)
                    .font(TS.Font.body)
                    .fontWeight(isCurrent ? .bold : .regular)
                    .foregroundStyle(isCurrent ? TS.SemanticColor.accent : .primary)
                Text(detail)
                    .font(TS.Font.detail)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, TS.Spacing.md)

            Spacer()

            Text(startDate)
                .font(TS.Font.monoSmall)
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(TS.Font.detail)
                .foregroundStyle(.tertiary)
            Text(endDate)
                .font(TS.Font.monoSmall)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, TS.Spacing.sm)
        .padding(.horizontal, TS.Spacing.md)
        .background(isCurrent ? TS.SemanticColor.accentSubtle : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: TS.Radius.chip))
    }
}

// 容器：
LazyVStack(spacing: 0) {
    ForEach(periods) { period in
        TimelineItemRow(...)
        Divider().padding(.leading, TS.Spacing.xl)
    }
}
```

**规范**：
- 左侧 4pt 宽色带标识类别
- 当前项用 accent 背景高亮
- 日期范围右对齐，等宽小字
- 行间用 Divider 分隔，缩进对齐

### 模板 E：混合内容页（Overview Page）

**适用于**：Horary 总览、Vedic 总览、Panchanga

```swift
ScrollView {
    VStack(alignment: .leading, spacing: TS.Spacing.xl) {
        // 1. 可选：顶部 InfoCard 网格
        LazyVGrid(...) { ... }

        // 2. 多个内容区块，每个用标题 + 内容
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text("区块标题").font(TS.Font.sectionTitle)
            // 区块内容：Grid / Table / ForEach
        }

        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            Text("区块标题").font(TS.Font.sectionTitle)
            // ...
        }

        // 3. 可选：底部警告/诊断
        if !warnings.isEmpty {
            WarningList(warnings: warnings)
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(TS.Padding.resultContent)
}
```

**规范**：
- 最外层 `ScrollView`
- 区块间距 `TS.Spacing.xl` (16pt)
- 区块内行间距 `TS.Spacing.md` (8pt)
- 不要用 `GroupBox` 包裹每个区块（Opus 审查时会决定哪些需要 GroupBox）
- 标题用 `TS.Font.sectionTitle`，不是 `.headline`

### 模板 F：分段切换内容（Segmented Content）

**适用于**：Dasa 系统切换、关系类型切换、分割图选择

```swift
VStack(alignment: .leading, spacing: TS.Spacing.md) {
    Picker("选择", selection: $selected) {
        Text("选项 A").tag("a")
        Text("选项 B").tag("b")
    }
    .pickerStyle(.segmented)

    switch selected {
    case "a":
        ViewA(data: dataA)
    case "b":
        ViewB(data: dataB)
    default:
        EmptyView()
    }
}
```

**规范**：
- 选项 ≤ 5 个用 `.segmented`
- 选项 > 5 个用 `.menu` 或单独的 Picker
- 切换内容必须有 default case

### 模板 G：数值矩阵（Number Matrix）

**适用于**：Ashtakavarga bindu 矩阵

```swift
VStack(alignment: .leading, spacing: TS.Spacing.md) {
    Text("矩阵标题").font(TS.Font.sectionTitle)

    Grid(alignment: .center, horizontalSpacing: TS.Spacing.sm, verticalSpacing: TS.Spacing.sm) {
        // 表头行
        GridRow {
            Text("").frame(width: 60) // 左上空白
            ForEach(1...12, id: \.self) { house in
                Text("\(house)")
                    .font(TS.Font.label)
                    .foregroundStyle(.secondary)
                    .frame(width: 36)
            }
            Text("总").font(TS.Font.label).foregroundStyle(.secondary).frame(width: 36)
        }

        Divider()

        // 数据行
        ForEach(rows, id: \.id) { row in
            GridRow {
                Text(row.label)
                    .font(TS.Font.body)
                    .frame(width: 60, alignment: .leading)
                ForEach(row.values, id: \.self) { val in
                    Text("\(val)")
                        .font(TS.Font.mono)
                        .frame(width: 36)
                        .background(val >= threshold ? TS.SemanticColor.accentSubtle : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                Text("\(row.total)")
                    .font(TS.Font.mono)
                    .fontWeight(.semibold)
                    .frame(width: 36)
            }
        }
    }
}
```

**规范**：
- 用 `Grid` 不用 `Table`（Table 不适合纯数值矩阵）
- 单元格固定宽度 36pt
- 高亮值用 accent 背景
- 总计列加粗

---

## 模板选择指南

| 新 View | 用哪个模板 |
|---------|-----------|
| VedicPanchangaView | E (混合内容) + C (键值区块) |
| VedicDivisionalChartView | F (分段切换) + B (数据表格) |
| VedicJaiminiView (karakas) | C (键值详情) |
| VedicJaiminiView (arudha) | B (数据表格) |
| VedicAshtakavargaView | G (数值矩阵) |
| VedicRelationshipsView | F (分段切换) + B (数据表格) |
| VedicUpagrahaView | B (数据表格) |
| VedicSpecialLagnaView | B (数据表格) |
| VedicDerivedChartView | B (数据表格) |
| VedicYoginiDasaView | D (时间轴) |
| VedicAshtottariDasaView | D (时间轴) |
| BirthdayTransition 卡片 | C (键值详情) + 警告色背景 |
| ActivatedLordFocus 卡片 | C (键值详情) + accent 标签 |
| VedicDasaContainerView | F (分段切换) |

---

## Tier 2 Review 检查清单

对每个新/改 View，逐条检查：

### 编译 & 数据
- [ ] `swift build` 通过，无警告
- [ ] 所有字段名与 Model 一致（grep 确认）
- [ ] Optional 字段用 `if let` guard
- [ ] 空状态用 `EmptyStateView`

### 视觉规范合规
- [ ] 使用了正确的模板（对照模板选择指南）
- [ ] Typography 只用 TS.Font.xxx，没有裸 .font(.caption)
- [ ] 间距只用 TS.Spacing/Padding.xxx，没有裸数字
- [ ] 数值列用 .monospacedDigit()
- [ ] 颜色用 TS.SemanticColor.xxx 或 .foregroundStyle(.secondary)
- [ ] 圆角用 TS.Radius.xxx

### 无回归
- [ ] 现有 tab 仍正常显示
- [ ] 现有导出功能不受影响
- [ ] AI 分析功能不受影响
