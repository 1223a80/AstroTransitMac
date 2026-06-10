# 模块 08：AI 分析视图整理

> **依赖**：01 (Design Tokens), 05-Phase2（ViewModel 提取完成后效果最好，但不是硬依赖）  
> **风险**：低  
> **修改文件**：`Sources/TransitStudio/AIAnalysisView.swift`

## 目标

将 AI 分析视图顶部的设置控件（模型选择器、提示词选择器、备注输入框）折叠到 DisclosureGroup 里，释放内容空间。

## 当前问题

```
┌─────────────────────────────────────────────────┐
│ AI 分析        [模型选择器 170px] [复制] [生成]    │  ← 行 1：标题 + 控件
│ [提示词选择器 180px] [备注输入框.....长长长长长]     │  ← 行 2：更多控件
│                                                 │
│ 💭 思考过程 (折叠)                                │
│                                                 │
│ (分析正文区域被挤压)                               │
└─────────────────────────────────────────────────┘
```

模型选择器和提示词设置占了两行宝贵的顶部空间，用户设置好后极少再改。

## 修改后布局

```
┌─────────────────────────────────────────────────┐
│ AI 分析                          [复制] [生成]    │  ← 干净的标题行
│ ▸ AI 设置                                       │  ← 折叠的设置区域
│                                                 │
│ 💭 思考过程 (折叠)                                │
│                                                 │
│ (分析正文区域变大)                                 │
└─────────────────────────────────────────────────┘
```

展开时：
```
│ ▾ AI 设置                                       │
│   模型：[选择器]   提示词：[选择器]                  │
│   备注：[输入框............................]       │
│   推理力度：[选择器]                               │
```

## 具体修改

在 `AIAnalysisView.swift` 的 `body` 中：

### 修改前（当前代码约 line 64-92）

```swift
var body: some View {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Text("AI 分析").font(.headline)
            Spacer()
            Picker("模型", selection: $llmModel) { ... }
                .labelsHidden()
                .frame(width: 170)
            CopyMarkdownButton(markdown: analysis)
            Button { analyze() } label: { ... }
        }

        HStack(alignment: .top, spacing: 12) {
            Picker("提示词", selection: $aiPromptStyle) { ... }
                .frame(width: 180)
            TextField("备注...", text: $aiNote)
                .textFieldStyle(.roundedBorder)
        }

        // reasoning section ...
        // analysis content ...
    }
}
```

### 修改后

```swift
@State private var settingsExpanded = false

var body: some View {
    VStack(alignment: .leading, spacing: TS.Spacing.lg) {
        // 标题行：只保留标题 + 核心动作按钮
        HStack {
            Text("AI 分析").font(TS.Font.sectionTitle)
            Spacer()
            CopyMarkdownButton(markdown: analysis)
            Button {
                analyze()
            } label: {
                Label(actionButtonLabel, systemImage: actionButtonIcon)
            }
            .disabled(isAnalyzing || !canAnalyze)
        }

        // 设置折叠区
        DisclosureGroup("AI 设置", isExpanded: $settingsExpanded) {
            VStack(alignment: .leading, spacing: TS.Spacing.md) {
                HStack(spacing: TS.Spacing.lg) {
                    LabeledContent("模型") {
                        Picker("", selection: $llmModel) {
                            ForEach(savedModelList, id: \.self) { model in
                                Text(model).tag(model)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 170)
                    }

                    LabeledContent("提示词") {
                        Picker("", selection: $aiPromptStyle) {
                            Text("通用").tag("general")
                            Text("本命盘").tag("natal")
                            Text("行运").tag("transit")
                            Text("窗口扫描").tag("scan")
                            Text("古典").tag("classical")
                            Text("Horary").tag("horary")
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }
                }

                TextField("备注会随排盘数据一起发送给 API", text: $aiNote)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.top, TS.Spacing.sm)
        }
        .font(TS.Font.label)

        // 思考过程（保持不变）
        if !reasoning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // ... 现有 reasoning section 不变，只替换硬编码间距为 TS token
        }

        // 主内容区（保持不变）
        if analysis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyStateView(...)
        } else {
            ScrollView {
                MarkdownBlocksView(markdown: normalizedMarkdown)
            }
        }
    }
}
```

## 关键改动总结

| 改动 | 说明 |
|------|------|
| 模型选择器移入 DisclosureGroup | 不再占据标题行空间 |
| 提示词选择器移入 DisclosureGroup | 同上 |
| 备注输入框移入 DisclosureGroup | 同上 |
| 标题行简化为 `标题 + 复制 + 生成` | 干净整洁 |
| 采用 TS token | 替换 spacing: 12 等硬编码值 |
| `@State private var settingsExpanded = false` | 默认折叠，不干扰阅读 |

## 关于 @AppStorage 属性

`AIAnalysisView` 内部声明了 6 个 `@AppStorage`：

```swift
@AppStorage("llmModel") private var llmModel = "glm-4.7-flash"
@AppStorage("savedLLMModels") private var savedLLMModels = "glm-4.7-flash"
@AppStorage("aiPromptStyle") private var aiPromptStyle = "general"
@AppStorage("aiNote") private var aiNote = ""
@AppStorage("aiReasoningEffort") private var aiReasoningEffort = "max"
```

**如果模块 05 Phase 1 已完成**：这些应该从 `AppState` 通过 `@Environment` 获取。将上面的 `@AppStorage` 替换为从 environment 读取。

**如果模块 05 尚未完成**：保持 `@AppStorage` 不变——它们和 `AppState` 读同一个 UserDefaults key，不会冲突。

## 验证

```bash
swift build
# 打开 app，对任意模式点击 AI 分析 tab
# 确认：
# 1. 默认只看到标题行 + "AI 设置" 折叠条
# 2. 展开设置后能选模型/提示词/填备注
# 3. 生成分析功能正常（流式输出 + 思考过程）
```

## 不要做的事

- ❌ 不要修改 `MarkdownBlocksView`——它的 Markdown 渲染逻辑独立且正常工作
- ❌ 不要修改流式传输逻辑——`streamingPhase` 和 `actionButtonLabel/Icon` 保持不变
- ❌ 不要移除推理力度（aiReasoningEffort）设置——它影响 API 调用参数
