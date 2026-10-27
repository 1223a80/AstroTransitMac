# Transit Studio — 功能规格与重写基线

Transit Studio 是一款 macOS 本地占星计算工作台：SwiftUI 界面 + Python/Swiss Ephemeris 计算后端，覆盖现代、古典、吠陀三种实践，西方 Horary、KP 数字占卜、三级生时矫正，以及 36 个后端计算模式。

本文不是发布记录，也不是路线图。它是当前实现的**功能规格**，用于指导从零重写。事实来源按优先级为：

1. 源码（`Sources/TransitStudio/`、`Sources/TransitStudio/Resources/backend/`）。
2. `Examples/` 中 44 个真实请求及其后端响应（字段级形状以这里为准）。
3. `SwiftTests/Fixtures/` 中 38 份真实输出快照。
4. `python_tests/` 中 1,232 项规则测试。

`docs/` 只作为历史说明，重写时不需要依赖。

**基线**：2026-10-18 源码，应用版本 1.6.2 (55)，macOS 13+，Swift 5.9，Python 3 + `pyswisseph`。当前验证：Python 1,232 项、Swift 234 项 / 32 suites、44 个实时样例全部通过。

---

## 目录

- [1. 产品定义](#1-产品定义)
- [2. 硬边界](#2-硬边界)
- [3. 技术形态](#3-技术形态)
- [4. 界面与交互](#4-界面与交互)
- [5. 通用数据契约](#5-通用数据契约)
- [6. 功能清单](#6-功能清单)
- [7. 星盘图](#7-星盘图)
- [8. 导出](#8-导出)
- [9. AI 分析](#9-ai-分析)
- [10. 模块地图](#10-模块地图)
- [11. 验证基线与性能](#11-验证基线与性能)
- [12. 重写验收清单](#12-重写验收清单)

---

## 1. 产品定义

用户在一台 Mac 上完成以下工作：

1. 录入出生时间、地点、宫制、黄道与技法选项。
2. 选择一种实践模式和一个技法，点击运行。
3. 得到星盘图、分 tab 的结构化表格/时间线/诊断，以及可复算的 JSON。
4. 可选：把结果导出为 Markdown / JSON / CSV，或交给外部 LLM 做流式分析。
5. 可选：在古典模式下用三级滑杆做生时矫正，并用结构化人生事件做证据审计。

产品定位是**可计算、可复算、可审计的数据工具**，不是“自动算命器”。大量模块只输出事实、方法、证据和候选，不输出吉凶结论。

### 三种实践模式

| 实践 | 导航入口 | 说明 |
|---|---|---|
| 现代 | 20 个现代技法 | 本命、关系盘、推运、现代扩展、天体地图 |
| 古典 | 本命设置、Horary、生时矫正、8 个古典进阶 | 古典本命与希腊化/中世纪技法 |
| 吠陀 | 吠陀排盘、KP 占卜 | Jyotish 与 Krishnamurti 数字占卜 |

公共入口在任何实践模式下都保留：**时间点**、**窗口扫描**、**程序设置**。

---

## 2. 硬边界

这些是产品约束，不是实现细节，重写时必须保留：

- **不做自动裁决**：Horary V3、KP、古典审计不输出 yes/no、吉凶、总分、confidence、machine summary。
- **不输出寿命**：Hyleg / Alcocoden 只输出候选、理由、证据，不输出寿命年数。
- **不做择时推荐**：世俗/择时模块只给 ingress、事实快照与候选矩阵，不排序“吉时”。
- **不猜出生时间**：出生时刻必须明确到分钟并带时区；不会把模糊生时降级成中午盘。
- **V1 Horary 仅兼容**：必须显式 `packetVersion=1`；默认 V3，显式 `2` 才走 V2.1。
- **AI 不参与计算**：没有 API Key 也能完整使用计算、结果页和导出。
- **计算本地完成**：除 AI 请求和用户主动触发的小行星下载外，不访问网络。
- **单请求超时 300 秒**：Swift 侧硬超时；超时终止子进程并报错。
- **不静默回退**：未知 mode、未知版本、非法选项都返回结构化错误，不猜测。

---

## 3. 技术形态

| 项 | 当前实现 |
|---|---|
| 应用 | Swift Package executable，单一 `TransitStudio` target |
| 界面 | SwiftUI，macOS 13+，窗口最小 1040×720 |
| 前端状态 | `AppState`（UserDefaults）+ `ContentView` 的 `@State` + 各 ViewModel |
| 后端 | Python 3 + `pyswisseph`（Swiss Ephemeris 2.10+） |
| 传输 | 每次请求启动一个 `transit_calc.py` 子进程；请求 JSON 写 stdin，响应 JSON 读 stdout |
| 进度 | 后端向 stderr 写 `{"progress": …}` 行；Swift 通过文件监视解析 |
| 星历 | 仓库内置 `.se1`，可配置外部目录；小行星文件可按需下载 |
| 依赖 | Swift 无第三方包；Python 运行仅 `pyswisseph`，测试加 `pytest`/`jsonschema` |
| 超时 | 300 秒；进程级取消与终止 |

重写时可以把“每次请求一个进程”改成进程内调用，但必须保持相同的请求/响应语义。

---

## 4. 界面与交互

### 4.1 主窗口布局

从左到右：

1. **技法导航栏**：可整体收起；技法列表独立滚动；底部固定“程序设置”。
2. **参数栏**：默认 430 pt，可拖拽 320–560 pt；可收起/展开；可“固定”以在计算后不自动收起；每个区块可折叠。
3. **结果工作区**：tabs + 内容 + 工具栏（导出）。
4. **AI 面板**：右侧可折叠，展开宽 380 pt；无上下文时显示占位说明。
5. **顶栏**：品牌、本命档案菜单、现代/古典/吠陀切换、运行按钮、进度。
6. **底部状态栏**：当前操作、错误、警告、进度。

### 4.2 导航结构

**现代**（20 个）：

本命盘、合盘、组合盘、戴维森盘、次限推进、太阳弧、调和盘、返照盘、中点、推进组合盘、迁移盘、朔望食相、赤纬事件、逆行阴影、会合周期、Draconic/日心、推运方法族、轨道点/Dial、天体地图、Local Space。

**古典**：

本命设置、Horary、生时矫正；分组“古典进阶”下 8 个：可见相位/行星时、希腊状态审计、派生盘/尊贵、时间主扩展、主限审计、沿界/主限扩展、产前朔望/Parans、世俗/择时事实。

**吠陀**：

吠陀排盘、KP 占卜。

**公共**：

时间点、窗口扫描、程序设置。

### 4.3 运行生命周期

- 点击运行后立即清空当前模式旧结果与旧 AI 文本，避免失败重跑后仍展示上一次图表。
- `CalculationViewModel.beginRun()` 递增 generation；只有当前 generation 能写结果、清任务或写终止错误。
- 顶部停止按钮可取消：取消会终止子进程；被取代的请求不得清掉新请求的任务引用。
- 扫描类任务先做工作量估算：
  - `> 1,500,000`：软警告。
  - `> 5,000,000`：需要用户确认。
  - `> 15,000,000`：直接阻止并提示缩小范围。
- 现代综合时间线有独立的时长/步数估算与确认。
- 后端 300 秒无响应视为超时；错误以可读文本显示在状态栏/错误区。

### 4.4 结果区

每个结果页由 `(id, title)` tab 列表 + “更多”菜单组成；工具栏标题由同一列表推导。通用约定：

- 有结果才显示内容，否则显示空态（等待计算 + 引导文案）。
- “诊断” tab 展示 warnings、`section_errors`、未解析端点、原始 JSON。
- 支持计算中切换页面；结果按模式独立缓存，切回仍可查看。
- 古典进阶支持“合并导出”：把多个已计算模式的 Markdown 合成一份。

### 4.5 程序设置

独立页面，四个 tab：

| Tab | 内容 |
|---|---|
| 界面 | 外观：跟随系统 / 浅色（羊皮纸）/ 深色（深空） |
| 后端 | Python 可执行路径、`pyswisseph` 检测状态、外部 Ephemeris 目录、自动下载小行星、不计算小行星、缺小行星星历策略（warn / strict / skip） |
| AI | Base URL、模型名（可保存/删除多个）、API Key、测试 API、reasoning effort（关/低/中/高/最大）、默认提示词风格与内容、备注 |
| 小行星 | 小行星编号列表、预下载、复制下载命令 |

### 4.6 档案、预设与模板

- **本命档案**：`name`、`moment`、`latitude`、`longitude`、`gmtOffset`、`chartStyle`、`houseSystem`、`zodiac`、`boundsSystem`、`triplicitySystem`。支持保存、载入、删除；载入会一次性应用这些设置。
- **时间点预设 / 扫描预设**：命名 + 模板文本，保存在 UserDefaults。
- **模板语法**：`KEY=VALUE` 行，`#` 注释，列表用英文逗号；扫描自定义目标用 `|` 分隔多条。
  - 时间点键：`TRANSIT_TIME`、`NATAL_BODIES`、`TRANSIT_BODIES`、`ASPECTS`、`CUSTOM_ASPECT_DEGREES`、`CUSTOM_ASTEROIDS`、`GLOBAL_ORB`。
  - 扫描键：`SCAN_KIND`、`LABEL`、`START`、`END`、`MOON_FILTER`、`TRANSIT_BODIES`、`TARGET_SOURCE`、`TARGET_PLANETS`、`TARGET_VIRTUAL_POINTS`、`TARGET_ASTEROIDS`、`TARGET_HOUSES`、`TARGET_LOTS`、`CUSTOM_TARGETS`、`ASPECTS`、`CUSTOM_ASPECT_DEGREES`、`CUSTOM_ASTEROIDS`。

---

## 5. 通用数据契约

### 5.1 时刻对象

```json
{
  "year": 2026, "month": 7, "day": 23,
  "hour": 22, "minute": 25, "second": 0,
  "timezone": "Asia/Shanghai",
  "fold": 0
}
```

- `timezone` 支持 IANA 名称与固定偏移：`UTC`、`GMT+8`、`UTC-05:00`、`+08:00`。
- `second` 可选，缺省 0；范围 0–59。
- IANA 时区中不存在的本地时间（夏令时跳时）必须报错。
- 回拨产生的歧义时间必须显式 `fold: 0` 或 `fold: 1`，否则报错。
- 所有计算先转 UTC，再取 Julian Day；响应同时给 UTC 与本地时间字符串。

### 5.2 地点

- `latitude` ∈ [-90, 90]，`longitude` ∈ [-180, 180]，必须有限数值。
- 地图类模式可带 `altitude_m`；`location.timezone` 用于本地显示。
- 时区只影响本地时间解释与显示，不改变同一 UTC 时刻的星象。

### 5.3 选项

| 选项 | 允许值 | 常用默认 |
|---|---|---|
| `houseSystem` | `whole_sign`、`placidus`、`porphyry`、`regiomontanus`、`alcabitius`、`equal` | 现代/古典 `whole_sign`；Horary `regiomontanus`；KP `placidus` |
| `zodiac` | `tropical`、`sidereal_lahiri`、`sidereal_raman`、`sidereal_krishnamurti`、`sidereal_yukteshwar`、`sidereal_citra`、`sidereal_revati`、`sidereal_pushya_paksha`、`sidereal_suryasiddhanta` | `tropical` |
| `boundsSystem` | `egyptian`、`ptolemaic` | `egyptian` |
| `triplicitySystem` | `dorothean`、`ptolemaic` | `dorothean` |
| `node_mode` | `true_node`、`mean_node` | `true_node`（Horary/KP 可不同） |
| Vedic ayanamsha | `lahiri`、`raman`、`krishnamurti`、`yukteshwar`、`suryasiddhanta`、`pushya_paksha`、`revati`、`citra`、`fagan_bradley`、`ss_revati`、`ss_citra` | `lahiri` |

宫制影响宫头、宫位归属与宫主；黄道影响所有黄经；界/三分性只影响古典尊贵与相关评分。

### 5.4 天体 ID

内置 24 个：

```
SUN MOON MERCURY VENUS MARS JUPITER SATURN
URANUS NEPTUNE PLUTO
CHIRON PHOLUS CERES PALLAS JUNO VESTA
MEAN_NODE TRUE_NODE SOUTH_MEAN_NODE SOUTH_TRUE_NODE
MEAN_LILITH OSCU_LILITH
RAHU KETU
```

- 南交点由北交点加 180° 得到；赤纬取反。
- 恒星黄道下 `RAHU`/`KETU` 与交点语义一致，但用于吠陀输出。
- 自定义小行星用整数编号（如 `433`、`16`），需对应 `.se1` 文件。

### 5.5 现代点集 `point_set`

```json
{
  "body_ids": ["SUN", "MOON"],
  "include_nodes": true,
  "node_mode": "true_node",
  "custom_asteroids": [433],
  "angle_ids": ["ASC", "MC"],
  "house_cusps": [1, 4, 7, 10],
  "lot_ids": ["fortune"],
  "midpoint_pairs": [{"point_a_id": "SUN", "point_b_id": "MOON"}]
}
```

- `body_ids` 不得包含节点 ID；节点由 `include_nodes` + `node_mode` 控制。
- `angle_ids` 仅支持：`ASC`、`MC`、`DSC`、`IC`、`VERTEX`、`ANTIVERTEX`、`EQUATORIAL_ASCENDANT`。
- `house_cusps` 为 1–12；`lot_ids` 为后端 Lots 注册表 ID。
- `midpoint_pairs` 可选；排序后生成稳定 axis ID。

### 5.6 相位

11 种 ID：

```
conjunction opposition trine square sextile
quincunx semisextile semisquare sesquisquare quintile biquintile
```

- 默认启用：合、冲、拱、刑、六合（0°/180°/120°/90°/60°）。
- 可选：150°、30°、45°、135°、72°、144°。
- 请求可带 `orb`（度）或全局 orb；后端按 `aspect_orb` 判定。
- 响应区分 `applying` / `separating`；相位行保留 `orb` 与几何类型。

### 5.7 目标点文本（扫描）

每一行：

```
Solar Return = Libra 12°30
Meeting Point, Scorpio, 03°15
Custom = 123.5
```

- `=` 或逗号分隔；名称任意。
- 值可以是“星座 + 度数”或直接 0–360 度。
- 星座支持中英文与常见别名（如 Aries/白羊、Libra/天秤）。

### 5.8 响应信封

通用字段：

| 字段 | 含义 |
|---|---|
| `meta` | 计算元信息：UTC/本地时刻、经纬度、宫制、黄道、星历、有效点集等 |
| `requested_config` / `effective_config` | 请求配置与实际生效配置（发生回退时不同） |
| `warnings` | 可恢复问题；不得静默丢弃 |
| `section_errors` | 单个区块失败但整体仍返回时的错误映射 |
| `calculation_assumptions` | 影响解释的常量/方法（orb、速率、评分口径等） |
| `schema` | 带版本的数据包标识（Horary、KP、证据包） |
| `display` | 面向展示的辅助内容（Horary V3 的 `reader_markdown`） |

约定：

- 后端响应字段以 `snake_case` 为主；请求字段历史原因混合 `camelCase` 与 `snake_case`，逐 mode 以 `Examples/` 为准。
- 角度保留浮点；展示文本另给 `degree_text`、`*_local`、`*_utc`。
- 中文名称与英文 ID 同时保留。
- 同一输入必须得到同一输出（无随机、无隐式当前时间）。

### 5.9 错误

输入校验失败：

```json
{
  "error": "缺少必需字段：birth.moment；字段无效：birth.latitude must be ...",
  "mode": "classical",
  "missing": ["birth.moment"],
  "invalid": ["birth.latitude must be ..."]
}
```

- 未知/空 mode：`{"error": "不支持的 mode：…", "mode": "…"}`。
- 运行时异常：stderr 文本 + 非零退出码；Swift 显示为“Python：…”。
- 校验失败仍以退出码 0 返回 JSON，前端按 `error` 字段识别。

### 5.10 星历行为

- 优先 `FLG_SWIEPH`（读取 `.se1`）；失败时对小行星按策略跳过/警告/报错。
- 非小行星失败时回退 `FLG_MOSEPH`，并写 warning，响应标注 `Moshier fallback`。
- 恒星黄道通过 `swe.set_sid_mode` 设置。
- 星历来源写入 `meta.ephemeris` 或对应行。
- 小行星缺失可自动从配置的 Dropbox 目录下载到 `~/Library/Application Support/TransitStudio/ephe`。

---

## 6. 功能清单

### 6.1 模式总表

36 个后端 mode：

| # | mode | 类别 | 当前入口 |
|---:|---|---|---|
| 1 | `moment` | 行运/本命 | 时间点、现代本命盘 |
| 2 | `scan` | 行运 | 窗口扫描 |
| 3 | `modern_timing` | 行运 | 窗口扫描 → 综合时间线 |
| 4 | `classical` | 古典 | 古典本命 |
| 5 | `horary` | 占卜 | 古典 → Horary |
| 6 | `kp_horary` | 占卜 | 吠陀 → KP 占卜 |
| 7 | `vedic` | 吠陀 | 吠陀排盘 |
| 8 | `rectify` | 古典 | 古典 → 生时矫正 |
| 9 | `rectify_evidence` | 古典 | 生时矫正 → 事件证据 |
| 10 | `synastry` | 现代 | 合盘 |
| 11 | `composite` | 现代 | 组合盘 |
| 12 | `davison` | 现代 | 戴维森盘 |
| 13 | `progression` | 现代 | 次限推进 |
| 14 | `solar_arc` | 现代 | 太阳弧 |
| 15 | `harmonic` | 现代 | 调和盘 |
| 16 | `modern_return` | 现代 | 返照盘 |
| 17 | `midpoint` | 现代 | 中点 |
| 18 | `progressed_composite` | 现代 | 推进组合盘 |
| 19 | `relocation` | 现代 | 迁移盘 |
| 20 | `modern_cycles` | 现代 | 朔望食相 |
| 21 | `declination_timing` | 现代 | 赤纬事件 |
| 22 | `retrograde_cycles` | 现代 | 逆行阴影 |
| 23 | `planetary_synodic` | 现代 | 会合周期 |
| 24 | `draconic_heliocentric` | 现代 | Draconic / 日心 |
| 25 | `method_families` | 现代 | 推运方法族 |
| 26 | `orbital_dial` | 现代 | 轨道点 / Dial |
| 27 | `astrocartography` | 现代 | 天体地图 |
| 28 | `local_space` | 现代 | Local Space |
| 29 | `classical_visibility` | 古典进阶 | 可见相位 / 行星时 |
| 30 | `hellenistic_condition_audit` | 古典进阶 | 希腊状态审计 |
| 31 | `classical_derivatives` | 古典进阶 | 派生盘 / 尊贵 |
| 32 | `time_lords_extended` | 古典进阶 | 时间主扩展 |
| 33 | `primary_directions_audit` | 古典进阶 | 主限审计 |
| 34 | `distributions_pd` | 古典进阶 | 沿界 / 主限扩展 |
| 35 | `prenatal_parans` | 古典进阶 | 产前朔望 / Parans |
| 36 | `mundane_electional` | 古典进阶 | 世俗 / 择时事实 |

### 6.2 现代子模式（28 个）

| 子模式 | UI | 后端 mode | 导航轨道 |
|---|---|---|---|
| `natal` | 本命盘 | `moment` | 现代 |
| `synastry` | 合盘 | `synastry` | 现代 |
| `composite` | 组合盘 | `composite` | 现代 |
| `davison` | 戴维森盘 | `davison` | 现代 |
| `progression` | 次限推进 | `progression` | 现代 |
| `solarArc` | 太阳弧 | `solar_arc` | 现代 |
| `harmonic` | 调和盘 | `harmonic` | 现代 |
| `returnChart` | 返照盘 | `modern_return` | 现代 |
| `midpoint` | 中点 | `midpoint` | 现代 |
| `progressedComposite` | 推进组合盘 | `progressed_composite` | 现代 |
| `relocation` | 迁移盘 | `relocation` | 现代 |
| `modernCycles` | 朔望食相 | `modern_cycles` | 现代 |
| `declinationTiming` | 赤纬事件 | `declination_timing` | 现代 |
| `retrogradeCycles` | 逆行阴影 | `retrograde_cycles` | 现代 |
| `planetarySynodic` | 会合周期 | `planetary_synodic` | 现代 |
| `draconicHeliocentric` | Draconic / 日心 | `draconic_heliocentric` | 现代 |
| `methodFamilies` | 推运方法族 | `method_families` | 现代 |
| `orbitalDial` | 轨道点 / Dial | `orbital_dial` | 现代 |
| `astrocartography` | 天体地图 | `astrocartography` | 现代 |
| `localSpace` | Local Space | `local_space` | 现代 |
| `classicalVisibility` | 可见相位 / 行星时 | `classical_visibility` | 古典进阶 |
| `hellenisticConditionAudit` | 希腊状态审计 | `hellenistic_condition_audit` | 古典进阶 |
| `classicalDerivatives` | 派生盘 / 尊贵 | `classical_derivatives` | 古典进阶 |
| `timeLordsExtended` | 时间主扩展 | `time_lords_extended` | 古典进阶 |
| `primaryDirectionsAudit` | 主限审计 | `primary_directions_audit` | 古典进阶 |
| `distributionsPd` | 沿界 / 主限扩展 | `distributions_pd` | 古典进阶 |
| `prenatalParans` | 产前朔望 / Parans | `prenatal_parans` | 古典进阶 |
| `mundaneElectional` | 世俗 / 择时事实 | `mundane_electional` | 古典进阶 |

现代导航只显示前 20 个；后 8 个只出现在古典导航。

---

### 6.3 行运与时间

#### `moment` — 时间点 / 现代本命

- **输入**：`natal`、`transit`（两个时刻）、`natalBodies`、`transitBodies`、`customAsteroids`、`aspects`、`pointSet`、`nodeMode`、`patternsEnabled`、`ephemerisPath`、`noAsteroids`、`requireEphemeris`。
- **输出区块**：`meta`、`natal_positions`、`transit_positions`、`angles`、`houses`、`lots`、`aspects`、`declination_aspects`、`natal_star_conjunctions`、`transit_star_conjunctions`、`patterns`、`chart_profile`、`warnings`。
- **现代本命**：`sameChart=true`，本命与行运使用同一时刻；后端跳过自相位与跨盘重复区块，前端只展示单盘，并按小行星选择过滤。
- **时间点**：双盘；行运位置对本命位置/角点/宫头/Lots 的接触。
- **界面**：本命 4 个主 tab（星盘图、本命位置、本命相位、结构）+ 赤纬、固定星、诊断；时间点 4 个主 tab（星盘图、相位、行运位置、本命位置）+ 诊断。
- **导出 / AI**：Markdown / JSON / CSV；有 AI。
- **规则**：`angles`/`houses`/`lots` 由 `birth` 设置与点集决定；相位区分 applying/separating；出生盘不因当前时间改变。

#### `scan` — 窗口扫描

- **输入**：`scanKind`（`aspect` / `ingress` / `station`）、`start`、`end`、`transitBodies`、`customAsteroids`、`aspects`、`targetText`、`label`、`moonFilter`（`exclude` / `include` / `only`）、`confirmedHeavyScan`。
- **输出**：`meta`、`hits`、`warnings`。命中行含本地时间、行运体、相位、目标、精确黄经、优先级分数/等级。
- **界面**：时间轴、命中表格 + 诊断。
- **导出 / AI**：Markdown / JSON / CSV；普通窗口扫描有 AI。
- **规则**：`aspect` 扫描“目标 ± 相位角”的精确成相；`ingress` 扫描换座；`station` 扫描顺逆停滞（不含日月）。窗口按后端年份上限截断并警告。300 秒超时。

#### `modern_timing` — 现代综合时间线

- **输入**：`birth`、`start`、`end`、`display_timezone`、`techniques`，以及二选一：
  - `target_point_set`（本命目标点集）；
  - `target_chart`（`composite` / `davison`，含 person A/B 与点集）。
- **技法**：
  - `transit`：事件类型 `aspect`、`ingress`、`station`。
  - `secondary_progression`：`aspect`、`moon_ingress`、`lunation`。
  - `solar_arc`：`aspect`。
  - 关系目标只允许 `transit`。
- **输出**：`meta`（含 `technique_configs`、`estimated_work_units`）、`events`、`warnings`、`section_errors`。
- **事件模型**：`source_type`、`event_type`、移动点、目标点、相位、orb 上限、`entering_utc` / `exact_utc` / `leaving_utc`、`pass_index_in_window` / `pass_count_in_window`、`window_clipped_start/end`、`method_key`。
- **界面**：时间线、分组、日历 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。
- **规则**：同一事件的多 pass 分开编号；窗口边界裁剪显式标记；估算超过阈值需要确认。

### 6.4 现代本命与关系盘

#### `synastry` — 合盘

- **输入**：`person_a`、`person_b`（各含 name、moment、lat/lon）、`house_system`、`zodiac`、`node_mode`、`aspects`。
- **输出**：`person_a_planets`、`person_b_planets`、双方角点/宫位、`cross_aspects`、`cross_declination_aspects`、`a_in_b_houses`、`b_in_a_houses`、`patterns`、`warnings`、`section_errors`。
- **界面**：跨盘相位、A 入 B 宫、B 入 A 宫、A 本命、B 本命 + 赤纬/诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；有 AI。

#### `composite` — 组合盘

- **输入**：`person_a`、`person_b`、`house_system`、`zodiac`、`node_mode`、`aspects`。
- **输出**：`angles`、`houses`、`planets`、`aspects`、`patterns`、`warnings`、`section_errors`。
- **规则**：点位取两人同点的循环中点；宫头/角点同样由中点生成。
- **界面**：行星、角点、宫位、相位、图形 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；有 AI。

#### `davison` — 戴维森盘

- **输入**：同组合盘。
- **输出**：同组合盘。
- **规则**：时间与空间都取两人中点（戴维森时空盘），不是组合盘的中点黄经。
- **界面 / 导出 / AI**：同组合盘。

#### `progressed_composite` — 推进组合盘

- **输入**：`person_a`、`person_b`、`reference`、`zodiac`、`node_mode`、`point_set`、`aspects`。
- **输出**：`radix_composite_planets`、`progressed_composite_planets`、`progressed_to_radix_aspects`、`warnings`、`section_errors`。
- **界面**：Radix Composite、Progressed Composite、推进→Radix 相位 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

### 6.5 推运与派生盘

#### `progression` — 次限推进

- **输入**：`birth`、`reference`、`house_system`、`zodiac`、`node_mode`、`aspects`。
- **输出**：`natal_planets`、`progressed_planets`、`natal_angles`、`progressed_angles`、`natal_houses`、`progressed_houses`、`progressed_to_natal_aspects`、`progressed_to_progressed_aspects`、`progressed_lunation`、`warnings`、`section_errors`。
- **规则**：一日一年（day-for-year）；推进时刻由出生到 reference 的时长换算。
- **界面**：推进盘、本命盘、推进→本命相位、推进盘相位、推进月相 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；有 AI。

#### `solar_arc` — 太阳弧

- **输入**：`birth`、`reference`、`house_system`、`zodiac`、`node_mode`、`patterns_enabled`、`aspects`。
- **输出**：`natal_planets`、`solar_arc_planets`、`solar_arc_angles`、`solar_arc_houses`、`solar_arc_to_natal_aspects`、`activation_clusters`、`arc_value`、`patterns`、`patterns_mode`、`aspects_internal_sa`、`aspects_internal_note`、`calculation_assumptions`。
- **界面**：Solar Arc 盘、本命盘、SA→本命相位、图形 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；有 AI。

#### `harmonic` — 调和盘

- **输入**：`birth`、`harmonic_order`、`house_system`、`zodiac`、`node_mode`、`aspects`。
- **输出**：`planets`、`angles`、`houses`、`houses_experimental`、`aspects`、`harmonic_order`、`calculation_assumptions`、`section_errors`。
- **规则**：把每个黄经乘以 order 后归一化；宫位为实验性派生。
- **界面**：调和行星、调和相位、诊断、JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

#### `modern_return` — 返照盘

- **输入**：`return_body_id`（SUN、MOON、MERCURY…PLUTO、CHIRON）、`birth`、`reference`、`location_source`（`birth` / `custom`）、`location`、`house_system`、`zodiac`、`node_mode`、`point_set`、`aspects`、`precession_correction`。
- **输出**：`previous_return`、`current_cycle_return`、`next_return`、`all_crossings`、`no_hit_in_user_window`、`suggested_window`、`search_start_local`、`search_end_local`、`calculation_assumptions`。
- **单次返照内容**：精确 UTC/本地时间、上升/中天、宫位、行星、本命交叉相位、宫位 overlay、周期起止、hit 序号、是否当前周期、地点来源。
- **规则**：按天体真实回归黄经求根；找不到窗口内命中时明确 `no_hit_in_user_window` 并给建议窗口，不造假数据。
- **界面**：当前返照、双盘、前后返照、返照→本命、宫位落点、图形 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

#### `midpoint` — 中点

- **输入**：`birth`、`reference`、`point_set`（可含 `midpoint_pairs`）、`focus_point_ids`、`activation_sources`（`natal` / `transit` / `secondary_progression` / `solar_arc`）、`activation_orb`、`modulus`、`include_opposite_axis`。
- **输出**：`axes`、`trees`、`snapshot_activations`、`warnings`、`section_errors`。
- **规则**：轴由两点中点与其对轴组成；激活按来源分别计算；orbit 由 `activation_orb` 控制。
- **界面**：中点轴、中点树、激活 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

#### `relocation` — 迁移盘

- **输入**：`birth`、`relocation`（name、lat、lon、timezone）、`house_system`、`zodiac`、`node_mode`、`point_set`、`aspects`。
- **输出**：`natal_chart`、`relocated_chart`、`planet_house_changes`、`relocated_angles_in_natal_houses`、`natal_angles_in_relocated_houses`、`warnings`、`section_errors`。
- **规则**：出生 UTC 不变；只改变地点与当地时区显示。
- **界面**：双盘、迁移宫位/角点、Overlays、Compare + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

### 6.6 现代扩展

#### `modern_cycles` — 朔望食相

- **输入**：`start`、`end`、`display_timezone`、`cycle_types`（`new_moon` / `full_moon` / `solar_eclipse` / `lunar_eclipse`）、`visibility`（`global` / `location`）、`location`、`birth`、`target_point_set`、`contact_aspects`、`zodiac`。
- **输出**：`events`、`timing_events`、`warnings`、`section_errors`。
- **界面**：周期事件、本命接触、时间线源 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

#### `declination_timing` — 赤纬事件

- **输入**：`birth`、`start`、`end`、`display_timezone`、`moving_body_ids`、`event_types`（`parallel` / `contraparallel` / `oob_entry` / `oob_exit` / `declination_station`）、`declination_orb`、`target_point_set`。
- **输出**：`events`、`warnings`、`section_errors`、`calculation_assumptions`。
- **界面**：赤纬事件、赤纬停滞、OOB、假设 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

#### `retrograde_cycles` — 逆行阴影

- **输入**：`start`、`end`、`display_timezone`、`body_ids`、`zodiac`。
- **输出**：`stations`、`cycles`、`warnings`、`section_errors`、`calculation_assumptions`。
- **规则**：由真实 station 求根；前阴影/逆行/后阴影按站度定义；重复触发单独计数。
- **界面**：逆行周期、站度、假设 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

#### `planetary_synodic` — 会合周期

- **输入**：`start`、`end`、`display_timezone`、`pair`（`body_a` / `body_b`）、`phases`、`birth`、`target_point_set`、`contact_aspects`、`zodiac`。
- **输出**：`events`、`cycles`、`window_end_state`、`current_cycle_progress`、`warnings`、`section_errors`、`calculation_assumptions`。
- **界面**：相位事件、会合周期、本命接触、假设 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

#### `draconic_heliocentric` — Draconic / 日心

- **输入**：`birth`、`node_mode`、`point_set`。
- **输出**：`draconic`、`heliocentric`、`geocentric`、`geo_helio_comparison`、`warnings`、`section_errors`、`calculation_assumptions`。
- **规则**：Draconic 以真/平北交点为 0° 重定位；日心坐标与地心并列对照。
- **界面**：Draconic、日心、对照、假设 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

#### `method_families` — 推运方法族

- **输入**：`birth`、`reference`。
- **输出**：`progression_profiles`、`solar_arc_profiles`、`profile_arc_comparison`、`method_difference`、`limitations`、`warnings`、`section_errors`、`calculation_assumptions`。
- **规则**：并列不同方法 profile 的事实结果，不裁决哪个“正确”。
- **界面**：次限角点、太阳弧 + 假设/诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

#### `orbital_dial` — 轨道点 / Dial

- **输入**：`birth`、`modulus`（常用 90 或 45）。
- **输出**：`orbital_points`、`dial_pictures`、`warnings`、`section_errors`、`calculation_assumptions`。
- **界面**：轨道点、行星图 + 假设/诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

#### `astrocartography` — 天体地图

- **输入**：`moment`、`body_ids`、`angle_kinds`（ASC/DSC/MC/IC）、`zodiac`。
- **输出**：`meta`、`lines`、`warnings`、`section_errors`。
- **界面**：ACG 线、地图说明 + 诊断/JSON；不内嵌交互地图。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

#### `local_space` — Local Space

- **输入**：`moment`、`location`（name、lat、lon、altitude）、`body_ids`、`zodiac`。
- **输出**：`meta`、`directions`、`warnings`、`section_errors`。
- **界面**：方位、地图说明 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

### 6.7 古典本命

#### `classical` — 古典本命

- **输入**：`birth`（含宫制/黄道/界/三分性）、`reference`、`aspectOrb`、`returnMode`（`full` / `compact` / `relationship` / `study`；Swift 当前固定传 `nil`，即 `full`）。
- **输出区块**：
  - 基础：`angles`、`houses`、`planets`、`lots`、`experimental_lots`；
  - 关系：`aspects`、`receptions`、`antiscia`、`declination_aspects`、`natal_star_conjunctions`；
  - 时间：`timing`（profection、firdaria、decennials、zodiacal_releasing、timeline）；
  - 返照：`planetary_returns`（7 政，每行星统一 `previous_return` / `current_cycle_return` / `next_return`）；
  - 专题：`primary_directions`、`circumambulations`、`prenatal_syzygy`、`almuten_figuris`、`hyleg_alcocoden`、`medieval`；
  - 摘要：`top_signatures`、`birthday_transition`、`activated_lord_focus`；
  - 审计：`warnings`、`section_errors`、`ambiguity`、`calculation_assumptions`。
- **Lots**：53 个常规（core 7、life 24、career 12、spirit 10）+ 3 个实验性。每个 Lot 保留昼夜公式、实际使用公式、来源传统、置信度、别名与独立性分组。
- **规则**：
  - `planetary_returns` 是返照唯一顶层入口，没有独立 `solar_return`。
  - `returnMode` 只筛选返回哪些行星：full 全 7；compact 日月 + 小限主星；relationship 日月 + 金星；study 日月 + 水星/木星。这是后端能力，Swift 界面未暴露选择器。
  - Prenatal Syzygy：满月同时保留太阳与月亮位置；轴度数约定使用太阳度数，并在 `syzygy_degree_used` 说明。
  - ZR 的 Loosing of the Bond 只在真正跳到松绑点/对宫时标记；普通换座不标记。
  - Hyleg/Alcocoden 只给候选、理由、限制，不给寿命年数。
- **界面**：星盘图、行星状态、点位/Lots、宫位、相位/接纳、评分明细、映点、主限法、沿界推进、时间技法 + 诊断/JSON。
- **深链**：主限法区块可直接跳到“主限审计”，产前朔望区块可直接跳到“产前朔望/Parans”工作区，并携带当前出生资料。
- **导出 / AI**：Markdown（按 section 选择）/ JSON / CSV；有 AI（仅古典本命）。

### 6.8 古典进阶

八个模式共享：`birth` + `requested_config` / `effective_config` + 结果区块 + `warnings` / `section_errors` / `calculation_assumptions`。全部支持 Markdown（按 section）/ JSON / CSV，**没有 AI**。

#### `classical_visibility` — 可见相位 / 行星时

- **输入**：`moment`、`location`、`display_timezone`、`body_ids`、`heliacal_event_types`、`include`（`heliacal` / `rise_set` / `planetary_hours`）、`observer_age`。
- **输出**：`heliacal_events`、`rise_set`、`planetary_hours`、`warnings`、`section_errors`、`calculation_assumptions`。
- **界面**：偕日升降、升落、行星时、假设 + 诊断/JSON。

#### `hellenistic_condition_audit` — 希腊状态审计

- **输入**：`birth`、`aspect_orb`、`source_profile`。
- **输出**：`conditions`、`planets_summary`、`warnings`、`section_errors`、`calculation_assumptions`。
- **内容**：sect、hayz、oriental/occidental、overcoming、enclosure、可视性等证据行。
- **界面**：条件证据、假设 + 诊断/JSON。

#### `classical_derivatives` — 派生盘 / 尊贵

- **输入**：`birth`。
- **输出**：`dodekatemoria`、`dodekatemoria_contacts`、`monomoiria`、`topical_almutens`、`warnings`、`section_errors`、`calculation_assumptions`。
- **界面**：十二分盘、一度主、主题 Almuten + 假设/诊断/JSON。

#### `time_lords_extended` — 时间主扩展

- **输入**：`birth`、`reference`。
- **输出**：`profection`、`daily_profection`、`zodiacal_releasing`、`firdaria`、`decennials`、`revolutions_concordance`、`warnings`、`section_errors`、`calculation_assumptions`。
- **界面**：技法汇合、日小限、ZR + 假设/诊断/JSON。

#### `primary_directions_audit` — 主限审计

- **输入**：`birth`。
- **输出**：`algorithm_description`、`directions`、`warnings`、`section_errors`、`calculation_assumptions`。
- **规则**：每行保留 promissor/significator、方向、弧、年龄、事件日期、key rate、方法说明、代理与独立性分组；明确当前算法是正式几何子集，不冒充完整 Placidian/Regiomontanian 主限。
- **界面**：主限表、算法说明、假设 + 诊断/JSON。

#### `distributions_pd` — 沿界 / 主限扩展

- **输入**：`birth`。
- **输出**：`distributions`、`primary_directions_by_profile`、`primary_directions_test_profiles`、`warnings`、`section_errors`、`calculation_assumptions`。
- **界面**：沿界、主限多配置、假设 + 诊断/JSON。

#### `prenatal_parans` — 产前朔望 / Parans

- **输入**：`birth`、`paran_event_orb_seconds`（默认 240）、`paran_ra_orb_deg`（默认 1°）、`include_legacy_paran_proxy`。
- **输出**：`method_trace`、`prenatal_packet`、`fixed_star_parans`、`legacy_fixed_star_parans`、`event_diagnostics`、`polar_degradation`、`migration`、`warnings`、`section_errors`、`calculation_assumptions`。
- **规则**：
  - 真实 paran 用 `swe.rise_trans` 分别求行星与恒星的四类本地事件，再按绝对事件时间差配对。
  - 旧 ΔRA 代理只放在 `legacy_fixed_star_parans`，不混入真实事件计数。
  - 极区无法求升落时只输出可用事件与诊断，不伪造 paran。
- **界面**：朔望包、Parans 事件、兼容代理、假设 + 诊断/JSON。

#### `mundane_electional` — 世俗 / 择时事实

- **输入**：`start`、`end`、`display_timezone`、`location`、`topicHouse`、`scanStepHours`。
- **输出**：`mundane_ingresses`、`daily_fact_snapshots`、`scan_samples`、`electional_candidates`、`electional_candidates_note`、`filtered_candidates`、`warnings`、`section_errors`、`calculation_assumptions`。
- **规则**：只给四至点 ingress 与事实矩阵；不排名、不推荐、不输出“吉时”。
- **界面**：入宫、择时事实、假设 + 诊断/JSON。

### 6.9 Horary

#### 版本路由

| `packetVersion` | 返回 | 状态 |
|---|---|---|
| 缺省、`3`、`v3`、`3.0` | `horary-data-packet/3.0` | 默认 |
| `2`、`v2`、`2.0`、`2.1` | `horary-data-packet/2.1` | 兼容 |
| `1`、`v1`、`legacy`、`1.0` | `horary-data-packet/1.0` | 仅兼容，已弃用 |

未知版本返回结构化校验错误。

#### 输入

```json
{
  "mode": "horary",
  "packetVersion": "3",
  "chart": {
    "moment": {"year": 2026, "month": 7, "day": 23, "hour": 22, "minute": 25, "timezone": "Asia/Shanghai"},
    "latitude": 35.0576,
    "longitude": 118.3346,
    "houseSystem": "regiomontanus",
    "zodiac": "tropical",
    "boundsSystem": "egyptian",
    "triplicitySystem": "dorothean"
  },
  "questionText": "问题文本",
  "placeName": "地点",
  "aspectOrb": 3,
  "eventPastDays": 4,
  "eventFutureDays": 30
}
```

约束：`questionText` 非空；`aspectOrb` ∈ [0, 10]；`chart` 经纬度合法；时刻支持秒与 `fold`。

#### V3 输出

`schema`、`question_metadata`、`calculation_config`、`provenance`、`time_and_location`、`houses`、`angles`、`bodies`、`dignities`、`pairwise_geometry`、`aspects`、`aspect_candidates`、`aspects_in_display_orb`、`display_orb_deg`、`receptions`、`lots`、`events`、`event_graph`、`moon`、`visibility`、`planetary_day_hour`、`considerations_evidence`、`nodes`、`optional_modules`、`event_search`、`validation`、`display`。

- `display.reader_markdown`：Python 生成的选择性中文解盘工作表；应用复制、Markdown 导出、AI 数据输入共用它，完整证据仍在 JSON。
- `events` 区分 `event_type`、`aspect_id`、UTC/本地时间、相对提问时刻偏移、`rule_id`、`algorithm_version`、`candidate_id`、`in_configured_window`。
- `moon` 包含当前星座、赤纬、相位角、照亮比例、出座时间、本座内过去/未来精确相位、VOC 规则证据、到北交点距离。
- `validation` 包含 forbidden field 扫描与不变量检查；V3 不输出征象星选择、radicality 结论、yes/no、translation/collection/prohibition/frustration 判断、score/confidence。

#### V2.1 与 V1

- V2.1 与 V3 共享大部分事实区块，但没有 `event_search`；字段结构以 `SwiftTests/Fixtures/horary-result.json` 为准。
- V1 只用于兼容，带 `legacy/deprecated` 标记与迁移提示；新功能不应依赖 V1。

#### 界面

主 tabs：星盘图、数据总览、天体/偶然、角点/Lots、宫位、相位候选、接纳、尊贵归属、月亮/VOC、事件/图。

更多：行星时、判断前事实、赤纬、Antiscia、固定星、可见性、校验、JSON。

- **星盘图只绘制 `aspects_in_display_orb`**；orb 外未来成相保留在候选与事件中。
- **导出 / AI**：Markdown / JSON / CSV；有 AI；Markdown 优先使用 `display.reader_markdown`。
- **模型保真**：Swift 保留完整原始根 JSON，JSON → Swift → JSON 不得丢失 `time_and_location`、`provenance`、`calculation_config`、`optional_modules` 等字段。

### 6.10 KP 数字占卜

#### `kp_horary`

- **输入**：`chart`（moment + lat/lon）、`question_text`、`place_name`、`horary_number`（1–249）、`focus_house`（1–12）、`node_mode`（默认 `mean`）。
- **固定口径**：Krishnamurti 恒星黄道 + Placidus；行星使用提问时刻；数字只确定上升区间与宫头。
- **数字区间**：以 Vimshottari 比例生成 243 个宿/副星主原始区间，在六个跨星座边界处拆分为 249 个连续区间；每个区间用中点作为无歧义代表黄经，并保留起止边界。
- **输出**：`mode`、`schema`、`question`、`time_and_location`、`calculation_config`、`horary_number`、`house_solution`、`angles`、`planets`、`houses`、`ruling_planets`、`planet_significators`、`house_significators`、`focus_house`、`node_representations`、`warnings`。
- **每层内容**：四轴/九曜/十二宫的星座主、宿主、副星主、副副星主；行星逐层宫位来源；十二宫四级 Significator 候选；焦点宫；交点代表关系；Ruling Planets 原始来源。
- **求解**：输出目标上升、实算上升、残差与评估次数。
- **不输出**：yes/no、verdict、总分、confidence。
- **界面**：数字总览、行星层级、宫头层级、行星征象、宫位征象、焦点宫 + 诊断/JSON。
- **导出 / AI**：Markdown / JSON / CSV；无 AI。

### 6.11 吠陀 / Jyotish

#### `vedic`

- **输入**：`birth`、`reference`、`full`（布尔）、可选 `vargas`、`dasas`、`yogas`、`shadbala`。
- **`full=true`**：`vargas=["D1","D9"]`、`dasas=["vimshottari","yogini","ashtottari"]`、`yogas=true`、`shadbala=true`，并追加完整分区与评分区块。
- **输出**：
  - 基础：`meta`、`rasi_chart`、`planets`、`panchanga`、`solar_day`、`navamsa`、`divisional_charts`、`moon_chart`、`bhava_chart`；
  - 点位：`upagrahas`、`special_lagnas`、`arudha`、`jaimini_karakas`；
  - 关系：`planet_relationships`；
  - 评分：`ashtakavarga`、`shadbala`、`yogas`；
  - 时间：`vimshottari`、`yogini_dasa`、`ashtottari_dasa`。
- **分盘**：固定 16 个：D1、D2、D3、D4、D7、D9、D10、D12、D16、D20、D24、D27、D30、D40、D45、D60。
- **Dashas**：Vimshottari 含出生宿、余额、maha dasa 列表、当前大运；Yogini 与 Ashtottari 同理。
- **Shadbala**：六类 bala、总分、rupas、最低要求、是否满足、状态与说明。
- **Ashtakavarga**：BAV 按行星、SAV 汇总。
- **Yogas**：名称、分组、说明、效果、涉及行星、是否仅条件、是否需要强度复核。
- **已知占位**：`kalachakra_dasa` 仍是占位接口，不得当成完整算法。
- **界面**：综览、Pañcāṅga、Daśā、Ṣaḍbala、Yōga、Navāṃśa、Varga、Jaimini、Aṣṭakavarga、关系 + Moon Chart、Bhava、副行星、特殊 Lagna、诊断、JSON。
- **导出 / AI**：Markdown（按 section 选择）/ JSON / CSV；有 AI。

### 6.12 生时矫正

#### `rectify` — 三级窗口

- **输入**：`birth_date`、`center_time`、`timezone`、`latitude`、`longitude`、`house_system`、`zodiac`、`bounds_system`、`triplicity_system`、`max_age`、`window_minutes`、`step_minutes`；二级/三级用 `offset_seconds`、`window_seconds`、`step_seconds`。
- **三级参数**：

| 级别 | 精度 | 默认范围 | 候选数 |
|---|---:|---:|---:|
| 1 | 1 分钟 | 中心 ±30 分钟 | 61 |
| 2 | 5 秒 | 当前 ±30 秒 | 13 |
| 3 | 1 秒 | 当前 ±5 秒 | 11 |

- **输出**：`center_offset_index`、`total_candidates`、`window_minutes` / `step_minutes` / `window_seconds` / `step_seconds`、`max_age`、`candidates`、`warnings`。每个候选含本地出生时间、偏移、四轴、行星摘要、主限候选。
- **交互**：一级由按钮启动；二、三级在上一级滑杆停止后自动运行；旧请求用 generation 失效；后端通过 stderr 输出进度。
- **界面**：滑杆 + 候选表 + 过滤（Prom / Sig / 相位 / 方向）；工作区切换“方向浏览 / 事件证据”。
- **导出 / AI**：无 Markdown/CSV 工具栏；无 AI。

#### `rectify_evidence` — 事件证据包

- **输入**：`birth`、`events`（结构化人生事件窗口）、`display_timezone`、`candidate_window_seconds`、`candidate_step_seconds`、`primary_direction_keys`、`target_angle_ids`、`max_age`、`max_evidence_rows_per_family`。
- **输出**：`schema`（`rectification-evidence-packet/1.0`）、`meta`、`requested_config`、`method_profiles`、`events`、`candidates`、`warnings`、`calculation_assumptions`。
- **方法族**：`primary_motion`、`transit`、`secondary_progression`、`solar_arc`；各自声明独立性组、包含/排除范围与状态。
- **规则**：只计算当前滑杆候选；方法分族输出；不生成总分、不自动选定出生时间；命中数不是评分。
- **界面**：事件编辑器 + 分组证据结果；无导出工具栏、无 AI。

---

## 7. 星盘图

- 支持：本命单盘、时间点双盘、返照双盘、迁移双盘、古典盘、Horary 盘。
- 输入是统一的 `ChartWheelData`：点位（行星/角点/Lots）、宫头、轴黄经、相位、未解析端点。
- 点位使用稳定 ID；短标签（日/月/金/木…）；元素配色。
- 悬停高亮；点击选中/取消；命中半径 16 pt。
- 不提供缩放/平移。
- 解析不到的相位端点进入诊断，不静默连错线。
- Horary 只画显示 orb 内的相位。
- 图形本身不参与计算；导出不包含图片（当前只导出文本/JSON/CSV）。

---

## 8. 导出

所有常规结果页有统一工具栏：

| 动作 | 说明 |
|---|---|
| 复制 Markdown | 写入剪贴板，附提示词（Horary）或标准标题 |
| 保存 Markdown | 按 `basename` 命名 |
| JSON | 完整结构化响应；Horary 用原始根 JSON 再编码 |
| CSV | 按结果类型的表格展开 |

按 section 选择：

- 古典本命：角度、宫位、行星、评分、三分主、Lots、相位、接纳、赤纬、固定星、映点、主限、沿界、时间技法、返照、Almuten、Hyleg、产前朔望、中世纪、警告。
- 吠陀：Rāśi、Navāṃśa、Nakṣatra、Daśā、Ṣaḍbala、Yōga、星座索引、Pañcāṅga、日出日落、分盘、Moon Chart、Bhava、关系、Arudha、Jaimini、Aṣṭakavarga。
- 古典进阶：每个 mode 有独立 section 目录；可把多个已计算 mode 合并成一份 Markdown（按 mode 过滤 section）。
- 其他现代模式：固定 Markdown 结构，无 section picker。

特殊约定：

- Horary Markdown 优先使用 `display.reader_markdown`；若不存在才回退 Swift 组装。
- Horary 的 JSON 导出必须保留全部原始字段。
- 生时矫正没有导出工具栏。
- CSV 为逐模式实现，列名与顺序由各 `TextExportBuilder` 重载决定。

---

## 9. AI 分析

- 协议：OpenAI-compatible Chat Completions，SSE 流式。
- 配置：Base URL、模型、API Key、reasoning effort、各场景提示词、备注。
- 提示词风格：general / natal / transit / scan / classical / horary。
- 请求：`stream=true`；DeepSeek V4 系列 max tokens 384,000，其他模型 4,096；DeepSeek 支持 thinking 开关。
- 流式渲染：token 先进入独立缓冲，按约 100 ms 节流刷新；结束后一次性写入对应模式的 `@Published` 文本。
- 失败：保留已到达的部分文本，显示错误；空响应报错。
- 上下文 = 该模式的 Markdown 报告；Horary 使用 reader_markdown + 提示词。

| 有 AI | 无 AI |
|---|---|
| 现代本命、时间点、普通窗口扫描 | 调和盘、返照、中点、推进组合盘 |
| Synastry、Composite、Davison | 迁移盘、所有现代扩展 |
| 次限推进、太阳弧 | 所有古典进阶 |
| 古典本命 | KP、生时矫正、事件证据 |
| 吠陀、Horary | 现代综合时间线（借用 scan 工作区） |

AI 面板在无上下文时显示“此页面暂不支持 AI 分析”；有上下文但未计算时显示“先完成计算”；无 API Key 时禁用分析按钮。

---

## 10. 模块地图

### 10.1 后端 mode → 模块

| mode | 模块 / 入口 |
|---|---|
| `moment` | `astro_backend_api.calculate_moment` |
| `scan` | `astro_backend_scan.scan_window` |
| `modern_timing` | `astro_backend_modern_timing.calculate_modern_timing` |
| `classical` | `astro_backend_classical`（由 api 调用） |
| `horary` V1 | `astro_backend_horary.calculate_horary` |
| `horary` V2.1 | `astro_backend_horary_v2.calculate_horary_v2` |
| `horary` V3 | `astro_backend_horary_v3.calculate_horary_v3` |
| `kp_horary` | `astro_backend_kp.calculate_kp_horary` |
| `vedic` | `astro_backend_jyotish.calculate_vedic` |
| `rectify` | `astro_backend_rectify.compute_window` |
| `rectify_evidence` | `astro_backend_rectify_evidence.compute_rectification_evidence` |
| `synastry` | `astro_backend_synastry.calculate_synastry` |
| `composite` | `astro_backend_composite.calculate_composite` |
| `davison` | `astro_backend_davison.calculate_davison` |
| `progression` | `astro_backend_progressions.calculate_progressions` |
| `solar_arc` | `astro_backend_solar_arc.calculate_solar_arc` |
| `harmonic` | `astro_backend_harmonic.calculate_harmonic` |
| `modern_return` | `astro_backend_modern_return.calculate_modern_return` |
| `midpoint` | `astro_backend_midpoints.calculate_midpoints` |
| `progressed_composite` | `astro_backend_progressed_composite.calculate_progressed_composite` |
| `relocation` | `astro_backend_relocation.calculate_relocation` |
| `modern_cycles` | `astro_backend_cycles.calculate_modern_cycles` |
| `declination_timing` | `astro_backend_declination_timing.calculate_declination_timing` |
| `retrograde_cycles` | `astro_backend_retrograde_cycles.calculate_retrograde_cycles` |
| `classical_visibility` | `astro_backend_visibility.calculate_classical_visibility` |
| `planetary_synodic` | `astro_backend_planetary_synodic.calculate_planetary_synodic` |
| `hellenistic_condition_audit` | `astro_backend_hellenistic_audit.calculate_hellenistic_condition_audit` |
| `draconic_heliocentric` | `astro_backend_draconic_heliocentric.calculate_draconic_heliocentric` |
| `classical_derivatives` | `astro_backend_classical_derivatives.calculate_classical_derivatives` |
| `time_lords_extended` | `astro_backend_time_lords_extended.calculate_time_lords_extended` |
| `method_families` | `astro_backend_method_families.calculate_method_families` |
| `primary_directions_audit` | `astro_backend_pd_audit.calculate_primary_directions_audit` |
| `distributions_pd` | `astro_backend_distributions_pd.calculate_distributions_pd` |
| `prenatal_parans` | `astro_backend_prenatal_parans.calculate_prenatal_parans` |
| `orbital_dial` | `astro_backend_orbital_dial.calculate_orbital_dial` |
| `mundane_electional` | `astro_backend_mundane_electional.calculate_mundane_electional` |
| `astrocartography` / `local_space` | `astro_backend_map.calculate_map_mode` |

共享底座：`astro_backend_core`（时间、黄道、角度、解析）、`astro_backend_ephemeris`（位置、宫位）、`astro_backend_modern_points`（点集）、`astro_backend_constants`（枚举与标签）。

### 10.2 前端关键文件

| 职责 | 文件 |
|---|---|
| 应用入口 | `TransitStudioApp.swift` |
| 主状态/布局 | `ContentView.swift` 及 `ContentView+*.swift` |
| 参数栏 | `ContentView+SidebarSections.swift` |
| 结果页 | `ContentView+ResultsPanes.swift`、各 `*Views.swift` |
| 后端调用 | `BackendClient.swift`、`RectifyClient.swift` |
| 请求模型 | `RequestModels.swift`、各 `*Models.swift` |
| 导出 | `Markdown*ExportBuilder.swift`、`TextExportBuilder.swift` |
| AI | `LLMAnalysisClient.swift`、`AIAnalysisView.swift`、`AIAnalysisViewModel.swift` |
| 星盘图 | `ChartWheelData.swift`、`ChartWheelGeometry.swift`、`ChartWheelCanvas.swift`、`ChartWheelInteraction.swift` |
| 生时矫正 | `RectifyModels.swift`、`PrimaryDirectionRectifierView.swift`、`RectificationEvidenceView.swift` |
| 设置 | `AppSettingsView.swift`、`AppState.swift` |

---

## 11. 验证基线与性能

### 11.1 当前测试

| 层 | 数量 |
|---|---:|
| Python 测试 | 1,232 |
| Swift 测试 | 234（32 suites） |
| 实时后端样例 | 44 |
| 契约 fixture | 38 |

```bash
# 完整门禁
bash check_vibe_changes.sh

# Python
.venv/bin/python -m pytest python_tests/ -q

# Swift
swift build --disable-sandbox
swift test --disable-sandbox

# 实时契约（44 个 Examples 真正跑后端再解码）
TRANSIT_LIVE_CONTRACTS=1 TRANSIT_TEST_PYTHON="$PWD/.venv/bin/python" \
  swift test --disable-sandbox --filter LiveBackendContractTests
```

> 在受限沙箱中直接 `swift build` 会因 SwiftPM manifest 调用 `sandbox-exec` 失败；使用 `--disable-sandbox`。正常终端不需要。

### 11.2 性能基线（热缓存，本机实测）

| 场景 | 当前耗时 |
|---|---:|
| `moment` 样例 | 0.04 s |
| `classical` 样例 | 0.18 s |
| `astrocartography` 样例 | 0.29 s |
| `horary` V2.1 | 1.16 s |
| `horary` V3 | 1.37 s |
| `modern_timing` 样例 | 1.46 s |
| `scan` 样例（8 天体 × 14 目标 × 5 相位 × 61 天） | 3.4 s |
| 进程启动 + Python import | 30–40 ms（冷启动约 190 ms） |

扫描样例约 433,360 次星历调用；原生 `swe.calc_ut` 约 5.8 µs/次，Python 包装约 7.5 µs/次。加一个 `(天体, 时刻)` 缓存即可把样例降到约 0.4 s（10,745 次调用），说明最大的性能杠杆是消除重复计算，而不是更换语言。

---

## 12. 重写验收清单

### 12.1 后端

- [ ] 36 个 mode 全部可调用；未知/空 mode 返回结构化错误。
- [ ] 28 个现代子模式到后端 mode 的映射与本文件 6.2 一致。
- [ ] 44 个 `Examples/` 请求都能产出可解码 JSON；顶层区块与本文件一致。
- [ ] 38 个 `SwiftTests/Fixtures/` 能解码；字段缺失/改名会显式失败。
- [ ] 时刻：IANA + 固定偏移、秒、`fold`、DST 不存在/歧义规则。
- [ ] 6 宫制、9 黄道、2 界、2 三分性、2 节点模式、11 相位、24 天体。
- [ ] 错误信封：`error` / `mode` / `missing` / `invalid`。
- [ ] 同一输入输出确定；不依赖当前时间。
- [ ] Horary 三版本路由；V3 不输出禁用结论。
- [ ] KP 1–249；不输出裁决。
- [ ] 古典 53+3 Lots、7 政返照三时段、ZR 松绑边界、Prenatal 轴约定、Hyleg 无寿命。
- [ ] 生时矫正三级参数与候选数；证据包四方法族分离。
- [ ] 现代时间线 entering/exact/leaving、多 pass、窗口裁剪。
- [ ] 吠陀 16 分盘、三种 Dasa、Shadbala、Ashtakavarga、Yogas。

### 12.2 界面

- [ ] 三实践模式导航与 20/8/2 入口数量。
- [ ] 参数栏折叠/固定/拖拽；结果 tabs 与“更多”。
- [ ] 运行、进度、取消、重跑清旧结果、generation 防串写。
- [ ] 扫描工作量阈值与确认。
- [ ] 设置四 tab；档案/预设/模板。
- [ ] 空态、诊断、原始 JSON。
- [ ] 星盘图 hover/选中；Horary 只画显示 orb。
- [ ] 导出工具栏与 section picker；古典进阶合并导出。
- [ ] AI 面板的有/无上下文、流式、部分失败保留。

### 12.3 非功能

- [ ] 本地计算不依赖网络；AI 可选。
- [ ] 300 秒超时与进程终止。
- [ ] 星历回退有 warning，不静默。
- [ ] 性能目标：`moment` < 5 ms、扫描样例 < 100 ms、首次结果 < 50 ms（重写后可验收）。

字段级细节（每个数组/对象的键）以 `Examples/` 的真实响应为准；本文件定义语义、区块与边界。若两者冲突，先修正实现或文档，不允许“都能解释”。
