# Agent 交接提示词

> 以下是按模块拆分的提示词模板。每次只给 agent **一个模块**的提示词。
> 把 `{{MODULE_NUMBER}}` 替换为实际模块号（01-08）。

---

## 通用前缀（每次都要带）

```
你即将对一个 macOS SwiftUI 占星应用 TransitStudio 进行前端重构。

在开始任何工作前，请**严格按顺序**阅读以下文件并确认你理解了每个文件的要求：

1. /Users/gacu/Documents/Codex/AstroTransitMac/AGENTS.md
2. /Users/gacu/Documents/Codex/AstroTransitMac/VIBE_WORKFLOW.md
3. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/00-overview.md
4. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/{{MODULE_NUMBER}}-xxx.md

读完后先告诉我你理解了什么、打算怎么做、分几步。不要直接开始写代码。
```

---

## 模块 01：Design Tokens

```
你的任务是执行模块 01：创建 DesignTokens.swift。

在开始任何工作前，请严格按顺序阅读以下文件并确认你理解了每个文件的要求：

1. /Users/gacu/Documents/Codex/AstroTransitMac/AGENTS.md
2. /Users/gacu/Documents/Codex/AstroTransitMac/VIBE_WORKFLOW.md
3. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/00-overview.md
4. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/01-design-tokens.md

这是一个纯新增文件的任务，不修改任何现有代码。文档中有完整的代码规范，照着写就行。

完成后执行 `swift build` 确认编译通过，然后更新 CHANGELOG.md。

读完后先告诉我你理解了什么、打算怎么做。不要直接开始写代码。
```

## 模块 02：CollapsibleSection

```
你的任务是执行模块 02：重写 CollapsibleSection.swift，去掉 GroupBox 包装。

前置条件：模块 01（DesignTokens.swift）必须已完成。先确认文件存在：
ls Sources/TransitStudio/DesignTokens.swift

在开始任何工作前，请严格按顺序阅读以下文件：

1. /Users/gacu/Documents/Codex/AstroTransitMac/AGENTS.md
2. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/00-overview.md
3. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/02-collapsible-section.md
4. Sources/TransitStudio/CollapsibleSection.swift（当前代码）

这只改一个文件，38 行改为差不多同样行数。API 签名不变，所有调用者不需要改。

完成后执行 `swift build`，然后更新 CHANGELOG.md。

读完后先告诉我你理解了什么、打算怎么做。不要直接开始写代码。
```

## 模块 03：Tab Bar

```
你的任务是执行模块 03：将 Tab 系统从二维网格改为单行水平滚动。

前置条件：模块 01（DesignTokens.swift）必须已完成。

在开始任何工作前，请严格按顺序阅读以下文件：

1. /Users/gacu/Documents/Codex/AstroTransitMac/AGENTS.md
2. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/00-overview.md
3. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/03-tab-bar.md
4. Sources/TransitStudio/ResultToolbarViews.swift（当前代码）

关键策略：文档要求你先写一个兼容性过渡 init（接受旧 tabRows 二维数组，内部 flatMap），这样 `swift build` 立刻通过。然后逐个迁移 12 个调用者。每迁移 2-3 个就 build 一次。

这是中等风险的任务——涉及 12 个调用点，分布在两个文件中。不要一次性改完，分批来。

完成后执行 `swift build`，然后更新 CHANGELOG.md。

读完后先告诉我你理解了什么、打算分几步做。不要直接开始写代码。
```

## 模块 04：Export Controls

```
你的任务是执行模块 04：清理导出控件死代码。

前置条件：模块 01 和 03 已完成。

在开始任何工作前，请阅读：

1. /Users/gacu/Documents/Codex/AstroTransitMac/AGENTS.md
2. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/04-export-controls.md

这是最简单的模块。先 grep 确认 ExportControls 无调用者，然后删除文件，swift build 确认通过。

完成后更新 CHANGELOG.md。

读完后告诉我你确认了什么，然后执行。
```

## 模块 05：ViewModel 提取（⚠️ 高风险）

```
你的任务是执行模块 05：从 ContentView 提取 ViewModel。这是整个重构中风险最高的模块。

前置条件：模块 01 已完成。

在开始任何工作前，请严格按顺序阅读以下文件：

1. /Users/gacu/Documents/Codex/AstroTransitMac/AGENTS.md
2. /Users/gacu/Documents/Codex/AstroTransitMac/VIBE_WORKFLOW.md（特别注意"ContentView 极度脆弱"的警告）
3. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/00-overview.md
4. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/05-viewmodel-extraction.md
5. Sources/TransitStudio/ContentView.swift（125 个属性的完整列表）

⚠️ 铁律：
- 每移动 5-7 个属性就 swift build 一次
- 如果 build 失败，立刻回退最近一批，不要试图修复
- 分三个 Phase 做，每个 Phase 结束后完整验证
- Phase 1（AppState）完成后先停下来让我确认，再继续 Phase 2

先只做 Phase 1：提取 @AppStorage 属性到 AppState.swift。

读完后告诉我你理解了什么、Phase 1 打算分几个批次。不要直接开始写代码。
```

## 模块 06：吠陀 View 补全

```
你的任务是执行模块 06：为吠陀模式补全缺失的数据展示 View。

前置条件：模块 01 和 03 已完成。

在开始任何工作前，请严格按顺序阅读以下文件：

1. /Users/gacu/Documents/Codex/AstroTransitMac/AGENTS.md
2. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/00-overview.md
3. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/06-vedic-data-views.md
4. Sources/TransitStudio/VedicResultModels.swift（所有 Model 定义——这是你的 source of truth）
5. Sources/TransitStudio/VedicResultViews.swift（现有 View 的 pattern 参考）
6. Sources/TransitStudio/ContentView+ResultsPanes.swift（line 905-970 附近的吠陀区域）

⚠️ 关键：文档中的示例代码使用了推测的字段名。你必须先读 VedicResultModels.swift 确认每个 Model 的实际字段名，以实际代码为准，不要照抄文档中可能不准确的字段名。

建议执行顺序：
1. 先改 ContentView+ResultsPanes.swift 的 tab 定义 + tabTitle 映射（加 empty case）
2. 逐个创建 View 文件：Panchanga → Jaimini → Ashtakavarga → Varga → Relationships → Misc
3. 每创建一个文件就 swift build 一次
4. 最后做 Daśā tab 增强（加 Yogini/Ashtottari 切换）

完成后更新 CHANGELOG.md。

读完后先告诉我 VedicResultModels.swift 里各个 Model 的实际字段名，以及你打算怎么做。不要直接开始写代码。
```

## 模块 07：古典隐藏字段

```
你的任务是执行模块 07：在古典模式的 timing tab 中补全两个隐藏字段的展示。

前置条件：模块 01 已完成。

在开始任何工作前，请阅读：

1. /Users/gacu/Documents/Codex/AstroTransitMac/AGENTS.md
2. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/07-classical-data-views.md
3. Sources/TransitStudio/ClassicalResultModels.swift（确认 BirthdayTransition 和 ActivatedLordFocus 的字段）
4. Sources/TransitStudio/ClassicalResultViews.swift（找到 ClassicalTimingView 的位置）

这是一个小模块——在现有 View 中插入两个卡片组件。不新建文件。

先用 sample-classical-request.json 跑一次后端，确认这两个字段是否有数据返回：
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json | python3 -c "import json,sys; d=json.load(sys.stdin); print('birthday:', d.get('birthday_transition')); print('lord:', d.get('activated_lord_focus'))"

完成后执行 swift build，更新 CHANGELOG.md。

读完后告诉我字段确认结果和你的计划。
```

## 模块 08：AI 分析视图

```
你的任务是执行模块 08：整理 AIAnalysisView 的控件布局。

前置条件：模块 01 已完成。如果模块 05 Phase 1 也完成了，可以同时迁移 @AppStorage。

在开始任何工作前，请阅读：

1. /Users/gacu/Documents/Codex/AstroTransitMac/AGENTS.md
2. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/08-ai-analysis-cleanup.md
3. Sources/TransitStudio/AIAnalysisView.swift（当前完整代码）

核心改动：把模型选择器、提示词选择器、备注输入框从标题行移到 DisclosureGroup 里，默认折叠。标题行只保留"AI 分析" + 复制按钮 + 生成按钮。

不要修改 MarkdownBlocksView 和流式传输逻辑。

完成后执行 swift build，更新 CHANGELOG.md。

读完后告诉我你的计划。
```

---

## 使用说明

1. **一次只给一个模块**——不要把多个模块的提示词合并
2. **按依赖顺序执行**——01 最先，然后 02/03/05-P1 可并行，等等
3. **每个模块结束后让 agent 跑验证**——`swift build` 必须通过
4. **如果 agent 说"我来重构一下 ContentView"却没读设计文档**——立刻打断，让它重新读
5. **模块 05 特别注意**——每个 Phase 完成后暂停确认，不要让 agent 一口气做完三个 Phase

---

## 三层工作流

```
Tier 1（便宜 Agent）→ 按模块文档 + 视觉规范写代码
Tier 2（中等 Agent）→ Review 正确性 + 规范合规
Tier 3（Opus）     → 最终设计审查，可否决/重写任何布局决定
```

---

## Tier 2 Review 提示词

```
你是 TransitStudio 前端重构的 code reviewer。请按以下步骤审查刚完成的模块：

1. 先读这些文件：
   - /Users/gacu/Documents/Codex/AstroTransitMac/AGENTS.md
   - /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/09-visual-design-spec.md
   - 被审查模块的设计文档

2. 运行 `swift build`，确认通过且无警告

3. 对每个新建/修改的 .swift 文件：
   - 读完整代码
   - 对照视觉规范的"Review 检查清单"逐条检查
   - 确认字段名与 VedicResultModels.swift / ClassicalResultModels.swift 一致
   - 确认 Optional 处理正确

4. 运行 smoke tests：
   python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json > /dev/null && echo "OK"
   python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-request.json > /dev/null && echo "OK"

5. 输出审查报告：
   - ✅ 通过项
   - ❌ 不通过项（附具体文件:行号 + 修复建议）
   - ⚠️ 建议项（不阻塞但建议改进）

不要自己修复问题——只报告，让 Tier 1 agent 修复。
```

---

## Tier 3 Opus 触发时机

当以下条件**全部满足**时，叫 Opus 做最终设计审查：

1. 所有 8 个模块 Tier 1 已完成
2. 所有模块 Tier 2 review 通过（无 ❌ 项）
3. `swift build` + `swift test` 全绿

## Tier 3 Opus 提示词

```
你是 TransitStudio 前端重构的最终设计审查者。你有完整的否决和重写权。

请阅读：
1. /Users/gacu/Documents/Codex/AstroTransitMac/docs/frontend-refactor/09-visual-design-spec.md
2. git diff main...HEAD（查看所有改动）

然后：
1. 打开 app（swift build -c release && open dist/...），逐模式检查视觉效果
2. 对每个新/改 View，评估：
   - 信息层级是否清晰？标题/正文/辅助文字区分明显吗？
   - 间距是否舒适？有没有拥挤或空旷的地方？
   - 表格列宽是否合理？
   - 卡片/区块的分组是否符合业务逻辑？
   - 空状态是否友好？
3. 直接修改不满意的 View——你可以：
   - 重写布局（VStack→Grid, HStack→LazyVGrid）
   - 调整间距、字体、颜色
   - 改变信息展示顺序
   - 添加/删除 GroupBox 包裹
4. 每次修改后 swift build 确认通过
5. 完成后更新 CHANGELOG.md
```
