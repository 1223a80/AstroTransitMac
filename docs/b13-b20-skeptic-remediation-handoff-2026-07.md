# B13–B20 skeptic remediation 交接说明

日期：2026-07-19
范围：审查 findings REQUEST CHANGES 的修复闭环（算法正确性 + Swift 契约 + 定义性测试 + 门禁）
基线：`origin/main` + 既有 B7–B20 16 commits；本轮在工作树完成 remediation（未强制改写历史）。

## 1. 修了什么

### B14 `time_lords_extended`
- **Lot 查找**：`fortune` / `spirit`（大小写不敏感），**禁止**静默 ASC 替代。
- 缺失 lot → `section_errors` + warning，不编造黄经。
- 响应写入 `meta.fortune_longitude` / `spirit_longitude` 与 ZR 包内 `lot_longitude`。
- **ZR L4**：顶层 `l4_periods`、`current_active_level` 可达 `L4`，LOB 检测含 L4。
- Concordance 使用稳定英文 `body_id`（+ `body_name` 显示名）。

### B17 `distributions_pd`
- 使用真实 PD 字段 `arc_signed` / `arc_abs`。
- **Naibod**：`age = |arc| / NAIBOD_RATE`。
- **Ptolemy**：`age = |arc| / 1.0`（与 Naibod 数值分化）。
- **Converse**：对 `arc_signed` 取反后按 Naibod 重算，`direction_type` 随符号更新。
- 仍为 B16 命名的简化经度/半弧代理引擎；assumptions 保持诚实。

### B15 `method_families`
- `secondary_armc_361` 文案改为 **ecliptic proxy of ARMC family**（`(361/365.2422)°/y`），非完整 361° RAMC→MC。
- 测试要求三 profile MC **两两不同**，并按公式复算 Naibod / armc 弧。

### B19 `orbital_dial`
- 中点改用 `circular_midpoint`（跨 0° 正确）。
- `nod_aps_ut` 无 `FLG_HELCTR` → `coordinate_center=geocentric`（不再误标 heliocentric）。

### B20 `mundane_electional`
- 强制 `location.latitude/longitude`；拒绝空 location。
- 时区经 `resolve_timezone`；非法时区抛错，**无**静默 UTC。

### Swift B13–B20（八模式）
- Models 保留核心结果集合（不再只 decode meta/warnings）。
- Views：与 `defaultResultTab` 对齐的 tab 列表 + 表格展示核心数据。
- Markdown/CSV/JSON 导出包含 method_key、黄经/年龄/事件等审计字段。
- `BackendContractTests` 断言 fixture decode 后核心数组非空并检查导出。
- Fixtures 由真实 sample 重生成。

## 2. 残余已知限制（诚实边界）

| 项 | 状态 |
|----|------|
| 完整 Placidus / Regiomontanus 主限 + 第三方数值表 | **未做**（B16 `external_crosscheck_status=local_se_consistent_only`） |
| 真 fixed-star rise/set/culmination parans | 仍为 **RA co-culmination proxy**（字段 `paran_class` / method_key 标明） |
| Monomoiria | 仍为 sign domicile proxy profile（显式 method_key） |
| Daily profection | 仍为 day-step proxy（显式 method_key） |
| B15 ARMC | ecliptic 黄经代理，非完整 RAMC 宫位重建 |
| Git | 历史 16 commits 仍堆在 `main` ahead of origin；本轮修复在工作树，交接时未必已分 task branch 提交 |

## 3. 如何重生成 fixtures / smoke

```bash
# 单 mode fixture（示例）
python3 Sources/TransitStudio/Resources/backend/transit_calc.py \
  < Examples/sample-time-lords-extended-request.json \
  > SwiftTests/Fixtures/time-lords-extended-result.json

# 本轮已覆盖的 B13–B20 samples
for s in \
  classical-derivatives time-lords-extended method-families \
  primary-directions-audit distributions-pd prenatal-parans \
  orbital-dial mundane-electional
do
  python3 Sources/TransitStudio/Resources/backend/transit_calc.py \
    < Examples/sample-${s}-request.json \
    > SwiftTests/Fixtures/${s}-result.json
done
```

Smoke 入口与 `check_vibe_changes.sh` / `AGENTS.md` 清单一致。

## 4. 验证命令与结果（本轮）

| 命令 | 结果 |
|------|------|
| `python3 -m pytest python_tests/ -q` | **839 passed** |
| `swift build` | **OK** |
| `swift test` | **103 tests / 20 suites OK** |
| `bash check_vibe_changes.sh` | **OK**（含 B7–B20 smokes + rectify） |
| `git diff --check origin/main...HEAD` | **OK**（exit 0；remediation commit 去掉 `test_distributions_pd.py` / `test_prenatal_parans.py` 的 EOF 空行） |
| 定义性 pytest（B14 lot、B17 arc、B15 MC、B19 mid/coords、B20 reject） | **OK** |

聚焦定义性测试文件：
- `python_tests/test_time_lords_extended.py`
- `python_tests/test_distributions_pd.py`
- `python_tests/test_method_families.py`
- `python_tests/test_orbital_dial.py`
- `python_tests/test_mundane_electional.py`
- `SwiftTests/BackendContractTests.swift`（B13–B20 core arrays）

## 5. 主要触达文件

**Backend：**
`astro_backend_time_lords_extended.py`、`astro_backend_classical_timing.py`、`astro_backend_distributions_pd.py`、`astro_backend_method_families.py`、`astro_backend_orbital_dial.py`、`astro_backend_mundane_electional.py`

**Swift：**
八组 `*Models` / `*Views` / `*Exports`、`ModernResultModels.swift`、`BackendContractTests.swift`、`ModernTabStateTests.swift`、对应 `SwiftTests/Fixtures/*`

**Tests / docs：**
上述 pytest、本交接文档、`CHANGELOG.md`、`PLANS.md`

## 6. 建议后续（非本轮阻断）

1. 将 remediation 拆成独立 task branch 提交并与 `origin/main` 同步。
2. 若产品需要完整 PD / 真 parans，另开批次 + 外部参考表。
3. 清理 `ContentView+ResultsPanes` 中重复 case 编译警告（预存，非本轮引入逻辑错误）。
