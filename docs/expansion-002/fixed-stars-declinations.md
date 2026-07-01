# 恒星与赤纬技术规格

**状态**：规划中
**目标**：在不破坏现有管线的前提下，增加赤纬、出界、平行/反平行相位、恒星合相检测

---

## 1. 赤纬管线

### 1.1 当前状态

`astro_backend_ephemeris.py` → `calculate_body()` 调用 `swe.calc_ut(jd, body_id, swe.FLG_SWIEPH | swe.FLG_SPEED)`，返回值：

| 索引 | 含义 | 是否使用 |
|------|------|----------|
| `values[0]` | 黄经 (longitude) | ✅ |
| `values[1]` | 黄纬 (ecliptic latitude β) | ✅（存为 `latitude`，但几乎不展示） |
| `values[2]` | 距离 (AU) | ❌ |
| `values[3]` | 黄经速度 (°/day) | ✅（存为 `speed`） |
| `values[4]` | 黄纬速度 | ❌ |
| `values[5]` | 距离速度 | ❌ |

**关键发现**：`values[1]` 是黄纬，不是赤纬。后续所有 `declination` / `out_of_bounds` / 平行反平行计算必须使用赤道坐标系下的赤纬 δ，不能把黄纬 β 当成赤纬。

### 1.2 方案对比

#### 方案 A：Swiss Ephemeris 赤道坐标（默认实现）

对行星和月亮使用同一时刻的第二次 `swe.calc_ut()`，加 `swe.FLG_EQUATORIAL`：

```python
equatorial_values, equatorial_retflag = swe.calc_ut(
    jd_ut,
    spec.code,
    swe.FLG_SWIEPH | swe.FLG_SPEED | swe.FLG_EQUATORIAL,
)
right_ascension = equatorial_values[0]
declination = equatorial_values[1]
```

**优点**：
- 与 Swiss Ephemeris 的星历、章动、视位置口径一致
- 月亮、水星、金星等高黄纬天体的 OOB 判定不会漏掉
- 后续如需要赤经/赤纬速度，可直接从同一个返回数组扩展

**代价**：
- 每个天体多一次 `swe.calc_ut()`；本命/返照/行运快照规模很小，可以接受
- 需要沿用现有 fallback 策略：如果 Swiss Ephemeris 文件缺失并 fallback 到 Moshier，赤道坐标调用也要使用同一 fallback flags

#### 方案 B：完整数学转换（仅作为 fallback 或测试辅助）

如果不想二次调用 Swiss Ephemeris，必须使用完整黄道坐标 `(λ, β)` 到赤道坐标的转换。不能只用黄经 `λ`。

```python
def declination_from_ecliptic(lon: float, lat: float, obliquity: float) -> float:
    """从黄经 λ、黄纬 β、黄赤交角 ε 计算赤纬 δ。角度单位为度。"""
    lon_rad = math.radians(lon)
    lat_rad = math.radians(lat)
    eps_rad = math.radians(obliquity)
    sin_dec = (
        math.sin(lat_rad) * math.cos(eps_rad)
        + math.cos(lat_rad) * math.sin(eps_rad) * math.sin(lon_rad)
    )
    return math.degrees(math.asin(max(-1.0, min(1.0, sin_dec))))
```

`astro_backend_primary_directions.py` 中现有的 `declination(lon, obliq)` 等价于假设 `β = 0`，只适合黄纬可忽略的太阳或主限近似公式，**不得用于 OOB 判定**。月亮黄纬可达约 ±5°，简化公式会漏判出界；例如 `λ=90°`、`β=+5.3°` 时，完整赤纬约 `+28.7°`，简化公式只有约 `+23.4°`。

### 1.3 实现计划

1. **新增公共 helper**：在 `astro_backend_ephemeris.py` 或 `astro_backend_core.py` 增加赤道坐标 helper，复用 `calculate_values()` 的 Swiss/Moshier fallback 策略
2. **在 `calculate_body()` 中**：
   - 原有调用继续产出 `longitude`、`latitude`、`speed`
   - 同一 `spec` 再调用 `FLG_EQUATORIAL` 获取 `declination`
   - `right_ascension` 暂不进入 Swift UI，若输出则保持 optional
   - 新增字段 `declination`（double，赤纬 δ，非黄纬 β）
   - 保留现有 `latitude` 字段（黄纬 β，不破坏契约）
   - 新增字段 `out_of_bounds`
3. **在 Swift `PositionRow` 中**：
   - 新增 `let declination: Double?`（可选，因为旧 fixture 不返回此字段）
   - 新增 `let outOfBounds: Bool?`

---

## 2. 出界检测

### 2.1 定义

天体赤纬的绝对值超过当前黄赤交角（obliquity of the ecliptic）时，即为"出界"（Out of Bounds）。

当前（~2026）黄赤交角 ≈ **23°26'10"** = **23.4361°**。

### 2.2 判定规则

```
|declination| > obliquity  →  out_of_bounds = true
```

实际使用时取 `swe.calc_ut(jd, swe.ECL_NUT, 0)` 返回的当前真实黄赤交角（含章动）。注意：`pyswisseph` 常量名是 `ECL_NUT`，不是 C 文档中的 `SE_ECL_NUT`；返回值需要先解包。

### 2.3 适用范围

| 天体 | 是否可能出界 | 说明 |
|------|------------|------|
| 太阳 | ❌ | 永远在黄道上，赤纬 ≤ 黄赤交角 |
| 月亮 | ✅ | 黄纬可达 ±5.3°，赤纬可达 ±28.7°，最常出界 |
| 水星 | ✅ | 黄纬可达 ±7°，偶尔出界 |
| 金星 | ✅ | 黄纬可达 ±8.5°，偶尔出界 |
| 火星 | ✅ | 黄纬可达 ±7°，偶尔出界 |
| 木星 | ❌ 极少 | 黄纬仅 ±1.3°，几乎不出界 |
| 土星 | ❌ 极少 | 黄纬仅 ±2.5°，几乎不出界 |
| 恒星 | N/A | 恒星使用赤道坐标，无"出界"概念 |

### 2.4 实现

```python
def true_obliquity(jd_ut):
    ecl_nut_values, _ = swe.calc_ut(jd_ut, swe.ECL_NUT, 0)
    return ecl_nut_values[0]  # true obliquity, includes nutation


def compute_declination_and_oob(jd_ut, spec, warnings):
    """计算赤纬和出界标志"""
    equatorial_values = calculate_equatorial_values(jd_ut, spec, warnings)
    if equatorial_values is None:
        return None, None

    dec = equatorial_values[1]
    obliquity = true_obliquity(jd_ut)
    oob = abs(dec) > obliquity

    return dec, oob
```

**不要**用 `declination_from_ecliptic(lon, lat=0, obliquity)` 或 `declination(lon, obliq)` 判断 OOB。

---

## 3. 平行 / 反平行相位

### 3.1 定义

| 类型 | 条件 | 效应类比 |
|------|------|----------|
| **平行 (Parallel)** | 两星赤纬在同一侧（同北或同南），差 < 1° | 类似合相（强化） |
| **反平行 (Contraparallel)** | 两星赤纬在不同侧（一北一南），绝对值差 < 1° | 类似冲相（对立） |

### 3.2 Orb 规则

- 默认 orb：**1°00'**（赤纬差）
- 对日月可放宽至 **1°30'**
- 不区分入相 / 出相（赤纬变化缓慢，入出相区分意义不大）

### 3.3 实现位置

Phase 1：仅在本命盘（`calculate_moment` / `classical_snapshot`）中增加平行/反平行检测。

在 `astro_backend_core.py` 新增 `find_declination_aspects()` 函数：

```python
def find_declination_aspects(bodies, orb=1.0):
    """检测平行和反平行相位"""
    parallels = []
    contraparallels = []
    for i, a in enumerate(bodies):
        for b in bodies[i+1:]:
            if a.decl is None or b.decl is None:
                continue
            diff = abs(abs(a.decl) - abs(b.decl))
            if diff <= orb:
                same_side = (a.decl * b.decl) > 0
                if same_side:
                    parallels.append((a.id, b.id, diff))
                else:
                    contraparallels.append((a.id, b.id, diff))
    return parallels, contraparallels
```

Phase 2（可选）：行运扫描引擎增加 declination-based 事件。

---

## 4. 恒星合相

### 4.1 数据来源

使用 `pyswisseph` 内置的 `swe.fixstar2_ut(star_name, jd, flags)` 函数。`fixstar2_ut()` 是 Swiss Ephemeris 2.07 后推荐的批量固定星接口，比旧固定星接口更适合一次计算 30 颗恒星。

Swiss Ephemeris 固定星函数依赖星表文件 `sefstars.txt`。当前项目 `Sources/TransitStudio/Resources/ephemeris/` 只包含行星/月亮/小行星星历文件，没有 `sefstars.txt`；实现恒星功能前必须将 `sefstars.txt` 打包进同一 ephemeris 目录，或在设置中要求用户配置包含 `sefstars.txt` 的 Swiss Ephemeris 路径。没有该文件时，`swe.fixstar2_ut()` 会抛 `swisseph.Error`。

Python binding 返回值为 `(xx, stnam, retflags)`：

```python
xx, resolved_name, retflags = swe.fixstar2_ut("Regulus", jd_ut, swe.FLG_SWIEPH)
longitude = xx[0]  # 黄经
latitude = xx[1]   # 黄纬；恒星可能有很大黄纬，不要假设接近 0

eq_xx, resolved_name, retflags = swe.fixstar2_ut(
    "Regulus",
    jd_ut,
    swe.FLG_SWIEPH | swe.FLG_EQUATORIAL,
)
right_ascension = eq_xx[0]
declination = eq_xx[1]
```

**名称匹配**：`swe.fixstar2_ut` 支持英文通用名（如 `"Regulus"`、`"Spica"`）和 nomenclature name（如 `",alLeo"`）。实现时先尝试英文通用名，失败后 fallback 到带逗号前缀的拜耳/Flamsteed 缩写；不要使用裸 `"alLeo"`，因为 Swiss Ephemeris 只有在字符串以逗号开头时才按 nomenclature name 查找。

### 4.2 恒星选择

计划纳入 **30 颗恒星**，分三类：

| 类别 | 数量 | 举例 | orb |
|------|------|------|-----|
| 一等王星 (Royal Stars) | 4 | Aldebaran, Regulus, Antares, Fomalhaut | 2° |
| 一等亮星 (1st mag) | 9 | Sirius, Vega, Capella, Rigel, Procyon, Betelgeuse, Altair, Achernar, Canopus | 1° |
| 重要二等星 (2nd mag) | 17 | Algol, Spica, Denebola, Castor, Pollux, Deneb, Hamal, Ras Alhague, 等 | 0°30' |

详见 `star-catalog.md`。

### 4.3 合相判定

```python
def find_star_conjunctions(
    planet_positions,
    jd,
    star_names,
    orb_map,
    cached_star_positions,
    cached_star_positions_future,
    warnings,
    delta_days=1.0,
):
    """
    检测行星与恒星合相
    返回: [(planet_name, star_name, orb_deg, star_mag, star_nature)]
    """
    events = []
    for planet in planet_positions:
        for star_name in star_names:
            star_lon = cached_star_positions[star_name].longitude
            separation = abs(shortest_signed_angle(planet.lon - star_lon))
            max_orb = orb_map.get(star_name, 1.0)
            if separation <= max_orb:
                next_planet_lon = planet_longitude_at_jd(jd + delta_days, planet.spec, warnings)
                next_star_lon = cached_star_positions_future[star_name].longitude
                next_separation = abs(shortest_signed_angle(next_planet_lon - next_star_lon))
                events.append({
                    'planet': planet.name,
                    'star': star_name,
                    'orb': round(separation, 2),
                    'applying': next_separation < separation,
                })
    return events
```

这里的合相是占星常用的**黄经投影合相**（zodiacal conjunction），不是天文学球面角距最小。固定星可能有较大黄纬，仍按黄经差判断是否落在同一黄道度数附近。

`applying` 不能简化为 `planet.speed > 0`。顺行只表示黄经增加，不表示正在接近恒星。最稳妥的实现是计算当前 separation 和短时间后的 separation（如 `delta_days = 1/24` 或 `1.0`），后者更小才是入相。若使用速度近似，也要使用有符号黄经差与相对速度，而不是只看行星顺逆。

### 4.4 性能考虑

- 每个 jd 只需计算 30 颗恒星位置，再与约 15 个行星做内存比较；不要写成 30 × 15 次重复 `fixstar2_ut()`
- 若要判断 `applying`，额外缓存 `jd + delta` 的 30 颗恒星位置
- 仅在需要恒星数据时调用（可通过请求参数控制）
- 可缓存恒星位置（所有行星共享同一个 jd，30 颗恒星只需计算一次）

---

## 5. 前端模型改动

### 5.1 PositionRow 扩展（`TransitResultModels.swift`）

```swift
struct PositionRow: Codable {
    let bodyID: String
    let name: String
    let longitude: Double
    let latitude: Double          // 黄纬 β（保留不变）
    let declination: Double?      // 新增：赤纬 δ
    let outOfBounds: Bool?        // 新增：出界标志
    let speed: Double
    let sign: String
    let degreeText: String
    let house: Int?
}
```

### 5.2 新增模型

```swift
/// 恒星合相事件
struct FixedStarConjunction: Codable {
    let planet: String
    let star: String
    let starMag: Double
    let starNature: String    // e.g. "Mars/Jupiter"
    let orb: Double
    let applying: Bool
}

/// 赤纬相位
struct DeclinationAspect: Codable {
    let body1: String
    let body2: String
    let type: String           // "parallel" | "contraparallel"
    let diff: Double           // 赤纬差
}
```

### 5.3 古典模型扩展

`ClassicalPlanetRow` 同样增加 `declination` 和 `outOfBounds`。

`ClassicalResult` 根对象增加：
```swift
let fixedStarConjunctions: [FixedStarConjunction]?
let declinationAspects: [DeclinationAspect]?
```

---

## 6. 后端 JSON 契约变更

### 6.1 Moment 模式

```json
{
  "positions": [{
    "body_id": "SUN",
    "name": "Sun",
    "longitude": 123.45,
    "latitude": 0.0,
    "declination": 18.2,        // 新增
    "out_of_bounds": false,     // 新增
    "speed": 0.97,
    ...
  }],
  "fixed_star_conjunctions": [...],  // 新增（可选）
  "declination_aspects": [...]       // 新增（可选）
}
```

### 6.2 Classical 模式

`classical_snapshot` 返回的 `planets` 数组同样增补 `declination` / `out_of_bounds`。

根对象新增 `fixed_star_conjunctions` 和 `declination_aspects`。

### 6.3 向后兼容

- 新增字段均为 optional（Swift `?` / Python 只在请求时返回）
- 旧 fixture 不包含这些字段，`BackendContractTests` 不需要立即刷新
- 可在请求体中添加 `include_fixed_stars: true` 控制

---

## 7. 测试计划

| 测试 | 内容 |
|------|------|
| `test_declination.py` | 验算已知赤纬值（如太阳在夏至点 ≈ +23°26'，在冬至点 ≈ -23°26'，在春分点 ≈ 0°） |
| `test_out_of_bounds.py` | 已知出界月亮案例（如 2025-01-01 00:00 UTC 月亮赤纬约 -25.86° → OOB true；1990-01-01 不是出界案例） |
| `test_parallel.py` | 构造平行/反平行边界案例（赤纬差 = 0.99° → 触发；1.01° → 不触发） |
| `test_fixed_stars.py` | 在打包 `sefstars.txt` 后，至少 3 颗恒星验证：Regulus 在 ~29°Leo、Spica 在 ~23°Libra、Algol 在 ~26°Taurus；同时验证 fallback `",alLeo"` |
| `test_star_conjunction.py` | 构造太阳与 Regulus 的精确合相案例，并验证 `applying` 不是简单等于顺行 |

---

## 8. UI 改动摘要

| 视图 | 改动 |
|------|------|
| `ClassicalResultViews.swift`（行星表格） | 新增"赤纬"列（显示 ° ′ ″ + N/S），出界标记 ⬆ |
| `TransitResultViews.swift`（行运表格） | 同上 |
| `HoraryResultViews.swift` | 不展示赤纬（卜卦不需要） |
| 行运事件视图 | 事件类型新增"恒星合相"，显示恒星名+星等+orb |
| `ClassicalTimingViews.swift` | 不涉及 |

**赤纬显示格式**：`23°26′ N` / `18°12′ S` / `0°05′ N`

---

## 9. 术语表

| 中文 | 英文 | 缩写 |
|------|------|------|
| 黄经 | Ecliptic Longitude | λ (lambda) |
| 黄纬 | Ecliptic Latitude | β (beta) |
| 赤经 | Right Ascension | α (alpha) |
| 赤纬 | Declination | δ (delta) |
| 黄赤交角 | Obliquity of the Ecliptic | ε (epsilon) |
| 出界 | Out of Bounds | OOB |
| 平行 | Parallel | ∥ |
| 反平行 | Contraparallel | ⧵ |
| 自行 | Proper Motion | μ (mu) |

---

## 10. 核对资料

- Swiss Ephemeris Programmer's Manual: https://www.astro.com/swisseph/swephprg.htm
- 黄道坐标与赤道坐标转换公式: https://en.wikipedia.org/wiki/Astronomical_coordinate_systems
- 月亮赤纬极值与 lunar standstill: https://en.wikipedia.org/wiki/Lunar_standstill
- 平行 / 反平行定义: https://en.wikipedia.org/wiki/Astrological_aspect
