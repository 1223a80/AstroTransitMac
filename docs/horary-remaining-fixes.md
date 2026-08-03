# Horary 剩余修复计划（2026-08-02 审计 → 待执行）

> 本文档供后续修改参照。每条问题含：位置、现状、建议修法、影响面、验证方式。
> 已完成修复见 `CHANGELOG.md`（2026-08-02 起多条条目）；本清单 A–J 已于 2026-08-03 全部完成。

## 已完成（勿重复）

1. **行星日/时 GMT±N 时区降级 UTC**（行星日主星/行星时错一天）— `astro_backend_horary_v2_modules.py`
2. **日出/日落过去窗口事件缺失** — `astro_backend_horary_v2.py` `_build_events`（含 400 天探针上限）
3. **`_jd_ut_to_local` 进位丢日期** — `astro_backend_horary_v2.py`
4. **Horary 证据 tab 显示枚举反射文本** — `HoraryDataPacketModels.swift` `prettyJSON` + 三处调用点
5. **离相（separating）候选 next_exact 无 refranation/换座防护** — `astro_backend_horary.py`（抽取 `nearest_branch_offset` / `application_continuity_interruption`）+ `astro_backend_horary_v2_aspects.py` separating fallback；golden/fixture 已重生成（移除 19 个虚假 aspect_exact 事件）
6. **A. 秒精度起盘时刻** — `ChartMoment.second`（可选，缺省不编码）、`makeMoment` 读秒、后端 `moment_to_local_datetime` 两分支支持 second（0-59 校验）、`DateTimeInput` `showsSeconds`（horary 起盘时间开启）；回归测试见 `python_tests/test_horary_v2.py::test_moment_second_*` 与 `SwiftTests/ModernRequestEncodingTests.swift::chartMomentSecondEncodesOnlyWhenPresent`
7. **B. VOC rule B 独立判定** — `_moon_index` 增加 `future_any`（4 天窗口不截断 sign_exit）；rule B 现为「未来任何成相都阻止 VOC」，与 rule A 的差异恰在成相晚于星座出口的情形；`_voc_interval` 对 start>end（成相晚于 sign_exit）输出 `complete=false`
8. **C. `_build_events` 相位事件整批丢弃（性能）** — 删除 `_build_events` 的 aspect_exact 生成段与 `aspects` 参数，`calculate_horary_v2` 只走 `aspect_exact_events_from_candidates` 重建路径（events 输出不变）
9. **D. `_search_station` kind 兜底** — after 采样缺失时按 before 方向推断（direct→retro / retro→direct），双缺失回退中性 `station`
10. **E. `packetVersion` 溯源哈希** — `input_canonical["packetVersion"] = str(request.get("packetVersion") or "2")`；`"2"` 请求 hash 不变
11. **F. `optional_modules` 占位键** — 移除 `not_computed_in_core` 占位（`declination_parallels`/`fixed_stars`/`planetary_hour`），仅输出真实数据键
12. **G. 死代码与类型标注** — 删除 `_build_pairwise`/`_applying_with_motion` 及 import；空 for 循环；`_formula_text` 标注改 `tuple[str,str]`；`declination_parallels` 标注改 dict|list 联合；`BackendContractTests` `==105` 魔数逃生口移除
13. **H. schema 与文档契约** — `docs/schemas/horary-data-packet-2.1.json` 补 required（`aspects_in_display_orb`/`display`）、bodies sign/motion/equatorial/horizontal/names、ecliptic 缺键、receptions `related_aspect_candidate_ids`、aspect_candidates/events/lots/validation 键补全、optional_modules/nodes 定义；`FIELD_DICTIONARY.md` optional_modules 表同步（无占位键说明）
14. **I. Swift 端体验** — `analyze()` 支持 `promptStyle` 参数（horary 分支固定 "horary"）；`runHorary` 起盘前清 `horaryResult` + AI 文本；`horaryAspectOrb` 钳制 0...10；删除 12 个未进入解码路径的类型化模型；`HoraryV2EvidenceRow.id` fallback 改用 FNV-1a 稳定哈希
15. **J. 测试补强** — `test_top_level_sections_present` 补 8 键；新增 separating-refranation 回归（2026-10-21 Mercury-Jupiter square → `next_exact.root_status == "not_found"` + refranation reason）

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
