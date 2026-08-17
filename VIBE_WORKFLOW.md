# Vibe Coding 工作流指南



## 1. 每次新对话（新 session）必须强制让 agent 先读这些文件

顺序很重要：

1. `AGENTS.md` （最高纪律：以复用为荣、以验证为荣、改了必须更新 CHANGELOG）
2. `PLANS.md` （当前正在进行的规范化计划，永远不要重复已经完成的工作）
3. `VIBE_WORKFLOW.md` （本文件，你现在正在读）
4. `计算规则.md` （现代占星计算不能让 agent 自己发明）
5. `docs/backend-contracts.md` + `docs/validation.md`
6. `README.md`

**命令模板**（直接复制给 agent）：
```
在开始任何工作前，请先完整阅读以下文件并确认你理解了项目的 vibe coding 现实：
/Users/gacu/Documents/Codex/AstroTransitMac/AGENTS.md
/Users/gacu/Documents/Codex/AstroTransitMac/PLANS.md
/Users/gacu/Documents/Codex/AstroTransitMac/VIBE_WORKFLOW.md
/Users/gacu/Documents/Codex/AstroTransitMac/计算规则.md
/Users/gacu/Documents/Codex/AstroTransitMac/docs/backend-contracts.md
/Users/gacu/Documents/Codex/AstroTransitMac/docs/validation.md
```

如果 agent 没先读这些就直接改代码，**立刻打断它**，让它重新读。

---

## 2. 最重要的反模式（vibe coding 最容易犯的）

### A. “我的数据”污染（最严重）
- 不要让 agent 把 `31.2304, 121.4737, Asia/Shanghai, 1990-01-01 12:00, "我的本命盘"` 作为**默认值**或**示例数据**到处硬编码。
- 好的做法：UI 初始值可以有，但要容易被用户覆盖；测试和 Examples 里用**中性数据**或明确标注“这是作者的测试数据，可替换”。
- 每次重大改动后，让 agent 跑：
  ```bash
  grep -r "31.2304\|121.4737\|1990-01-01\|我的本命盘" --include="*.swift" --include="*.py" --include="*.json" Sources/ python_tests/ Examples/ | cat
  ```
  只允许在明确标注为“作者个人测试数据”的地方出现。

### B. 直接怼新功能进 ContentView.swift
这是 vibe coding 的天敌。ContentView 已经 80+ 个 @State，是典型的“越改越大”的 vibe 产物。

**规则**：
- 新增任何计算模式（哪怕只是“加个关系盘”），**第一步必须让 agent 提出最小侵入方案**，而不是直接开始写 ContentView+XXX.swift。
- 优先考虑：新 Tab / 新 Sheet / 独立的 XXXView.swift + 少量状态提升，而不是继续往主 View 里塞。
- 现代占星（synastry/composite 等）目前后端已完成，UI 尚未接入（见 PLANS.md 最新记录）。下次做这个时，必须先讨论 UI 架构。

### C. “先跑通再说”的后端先行
Agent 特别喜欢先把 Python 模块写得特别漂亮（因为 prompt 容易描述算法），然后说“Swift UI 后面再接”。

**规则**：
- 任何新特性，必须同时规划：
  - Python 计算
  - Swift 模型（Codable）
  - 至少一个 contract test
  - **UI 接入的最小方案**（哪怕只是先放一个占位按钮 + 打印结果）
- 不要接受“UI 后面再说”的交付，除非明确写进 PLANS.md 作为下一阶段任务。

### D. 硬编码作者机器路径和个人配置
已知雷区：
- `AsteroidEphemerisManager.swift` 里的 `/Users/gacu/资料库/ephe`
- `package_app.sh` 里的 `com.gacu.TransitStudio`、`1.0.0` 硬版本、`/private/tmp/...`
- Logger subsystem 里的 `com.gacu.TransitStudio`
- 所有 `@AppStorage` 默认值如果带个人坐标

**规则**：任何涉及“路径、bundle id、版本、默认经纬度”的改动，必须让 agent 先 grep 全项目，再提出中性方案。

---

## 3. 接受 agent 改动前的强制验证清单（复制粘贴用）

让 agent 每次改完后，**必须逐条执行并把结果贴出来**，我才考虑接受：

1. `python3 -m pytest python_tests/ -q` （全部通过）
2. `swift build` （成功）
3. `swift test` （如果环境允许）
4. 跑至少 3 个 smoke：
   - `python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json > /dev/null && echo "classical OK"`
   - 类似 scan、horary、rectify
5. `grep -r "31.2304\|/Users/gacu" --include="*.swift" --include="*.py" Sources/ python_tests/ Examples/ | cat` （只剩可接受的几个）
6. `git diff --stat` 让我看改了哪些文件
7. 如果改了模型或导出：让 agent 展示同一个输入的 Markdown 导出前后对比关键部分
8. 更新 `CHANGELOG.md`（最上面加一条）
9. 如果是新功能，更新 `PLANS.md` 当前进度

**我（用户）唯一要做的**：看清单结果是否全绿 + 改动范围是否合理，然后说“可以”或“不行，修 XXX”。

**更简单的方法**：直接在终端运行 `./check_vibe_changes.sh` （已经提前做好了可执行权限）。它会自动跑大部分检查，并给出总结。运行完把输出截图或复制给 agent，让它根据结果自查。

---

## 4. 推荐的 prompting 技巧（针对不懂代码的人）

- **永远先问架构，而不是直接说“帮我加 XXX 功能”**。
  坏 prompt: “帮我加上 synastry 功能”
  好 prompt: “目前项目已经有了 ModernBackendClient 和 ModernResultModels，请先分析如果要支持 synastry/composite 等关系盘，UI 层应该怎么最小侵入地接入，不要直接改 ContentView。给出 2-3 个方案并推荐一个。”

- **要求 agent 先输出计划，再执行**（我们已经在用 plan mode）。

- **要求 agent 用中文解释关键改动**，尤其是状态管理、数据流。

- **定期让 agent 做“去个人化审查”**：
  “请做一次全项目个人数据与作者痕迹审查，列出所有需要中性化的地方，并给出修改计划。”

- **备份策略**：
  重要 session 前，手动复制整个 `Sources/TransitStudio` 和 `Sources/TransitStudio/Resources/backend` 到 `backups/$(date +%Y%m%d-%H%M)`。

---

## 5. 当前项目最需要保护的脆弱点（2026-06 状态）

根据 PLANS.md 和最近审计：

1. **ContentView 已经极度脆弱** —— 任何新 UI 功能都要极度小心。
2. **现代占星 UI 尚未接入** —— 这是当前最大的“后端跑通但不可用”债务。
3. **AsteroidEphemerisManager 的硬编码路径** —— 仍未完全根治，会让其他用户直接用不了小行星。
4. **发布工程几乎为零** —— package_app.sh 仍是作者本地脚本，没有公证、没有更新机制。
5. **用户数据全在 UserDefaults** —— 换电脑就丢，API Key 明文。
6. **没有 CI** —— 所有验证都靠人（我）让 agent 跑本地命令。

下次 vibe 时，优先把精力放在**让这些脆弱点不继续恶化**，而不是继续加新占星算法。

---

## 6. 心态调整

- 接受“项目会一直有一点屎山”，目标是**可控的屎山**，而不是完美架构。
- 每当 agent 想“重构一下 ContentView”，要极度警惕。除非有非常清晰的小步计划，否则通常是 vibe 过度。
- 我的价值在于**业务判断 + 占星知识 + 产品感觉**，而不是代码审查。让 agent 把东西解释到我能懂的程度（用比喻、用例子、用“如果用户这么操作会怎样”）。

---

**最后一条铁律**：

> 任何让我感觉“这个改动以后我自己都搞不懂了”的 PR，都要打回去让 agent 简化或加更多文档/测试。

这个项目能走到今天已经很厉害了。只要我们把“vibe coding 的纪律”也当作第一优先级的需求，它就能持续发展下去，而不是变成只有我一个人（和 agent）能用的黑箱。

---

更新历史：
- 2026-06-xx：首次创建，基于对项目真实开发方式的反思。
