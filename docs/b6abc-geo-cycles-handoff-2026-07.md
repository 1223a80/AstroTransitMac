# B6A/B6B/B6C 地理与周期交付交接（2026-07-19）

分支：`codex/feature-modern-completeness`
基线：B5A `d110b45` 之后完整实现 B6A + B6B + B6C（spike + 可计算产品路径）。

## 1. 已交付

### B6A Relocation（`mode=relocation`）

| 项 | 内容 |
|---|---|
| Method | `same_birth_utc_new_location_houses` |
| Backend | `astro_backend_relocation.py` |
| 契约 | 同一 birth UTC/JD；行星黄经共享（&lt;1e-9°）；仅重算 houses/angles；`planet_house_changes`；双向 angle overlays；**无**跨盘行星相位表 |
| UI | `ModernSubMode.relocation`：biwheel / relocated houses+angles / overlays / compare / diagnostics / json |
| 导出 | Markdown / CSV / JSON（记录两地 + 共享 birth UTC + house requested/effective） |
| Sample | `Examples/sample-relocation-request.json` |
| Fixture | `SwiftTests/Fixtures/relocation-result.json`（真实 backend 输出） |
| Tests | `python_tests/test_relocation.py` + `BackendContractTests.decodeRelocationFixtureFromRealOutput` |

### B6B modern_cycles（`mode=modern_cycles`）

| 项 | 内容 |
|---|---|
| Method | `swiss_ephemeris_cycles_v1` |
| Backend | `astro_backend_cycles.py` |
| 事件 | New/Full Moon（elongation root）、Solar/Lunar Eclipse（`swe.sol_eclipse_when_glob` / `swe.lun_eclipse_when`） |
| 可见性 | `visibility=global|location`；地点不可见**不删除**全球事件；`visible_at_location` 独立字段 |
| 本命接触 | 可选 birth + target_point_set；contact `exact_utc` **等于** cycle maximum |
| 时间线源 | 响应含 `timing_events`（`source_type=modern_cycles`），可接入时间线适配 |
| UI | `ModernSubMode.modernCycles`：events / contacts / timing / diagnostics / json |
| Sample/Fixture | `Examples/sample-modern-cycles-request.json`、`SwiftTests/Fixtures/modern-cycles-result.json` |
| Tests | `python_tests/test_modern_cycles.py` + BackendContractTests |

**已验证的 Swiss binding 签名（pyswisseph 运行时 introspect）：**

- `swe.sol_eclipse_when_glob(tjdut, flags=FLG_SWIEPH, ecltype=0, backwards=False)` → `(retflag, tret)`，`tret[0]`=global max
- `swe.lun_eclipse_when(tjdut, flags=FLG_SWIEPH, ecltype=0, backwards=False)`
- `swe.sol_eclipse_when_loc` / `swe.lun_eclipse_when_loc` / `swe.sol_eclipse_how` / `swe.lun_eclipse_how`
- 详见响应 `meta.swiss_bindings`

### B6C A\*C\*G / Local Space

| 项 | 内容 |
|---|---|
| Modes | `astrocartography`、`local_space` |
| Backend | `astro_backend_map.py` |
| ACG | 最多 10 行星 × ASC/DSC/MC/IC；MC/IC 子午线（RA−GMST）；ASC/DSC = 真高度≈0（含 ecl_lat）+ 北起顺时针东/西升降分类；物理几何固定 tropical true-of-date，不随 ayanamsha 移动 |
| Local Space | `swe.azalt` 方位/高度；物理几何固定 tropical true-of-date；great-circle **显示采样远点为近似**（`meta.unverified`） |
| UI | 线表 + map note（MapKit polyline 产品渲染列为后续 UI 迭代；**几何与 method/trace 已交付**） |
| Samples/Fixtures | `sample-astrocartography-request.json`、`sample-local-space-request.json` + 对应 Fixtures |
| Tests | `python_tests/test_map_modes.py` + BackendContractTests |

## 2. B6C Spike 答案（已记录）

1. **Swiss binding**：见上文 + `azalt(tjdut, ECL2HOR|EQU2HOR, geopos, atpress, attemp, xin)`；`sidtime` 返回 **小时**，×15 → 度。
2. **ACG 公式**：`λ_MC = RA − GMST`；`λ_IC = λ_MC + 180`；ASC/DSC = 固定纬度上 `swe.azalt` 真高度过零（输入完整黄道向量含黄纬）；升降分类用北起顺时针方位（SE 原始方位先 `(az+180)%360`）。
3. **极区 / ±180°**：ASC/DSC 采样约 ±66°；无根则跳过；polyline 在经度跳变 &gt;180° 处断段。
4. **MapKit**：macOS 13+ `MKPolyline` 可行；当前 UI 交付表格 + 说明，非完整交互地图。
5. **交叉验证**：MC 公式内部复算通过；**未**联网对照 Astro.com/Solar Fire 数值——见 `meta.unverified` / 下方空缺。

## 3. 故意留空 / 未验证

| 项 | 状态 |
|---|---|
| 第三方权威工具 ≥10 点坐标交叉 | **未做**（无离线权威表）；`third_party_cross_check_coordinates` |
| Local Space 远点测地精度 | **近似 equirectangular**；`great_circle_far_point_is_approximate` |
| Local Space 方位约定 | 已转换：SE 南点向西 → 北起顺时针 `(az+180)%360`（2026-07-19 审查修复） |
| Parans / zenith-nadir / 固定星线 / Johndro | **不做**（蓝图 v1 外） |
| 食相“影响窗” interpretive_window | **不做** |
| 5B 关系方法争议项 | **不做**（决策门） |
| 新模式 AI 分析 tab | **延后**（返回 nil） |
| MapKit 交互地图产品 | **部分**：数据就绪，完整地图 UI 后续 |

## 4. 请求形状速查

### Relocation

```json
{
  "mode": "relocation",
  "birth": { "name": "...", "moment": { "year":..., "timezone": "..." }, "latitude": 0, "longitude": 0 },
  "relocation": { "name": "London", "latitude": 51.5, "longitude": -0.1, "timezone": "Europe/London" },
  "house_system": "placidus",
  "zodiac": "tropical",
  "point_set": { "body_ids": ["SUN", "..."], "angle_ids": ["ASC","MC","DSC","IC"], ... }
}
```

### modern_cycles

```json
{
  "mode": "modern_cycles",
  "start": { "...", "timezone": "UTC" },
  "end": { "...", "timezone": "UTC" },
  "display_timezone": "UTC",
  "cycle_types": ["new_moon","full_moon","solar_eclipse","lunar_eclipse"],
  "visibility": "global",
  "location": null,
  "birth": null,
  "target_point_set": null
}
```

### astrocartography / local_space

见 `Examples/sample-astrocartography-request.json` 与 `sample-local-space-request.json`。

## 5. 验证证据

一键门禁（本机）：

```text
Python: 778 passed
Swift:  89 tests / 20 suites passed
Smokes: classical, moment, scan, horary, vedic, harmonic, modern returns/timing/midpoint/relationship,
        progressed_composite, relocation, modern_cycles, astrocartography, local_space, rectify
```

命令：`bash check_vibe_changes.sh`

Fixture 再生：

```bash
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-relocation-request.json > SwiftTests/Fixtures/relocation-result.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-modern-cycles-request.json > SwiftTests/Fixtures/modern-cycles-result.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-astrocartography-request.json > SwiftTests/Fixtures/astrocartography-result.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-local-space-request.json > SwiftTests/Fixtures/local-space-result.json
```

## 6. 如何继续

1. **MapKit 产品地图**：用 `lines[].segments` / `directions[].great_circle_points` 画 polyline；点击命中返回 `method_key` + `trace`。
2. **第三方交叉验证**：补 10 点 ACG 容差表后去掉 `unverified` 标记。
3. **时间线 UI 合入**：将 `timing_events` 以 `source_type=modern_cycles` 并入 `modern_timing` 结果页（backend 注册行已齐）。
4. **5B**：仍需用户决策，不得在施工中拍板。
5. 提交前按 AGENTS：`git status` / `git diff` / 确认门禁与本 handoff 一致。

## 7. 主要新增/修改文件

- Backend: `astro_backend_relocation.py`, `astro_backend_cycles.py`, `astro_backend_map.py`, `astro_backend_api.py`
- Swift: `GeoCyclesModels.swift`, `GeoCyclesExports.swift`, `GeoCyclesViews.swift`, `ModernResultModels.swift`, `ModernBackendClient.swift`, ContentView* 接线
- Tests: `test_relocation.py`, `test_modern_cycles.py`, `test_map_modes.py`, BackendContractTests, ModernTabStateTests
- Examples + Fixtures + `check_vibe_changes.sh` + `.github/workflows/ci.yml`
