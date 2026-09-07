# 计算审计缺陷修复执行规范

> 收尾状态（2026-09-06）：此规范对应的 13 项改动已存在于当前源码，本轮审查与收口；不再作为待执行清单从任务 1 重跑。历史记录见 archive/plans-through-2026-09-06.md，当前状态见 current-status.md。后续补充发现不属于这 13 项已完成记录。

## 1. 执行目标

修复本文列出的 13 项缺陷。只允许修改本文明确列出的生产文件、对应测试文件、必要的契约 fixture，以及项目强制要求的 `PLANS.md`、`CHANGELOG.md`。禁止顺手重构、改 UI 文案、调整无关 schema、改变无关计算结果或打包发布。

必须按本文顺序执行。每项任务必须先新增能在旧代码上失败的测试，再修改生产代码，再运行该项聚焦测试。不得先改代码再补一个只验证新实现的宽松测试。

## 2. 全局强制规则

### 2.1 开始前

1. 完整阅读根目录 `AGENTS.md`。
2. 执行并保存输出：

   ```bash
   git status --short --branch
   git rev-parse HEAD
   ```

3. 如果工作区有与本文任务无关的改动，保留并绕开；不得覆盖、回滚、暂存或提交它们。
4. 在 `PLANS.md` 顶部新增本次修复计划，并逐项更新状态。
5. 非平凡修复必须在 `codex/fix-calculation-audit` 或操作者明确指定的任务分支完成。不得直接在共享 `main` 上混入实验提交。

### 2.2 每项任务的固定流程

每项任务必须依次完成：

1. 阅读目标函数、所有调用点、相关模型、导出代码和现有测试。
2. 新增精确失败测试，并单独运行，确认旧代码确实失败。把失败原因记录到 `PLANS.md` 对应任务项。
3. 只修改解决该失败所需的最小生产代码。
4. 再次运行聚焦测试，确认通过。
5. 运行该模块原有全部测试，确认没有回归。
6. 检查 `git diff --check` 和该项完整 diff。
7. 在 `CHANGELOG.md` 追加一条具体说明，不写“优化若干”“修复问题”等模糊文字。

### 2.3 绝对禁止

- 禁止删除或放宽现有断言来让测试通过。
- 禁止使用 `try/except Exception`、默认空值或静默 fallback 掩盖计算错误。
- 禁止硬编码本文示例的期望输出。
- 禁止通过增大 orb、扩大搜索窗口、降低精度或删字段规避失败。
- 禁止改变 Horary v2.1、KP、Rectifier 或其他未列入任务的算法。
- 禁止同时重写整个 Jyotish、Classical Timing 或 Modern Timing 模块。
- 禁止编辑 `dist/`、`.build/`、`.pytest_cache/`、`__pycache__/`、`backups/`。
- 禁止在未确认传统口径时自行发明占星规则。
- 禁止把“现有测试通过”写成“算法 100% 正确”。

### 2.4 数值测试要求

- 角度比较必须使用环形差值，不得直接比较跨 0° 的线性差。
- 除整数星座索引外，浮点结果使用 `pytest.approx` 并给出明确绝对误差。
- 时间结果必须同时断言日期、时刻和时区；不得只断言字符串存在。
- 搜索算法必须与更细步长的基准结果比较事件数量和时间，不得只断言“结果非空”。
- 每个边界至少测试“边界前、边界值、边界后”。

## 3. 修复顺序

严格按以下顺序执行：

1. Arudha Pada
2. D30 Trimsamsha
3. 8 星 Chara Karaka
4. Yogakaraka
5. Ekadhipatya Shodhana
6. Nathonatha Bala
7. Zodiacal Releasing 与 Loosing of the Bond
8. 行星会合搜索步长
9. 组合盘象限宫位平移
10. 跨 0° 星盘形态
11. Heliacal previous event
12. Alcocoden 排名
13. JD 午夜进位

任务 1–6 完成后先运行全部 Jyotish 测试；任务 7 完成后运行 Classical 测试；任务 8–10 完成后运行 Modern/Relationship 测试；任务 11–13 完成后运行相应聚焦测试。全部完成后才允许运行全量门禁。

---

## 4. 任务 1：修复 Arudha Pada 例外规则

### 4.1 允许修改

- `Sources/TransitStudio/Resources/backend/astro_backend_jyotish_arudha.py`
- `python_tests/test_jyotish_focused.py`

### 4.2 当前缺陷

`calc_arudha_pada()` 初算 Pada 后，对“落本宫”和“落对宫”统一执行：

```python
pada = (pada + 10) % 12
```

这会产生错误的 0-based 偏移。现有 `test_arudha_opposite_exception_shifts_ten_signs` 把错误行为锁成了测试期望，必须替换为规则测试，不得保留旧断言。

### 4.3 锁定规则

采用以下明确规则：

- 初算 Pada 落在原宫 `H`：结果为从原宫数第 10 宫，即 `(H + 9) % 12`。
- 初算 Pada 落在原宫对宫 `(H + 6) % 12`：结果为从原宫数第 4 宫，即 `(H + 3) % 12`。
- 其他情况返回初算 Pada，不应用例外。

不得继续使用“统一从初算 Pada 加一个常数”的实现。

### 4.4 必须新增的测试

至少覆盖：

1. 白羊宫、火星在白羊：结果为摩羯索引 9。
2. 初算 Pada 落原宫对宫：结果为原宫加 3。
3. 初算 Pada 不落本宫或对宫：结果保持正常公式值。
4. 原宫靠近双鱼时验证 `% 12` 回绕。
5. `compute_arudha()` 的 AL、UL 和 A2–A11 均保持合法索引 `0...11`。

### 4.5 完成条件

- 不再存在 `pada + 10` 的统一例外逻辑。
- 测试名称描述规则，不描述旧实现。
- 不改变返回 JSON 键。

---

## 5. 任务 2：修复 D30 Trimsamsha 偶数星座分段

### 5.1 允许修改

- `Sources/TransitStudio/Resources/backend/astro_backend_jyotish_varga.py`
- `python_tests/test_jyotish_focused.py`
- 如已有更合适的 varga 专项测试文件，可在该文件追加，但不得新建平行计算实现。

### 5.2 锁定规则

奇数星座保持现有规则：

| 宫内度数 | D30 星座 |
|---|---|
| `[0, 5)` | Aries |
| `[5, 10)` | Aquarius |
| `[10, 18)` | Sagittarius |
| `[18, 25)` | Gemini |
| `[25, 30)` | Libra |

偶数星座必须改为：

| 宫内度数 | D30 星座 | 区间长度 |
|---|---|---:|
| `[0, 5)` | Taurus | 5° |
| `[5, 12)` | Virgo | 7° |
| `[12, 20)` | Pisces | 8° |
| `[20, 25)` | Capricorn | 5° |
| `[25, 30)` | Scorpio | 5° |

### 5.3 实现要求

不能只改 `10→12`、`18→20`。区间内连续映射公式必须同步改为对应区间长度：

- Virgo 段按 7°映射完整 30°；
- Pisces 段按 8°映射完整 30°；
- Capricorn 段按 5°映射完整 30°；
- 所有偶数段保持当前反向映射方向；
- 输出必须归一化到 `[0, 360)`。

必须明确处理边界归属，禁止同时使用互相重叠的 `<=` 分支。推荐统一左闭右开，30°通过输入归一化进入下一星座。

### 5.4 必须新增的测试

对偶数星座至少测试以下宫内度数：

```text
0, 4.999999, 5, 5.000001,
11.999999, 12, 12.000001,
19.999999, 20, 20.000001,
24.999999, 25, 25.000001, 29.999999
```

每个点必须断言：

- D30 星座索引正确；
- 输出在 `[0, 360)`；
- 每段内部映射方向正确；
- 段端点无不合理大跳之外的预期换座；
- 奇数星座现有结果不回归。

### 5.5 完成条件

- 5–12°全部落 Virgo；12–20°全部落 Pisces；20–25°全部落 Capricorn。
- 不复制一个新的 D30 函数。
- D1、D9、D12 等其他分盘结果不变。

---

## 6. 任务 3：修复 8 星 Chara Karaka 截断和名称顺序

### 6.1 允许修改

- `Sources/TransitStudio/Resources/backend/astro_backend_jyotish_jaimini.py`
- `python_tests/test_jyotish_focused.py`

### 6.2 锁定规则

7 星制名称顺序：

```text
Atma, Amatya, Bhratri, Matri, Putra, Gnati, Dara
```

8 星制名称顺序：

```text
Atma, Amatya, Bhratri, Matri, Pitri, Putra, Gnati, Dara
```

Rahu 的有效宫内度数继续使用 `30 - rasi_longitude`。本任务不得改变 Rahu 反向排序规则。

### 6.3 实现要求

- 为 7 星制和 8 星制定义独立、长度准确的名称表。
- `include_rahu=True` 且八星数据齐全时必须返回 8 条。
- `include_rahu=False` 时必须返回 7 条。
- `system` 字段必须与实际返回条数一致。
- Dara Karaka 必须始终是所选体系的最后一名。
- 如果输入缺少某颗行星，只对实际存在的候选排序；不得用经度 0 的虚构行星补位。
- 排序相同度数时必须确定稳定 tie-break；沿用候选列表顺序，并写测试锁定。

### 6.4 必须新增的测试

1. 八星齐全：正好 8 条，类型 `0...7`，第 5 项为 Pitri，第 8 项为 Dara。
2. 七星制：正好 7 条，不含 Rahu，不含 Pitri 插槽。
3. Rahu 排名使用反向宫内度数。
4. 缺一颗普通行星时不产生虚构候选。
5. 相同有效度数时输出顺序确定且可复现。

### 6.5 完成条件

- 删除因名称表过短而 `break` 的截断行为。
- 返回的 `system`、数量、名称和 `karaka_type` 一致。

---

## 7. 任务 4：修复 Yogakaraka 映射

### 7.1 允许修改

- `Sources/TransitStudio/Resources/backend/astro_backend_jyotish_yoga.py`
- `python_tests/test_jyotish_focused.py`

### 7.2 锁定映射

0-based 上升星座索引：

```python
{
    1: "SATURN",  # Taurus
    3: "MARS",    # Cancer
    4: "MARS",    # Leo
    6: "SATURN",  # Libra
    9: "VENUS",   # Capricorn
    10: "VENUS",  # Aquarius
}
```

其他上升星座不得产生 Yogakaraka 条目。

### 7.3 实现要求

优先从现有星座守护关系推导“同时统治 Kendra 和 Trikona”的交集；如果项目结构不适合推导，可使用上述锁定字典，但不得保留错误的 Venus/Cancer 或 Mercury/Leo。

`planet_positions` 中缺少对应行星时，继续返回 `None`，不得创建不存在的行星行。

### 7.4 必须新增的测试

- 参数化测试全部 12 个上升星座。
- 六个应命中的上升必须精确断言行星。
- 其余六个必须返回 `None`。
- 巨蟹和狮子必须都是 Mars。
- 天秤必须是 Saturn；水瓶必须是 Venus。

### 7.5 完成条件

- 12 上升参数化测试全部通过。
- 不改变其他 Yoga 检测函数。

---

## 8. 任务 5：重写 Ekadhipatya Shodhana 为完整规则矩阵

### 8.1 允许修改

- `Sources/TransitStudio/Resources/backend/astro_backend_jyotish_ashtakavarga.py`
- `python_tests/test_jyotish_focused.py` 或现有 Ashtakavarga 专项测试文件

### 8.2 必须保留

- `rekha` 原始矩阵；
- `trikona` 三角削减矩阵；
- `ekadhi` 双重统治削减矩阵；
- 五组双守护星座对：`(0,7) (1,6) (2,5) (8,11) (9,10)`；
- 现有返回 JSON 键名。

### 8.3 实现要求

1. `ekadhi` 必须从 `trikona` 深复制，不得从 `rekha` 复制。
2. 必须按实际七曜在星座中的入驻数构造 `planet_count_by_rasi`。ASC、Rahu、Ketu 不计入这里的七曜入驻。
3. 每对星座、每个被评估行必须按以下互斥规则处理：

   - 一边数值为 0、另一边大于 0：两边保持不变。
   - 两边都有行星：两边保持不变。
   - 两边都无行星、数值不同：两边都变成较小值。
   - 两边都无行星、数值相同：两边都变成 0。
   - 只有一边有行星，且有行星一边数值较小：有行星一边不变；无行星一边减去较小值。
   - 只有一边有行星，且有行星一边数值较大：有行星一边不变；无行星一边变为 0。
   - 只有一边有行星，且两边数值相同：有行星一边不变；无行星一边变为 0。

4. 每个分支必须通过一个纯 helper 测试，不得只能通过完整星盘间接覆盖。
5. 所有结果必须是非负整数。

### 8.4 必须新增的测试

对上述七种情形逐项参数化。另加一个完整矩阵测试，证明：

- `ekadhi` 输入来自 `trikona`；
- 原始 `rekha` 和 `trikona` 未被原地修改；
- `sarva_ekadhi` 等于各行 `ekadhi` 的列和。

### 8.5 禁止

- 禁止沿用当前 `if t := ekadhi[i][b1]` 的非对称实现。
- 禁止忽略行星入驻。
- 禁止把负数强行 `max(0, value)` 来掩盖规则错误。

---

## 9. 任务 6：修复 Nathonatha Bala 的地方平时

### 9.1 允许修改

- `Sources/TransitStudio/Resources/backend/astro_backend_jyotish_shadbala.py`
- 对应 Shadbala/Jyotish 测试文件

### 9.2 实现要求

- 东经为正、西经为负。
- 使用：

  ```python
  jd_lmt = jd_ut + longitude / 360.0
  ```

- 从 `jd_lmt` 得到地方平时钟点，再计算与地方午夜/正午的距离。
- Mercury 固定 60 的现有规则保持不变。
- Moon/Mars/Saturn 使用 Nata 值；Sun/Jupiter/Venus 使用 `60 - Nata` 的现有映射保持不变。
- 删除当前只为检查宫位而调用、但结果完全未使用的 `call_houses_ex`；不得让宫制计算失败导致全体回退 30。
- 输出限制在 `[0, 60]`。

### 9.3 必须新增的测试

1. 同一 `jd_ut`，经度 0°与 120°E 输出不同。
2. 120°E 的结果应等于 UT 增加 8 小时、经度 0°的结果。
3. 120°W 的结果应等于 UT 减少 8 小时、经度 0°的结果。
4. 地方午夜：Nata 组接近 0，Unnata 组接近 60。
5. 地方正午：Nata 组接近 60，Unnata 组接近 0。
6. 跨前一日和后一日均正确。

### 9.4 完成条件

- `longitude` 对输出有可验证影响。
- 不再导入或调用未使用结果的宫位函数。

### 9.5 Jyotish 阶段门禁

任务 1–6 完成后运行：

```bash
.venv/bin/python -m pytest python_tests/test_jyotish_focused.py -q
.venv/bin/python -m pytest python_tests -q -k 'jyotish or vedic or varga or shadbala or ashtakavarga'
```

任何失败必须在继续任务 7 前解决；不得用 `-x` 后忽略未执行测试。

---

## 10. 任务 7：重构 Zodiacal Releasing 子期并生成真实 LoB

### 10.1 允许修改

- `Sources/TransitStudio/Resources/backend/astro_backend_classical_timing.py`
- `Sources/TransitStudio/Resources/backend/astro_backend_time_lords_extended.py`，仅当 L4 调用契约必须同步
- `python_tests/test_classical.py`
- `python_tests/test_time_lords_extended.py`
- 因有意输出变化而受影响的真实 fixture；必须按 `docs/validation.md` 再生成，禁止手改

### 10.2 先决决策门禁

开始写生产代码前，必须在 `PLANS.md` 记录并由操作者确认一个明确的 `ZR_UNIT_PROFILE`，至少写清：

- L1 如何把 period number 转成日期；
- L2 的一个单位是何种“月”；
- L3 的一个单位是何种“日”；
- L4 的一个单位是什么；
- 父期结束时如何截断最后一个子期；
- 完成第一轮 12 星座后 LoB 的精确定义。

如果没有得到这项确认，只暂停任务 7；继续执行任务 8–13。禁止自行猜测 L4 单位。

### 10.3 不依赖流派选择的强制结构

无论选定哪个单位 profile，都必须满足：

1. 删除或停止使用“把 12 个子期按比例压缩到父期”的 `_zr_proportional_sub_periods`。
2. 子期按照各星座 period number 和该层固定单位逐段累积，不得为了填满父期而重新缩放。
3. 第一轮从父期星座开始，按黄道顺序运行 12 个星座。
4. 如果父期在第一轮完成后仍未结束，下一段必须按已确认 profile 产生 LoB 跳跃；跳跃必须真实写入 period sequence，不能只在结果上补一个布尔值。
5. 跳跃后的后续星座顺序必须由生成器产生。
6. 最后一段超过父期末端时，`end_local` 截断到父期末端；不得让子期越过父期。
7. `is_active` 必须满足半开区间 `start <= reference < end`。
8. 每层 LoB 的 origin 是该层所属父期的星座，不得永远使用最外层 Lot 星座。
9. `_detect_level_loosing_of_bond` 继续只认“到 origin 对宫且不是普通下一星座”的真实跳跃。
10. 普通 Leo→Virgo、Pisces→Aries 和按顺序进入 origin 对宫均不得标为 LoB。

### 10.4 必须新增的测试

1. 一个父期短于完整子期轮：不产生 LoB。
2. Aquarius 30 年 L1：L2 第一轮完整结束后，下一段真实跳到 Aquarius 对宫 Leo，并标记 L2 LoB。
3. 生成出来的 period sequence，而不是手工数组，能够触发 `_detect_loosing_of_bond`。
4. 普通顺序进入对宫不触发 LoB。
5. 最后一子期被父期末端截断。
6. `reference == end` 时激活下一期，不激活上一期。
7. L2、L3、L4 各自使用正确 origin；如果 profile 未启用某层，则明确拒绝该层，不能伪造结果。
8. `max_level=3` 和扩展模块的 `max_level=4` 契约都必须有测试。

### 10.5 禁止

- 禁止只修改 `_detect_level_loosing_of_bond` 来“制造”LoB。
- 禁止把所有进入对宫的普通过渡标为 LoB。
- 禁止继续生成固定 12 行后结束。
- 禁止保留两个互相冲突的生产子期生成器。

### 10.6 Classical 阶段门禁

```bash
.venv/bin/python -m pytest python_tests/test_classical.py python_tests/test_time_lords_extended.py -q
.venv/bin/python -m pytest python_tests/test_technique_maintenance_classical.py -q
```

---

## 11. 任务 8：修复行星会合搜索步长

### 11.1 允许修改

- `Sources/TransitStudio/Resources/backend/astro_backend_planetary_synodic.py`
- 如需复用现有安全步长 helper，可最小修改 `astro_backend_modern_timing.py`
- `python_tests/test_planetary_synodic.py`

### 11.2 实现要求

最低可接受修复：两星搜索基础步长取两者较小值，而不是较大值。

推荐修复：根据当前或保守最大相对角速度限制每步相位变化，同时以两星中较小的既有步长为上限。无论采用哪一种，都必须保证 Moon/Pluto 等快慢组合不会使用慢行星的 2 天或更大步长。

禁止改变 `_find_roots` 的全局行为来迁就本模块，除非新增测试证明所有调用者不回归。

### 11.3 必须新增的测试

1. 单元测试证明 Moon/Pluto 的生产步长不大于 Moon 步长。
2. 对一个包含至少一次 Moon/Pluto conjunction 和 opposition 的固定窗口：
   - 用生产算法计算事件；
   - 用 30 分钟或更细的独立基准扫描计算事件；
   - 两者的事件类型和数量完全一致；
   - 每个事件时间误差在根求解器既有精度内。
3. 交换 `body_a` / `body_b` 后，事件时刻和类型保持一致。
4. Mars/Jupiter 现有样例不回归。
5. 短窗口无事件时稳定返回空数组。

### 11.4 完成条件

- 删除“Relative motion is slower than the faster body”这一错误注释。
- 不能只断言结果非空。
- 不通过扩大搜索窗口掩盖漏检。

---

## 12. 任务 9：修复组合盘象限宫位平移基准

### 12.1 允许修改

- `Sources/TransitStudio/Resources/backend/astro_backend_composite.py`
- 现有 composite/relationship 测试文件

### 12.2 实现要求

非 `whole_sign` 分支必须保存中点地理坐标起盘得到的原始角度：

```python
raw_cusps, raw_angles, _ = build_houses(...)
mc_delta = signed_or_normalized_delta(comp_mc, raw_angles["MC"])
comp_cusps = [norm360(c + mc_delta) for c in raw_cusps]
```

允许使用现有 `norm360(comp_mc - raw_angles["MC"])`，只要所有宫头加同一旋转量。绝对禁止继续减 `a_angles["MC"]` 或 `b_angles["MC"]`。

### 12.3 必须新增的测试

1. A/B 对调后，组合行星、角度和 12 宫头在容差内完全相同。
2. 使用 monkeypatch 的确定数据：原始 MC=100°、组合 MC=130°，所有原始宫头精确加 30°。
3. 盘 A 的 MC 改变但 `raw_angles` 和组合 MC 固定时，宫头不受 A 本命 MC 影响。
4. 跨 0°：原始 MC=350°、组合 MC=10°，旋转为 +20°。
5. `whole_sign` 分支结果不变。
6. Placidus、Equal 或项目实际支持的至少一个非整宫制端到端请求可正常编码。

### 12.4 完成条件

- `mc_delta` 计算中不再出现 `a_angles["MC"]`。
- A/B 交换对称测试通过。

---

## 13. 任务 10：修复跨 0° 的 Chart Shapes

### 13.1 允许修改

- `Sources/TransitStudio/Resources/backend/astro_backend_patterns.py`
- 新增或现有 patterns 测试文件

### 13.2 实现要求

1. 对排序后的黄经计算包含末尾到开头的全部环形 gaps。
2. 找到最大 gap。
3. 最小包围弧：

   ```python
   span = 360.0 - max_gap
   ```

4. 线性分析起点必须旋转到最大 gap 之后的第一颗行星；后续需要线性顺序的聚类、leader 或分组逻辑必须使用旋转后的顺序。
5. 不得只替换 `span` 而继续让后续逻辑使用错误切点。

### 13.3 必须新增的测试

1. `350, 355, 5, 10`：span=20°，必须包含 Bundle 和 Bowl，不得仅为 Splay。
2. 同一组全部加 40°后，形态类型和 span 不变；验证旋转不变性。
3. 最大 gap 出现在普通数组中间时，span 正确。
4. 均匀分散星体不误判为 Bundle/Bowl。
5. 恰好 90°、略大于 90°、恰好 180°、略小于 180°按现有阈值语义测试。
6. 输入黄经先归一化；负角度和大于 360°的等价输入结果一致。

### 13.4 Modern/Relationship 阶段门禁

```bash
.venv/bin/python -m pytest python_tests/test_planetary_synodic.py -q
.venv/bin/python -m pytest python_tests -q -k 'composite or relationship or pattern or chart_shape'
```

---

## 14. 任务 11：修复 Heliacal previous event 查询

### 14.1 允许修改

- `Sources/TransitStudio/Resources/backend/astro_backend_visibility.py`
- `python_tests/test_classical_visibility.py`
- 对应 visibility fixture；只有输出有意变化时按 `docs/validation.md` 再生成

### 14.2 当前缺陷

`swe.heliacal_ut` 本地 Python API 只有 7 个参数。当前传入第 8 个 `True` 必然 `TypeError`，然后静默把 `previous_exact` 设为 `None`。

### 14.3 实现要求

1. 删除所有 8 参数 `swe.heliacal_ut(..., True)` 调用。
2. 不得把 `jd_start - 1` 调用“查找下一个事件”的结果直接当 previous。
3. 实现独立 helper，例如：

   ```python
   find_previous_heliacal_event(jd_start, ..., lookback_days, max_iterations)
   ```

4. 该 helper 必须：
   - 从足够早于 `jd_start` 的安全起点调用 7 参数 API；
   - 如果返回事件仍不早于 `jd_start`，继续向更早处回退；
   - 最终只接受严格满足 `event_jd < jd_start` 的结果；
   - 有明确最大回退范围和迭代次数；
   - 找不到时返回 `None` 并增加一条可审计 warning，不得伪造日期。
5. next event 仍必须满足 `event_jd >= jd_start`。
6. 不得吞掉 `TypeError` 来假装“无 previous”。API 签名错误必须在测试中暴露。

### 14.4 必须新增的测试

使用 monkeypatch 替代真实 Swiss Ephemeris，以确定性验证：

1. 所有调用参数数量为 7。
2. 第一次返回未来事件时 helper 会继续向前回退。
3. 只接受严格早于起点的 previous。
4. 达到迭代上限时返回 `None` 并产生 warning。
5. 真实集成样例中 `previous_event_utc < chart/start time <= next/exact event`。
6. 高纬度或 Swiss Ephemeris 无结果时不崩溃。

### 14.5 完成条件

- 源码不存在声称 `backwards=True` 的第八参数。
- previous 字段的语义由测试锁定，而不是仅断言字段存在。

---

## 15. 任务 12：修复 Alcocoden 候选排名语义

### 15.1 允许修改

- `Sources/TransitStudio/Resources/backend/astro_backend_classical_audit.py`
- `python_tests/test_classical.py`
- `python_tests/test_technique_maintenance_classical.py`
- 如果 Swift 模型把 `rank` 强制为非可选整数，允许最小修改对应 Codable 模型与展示/导出测试

### 15.2 锁定语义

- 只有 `eligible_under_profile=True` 的候选有排名。
- 合格候选按现有排序键 `(-weight, -own_condition_score)` 排名 `1...N`。
- 不合格候选 `rank = None`，不得使用 99、0 或原始循环序号伪装排名。
- `selected` 必须等于 rank 1 的候选；无合格候选时 `selected` 为空，所有 rank 为 `None`。

### 15.3 必须新增的测试

1. 合格和不合格候选混合时，只有合格候选排名且无重复。
2. 两个合格候选权重不同，权重高者 rank 1。
3. 权重相同，`own_condition_score` 高者 rank 1。
4. 全部不合格时所有 rank 为 `None`，selected 为空。
5. JSON 编码后的 `rank` 为整数或 `null`。
6. Swift 解码、Markdown/文本导出如涉及该字段，必须处理 `null`，不得显示 0 或 99。

### 15.4 完成条件

- 删除给 `alcocoden_candidates` 全体预先编号的循环。
- 不改变实际 eligibility 和 selection 规则。
- 不恢复寿命年数输出；项目契约明确禁止输出 longevity years。

---

## 16. 任务 13：修复 JD 转 UTC 的午夜进位

### 16.1 允许修改

- `Sources/TransitStudio/Resources/backend/astro_backend_cycles.py`
- 相关 modern cycles 测试文件

如果发现其他模块有完全相同的手写进位实现，只记录到 `PLANS.md`；本任务不得顺手批量重构，除非操作者扩大范围。

### 16.2 实现要求

使用日期起点加 `timedelta`，由标准库处理秒、分、小时、日期、月份、年份和闰年进位。推荐形态：

```python
base = datetime(year, month, day, tzinfo=timezone.utc)
return base + timedelta(hours=hour_float)
```

如果需要微秒精度，统一在 `timedelta` 输入前或输出后做一次舍入。禁止继续手写 `seconds→minutes→hours` 并对小时 `% 24`。

### 16.3 必须新增的测试

通过 monkeypatch `swe.revjul` 或纯 helper 精确覆盖：

1. 普通中午不变。
2. `23:59:59.9999996` 舍入到下一日 00:00:00。
3. 月末进位。
4. 年末进位。
5. 闰年 2 月 29 日及其下一日。
6. 不应进位的 `23:59:59.999400` 保留原日期。
7. 返回对象始终带 `timezone.utc`。

### 16.4 完成条件

- 源码不存在 `whole_hours % 24`。
- 日期进位完全由 `datetime + timedelta` 处理。

---

## 17. Fixture 与契约处理

只有生产输出发生有意变化且现有 fixture 因此失败时，才允许再生成 fixture。

执行顺序：

1. 先确认失败来自本文修复，而不是无关漂移。
2. 阅读 `docs/validation.md` 的 Backend Contract Fixtures。
3. 使用文档规定的真实后端命令再生成。
4. 禁止手工编辑数值让测试通过。
5. 对新旧 fixture 做结构化 diff，确认只包含预期字段和值。
6. 如果 JSON shape 改变，必须同时检查 Swift Codable、Markdown、CSV/Text 导出和 schema。

预期可能改变 fixture 的任务：D30、Karaka、Yogakaraka、Ashtakavarga、Shadbala、ZR、Composite、Patterns、Visibility、Alcocoden。任务 8 和任务 13 通常只应改变事件完整性或极端时间值，不应无理由重写大型 fixture。

## 18. 最终验证

### 18.1 聚焦测试

```bash
.venv/bin/python -m pytest python_tests/test_jyotish_focused.py -q
.venv/bin/python -m pytest python_tests/test_classical.py -q
.venv/bin/python -m pytest python_tests/test_technique_maintenance_classical.py -q
.venv/bin/python -m pytest python_tests/test_time_lords_extended.py -q
.venv/bin/python -m pytest python_tests/test_planetary_synodic.py -q
.venv/bin/python -m pytest python_tests/test_classical_visibility.py -q
.venv/bin/python -m pytest python_tests/test_modern_cycles.py -q
```

如实际相关测试分布在其他文件，必须追加运行，不得以本文命令未列出为由跳过。

### 18.2 项目完整门禁

```bash
bash check_vibe_changes.sh
```

门禁必须完整成功。不得只报告最后一条命令；最终记录必须包含：

- Python 测试通过数和 skipped 数；
- Swift 测试通过数；
- `swift build` 结果；
- backend smoke 结果；
- fixture/schema 检查结果。

### 18.3 差异审查

```bash
git diff --check
git diff --stat
git diff -- Sources/TransitStudio/Resources/backend python_tests SwiftTests docs PLANS.md CHANGELOG.md
git status --short --branch
```

必须逐文件阅读完整 diff。发现无关格式化、生成缓存、架构重构或未计划文件时，停止并清理任务边界；不得把无关改动一起提交。

## 19. 完成判定

只有同时满足以下条件才可宣布完成：

- 13 项任务均有旧代码失败、新代码通过的回归测试；或者任务 7 因缺少明确 `ZR_UNIT_PROFILE` 被单独标记为阻塞，其他任务不受影响。
- 所有生产改动都能对应到本文某一项任务。
- 未放宽任何无关测试。
- 所有有意 fixture 变化均由真实后端再生成并审查。
- `check_vibe_changes.sh` 全绿。
- `git diff --check` 无错误。
- `PLANS.md` 状态、`CHANGELOG.md` 内容和实际 diff 一致。
- 已清理 `.build`、pytest cache、`__pycache__`、`.pyc` 和临时输出；不得删除源码、fixture 或用户文件。
- 最终报告逐项列出：修改文件、失败测试、实现摘要、验证命令、验证结果、未解决事项。

如果任一条件不满足，只能报告“未完成”或“被阻塞”，不得使用“全部修复”“完全正确”“100% 通过”。
