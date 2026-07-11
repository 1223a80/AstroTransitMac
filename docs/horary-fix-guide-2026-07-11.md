# Horary 审计问题修复指导

- 日期：2026-07-11
- 对应问题报告：`docs/horary-audit-2026-07-10.md`
- 适用基线：`49002fe` 及其后的纯文档审计改动

## 1. 修复目标

按依赖关系修复 Horary 审计确认的计算、契约和展示问题，补足真实事件序列回归，保证：

1. 同一盘面的相位完成、换向、换座和第三方介入结论来自同一事实序列；
2. Python 响应与 Swift 解码、UI、Markdown、CSV、AI 数据包一致；
3. 扩展 Lots 与仓库声明的公式 source of truth 一致；
4. 不把尚未确认的流派选择伪装成 bug 修复；
5. 全量验证、版本、打包、安装验证和缓存清理符合 `AGENTS.md`。

## 2. 开工前必须做的事

1. 完整读取根 `AGENTS.md`、`PLANS.md`、`CHANGELOG.md` 和问题报告。
2. 检查 `git status --short --branch`、`git log --oneline -10`，保留当前审计文档改动，不 reset、不 checkout 丢弃、不覆盖用户工作。
3. 在 `PLANS.md` 新增修复计划；非平凡工作使用独立分支，建议 `codex/fix-horary-audit-2026-07`。
4. 查询现有 helper、模型和调用点后再改；不要新建与现有 ephemeris/aspect/house helper 平行的接口。
5. 每次代码变更同步追加 `CHANGELOG.md`；每个批次先写失败回归，再实现修复。

## 3. 明确不在默认修复范围内的业务选择

以下项目需要项目所有者确认，默认不要改：

- VOC 是否按 Lilly 的 orb/application 口径，还是继续采用当前“换座前 exact perfection”口径；
- out-of-sign application 是否允许完成；
- reception 是否扩展为无相位 mutual reception；
- 全局 `aspectOrb` 是否改为行星 moiety；
- 默认宫制、Hayz 范围、ASC 早晚度等流派参数；
- 问题文本自动推断之外，是否新增显式 quesited house 选择器。

本轮可以修复“缺少 `questionText` 校验”和“unknown 时缺少 warning/诊断”；不要自行发明更多关键词或 derived-house 优先级。若要增加人工宫位选择，先向用户确认模型和 UI。

### 3.1 强制范围矩阵

状态定义：

- `REQUIRED`：必须实现、测试、验收；任一未完成不得宣称任务完成。
- `DECISION_REQUIRED`：必须停下向用户确认；未获确认不得实现，也不得宣称已修复。

| ID | 状态 | 最低交付 |
|---|---|---|
| P1-01 | REQUIRED | UTC 事件连续性 + refranation 真实回归 |
| P1-02 | REQUIRED | Moon 在 pair 左右两侧结果对称 |
| P1-03 | REQUIRED | 慢于主征象星的第三星不得成为 translator |
| P1-04 | REQUIRED | 统一事件序列；同一事件不产生矛盾 detected 证词 |
| P1-05 | REQUIRED | Horary fixture 的全部相位端点可解析并可绘制 |
| P2-01 | REQUIRED | IANA 回拨与 UTC 搜索返回同一精确根 |
| P2-02 | REQUIRED | ingress 后 26.5 秒真实首相位不再被跳过 |
| P2-03 | REQUIRED | 四项 Lots 与项目 source of truth 一致 |
| P2-04 | REQUIRED | `score_label` 与最终 score 一致 |
| P2-05 | REQUIRED | detriment + fall 可同时输出 |
| P2-06 | REQUIRED | sidereal meta 与实际 ayanamsha 一致 |
| P2-07 | REQUIRED | detected Advanced 字段与 exact time 不在 Swift/UI/导出丢失 |
| P2-08 | REQUIRED | experimental Lots 独立分组并保留 confidence |
| P2-09 | REQUIRED | meta/Markdown/CSV/AI 含完整计算 provenance |
| P2-10 | REQUIRED | JSON tab 在原页重算后刷新 |
| P3-01 | REQUIRED | Horary 嵌套请求返回结构化校验错误，不抛裸 KeyError |
| P3-02 | DECISION_REQUIRED | 是否增加 quesited-house picker/扩展推断规则，必须由用户决定 |

### 3.2 强制停止条件

出现任一情况，Agent 必须停止相关实现并向用户报告，不得自行选择：

1. 工作树出现与 Horary 审计无关的未提交业务改动；
2. 要改变 VOC、out-of-sign、reception、moiety、默认宫制或 derived-house 规则；
3. 需要删除/重命名现有 JSON 字段，或把可选字段改为必填从而破坏旧 fixture；
4. P1 真实复现无法在当前基线重现；
5. 项目 source of truth、现有测试与权威规则互相冲突且不能同时满足；
6. 全量门禁失败原因不属于本任务，且修复会扩大到其他领域。

不得用“刷新 fixture”“放宽断言”“改成 warning”“捕获裸 Exception”绕过停止条件。

## 4. 推荐修复批次与依赖

| 批次 | 目标 | 覆盖问题 | 依赖 |
|---|---|---|---|
| A | UTC 时间搜索与连续 application | P1-01、P2-01、P2-02 | 无 |
| B | Moon 对称性与统一事件序列 | P1-02、P1-03、P1-04 | A |
| C | Lots / 评分 / 负接纳 | P2-03、P2-04、P2-05 | 无，可与 A 独立提交 |
| D | 星盘图与 Swift 动态字段 | P1-05、P2-07、P2-08、P2-10 | Python 契约稳定后 |
| E | meta / 导出 / API 校验 | P2-06、P2-09、P3-01 | D 前后均可，fixture 最后统一刷新 |
| F | 全量验收与发布 | 全部 | A–E |

建议按批次单独提交，避免把核心时序重构、Lots 数据修正和 Swift UI 改动揉成一个无法评审的提交。

## 5. 批次 A：UTC 时间搜索与连续 application

### 5.1 所有搜索在 UTC 时间轴运行

目标文件：`astro_backend_horary.py`。

要求：

- `next_exact_for_pair*`、`previous_exact_for_pair*`、`refine_pair_crossing()`、`next_sign_exit_for_body()`、`refine_body_longitude_crossing()` 的步进和二分使用 UTC aware datetime；
- 对外返回值转换回起盘 datetime 的原 timezone，保持 `exact_local` 与 UI 契约；
- naive datetime 的现有测试语义保持不变，不要把 naive 值擅自解释为系统本地时区；
- 不重复实现 JD 转换，继续复用 `body_longitude_at()` / `jd_from_datetime()`。

必须新增：

- `America/New_York` 2000-10-29 Moon–Saturn opposition 回拨回归；
- 同一事件从 IANA local 与 UTC 起点搜索，UTC exact 和相位残差一致；
- DST gap/fold 输入验证原测试继续通过。

验收：相位残差建议 `< 1e-5°`，不能再返回 `01:59:59 EDT` 的伪根。

### 5.2 显式识别 refranation / application 中断

不要只在当前时刻打一次 `入相` 标签后搜索任意未来根。需要检查从 chart time 到候选 exact 的事件连续性。

推荐做法：

1. 为 pair 建立最小事件序列：candidate exact、双方 station/retrograde/direct、双方 sign exit；
2. 候选 exact 之前若应用方停滞并使 signed orb 由收敛转为发散，则原 application 为 refranation；
3. 后续恢复顺行形成的新 application 不能当作原 application 的连续完成；
4. `exact_datetime_for_signature()` 返回结构化失败原因，或增加内部 result 类型；避免所有失败继续坍缩为 `None`。

可优先复用 `body_speed_at()`；不要用固定日期表或仅检查起点/终点速度。

必须新增真实回归：

- `2026-10-21 00:00 UTC` Mercury–Jupiter square；
- 断言不再返回 `2026-12-04 07:02` 为原 application perfection；
- key link 的 `perfects_before_sign_exit=false`，reason 明确为 refranation/application interrupted；
- 正常无 station 的慢行星 Jupiter–Saturn 既有回归仍通过。

### 5.3 不再固定跳过 ingress 后一分钟

替换 `sign_exit_dt + timedelta(minutes=1)`：

- 可从 ingress exact 使用极小时间 epsilon（例如微秒级/亚秒级）；
- 或从 ingress 时刻搜索，再显式排除 `exact <= ingress` 的旧根；
- 不允许用 1 分钟、1 秒等会吞掉真实事件的任意窗口。

真实回归：`1905-06-21 12:00 UTC` 应把入双鱼后约 26.5 秒的 Moon trine Sun 识别为 `first_after_ingress`。

## 6. 批次 B：Moon 对称性与统一 Advanced 事件序列

### 6.1 修复 Moon pair 左右不对称

目标：`key_significator_links()`。

要求：

- pair 任一端为 Moon 都使用 Moon storyline；
- 正确识别另一端为 target；
- 输出 pair label 和 ID 的现有方向可保持，但相位、orb、exact、perfection 必须对称；
- self-significator 路径继续优先排除。

真实回归：`2026-01-03 00:00 UTC`、纬度 0、经度 -10、Whole Sign、问题“工作”、orb 3；`VENUS|MOON` 必须复用 `08:40` opposition，而不是 `sign-based only`。

再加属性测试：交换 `left_row/right_row` 后，相位类型、orb、是否完成和 UTC exact 一致。

### 6.2 建立统一事件事实流

不要让 Translation、Collection、Prohibition、Frustration 各自重新猜测未来。建议增加内部结构，例如：

```text
HoraryEvent
- kind: aspect_exact / station / retrograde / direct / sign_exit
- utc
- local
- body_ids
- aspect_id / angle
- applying_body
- valid_before_sign_exit
- interruption_reason
```

名称和实现形式可按项目风格调整，但四个 detector 必须消费同一批按 UTC 排序的事件。

### 6.3 Translation

至少要求：

- translator 与两主征象星不同；
- translator 比双方更快（按实际运动和选定传统定义处理 retrograde，不可只看名称）；
- 当前确实仍在离相一方且同时入相另一方；
- 下一 first application 是另一主征象星，途中无更早阻断事件；
- 复用批次 A 的 refranation/sign-exit 结果。

真实回归：`2015-01-01 12:00 Asia/Shanghai`、上海、问题“房产”、orb 8；Jupiter 不得再被判为 Moon/Mars 的 translator。

### 6.4 Collection / Prohibition / Frustration

要求：

- Collection 比较双方 first application 和完成时间；发生在主相位之后的第二次接触不能反过来促成主事件；
- Prohibition 和 Frustration 使用同一主相位、同一第三方事件与同一 UTC 顺序；
- Frustration 若作为 Prohibition 的明确 subtype，保持四个固定 response ID 以兼容 Swift，但同一事件只允许一个 row 为 `detected`；另一 row 可返回 `not detected` 并说明已归类为 subtype；
- 不要在缺少主 application 时声称 denial；
- 继续排除 self-aspect。

真实回归：`2010-01-03 00:00 Asia/Shanghai`、上海、问题“学习”、orb 8：

- `2010-01-12` 的 Sun collection 不得 detected；
- `2010-01-05 03:06` 的同一事件不能同时作为两个独立 detected 证词；
- 主相位与 denial 的时间顺序必须可从单一事件列表解释。

## 7. 批次 C：Lots、评分与负接纳

### 7.1 Lots 严格对齐 source of truth

目标文件：`astro_backend_classical_lots.py`、`python_tests/test_extended_lots.py`。

实现 `house_ruler:N` 或等价现有风格引用：

1. 取实际 `cusps[N-1]`；
2. `zodiac_sign_index()`；
3. `SIGN_RULERS[sign]`；
4. 取该主星在 `positions` 中的真实黄经。

禁止复用当前 `house_ruler_lon()` 的“自然宫位 0°”逻辑；它不是实际宫主星位置。

按规范修正：

- Marriage 日/夜方向；
- Travel 使用实际 H9 ruler；
- Lost Objects 使用实际 H2 ruler；
- Murder 使用实际 H12 ruler。

增加数据驱动测试，至少逐条断言这四项 day/night formula token 和真实数值；最好把规范中所有使用“宫主”的 Lots 纳入契约测试。

### 7.2 评分 label 必须由最终 score 生成

抽取唯一 helper，例如 `score_label_for(score)`：

- 初始构造和 conditioning 完成后都调用同一 helper；
- 最好只在全部 conditioning 完成后最终写 label，避免重复状态；
- 检查 medieval/timing 摘要是否读取 stale label。

回归：原 sample Jupiter 最终 9 分时 label 必须为“状态良好”。

### 7.3 Negative reception 同时保留 detriment 与 fall

把单一 `debility` 的 `if/elif` 改为收集所有成立项并逐项输出；保持稳定排序与唯一 ID。

回归：`2026-03-10 15:30 Asia/Shanghai`、orb 8，Mercury 对 Pisces 中相关星体应同时出现 detriment 与 fall。

## 8. 批次 D：Swift 星盘图、动态字段与 Lots 分组

### 8.1 Wheel endpoint 使用稳定 ID

优先在 Swift 映射现有响应，避免仅为 UI 改大范围 JSON schema：

- 由 `result.planets` 建 `name -> id` 映射；
- `ClassicalAspectRow.bodyA/bodyB` 转成稳定 point IDs；
- Classical 与 Horary 共用纯 helper；
- 无法解析的端点要可诊断，不能静默全部跳过。

相位颜色同时标准化：`整宫冲相 -> 冲相`、`整宫拱相 -> 拱相`、`整宫六合 -> 六合`、`同宫 -> 合相/单独 co-presence 颜色`，由产品现有色语义决定。

Swift 测试至少断言：真实 Horary fixture 的 11 条相位均能解析到有效 endpoint；硬/软相位颜色 key 正确。

### 8.2 补齐 Advanced 动态字段

Python detected response 与 Swift model 对齐：

- 增加 `frustratingPlanet` / `frustrating_planet`；
- 检查并清理重复的 `HoraryAdvancedResult` 与 `HoraryAdvancedCandidate`，优先复用一个模型，但不要为重构扩大无关 diff；
- UI 显示 `exactTime` 和第三方角色；
- Markdown、CSV、AI packet 输出 exact time 与 detected-specific fields；
- JSON decode → encode 不得丢字段。

新增 detected-state Swift fixture/test，不能继续只用四项全 `not detected` 的 fixture。

### 8.3 正确分组 experimental Lots

Horary Points 页按 `lotGroup` 拆分：

- 正式组与 experimental 分开传给 `ClassicalPointsView`；
- 不要把全部 56 项统一命名为 Hermetic Lots，可按 `core / life / career / spirit / experimental` 显示，或至少把 experimental 单列并显示 confidence；
- CSV 增加 `lot_group`、`confidence`。

### 8.4 RawJSON 必须随 result 更新

不要用永久 `hasGeneratedJSON` 缓存。可选安全方案：

- 调用点为 `RawJSONView` 提供稳定但随结果变化的 revision/id；或
- 让 view 在输入编码结果改变时重新生成；或
- 用轻量 observable cache，但必须有明确 invalidation。

回归：停留 JSON tab 重算 Horary 后，问题文本、asked time 和行星位置必须立即变成新结果。

## 9. 批次 E：meta、导出与 API 校验

### 9.1 复用 sidereal label 映射

不要再次硬编码。复用/提取 `astro_backend_api.py` 中已有 zodiac label 逻辑，保证 Raman、Krishnamurti、Yukteshwar 等按实际模式输出。

### 9.2 记录完整 provenance

响应 meta 增加 `aspect_orb`（建议可选 Swift 字段以兼容旧 fixture），并确保：

- UI metadata 显示；
- Markdown / CSV / AI packet 包含 house system、zodiac、bounds、triplicity、aspect orb；
- JSON fixture 更新；
- 旧响应缺字段时 Swift 仍可解码。

### 9.3 嵌套输入验证

`validate_required_fields()` 至少检查：

- `chart` 是 object；
- `chart.moment` 及 year/month/day/hour/minute/timezone；
- latitude/longitude 存在、是有限数字且范围合法；
- `questionText` 是非空字符串；
- `aspectOrb` 是有限正数且在 UI/项目允许范围内；
- house/zodiac/bounds/triplicity 使用共享常量允许值。

错误继续走现有 JSON error protocol，不抛裸 KeyError，不改变进程契约。

`questionText` 无法推断 Matter 时至少返回明确 warning/diagnostic；不要未经确认扩展关键词业务规则。

## 10. Fixture 与测试矩阵

### 10.1 Definition of Done（硬门槛）

只有同时满足以下全部条件，才允许把任务标为完成：

- 16 项 `REQUIRED` 均有失败前回归和修复后通过证据；
- 5 项 P1 均有至少一个真实 Swiss Ephemeris 复现，不是纯 monkeypatch；
- P3-02 明确记录为“用户已决定并实施”或“未获决定、保持 deferred”，不得静默消失；
- Horary Python 聚焦、extended lots、contract tests 全绿；
- Swift build、Horary/BackendContract/Markdown tests 全绿；
- `bash check_vibe_changes.sh` 全绿；
- 报告列出的所有真实复现逐项复跑，旧错误输出消失；
- 有意 JSON shape 变化已人工审查 fixture diff，Swift 对旧响应向后兼容；
- 完整 `git diff` 无无关改动、生成物、cache、pyc；
- 版本、打包、安装、codesign、安装包 Horary smoke、缓存清理全部完成；
- 未经用户明确要求没有 push。

### Python 聚焦

```bash
/usr/local/bin/python3 -m pytest python_tests/test_horary.py -q
/usr/local/bin/python3 -m pytest python_tests/test_extended_lots.py -q
/usr/local/bin/python3 -m pytest python_tests/test_contracts.py::TestHoraryContract -q
```

新增测试不得只 monkeypatch exact 时间；每个 P1 至少保留一个真实 Swiss Ephemeris 回归。

### Swift

```bash
swift build
swift test --filter HoraryResultTests
swift test --filter BackendContractTests
swift test --filter MarkdownExportTests
```

若 JSON shape 有意变化，按 `docs/validation.md` 重新生成 Horary fixture；先比较 schema diff，禁止用刷新 fixture 掩盖意外字段漂移。

### 全量门禁与 smoke

```bash
bash check_vibe_changes.sh
/usr/local/bin/python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-horary-request.json
```

另外执行报告中的 P1/P2 真实复现请求，确认旧错误已消失。

## 11. 评审与提交要求

每个批次完成后：

1. 更新 `PLANS.md` 状态和 `CHANGELOG.md`；
2. 运行该批次聚焦测试；
3. 检查 `git diff --stat` 和完整 `git diff`；
4. 确认无 `.build/`、`.pytest_cache/`、`__pycache__/`、`.pyc`、fixture 临时文件混入；
5. 以独立 commit 表示 A/B/C/D/E 逻辑边界；
6. 最终全量门禁通过后再更新版本、打包覆盖 `/Applications/TransitStudio.app`；
7. 验证安装版本、codesign、无 pycache，并运行安装包内 Horary smoke；
8. 清理 Swift/Python 构建测试缓存，降低硬盘占用；
9. 未经用户明确要求不要 push、force-push 或改写共享历史。

## 12. 直接交给修复 Agent 的提示词

以下内容可直接复制：

```text
你将在 /Users/gacu/Documents/Codex/AstroTransitMac 修复 Horary 专项审计确认的问题。该任务是高约束执行任务，不是自由重构：问题报告共 17 项，其中 16 项 REQUIRED 必须全部完成，P3-02 是 DECISION_REQUIRED，未经用户确认禁止实现。任一 REQUIRED 未完成，不得宣称完成。

开始前必须完整读取：
1. /Users/gacu/Documents/Codex/AstroTransitMac/AGENTS.md
2. /Users/gacu/Documents/Codex/AstroTransitMac/docs/horary-audit-2026-07-10.md
3. /Users/gacu/Documents/Codex/AstroTransitMac/docs/horary-fix-guide-2026-07-11.md
4. 根 PLANS.md、CHANGELOG.md、docs/validation.md

先检查 git status / branch / 最近提交，保留现有审计文档和用户改动，禁止 reset、checkout 丢弃、stash 覆盖或混入无关修改。如果工作树除 PLANS.md、CHANGELOG.md 和两份 Horary 审计文档外还有未归类修改，立即停止并报告。否则建立独立分支 codex/fix-horary-audit-2026-07，并先把任务计划写入 PLANS.md。

开始改代码前，逐项复跑问题报告中的 5 个 P1 真实样例，把旧错误输出写入本次验证记录。任何 P1 无法复现，立即停止对应修复并报告基线差异，不得凭报告盲改。

严格按修复指导的 A→B→C→D→E 批次施工：
- A：UTC 时间轴、DST 精确根、refranation、ingress 后首相位；
- B：Moon pair 对称性、统一事件队列、Translation/Collection/Prohibition/Frustration；
- C：Lots source-of-truth、最终 score_label、双重 negative reception；
- D：Horary/Classical wheel endpoint、Advanced 动态字段与 exact time、experimental Lots、RawJSON 刷新；
- E：sidereal meta、aspectOrb/完整 provenance、Markdown/CSV/AI、嵌套 API 校验。

每个 bug 先写会失败的聚焦回归，再修实现。P1 必须至少有一个真实 Swiss Ephemeris 回归，不能全部用 monkeypatch。查询现有 helper 和调用点后再修改，优先复用 body_longitude_at、body_speed_at、house_for_longitude、现有 Swift models/builders；不要猜接口，不要平行造轮子。

禁止擅改这些业务口径：VOC 定义、out-of-sign application、无相位 mutual reception、行星 moiety、默认宫制、Hayz/ASC radicality、问题文本 derived-house 规则。P3-02 必须保持 DECISION_REQUIRED：问题无法推断宫位时可以增加 warning/diagnostic；新增关键词、derived-house 优先级或人工 quesited-house picker 必须先问用户并得到明确答复。

强制停止条件：出现无关 dirty 业务改动；需要破坏旧 JSON；需要改变上述流派口径；P1 不能复现；source of truth 与测试冲突；全量门禁出现任务外失败且修复会扩范围——任一发生都必须停止并报告。禁止通过刷新 fixture、放宽断言、改成 warning、捕获裸 Exception 或删除测试绕过。

保持现有 JSON 向后兼容；需要新增 meta 字段时 Swift 用可选字段兼容旧响应。若有意改 JSON shape，按 docs/validation.md 更新 Horary fixture，并人工检查 schema diff。Detected advanced fixture 必须覆盖 frustrating_planet 和 exact_time，确保 Swift decode→encode、UI、Markdown、CSV、AI 都不丢数据。

每批次更新 CHANGELOG.md 和 PLANS.md，运行对应测试并检查完整 diff。最终运行：
- /usr/local/bin/python3 -m pytest python_tests/test_horary.py -q
- /usr/local/bin/python3 -m pytest python_tests/test_extended_lots.py -q
- /usr/local/bin/python3 -m pytest python_tests/test_contracts.py::TestHoraryContract -q
- swift build
- swift test
- bash check_vibe_changes.sh
- Horary backend smoke 与问题报告中的所有真实复现

只有 16 项 REQUIRED 全部满足 Definition of Done 后，才允许按改动规模更新版本并默认打包覆盖 /Applications/TransitStudio.app；验证安装版本、codesign、安装包内 Horary smoke 和无 pycache。最后清理 .build、pytest/pycache 等缓存，检查 git diff --stat、完整 diff、git status。未经用户明确要求不要 push，也不要宣称已上 GitHub。

修复完成时按批次列出：修改文件、根因、回归测试、全量验证、仍需用户决定的业务项。不要只说“测试通过”；给出真实数量和关键复现已消失的证据。
```
