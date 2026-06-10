# 模块 03：Tab 系统重构

> **依赖**：01 (Design Tokens)  
> **风险**：中（涉及所有结果面板的 tab 渲染）  
> **修改文件**：  
> - `Sources/TransitStudio/ResultToolbarViews.swift` — 核心组件  
> - `Sources/TransitStudio/ContentView+ResultsPanes.swift` — 6 个结果面板的 tab 定义  
> - `Sources/TransitStudio/ModernResultViews.swift` — 5 个现代盘面板的 tab 定义  

## 目标

将 tab 从二维网格 `tabRows: [[(id, title)]]` 改为单行水平滚动 `tabs: [(id, title)]`，符合 macOS 标准。

## 当前问题

```swift
// 当前：二维数组渲染两行 tab 按钮
tabRows: [
    [("wheel", "星盘图"), ("planets", "行星状态"), ("points", "点位/Lots"), ("houses", "宫位"), ("aspects", "相位/接纳"), ("judgement", "评分明细")],
    [("timing", "时间技法"), ("ai", "AI 分析")]
]
```

这在 macOS 上没有对应的标准 pattern，用户会困惑为什么有两排按钮。

## 修改方案

### 1. 重写 ResultPaneToolbar

```swift
// ResultToolbarViews.swift — 修改后

struct TabChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TS.Font.label)
                .padding(.horizontal, TS.Padding.chipHorizontal)
                .padding(.vertical, TS.Padding.chipVertical)
                .background(isSelected ? TS.SemanticColor.chipSelectedBackground : TS.SemanticColor.chipBackground)
                .foregroundStyle(isSelected ? TS.SemanticColor.chipSelectedForeground : .primary)
                .clipShape(RoundedRectangle(cornerRadius: TS.Radius.chip))
        }
        .buttonStyle(.plain)
    }
}

struct ResultPaneToolbar: View {
    @Binding var selection: String
    let tabs: [(id: String, title: String)]                // ← 改为一维
    let moreTabs: [(id: String, title: String)]
    let currentTabTitle: String
    let markdownProvider: () -> String
    let jsonProvider: () -> String
    let csvProvider: () -> String
    var basename = "astro_export"
    var classicalSectionPicker: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: TS.Spacing.md) {
            // 单行可滚动 tab 栏
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TS.Spacing.sm) {
                    ForEach(tabs, id: \.id) { tab in
                        TabChip(
                            title: tab.title,
                            isSelected: selection == tab.id,
                            action: { selection = tab.id }
                        )
                    }

                    if !moreTabs.isEmpty {
                        moreMenu
                    }
                }
            }

            // 标题 + 导出行
            HStack {
                Text(currentTabTitle)
                    .font(TS.Font.sectionTitle)
                Spacer()
                if let classicalSectionPicker {
                    Button("导出 Markdown...") { classicalSectionPicker() }
                        .font(TS.Font.label)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                } else {
                    CopyMarkdownButton(title: "复制 Markdown", textProvider: markdownProvider)
                }
                ExportMenu(
                    markdownProvider: markdownProvider,
                    jsonProvider: jsonProvider,
                    csvProvider: csvProvider,
                    basename: basename
                )
            }
        }
    }

    private var moreMenu: some View {
        Menu {
            ForEach(moreTabs, id: \.id) { tab in
                Button(tab.title) { selection = tab.id }
            }
        } label: {
            Text("更多")
                .font(TS.Font.label)
                .padding(.horizontal, TS.Padding.chipHorizontal)
                .padding(.vertical, TS.Padding.chipVertical)
                .background(TS.SemanticColor.chipBackground)
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: TS.Radius.chip))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
```

### 2. 兼容性过渡 init

为了让 12 个调用者可以**逐个迁移**而不是一次性全改，提供一个过渡 init：

```swift
extension ResultPaneToolbar {
    /// 过渡 init：接受旧的二维 tabRows，内部 flatMap 为一维。
    /// 迁移完所有调用者后删除此 init。
    init(
        selection: Binding<String>,
        tabRows: [[(id: String, title: String)]],
        moreTabs: [(id: String, title: String)],
        currentTabTitle: String,
        markdownProvider: @escaping () -> String,
        jsonProvider: @escaping () -> String,
        csvProvider: @escaping () -> String,
        basename: String = "astro_export",
        classicalSectionPicker: (() -> Void)? = nil
    ) {
        self.init(
            selection: selection,
            tabs: tabRows.flatMap { $0 },
            moreTabs: moreTabs,
            currentTabTitle: currentTabTitle,
            markdownProvider: markdownProvider,
            jsonProvider: jsonProvider,
            csvProvider: csvProvider,
            basename: basename,
            classicalSectionPicker: classicalSectionPicker
        )
    }
}
```

### 3. 迁移调用者

有了过渡 init，`swift build` 立刻通过（现有 `tabRows:` 调用走过渡 init）。然后逐个迁移调用者：

**ContentView+ResultsPanes.swift 中的 6 处**：

| 面板 | 旧变量名 | 改为 |
|------|----------|------|
| 现代本命 | `modernNatalTabRows` | `modernNatalTabs`（flatMap） |
| 时间点 | `momentTabRows` | `momentTabs` |
| 窗口扫描 | `scanTabRows` | `scanTabs` |
| Horary | `horaryTabRows` | `horaryTabs` |
| 古典 | `classicalTabRows` | `classicalTabs` |
| 吠陀 | 内联 tabRows | 改为 `vedicTabs` 变量 |

**ModernResultViews.swift 中的 5 处**：

| 面板 | 位置 |
|------|------|
| SynastryResultPane | `tabRows` property |
| CompositeDavisonResultPane | `tabRows` property |
| ProgressionResultPane | `tabRows` property |
| SolarArcResultPane | `tabRows` property |
| HarmonicResultPane | `tabRows` property |

每改完一处，`swift build` 确认通过。全部迁移完后，删除过渡 init。

## 验证

```bash
swift build
```

打开 app，切换到各模式确认：
- Tab 是单行水平排列
- Tab 多时可以滚动
- "更多" 菜单仍正常弹出
