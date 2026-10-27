# 汉堡占星（Hamburg / Uranian）Swift 核心

状态：可运行的独立计算核心与 CLI 后端。标准行星、宫位和 ASC/MC 继续复用现有 Python 后端；汉堡/乌拉尼亚增量算法全部在 Swift 中实现。本文记录算法、契约、精度边界与验证方式。

## 1. 交付边界

本轮只交付：

- `Sources/HamburgCore/`：纯 Swift 库，不依赖 Python、AppKit 或 SwiftUI。
- `Sources/HamburgCLI/`：`hamburg` 命令行入口，按需启动现有 `transit_calc.py` 取标准盘，再在 Swift 中完成汉堡计算。
- `HamburgTests/`：独立 Swift 测试与 Swiss Ephemeris 静态参考值。
- `HamburgExamples/sample-hamburg-request.json`：真实请求样例。
- `HamburgExamples/` 故意不放在 `Examples/`，因为现有 `LiveBackendContractTests` 会扫描 `Examples/` 并要求每个 mode 都有 Python 后端和 Swift 解码器。

本轮不做：

- 不接入 TransitStudio 导航、结果页、Markdown/CSV section picker 或 AI 面板。
- 不修改 `transit_calc.py`、`astro_backend_api.py` 或任何 Python 算法。
- 不输出完整解释文本、吉凶判断或“行星图像词典”。TNP 关键词只是传统联想，不是裁决。
- 不宣称八颗 TNP 是已确认的天文实体。

## 2. 为什么是“Swift 额外后端”

现有 App 的星历、宫位与标准行星位置由 Python + Swiss Ephemeris 提供，这部分稳定且不需要重写。汉堡占星真正新增的是：

1. 八颗 TNP 的 Kepler 星历；
2. 90°/45°/22.5° dial 与中点几何；
3. Witte 四因子和等式（planetary pictures）；
4. 太阳弧、映点、汉堡等宫。

这些都在 `HamburgCore` 中完成。CLI 的调用链是：

```text
JSON request
  -> (optional) Python transit_calc.py, mode=moment
       -> natal_positions / angles / houses / meta.natal_utc
  -> HamburgCore
       -> native TNPs + dial + midpoints + pictures + solar arc + antiscia
  -> JSON or Markdown
```

如果请求直接提供 `points` / `angles` / `houses`，则完全不会启动 Python；适合离线测试、嵌入其他前端或复算。

## 3. 文件地图

| 文件 | 职责 |
|---|---|
| `Angle.swift` | 360° 归一化、最短角距、圆周中点、dial 折叠、星座格式化 |
| `Moment.swift` | 民用时刻 + IANA 时区 → UT Julian Day；ISO-8601 解析 |
| `Precession.swift` | 黄道/赤道坐标旋转、IAU 1976 岁差、黄赤交角 |
| `SolarEphemeris.swift` | Meeus 低精度太阳黄经与日地距离；TNP 地心转换的太阳参考 |
| `Transneptunian.swift` | 八颗 TNP 的 Neely 1980 根数、Kepler 求解、地心/日心位置 |
| `Chart.swift` | `ChartPoint`、`HamburgChart`、Witte 等宫、点集去重 |
| `Options.swift` | dial、orb 单位、焦点、太阳弧方法、截断上限、dial 邻近算法 |
| `HamburgEngine.swift` | 中点轴/树、行星图像、太阳弧、映点、报告组装 |
| `Report.swift` | 稳定 snake_case Codable 输出 |
| `MarkdownRenderer.swift` | 中文 Markdown 报告 |
| `Sources/HamburgCLI/PythonBackend.swift` | 启动现有 Python 后端并解析 `moment` 输出 |
| `Sources/HamburgCLI/main.swift` | 参数、请求、输出、错误信封 |

## 4. TNP 星历

### 4.1 根数

八颗 TNP 使用 James Neely 发表在 *Matrix Magazine* VII (1980), Table I 的 J1900 根数。Swiss Ephemeris 源码将其标注为 `Neely 1980`，并采用同一组值。核心中的表为：

| TNP | M₀ (°) | a (AU) | e | ω (°) | Ω (°) | i (°) |
|---|---:|---:|---:|---:|---:|---:|
| Cupido | 163.7409 | 40.99837 | 0.00460 | 171.4333 | 129.8325 | 1.0833 |
| Hades | 27.6496 | 50.66744 | 0.00245 | 148.1796 | 161.3339 | 1.0500 |
| Zeus | 165.1232 | 59.21436 | 0.00120 | 299.0440 | 0 | 0 |
| Kronos | 169.0193 | 64.81960 | 0.00305 | 208.8801 | 0 | 0 |
| Apollon | 138.0533 | 70.29949 | 0 | 0 | 0 | 0 |
| Admetos | 351.3350 | 73.62765 | 0 | 0 | 0 | 0 |
| Vulkanus | 55.8983 | 77.25568 | 0 | 0 | 0 | 0 |
| Poseidon | 165.5163 | 83.66907 | 0 | 0 | 0 | 0 |

根数历元与坐标系：J1900 = JD 2415020.0，黄道/春分点 J1900。表中数值是事实性数据；本实现未复制 Swiss Ephemeris 或 GPL 参考项目的代码。

### 4.2 传播

对每个 TNP：

```text
n = 0.9856076686 / a^1.5              (deg/day, Gaussian daily motion)
M = M0 + n * (JD - J1900)             (mod 360)
E - e sin E = M                        (Newton iteration)
x = a (cos E - e)
y = a sqrt(1 - e^2) sin E
```

然后用 ω、i、Ω 将轨道平面位置旋转到 J1900 黄道，再按 IAU 1976 岁差旋转到目标日期的黄道/春分点。TNP 的轨道半长轴为 41–84 AU，周期约 262–765 年。

### 4.3 地心位置

行星位置是日心的；占星使用地心黄经。转换方式：

```text
TNP_geo = TNP_helio + Sun_geo
```

`Sun_geo` 由现有 Python 后端的太阳黄经/黄纬与 Swift 计算的日地距离构成。若没有太阳位置（纯点集输入），使用 Meeus 低精度太阳黄经与距离。地心转换包含最多两次光行时迭代：

```text
dt = |TNP_geo| * 499.004784 / 86400   (days)
TNP_helio(t - dt) + Sun_geo(t)
```

### 4.4 精度

`HamburgTests/Fixtures/tnp-reference.json` 由 pyswisseph 2.10.3.2 / Swiss Ephemeris 2.10.03 在 J1900、1990-01-01、J2000、2026-01-01 生成，仅作静态测试 oracle。对八颗 TNP：

- 地心黄经误差：测试容差 `< 0.02°`；实测大多数在 `0.001–0.01°`。
- 地心黄纬误差：`< 0.02°`；多数 `< 0.001°`。
- 日心黄经/黄纬：`< 0.02°`。
- 日心距离：`< 0.001 AU`。

误差来源：太阳位置采用视黄经、光行时近似、岁差常数精度、UT/TT 差异。对 1° 级别的 dial orb 工作足够；不应把该星历当作天文测量或高精度历表。

### 4.5 关键词

`UranianPlanet` 附带一组简短英文/中文关键词（结合、家庭、艺术……），仅用于报告可读性。它们不是完整判断，也不替代 Witte/Ebertin 原典。

## 5. Dial 与中点

### 5.1 圆周中点

```text
midpoint(a, b) = a + signedSeparation(a, b) / 2
```

`0°/180°` 的对径情形采用确定性 tie-break：`midpoint(0, 180) = 90`，`midpoint(180, 0) = 270`。中点轴由规范化 pair ID 排序后生成，因此报告中的轴不随输入顺序漂移。

每对点产生一条轴：

- `direct`；
- `opposite = direct + 180°`；
- 两者在 90° dial 上折叠为同一点。

### 5.2 Dial 折叠与谐波

`dial = m` 时：

```text
fold(x, m) = x mod m
dialDistance(a, b) = min(|fold(a)-fold(b)|, m - |fold(a)-fold(b)|)
```

对任意轴 `A` 与焦点 `F`，核心找最近谐波：

```text
k = round((F - A) / m)
nearest = A + k*m
distance = |shortestSeparation(nearest, F)|
harmonic = k mod (360/m)
branch = (k mod 2 == 0) ? "direct" : "opposite"
```

因此 90° dial 会把合、刑、冲、刑（270°）折叠到同一轴；45° dial 还会继续折叠半刑。`harmonic` 字段告诉读者这是第几个 90° 谐波。

`dial_modulus` 应当整除 360（360、180、90、45、22.5、11.25、5.625……），这样 `360/m` 才是整数谐波数。传入 100 这类不整除的值会 warning 并回退到 90，而不是生成无法解释的 harmonic 编号。

### 5.3 orb 单位

这是最容易误读的部分。核心显式要求 `orb_unit`：

- `zodiac`：orb 以 360° 黄经度数为单位。90° dial 上的有效距离 = `orb * 90 / 360 = orb / 4`。
- `dial`：orb 直接以所选 dial 的度数为单位。

报告同时输出：

- `orb`：**谐波等价**的 360° 度数 = `dialDistance * 360 / m`。
- `orb_dial`：dial 上的实际距离。

因此一个 `orb_dial = 0.0686°` 的 90° dial 命中，其 `orb = 0.2744°`。这不是焦点到 direct midpoint 的原始黄经差，而是折叠后的谐波等价 orb。报告还给出 `axis_longitude`（最近的谐波位置），可据此复算。

默认值：

- `midpoint_orb = 1.0`（zodiac 度）；
- `picture_orb = 1.0`（zodiac 度）；
- `solar_arc_orb = 1.0`（zodiac 度）。

Uranian 实践常用的 1°–1.5° 通常指 360° 黄经 orb；如果读者习惯“dial 上的 1°”，请把 `orb_unit` 设为 `dial` 并自行承担其约 4° 黄经等价宽度。

### 5.4 中点树

对每个焦点（默认 SUN、MOON、ASC、MC、ARIES_POINT）扫描所有中点轴，保留 `dialDistance <= midpoint orb` 的命中。排除“焦点 = 自己与另一点的中点”这种几何自指，因为它不是 Witte 图像。

`focus_point_ids: ["*"]` 或 `["ALL"]` 可扫描全点集。每个树有 `max_hits_per_tree` 截断。

### 5.5 行星图像

四因子 Witte 和等式：

```text
A + B = C + D
```

在 dial 上等价于：

```text
(A + B) - (C + D) ≡ 0 (mod m)
```

核心枚举 `C(n,4)` 个四点组合，对每个组合测试三种配对：

```text
AB|CD, AC|BD, AD|BC
```

取 dial 距离最小的一种；若 `<= picture orb` 则输出。四元组内每对按 ID 排序，两侧按 pair key 排序，得到唯一规范式。默认 `max_pictures = 300`，超过时截断并写入 warning。点数超过 64 时只扫描前 64 个点，避免病态组合爆炸。

注意：三因子中点树（`A = B/C`）与四因子和等式（`A+B=C+D`）是两类输出，不互相替代。

## 6. 太阳弧

### 6.1 三种 key

- `true_sun`：默认。年龄 = `(referenceJD - birthJD) / 365.2422`；推进时刻 = `birthJD + age`；弧 = `progressedSun - natalSun`（有符号最短角距）。推进太阳由 Swift 的 Meeus 公式计算。
- `naibod`：`0.98564733 * ageYears`。
- `custom`：`solar_arc_rate * ageYears`。

`solar_arc_method = custom` 时必须提供有限的 `solar_arc_rate`；否则 warning 并回退 Naibod。

### 6.2 方向

所有非 `.axis` 点（行星、TNP、ASC/MC、节点）加上弧，得到 `directed_positions`。输出：

- `SA(point) = natal point`；
- `SA(point) = natal midpoint`；
- 可选 `SA(midpoint) = natal point`（`include_directed_midpoints = true`）。

可开启 `include_converse_solar_arc`，用 `-arc` 生成 `direction = "converse"` 的命中。`solar_arc_orb` 独立于中点/图像 orb。

### 6.3 与现有 Python 的对照

同一出生/参考时刻（1990-01-01 12:00 Asia/Shanghai → 2026-10-26 12:00 Asia/Shanghai）：

- Python `solar_arc` 的 `arcValue = 37.454742°`；
- Swift `true_sun` 报告 `arc_degrees = 37.456993°`；
- 差约 `0.00225°`（8.1″），来自 Swift 低精度推进太阳与 Swiss Ephemeris 的差异。CLI 仍使用现有 Python 取本命太阳，因此该差异只出现在推进太阳的近似上。

## 7. 映点

对每个点：

```text
antiscion(x)      = 180° - x
contraAntiscion(x)= 360° - x
```

投影点按所选 dial 与所有本命点、所有本命中点比较，输出 `antiscion(A) = B` 或 `antiscion(A) = B/C`。默认使用 midpoint orb。90° dial 上会自然折叠 90° 谐波。

## 8. 汉堡等宫

Witte 的汉堡宫制是等宫，**0° 天秤 = I 宫**：

```text
cusps = 180°, 210°, 240°, ..., 150°
house(x) = floor(((x - 180°) mod 360°) / 30°) + 1
```

这与 Placidus/整宫都不同。`house_assignment = "hamburg"` 使用该固定宫制；`"backend"` 使用 Python 返回的 12 个宫头。报告同时保留 `backend_cusps`，便于对照。

ASC/MC 仍按传统方式由 Python 计算，只是不参与汉堡等宫的分宫。

## 9. CLI 契约

### 9.1 运行

```bash
swift run hamburg --request HamburgExamples/sample-hamburg-request.json --format json
swift run hamburg --request HamburgExamples/sample-hamburg-request.json --format markdown
swift run hamburg --request HamburgExamples/sample-hamburg-request.json --format json --output /tmp/hamburg.json
```

纯点集、不启动 Python：

```bash
swift run hamburg --request /path/to/points.json --no-python
```

指定现有后端与解释器：

```bash
swift run hamburg \
  --python /path/to/.venv/bin/python \
  --backend Sources/TransitStudio/Resources/backend/transit_calc.py \
  --request HamburgExamples/sample-hamburg-request.json
```

默认路径：

- Python：`<repo>/.venv/bin/python` → `/usr/bin/python3` → `/opt/homebrew/bin/python3` → `/usr/local/bin/python3` → `python3`（通过 `/usr/bin/env`）。
- 后端：`<repo>/Sources/TransitStudio/Resources/backend/transit_calc.py`。

### 9.2 请求

```json
{
  "moment": {
    "year": 1990, "month": 1, "day": 1,
    "hour": 12, "minute": 0, "timezone": "Asia/Shanghai"
  },
  "location": {
    "latitude": 31.2304, "longitude": 121.4737,
    "timezone": "Asia/Shanghai",
    "house_system": "hamburg"
  },
  "reference": {
    "year": 2026, "month": 10, "day": 26,
    "hour": 12, "minute": 0, "timezone": "Asia/Shanghai"
  },
  "zodiac": "tropical",
  "house_assignment": "hamburg",
  "options": {
    "dial_modulus": 90,
    "midpoint_orb": 1.5,
    "picture_orb": 1.0,
    "orb_unit": "zodiac",
    "focus_point_ids": ["SUN", "MOON", "ASC", "MC", "ARIES_POINT"],
    "max_pictures": 200,
    "max_hits_per_tree": 80,
    "max_antiscia_contacts": 120,
    "antiscia_enabled": true,
    "solar_arc_enabled": true,
    "solar_arc_method": "true_sun",
    "solar_arc_orb": 1.0,
    "include_converse_solar_arc": false,
    "display_dials": [360, 90, 45, 22.5],
    "apply_tnp_light_time": true
  }
}
```

字段说明：

- `moment`：本命时刻，必需（除非提供 `julian_day_ut` 或 `points`）。
- `location`：Python 后端需要 `latitude`/`longitude` 才能给 ASC/MC/宫位；只做点集计算时可省略。
- `reference`：太阳弧参考时刻；省略时默认不计算太阳弧。
- `points` / `angles` / `houses`：可选，提供后跳过 Python。`houses` 为 12 个宫头黄经。
- `zodiac`：目前只接受 `tropical`；显式传入非热带会返回错误。
- `house_assignment`：`hamburg`（默认）或 `backend`。
- `julian_day_ut` / `reference_julian_day_ut`：可绕过日历转换，便于测试。
- `options`：所有键可选，缺失时使用默认值。

`options` 默认值：

```json
{
  "dial_modulus": 90,
  "midpoint_orb": 1.0,
  "picture_orb": 1.0,
  "orb_unit": "zodiac",
  "focus_point_ids": ["SUN", "MOON", "ASC", "MC", "ARIES_POINT"],
  "max_pictures": 300,
  "max_hits_per_tree": 100,
  "max_antiscia_contacts": 200,
  "antiscia_enabled": true,
  "solar_arc_enabled": true,
  "solar_arc_method": "true_sun",
  "solar_arc_orb": 1.0,
  "max_solar_arc_hits": 200,
  "include_converse_solar_arc": false,
  "include_directed_midpoints": false,
  "display_dials": [360, 90, 45, 22.5],
  "apply_tnp_light_time": true
}
```

### 9.3 输出

JSON 顶层：

```text
meta
positions
houses
midpoints
trees
pictures
solar_arc
antiscia
warnings
```

`meta` 至少包含：

- `engine`, `version`, `method`
- `julian_day_ut`, `moment_utc`, `reference_utc`
- `location`, `dial_modulus`, `orb_unit`, `midpoint_orb`, `picture_orb`
- `point_count`, `tnp_model`, `ephemeris`

所有字段使用 snake_case；`warnings` 是去重排序后的字符串数组。Markdown 由 `HamburgMarkdownRenderer` 生成，包含星体位置、TNP、宫位、中点树、行星图像、太阳弧、映点与方法/来源。

## 10. 验证

```bash
swift build --disable-sandbox --scratch-path .build
swift test --disable-sandbox --scratch-path .build --filter HamburgCoreTests
```

当前测试：33 项，覆盖：

- TNP 在 J1900/J2000/1990/2026 的 Swiss Ephemeris 参考值；
- 跨 0° 中点与 180° tie-break；
- dial 折叠、谐波、90° 合/刑/冲折叠；
- 中点树与 90° 刑相命中；
- 四因子图像规范式、去重、排序、截断；
- 太阳弧 true sun / Naibod / custom / converse / 跨 0°；
- 映点与 contra-antiscia；
- 汉堡等宫与 backend 宫头；
- JSON round-trip 与 Markdown section。

真实 Python 后端 smoke：

```bash
.build/debug/hamburg \
  --request HamburgExamples/sample-hamburg-request.json \
  --format json --output /tmp/hamburg.json
```

期望：`point_count = 22`（10 行星 + 真交点 + 8 TNP + ASC/MC + Aries Point），`warnings = []`，TNP 来源为 `native_tnp`，太阳弧有 true_sun 结果。

## 11. 已知限制

1. 只支持热带黄经。恒星黄经需要先把 Python 返回的位置和 TNP 都转换到同一 sidereal frame，并明确 ayanamsha；当前未实现。
2. TNP 是数学假想点；星历精度约 0.01°，不应用于天文观测或精密历表。
3. 不计算primary directions、完整宫主星体系、固定星 parans 或解释性判断。
4. 三因子中点树只对焦点集合输出；需要全点集时用 `focus_point_ids: ["*"]`。四因子图像扫描全点集，但截断到 64 点/`max_pictures`。
5. orb 的 `zodiac` 默认口径会产生较窄的 90° dial 命中；Uranian 实践常用的“1° dial orb”请显式设 `orb_unit: "dial"`。
6. `true_sun` 的推进太阳由 Swift 低精度公式计算；与 Python Swiss Ephemeris 的弧差约 0.002°。
7. CLI 运行依赖仓库内的现有 Python 后端路径；分发独立二进制时需显式提供 `--python` 与 `--backend`，或改用 `--no-python` 的点集输入。
8. `Moment` 的 `fold` 会转交给 Python 后端；纯点集且需要精确处理 DST 重叠时刻时，请直接提供 `julian_day_ut`。
9. 报告中的 `orb` 是**谐波等价**的 360° 度数，不是焦点到 direct midpoint 的原始黄经差；`axis_longitude` 与 `orb_dial` 才是 dial 上的实际几何量。
10. 宫位目前只提供 0° 天秤起 I 宫的固定 Witte 等宫；原始汉堡资料还提到以 0° 白羊/巨蟹/摩羯为起点的三种观察设置，本版未把它们暴露为独立宫格。

## 12. 来源与许可证边界

算法与数据来源：

- James Neely, “Orbital Elements for the Transneptunian Planets”, *Matrix Magazine* VII (1980), Table I, p. 10.
- Swiss Ephemeris source `swemplan.c`（Neely 根数与 Kepler 传播参考）：<https://github.com/aloistr/swisseph/blob/master/swemplan.c>
- Swiss Ephemeris Programmer's Manual：<https://www.astro.com/swisseph/swephprg.htm>
- Astrodienst, “The Swiss Ephemeris” PDF（hypothetical bodies 说明）：<https://www.astro.com/swisseph/swisseph_acrobat.pdf>
- Hamburger Schule, “Das Häusersystem nach Alfred Witte”：<http://hamburgerschule.de/Menu/HS/Grundlagen/Hauser/hauser.html>
- Uranian astrology / Hamburg School overview（90° dial、midpoint tree、planetary picture）：<https://astrolium.com/guides/uranian-astrology>
- Midpoint / 90° dial practical notes：<https://astrolium.com/tools/midpoint-calculator>
- Witte, *Rules for Planetary Pictures*；Ebertin, *The Combination of Stellar Influences*（书目参考，未复制文本）。

许可证边界：

- 本目录代码为独立 Swift 实现，未复制 `maitreya8-reference/`（GPL）或 Swiss Ephemeris 的源代码。
- Neely 根数是事实性数值；表中的数值与 Swiss Ephemeris 文档/源码一致，仅用于计算。
- 测试 fixture 由 pyswisseph 生成，只保存数值，不包含第三方代码。
- `keywords` 为简短的传统联想词，不是从受版权保护的释义文本复制。
