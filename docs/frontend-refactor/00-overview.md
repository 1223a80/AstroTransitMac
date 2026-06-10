# TransitStudio 前端重构 — 总览

> **本文档是所有模块文档的主索引。执行任何模块前必须先读本文件和项目根目录的 `AGENTS.md`。**

## 项目背景

TransitStudio 是一个 macOS SwiftUI 占星桌面应用，Python 后端通过 stdin/stdout JSON 与前端交互。所有代码由 AI agent 生成，项目维护者不写代码——你（agent）是唯一的开发者。

### 当前痛点

| 类别 | 问题 | 严重度 |
|------|------|--------|
| 视觉 | 无设计 token，字体/间距/颜色散乱，GroupBox 嵌套压迫 | 🔴 |
| 数据 | 吠陀后端返回 15 种数据，前端只展示 5 种 | 🔴 |
| 数据 | 古典 `birthdayTransition`、`activatedLordFocus` 已解码但无 UI | 🟡 |
| 架构 | ContentView 持有 125 个属性（104 @State + 21 @AppStorage） | 🔴 |
| 组件 | Tab 系统用二维数组渲染两行按钮，违反 macOS 规范 | 🟡 |
| 组件 | ExportControls.swift 是死代码（零调用者） | 🟢 |

## 模块清单

| # | 文档 | 改什么 | 风险 | 复杂度 |
|---|------|--------|------|--------|
| 01 | [design-tokens.md](01-design-tokens.md) | 新建 `DesignTokens.swift` | 低 | 中 |
| 02 | [collapsible-section.md](02-collapsible-section.md) | 重写 `CollapsibleSection.swift` | 低 | 低 |
| 03 | [tab-bar.md](03-tab-bar.md) | 重写 `ResultToolbarViews.swift` + 所有调用者 | 中 | 中 |
| 04 | [export-controls.md](04-export-controls.md) | 删除死代码，整理导出按钮 | 低 | 低 |
| 05 | [viewmodel-extraction.md](05-viewmodel-extraction.md) | 从 ContentView 提取 3 个 ViewModel | 高 | 高 |
| 06 | [vedic-data-views.md](06-vedic-data-views.md) | 新建 6 个吠陀 View 文件 | 低 | 中高 |
| 07 | [classical-data-views.md](07-classical-data-views.md) | 新建 2 个古典 View，嵌入 timing tab | 低 | 低 |
| 08 | [ai-analysis-cleanup.md](08-ai-analysis-cleanup.md) | 重构 `AIAnalysisView.swift` | 低 | 低 |
| 09 | [visual-design-spec.md](09-visual-design-spec.md) | 视觉设计规范 + 7 个组件模板（参考文档，不直接执行） | — | — |

## 依赖图与执行顺序

```
Phase A ─── 01 Design Tokens ──────────────────────────────────
                  │
Phase B ─── 02 CollapsibleSection ──┐
            03 Tab Bar ─────────────┤  (可并行)
            05-Phase1 AppState ─────┘
                  │
Phase C ─── 04 Export Controls ─────┐
            06 Vedic Views ─────────┤  (可并行，需 03 完成)
            07 Classical Views ─────┘
                  │
Phase D ─── 05-Phase2 CalculationVM ─── 05-Phase3 AIVM ────────
                  │
Phase E ─── 08 AI Analysis Cleanup ────────────────────────────
```

**并行提示**：Phase B 的 02/03/05-Phase1 可以同时分给三个 agent。Phase C 的 04/06/07 也可以三个 agent 并行。

## 必须遵守的公约

### 来自 AGENTS.md

1. **以复用现有为荣** — 不要创建平行结构。如果已有 `InfoCard`、`TabChip`、`ExportMenu`，直接复用。
2. **以认真查询为荣** — 修改任何文件前先 `grep` 确认调用者和依赖。
3. **改了必须更新 CHANGELOG.md** — 追加到最上面。
4. **更新 PLANS.md** — 记录当前进度。

### 来自 VIBE_WORKFLOW.md

1. **ContentView 极度脆弱** — 任何修改必须是小步增量，每步 `swift build` 通过。
2. **验证清单** — 每个模块完成后执行：
   ```bash
   swift build
   swift test
   python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json > /dev/null && echo "classical OK"
   python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-request.json > /dev/null && echo "moment OK"
   ```
3. **不要一次性大改** — 每个模块内部也要分多次 commit，每次 commit 必须能 build。

### 视觉风格方向

- **轻度定制**：在 macOS 原生控件基础上加少量品牌色、卡片圆角、微妙阴影
- 不偏离 macOS HIG，不做 Web-style 自定义控件
- 保持 `Color.accentColor` 作为主色调
- 四元素色系（火/土/风/水）保留但统一到 token 体系

### 文件组织

- 源码路径：`Sources/TransitStudio/`
- 后端路径：`Sources/TransitStudio/Resources/backend/`
- 测试：`SwiftTests/`（Swift）、`python_tests/`（Python）
- **不要编辑** `dist/`、`.build/`、`__pycache__/`、`backups/`
