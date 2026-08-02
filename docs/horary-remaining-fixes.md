# Horary 剩余修复计划（2026-08-02 审计 → 待执行）

> 本文档供后续修改参照。每条问题含：位置、现状、建议修法、影响面、验证方式。
> 已完成的修复见 `CHANGELOG.md`（2026-08-02 两条条目）。

## 已完成（勿重复）

1. **行星日/时 GMT±N 时区降级 UTC**（行星日主星/行星时错一天）— `astro_backend_horary_v2_modules.py`
2. **日出/日落过去窗口事件缺失** — `astro_backend_horary_v2.py` `_build_events`（含 400 天探针上限）
3. **`_jd_ut_to_local` 进位丢日期** — `astro_backend_horary_v2.py`
4. **Horary 证据 tab 显示枚举反射文本** — `HoraryDataPacketModels.swift` `prettyJSON` + 三处调用点
5. **离相（separating）候选 next_exact 无 refranation/换座防护** — `astro_backend_horary.py`（抽取 `nearest_branch_offset` / `application_continuity_interruption`）+ `astro_backend_horary_v2_aspects.py` separating fallback；golden/fixture 已重生成（移除 19 个虚假 aspect_exact 事件）

---

## 待修复清单

### A. 秒精度起盘时刻（用户确认要做）

- **现状**：Swift `ContentView+RequestHelpers.swift:59` `makeMoment` 用 `dateComponents([.year,.month,.day,.hour,.minute])` 丢弃秒；`ChartMoment`（`RequestModels.swift`）无 `second` 字段；后端 `astro_backend_core.py:168-211` `moment_to_local_datetime` 只读 `hour/minute`。
- **动机**：用户能提供精确到秒的事件时间（如手表记录），对 ASC/宫位有实际影响（秒 ≈ 15″ ASC，约 0.05° 宫头变化）。
- **建议修法**：
  1. Swift：`ChartMoment` 加 `second: Int?`（可选，编码时存在才输出，兼容旧请求）；`makeMoment` 读 `dateComponents([... .second])`；Horary 侧边栏时间选择器支持秒输入（需看 `ContentView+SidebarSections.swift` horary 时间控件现状，可能用 `DatePicker` 的 `dateComponents` 或自定义 Stepper）。
  2. 后端：`moment_to_local_datetime` 增加 `second = int(moment.get("second") or 0)`，同时支持 `moment["second"]` 校验（0-59、整数）；`resolve_timezone` 不动。
  3. 影响面：其它 mode 的 moment 请求无 `second` 键 → 缺省 0，输出不变；**input_hash 需确认**：`input_canonical` 的 moment 规范化字符串是否含 second（若不含则 hash 不变，若含则缺省 0 时也应与旧一致——需看 `astro_backend_horary_v2.py` 的 canonical 构造，避免旧请求 hash 漂移导致 golden 断言失败）。
  4. **验证**：`Examples/` 请求不带 second 时 fixture 不变（hash 断言全绿）；带 second=30 的请求输出 jd_ut 尾数变化、`time_and_location.utc_datetime` 含秒；`swift test` 请求编码测试。

### B. VOC rule B 与 rule A 输出相同判定

- **位置**：`astro_backend_horary_v2.py:1384-1396`（`_moon_index` 内）。
- **现状**：`voc_applying_only = len(future_in_sign) == 0` 与 rule A 的 `voc_before_sign_exit` 同值、同 interval，输出两个不同 `rule_id` 的规则行（`moon.void_of_course_rules`），`considerations_evidence` 也输出两条相同事实。代码注释自认 "conservative: all future_in_sign are exacts searched forward"。
- **建议修法**（二选一，需先读 `_moon_index` 全貌）：
  1. 让 rule B 真正独立：rule B 只检查"本星座内未来相位"为空（不含 sign-exit 前全窗口），即去掉 rule A 的 `sign_exit` 提前截断逻辑，判定集合不同；
  2. 或删除 rule B，保留单条 `rule_id`（破坏面：`moon.void_of_course_rules` 数量变化、`considerations_evidence` 两条 voc 事实变一条、Swift 无类型化依赖——`HoraryV2VocRule` 未参与解码）。
- **影响**：`moon.void_of_course_rules` 与 `considerations_evidence` 内容变化 → golden/fixture 重生成。
- **验证**：断言两条 rule 的 `value`/`interval` 不再恒等；`python_tests/test_horary_v2.py` 现有 `test_moon_voc_rules_have_intervals`。

### C. `_build_events` 相位事件生成后整批丢弃（性能）

- **位置**：`astro_backend_horary_v2.py:1026-1056`（`_build_events` 内 aspect_exact 生成）与 `:2007-2011`（`calculate_horary_v2` 过滤 `non_aspect_events` 后用 `aspect_exact_events_from_candidates` 重建）。
- **现状**：`_build_events` 对每个 orb 内相位做 next+previous 两次全窗口搜索生成 aspect_exact 事件，随后被整体丢弃——纯浪费（约一半 swe 调用）。
- **建议修法**：删除 `_build_events` 内的 aspect_exact 生成段（1026-1056），只保留重建路径。**前提**：确认 `aspect_exact_events_from_candidates`（`astro_backend_horary_v2_aspects.py`）生成的 id/字段/排序与现有一致（现有 golden 已在用重建路径，events 内容应不变——验证：golden 对比事件 id 集合不变）。
- **影响**：events 输出不变（若等价），仅性能提升。**验证**：golden `events` id 集合与重生成前一致；计时对比。

### D. `_search_station` kind 兜底可能错标

- **位置**：`astro_backend_horary_v2.py:580-586`。
- **现状**：`after` 速度采样为 None 时默认 `kind = "station_retrograde"`，可能错标（应可能是 station_direct）。
- **建议修法**：`after` 为 None 时依据 `before` 符号推断或标记 `kind = "station"`（中性），看上下文决定。
- **验证**：构造 after 采样失败场景（星历缺失难模拟，可单测函数）。

### E. `packetVersion` 硬编码影响溯源哈希

- **位置**：`astro_backend_horary_v2.py:2155`（`input_canonical["packetVersion"] = "2"`）。
- **现状**：请求 `"2.1"/"v2"` 时 provenance 的 input_hash 与 `"2"` 相同，不反映真实版本别名。
- **建议修法**：`input_canonical["packetVersion"] = str(request.get("packetVersion") or "2")`。**注意**：golden/Swift 请求均为 `"2"` → hash 不变，fixture 无需重生成（跑 golden 测试确认）。
- **验证**：请求 `packetVersion="2.1"` 与 `"2"` 的 input_hash 不同；`"2"` 的 hash 与现 golden 相同。

### F. `optional_modules` 占位键与覆盖键并存

- **位置**：`astro_backend_horary_v2.py:1713-1730`（占位）vs `:2088-2097`（覆盖）。
- **现状**：`optional_modules["declination_parallels"]` 保持 `"not_computed_in_core"` 占位，实际数据在 `declination_contacts`；`fixed_stars` 占位被覆盖。schema 混乱。
- **建议修法**：`_optional_modules` 不再输出 `declination_parallels`/`fixed_stars` 占位键，或统一命名。**影响**：`optional_modules` 键集变化 → golden/fixture 重生成；Swift `optionalModules` 是 `HoraryV2JSONValue?` 无损袋，无需改模型。
- **验证**：断言 `optional_modules` 无 `"not_computed_in_core"` 占位值。

### G. 死代码与类型标注清理

- `astro_backend_horary_v2.py:636-762` `_build_pairwise`（未被调用）— 删除前 grep 确认无引用。
- `astro_backend_horary_v2_modules.py:807-809` `considerations_evidence` 空 for 循环 — 删除。
- `astro_backend_horary_v2.py:1254-1257` `_moon_index` 的 `events` 参数未使用 — 删参数并更新调用点。
- `astro_backend_classical_lots.py:201` `_formula_text` 标注 `tuple[str,str,str,str]` 实际返回 2 元组；`astro_backend_horary_v2_modules.py:904` `declination_parallels` 标注 `-> list[...]` 实际 dict — 改标注。
- `SwiftTests/BackendContractTests.swift:614` `== 105` 魔数逃生口 — 去掉，保留结构断言。

### H. schema 与文档契约修正

- `docs/schemas/horary-data-packet-2.1.json`：
  - `:203` `related_aspect_id`（单数）→ 实际输出 `related_aspect_candidate_ids`（复数）——改 schema；
  - `:121` `bodies.required` 引用未定义的 `sign`/`motion` — 补 properties 定义；
  - `:124-131` ecliptic 缺 `distance_au`/`latitude_speed_deg_per_day`/`distance_speed_au_per_day`；aspect_candidates/events/lots.house/validation 均有多键未定义（`additionalProperties` 放行）— 补全；
  - required（`:8-15`）缺 `aspects_in_display_orb`/`display` — 补（收紧后 fixture 仍过，因为引擎恒输出）。
- `docs/horary-v2/FIELD_DICTIONARY.md:76-83` optional_modules 表缺 `planetary_hour`/`nodes` — 补。
- **验证**：`test_jsonschema_validates_packet` + `test_golden_file_matches_engine` 全绿。

### I. Swift 端体验问题

1. **AI 分析默认用错提示词**：`ContentView+AI.swift:161,244-259` `analyzeHoraryResult` 用全局 `aiPromptStyle`（默认 `general`），而"复制 Markdown"固定嵌入 horary 提示词。修法：horary 分支显式传 `appState.aiPromptHorary`（或 `AIPromptDefaults.text(for: "horary")`），与 ResultsPanes 导出一致。
2. **重算失败旧结果残留**：`ContentView+RunActions.swift:180-194` `performRun` catch 只写 `errorMessage` 不清 `calcVM.horaryResult` → AI 面板仍可对旧盘分析。修法：horary 模式失败时清 `horaryResult`（或通用：所有模式清各自 result，改动大，先只做 horary）。
3. **`horaryAspectOrb` 无输入约束**：`ContentView+SidebarSections.swift:203` `TextField` 清空回落 0 → 轮盘无相位线。修法：`.onChange` 钳制到 0...10 或改 `Stepper`/`Picker`。
4. **未使用的类型化模型**：`HoraryDataPacketModels.swift` 中 `HoraryV2Ecliptic`/`HoraryV2VocRule`/`HoraryV2Moon`/`HoraryV2Antiscia`/`HoraryV2ViaCombusta`/`HoraryV2Dodecatemoria` 等未进入解码路径（bodies 走 `HoraryV2EvidenceRow`）— 删除（grep 确认无引用）或补全键。
5. **`HoraryV2EvidenceRow.id` fallback**（`HoraryDataPacketModels.swift:574-578`）用 `keys.hashValue`（跨进程不稳定）— 改为按 key 排序拼接的稳定哈希。

### J. 测试补强

- `python_tests/test_horary_v2.py:103-125` `test_top_level_sections_present` 键列表缺 `aspect_candidates`/`aspects_in_display_orb`/`display_orb_deg`/`event_graph`/`planetary_day_hour`/`considerations_evidence`/`nodes`/`display` — 补齐。
- 新增：separating-refranation 回归（构造离相且未来被换座打断的 chart，断言 `next_exact.root_status == "not_found"` 且 reason 含拦截原因）。

---

## 明确不修（设计/契约决策，非缺陷）

| 项 | 理由 |
|---|---|
| `aspects` 与 `aspect_candidates` 同一对象（payload 双份） | 有意的 v1 兼容别名（`FIELD_DICTIONARY` 已说明）；改语义破坏 v2.1 契约 |
| GMTOffset 固定偏移无 DST | 全 app 既有设计（用户自选偏移，无 IANA 名） |
| 事件 id 秒级精度（亚秒丢失） | 改 id 格式会导致全部事件 id 变化、golden 大改；实际影响极低 |
| `sign_ingress` 逆行退回前一星座的标记 | 输出语义模糊但非错误；修正需新增字段，契约变化大 |
| v2.1 高级选项（eventPastDays 等）无 UI | 功能新增（非修复），需产品决策 |
| `nodes` 顶层与 `optional_modules.nodes` 重复 | schema 顶层 required 兼容所需 |
| `utc_datetime` 与 `utc_datetime_iso` 双轨 | 契约兼容，消费者需兼容两者 |
