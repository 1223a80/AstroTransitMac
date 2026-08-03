# Transit Studio

Transit Studio 是一款面向 macOS 的本地占星计算工作台。应用界面使用 SwiftUI，计算层使用 Python 与 Swiss Ephemeris；Swift 通过启动随应用打包的 `transit_calc.py` 子进程，以 stdin/stdout JSON 契约取得计算结果。

最近已打包版本为 **1.4.6 (48)**。项目覆盖现代、古典、Horary 与吠陀工作流，并提供星盘图、结构化结果页、Markdown / JSON / CSV 导出、部分模式的流式 AI 分析，以及三级生时矫正；本版完成 Horary v2.1 剩余审计项，并收口行星日/时、事件窗口、秒精度、schema 与证据展示。

> Transit Studio 首先是一套“可计算、可复算、可审计”的数据工具。部分模块只输出事实、方法与证据，不自动给出吉凶、寿命、择时推荐或 Horary 最终判断。

## 当前状态

| 项目 | 当前实现 |
|---|---|
| 最近已打包版本 | 1.4.6 (48) |
| 本版发布重点 | Horary v2.1 审计收口、时区/事件/VOC 修复、秒精度与 schema 强校验 |
| 系统要求 | macOS 13 或更高 |
| 应用架构 | Swift Package executable；当前打包脚本生成 arm64 `.app` |
| 前端 | SwiftUI |
| 后端 | Python 3 + `pyswisseph` |
| 星历 | 仓库内置 Swiss Ephemeris 文件，也可配置外部 `.se1` 目录 |
| 后端协议 | 单次 JSON 请求写入 stdin，JSON 响应写入 stdout |
| Horary 默认协议 | `horary-data-packet/2.1`，判断无关的数据包 |
| AI | OpenAI-compatible Chat Completions / SSE 接口；需要用户自行配置 Base URL、模型和 API Key |
| 自动化验证 | GitHub Actions 在 push 与 pull request 上执行 Swift、Python 和后端 smoke |
| 当前源码门禁 | Python 980 项、Swift 214 项 / 28 suites、Swift build 与全部登记 smoke 通过 |

## 当前已交付能力与 B18 增量

1.4.6 是最近已打包并验证的发布基线；当前源码包含 B7–B20 计算扩展、古典进阶工作区、Horary v2.1、主窗口布局收口、B18 固定星 paran 真实事件引擎与可读 Markdown 导出。以下均为已经接入 UI、后端、模型、导出与测试的现有能力，不是 roadmap。

### B7–B20 计算扩展

| 批次 | 已交付能力 | 当前入口 |
|---|---|---|
| B7 | 动态赤纬时间线：平行、反平行、OOB 进入 / 离开、赤纬停滞、多 pass | 现代 → 赤纬事件 |
| B8 | 太阳、月亮、水星至冥王星及 Chiron 返照；真实 station 驱动的前阴影、逆行区间、后阴影与重复触发 | 现代 → 返照盘 / 逆行阴影 |
| B9 | Swiss Ephemeris heliacal phases、地方升落、昼夜不等行星时 | 古典进阶 → 可见相位 / 行星时 |
| B10 | 任意两星的 synodic cycle、合冲刑等相位阶段、相对速度、pass 和本命接触 | 现代 → 会合周期 |
| B11 | Hellenistic condition evidence：sect、hayz、oriental / occidental、overcoming、enclosure 等 | 古典进阶 → 希腊状态审计 |
| B12 | 真 / 平交点 Draconic 移位盘与 heliocentric 坐标对照 | 现代 → Draconic / 日心 |
| B13 | Dodekatemoria、Monomoiria、Topical Almutens | 古典进阶 → 派生盘 / 尊贵 |
| B14 | Profection 扩展、ZR L4、Fortune / Spirit 与多技法 concordance | 古典进阶 → 时间主扩展 |
| B15 | Secondary Progression / Solar Arc 多 method profile 事实对照 | 现代 → 推运方法族 |
| B16 | 当前 Primary Directions 算法命名、profile、限制、诊断与审计 | 古典进阶 → 主限审计 |
| B17 | 多 significator Circumambulations / Distributions 与多 PD profile | 古典进阶 → 沿界 / 主限扩展 |
| B18 | 可复核的 prenatal syzygy chart packet；固定星与行星的本地升、上中天、落、下中天真实事件配对；RA 代理独立作为 legacy 迁移输出 | 古典进阶 → 产前朔望 / Parans |
| B19 | Swiss Ephemeris 轨道节点、近日点 / 远日点和 45° / 90° 等 modulus dial pictures | 现代 → 轨道点 / Dial |
| B20 | 四至点太阳 ingress 与 electional fact matrix；不做吉时排名 | 古典进阶 → 世俗 / 择时事实 |

### Horary v2.1

- 默认生产入口从旧解释型响应升级为 `horary-data-packet/2.1`。
- 相位计算与显示 orb 解耦：完整保留候选与未来 exact，盘面只绘制当前显示 orb 内相位。
- 新增 event graph、前后 sign / house change、月亮接触序列和 VOC 规则证据。
- 新增 mean / true nodes、偶然状态、完整接纳、行星日时、considerations evidence。
- 新增赤纬、antiscia contacts、固定星与 Swiss `pheno_ut` 数据。
- 输入配置、时间地点、星历方法、numeric precision 和 provenance hash 可复核。
- Swift 模型、图轮、结果 tabs、Markdown / JSON / CSV 与 AI 上下文全部迁移到 v2.1。
- 旧 `packetVersion=1` 保留为显式兼容入口，并补齐时刻、时区、选项、最早事件和精确去重校验。

### 古典进阶 UI 与工作区

- 现代、古典、吠陀三种实践模式拥有独立导航语义。
- 八个古典进阶入口从现代长列表中移入“古典进阶”分组。
- 每个进阶模式拥有明确的运行按钮、参数栏、结果 tabs、空态、方法说明和诊断区。
- 结构化展示 ZR、Primary Directions、Distributions、Prenatal packet 和世俗 / 择时事实矩阵。
- 计算结果按 mode 独立缓存；切换后仍可回看先前结果。
- 支持逐 mode Markdown section picker，并可合并多个古典进阶结果。
- 古典本命“主限”和“产前朔望”可深链到对应进阶工作区。

### 主窗口布局收口

- 左侧技法列表改为固定比例区域内独立纵向滚动。
- 导航收起按钮和程序设置固定，不随技法列表滚走。
- 顶部现代 / 古典 / 吠陀切换与运行按钮保持可见。
- 底部状态栏固定；超长现代技法列表不再抬高整个窗口最小高度。
- 已在紧凑窗口验证 20 个现代入口与 8 个古典进阶入口的分流和滚动行为。

## 界面工作流

窗口顶部切换三种实践模式：

- **现代**
- **古典**
- **吠陀**

左侧导航根据实践模式显示对应技法，并始终保留公共的“时间点”“窗口扫描”和底部“程序设置”。导航技法列表占据剩余高度并独立滚动；顶部实践切换、排盘按钮、状态栏和程序设置不会再被长列表挤出窗口。

主界面由以下区域组成：

1. 左侧技法导航。
2. 中间参数栏。
3. 主结果工作区。
4. 右侧可折叠 AI 分析面板。
5. 顶部实践切换与运行按钮。
6. 底部运行状态。

## 功能矩阵

### 现代工作流

现代导航当前包含 20 个独立入口：

| UI 名称 | 后端 mode | 主要输出 |
|---|---|---|
| 本命盘 | `moment` | 行星、角点、宫位、相位、结构、盘型、赤纬、OOB、固定星 |
| 合盘 | `synastry` | 双人本命数据、跨盘相位、落宫、赤纬关系 |
| 组合盘 | `composite` | Composite 行星、角点、宫位、相位与方法信息 |
| 戴维森盘 | `davison` | Davison 中点时空盘、相位、角点与宫位 |
| 次限推进 | `progression` | Secondary Progressions、推进点与本命接触 |
| 太阳弧 | `solar_arc` | Solar Arc 点位、推进方法与本命接触 |
| 调和盘 | `harmonic` | 可配置 harmonic order 的调和位置与相位 |
| 返照盘 | `modern_return` | Solar / Lunar / Mercury 等返照，前次、当前周期与下次命中 |
| 中点 | `midpoint` | 中点轴、direct / opposite 分支、焦点与激活 |
| 推进组合盘 | `progressed_composite` | 双人分别推进后再合成，保留逐点 trace |
| 迁移盘 | `relocation` | 同一出生 UTC 下的新地点宫位、角点与落宫变化 |
| 朔望食相 | `modern_cycles` | 新月、满月、日食、月食、地点可见性与本命接触 |
| 赤纬事件 | `declination_timing` | 平行、反平行、OOB 进出、赤纬停滞及生命周期 |
| 逆行阴影 | `retrograde_cycles` | 前阴影、逆行区间、后阴影和重复触发 |
| 会合周期 | `planetary_synodic` | 任意两星会合周期、相位阶段、pass 与本命接触 |
| Draconic / 日心 | `draconic_heliocentric` | Draconic 与 heliocentric 坐标对照 |
| 推运方法族 | `method_families` | 次限与太阳弧不同方法 profile 的事实对照 |
| 轨道点 / Dial | `orbital_dial` | 节点、近日点/远日点与 modulus dial pictures |
| 天体地图 | `astrocartography` | Astrocartography 线几何与可导出数据 |
| Local Space | `local_space` | 本地空间方位与方向数据 |

现代本命的 point set 可以包含：

- 十大行星。
- Chiron、Pholus、Ceres、Pallas、Juno、Vesta。
- 平 / 真交点及其南交点。
- Mean / Osculating Lilith。
- ASC、MC、DSC、IC、Vertex、Antivertex、Equatorial Ascendant。
- 显式宫头、Lots 与自定义小行星。

公共相位支持合、冲、拱、刑、六合，以及可选的 150°、30°、45°、135°、72°、144°。

### 古典工作流

古典实践模式分为本命、Horary、生时矫正和八个“古典进阶”入口。

#### 古典本命

`mode="classical"` 当前覆盖：

- 四轴、十二宫与七政。
- 50+ Lots 与实验性 Lots。
- 古典相位、接纳、antiscia、赤纬相位与固定星。
- 本质尊贵、偶然状态、昼夜盘、太阳相位与运动状态。
- 年 / 月小限、Firdaria、Decennials、Zodiacal Releasing。
- 七政返照；每颗行星统一使用 `previous_return`、`current_cycle_return`、`next_return`。
- Solar Return / 年主综合与统一时间线。
- Primary Directions 与 Circumambulations。
- Prenatal Syzygy。
- Almuten Figuris、Kurios / Oikodespotes。
- Hyleg / Alcocoden 审计数据。

重要边界：

- `planetary_returns` 是古典返照的唯一顶层入口；没有独立 `solar_return` 字段。
- Prenatal Syzygy 的满月数据同时保留太阳和月亮位置，当前轴度数约定使用太阳度数。
- Zodiacal Releasing 的 Loosing of the Bond 只在真实跳转到松绑点时标记，普通下一星座过渡不标记。
- Hyleg / Alcocoden 只输出候选、理由与证据，不输出寿命年数。

#### 古典进阶

| UI 名称 | 后端 mode | 定位 |
|---|---|---|
| 可见相位 / 行星时 | `classical_visibility` | Heliacal phases、地方升落、昼夜不等行星时 |
| 希腊状态审计 | `hellenistic_condition_audit` | Oriental / Occidental、sect、hayz、overcoming、enclosure 等证据 |
| 派生盘 / 尊贵 | `classical_derivatives` | Dodekatemoria、Monomoiria、Topical Almutens |
| 时间主扩展 | `time_lords_extended` | Profection、ZR L4、Fortune / Spirit 与多技法 concordance |
| 主限审计 | `primary_directions_audit` | 当前主限算法、profile、限制与诊断 |
| 沿界 / 主限扩展 | `distributions_pd` | 多 significator 沿界与多 PD profile |
| 产前朔望 / Parans | `prenatal_parans` | 产前朔望盘包；固定星与行星的本地升/上中天/落/下中天真实事件配对；RA 代理仅作 legacy 迁移输出 |
| 世俗 / 择时事实 | `mundane_electional` | 四至点 ingress 与择时事实矩阵，不排序“吉时” |

八个古典进阶模式拥有独立参数区、结构化结果页、Markdown 章节选择与合并导出，但当前不开放 AI 分析。

#### B18 固定星 Paran 契约

- `fixed_star_parans`（schema v2）分别使用 Swiss Ephemeris `swe.rise_trans` 求行星和固定星的 rising、culminating、setting、lower-culminating 事件，再按绝对事件时间差配对。
- 每行保留两端事件类型、UTC / 出生地本地时间、JD、`event_delta_seconds`、容许度、方法 key 与方法溯源；默认 `paran_event_orb_seconds` 为 240 秒。
- 旧的 ΔRA co-culmination proxy 不混入真实事件计数，独立位于 `legacy_fixed_star_parans`；其默认 RA 容许度为 1°，可用 `include_legacy_paran_proxy=false` 关闭。
- 极区或其他不可求得的升落事件只输出可用事件和对象级诊断，不伪造 paran；顶层 `polar_degradation` 与 warnings 说明降级范围。
- 请求样例见 [`Examples/sample-prenatal-parans-request.json`](Examples/sample-prenatal-parans-request.json)；真实事件与 legacy 迁移信息均可导出为 Markdown / CSV。

### Horary

Horary 默认走 **Data Packet v2.1**：

```json
{
  "mode": "horary",
  "packetVersion": "2",
  "chart": {
    "moment": {
      "year": 2026,
      "month": 7,
      "day": 23,
      "hour": 22,
      "minute": 25,
      "timezone": "Asia/Shanghai"
    },
    "latitude": 35.0576,
    "longitude": 118.3346,
    "houseSystem": "regiomontanus",
    "zodiac": "tropical",
    "boundsSystem": "egyptian",
    "triplicitySystem": "dorothean"
  },
  "questionText": "问题文本",
  "placeName": "地点",
  "aspectOrb": 3
}
```

v2.1 是判断无关的数据管线，主要包含：

- 输入、计算配置、时间地点和 provenance。
- 宫位、角点、天体、尊贵归属、节点与偶然状态证据。
- 全量相位候选、显示 orb 内相位、pairwise geometry。
- 精确事件、event graph、月亮事件序列与 VOC 规则。
- 接纳、Lots、赤纬、antiscia、固定星、可见性与 `pheno_ut`。
- 行星日 / 时、considerations evidence、optional modules。
- 技术校验、warnings 和显示辅助字段。

v2.1 **不自动输出**：

- 征象星选择。
- radicality 统一结论。
- yes / no。
- Translation / Collection / Prohibition / Frustration 判断。
- machine summary、score 或 confidence。

如确实需要旧解释型 packet，必须显式传 `packetVersion=1`；该入口只用于兼容，已弃用。未知版本会返回结构化校验错误。

详细说明：

- [Horary v2 架构](docs/horary-v2/README.md)
- [字段字典](docs/horary-v2/FIELD_DICTIONARY.md)
- [v1 → v2 迁移](docs/horary-v2/MIGRATION.md)
- [生产 JSON Schema](docs/schemas/horary-data-packet-2.1.json)
- [Canonical golden](docs/examples/horary-data-packet-v2-linyi-golden.json)

### 生时矫正

古典导航中的“生时矫正”使用 Primary Directions 候选进行三级细化：

| 级别 | 精度 | 默认范围 | 候选数 |
|---|---:|---:|---:|
| 1 | 1 分钟 | 中心时间 ±30 分钟 | 61 |
| 2 | 5 秒 | 当前选择 ±30 秒 | 13 |
| 3 | 1 秒 | 当前选择 ±5 秒 | 11 |

第一级由用户点击“计算生时矫正”启动；第二、三级在上一级滑杆停止后自动运行。后端通过 stderr 输出 JSON progress 行，Swift 客户端实时显示进度。

### 吠陀 / Jyotish

吠陀模式支持：

- Sidereal zodiac 与 Lahiri、Raman、Krishnamurti、Yukteshwar、True Citra 等 ayanamsha。
- Panchanga：Tithi、Vara、Nakshatra、Yoga、Karana。
- 日出日落与 solar day 数据。
- Rasi、Navamsa、Moon Chart、Bhava Chart。
- D1 / D2 / D3 / D4 / D6 / D7 / D8 / D9 / D10 / D12 / D16 / D20 / D24 / D27 / D30 / D40 / D45 / D60。
- Upagrahas、Special Lagnas、Arudha。
- Jaimini Karakas。
- 行星敌友关系与 Ashtakavarga。
- Vimshottari、Yogini、Ashtottari Dasa。
- Shadbala 与 Vedic Yogas。

`kalachakra_dasa` 仍是占位接口，不应视为完整算法交付。

### 公共时间工具

三个实践模式共用：

- **时间点**：计算指定时刻的行运位置及其对本命的接触。
- **窗口扫描**：扫描时间区间内的相位命中、ingress 与 station。

现代综合时间线另使用 `modern_timing`，支持：

- Transit → Natal。
- Secondary Progression → Natal。
- Solar Arc → Natal。
- Transit → Composite / Davison。
- Midpoint direct / opposite target。
- entering / exact / leaving 生命周期。
- clipped 边界与逆行多 pass 编号。

## 星盘图与结果页

结果工作区根据模式显示图轮、表格、时间线、分组结果、诊断和原始 JSON。星盘端点使用稳定 ID；解析不到的相位端点进入诊断，而不是静默绘制错误连线。

Horary v2.1 图轮只绘制 `aspects_in_display_orb`；orb 外未来成相保留在候选与事件数据中，不当作当前盘面相位显示。

## 导出

应用按模式提供以下格式：

- **Markdown**：面向阅读、复核和 AI 输入。
- **JSON**：保留结构化后端数据。
- **CSV / 类 CSV 文本**：按结果类型展开关键表格。

古典本命、古典进阶与吠陀支持按 section 选择 Markdown。古典进阶还支持把多个已经计算的 mode 合并为一份 Markdown。

Horary v2.1 的 Swift 模型保留原始根 JSON，JSON → Swift → JSON 不应静默丢失 `time_and_location`、`provenance`、`calculation_config`、optional modules 等字段。

## AI 分析

AI 面板使用用户配置的 OpenAI-compatible API：

- API Base URL。
- 模型名称。
- API Key。
- reasoning effort。
- 各场景默认提示词和用户备注。

响应通过 SSE 流式显示。当前有 AI 上下文的入口：

- 现代本命。
- Synastry、Composite、Davison。
- Secondary Progression、Solar Arc。
- 古典本命。
- 吠陀。
- Horary。
- 时间点。
- 普通窗口扫描。

当前没有 AI 上下文的入口包括：调和盘、返照、中点、推进组合盘、生时矫正、现代扩展模式、古典进阶模式，以及借用 scan 工作区的 Modern Timing。

AI 是可选能力；本地计算、结果页与导出不依赖 API Key。

## 架构

```text
SwiftUI views / state
        │
        ▼
BackendClient / ModernBackendClient / RectifyClient
        │  JSON request via stdin
        ▼
Resources/backend/transit_calc.py
        │
        ▼
astro_backend_api.py
        │
        ├── modern / timing / map modules
        ├── classical / audit / visibility modules
        ├── horary v2.1 modules
        ├── vedic modules
        └── rectify module
        │  JSON response via stdout
        ▼
Swift Codable models → result panes / wheel / exports / AI context
```

后端模块通过资源目录内的文件名互相导入。Swift 与 Python 之间没有内嵌解释器或私有二进制协议。

## 支持的后端 mode

当前 `astro_backend_api.validate_required_fields()` 注册 34 个 mode：

```text
moment
classical
vedic
horary
scan
rectify
synastry
composite
davison
progression
solar_arc
harmonic
modern_return
modern_timing
midpoint
progressed_composite
relocation
modern_cycles
astrocartography
local_space
declination_timing
retrograde_cycles
classical_visibility
planetary_synodic
hellenistic_condition_audit
draconic_heliocentric
classical_derivatives
time_lords_extended
method_families
primary_directions_audit
distributions_pd
prenatal_parans
orbital_dial
mundane_electional
```

未知、拼错或空 mode 会返回 JSON error，不会静默回退到其他计算。

## 项目结构

```text
AstroTransitMac/
├── Sources/TransitStudio/                 SwiftUI 应用与 Codable 模型
│   └── Resources/
│       ├── backend/                       Python 计算后端
│       └── ephemeris/                     内置 Swiss Ephemeris 文件
├── SwiftTests/                            Swift 单元与契约测试
│   └── Fixtures/                          真实后端输出 fixture
├── python_tests/                          Python pytest
├── Examples/                              每个后端 mode 的请求样例
├── docs/                                  契约、决策、验证、设计与路线
├── assets/                                应用资源
├── package_app.sh                         release 构建、签名与安装脚本
├── check_vibe_changes.sh                  一键本地门禁
├── Package.swift                          Swift Package 清单
├── requirements.txt                       Python 运行依赖
├── requirements-dev.txt                   Python 测试与契约校验依赖
├── AGENTS.md                              项目施工规则与高风险契约
├── PLANS.md                               任务计划与执行记录
└── CHANGELOG.md                           人类可读变更记录
```

以下目录不是 source of truth：

- `.build/`
- `dist/`
- `.pytest_cache/`
- `__pycache__/`
- `backups/`

## 开发环境

### 要求

- macOS 13 或更高。
- Xcode / Swift 5.9 工具链。
- Python 3。
- `pyswisseph`。

CI 当前使用 macOS 15 与 Python 3.12。

### 安装 Python 依赖

```bash
cd AstroTransitMac
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.txt
```

项目的一键门禁会优先使用 `.venv/bin/python`。

### 构建与运行 Swift 应用

```bash
swift build
swift run TransitStudio
```

也可以在 Xcode 中打开 `Package.swift`，运行 `TransitStudio` executable target。

如果应用没有找到正确的 Python，请在“程序设置 → 后端”中指向虚拟环境：

```text
/absolute/path/to/AstroTransitMac/.venv/bin/python
```

程序设置还可以配置：

- 外部 Ephemeris 目录。
- AI Base URL、模型与 API Key。
- AI 提示词。
- 小行星下载策略。

## Swiss Ephemeris

内置星历目录：

```text
Sources/TransitStudio/Resources/ephemeris/
```

如需外部星历文件，在程序设置中选择包含 `.se1` 文件的目录。计算响应会尽量保留 ephemeris、zodiac、house system 与方法 provenance，方便复算和审计。

## 直接运行后端

后端从 stdin 读取一个 JSON，并把 JSON 响应写到 stdout：

```bash
.venv/bin/python Sources/TransitStudio/Resources/backend/transit_calc.py \
  < Examples/sample-request.json
```

常用示例：

```bash
# 古典本命
.venv/bin/python Sources/TransitStudio/Resources/backend/transit_calc.py \
  < Examples/sample-classical-request.json

# Horary v2.1
.venv/bin/python Sources/TransitStudio/Resources/backend/transit_calc.py \
  < Examples/sample-horary-request.json

# 现代综合时间线
.venv/bin/python Sources/TransitStudio/Resources/backend/transit_calc.py \
  < Examples/sample-modern-timing-request.json

# 古典进阶：主限审计
.venv/bin/python Sources/TransitStudio/Resources/backend/transit_calc.py \
  < Examples/sample-primary-directions-audit-request.json

# 吠陀
.venv/bin/python Sources/TransitStudio/Resources/backend/transit_calc.py \
  < Examples/sample-vedic-ai-request.json
```

完整请求样例位于 [`Examples/`](Examples/)。

时刻对象支持 IANA timezone 和固定偏移。DST 跳时中的不存在本地时间会被拒绝；DST 回拨产生的歧义时间必须传 `fold: 0` 或 `fold: 1`。

## 验证

### 一键完整门禁

```bash
bash check_vibe_changes.sh
```

该脚本执行：

1. 全部 Python tests。
2. `swift build`。
3. `swift test`。
4. 已登记的后端 smoke，包括 rectify。
5. 个人路径 / 测试数据痕迹扫描。

### 聚焦验证

```bash
# Python 全量
.venv/bin/python -m pytest python_tests/ -q

# Horary v2.1、legacy 与跟进回归
.venv/bin/python -m pytest \
  python_tests/test_horary.py \
  python_tests/test_horary_followup.py \
  python_tests/test_horary_v2.py -q

# 古典
.venv/bin/python -m pytest python_tests/test_classical.py -q

# Swift
swift build
swift test
```

后端 JSON shape 有意变化时，必须同时更新对应 Swift Codable model 和真实输出 fixture；fixture 不应手工编辑。

详细说明见 [docs/validation.md](docs/validation.md)。

## 打包与安装

默认发布命令：

```bash
./package_app.sh
```

脚本会：

1. 使用 SwiftPM release configuration 构建。
2. 把资源 bundle 放入 `.app`。
3. 清理 `.pyc`。
4. 生成 `Info.plist`。
5. 进行 ad-hoc codesign。
6. 写入 `dist/TransitStudio.app`。
7. 默认覆盖 `/Applications/TransitStudio.app`。

只生成 `dist`、不覆盖 `/Applications`：

```bash
SKIP_INSTALL=1 ./package_app.sh
```

可用环境变量：

- `APP_OUTPUT_DIR`
- `APP_INSTALL_ROOT`
- `APP_INSTALL_PATH`
- `APP_STAGING_ROOT`
- `SWIFTPM_BUILD_PATH`
- `SKIP_INSTALL`

`dist/` 是生成产物；不要直接修改其中的应用内容。

## 关键契约与已知边界

- 出生时间与事件时间要求明确到分钟并带 timezone；项目不自动把模糊生时降级成中午盘。
- Horary 默认 v2.1 只给事实数据，不给自动判断。
- Legacy Horary 只通过 `packetVersion=1` 显式调用。
- 古典返照统一位于 `planetary_returns`。
- Hyleg / Alcocoden 不输出寿命年数。
- 世俗 / 择时模块只输出事实矩阵，不做吉时推荐或吉凶排序。
- 主限审计会明确当前算法及限制，不把不同传统公式伪装成同一个“完整主限”。
- `kalachakra_dasa` 是占位接口。
- AI 依赖外部 API，不是本地模型；计算本身不依赖 AI。
- `docs/roadmap/` 中的条目是规划，不等于当前已交付功能。

## 开发与 Git 纪律

开始修改前：

```bash
git status --short --branch
git log origin/main..HEAD --oneline
```

基本要求：

- 一个任务一个分支、一个清晰提交边界。
- 本地 commit 不等于已经同步 GitHub。
- 不把 `.build`、`dist`、pytest cache、`__pycache__` 或 backups 当源码修改。
- 先查询现有模型、调用点和 JSON 契约，再改接口。
- 计算规则变化必须增加聚焦测试。
- Swift 展示 / 导出变化至少执行 Swift build/test 和相关导出检查。
- 完成前更新 `PLANS.md`、`CHANGELOG.md`，检查 `git diff --check`、完整 diff 和测试结果。
- 不 force-push，不重写共享历史，除非得到明确授权。

完整约定见：

- [AGENTS.md](AGENTS.md)
- [Git workflow](docs/git-workflow.md)
- [Validation](docs/validation.md)

## 文档索引

- [Documentation Index](docs/README.md)
- [Project Structure](docs/project-structure.md)
- [Backend Contracts](docs/backend-contracts.md)
- [Product Decisions](docs/product-decisions.md)
- [Horary v2.1](docs/horary-v2/README.md)
- [B7–B20 UI Design](docs/ui-design-b7-b20-2026-07.md)
- [Post-B6 Roadmap](docs/roadmap/modern-classical-techniques-after-b6-2026-07.md)
- [Changelog](CHANGELOG.md)
- [Task Plans](PLANS.md)

路线文档可能包含尚未交付的候选能力；判断当前实现时，以源码、`Examples/`、后端 mode 注册和本 README 的“功能矩阵”为准。
