# Transit Studio

Transit Studio 是一个运行在 macOS 上、基于 SwiftUI 的占星计算应用。界面层使用 Swift 编写，计算工作委托给随应用打包的 Python 后端，并通过 `pyswisseph` 完成。当前项目同时覆盖现代、古典、卜卦与吠陀四套工作流，并提供图轮、导出和 AI 辅助分析工具。

## 功能概览

- 现代工作流：
  - 计算本命盘与行运位置。
  - 计算某个特定时刻的行运对本命相位。
  - 扫描一段时间窗口内的精确相位命中、入座事件与留逆/顺行站点。
  - 支持可配置 point set、Vertex / Antivertex / Equatorial Ascendant、赤纬、出界、平行 / 反平行、盘型与相位图形等结构化本命信息。
  - 支持合盘（Synastry）、组合盘（Composite）、戴维森盘（Davison）、次限推进（Secondary Progressions）、太阳弧（Solar Arc）、调和盘（Harmonic）和 Progressed Composite。
  - 支持现代 Solar / Lunar Return、本命中点轴与中点激活，以及包含 entering / exact / leaving、多次逆行命中编号的综合预测时间线。
  - 支持 Transit → Composite / Davison 等关系动态计算，并输出 point-set、method、trace 与 cross-aspect 等可审计数据。
  - 支持 Relocation、朔望与日月食周期、地点可见性、本命接触、Astrocartography 和 Local Space 计算。
- 古典工作流：
  - 支持古典本命盘，包含四轴、宫位、七政、50+ Lots、相位、接纳、antiscia、赤纬相位、固定星、尊贵与偶然状态审计。
  - 支持年 / 月小限、Firdaria、Decennials、Zodiacal Releasing、七政返照、年主与 Solar Return 综合，以及统一时间线。
  - 支持主限（Primary Directions）、沿界推进（Circumambulations）、Prenatal Syzygy、Almuten Figuris、Kurios / Oikodespotes 与 Hyleg / Alcocoden 审计数据。
  - 支持生时矫正（Rectify），采用 1 分钟 / 5 秒 / 1 秒三级滑杆细化，并显示 Python 后端实时进度。
- 卜卦工作流：
  - 支持 Horary 起盘与结果展示。
- 吠陀 / Jyotish 工作流：
  - 支持 sidereal 模式与多种 ayanamsha（Lahiri、Raman、Krishnamurti、Yukteshwar、True Citra 等）。
  - 支持 Panchanga（Tithi / Vara / Nakshatra / Yoga / Karana）与日出日落。
  - 支持 Rasi、Navamsa 以及一组 divisional charts（D1 / D2 / D3 / D4 / D7 / D9 / D10 / D12 / D16 / D20 / D24 / D27 / D30 / D40 / D45 / D60）。
  - 支持 Moon Chart、Bhava Chart、Upagrahas、Special Lagnas、Arudha、Jaimini Karakas、Ashtakavarga、Vimshottari / Yogini / Ashtottari Dasa、Shadbala 与 Vedic Yogas。
- 通用工具能力：
  - 支持星盘图（Chart Wheel）可视化。
  - 支持导出 Markdown、JSON 和 CSV / 类 CSV 文本格式结果；古典与吠陀支持按 section 选择 Markdown 导出。
  - 支持部分结果页的 AI 分析标签页，包括本命、时间点、窗口扫描、古典与 Horary；吠陀导出内容也面向 AI 消费组织。
  - 支持自定义天体、小行星星历策略、节点模式和小行星下载辅助。

## B6 后计算路线（规划中）

> 本节是后续路线，不代表这些功能已经交付。当前已实现能力以“功能概览”和后端契约为准。

下一阶段继续以“本地可计算、可复算、可审计、Markdown 可完整导出”为准绳；先输出坐标、时间、周期、相位、容许度、方法和公式证据，再考虑解释性内容。同名技法存在不同流派时，必须在请求、响应 `meta` 和 Markdown 中显式记录方法，不能静默使用未说明的默认值。

近期优先批次：

1. **B7 动态赤纬事件**：平行 / 反平行精确时间、OOB 进入与离开、赤纬停滞、orb 生命周期和多次命中。
2. **B8 行星返照与逆行周期**：把现代返照扩展到水星至外行星，补齐逆行前阴影、逆行区间、后阴影及重复触发。
3. **B9 古典可见相位与行星时**：基于 Swiss Ephemeris 计算 heliacal rising / setting、地方升落与昼夜不等时。
4. **B10 行星会合周期**：任意两星的 synodic cycle、合冲四分、周期阶段、相对速度和对本命 point set 的接触。

后续现代方向包括 Draconic、进阶次限与太阳弧方法、行星轨道节点 / 近日点 / 远日点、Heliocentric 对照、45° / 90° dial、年龄与关系调和盘。后续古典方向包括 Hellenistic planetary condition audit、完整 Dodekatemoria、Monomoiria、Topical Almutens、Profections / ZR 深化、Prenatal Syzygy 完整盘、fixed-star parans、mundane ingress 和 electional fact scanner。

Primary Directions 将先进行方法审计与外部数值交叉验证，再单独扩展 Placidus / Regiomontanus、zodiacal / mundane、direct / converse 和多种 key；不会把不同传统公式混为一个不透明的“完整主限”。

完整候选清单、优先级、输出字段、Markdown 结构、共用底层与 Definition of Done 见 [B6 后现代与古典占星计算扩展规划](docs/roadmap/modern-classical-techniques-after-b6-2026-07.md)。

## 导出能力

- 现代本命 / 时间点 / 窗口扫描：支持 Markdown、JSON 与 CSV 导出。
- 现代高级模式（Synastry / Composite / Davison / Progression / Solar Arc / Harmonic / Modern Return / Modern Timing / Midpoint / Progressed Composite / Relocation / Cycles / Astrocartography / Local Space）：支持结构化 Markdown、JSON，并按结果类型提供 CSV。
- 古典模式：支持最完整的 Markdown / JSON / CSV 导出，覆盖角点、宫位、行星、Lots、相位、接纳、时间技法、返照、主限、沿界推进、Prenatal Syzygy、Almuten、Hyleg / Alcocoden 等。
- Horary：支持结构化 Markdown / JSON / CSV 导出，覆盖问题元数据、radicality、significators、Moon storyline、receptions、lots 与 advanced candidates。
- 吠陀模式：支持带 section picker 的 Markdown 导出，以及 JSON / CSV 导出；Markdown 可覆盖基本信息、重要设置、星座索引表、Panchanga、日出日落、分盘信息、Moon / Bhava Chart、敌友关系、Arudha、Yogas、Jaimini Karakas、Ashtakavarga、Dasa 与 Shadbala。

## 项目结构

- `Sources/TransitStudio/` - SwiftUI 应用源码。
- `Sources/TransitStudio/Resources/backend/` - 随应用打包的 Python 后端源码。
- `Sources/TransitStudio/Resources/ephemeris/` - 随应用打包的 Swiss Ephemeris 文件。
- `Examples/` - 后端请求示例。
- `python_tests/` - 后端逻辑的 pytest 测试。
- `SwiftTests/` - Swift Package 测试。
- `docs/` - 项目结构、后端契约、验证说明与范围要求。
- `docs/roadmap/` - 尚未交付的计算能力路线与实施边界；路线项目不等于现有功能。
- `AGENTS.md` - 提供给 coding agent 的工作说明。

像 `.build/`、`dist/`、`.pytest_cache/`、`__pycache__/` 和 `backups/` 这类生成目录都不是 source-of-truth。

## 环境准备

```bash
cd AstroTransitMac
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

然后在 Xcode 中打开 `Package.swift` 并运行 `TransitStudio` 可执行目标，或者直接在终端使用 SwiftPM。

应用内还提供“程序设置”页，用于配置 Python 路径、外部 Ephemeris 目录、AI API 参数以及小行星下载策略。

如果应用无法找到 Python，请在应用中将 Python 路径指向虚拟环境里的可执行文件，例如：

```text
/Users/yourname/path/to/AstroTransitMac/.venv/bin/python
```

## Swiss Ephemeris

后端会优先尝试使用 Swiss Ephemeris，并在代码允许的地方回退到其他路径。随项目打包的星历文件目录为：

```text
Sources/TransitStudio/Resources/ephemeris
```

如果你要使用外部星历文件，请把应用里的 Ephemeris 文件夹设置为包含 `.se1` 文件的目录。

## 直接运行后端

```bash
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-scan-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-ingress-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-station-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-synastry-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-composite-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-davison-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-progressions-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-solar-arc-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-solar-return-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-lunar-return-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-timing-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-midpoint-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-progressed-composite-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-relocation-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-cycles-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-astrocartography-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-local-space-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-vedic-ai-request.json
```

PowerShell 等价写法：

```powershell
Get-Content -Raw -Encoding UTF8 Examples/sample-classical-request.json | python Sources/TransitStudio/Resources/backend/transit_calc.py
```

## 验证改动

```bash
python3 -m pytest python_tests/test_classical.py
python3 -m pytest python_tests
swift build
swift test
```

更多 smoke test（包括 rectify）和沙箱说明见 `docs/validation.md`。

## Git 卫生

如果你在这个仓库里继续开发，建议遵守下面这套最小流程：

```bash
git status --short --branch
git log origin/main..HEAD --oneline
```

- 先看当前工作树是否干净，以及本地 `main` 是否已经领先于 GitHub。
- 一个任务一笔提交；如果本地同时混入多类改动，先拆开再提交。
- 不要把“已经本地 commit”当成“已经同步到 GitHub”。
- 在声称任务完成前，确认对应验证已经跑过，`PLANS.md` / `CHANGELOG.md` 已同步更新，并且 `git status --short --branch` 反映的远端状态符合预期。

更详细的仓库操作约定见 [docs/git-workflow.md](docs/git-workflow.md) 和 [AGENTS.md](AGENTS.md)。

## 古典模式输出结构

`mode: "classical"` 会返回这些主字段：

```text
meta
angles
houses
planets
lots
experimental_lots
aspects
receptions
antiscia
primary_directions
circumambulations
timing
planetary_returns
prenatal_syzygy
almuten_figuris
hyleg_alcocoden
warnings
ambiguity
calculation_assumptions
```

重要契约说明：

- 太阳 / 月亮 / 水星 / 金星 / 火星 / 木星 / 土星的返照结果都位于 `planetary_returns` 中。
- 每条返照记录都包含 `previous_return`、`current_cycle_return` 和 `next_return`。
- Prenatal Syzygy 同时包含 `sun_position` 和 `moon_position`。
- Loosing of the Bond 不是普通的下一星座过渡。
- Hyleg / Alcocoden 的输出是审计数据包，不包含寿命年数。

更详细的后端契约说明见 `docs/backend-contracts.md`。

## 吠陀模式输出范围

`mode: "vedic"` 当前可返回的大块数据包括：

```text
meta
rasi_chart
planets
navamsa
panchanga
solar_day
divisional_charts
moon_chart
bhava_chart
upagrahas
special_lagnas
planet_relationships
arudha
jaimini_karakas
ashtakavarga
vimshottari
yogini_dasa
ashtottari_dasa
kalachakra_dasa
shadbala
yogas
warnings
```

其中：

- `vimshottari` 包含 Mahadasha 及其 Antardasha。
- `divisional_charts` 当前覆盖 16 个主分盘。
- `kalachakra_dasa` 仍是占位接口，不应视为完整算法交付。
- 吠陀 Markdown 导出按 AI 可消费文本组织，不等于全部字段都会在 CSV 中完整展开。

## 打包

```bash
./package_app.sh
```

这会创建或更新 `dist/TransitStudio.app`。请把 `dist/` 视为生成产物目录。
