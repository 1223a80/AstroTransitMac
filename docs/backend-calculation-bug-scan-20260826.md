# 后端计算缺陷并行扫描报告（2026-08-26）

> 收尾状态（2026-09-06）：本文保留 2026-08-26 的原始审计证据与当时行号。P1-1（SAV 七曜汇总）已在本轮独立复现并修复；其余 35 个编号仍是后续复核/修复候选，未因本轮 JSON 解码通过而自动关闭。统一入口：current-status.md。

- 日期：2026-08-26
- 方式：7 路子代理按模块并行只读审计 + modern_timing.py 人工逐行补审；全部 P1/P2 经 `.venv/bin/python` 数值实验复现
- 范围：`Sources/TransitStudio/Resources/backend/` 全部 50 个 Python 模块（含 api 分发层）
- 基线：分支 `codex/fix-calculation-audit` 未提交工作区；本分支此前 13 项审计修复（2026-08-14/15）已复核成立，不在本报告重复列出
- 性质：纯只读扫描，未修改任何源码

严重度定义：

- **P1**：经典常数/主输出系统性错误，直接进入 UI 与导出
- **P2**：计算方向/结构错误或字段恒错，影响判断语义
- **P3**：边界条件、显示标签、契约健壮性、潜伏隐患

---

## 一、P1（1 项）

### P1-1 SAV 求和计入 ASC 行，总量 386 ≠ 经典 337

- **位置**：`astro_backend_jyotish_ashtakavarga.py:268-272`
- **现状逻辑**：`sarva_rekha/trikona/ekadhi` 按 `for j in range(8)` 累加，包含 index 7（ASC 的 BAV，各星座合计恒 49 bindus）；注释自称 "SAV = sum of BAV"。
- **应然逻辑**：经典 Sarvashtakavarga 只累加七曜（Sun…Saturn）的 BAV，总和恒为 **337**（BPHS Ashtakavarga 章公认常数；其声称参考的 Maitreya `Ashtakavarga.cpp::calcSarva()` 默认 `jmax=7`）。
- **影响**：12 个星座的 SAV 值被 ASC 行系统性抬高；消费方 `VedicAshtakavargaView.swift:9` 与 `MarkdownVedicExportBuilder.swift:342` 直接展示/导出该值。
- **最小验证**：任意 9 星位置调 `compute_ashtakavarga(pos, asc_lon)`，断言 `sum(sav["rekha"]) == 337`（当前失败）；改 `range(7)` 后通过。
- **修复注意**：修复后 `sav.rekha/trikona/ekadhi` 全部 12 个值口径变化（Swift schema 无需改动），需同步契约 fixture。

---

## 二、P2（11 项）

### P2-1 恒星黄道下 `build_houses_from_armc` 缺 SIDEREAL flag

- **位置**：`astro_backend_ephemeris.py:366-408`；连带 `armc_from_mc`（同文件 :411-422）在 `astro_backend_method_families.py:174` 被喂入恒星 MC 却按热带黄经反推赤经。
- **现状逻辑**：`swe.houses_armc(armc, lat, obl, code)` 不传 flags；姊妹函数 `build_houses`（:239-352）有 `sidereal` 参数并传 `FLG_SIDEREAL`。
- **应然逻辑**：恒星模式下 cusps/ASC/MC 应与全盘同一黄道参考系。
- **证据**：1990-01-01 12:00 Asia/Shanghai、Lahiri 实测：natal ASC(sidereal)=353.8953°；同一 ARMC 走 `build_houses_from_armc` 得 17.6160°(tropical)，减 ayanamsha 23.7174° 后=353.8986°——相差恰为一个完整 ayanamsha。
- **触发面**：method_families 的 `secondary_armc_naibod` 等 profile 在支持 `zodiac=sidereal_*` 时（:82-86），推进后宫头重建走无 flags 版本。
- **最小验证**：上述双调用断言；或对同一 birth 分别以 tropical/sidereal_lahiri 请求 method_families 推进 profile，比较宫位差是否恰为一个 ayanamsha。

### P2-2 Hellenistic audit 的 applying/separating 证据行结构上恒为 0 行

- **位置**：`astro_backend_hellenistic_audit.py:403-436`（数据源 `astro_backend_classical.py:486-494`）
- **现状逻辑**：双重失配——① aspects 行存的是中文名（`body_a="月亮"`），循环用英文 id（`"SUN"`）匹配 `bodies_pair`，永远 miss 后 `continue`；② 即便命中，`applying` 字段值为 `"入相"/"离相"`，而代码比较 `== "applying"` / `== "separating"` / `is True` / `is False`，两个分支都不追加。
- **应然逻辑**：用 body_id 匹配（aspects 行需补 id 或反查中文名），并按 `"入相"/"离相"` 值分支。
- **证据**：端到端跑 `Examples/sample-hellenistic-condition-audit-request.json` 输出 41 行条件，`condition_id=="applying_aspect"/"separating_aspect"` 两类恒为 0 行。
- **最小验证**：重放该样例并统计两类 condition 行数。

### P2-3 返照三元组把出生瞬间当作一次返照

- **位置**：`astro_backend_classical.py:666-667, 825-842`（搜索窗口 `astro_backend_classical_timing.py:735-736`）
- **现状逻辑**：搜索窗口以参考时刻对称展开（MOON ±35d、VENUS ±730d 等）。当参考时刻距出生不足半个窗口时，出生瞬间本身是 natal 经度的一次过零点，被收入 `exacts` 并按 `exact <= reference_dt` 归入 before，于是 `current_hit = previous_exact`＝出生时刻。
- **应然逻辑**：返照定义为生后完成一圈的回归：`search_return_exacts` 结果应过滤掉 ≤ 出生时刻（+ε）的过零点。MARS/JUPITER/SATURN 已有 age<3 补丁，MOON/VENUS/MERCURY 无守卫。
- **证据**：1990-01-01 12:00 UTC 生、1990-01-11 参考：`search_return_exacts(MOON, natal 333.2677°, ref±35d)` 返回 hits 首项 `1990-01-01T11:59:59.999947`（与出生差 0 秒）；全链路 classical 输出 `current_cycle_return.exact_local="1990-01-01 11:59", previous=None`——零长度"当前周期"。
- **最小验证**：上述新生儿请求跑 `calculate_classical`，检查 MOON 的 current_cycle_return。

### P2-4 Yogini Dasha 起算与余额规则整体错位

- **位置**：`astro_backend_jyotish.py:457-464`
- **现状逻辑**：首限主 `start_idx = (pada - 1) % 8`（只能以 Mangala/Pingala/Dhanya/Bhramari 起始，Siddha/Ulka/Sankata 永远不会成为首限主）；余额 = pada 内进度 × 首限年数。
- **应然逻辑**：主流规则（Tajika Neelakanthi 系）：首限 Yogini 由月亮 **Nakshatra 序号** 决定 `first = (nak_0based − 5) mod 8`（标准表 Mangala={6,14,22} 1-based，等差 8，与该式吻合）；余额 = 月亮在整段 nakshatra 内已行弧比例 × 首限年数。
- **证据**：Moon=27°/29°（Krittika）代码给出 Mangala；经典应为 Siddha（Krittika 属 Siddha 组 n≡2 mod 8）。
- **最小验证**：Moon 取 Krittika 三段中点各跑 `_calc_yogini_dasa`，对照标准表。

### P2-5 特殊上升点与时间型 Upagraha 为占位实现且随时区漂移

- **位置**：`astro_backend_jyotish_aux_points.py:156-220`（Hora/Ghati/Vighati/Pranapada/Sree/Indu/Bhava/Varnada/Kunda）、`:77-96`（Kaala/Mrityu/Artha Praharaka/Yama Ghantaka/Gulika/Maandi）
- **现状逻辑**：`hora_lagna = sun + (jd_ut % 1.0)×180`、`ghati_lagna = sun + (jd_ut % 1.0)×360` 等，全部用 **UTC 格林威治午夜小数日**代替「日出起经过的时间」；Vighati=asc+moon−sun、Sree=moon+asc、Indu=Moon、Varnada=ASC、Bhava Lagna=ASC 均为占位式恒等组合；Gulika/Maandi 等六点为 `asc + 常数` 类算式，与 BPHS 昼夜八分定义无关（Sun 系五点 Dhuma→Upaketu 链经代数验证正确）。
- **应然逻辑**：HL/GL/BL 自日出位置分别每 1h/24min/2h 推进一宫；Pranapada 依 BPHS 日出起算；时间型 Upagraha 由星期主星+日出日落八分段定义。
- **危害**：`(jd_ut % 1.0)` 使同一出生时刻在 UTC+8 与 UTC−5 下结果相差数个星座；代码注释自认 "Simplified"，但 payload/UI 无任何降级标记（对比 Shadbala 有 `is_complete:false`），D1/D9 图静默附带这些点。
- **最小验证**：同一 JD 分别以 timezone "Asia/Shanghai" 与 "UTC" 跑 `calc_special_lagnas`，HL/GL 结果不同即证。

### P2-6 horary v2 `approaching_sun` 方向判定反转

- **位置**：`astro_backend_horary_v2_modules.py:123`
- **现状逻辑**：`approaching_sun = abs(sep_signed) < abs(sep_signed_future)`，其中 future 用 `lon + speed` 外推——未来角距**变大**时输出 True。
- **应然逻辑**：行星趋近太阳 = 未来 |sep| 变小。现逻辑恰好颠倒：正在远离燃烧标 approaching=True、正在逼近标 False。
- **证据**：金星在太阳前 5° 且更快（远离中）→ True（错）；在后 5° 且更快（逼近中）→ False（错）。字段随 v2 包 `bodies[].accidental.approaching_sun` 出货，下游燃烧加剧/缓解判断面拿到反向事实。
- **最小验证**：构造 sun_lon=10、venus_lon=5、speed=1.6 调 `accidental_condition`，未来 sep=-3.4 在逼近但返回 False。

### P2-7 mundane_electional 行星日主/时主键名错配恒 null

- **位置**：`astro_backend_mundane_electional.py:227-228`
- **现状逻辑**：`ph.get("day_ruler") or ph.get("planetary_day_ruler")`、`(cur_hour or {}).get("ruler") or ph.get("hour_ruler")`——四个键均不存在。
- **应然逻辑**：`_planetary_hours()` 返回键为 `day_ruler_id`/`day_ruler_name`，小时行内为 `ruler_id`/`ruler_name`（同函数 :229 读 `start_local` 正确，佐证笔误）。
- **证据**：实测 `_planetary_hours(...)` 返回 keys 含 `day_ruler_id/day_ruler_name/ruler_id/ruler_name`，status=ok 时输出仍为 null。
- **最小验证**：任一 `mode=mundane_electional` 样例检查 `daily_fact_snapshots[*].planetary_day_ruler / planetary_hour_ruler` 恒 null。
- **修复注意**：下游若已有针对 null 的兼容分支须一并清理，避免新旧语义并存。

### P2-8 scan 相位 applying/separating 由采样端点决定而非相对速度

- **位置**：`astro_backend_scan.py:540`
- **现状逻辑**：`phase = "applying" if abs(f_prev) > abs(f_next) else "separating"`，f_prev/f_next 是包含 exact hit 的那个采样步长两端点的带符号 orb——幅度取决于 crossing 落在步长区间内的位置。
- **应然逻辑**：应由行运星相对目标点的角速度符号在命中时刻附近决定；至少不应随窗口起点平移而翻转。
- **证据**：Moon 合 T 点 2026-03-10 实测：窗口 00:00 起 → `separating`；仅把起点平移至 00:20 → 同一事件变 `applying`。该字段经 `TextExportBuilder.swift:89` 直接进导出表格。
- **最小验证**：两次 scan_window 调用（改 start 分钟 0→20），比对同一命中行的 phase。

### P2-9 patterns Kite 的 aspect_types 恒为三个 opposition

- **位置**：`astro_backend_patterns.py:236-239`
- **现状逻辑**：`"opposition" if angular_separation(a, b) <= 180 + ORB else "sextile"`——`angular_separation` 值域 [0,180]，条件恒真。
- **应然逻辑**：标准风筝 = 大三角 3 星中 1 颗被 apex 对冲、另 2 颗成六合，应为 1×opposition + 2×sextile。
- **证据**：教科书风筝（0°/120°/240° + apex 180°）实测输出 `['opposition','opposition','opposition']`；字段被 `ModernResultModels.swift:174` 解码消费。
- **最小验证**：构造四点经度调 `find_patterns` 查 kite 条目。

### P2-10 patterns 图形按 type 去重丢弃多实例

- **位置**：`astro_backend_patterns.py:310-316`
- **现状逻辑**：`sig = s["type"]; if sig not in shape_seen` —— 每个 shape 类型最多保留 1 条。
- **应然逻辑**：下层 `find_chart_shapes` 本身按 `(type, members)` 去重（:489-495），可返回多个不同成员实例；上层应全量透传。
- **证据**：8 星双摇篮构造图实测：`find_chart_shapes` 返回 2 个 cradle，`find_patterns` 只剩第 1 组。
- **最小验证**：同一构造经两函数分别计数 cradle 条目。

### P2-11 Davison 空间中点用等距圆柱平均而非大圆中点

- **位置**：`astro_backend_davison.py:87-88`
- **现状逻辑**：`mid_lat = (a_lat+b_lat)/2`、`mid_lon` 取经度短弧平均；meta 标注 `"method": "davison_midtime_midspace"` 未披露该近似。
- **应然逻辑**：Davison 法规范做法是两地的大圆（球面向量）中点。
- **证据**：伦敦(51.51N)/纽约(40.71N)：算术中点 (46.110, −37.067) vs 大圆中点 (52.368, −41.290)，Δlat=−6.26°、Δlon=+4.22°；同一中间时刻 `build_houses` 实测当前实现 ASC=59.95°/MC=303.06°，大圆中点 ASC=62.48°/MC=299.00°——ASC 偏 2.5°、MC 偏 4.1°（RAMC=GMST+经度，经度误差直通 MC）。composite 模块同款近似因有 `mc_delta` 旋转校正部分抵消，Davison 无任何校正。高纬/跨半球配对系统性失真且静默产出。
- **最小验证**：向量平均（`asin(z/r)`、`atan2(y,x)`）对比算术平均，再各调一次 `build_houses(mid_jd,…)` 比 ASC/MC。

---

## 三、P3（24 项）

### 契约 / 静默失败类

| # | 位置 | 问题摘要 |
|---|---|---|
| P3-1 | `astro_backend_api.py:973-985` | classical 模式缺 `birth.moment` 字段校验，绕过 `{"error","missing"}` 结构化契约直崩（实测报非结构化 `未知时区：None`） |
| P3-2 | `astro_backend_ephemeris.py:64-66` | `resolve_bodies` 静默丢弃未知 body_id 且不写 warnings（legacy `natalBodies` 路径行星无声缺失） |
| P3-3 | `astro_backend_location_service.py:206` | manual 坐标默认 `"UTC"` 时区，relocation 静默覆盖显示时区（relocation.py:253 合并链） |
| P3-4 | `astro_backend_prenatal_parans.py:243-249` | legacy RA proxy `except Exception: continue` 静默吞星，签名里的 `warnings` 形参未使用 |
| P3-5 | `astro_backend_modern_return.py:397-400` | `previous_return` 缺失不告警（next/current 有告警）；搜索窗口硬编码且 modern 无参数可扩 |

### 边界 / 精度类

| # | 位置 | 问题摘要 |
|---|---|---|
| P3-6 | `astro_backend_core.py:340-343` + `astro_backend_ephemeris.py:181` | OOB 判定阈值用平黄赤交角多项式，dec 却是真分点坐标，边界带 ±9.2″ 内可翻转（真值 `obliquity_deg` 已存在未用） |
| P3-7 | `astro_backend_jyotish.py:501` | Ashtottari 28 宿修正表 Shravana 上限 293.6667° 应为 293.3333°（293°20′），现区间内 portion 回跳非单调 |
| P3-8 | `astro_backend_scan.py:442-443` | 年份钳制 `.replace(year=1800/2100)` 对 2 月 29 日抛 ValueError，合法闰日窗口被笼统拒 |
| P3-9 | `astro_backend_jyotish.py:343-349,400-423` | MD/AD 边界经 `%H:%M` 格式化往返截断秒级，current_mahadasa 判定有 ±1 分钟误差窗（附注：无 Pratyantar 层属功能缺口） |
| P3-10 | `astro_backend_rectify_primary_motion.py:154` ↔ `astro_backend_progressions.py:51` 等 | day-for-year 年长分裂：rectify 用 365.2425，progressions/solar_arc/modern_timing/midpoints/progressed_composite/method_families 统一 365.2422；两者在 rectify_evidence.py:364 归入同一独立性组，60 岁差约 26 分钟 |
| P3-11 | `astro_backend_modern_timing.py:1122,1138` | 事件组排序与最终排序用本地 ISO 字符串字典序，DST 回拨重复小时内顺序可倒置（pass_index 编号边缘错序；dedupe 比较本身解析回 datetime 不受影响） |

### 语义 / 展示类

| # | 位置 | 问题摘要 |
|---|---|---|
| P3-12 | `astro_backend_classical_audit.py:364` | Hyleg 候选 place_pass 宫集写错：angular={1,10,7,9} 应为 {1,4,7,10}（4 宫落 cadent 分支）；仅展示字段，资格判定用独立集合不受影响 |
| P3-13 | `astro_backend_api.py:553-556` + `astro_backend_classical_audit.py:205-236` | syzygy 计算失败兜底 `{"longitude":0.0}` 后 Almuten Figuris 照常给 0°白羊计五项尊贵分，可能改变 winner（有 confidence="low" 标记但分数已污染）；fortune/spirit 缺失同样兜底 0.0 |
| P3-14 | `astro_backend_classical_audit.py:151` | Prenatal Syzygy dignity_rulers 硬编码 `(True,"egyptian","dorothean")`，夜盘也报三分昼主，不接收请求配置 |
| P3-15 | `astro_backend_classical_dignity.py:35,250-252` | ptolemaic 水象 `("MARS","MARS","")` 使 index 恒 0，夜间火星标"三分 昼主"（+3 计分在 dual-sect 读法下无误，仅角色标签错） |
| P3-16 | `astro_backend_classical_lots.py:31-33` | 整宫宫头兜底 `(h-1)*30` 锚定 0°白羊而非 ASC 所在星座（仅 cusps/mc 缺失兜底路径触发，潜伏） |
| P3-17 | `astro_backend_fixed_stars.py:130-135` | 恒星合相只比黄经忽略黄纬（Vega 黄纬 +61° 可与黄经相同行星报"合"），至少应标注为黄经合相 |
| P3-18 | `astro_backend_jyotish_yoga.py:144-359` | 六组 Yoga 定义与经典不符：Viparita 检"坐落"6/8/12 应检"宫主"；Dharma-Karmadhipati 任一吉星入 Kendra 即触发（几乎必真）应检 9/10 宫主关联；Dhana 两式未涉宫主权；ArdhaChandra/Kedara 非 Nabhasa 原义；Sunapha/Anapha 仅检 {Jup,Ven,Mer} 漏火土等（假阴性） |
| P3-19 | `astro_backend_planetary_synodic.py:88` | relative_motion 标签在冲相附近翻转：sep 从 +179.9 跳 −179.9 时几何上仍逼近却被判 separating（事件时刻/orb 不受影响） |
| P3-20 | `astro_backend_harmonic.py:69` | harmonic_order 无下界校验，0/负数静默接受（-3 出镜像图，0 折叠全 0） |
| P3-21 | `astro_backend_composite.py:102-105`（同 progressed_composite.py:106） | 对置 180° 时 `circular_midpoint` tie-break 随 A/B 序翻转（core.py:293-294 实测 m(0,180)=90 vs m(180,0)=270）；需 1e-9° 精确对置才触发，理论性；midpoints 模块已有按 point_id 排序先例可复用 |
| P3-22 | `astro_backend_rectify.py:344` | center_dt 用裸 `replace(tzinfo=tz)` 绕过全库 DST gap/fold 校验（core.py:206-222）；缺口时间静默接受，±window 扫描跨 DST 候选点撕裂 ±1h；evidence 模块 `_shift_birth_datetime` 是正确做法可对齐 |
| P3-23 | `astro_backend_horary_v2.py:747` ↔ `astro_backend_visibility.py:113,123` | 同一 v2 包内两套日出/日落约定（rsmi/atpress/attemp 不同），planetary_day_hour 与 events 日出日落相差 1–2 分钟（临沂实测 −1.7min） |
| P3-24 | `astro_backend_patterns.py:418-420`；`prenatal_parans.py:181-187,207`；`visibility.py:37-40`；`draconic_heliocentric.py:279`；`modern_timing.py:1279` | 五条小项：① Seesaw 聚类均值未圆量归一，355°/5° 均值成 180° 致漏检误检；② paran 配对不排除同型轴对（rising/rising 也标 full_paran）；③ MORNING_LAST/EVENING_LAST 回退字面量互换（pyswisseph 实际 4/2，当前 getattr 命中故潜伏）；④ `SCHEMA_VERSION + 1 if isinstance(...) else ...` 优先级 bug 恒报 2；⑤ moon_ingress 开启但未选 MOON 时静默空结果无警告 |

---

## 四、已验证干净的重点面（无需返工）

| 领域 | 结论 |
|---|---|
| 时间/坐标核心 | JD↔datetime（微秒/proleptic Gregorian）、DST spring-forward/fold 双解拒绝、GMT± 符号、format_longitude 进位链、signed_orb/angular_separation/circular_midpoint、星座索引边界——实测通过 |
| 寻根机制 | `search_return_exacts` unwrap+20° 护栏、`refine_crossing` 50 轮二分、`_find_roots` ±180 包裹过滤 + 80 轮二分 + 0.05s/1e-10 容差、`_lifecycle_bounds` 内外括号——月亮回归 5 次 exact 误差 <1e-8°，水星逆行期三次穿越全找到 |
| KP | 1–249 表 243 段+6 处跨座拆分无缝全覆盖、Sub 弧长 Fraction 精确、weekday lord、ASC 反解 golden-section、RP 七源 |
| 吠陀核心 | 分盘 D1–D60 全表逐式对照 Parasara（含整除边界 clamp）、Vimshottari 起算/余额/AD 链、BAV 点位表七曜总数 48/49/39/54/56/52/39、Trikona/Ekadhipatya 规则矩阵、Shadbala 各分项对照 Maitreya、Panchanga 四要素索引边界 |
| 古典技术 | ZR L1/L2 步进+LoB 跳宫+半开区间、Firdaria 昼夜序列、Decennials 129 月连续、Egyptian 界表逐界对照 Valens、Chaldean face、Hermetic Lots 主公式及依赖链、is_day 真地平几何、入相/离相 signed-orb×速度判据 |
| 关系盘/地图 | midpoints 全程短弧+轴序对称、ACG λ_MC=RA−GMST/ASC-DSC 曲线根 |alt|≤0.05°、Local Space 方位角与 Meeus 全零偏差、relocation 行星共享+宫位重算、progressed_composite 双人同基准 |
| 卜卦/方向 | 行星时迦勒底链+极区降级、refranation 双方 sign-exit、next_exact 真实星历步进+二分（非直线外推）、Moon VOC 双规则区间、antiscia 镜像公式、PD RA/OA/OD 几何与绕极守卫、circumambulation norm360 连续无缝、矫正 61 点网格换算链 |
| 现代动态 | retrograde_cycles 站留二分+阴影配对、solar arc 方向与 naibod 常数、declination timing 真黄赤交角、orbital dial mod 45/90、cycles `_utc_from_jd` 微秒进位修复（305 个随机 JD 往返误差 0.0s）、synodic min 步长修复 |
| 本分支近期修复 | heliacal previous 回溯、chart shapes span=360−max_gap 三项、Alcocoden rank=None、Arudha H+9/H+3、D30 偶座分段、CK 名称表、Yogakaraka 映射、Nathonatha LMT——全部复核成立 |

---

## 五、修复优先级建议

1. **第一批（P1 + 高危 P2）**：P1-1 SAV、P2-2 hellenistic 证据行恒空、P2-3 出生瞬间当返照、P2-6 approaching_sun 反转、P2-7 键名错配、P2-9/P2-10 patterns 两项——均为局部小改，回归测试易写。
2. **第二批（语义级 P2）**：P2-4 Yogini、P2-5 aux points/upagraha（需先决策：实现完整 BPHS 版还是显式降级标记）、P2-8 scan phase、P2-11 Davison 大圆中点、P2-1 恒星宫位 flag。
3. **第三批（P3）**：按契约→精度→展示顺序清理；P3-10 day-for-year 常量统一建议随第一批顺手处理（一处常量改动）。

每批遵循 AGENTS.md 全链路要求：Python 回归测试 + 受影响 Swift 模型/导出核对 + 契约 fixture 再生 + Examples 冒烟。
