# Transit Studio

Transit Studio 是一个运行在 macOS 上、基于 SwiftUI 的占星计算应用原型。界面层使用 Swift 编写，计算工作委托给随应用打包的 Python 后端，并通过 `pyswisseph` 完成。当前项目同时覆盖现代与古典两套工作流，并提供图轮、导出和 AI 辅助分析工具。

## 功能概览

- 现代工作流：
  - 计算本命盘与行运位置。
  - 计算某个特定时刻的行运对本命相位。
  - 扫描一段时间窗口内的精确相位命中、入座事件与留逆/顺行站点。
  - 支持合盘（Synastry）、组合盘（Composite）、戴维森盘（Davison）、次限推进（Secondary Progressions）、太阳弧（Solar Arc）和调和盘（Harmonic）。
  - 支持图形识别与关系/推运结果页展示，包括 patterns、cross aspects、house placements 等结构化输出。
- 古典工作流：
  - 支持古典本命盘，包含四轴、宫位、七政、Lots、相位、接纳、antiscia、时主法摘要、行星返照、Prenatal Syzygy、Almuten Figuris 与 Hyleg / Alcocoden 审计数据。
  - 支持主限（Primary Directions）与沿界推进（Circumambulations）。
  - 支持生时矫正（Rectify），采用 1 分钟 / 5 秒 / 1 秒三级滑杆细化，并显示 Python 后端实时进度。
- 卜卦工作流：
  - 支持 Horary 起盘与结果展示。
- 通用工具能力：
  - 支持星盘图（Chart Wheel）可视化。
  - 支持导出 Markdown、JSON 和类 CSV 文本格式结果。
  - 支持部分结果页的 AI 分析标签页，包括本命、时间点、窗口扫描、古典与 Horary。
  - 支持自定义天体、小行星星历策略、节点模式和小行星下载辅助。

## 项目结构

- `Sources/TransitStudio/` - SwiftUI 应用源码。
- `Sources/TransitStudio/Resources/backend/` - 随应用打包的 Python 后端源码。
- `Sources/TransitStudio/Resources/ephemeris/` - 随应用打包的 Swiss Ephemeris 文件。
- `Examples/` - 后端请求示例。
- `python_tests/` - 后端逻辑的 pytest 测试。
- `SwiftTests/` - Swift Package 测试。
- `docs/` - 项目结构、后端契约、验证说明与范围要求。
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

## 打包

```bash
./package_app.sh
```

这会创建或更新 `dist/TransitStudio.app`。请把 `dist/` 视为生成产物目录。
