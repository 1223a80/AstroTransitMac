# Expansion 002 代码评审修复任务书（2026-07-02）

> 本文档是一次多角度代码评审（8 个查找角度 → 逐项独立验证）的产出，交给修复 Agent 执行。
> 共 5 项修复：F1、F2 为正确性/展示问题，F3 为防御性加固，F4、F5 为确认过的清理项。
> 每项都给出了精确位置、现状代码、强制修法和验收标准。**请逐字遵守约束，不要自由发挥。**

---

## 0. 全局强约束（先读完再动手）

1. **工作区状态**：当前分支 `codex/expansion-002`，工作区已有**未提交的改动**（上一轮修复）和一个**未跟踪新文件** `Sources/TransitStudio/MarkdownClassicalExpansionExportBuilder.swift`。
   - **禁止** `git checkout`、`git reset`、`git stash`、`git clean` 等任何会丢弃现有改动的操作。
   - 在现有工作区之上直接继续修改。
2. **只允许改动以下文件**（测试文件除外，见各项）：
   - `Sources/TransitStudio/Resources/backend/astro_backend_classical_lots.py`
   - `Sources/TransitStudio/Resources/backend/astro_backend_classical_medieval.py`
   - `Sources/TransitStudio/Resources/backend/astro_backend_fixed_stars.py`
   - `Sources/TransitStudio/Resources/backend/astro_backend_api.py`（仅 F2 的一行调用处）
   - `Sources/TransitStudio/Resources/backend/astro_backend_classical.py`（仅 F2 的一行调用处）
   - `python_tests/test_extended_lots.py`、`python_tests/test_medieval.py`（补回归测试）
   - `CHANGELOG.md`、`PLANS.md`（记录）
   - `package_app.sh`（仅版本号两行，见第 7 节）
   - 若任何一项修复迫使你改动此清单之外的文件，**停下来向用户报告**，不要擅自扩大范围。
3. **禁止顺手重构**：不重命名、不挪文件、不改无关格式、不加类型标注、不"优化"清单之外的代码。diff 越小越好。
4. **以下内容是有意设计，已被验证为正确，禁止"修复"**：
   - Firdaria 次限的**七曜七等分、从主限星起始、交点不拆次限**算法（`astro_backend_classical_timing.py`）——这是本分支按 Sira Uysal 主流口径的有意修正。
   - 恒星名 `Zubeneshamali`（与 `sefstars.txt` 第 901 行一致，改回旧拼写是错的）。
   - `astro_backend_classical_medieval.py` 里 `p.get("motion", "").startswith("逆")` 的逆行判断——motion 字段全链路恒为 `"逆行"/"停滞"/"顺行"`，判断正确。
   - `calculate_lots` 的 `mc` 参数缺省值与两个调用方的 `angles.get("MC", 270.0)` 兜底。
   - `find_declination_aspects` 的 `id_key` 用法及 natal_/transit_ 前缀方案。
   - 行星行的 `declination`/`out_of_bounds` 成对输出逻辑。
5. **禁止改动** `Sources/TransitStudio/Resources/ephemeris/sefstars.txt`、`dist/`、`.build/`、`docs/expansion-002/` 下的其他文档、`maitreya8-reference/`。
6. Python 测试一律沿用 `python_tests/conftest.py` 的路径机制导入模块（`from astro_backend_classical_lots import ...`），**不要**自己 `sys.path.append`。
7. 后端警告文案用中文，风格对齐现有文案（参考 `astro_backend_fixed_stars.py` 里的 `固定星计算失败：...`）。
8. 下文引用的行号是写作时点的行号，执行时可能有 ±几行漂移。**以符号名和引用的代码原文定位**，不要盲改行号。

---

## F1（P1，正确性/展示）magistery 公式文本显示为 "ASC + 0° - Sun"

### 现状

文件：`Sources/TransitStudio/Resources/backend/astro_backend_classical_lots.py`

- 第 ~194 行，magistery 注册时用 `"lon:0"` 占位（真实语义是 MC）：

```python
reg("magistery",  "权威点",   "Magistery",   "ASC + MC - Sun",          "ASC + Sun - MC",         "career","Bonatti","lon:0","planet:SUN")  # MC at 0° of 10th sign in Whole Sign
```

- 第 ~292-297 行，`calculate_lots()` 主循环里对 magistery 做特判，用 `mc_lon` 替换掉占位符（**数值计算是对的**）：

```python
if lid == "magistery":
    # Day: ASC + MC - Sun  → a=MC, b=Sun
    # Night: ASC + Sun - MC → a=Sun, b=MC
    a = mc_lon if is_day else _resolve_lot_ref(p1, computed, positions, asc)
    b = _resolve_lot_ref(p2, computed, positions, asc) if is_day else mc_lon
    lon = lot_value(asc, a, b)
```

- 第 ~305-312 行，输出行的公式文本却由 `_formula_text()` 按参数说明符**重新推导**，`"lon:0"` 被渲染成 `0°`；注册时人工写好的 `lot_def["day_formula"]`/`["night_formula"]`（reg() 第 141-142 行存入）从未被使用：

```python
day_f, night_f = _formula_text(
    lot_def["day_p1"], lot_def["day_p2"],
    lot_def["night_p1"], lot_def["night_p2"],
)
used_f = day_f if is_day else night_f
formula_text = f"昼 {day_f}；夜 {night_f}"
```

结果：App 界面与 Markdown 导出中，magistery 显示 `昼 ASC + 0° - Sun；夜 ASC + Sun - 0°`。

### 强制修法：把 `mc` 提升为一等参数说明符（不要用其他方案）

按以下五步改，全部完成，缺一不可：

1. `_resolve_lot_ref()`（第 ~221 行）签名追加关键字参数 `mc: float | None = None`，并在 `if ref in computed:` 之后、`planet:` 分支之前加：

   ```python
   if ref == "mc":
       return mc if mc is not None else house_cusp_lon(10)
   ```

2. magistery 的注册行改为 `"mc","planet:SUN"`（替换 `"lon:0","planet:SUN"`），行尾那句 `# MC at 0° ...` 注释一并删除。`reg()` 的夜间自动反转（`night_p1=day_p2, night_p2=day_p1`）会自然给出 夜=ASC+Sun−MC，**不要**额外显式传 night 参数。
3. **删除** `calculate_lots()` 主循环里 `if lid == "magistery":` 整个特判分支（含注释），让 magistery 走通用路径；通用路径的两处 `_resolve_lot_ref(...)` 调用补传 `mc=mc_lon`。
4. `_formula_text()` 内部的 `fmt()`（第 ~240 行附近）在 `planet:` 分支之前加：

   ```python
   if spec == "mc":
       return "MC"
   ```

5. `mc_lon = mc if mc is not None else house_cusp_lon(10)` 这一行保留不动。

**不改** reg() 存入的 `day_formula`/`night_formula` 字段（它们继续作为注册处的参考文本，允许保持未使用状态）。

### 验收标准

- `calculate_lots(...)` 输出中 `lot_id == "magistery"` 的行：`formula` 字段（或对应 key，以 `point_row` 实际字段为准）等于 `昼 ASC + MC - Sun；夜 ASC + Sun - MC`。
- 数值不回归：昼盘 `lon == lot_value(asc, mc, sun_lon)`，夜盘 `lon == lot_value(asc, sun_lon, mc)`（与修改前特判分支的结果逐位一致）。
- 在 `python_tests/test_extended_lots.py` 新增回归测试（沿用现有 class 风格）：
  - 用合成输入直接调 `calculate_lots`（例如 `angles={"ASC": 100.0, "MC": 10.0}`、positions 含 SUN/MOON 等必需行星、`cusps=[i*30.0 for i in range(12)]`），分别断言昼、夜两种 `is_day` 下 magistery 的数值与公式文本；
  - 断言 magistery 的公式文本包含 `"MC"` 且不包含 `"0°"`。

---

## F2（P1，健壮性）单颗行星星历失败会让整个 lots 计算崩溃

### 现状

- `_resolve_lot_ref()` 第 ~227 行对 `positions[pid]["longitude"]` 直接取值，无守卫。
- 上游 `calculate_positions()` 会**静默丢弃**计算失败的天体（`if row is not None: rows.append(row)`），所以 positions dict 可能缺 key。
- `calculate_lots()` 的 56-lot 主循环（第 ~279-325 行）**没有任何 try/except**：第一个引用缺失行星的 lot 抛 `KeyError`，整个请求失败。

### 强制修法

1. `calculate_lots()` 签名追加关键字参数 `warnings: list[str] | None = None`（放在 `mc` 之后）。
2. 主循环内，把"解析参数 + 计算 lon"的部分（即 `p1 = ...` 到 `computed[lid] = lon` 之前的取值计算段）包进：

   ```python
   try:
       ...现有解析与计算...
   except KeyError as exc:
       if warnings is not None:
           warnings.append(f"阿拉伯点 {name_cn}({lid}) 计算失败：缺少 {exc.args[0]} 数据，已跳过")
       continue
   ```

   **约束**：
   - 只捕获 `KeyError`，**禁止**捕获裸 `Exception`（避免掩盖真实 bug）。
   - 失败的 lot 不写入 `computed`、不产出 row；依赖它的后续 lot 会各自再触发 KeyError → 各自跳过并各自记 warning。这是预期行为，不要额外做依赖图分析。
3. 两个调用方各补传 warnings（两处都已有 `warnings` 变量在作用域内）：
   - `astro_backend_api.py` 第 ~135 行：`calculate_lots(angle_values, lot_positions_by_id, cusps, is_day, mc=mc_lon, warnings=warnings)`
   - `astro_backend_classical.py` 第 ~544 行：`calculate_lots(angles, planet_positions, cusps, is_day, mc=angles.get("MC", 270.0), warnings=warnings)`

### 验收标准

- 在 `python_tests/test_extended_lots.py` 新增测试：构造缺少 `SATURN` 的 positions dict 调 `calculate_lots(..., warnings=w)`：
  - 不抛异常；
  - 返回的 rows 中不含任何引用 SATURN 的 lot（如 `nemesis`、`dignity`）；
  - `w` 中至少有一条包含 `"SATURN"` 的中文警告；
  - 不引用 SATURN 的 lot（如 `fortune`、`spirit`）仍正常产出。
- 传入完整 positions 时，输出 rows 数量与修改前完全一致（无意外跳过）。

---

## F3（P2，防御性）年主星宫位标签的列表索引无边界检查

### 现状

文件：`Sources/TransitStudio/Resources/backend/astro_backend_classical_medieval.py`，函数 `profection_solar_return_synthesis()`（起始于第 ~230 行），第 ~279 行：

```python
"house_label": ["","1st","2nd","3rd","4th","5th","6th","7th","8th","9th","10th","11th","12th"][p.get("house", 0)],
```

正常路径下 `house_for_longitude()` 保证 house ∈ 1..12，但日返快照数据一旦畸形（house 缺失 → 0 → 静默空标签；house > 12 → `IndexError` 直接炸掉整个 synthesis）。

### 强制修法

1. 在该文件模块顶部（常量区）新增：

   ```python
   _HOUSE_LABELS = ["", "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th", "11th", "12th"]
   ```

2. 构造 `lord_in_sr` 的循环体内，把内联列表索引替换为守卫式取值（`house` 变量已同时供 `"house"` 字段使用）：

   ```python
   house = p.get("house", 0)
   ...
   "house": house,
   "house_label": _HOUSE_LABELS[house] if 0 <= house <= 12 else "",
   ```

3. **只改这一处**。第 ~322 行 `lord_in_sr.get("house_label", ...)` 是消费方，不改。

### 验收标准

- 在 `python_tests/test_medieval.py` 新增测试：构造 `solar_return_snapshot` 中年主行 `house = 13`（以及 `house` 缺失两种 case）调用 `profection_solar_return_synthesis`，断言不抛异常且 `house_label == ""`。
- 正常输入（house=1..12）时 `house_label` 与修改前一致。

---

## F4（P3，清理）删除 lots 模块的死代码块

### 现状

`astro_backend_classical_lots.py` 中存在被新的 `reg()`/`_resolve_lot_ref()` 注册管线完全取代的旧机制，全仓（`Sources/` + `python_tests/`）零调用点：

- `_day_night_simple()`（第 ~60-67 行）
- `_resolve()`（第 ~75-89 行）
- `_resolve_args()`（第 ~92-93 行）
- `_make_calc()`（第 ~96-110 行）
- 以及第 ~55-58 行紧邻的过时注释块（`# Lot definitions: ... lambda-style approach at calc time.`）和第 ~69-73 行的过时注释（`# Pre-computed extended lot definitions ...`）

### 强制修法

1. 动手前先自行验证零引用（必须执行，结果须只剩定义处）：

   ```bash
   grep -rn "_day_night_simple\|_resolve_args\|_make_calc\|[^t]_resolve(" Sources/ python_tests/
   ```

   注意 `_resolve(` 的匹配要排除 `_resolve_lot_ref(`——上面模式已通过 `[^t]` 处理，若你调整模式，务必保证不会把 `_resolve_lot_ref` 误算进去。
2. 确认后整块删除上述 4 个函数及其伴随注释。**不要**动 `_resolve_lot_ref()`、`reg()`、`LOT_LIST`、`lot_value()`、`house_cusp_lon()`、`exaltation_lon()`。
3. 若删除后出现未使用的 import，一并清掉（仅限因本次删除而失效的）。

### 验收标准

- 上述 grep 在删除后零命中；`python3 -m pytest python_tests/ -q` 全绿。

---

## F5（P3，复用）fixed_stars 内联重写了 core 已有的几何工具函数

### 现状

`astro_backend_core.py` 已提供（语义与内联代码完全一致）：

```python
def norm360(value: float) -> float:          # 第 ~211 行
    return value % 360.0

def angular_separation(a: float, b: float) -> float:   # 第 ~253 行
    diff = abs((a - b) % 360.0)
    return min(diff, 360.0 - diff)
```

`astro_backend_fixed_stars.py` 第 10 行只 `from astro_backend_core import swe`，然后：

- 第 ~84 行内联：`lon = values[0] % 360.0`
- 第 ~126-127 行内联：`sep = abs((p_lon - star["longitude"]) % 360.0)` + `sep = min(sep, 360.0 - sep)`

### 强制修法

1. import 行改为：`from astro_backend_core import swe, norm360, angular_separation`
2. 第 ~84 行改为：`lon = norm360(values[0])`
3. 第 ~126-127 两行合并为一行：`sep = angular_separation(p_lon, star["longitude"])`
4. **此文件不做任何其他改动**（`compute_star_positions` 的两次 `swe.fixstar_ut` 调用是必要的——黄道与赤道坐标各取一次，禁止合并）。

### 验收标准

- `python3 -m pytest python_tests/test_fixed_stars.py -q` 全绿（现有恒星合相/赤纬断言即回归保障，数值应逐位不变）。

---

## 6. 门禁（全部必须通过，缺一不可）

按顺序执行，任何一步失败先修到通过再继续；**禁止**跳过或弱化断言来"让测试变绿"：

```bash
# 1. 聚焦测试
python3 -m pytest python_tests/test_extended_lots.py python_tests/test_medieval.py python_tests/test_fixed_stars.py -q
# 2. 全量 Python
python3 -m pytest python_tests/ -q
# 3. Swift
swift build && swift test
# 4. 项目验收门禁
./check_vibe_changes.sh
```

## 7. 记录与打包

1. `CHANGELOG.md`：按现有格式追加本轮 5 项修复的条目（中文，注明 F1-F5 内容概要）。
2. `PLANS.md`：按仓库约定在顶部新增一节任务表并全部勾选（参考文件里已有各节的格式）。
3. 打包（按 `AGENTS.md` 约定，无特殊说明默认覆盖 `/Applications`）：
   - `package_app.sh` 顶部 `APP_VERSION="1.1.11"` → `"1.1.12"`，`BUILD_VERSION="31"` → `"32"`；
   - 运行 `./package_app.sh`，确认 codesign 通过、产物无 `__pycache__` 污染、安装版 backend smoke 正常；
   - 若打包环境不可用，**明确报告跳过原因**，不要假装完成。
4. 提交：门禁全绿后一次性提交，提交信息建议 `fix: expansion-002 评审修复（magistery公式文本/lots容错/宫位标签守卫/死代码/复用core工具）`。**只 commit，不 push**。

## 8. 完成定义（DoD）

- [ ] F1-F5 全部按"强制修法"逐条落实，无清单外改动
- [ ] 新增回归测试全部存在且有实际断言（F1 数值+文本、F2 缺行星容错、F3 越界宫位）
- [ ] 第 6 节 4 条门禁全部通过，输出贴在结果报告里
- [ ] CHANGELOG.md / PLANS.md 已更新
- [ ] 版本号递增并打包覆盖 /Applications（或明确说明跳过原因）
- [ ] 最终报告逐项列出 F1-F5 的实际改动文件与行、测试结果、以及任何偏离本文档的地方（理想情况为零偏离）
