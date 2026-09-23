# 后端计算缺陷修复总体计划（2026-09-22）

> 历史版本：后续实施请以 [v2 修订计划](bugfix-master-plan-20260922-v2.md) 为准。v2 已纠正本文部分接口假设、修法和任务覆盖；本文保留作修订依据。

> 性质：**修复计划，不含修复实现**。本文汇总 `docs/` 内全部 bug/审查文档的待修项，给出逐条修法、影响面、测试与验证方式，供后续分批执行。
> 来源：`backend-calculation-review-20260908.md`（新发现）、`backend-calculation-bug-scan-20260826.md`（旧扫描未关闭项）、`current-status.md`（收口状态）、`horary-remaining-fixes.md`（已关闭，仅作边界）、`calculation-audit-repair-spec.md`（已关闭，仅作边界）。
> 基线：`pytest` 1091 passed；分支 `codex/stabilize-json-contracts`。
> **禁止**把本文当作口径变更授权；标注 `DECISION_REQUIRED` 的项未获产品确认前不得实现。

---

## 0. 状态分流（先读这一节）

| 分类 | 数量 | 处理 |
|---|---|---|
| 新发现 P1 | 2 | 批次 A 必修 |
| 新发现 P2 | 14 + 2（horary）= 16 | 批次 B/C |
| 新发现 P3 | 20 + 10（horary）= 30 | 批次 E/F |
| 旧扫描仍未关闭 P2 | 11（P2-1～P2-11） | 批次 C/D |
| 旧扫描仍未关闭 P3 | 24（P3-1～P3-24） | 批次 E/F |
| 已仲裁误报 | 4 | **不修**：`armc_from_mc`、scan 无 stderr 进度、ZR 子周期 step==24 不可达、jyotish ET/UT ayanamsha 差 0.0001″ |
| 已关闭 | P1-1 SAV 337、horary A–J、13 项 calculation-audit | **勿重复** |
| 待口径决策 | 4 | 批次 G，先问人类 |

> 编号约定：`R-P1-1`/`R-P2-a` 等 = 20260908 报告；`S-P2-1`/`S-P3-1` 等 = 20260826 报告；`H-P2-F`/`H-P2-D` = 20260908 horary 补审。

---

## 1. 全局执行纪律（每批强制）

1. 开工前：`git status --short --branch` + `git rev-parse HEAD` 存档；脏工作区只绕开、不覆盖。当前工作区已有未提交的 `CHANGELOG.md`/`PLANS.md` 与未跟踪审查文档，归审查任务，不得混入修复提交。
2. 每批独立分支：`fix/bugfix-batch-a-egyptian-bounds-tz` 等；一批一事，禁止把 P3 清理混进 P1 提交。
3. 任务卡写入 `PLANS.md`，执行中逐项打勾；每条代码变更后追加 `CHANGELOG.md`（具体到行为差异，禁止“优化若干”）。
4. **先写失败测试 → 确认旧代码失败 → 最小修复 → 聚焦通过 → 模块全量无回归**。禁止放宽/删除既有断言，禁止硬编码期望值，禁止 `except Exception` 掩盖。
5. 数值断言：角度用环形差；浮点 `pytest.approx` 给绝对误差；时间同时断言日期/时刻/时区；搜索算法与更细步长基准比事件数与时刻；边界前/边界值/边界后三点。
6. 全链路：改 JSON 形状 → 查 Swift Codable 调用点 → 改模型/视图/导出 → 再生 fixture → `BackendContractTests` + `LiveBackendContractTests` → `Examples/` 冒烟。fixture 只能真实输出重生成，禁止手改。
7. 每批收尾门禁：`bash check_vibe_changes.sh`；后端单测 `python3 -m pytest python_tests/ -q`；Swift `swift build && swift test`。
8. 部署验证（若打包）：替换 `/Applications/TransitStudio.app/Contents/MacOS/TransitStudio` 后 `killall TransitStudio` 再 `open`，并 `ls -la /Applications/ | grep -i transit` 确认入口。
9. 涉及资源/目录结构变动后必须 `rm -rf .build && swift build`。
10. 交付说明三件事：改了什么、验证了什么、剩什么风险。

---

## 2. 批次 A — P1（必须最先做）

### A-1 `R-P1-1` 埃及界 Aries 误用托勒密数值

- **位置**：`astro_backend_classical_dignity.py:54-57`（`EGYPTIAN_BOUNDS[0]`）；注释 `:54` 自称 "Ptolemy's table of the Egyptians" 但值抄成托勒密自己的界。
- **现状**：`[("JUPITER",6),("VENUS",14),("MERCURY",21),("MARS",26),("SATURN",30)]` → Aries 12–14°/20–21°/25–26° 界主判错。
- **应然**（Tetrabiblos I.21 埃及界、Valens、Paulus、astro.com）：Jup 0–6 / Ven 6–12 / Mer 12–20 / Mar 20–25 / Sat 25–30，即 `[("JUPITER",6),("VENUS",12),("MERCURY",20),("MARS",25),("SATURN",30)]`。
- **修法**：只改 `EGYPTIAN_BOUNDS[0]` 五行；注释改为注明来源（Tetrabiblos I.21 Egyptian terms）与断言“其余 11 座已逐界核对”。**不动** `PTOLEMAIC_BOUNDS`（那是另一口径，见 G-1）。
- **影响面**：`bounds_ruler` → `planets[].bound/bound_ruler`、`score_breakdown`、`almuten_figuris`、`circumambulations`、`prenatal_syzygy.dignity_rulers`、hellenistic audit、classical_derivatives、time_lords 等全部 Egyptian 口径输出。
- **测试**：
  - 新增失败测试（先跑确认旧代码失败）：`test_classical.py` 或 `test_technique_maintenance_classical.py` 增加 Aries 逐界表测试，断言 `bounds_ruler(13,'egyptian')=="MERCURY"`、`bounds_ruler(20.5,'egyptian')=="MARS"`、`bounds_ruler(25.5,'egyptian')=="SATURN"`，并覆盖边界前/值/后（11.999/12/12.001、19.999/20/20.001、24.999/25/25.001）。
  - **必须同步修正** `test_classical.py:100-105` 现有断言（`bounds_ruler(20)==MERCURY`、`bounds_ruler(25)==MARS` 固化了错误表）——这是修正错误期望，不是放宽断言。
  - 全 12 星座表完整性测试：每座 5 界、上限严格递增、末界=30。
- **fixture**：classical 相关 fixture 若含 bound 字段需真实输出重生成；`SwiftTests/Fixtures/classical-*.json`、hellenistic-condition-audit、time-lords-extended、classical-derivatives、distributions-pd 受影响。
- **风险**：输出数值变化是**预期**；需在 CHANGELOG 明说“Aries 界主口径修正，评分/almuten 可能变”。Swift 模型无 schema 变化（字段名不变）。

### A-2 `R-P1-2` declination_timing 固定偏移时区被静默改成 UTC

- **位置**：`astro_backend_declination_timing.py:199-205`（`_display_zone`）。
- **现状**：`resolve_timezone("GMT+8")` 返回 `datetime.timezone`（固定偏移）而非 `ZoneInfo`，函数无条件 `return ZoneInfo("UTC")`，所有 `*_local` 显示 UTC，差 8 小时。
- **应然**：与其余模块一致——try `ZoneInfo` / except `resolve_timezone`，固定偏移直接用（参照 `modern_timing.py:1164`、`planetary_synodic.py:291-293`、`retrograde_cycles.py:237-239`、`visibility.py:531-533`、`mundane_electional.py:46`、`rectify.py:289-303`）。
- **修法**：
  ```python
  def _display_zone(name: str):
      text = str(name or "").strip() or "UTC"
      try:
          return ZoneInfo(text)
      except Exception:
          return resolve_timezone(text)  # 含 GMT±N 固定偏移与 UTC
  ```
  返回类型注解从 `ZoneInfo` 放宽为 `tzinfo`；检查下游 `astimezone` 调用点（`_display_zone` 的所有消费处）只依赖 `tzinfo` 协议则无需改动。
- **影响面**：`declination_timing` 全部 `*_local` 字段与 Swift `DeclinationTimingModels` 显示、导出 CSV/Markdown。
- **测试**：
  - `test_declination_timing.py` 新增：`_display_zone("GMT+8").utcoffset(None) == timedelta(hours=8)`；`"Asia/Shanghai"`、`"UTC"`、`"GMT-5:30"`、非法名抛错/回退行为与其余模块一致。
  - 端到端：同一请求 `display_timezone="GMT+8"` vs `"UTC"`，断言 `exact_utc` 相同、`exact_local` 差 8 小时（与 `test_modern_timing.py::test_display_timezone_changes_only_local_representation` 同口径）。
- **fixture**：`declination-timing-result.json` 需重生成（local 值变）。
- **风险**：低；属显示层修正，UTC 事实不变。

**批次 A 验证**：`python3 -m pytest python_tests/test_classical.py python_tests/test_technique_maintenance_classical.py python_tests/test_declination_timing.py python_tests/test_hellenistic_condition_audit.py -q` → 全量 pytest → 再生 fixture → `swift test` → 门禁。

---

## 3. 批次 B — 新发现 P2 局部小改（低风险高收益）

### B-1 `R-P2-a` composite 非等宫制 ASC 轴与宫头不一致

- **位置**：`astro_backend_composite.py:117-133`（同款逻辑 `progressed_composite.py` 需一并核对）。
- **现状**：`comp_asc=circular_midpoint(a_asc,b_asc)`，但宫头取均值盘 `raw_cusps` 再整体 `mc_delta` 平移 → `comp_cusps[0] ≠ comp_asc`（实测 Placidus 差 18.8°）。
- **应然**：非等宫制下重建后的第 1 宫头必须等于 `comp_asc`；两字段不得自相矛盾。
- **修法**（推荐最小一致化）：保留 `mc_delta` 旋转以保宫头相对结构，再做 `asc_delta = norm360(comp_asc - comp_cusps[0])` 二次平移使 `comp_cusps[0]==comp_asc`；或改为用 `build_houses_from_armc(comp_armc,…)`（但需先做 `S-P2-1` 的 sidereal flag）。**先与人类确认**采用“ASC 对齐”还是“MC 对齐”为权威（二者在非等宫制下不能同时满足，这是几何事实）——默认按 AGENTS 古典/现代惯例以 **ASC 对齐** 为准并在 `meta`/warnings 记录 `house_rebuild_alignment: "asc"`。
- **测试**：`test_modern_composite_davison_points.py` / `test_modern_relationship.py` 新增：Placidus 请求断言 `|circular_diff(angles.ASC, houses[0].cusp)| < 1e-6`；whole_sign 不回归；A/B 交换对称性保持（现有 `test_placidus_quadrant_houses_symmetric_under_ab_swap`）。
- **fixture**：`composite-result.json`、`progressed-composite-result.json` 重生成。
- **风险**：宫头数值整体变化，下游 house 归属、aspects 的 house 字段联动变化。

### B-2 `R-P2-b` Mercury Hayz 判定失效

- **位置**：`astro_backend_classical_dignity.py:460-461`。
- **现状**：`in_sect = sect.startswith("合")`，但 `sect_status` 对 Mercury 返回 `"随昼"`/`"随夜"`，`in_sect` 恒 False → Mercury 与盘 sect 一致时应 Hayz 得 `''`，反向 case 误判 Hayz。
- **修法**：显式判定 Mercury 的 sect 归属：`in_sect = ("昼" in sect and is_day) or ("夜" in sect and not is_day)`，或让 `sect_status` 额外返回结构化 `(sect_owner, follows_chart_sect: bool)` 再消费（优先扩展返回值，避免再靠中文子串）。注意保留 Sun 分支现有语义。
- **测试**：`test_classical.py::TestSectHayzJoy` 新增：昼盘太阳 20°白羊、Mercury 10°白羊（随昼）、house 10、阳星座 → `"Hayz"`；夜盘同几何反向断言非 Hayz；对照 Jupiter 同几何行为不变。
- **fixture**：classical fixture 重生成（`hayz` 字段）。
- **风险**：低。

### B-3 `R-P2-g` / `R-P2-h` method_families 参数吞噬

- **位置**：`astro_backend_method_families.py:115`（`or 1.0`）、`:138`（`bool()`）。
- **现状**：`solar_arc_rate_deg_per_year=0` 被吞成 1.0 → `arc_deg` 变成 age_years；`include_experimental_profiles="false"`（JSON 字符串）非空 → True。
- **修法**：
  - 速率：显式类型校验（`isinstance(x,(int,float)) and not isinstance(x,bool) and math.isfinite`），0 为合法值（表示零推进率）；缺失才用默认 1.0。校验下沉到 `astro_backend_api.py::validate_required_fields`（对 `mode=method_families` 增加字段规则），无效值返回结构化 `{"error","invalid"}`。
  - 布尔：`include_experimental_profiles` 必须是 JSON bool，字符串一律 `invalid`；同样进 API 校验。
- **测试**：`test_method_families.py` 新增：rate=0 → `arc_deg≈0`；rate 缺失 → age_years×1.0；`include_experimental_profiles="false"` 走结构化校验错误；`true/false` 真假分支各自生效。
- **fixture**：`method-families-result.json` 若样本含该字段则重生成。
- **风险**：低；契约更严（原先静默接受的非法输入现在报错），属预期收紧。

### B-4 `R-P2-e` Krittika 中文名错误

- **位置**：`astro_backend_jyotish_data.py:29`。
- **现状**：`Krittika` 的 `name_zh` 为“鬼宿”，与 `:34` Pushya 重复；应为“昴宿”。
- **修法**：`:29` 改为 `"name_zh": "昴宿"`；顺手全表扫描重复 `name_zh`（写测试断言 28 宿 `name_zh` 两两不同）。
- **测试**：`test_jyotish_focused.py` 新增 Krittika 中文名断言 + 28 宿 `name_zh` 唯一性；现有 `test_jyotish_focused.py:955,968` 只断言 `name_sa`，不受影响。
- **fixture**：`vedic-result.json` 重生成（`name_zh`）。
- **风险**：低；仅显示名。

### B-5 `S-P2-9` patterns Kite 的 aspect_types 恒 opposition

- **位置**：`astro_backend_patterns.py:236-239`。
- **现状**：`angular_separation` 值域 [0,180]，`<= 180+ORB` 恒真 → 三个 opposition。
- **应然**：1×opposition + 2×sextile（apex 对冲、另两星六合）。
- **修法**：按成员角色判定——先标 apex（与大三角对顶的那颗），apex–gt_member 为 `opposition`；其余两对为 `sextile`。可改为直接查 `_all_orbs`/aspect 表里实际命中的相位类型，禁止用“距离≤180”猜。
- **测试**：`test_patterns.py::test_kite` 扩展：教科书风筝（0/120/240+180）断言 `aspect_types` 计数 `opposition==1 and sextile==2`。
- **fixture**：含 patterns 的 modern/moment 结果重生成。
- **风险**：低。

### B-6 `S-P2-10` patterns 图形按 type 去重丢多实例

- **位置**：`astro_backend_patterns.py:310-316`。
- **现状**：`sig = s["type"]; if sig not in shape_seen` → 每类最多 1 条；下层 `find_chart_shapes` 本可返回多个不同成员实例。
- **修法**：删除按 type 去重，改为按 `(type, tuple(members))` 去重（与下层一致），全量透传。
- **测试**：8 星双摇篮构造断言 `find_patterns` 保留 2 个 cradle；现有单实例测试不回归。
- **风险**：低；输出数组可能变长。

### B-7 `R-P2-i` horary v2 速度缺失被无条件判 separating

- **位置**：`astro_backend_horary_v2_aspects.py:110-115`、`:165-166`。
- **现状**：速度 `or 0.0` → `rel=0` 落入 `abs(rel)<1e-12` 分支 → 无条件 `separating`。
- **修法**：速度缺失（None）与真 0（station）区分：缺失返回 `"unknown"`/`None` 并写 `application_note`；仅在双方速度都已知时才判 applying/separating；`rel==0` 且双方速度已知 → `stationary`。同步检查调用点（`_motion_state`、refranation、VOC）对 `unknown` 的容忍（不得当离相用）。
- **测试**：构造单侧速度缺失 → `application=="unknown"`（或字段为 None）且不进入 separating 的 refranation 否决路径；`test_horary_v2.py` 增补。
- **fixture**：`horary-result.json`、golden 文件按真实输出重生成（注意 `test_golden_file_matches_engine`）。
- **风险**：中——horary 证据链语义变化，必须重跑 `test_horary.py` + `test_horary_v2.py` 全量。

### B-8 `H-P2-F` Frustration 第三方速度约束过严（漏报）

- **位置**：`astro_backend_horary.py:1483`。
- **现状**：`if abs(third.speed) > slower_speed: continue`；Lilly 定义只要求“被接近的慢行星先与第三方完美”，对第三方速度无约束。
- **修法**：删除该速度过滤，保留“`third_exact < main_exact` 且 third_event 为入相于 slower”这两条真实约束；按 Lilly 主定义（被接近者先完美）保留现有方向，变体见 F-1。
- **测试**：新增构造——第三方**更快**（如 Venus 追 Saturn）仍应报 Frustration；现有 `test_horary.py:716`（更慢第三方）不回归。
- **风险**：中；影响 judgement 派生候选，golden 可能变化。

### B-9 `H-P2-D` declination_parallels 未校验同半球

- **位置**：`astro_backend_horary_v2_modules.py:906-947`。
- **现状**：`d_par=|da−db|`、`d_contra=|da+db|` 只与 orb 比较，无符号检查 → 异号时 parallel 与 contra 双双 `within_orb=True`。
- **应然**：parallel 要求同号且 `|da−db|≤orb`；contra 要求异号且 `|da+db|≤orb`；二者互斥。
- **修法**：进入判定前先 `same_side = (da*db) > 0 or (da==0 and db==0)`；`parallel` 仅 `same_side and d_par<=orb`；`contra_parallel` 仅 `(not same_side) and d_contra<=orb`；互斥互否。
- **测试**：`da=+0.4,db=-0.3` → 仅 contra；`+0.4/+0.3` → 仅 parallel；0 边界三点。
- **风险**：低-中；horary v2 包内 `declination_parallels` 行变化。

**批次 B 验证**：相关 pytest 文件 + `test_contracts.py` + horary 全量 + fixture 再生 + `swift test`。

---

## 4. 批次 C — 新发现 P2 语义/几何级

### C-1 `R-P2-c` primary_directions 非合相只取单方向

- **位置**：`astro_backend_primary_directions.py:104`。
- **现状**：非合相 `target_lon = sig_lon + ASPECT_ANGLES[asp]` 单分支；converse（`sig_lon − angle`）不生成，约一半方向缺失，`method_note` 未说明。
- **修法**：对非合相生成两条：`norm360(sig_lon + angle)`（direct/promissor 方向）与 `norm360(sig_lon - angle)`（converse/promissor 反方向），各自走 `platiclon_to_arc` 得 `arc_signed`，由符号决定 `direction_type`（direct/converse）；id 后缀区分（如 `…-direct` / `…-converse`）。`method_note` 更新为“双向齐取”。
- **DECISION_REQUIRED**（可降级为说明性修复）：产品是否真要 converse 双向（报告 §四.3）？默认**要**（几何完备性），若产品确认只做单向则至少在 `method_note` 明示“仅 direct 分支”。
- **测试**：square/sextile/trine 各断言行数翻倍且两方向 `arc_signed` 异号（同几何下）；`test_technique_maintenance_classical.py::test_pd_converse_dates_are_after_birth`、`test_pd_symmetric_duplicate_flag` 需按新结构核对。
- **fixture**：`primary-directions-audit-result.json`、classical 的 `primary_directions` 段、rectify 内 PD 行重生成。
- **风险**：中；行数与 id 变化，Swift 表格/导出联动。

### C-2 `R-P2-d` orbital_dial 行星图判定忽略 modulus

- **位置**：`astro_backend_orbital_dial.py:80/97`。
- **现状**：mid 已 `% modulus` 折叠，但 C 的判据用整圈距离 `abs(((c-mid+180)%360)-180)`；modulus=45/90 时相差 k×modulus 的同盘位被漏报/误报。
- **修法**：判据改为模距：`orb = min(abs(((c - mid) % modulus)), modulus - abs(((c - mid) % modulus)))`（即在模意义下的最短距），或等价地把 `c` 与 `mid` 同时折叠后取环形差。
- **测试**：`mid=10, c=55, modulus=45` → 模距 0 应命中；`mid=10, c=32.5, modulus=45` → 模距 22.5 不命中 orb=1；modulus=360 行为不回归。
- **fixture**：`orbital-dial-result.json` 重生成。
- **风险**：低。

### C-3 `R-P2-k` / `R-P2-l` mundane_electional 无 orb 阈值 + candidate_count 自相矛盾

- **位置**：`astro_backend_mundane_electional.py:169-182`（nearest_aspects）、`:258/286`（count vs 数组）。
- **现状**：最近主相位 orb 可达 30° 仍输出且 `applying/separating/exact_time` 恒 None；`meta.candidate_count = len(electional_candidates)` 但顶层 `electional_candidates` 实为 `scan_samples`，count=0 与数组非空并存。
- **修法**：
  - nearest_aspects 增加 orb 阈值（默认 `picture_orb`/`aspect_orb` 口径，建议 8°，进 `effective_config` 披露），超阈不入表；`applying/separating` 用相对速度符号填真实值（复用 `signed_orb×rel_speed` 判据），`exact_time` 可留 None 但加 `exact_time_note`。
  - 命名对齐：`meta.candidate_count` 改为统计真正的 `filtered_candidates`；或把顶层 legacy 键改名并同步 Swift `MundaneElectionalModels`（**禁止新旧语义并存**——选一条路）。推荐：`meta.candidate_count = len(filtered_candidates)`，顶层保留 `electional_candidates` 但内容改为 ranked candidates，`daily_fact_snapshots` 专存扫描行；Swift 与 CSV 导出同步。
- **测试**：`test_mundane_electional.py` 新增 orb 阈值过滤断言、`meta.candidate_count == len(filtered_candidates)`、applying/separating 非 None（在速度可知时）。
- **fixture**：`mundane-electional-result.json` 重生成；核对 `MundaneElectionalExports` CSV 列。
- **风险**：中——契约语义变化，需 Swift 模型/导出同改。

### C-4 `R-P2-f` Shadbala Jupiter +15 无据 + Drik 恒 0

- **位置**：`astro_backend_jyotish_shadbala.py:202`（`+15.0 if pid in ["JUPITER"]`）、`:220`（`dṛg_bala: 0.0`）。
- **DECISION_REQUIRED**（报告 §四.2）：补齐真实 Shadbala 子项，还是显式降级？
- **默认可修部分（无需决策）**：删除 Jupiter 特例 `+15.0`（无经典依据的硬编码优先删除，而不是保留）；`is_complete: False` 已存在，`shadbala_total/percent` 在 `is_complete=False` 时改为 `null` 或改名 `shadbala_partial_total` 并在 `calculation_assumptions` 声明未实现 Drik/Stthana 全分项——**需产品二选一**，默认取“`shadbala_total` 保留但加 `is_complete:false` + `excluded_components:["dṛg_bala","sthāna_bala(仅 uchcha)"]` 说明”，避免 schema 断裂。
- **测试**：Jupiter Kala Bala 与其它行星同公式；`is_complete==False` 时 excluded_components 非空。
- **fixture**：`vedic-result.json` 重生成；核对 `VedicResultModels`/`MarkdownVedicExportBuilder` 对 total/percent 的展示（is_complete=false 时加标注）。
- **风险**：中（口径）。

### C-5 `S-P2-11` Davison 空间中点用算术平均而非大圆中点

- **位置**：`astro_backend_davison.py:87-88`。
- **现状**：`mid_lat=(a+b)/2`、经度短弧平均；高纬/跨半球失真（伦敦/纽约 Δlat=−6.26°、ASC 偏 2.5°、MC 偏 4.1°），`meta.method` 未披露近似。
- **修法**：球面向量平均：单位向量 `v=(cosφcosλ, cosφsinλ, sinφ)`，`v̄=(v_a+v_b)/|v_a+v_b|`，`lat=asin(z)`、`lon=atan2(y,x)`；退化（对跖点）时明确报错/告警。`meta` 增加 `midspace_method: "great_circle_vector_mean"`。
- **测试**：伦敦/纽约断言大圆中点 ≈ (52.368, −41.290)（报告实测值，容差 0.01°）；对称性 `swap(a,b)` 不变；现有 `test_modern_relationship.py::test_geographic_longitude_midpoint_crosses_dateline` 保持；补 composite 是否同改——**composite 有 `mc_delta` 校正部分抵消，本批只改 Davison，composite 归 B-1**。
- **fixture**：`davison-result.json`、`modern-timing-davison-result.json` 重生成。
- **风险**：中；角度/宫位整体变化。

### C-6 `S-P2-1` build_houses_from_armc 缺 SIDEREAL flag

- **位置**：`astro_backend_ephemeris.py:366-408`；消费方 `method_families.py:170,175`。
- **现状**：`swe.houses_armc(...)` 不传 flags；恒星模式下宫头差一整个 ayanamsha。
- **修法**：`build_houses_from_armc` 增加 `sidereal: bool` 参数，传 `swe.FLG_SIDEREAL`（与 `build_houses:239-352` 同法）；`method_families` 调用点传入 `sidereal`。`armc_from_mc` 保持不动（已仲裁为精确）。
- **测试**：1990-01-01 12:00 Asia/Shanghai、Lahiri：`build_houses`(natal ASC sidereal)=353.8953° 与 `build_houses_from_armc`(同 ARMC, sidereal) 差 <0.01°；tropical 不回归。
- **fixture**：`method-families-result.json`（sidereal 请求）重生成。
- **风险**：中；method_families 恒星推进宫位变化。

### C-7 `S-P2-2` hellenistic audit 的 applying/separating 证据行恒 0

- **位置**：`astro_backend_hellenistic_audit.py:403-436`；数据源 `astro_backend_classical.py:486-494`。
- **现状**：双重失配——① aspects 行存中文名（`body_a="月亮"`）却用英文 id 匹配；② `applying` 值为 `"入相"/"离相"` 却比较 `"applying"/"separating"`。
- **修法**：
  - 上游 `classical.py` aspects 行**补 `body_a_id`/`body_b_id`**（英文 id，字段增量，Swift 可选解码）；hellenistic 用 id 匹配。
  - 判定改：`if applying in (True,"applying","入相")` / `elif applying in (False,"separating","离相")`（或上游统一改英文枚举——**推荐上游统一英文 `applying`/`separating`**，中文仅显示层，避免双语判定；若改上游需查全部消费点）。
- **测试**：`test_hellenistic_condition_audit.py` 新增：重放 `Examples/sample-hellenistic-condition-audit-request.json`，断言 `applying_aspect`/`separating_aspect` 两类行数 >0 且覆盖七曜。
- **fixture**：`hellenistic-condition-audit-result.json`、`classical-*` 重生成。
- **风险**：中；若统一枚举，导出文案需保持中文显示。

### C-8 `S-P2-3` 返照把出生瞬间当作一次返照

- **位置**：`astro_backend_classical.py:666-667, 825-842`；搜索窗口 `astro_backend_classical_timing.py:735-736`。
- **现状**：参考时刻距出生不足半窗时，出生瞬间过零点被收入 `exacts` 并归入 before → `current_cycle_return` = 出生时刻（零长度周期）。
- **修法**：`search_return_exacts` 结果统一过滤 `exact > birth_dt + ε`（ε 建议 1e-6 秒或 1 秒，需与秒精度口径一致）；删除 MARS/JUPITER/SATURN 的 `age<3` 特例补丁（被通用过滤取代）或保留为额外成熟度守卫但改为统一实现。`modern_return.py` 的同名搜索（若有共享 helper）一并走统一过滤。
- **测试**：1990-01-01 12:00 UTC 生、1990-01-11 参考：MOON `current_cycle_return` 不为出生时刻且 `exact > birth`；新生儿（age<1d）无 current 时 `previous_return`/`current` 语义为 null + warning；`test_contracts.py::planetary_returns_structure` 的三元组 schema 不变。
- **fixture**：`classical-*`、`modern-*-return-result.json` 重生成。
- **风险**：中；三元组数值变化。

### C-9 `S-P2-4` Yogini Dasha 起算与余额错位

- **位置**：`astro_backend_jyotish.py:457-464`。
- **现状**：`start_idx=(pada-1)%8`（只能 Mangala/Pingala/Dhanya/Bhramari 起）；余额按 pada 内进度。
- **应然**（Tajika Neelakanthi 系）：`first = (nak_0based − 5) mod 8`；余额 = 月亮在整段 nakshatra 内已行弧比例 × 首限年数。
- **修法**：改起算式与余额公式；在 `calculation_assumptions`/`_source_tradition` 声明流派（“Tajika Neelakanthi / standard Yogini table”）。
- **测试**：Moon 取 Krittika（n≡2 mod 8）三段中点 → 首限 Siddha；8 个起始限主全覆盖（对 28 宿循环断言 `first∈0..7` 且可取到 Siddha/Ulka/Sankata）；余额边界（nak 起点=0、终点→1）。
- **fixture**：`vedic-result.json` 重生成。
- **风险**：中-高（传统口径）；执行前把标准表写进测试注释作为 source of truth。

### C-10 `S-P2-5` 特殊上升点与时间型 Upagraha 为占位实现且随时区漂移

- **位置**：`astro_backend_jyotish_aux_points.py:156-220`（HL/GL/BL/Vighati/Sree/Indu/Bhava/Varnada/Kunda/Pranapada）、`:77-96`（Kaala/Mrityu/Artha/Yama/Gulika/Maandi）。
- **DECISION_REQUIRED**：完整 BPHS 实现 vs 显式降级标记。
- **默认可修部分**：立即给这些点加 `is_complete: false` / `method_status: "placeholder"` 与 `calculation_assumptions` 披露（对齐 Shadbala 的降级先例），避免静默错误数据出货；完整实现另立任务（需日出日落、昼夜八分段、星期主星链）。
- **测试**：占位点输出必带降级标记；`test_audit_vedic_regressions.py::test_sun_based_upagrahas_are_distinct…`（Sun 系五点已正确）不回归。
- **风险**：低（标记）/ 高（完整实现）。

### C-11 `S-P2-6` horary v2 `approaching_sun` 方向反转

- **位置**：`astro_backend_horary_v2_modules.py:123`。
- **现状**：`approaching_sun = abs(sep_signed) < abs(未来 sep)` —— 未来角距变大时输出 True（反了）。
- **修法**：改为 `approaching_sun = abs(未来 sep) < abs(sep_signed)`；`speed` 缺失/为 0 时输出 `None`（unknown）而非 False。
- **测试**：sun_lon=10、venus_lon=5、speed=1.6 → 未来 sep 收敛 → True；速度取负号镜像 case；speed=0 → None。
- **fixture**：`horary-result.json`、golden 重生成。
- **风险**：低-中。

### C-12 `S-P2-7` mundane 行星日主/时主键名错配恒 null

- **位置**：`astro_backend_mundane_electional.py:227-228`。
- **现状**：读 `day_ruler`/`planetary_day_ruler`/`hour_ruler`/`ruler`，实际键为 `day_ruler_id`/`day_ruler_name`、`ruler_id`/`ruler_name`。
- **修法**：改读真实键（`day_ruler_id` + `day_ruler_name` 映射到 `planetary_day_ruler`/`planetary_day_ruler_id` 之类一致命名）；**同时清理下游 null 兼容分支**，禁止新旧语义并存。Swift `MundaneElectionalModels` 字段类型若为可选需改必填并核对导出 CSV 列。
- **测试**：`test_mundane_electional.py` 断言 `daily_fact_snapshots[*].planetary_day_ruler` 非 null（status=ok 时）且等于 `test_classical_visibility.py:72` 同源 ruler。
- **fixture**：`mundane-electional-result.json` 重生成。
- **风险**：低-中（契约收紧）。

### C-13 `S-P2-8` scan 相位 applying/separating 由采样端点决定

- **位置**：`astro_backend_scan.py:540`。
- **现状**：`phase = "applying" if abs(f_prev)>abs(f_next) else "separating"`，随窗口起点平移翻转。
- **修法**：改为命中时刻附近相对角速度符号：`rel = speed_transit - speed_target`（目标点速度 0），`signed_orb×rel<0 → applying`；或用 refine 后的一阶导。`priority_score`/`orb_factor` 一并核对（见 E-13）。
- **测试**：同一事件窗口起点 00:00 vs 00:20 断言 `phase` 一致且符号正确；`TextExportBuilder` 导出列取值同步。
- **fixture**：`scan-result.json` 重生成。
- **风险**：中；导出表格变化。

**批次 C 验证**：各模块 pytest + `test_contracts.py` + fixture 再生 + Swift 解码/导出测试 + 门禁。建议 C 再拆 2–3 个 PR（几何类 / 文本与键名类 / 搜索语义类）。

---

## 5. 批次 D — 旧扫描 P2 收尾

> 与批次 C 同级，独立分支。D-1～D-5 见 C-5/C-6/C-7/C-8/C-9/C-10/C-11/C-12/C-13（已并入上文，勿重复）。
> D 剩余独立项：

### D-1 `R-P2-m` BODY_REGISTRY 与 LABELS 中文名两套

- **位置**：`astro_backend_core.py:92`（`BODY_REGISTRY[*].name`）vs `astro_backend_constants.py:69`（`LABELS`）。
- **现状**：PHOLUS “人龙星”/“Pholus”、MEAN_NODE “北交点 平”/“北交点”、MEAN_LILITH “Lilith 平”/“黑月（均）”；`planet_name()` 与 UI/导出取不同表。
- **修法**：单一来源——`LABELS` 只保留展示元数据或改为从 `BODY_REGISTRY` 派生；删除重复中文定义，`planet_name()` 成为唯一取名入口。Swift 侧不硬编码中文名（核对 `AstroConstants.swift`/`bodyOptions` 是否有第三份，若有则统一由后端下发或明确 UI 独立命名策略）。
- **测试**：断言 `BODY_REGISTRY[b].name == LABELS[b]["zh"]`（或新契约）对全部 body_id 成立；grep 确认无第三份中文表。
- **fixture**：含 `name`/`body_name` 的 fixture 重生成。
- **风险**：低-中（显示名变化）。

### D-2 `R-P2-n` 相位角表/orb 表/静止阈值跨模块不统一

- **位置**：跨模块（`quincunx` 仅 scan/patterns；合相 orb 1°～8°；静止 ±1e-9/±1e-6/<0 三种）。
- **DECISION_REQUIRED**：统一口径表（orb/静止阈值/相位角）需产品定数值。
- **默认可修部分**：抽 `astro_backend_constants.py` 增加 `STATION_SPEED_THRESHOLD`、`DEFAULT_ASPECT_ORBS`、`PATTERN_ASPECT_ORBS` 作为唯一常量表，各模块改引用（数值先保持各自现状并标注 `source_module`，避免一次改数值）；第二步再由产品统一数值。
- **测试**：常量表自身测试 + 各模块行为不回归（数值未变时全绿）。
- **风险**：低（本轮只抽表）。

**批次 D 验证**：全量 pytest + 门禁。

---

## 6. 批次 E — 旧扫描 P3（契约与时间边界优先）

按 `current-status.md` 的三批建议拆：

### E-1 输入校验类（P3-1/P3-2/P3-3/P3-5 + R-P3 api 项）

| 项 | 位置 | 修法 | 测试 |
|---|---|---|---|
| `S-P3-1` classical 缺 `birth.moment` 直崩 | `astro_backend_api.py:973-985` | `validate_required_fields` 对 classical 校验 `birth.moment` 五个字段，返回结构化 error | 缺字段 → `{"error","missing"}` 而非 `未知时区：None` |
| `S-P3-2` `resolve_bodies` 静默丢未知 id | `astro_backend_ephemeris.py:64-66` | 写 warnings 并列出被丢弃 id | 未知 id → warnings 非空 |
| `S-P3-3` manual 坐标默认 `"UTC"` | `astro_backend_location_service.py:206` | 缺省时区改为必填或显式 `None`+warning，禁止静默覆盖显示时区（`relocation.py:253` 合并链一并核对） | manual 无 timezone → 结构化校验错误或 warning |
| `S-P3-5` `previous_return` 缺失不告警 | `astro_backend_modern_return.py:397-400` | previous 缺失同样 warning；搜索窗口参数化 | previous null → warning |
| `R-P3` mundane 必填未进校验 | `astro_backend_api.py:1771-1816` | `display_timezone`/`location.timezone` 进 `required_by_mode`/字段校验 | 缺 → 结构化 error |

### E-2 时间与精度类（P3-6～P3-11 + R-P3 时间项）

| 项 | 位置 | 修法 | 测试 |
|---|---|---|---|
| `S-P3-6` OOB 用平黄赤交角 | `core.py:340-343` + `ephemeris.py:181` | 改用真 `obliquity_deg(jd)` | 边界带 ±9.2″ 内用真值单侧 |
| `S-P3-7` Ashtottari Shravana 上限 | `jyotish.py:501` | 293.6667 → 293.3333 | portion 单调 |
| `S-P3-8` 2/29 年份钳制抛错 | `scan.py:442-443` | 用 `min(year, max)` 的安全构造（先 clamp 月日） | 闰日窗口不被拒 |
| `S-P3-9` MD/AD 秒截断 | `jyotish.py:343-349,400-423` | 比较用 datetime 而非 `%H:%M` 往返 | 边界 ±1 分钟三点 |
| `S-P3-10` day-for-year 年长分裂 | `rectify_primary_motion.py:154` vs `progressions.py:51` 等 | 统一 365.2422（或统一 365.2425，**DECISION_REQUIRED**，默认 365.2422 与多数模块一致）；`rectify_evidence.py:364` 独立性组口径同步 | 60 岁差 <1 分钟 |
| `S-P3-11` 本地 ISO 字典序排序 | `modern_timing.py:1122,1138` | 排序键改解析后的 UTC datetime | DST 回拨小时内 pass_index 单调 |
| `R-P3` `parse_degree("10-2")` | `core.py:442` | `-` 进 AST 分支或明确拒绝 | `10-2` 语义写测试（度-分） |
| `R-P3` dec==0 归 contraparallel | `core.py:388` | 0 视为同侧/特殊，仅 parallel | 0/0 → parallel |
| `R-P3` 允许 GMT-14 | `core.py:156` | 下限 −12 | GMT-13 抛错 |
| `R-P3` naive datetime 按系统时区 | `core.py:227` | 拒绝 naive 或强制 UTC 并 warning | naive 输入行为确定 |
| `R-P3` retrograde station 窗口钳制 | `retrograde_cycles.py:82-83` | 采样 ±6h 用扩展搜索区而非用户窗 | 窗口边缘 station kind 稳定 |
| `R-P3` rectify 主方向弧 ±180 截断 | `rectify_primary_motion.py:53-57` | 用真实最短/长弧约定并在 diagnostics 披露 | 弧 >180 的 age 不偏小 |
| `R-P3` `direction_type=="converse_label"` | `rectify_primary_motion.py:249` | 改 `"converse"`（与 `rectify.py:131`、Swift `RectifyModels` 一致） | 枚举值白名单测试 |
| `R-P3` classical return `exact_utc` 分钟截断 | `classical.py:720` | 输出 ISO 秒精度（内部已是精确秒） | 显示与角度同源 |
| `R-P3` delta_t 异常静默 | `horary_v2.py:1723-1724` | warning + 显式 `delta_t_used:false` | 异常时可观察 |

### E-3 契约/静默失败类（P3-12～P3-17、P3-22～P3-24）

| 项 | 位置 | 修法 | 测试 |
|---|---|---|---|
| `S-P3-12` Hyleg place_pass 宫集 | `classical_audit.py:364` | angular={1,4,7,10} | 4 宫标 angular |
| `S-P3-13` syzygy 失败 0°白羊污染 almuten | `api.py:553-556` + `classical_audit.py:205-236` | 失败时 almuten 输出 `confidence:"low"` **且** `score_breakdown` 标注 `syzygy_unavailable` 并可选跳过该项计分 | 失败注入 → 不再产生完整五项尊贵分 |
| `S-P3-14` syzygy dignity_rulers 硬编码 | `classical_audit.py:151` | 接收请求 `bounds_system`/`triplicity_system` | 夜盘不报三分昼主 |
| `S-P3-15` ptolemaic 水象标签 | `classical_dignity.py:35,250-252` | `("MARS","MARS","")` 的 index 角色标签按 dual-sect 正确标注 | 标签与计分一致 |
| `S-P3-16` lots 整宫兜底锚 0°白羊 | `classical_lots.py:31-33` | 兜底锚定 ASC 所在星座 | cusps 缺失路径测试 |
| `S-P3-17` 恒星合相忽略黄纬 | `fixed_stars.py:130-135` | 输出加 `conjunction_type:"ecliptic_longitude_only"` 或用球面角距 | Vega 高黄纬不误报“真合” |
| `S-P3-22` rectify `replace(tzinfo)` 绕过 DST 校验 | `rectify.py:344` | 对齐 `rectify_evidence.py` 的 `_shift_birth_datetime` | DST gap 拒绝 / fold 双解拒绝 |
| `S-P3-23` 同包两套日出日落约定 | `horary_v2.py:747` vs `visibility.py:113,123` | 统一 rsmi 约定并披露 | 临沂样例两者差 <10s |
| `S-P3-24①` Seesaw 聚类均值未圆量归一 | `patterns.py:418-420` | 用 `circular_midpoint`/圆量均值 | 355°/5° → 0° 附近 |
| `S-P3-24②` paran 同型轴对 | `prenatal_parans.py:181-187,207` | 排除 rising/rising 等同型 | `full_paran` 需异型 |
| `S-P3-24③` MORNING_LAST/EVENING_LAST fallback 互换 | `visibility.py:37-40` | 改 4/2（pyswisseph 实际值） | 常量断言 |
| `S-P3-24④` `SCHEMA_VERSION + 1 if…` 恒 2 | `draconic_heliocentric.py:279` | 加括号或直接用 int | schema_version 期望值 |
| `S-P3-24⑤` moon_ingress 未选 MOON 静默空 | `modern_timing.py:1279` | 空结果写 warning | 可观察 |

**批次 E 验证**：全量 pytest + `test_contracts.py` + 受影响 fixture 再生 + 门禁。P3 批量提交时每 5–8 项一个 commit。

---

## 7. 批次 F — horary 与剩余 P3（语义/展示）

### F-1 `R-P3` Frustration 变体覆盖

- **位置**：`astro_backend_horary.py:1485-1491`。
- **DECISION_REQUIRED**：Lilly 主定义为“被接近者先完美”；“applying 行星转向第三方”变体是否纳入需产品定。默认**不新增变体**，仅在 `details`/`method_note` 注明当前采用 Lilly 主定义（避免发明规则）。

### F-2 `R-P3` Translation/Collection 用 `abs(speed)` 忽略逆行

- **位置**：`horary.py:1249-1253`、`:1323-1325`。
- **修法**：快慢比较改用**黄经进度速度**（带符号，顺行为正），仅当 translator 进度严格快于两者才成立；逆行 translator 不再被判“更快”。
- **测试**：逆行 fast-planet（带符号为负）→ 不构成 translation。

### F-3 `R-P3` Collection 排除条件不全

- **位置**：`horary.py:1345-1347`。
- **修法**：征象星间已有入相主相位时不上报 collection（与主相位竞争时以主相位为准）；现有“晚于主相位则排除”保留。
- **测试**：双征象已入相 → collection `not detected`。

### F-4 `R-P3` 事件 id 分钟级碰撞

- **位置**：`horary.py:456`（`%Y%m%d%H%M`）。
- **修法**：id 加秒（`%Y%m%d%H%M%S`）+ 角色后缀；**注意**：改 id 会动 golden/fixture——按 `horary-remaining-fixes` 的既有决策“事件 id 秒级精度（亚秒丢失）”已被列为**不修**，本项若修需产品确认（默认**不修**，仅在文档记录碰撞风险）。

### F-5 `R-P3` VOC 事件 id 不含 rule_id → 覆盖

- **位置**：`horary_v2.py:703-708`、`:1055-1078`。
- **修法**：物理事件去重保留，但 `voc_rule_id` 改为**数组**（同一边界被多规则命中时并列），或 id 含 rule_id 但 dedupe 改按 `(event_type, body_ids, exact)` 合并 rule 来源。推荐后者（事件不翻倍，归属不丢）。
- **测试**：两条规则 interval 相同时，边界事件的 rule 归属完整。
- **风险**：中——horary v2 schema 若 `voc_rule_id` 从 string 变 array，需同步 `docs/schemas/horary-data-packet-2.1.json` + `HoraryDataPacketModels.swift` + golden。

### F-6 `R-P3` rule B `sign_exit_truncation` 表述不一致

- **位置**：`horary_v2.py:1287` vs `:1246-1251`。
- **修法**：`definition.sign_exit_truncation` 与 interval 计算一致（rule B 本就不按 sign_exit 截断，则 `end` 不应写 sign_exit；改用 `window_end` 或 `null` + `end_note`）。
- **测试**：rule B interval 与 definition 自洽。

### F-7 `R-P3` 日出日落异常静默 / probes ±400 天截断

- **位置**：`horary_v2.py:746-751`、`:957-962`。
- **修法**：失败写 warning + `events` 内省标记；探针上限参数化并在 `meta` 披露 `event_search_limit_days`，超限截断时 warning。

### F-8 `R-P3` `assert_no_forbidden_fields` 黑名单不完备

- **位置**：`horary_v2.py:1625-1643`。
- **修法**：黑名单扩到已知判定词全集（`judgment`/`verdict`/`answer`/`score`/`confidence`/`strong`/`weak`/`bonification`/`maltreatment`/`key_` 前缀已有 + 补 `yes`/`no` 值域在非用户文本路径）；增加**白名单模式**测试（新字段必须显式登记才能通过防护）。
- **测试**：注入 `{"judgment":"x"}` 必被拦。

### F-9 `R-P3` 赤纬平行 application 固定 +6h 单点

- **位置**：`horary_v2_modules.py:895-905`。
- **修法**：对齐 aspects 的多点采样/根搜索（复用 `_station_or_retrograde_before_exact` 或 `_declination_root` 的一阶导），高速天体不再方向翻转。
- **测试**：月亮近根 ±6h vs 多点采样结论一致。

### F-10 `R-P3` phase_angle / `_build_receptions` 死代码 / morning_evening

- **位置**：`horary_v2.py:1406`、`:628`、`:1395`。
- **修法**：`phase_angle_deg` 有 pheno 时以 pheno 为准（现已覆盖则删球面近似分支或标注 fallback）；删除 `_build_receptions` 死代码；`morning_evening` 由黄经符号改为基于真实升落/visibility 约定（**DECISION_REQUIRED**，默认仅加 `morning_evening_definition` 已有披露，不改语义）。

### F-11 旧 P3 语义项（`S-P3-18` 六组 Yoga、`S-P3-19` 会合冲相标签、`S-P3-20` harmonic 下界、`S-P3-21` 180° 中点 tie-break、`R-P3` scan `orb_factor`、`R-P3` ZR L1 LoB / `_zr_walk` 死代码、`S-P3-4` parans 静默吞星）

| 项 | 修法要点 | 测试 |
|---|---|---|
| `S-P3-18` Yoga 六组定义 | 按 BPHS 逐条重写 Viparita（检宫主）、Dharma-Karmadhipati（9/10 宫主）、Dhana（涉宫主）、Sunapha/Anapha（补火土）；ArdhaChandra/Kedara 若非 Nabhasa 原义则改名/移出 Nabhasa 组 | 每组正反 case + 与经典对照表注释 |
| `S-P3-19` synodic 冲相标签翻转 | `relative_motion` 用带符号分离角变化率（unwrap ±180） | lon 179.9/0 + rel_speed=+1 → applying |
| `S-P3-20` harmonic_order 无下界 | API 校验 `1…100`（上限产品定），0/负结构化拒绝 | 非法值 error |
| `S-P3-21` 180° tie-break 随 A/B 翻转 | 复用 midpoints 的 point_id 排序先例 | `m(0,180)==m(180,0)` |
| `R-P3` scan `orb_factor` 恒 ≈1 | refine 后用真实 orb 重算 factor | 与精确度单调 |
| `R-P3` ZR L1 无 LoB / `_zr_walk` 死代码 | 删除 `_zr_walk`；L1 LoB 按 AGENTS 语义（仅真实跳转才标）补全或明确 `>211 年不可达` 注释 | 现有 `test_classical.py` LoB 三例不回归 |
| `S-P3-4` parans `except: continue` | 写 warning 并使用 `warnings` 形参 | 失败可观察 |

**批次 F 验证**：`test_horary*.py` 全量 + golden/schema 同步 + `test_classical.py` + 门禁。

---

## 8. 批次 G — 需产品/口径确认（未确认不得实现）

| 项 | 问题 | 建议默认 |
|---|---|---|
| G-1 | `PTOLEMAIC_BOUNDS` 版本（Aries Mars 28 vs Robbins 26；Gemini Lilly 变体等） | 选定版本 + 来源注释 + 补表测试；不与 Egyptian 修复混批 |
| G-2 | Shadbala：补齐子项 vs 显式降级 | 先降级披露（C-4），完整实现另立任务 |
| G-3 | primary_directions 是否补 converse 双向 | 补（C-1），若否则 method_note 明示单向 |
| G-4 | horary v2 per-planet moiety orb | 保持全局 orb（judgment-free 设计），不改 |
| G-5 | day-for-year 年长 365.2422 vs 365.2425 | 统一 365.2422 |
| G-6 | aux points/upagraha：完整 BPHS vs 降级标记 | 先降级标记（C-10） |
| G-7 | Frustration 变体、事件 id 秒级、morning_evening 语义 | 维持现状 + 文档披露（F-1/F-4/F-10） |
| G-8 | composite 宫位重建以 ASC 还是 MC 为权威 | ASC 对齐（B-1） |

---

## 9. 推荐执行顺序与 PR 切分

| PR | 内容 | 预估 |
|---|---|---|
| PR-1 | 批次 A（2 项 P1）+ 对应 fixture/测试 | 小 |
| PR-2 | 批次 B（B-1～B-9）局部小改 | 中 |
| PR-3 | 批次 C 几何/搜索（C-1/C-2/C-5/C-6/C-8/C-13） | 中 |
| PR-4 | 批次 C 契约/键名（C-3/C-7/C-11/C-12）+ D-1 | 中 |
| PR-5 | 批次 C 口径相关（C-4/C-9/C-10）——依赖 G 决策 | 中 |
| PR-6 | 批次 E-1/E-2（输入与时间边界） | 中 |
| PR-7 | 批次 E-3 + F-11（契约与语义） | 中 |
| PR-8 | 批次 F（horary 专项）+ schema/golden | 中 |
| PR-9 | 批次 D-2 常量表统一（数值不变）+ 收尾全量回归 | 小 |

每个 PR 合并前：`bash check_vibe_changes.sh` 全绿 + `git diff --stat` 无越界文件 + CHANGELOG/PLANS 对齐 commit 边界。

---

## 10. 影响面总表（改 JSON 形状必查）

| 后端字段族 | Swift 消费点 | 导出 | fixture |
|---|---|---|---|
| `bound`/`bound_ruler`/`score_breakdown`/`almuten_figuris`/`dignity_rulers` | `ClassicalCoreModels`/`ClassicalResultModels`/`ClassicalResultViews` | `MarkdownClassicalExportBuilder`/`TextExportBuilder` | `classical-*.json` |
| `*_local`（declination_timing） | `DeclinationTimingModels` | `DeclinationTimingExports` | `declination-timing-result.json` |
| composite `houses`/`angles` | `ModernResultModels`/`ModernResultViews` | `MarkdownModernExportBuilder` | `composite-result.json`/`progressed-composite-result.json` |
| `hayz` | `ClassicalCoreModels.hayz` | `MarkdownClassicalSections` | classical |
| `arc_deg`/`solar_arc_rate` | `MethodFamiliesModels`/`MethodFamiliesExports` | 同左 | `method-families-result.json` |
| `name_zh` | `VedicResultModels` | `MarkdownVedicExportBuilder` | `vedic-result.json` |
| patterns `aspect_types`/shapes | `ModernResultModels` | modern export | 含 patterns 的 fixture |
| horary `application`/`approaching_sun`/`declination_parallels`/`voc_rule_id` | `HoraryDataPacketModels`/`HoraryExtraViews` | `MarkdownHoraryExportBuilder` | `horary-result.json` + golden |
| mundane `planetary_day_ruler`/`candidate_count`/`electional_candidates` | `MundaneElectionalModels` | `MundaneElectionalExports` | `mundane-electional-result.json` |
| scan `phase`/`priority_score` | `TransitResultModels` | `TextExportBuilder` | `scan-result.json` |
| davison `method`/mid position | `ModernResultModels` | modern export | `davison-result.json` |
| hellenistic condition rows | `HellenisticAuditModels` | `HellenisticAuditExports` | `hellenistic-condition-audit-result.json` |
| yogini dasa | `VedicResultModels`/`VedicResultViews` | `MarkdownVedicExportBuilder` | `vedic-result.json` |
| `direction_type`/PD rows | `RectifyModels`/`PrimaryDirectionsAuditModels` | 对应 Exports | `primary-directions-audit-result.json` |

---

## 11. 验证门禁（每批收尾必跑）

```bash
# 1) Python 全量
python3 -m pytest python_tests/ -q

# 2) 后端冒烟（受影响 mode 至少各 1）
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json >/dev/null
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-horary-request.json >/dev/null
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-declination-timing-request.json >/dev/null
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-timing-composite-request.json >/dev/null
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-davison-request.json >/dev/null
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-hellenistic-condition-audit-request.json >/dev/null
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-mundane-electional-request.json >/dev/null
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-vedic-ai-request.json >/dev/null
# …其余受影响 mode 按 docs/validation.md 全列表

# 3) 契约 fixture 再生（仅故意的 schema/数值变化后）
#    python3 Sources/TransitStudio/Resources/backend/transit_calc.py \
#      < Examples/sample-<mode>-request.json > SwiftTests/Fixtures/<mode>-result.json

# 4) Swift
swift build
swift test
TRANSIT_LIVE_CONTRACTS=1 swift test --filter LiveBackendContractTests

# 5) 一键门禁
bash check_vibe_changes.sh
```

> `swift test` 可能需要用户缓存目录写权限（沙箱外跑）。涉及资源复制规则变动后：`rm -rf .build && swift build`。

---

## 12. 剩余风险登记（交付时逐条对照）

1. **口径未决**：G-1～G-8 未确认前，相关批次不得开工；Egyptian 界修复（A-1）不依赖 G-1（不同表）。
2. **数值漂移预期**：A-1、B-1、C-1、C-5、C-6、C-8、C-9、C-13 会让结果数值变化——这是修复本身，需在 CHANGELOG 明示“旧值为错误口径”。
3. **契约收紧**：B-3、C-3、C-12、E-1 会让原先静默接受的非法输入改为结构化错误——调用方（Swift UI 校验）需确认不会误伤正常路径。
4. **horary golden**：B-7/B-8/B-9/C-11/F-* 涉及 v2.1 包与 golden；必须同步 `docs/schemas/horary-data-packet-2.1.json`，并保持 `assert_no_forbidden_fields` 防护。
5. **禁止范围**：不改 Horary v2.1/KP/Rectifier 未列入任务的算法；不顺手重构；不编辑 `dist/`、`.build/`、`__pycache__/`、`backups/`。
6. **已知不可修/不修**：误报 4 项；`horary-remaining-fixes` 的“不修”表（事件 id 亚秒、GMTOffset 无 DST 等）继续有效。

---

## 13. 与既有文档的关系

| 文档 | 关系 |
|---|---|
| `backend-calculation-review-20260908.md` | 本文的 R-* 条目来源；保留为证据 |
| `backend-calculation-bug-scan-20260826.md` | 本文的 S-* 条目来源；关闭时在该文加“已修复于 PR-x”注记 |
| `current-status.md` | 本文是其“后续计算审计候选”的执行化展开 |
| `calculation-audit-repair-spec.md` | 已完成 13 项，不重跑 |
| `horary-remaining-fixes.md` | A–J 已完成；其“明确不修”表约束 F-4 等 |
| `validation.md` | 门禁与 fixture 再生流程以它为准 |
| `backend-contracts.md` | schema 形状变更时同步 |
