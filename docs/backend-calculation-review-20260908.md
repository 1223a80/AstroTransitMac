# 后端计算代码整体审查报告（2026-09-08）

- 范围：`Sources/TransitStudio/Resources/backend/` 全部 61 个 Python 模块（约 31.7k 行）
- 方式：12 组只读子代理按模块并行深读（core/classical×2/modern×2/vedic/horary×2/rectify-scan/techniques/api/跨模块一致性）+ 主会话用 pyswisseph 独立数值对拍 + 权威资料（Tetrabiblos I.21/I.22、Valens、astro.com、pyswisseph 运行时常量）核对
- 基线：`python3 -m pytest python_tests/ -q` → **1091 passed**；本报告只读，未修改任何业务代码
- 对照：`docs/backend-calculation-bug-scan-20260826.md`（36 项旧编号，除 P1-1 外均未修复）；本报告只详列**新发现**，旧项以“复核仍未修复”清单收口

---

## 一、新发现

### P1（2 项）

#### P1-1 埃及界 Aries 使用了托勒密数值

- 位置：`astro_backend_classical_dignity.py:57`
- 现状：`EGYPTIAN_BOUNDS[0] = [("JUPITER",6),("VENUS",14),("MERCURY",21),("MARS",26),("SATURN",30)]`
- 应然（Tetrabiblos I.21 “埃及界”、Valens、Paulus、astro.com）：Aries = Jup 0–6 / Ven 6–12 / Mer 12–20 / Mar 20–25 / Sat 25–30
- 影响：Aries **12–14°、20–21°、25–26°** 三个区间的界主判定错误，波及所有 Egyptian 口径输出：`planets[].bound/bound_ruler`、`score_breakdown`、`almuten_figuris`、`circumambulations`、`prenatal_syzygy.dignity_rulers` 等
- 复现：
  ```bash
  python3 -c "from astro_backend_classical_dignity import bounds_ruler as b; \
  print(b(13,'egyptian'), b(20.5,'egyptian'), b(25.5,'egyptian'))"
  # 现输出 VENUS MERCURY MARS；应为 MERCURY MARS SATURN
  ```
- 测试固化：`python_tests/test_classical.py:100-105` 的断言（20°→MERCURY、25°→MARS）基于错误表，修表时须同步
- 备注：本次以脚本对照 Tetrabiblos I.21 全 12 星座，**仅 Aries 不匹配**（其余 11 星座逐界一致）；旧扫描文档第四节把“Egyptian 界表逐界对照 Valens”整体列为已验证干净，该结论对 Aries 不成立。`EGYPTIAN_BOUNDS` 的注释（`:54`）自称 “Ptolemy's table of the Egyptians”，但值抄成了托勒密自己的界

#### P1-2 declination_timing 固定偏移时区被静默改成 UTC

- 位置：`astro_backend_declination_timing.py:199-205`（`_display_zone`）
- 现状：`display_timezone="GMT+8"`（Swift `GMTOffset` 标签）时，`resolve_timezone` 返回 `datetime.timezone` 而非 `ZoneInfo`，函数无条件 `return ZoneInfo("UTC")`，导致响应里所有 `*_local` 字段显示 UTC 时刻（与用户所在时区差 8 小时）
- 应然：与其余模块一致（`modern_timing.py:1164`、`planetary_synodic.py:291-293`、`retrograde_cycles.py:237-239`、`visibility.py:531-533`、`mundane_electional.py:46`、`rectify.py:289-303` 均为 try `ZoneInfo` / except `resolve_timezone`）
- 复现：
  ```bash
  python3 -c "from astro_backend_declination_timing import _display_zone; print(_display_zone('GMT+8'))"
  # 现输出 UTC（utcoffset 0:00:00）
  ```

### P2（新发现）

| # | 位置 | 问题 | 复现要点 |
|---|---|---|---|
| P2-a | `astro_backend_composite.py:117-133` | 非等宫制下 composite 的 ASC 轴与第 1 宫头不一致：`comp_asc=circular_midpoint(a_asc,b_asc)`，但宫头取均值盘 `raw_cusps` 整体平移，`comp_cusps[0] ≠ comp_asc` | `house_system="placidus"` 请求实测 `angles.ASC=70.2976`、`houses[0].cusp_longitude=51.4655`（差 18.8°），ASC 定宫错误且两字段自相矛盾 |
| P2-b | `astro_backend_classical_dignity.py:460-461` | Mercury 的 Hayz 判定失效：`in_sect = sect.startswith("合")`，但 `sect_status` 对 Mercury 返回 `"随昼"`/`"随夜"`，Mercury 与盘 sect 一致时 `in_sect` 恒 False | 昼盘、太阳 20°白羊、Mercury 10°白羊（随昼）、house 10、阳星座 → 应 Hayz，实得 `''`（对照 Jupiter 同几何得 Hayz）；反向 case 误判为 Hayz |
| P2-c | `astro_backend_primary_directions.py:104` | 非合相相位只取 `sig_lon + angle` 单分支，square/sextile/trine 的 converse 方向（`sig_lon − angle`）不生成行，约一半 PD 方向缺失（`method_note` 未说明） | `grep -n "target_lon = norm360(sig_lon" astro_backend_primary_directions.py`（仅一处） |
| P2-d | `astro_backend_orbital_dial.py:80/97` | 行星图判定忽略 modulus：mid 已 `% modulus` 折叠，但 C 的判据用整圈距离 `abs(((c-mid+180)%360)-180)`，modulus=45/90 时同盘位（相差 k×modulus）被误报 45°/90° | `mid=10, c=55, modulus=45`：整圈距离 45.0（漏报），模距 0.0（同盘位） |
| P2-e | `astro_backend_jyotish_data.py:29`（与 `:34`） | Krittika 中文名错误且与 Pushya 重复，均为“鬼宿”；Krittika 应为“昴宿”（Pleiades），且与表内其余梵语音译风格不一致 | `grep -n '"name_zh"' astro_backend_jyotish_data.py` 前 10 行 |
| P2-f | `astro_backend_jyotish_shadbala.py:202`（Drik 恒 0 见 `:220`） | Jupiter 的 Kala Bala 额外 `+15.0` 无经典依据；Drik Bala 写死 0；Sthana 仅取 Uchcha。模块已标 `is_complete: False`，但 `shadbala_total/percent` 仍输出，易被误读为完整值 | `kb = nth_val + paksha_val + 15.0 if pid in ["JUPITER"] else ...` |
| P2-g | `astro_backend_method_families.py:115` | `solar_arc_rate_deg_per_year=0` 被 `or 1.0` 吞成 1.0，`solar_arc_custom_key.arc_deg` 变成 age_years（36.34），API 对该字段也无校验 | 请求置 0 → `arc_deg=36.340269553` |
| P2-h | `astro_backend_method_families.py:138` | `include_experimental_profiles` 用 `bool()` 强转，JSON 字符串 `"false"` 非空 → True，实验 profile 仍启用；API 无类型校验 | — |
| P2-i | `astro_backend_horary_v2_aspects.py:165-166`、`:110-115` | 速度字段缺失或恰为 0 时 `or 0.0` → `rel=0` 落入 `abs(rel)<1e-12` 分支，**无条件判 separating** 而非 unknown | 速度获取失败的 body 会把真实入相标成离相 |
| P2-j | `astro_backend_horary_v2_aspects.py:51` | station/逆行采样过稀：`steps = max(2, min(12, int(span/86400)+2))`，30 天窗口仅 12 点（≈2.5 天/点），水星/金星停滞期可被跳过，污染 refranation 证据 | — |
| P2-k | `astro_backend_mundane_electional.py:169-182` | `nearest_aspects` 无 orb 阈值，最近主相位 orb 可达 30° 仍输出为 `aspect/orb`，且 `applying/separating/exact_time` 恒 None | — |
| P2-l | `astro_backend_mundane_electional.py:258/286` | 顶层 `electional_candidates` 与 `meta.candidate_count` 自相矛盾（count=0 但数组非空） | — |
| P2-m | `astro_backend_core.py`（BODY_REGISTRY）vs `astro_backend_constants.py`（LABELS） | 同一天体两套中文名：PHOLUS “人龙星”/“Pholus”、MEAN_NODE “北交点 平”/“北交点”、MEAN_LILITH “Lilith 平”/“黑月（均）”；`planet_name()` 与 UI/导出取不同表 | — |
| P2-n | 跨模块 | 相位角表/orb 表/静止阈值不统一：`quincunx` 仅 scan（权重 0.7）与 patterns（orb 3°）认；合相 orb 1°（cycles/draconic）～8°（classical_audit）；静止判定 ±1e-9 / ±1e-6 / `<0` 三种口径 | `grep -rn "quincunx\|1e-9\|1e-6" backend/*.py` |

### P3（新发现，精选）

| 位置 | 问题 |
|---|---|
| `astro_backend_primary_directions.py:56-64` | 极区半弧 `asin` 域外异常被 `except` 吞掉返回 `ad=0.0` 且无 warning，OA/OD 静默退化为纯赤经差 |
| `astro_backend_pd_audit.py:55` | `direction_class` 读取不存在的 `type/kind` 键，恒为 `"zodiacal_proxy"` |
| `astro_backend_modern_timing.py:387,408` | 推运/太阳弧评估器 `value.speed / 365.2422` 量纲错误（推运点对“年”的导数即日速度）；仅用于符号判断，未入输出 |
| `astro_backend_solar_arc.py:129-137` | `arc_value` 在 `true_sun`（归约 0–360）与 `naibod_mean`/`custom`（不归约）下量纲不一致 |
| `astro_backend_modern_return.py:407-419` | current 聚合窗口硬编码 400 天；对 MOON 会把整年多轮回归并入 current 的 pass |
| `astro_backend_core.py:442` | `parse_degree("10-2")` 被当度分秒解析为 9.9667（`-` 未进 AST 分支） |
| `astro_backend_core.py:388` | 赤纬恰为 0 时归入 contraparallel |
| `astro_backend_core.py:156` | 允许 `GMT-14`（UTC 偏移法定下限为 −12） |
| `astro_backend_core.py:227` | `jd_from_datetime` 对 naive datetime 静默按系统时区解释 |
| `astro_backend_patterns.py:62` | `_find_stelliums` 冲突判据 `r.get("stellium_house")==h` 恒假（星座 stellium 该字段恒 None） |
| `astro_backend_api.py:1771-1816` | mundane 的 `display_timezone`/`location.timezone` 必填未进 `validate_required_fields`，下游 raise 经 `fail()` 变成非结构化 stderr 错误 |
| `astro_backend_retrograde_cycles.py:82-83` | station 分类用用户窗口（而非扩展搜索区）钳制 ±6h 采样点，窗口边缘 station 的 kind 可能翻转 |
| `astro_backend_rectify_primary_motion.py:53-57` | 主方向弧取最短弧（±180° 截断），真实弧 >180° 时年龄偏小 |
| `astro_backend_rectify_primary_motion.py:249` | `direction_type` 产出非标准值 `"converse_label"`，`rectify.py:131` 与 Swift 端只认 `"converse"` |
| `astro_backend_scan.py:539-541` | refine 后 `orb_factor` 恒 ≈1，`priority_score` 与离精确度无关 |
| `astro_backend_classical_timing.py:578`、`:382` | ZR L1 序列无 LoB 跳转（现实/算术不可达，>211 年才暴露）；`_zr_walk` 为死代码 |
| `astro_backend_horary_v2.py:1406`、`:628`、`:1395` | `phase_angle_deg` 用球面分离（pheno 可用时被覆盖）；`_build_receptions` 死代码；`morning_evening` 仅按黄经符号 |
| `astro_backend_classical.py:720` | return 的 `exact_utc` 用 `strftime("%Y-%m-%d %H:%M")` 截断到分钟，而 return chart 角度用精确秒计算（实测 ASC 差 0.0012°）；显示与内部精度不一致 |

### 补审补充：horary 全量覆盖（2026-09-08 追加）

首轮 `horary.py` 只精读 1–1000 行、`horary_v2.py`/`horary_v2_modules.py` 有函数级缺口；本轮补齐：

| 文件 | 补审覆盖 |
|---|---|
| `astro_backend_horary.py` | 全文 1650 行；新增精读 `_detect_translation`(1210)、`_detect_collection`(1293)、`_detect_prohibition`(1372)、`_detect_frustration`(1439)、`advanced_candidates`(1513)、`calculate_horary`(1556)、`negative_receptions`(1102) 等 |
| `astro_backend_horary_v2.py` | `calculate_horary_v2`(1661–2160)、`_voc_interval`(1184–1328)、`_motion_state`(294)、`_full_body_calc`(446)、`_rule_flag`(324)、`_next_sun_rise_or_set`(736)、`_event_row`(690)、`assert_no_forbidden_fields`(1625)、`format_horary_v2_markdown`(2166) 等 |
| `astro_backend_horary_v2_modules.py` | `considerations_evidence`(720)、`declination_parallels`(877)、`_declination_at`/`_declination_root`(806–874)、`_snapshot_body_at`/`_earliest_next_exact`(211–275) 等 |

**补审新增发现**

- **[P2] Frustration 第三方速度约束与经典规则不符，导致漏报** —— `astro_backend_horary.py:1483`
  `if abs(third.speed) > slower_speed: continue` 要求第三方不快于较慢征象星；Lilly 的 Frustration 只要求"被接近的慢行星在快行星到达前先与第三方完美"，对第三方速度无约束。第三方更快（如 Venus 追上 Saturn）时同样构成受挫，却被直接跳过。现有 `test_horary.py:716` 恰好用更慢的第三方，无法暴露。
- **[P2] `declination_parallels` 未校验同半球，0 赤纬附近双判/异号误判** —— `astro_backend_horary_v2_modules.py:906-947`
  `d_par=|da−db|`、`d_contra=|da+db|` 只与 orb 比较，无符号检查。实测 `da=+0.4, db=−0.3`（异半球）时 parallel 与 contra_parallel **同时** `within_orb=True`；同半球 `+0.4/+0.3` 也双判。正确规则：parallel 要求同号且 `|da−db|≤orb`，contra 要求异号且 `|da+db|≤orb`，二者互斥。复现：`python3 /tmp/astro_review/verify6.py`（脚本不入库）。

**补审 P3**

| 位置 | 问题 |
|---|---|
| `astro_backend_horary.py:1485-1491` | Frustration 未覆盖"applying 行星转向第三方"变体（Lilly 主定义为被接近者先完美） |
| `astro_backend_horary.py:1249-1253`、`:1323-1325` | Translation/Collection 用 `abs(speed)` 比较快慢，忽略逆行方向 |
| `astro_backend_horary.py:1345-1347` | Collection 仅在 collection 晚于主相位时排除；征象星间本已有入相主相位时仍可能上报 |
| `astro_backend_horary.py:456` | `make_aspect_event` 事件 ID 只到分钟（`%Y%m%d%H%M`），同分钟多事件可碰撞 |
| `astro_backend_horary_v2.py:703-708`、`:1055-1078` | VOC 事件 id 不含 `rule_id`；两条规则 interval 相同时后写覆盖前写，`voc_rule_id` 归属丢失（物理事件去重的副作用） |
| `astro_backend_horary_v2.py:1287` vs `:1246-1251` | rule B `definition.sign_exit_truncation: False` 与其 interval 仍以 sign_exit 为 end 表述不一致 |
| `astro_backend_horary_v2.py:1723-1724` | `delta_t` 异常时 `jd_tt` 静默等于 `jd_ut` |
| `astro_backend_horary_v2.py:746-751`、`:957-962` | 日出日落异常静默返回 None 不告警；probes 日范围硬截断 ±400 天，窗口内事件可被静默丢弃 |
| `astro_backend_horary_v2.py:1625-1643` | `assert_no_forbidden_fields` 为黑名单，未列出的判定字段可穿过 judgment-free 防护 |
| `astro_backend_horary_v2_modules.py:895-905` | 赤纬平行 application 用固定 +6h 单点采样，月亮等高速天体在根附近可能方向翻转 |

**补审仲裁**：`lot_ruler_condition`（`horary.py:1043-1048`）以中文名匹配 `lot["ruler"]` 曾被疑为恒空——实测 classical 输出的 `lot["ruler"]` 即中文名（如"水星"），匹配正确，**非 bug**。

---

## 二、2026-08-26 旧扫描文档中仍未修复、且本次独立复现/代码确认的项

| 旧编号 | 本次状态 |
|---|---|
| P2-2 hellenistic audit 的 applying/separating 证据行恒 0 行 | **复现**：`Examples/sample-hellenistic-condition-audit-request.json` 输出 41 行条件，无 `applying_aspect`/`separating_aspect` |
| P2-4 Yogini Dasha 起算错位 | **复现**：`_calc_yogini_dasa` 起始只能取 Mangala/Pingala/Dhanya/Bhramari 四种（`start_idx=(pada-1)%8`），标准应由 nakshatra 决定、可覆盖 8 种 |
| P2-6 horary v2 `approaching_sun` 方向反转 | **代码确认**：`modules.py:123` 用未来角距“变大”判 approaching |
| P2-8 scan 相位 applying/separating 由采样端点决定 | **代码确认**：`scan.py:540` |
| P2-9 patterns Kite 的 `aspect_types` 恒 opposition | **复现**：`['opposition','opposition','opposition']` |
| P2-11 Davison 空间中点纬度算术平均 | **代码确认**：`davison.py:87` |
| P3-6 OOB 阈值用平均交角 | 代码确认 |
| P3-14 syzygy 尊贵参数硬编码 | 代码确认（`classical_audit.py:151`） |
| P3-18 六组 Yoga 定义与经典不符 | 代码确认 |
| P3-19 planetary_synodic 冲相标签翻转 | **复现**：`lon_a=179.9, lon_b=0, rel_speed=+1` → separating（几何上应 applying） |
| P3-24③ visibility fallback 字面量互换 | **复现**：`swe.MORNING_LAST=4`/`EVENING_LAST=2`，代码 fallback 写反（当前 `getattr` 命中真实常量，潜伏） |

其余旧项（P2-1/P2-3/P2-5/P2-7/P2-10、P3-1～P3-5、P3-7～P3-13、P3-15～P3-17、P3-20～P3-23、P3-24①②④⑤）本次未逐一复现，按旧文档状态视为“未修复候选”。

---

## 三、已仲裁为误报的项

| 疑似问题 | 仲裁结论 |
|---|---|
| `armc_from_mc` 忽略 MC 黄纬（core 组 P2） | **误报**：MC 是黄道与子午圈交点，位于黄道上 β=0，该反演是精确解。实测 `armc_from_mc(swe MC)=282.02462039720274` vs `swe.houses_ex` ARMC `=282.0246203972028`（差 6e-14）。附带：`method_families.py:376` 的 limitations 声称“零纬近似存在弧秒残差”与事实不符 |
| scan 不产生 stderr JSONL 进度（rectify 组 P2） | **误报**：Swift `BackendClient.scan`（`BackendClient.swift:280-282`）不传 `progressCallback`，前后端一致；进度契约只覆盖 rectify / modern_timing / rectify_evidence |
| ZR 子周期 `step==24` 未跳回起始 sign（classical-timing 组 P3） | **不可达**：子层一轮/父层长度比恒 <2（L2 6330/10957 天等），step 24 永不出现 |
| jyotish 用 `get_ayanamsa`（ET）传 UT JD | 实测与 `get_ayanamsa_ut` 差 **0.0001 角秒**，可忽略；仅代码一致性建议 |

---

## 四、待产品/口径确认

1. **PTOLEMAIC_BOUNDS 版本**：`Aries` Mars 上限 28（Tetrabiblos Robbins 标准文本为 26）；`Gemini` 采用 Lilly 变体 7/14/21/25/30（Robbins 文本为 7/13/20/26/30）；`Leo/Cancer/Scorpio/Capricorn` 等与 Robbins 表差异较大。建议选定版本、注明来源并补测试。
2. **Shadbala 完整度**：`is_complete: False` 已标注，但 `shadbala_total/percent` 仍输出；是补齐子项还是显式降级。
3. **primary_directions 单向**：当前为 proxy 方法（`method_note` 自述），是否补 converse 方向。
4. **horary v2 per-planet moiety orb**：当前只有全局 orb；judgment-free 数据包可能有意。

---

## 五、已验证干净的高风险面（本次独立数值对拍）

| 面 | 结论 |
|---|---|
| moment 行星黄经/黄纬/赤纬/速度 vs pyswisseph 直接调用 | 12 组全部一致（最大偏差 1.3e-4，四舍五入级） |
| ASC/MC/DSC/IC vs `swe.houses_ex` | 0 差异 |
| 6 种宫位制（W/P/O/R/B/A）宫头 vs `swe.houses_ex` | 全部 0 差异 |
| prenatal syzygy vs 独立二分求朔 | 秒级一致（1989-12-28 03:19:37 vs 后端 03:20） |
| solar return 求解 | 内部角度用精确秒求解（与真根 ASC 差 0.0012°），`return_solver` 50 轮二分收敛 |
| 福点/antiscia/PD 年龄换算 | 公式与常数自洽 |
| 全量 pytest | 1091 passed |

---

## 六、修复优先级建议

1. **第一批（P1）**：埃及界 Aries（改表 + 同步 `test_classical.py:100-105` + 契约 fixture）；`declination_timing._display_zone` 固定偏移（照抄其余模块的 try/except 写法）。
2. **第二批（P2 局部小改）**：composite ASC/cusp 一致化；Mercury Hayz 的 `in_sect` 判定；method_families 的 `or 1.0`/`bool()`；Krittika 译名；patterns Kite（旧 P2-9）；horary v2 速度缺失降级为 unknown。
3. **第三批（语义/口径）**：primary_directions 双向、orbital_dial modulus、Shadbala 完整度、旧文档 P2-2/P2-4/P2-6/P2-8/P2-11。
4. 每批按 AGENTS.md 全链路要求：Python 回归测试 + 受影响 Swift 模型/导出核对 + 契约 fixture 再生 + `Examples/` 冒烟。
