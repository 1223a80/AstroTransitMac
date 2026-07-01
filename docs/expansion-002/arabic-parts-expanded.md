# 扩展阿拉伯点完整公式表

**状态**：规划中
**来源**：Paulus Alexandrinus, Abu Ma'shar, Bonatti, Lilly 等中世纪文献
**约定**：所有公式的 `ASC` 指上升点黄经。表格中的"日间公式"和"夜间公式"是本项目实现的 source of truth；不要在代码中脱离表格自行推导反转方向。

---

## 实现总约束

1. **逐条定义，不做隐式推断**：每个点都应有稳定 `lot_id`、`day_formula`、`night_formula`、`source`、`group`、`confidence`、`notes`。即使多数点符合 `ASC + A - B` / `ASC + B - A` 模式，也要按表格逐条声明，避免把未来不反转或有特殊性别规则的点算错。
2. **角度单位**：公式中的固定度数统一解释为黄道绝对经度或星座内 0-based 度数。例如 `15°♋` = `90 + 15 = 105.0°`，`19°♈` = `19.0°`。如果某来源使用"第 N 度"的 ordinal 表述，应在 `notes` 中单独说明，不在实现里混用。
3. **宫头口径**：Whole Sign 使用对应星座 0°；象限宫制必须使用实际 `build_houses()` 返回的 cusp。不要把象限宫制也简化成 Whole Sign。
4. **宫主星口径**：使用当前项目古典主星体系（七政主星），不引入现代主星。若后续支持现代主星，应作为显式选项。
5. **公式冲突不是去重条件**：多个点公式相同但语境不同，应保留独立 `lot_id`，并在 `notes` 标记公式同源/同形。

---

## 已实现的核心点（7 个）

这些已在 `astro_backend_classical_lots.py` 中实现，保持不变。

| # | 名称 | 日间公式 | 夜间公式 | 分组 |
|---|------|----------|----------|------|
| 1 | **Fortune** (福点) | ASC + ☽ - ☉ | ASC + ☉ - ☽ | core |
| 2 | **Spirit** (精神点) | ASC + ☉ - ☽ | ASC + ☽ - ☉ | core |
| 3 | **Eros** (爱欲点) | ASC + ♀ - Spirit | ASC + Spirit - ♀ | core |
| 4 | **Necessity** (必然点) | ASC + Fortune - ☿ | ASC + ☿ - Fortune | core |
| 5 | **Courage** (勇气点) | ASC + Fortune - ♂ | ASC + ♂ - Fortune | core |
| 6 | **Victory** (胜利点) | ASC + ♃ - Spirit | ASC + Spirit - ♃ | core |
| 7 | **Nemesis** (复仇点) | ASC + Fortune - ♄ | ASC + ♄ - Fortune | core |

---

## 新增点：人生领域（~25 个）

| # | 名称 | 日间公式 | 夜间公式 | 来源 | 备注 |
|---|------|----------|----------|------|------|
| 8 | **Basis** (基础点) | ASC + Fortune - Spirit | ASC + Spirit - Fortune | Paulus | ⚠️ 与现有 Basis 公式不同（现有使用 Moon/Sun），需重命名现有为 `BasisOld` 或直接替换 |
| 9 | **Marriage** (婚姻点) ♀ | ASC + ♄ - ♀ | ASC + ♀ - ♄ | Bonatti | 另有一说男性取此公式、女性反转；此处取通用版 |
| 10 | **Father** (父亲点) | ASC + ♄ - ☉ | ASC + ☉ - ♄ | Lilly | 日生取土星，夜生取太阳；若父不详可参考 |
| 11 | **Mother** (母亲点) | ASC + ☽ - ♀ | ASC + ♀ - ☽ | Lilly | |
| 12 | **Siblings** (兄弟点) | ASC + ♃ - ♄ | ASC + ♄ - ♃ | Bonatti | |
| 13 | **Friends** (朋友点) | ASC + ☿ - ☽ | ASC + ☽ - ☿ | Lilly | |
| 14 | **Enemies** (敌人点) | ASC + ♄ - ☿ | ASC + ☿ - ♄ | Bonatti | |
| 15 | **Death** (死亡点) | ASC + 8宫头 - ☽ | ASC + ☽ - 8宫头 | Bonatti | 使用 Whole Sign 8 宫头 |
| 16 | **Illness** (疾病点) | ASC + ♂ - ♄ | ASC + ♄ - ♂ | Bonatti | 慢性病倾向 |
| 17 | **Acute Illness** (急病点) | ASC + ♂ - ☽ | ASC + ☽ - ♂ | Lilly | 急性病/外伤 |
| 18 | **Travel** (旅行点) | ASC + 9宫头 - 9宫主 | ASC + 9宫主 - 9宫头 | Bonatti | 9 宫主需跨步计算 |
| 19 | **Captivity** (牢狱点) | ASC + 12宫头 - ♄ | ASC + ♄ - 12宫头 | Bonatti | 囚禁/限制 |
| 20 | **Debt** (债务点) | ASC + ♄ - ☿ | ASC + ☿ - ♄ | Lilly | |
| 21 | **Livelihood** (生计点) | ASC + ☽ - ☉ | ASC + ☉ - ☽ | Abu Ma'shar | 注意：此与 Fortune 同公式 → 可能实为 Fortune 的变体称呼 |
| 22 | **Property** (不动产点) | ASC + 4宫头 - ♄ | ASC + ♄ - 4宫头 | Bonatti | |
| 23 | **Inheritance** (遗产点) | ASC + ☽ - ♄ | ASC + ♄ - ☽ | Bonatti | |
| 24 | **Danger** (危险点) | ASC + ☿ - ♄ | ASC + ♄ - ☿ | Lilly | 意外与危机 |
| 25 | **Peril** (劫难点) | ASC + 8宫头 - ♄ | ASC + ♄ - 8宫头 | Bonatti | 与 Death 不同：强调暴烈/意外死亡 |
| 26 | **Water Travel** (水路旅行点) | ASC + 15°♋ - ♄ | ASC + ♄ - 15°♋ | Bonatti | 15°♋ 为固定参考点 |
| 27 | **Return** (归返点) | ASC + ☿ - ♄ | ASC + ♄ - ☿ | Abu Ma'shar | 失物归还是否 |
| 28 | **Lost Objects** (失物点) | ASC + ☽ - 2宫主 | ASC + 2宫主 - ☽ | Lilly | |
| 29 | **Theft** (盗窃点) | ASC + ♂ - ☿ | ASC + ☿ - ♂ | Bonatti | |
| 30 | **Murder** (谋杀点) | ASC + 12宫主 - ♄ | ASC + ♄ - 12宫主 | Bonatti | 暴力致死倾向 |
| 31 | **Servants** (仆役点) | ASC + ☿ - ☽ | ASC + ☽ - ☿ | Bonatti | 雇工/下属 |

---

## 新增点：职业与地位（~12 个）

| # | 名称 | 日间公式 | 夜间公式 | 来源 | 备注 |
|---|------|----------|----------|------|------|
| 32 | **Kingship** (王权点) | ASC + ☽ - ☉ | ASC + ☉ - ☽ | Bonatti | 公式同 Fortune，但仅日生解读为权力 |
| 33 | **Honor** (荣誉点) | ASC + 19°♈ - ☉ | ASC + ☉ - 19°♈ | Lilly | 19°♈ 为太阳的擢升度 |
| 34 | **Nobility** (贵族点) | ASC + ♃ - ☽ | ASC + ☽ - ♃ | Abu Ma'shar | 高贵/社会地位 |
| 35 | **Profession** (职业点) | ASC + ☉ - ☿ | ASC + ☿ - ☉ | Bonatti | |
| 36 | **Magistery** (权威点) | ASC + MC - ☉ | ASC + ☉ - MC | Bonatti | 领导/管理角色 |
| 37 | **Dignity** (尊荣点) | ASC + ☉ - ♄ | ASC + ♄ - ☉ | Abu Ma'shar | |
| 38 | **Fame** (名声点) | ASC + ♃ - ☉ | ASC + ☉ - ♃ | Lilly | 公众知名度 |
| 39 | **Success** (成功点) | ASC + ♃ - Fortune | ASC + Fortune - ♃ | Bonatti | |
| 40 | **Commerce** (商业点) | ASC + ☿ - ☉ | ASC + ☉ - ☿ | Lilly | |
| 41 | **Justice** (司法点) | ASC + ♃ - ☿ | ASC + ☿ - ♃ | Bonatti | 法律/审判 |
| 42 | **Speculation** (投机点) | ASC + ♀ - ♃ | ASC + ♃ - ♀ | Lilly | 赌博/投资 |
| 43 | **Boldness** (勇敢点) | ASC + ♂ - ☽ | ASC + ☽ - ♂ | Abu Ma'shar | 军人素质 |

---

## 新增点：精神与关系（~10 个）

| # | 名称 | 日间公式 | 夜间公式 | 来源 | 备注 |
|---|------|----------|----------|------|------|
| 44 | **Faith** (信仰点) | ASC + ☿ - ☽ | ASC + ☽ - ☿ | Lilly | 宗教虔诚 |
| 45 | **Understanding** (理解点) | ASC + ☉ - ☿ | ASC + ☿ - ☉ | Abu Ma'shar | 智慧与领悟 |
| 46 | **Reason** (理性点) | ASC + ☿ - ☽ | ASC + ☽ - ☿ | Bonatti | 逻辑思维能力 |
| 47 | **Love & Concord** (爱和点) | ASC + ♃ - ♀ | ASC + ♀ - ♃ | Lilly | 和谐恋爱关系 |
| 48 | **Discord** (纷争点) | ASC + ♂ - ♃ | ASC + ♃ - ♂ | Bonatti | 吵架/冲突 |
| 49 | **Lawsuits** (诉讼点) | ASC + ♃ - ♂ | ASC + ♂ - ♃ | Lilly | |
| 50 | **Secret Enemies** (暗敌点) | ASC + 12宫头 - ☿ | ASC + ☿ - 12宫头 | Bonatti | 小人/暗算 |
| 51 | **Treachery** (背叛点) | ASC + ♄ - ☉ | ASC + ☉ - ♄ | Lilly | |
| 52 | **Praise** (赞誉点) | ASC + ♀ - ♃ | ASC + ♃ - ♀ | Bonatti | 受他人赞赏 |
| 53 | **Piety** (虔诚点) | ASC + ♃ - ☿ | ASC + ☿ - ♃ | Abu Ma'shar | 变体：近乎 Faith |

---

## 现有实验性点（已在当前代码中）

这些已在当前代码中实现（标记为 `confidence: low` / `lot_group: experimental`），本次不修改：

| 名称 | 说明 |
|------|------|
| **Basis (old)** | 现有公式 ASC + ASC - Moon(日)/Sun(夜)，可能是非标准变体。需重命名避免与新的 Paulus Basis 冲突。 |
| **Exaltation** | ASC + Sun/Moon - 擢升度 |
| **Acquisition** | ASC + Spirit - Fortune（与初始福点反转） |
| **Children** | ASC + Jupiter - Saturn(日) / ASC + Saturn - Jupiter(夜) |

---

## 实现注意事项

### 1. 日夜反转模式

绝大多数阿拉伯点使用这个标准模式，但实现时仍应以每条 lot definition 的 `day_formula` / `night_formula` 为准：

```python
if is_day:
    lot_lon = norm360(asc_lon + planet_a_lon - planet_b_lon)
else:
    lot_lon = norm360(asc_lon + planet_b_lon - planet_a_lon)
```

### 2. 宫头参与的点

部分点使用宫头（如 8 宫头、4 宫头、12 宫头）。在 Whole Sign 宫位系统中，宫头 = 该星座的起始度数（0°），等价于该星座在黄道上的绝对经度。

```python
def house_cusp_lon(sign_index):
    """Whole Sign 宫头经度"""
    return sign_index * 30.0  # 0° of the sign
```

如果使用象限宫位系统（如 Regiomontanus），宫头需要取实际计算值。后续 Agent 不要用 `sign_index * 30` 代替象限宫 cusp。

### 3. 宫主星参与的点

部分点使用"X 宫主星"而非具体行星。需先确定该宫的 sign，再取该 sign 的主星。

```python
def house_ruler_lon(house_number, house_system, positions):
    sign = get_house_sign(house_number, house_system)
    ruler = get_sign_ruler(sign)
    return get_planet_lon(ruler, positions)
```

对于"12 宫主"这种：先确定 12 宫头所在的星座 → 该星座的主星 → 该行星的黄经。

### 4. 公式冲突

| 冲突组 | 涉及的点 | 处理方式 |
|--------|----------|----------|
| Fortune = Kingship = Livelihood | 三者日间公式完全相同 | 保留三个独立点，在 notes 中注明公式相同但解读语境不同 |
| Friends = Servants = Faith | 公式完全相同 | 同上 |

### 4.1 现有 Basis 冲突处理

当前代码已有 `basis`，公式为 `ASC + ASC - Moon`（日）/ `ASC + ASC - Sun`（夜），并标记为 experimental。新增 Paulus `Basis` 前必须先处理命名冲突：

- 保留旧点为 `basis_old`，显示名 `Basis (old)` / `旧基础点`，`group = experimental`，`confidence = low`
- 新 Paulus 公式使用 `basis` 或 `basis_paulus`，但 Swift 模型、导出和测试要统一
- 不要让两个输出对象共享同一个 `lot_id`

### 5. 性能

- 50+ 个阿拉伯点的计算仅涉及加减法 + 标准化到 0-360°，不调用 `swe.calc_ut`
- 时间复杂度：O(N) where N = number of lots
- 总计算时间 < 1ms

### 6. 分组策略

在 Python 输出和 Swift 模型中，每个点增加：

```json
{
  "name": "Marriage",
  "nameCN": "婚姻点",
  "longitude": 123.45,
  "sign": "Leo",
  "house": 5,
  "formula": "ASC + Saturn - Venus",
  "isDayFormula": true,
  "source": "Bonatti",
  "group": "life",
  "confidence": "medium",
  "notes": "Formula variant selected for project contract"
}
```

前端按 `group` 分组展示：
- `core`：主表直接显示
- `life`："人生领域"折叠区
- `career`："职业与地位"折叠区
- `spirit`："精神与关系"折叠区
- `experimental`：默认隐藏的折叠区

---

## 参考文献

- Paulus Alexandrinus, *Introductory Matters* (4th century)
- Abu Ma'shar, *The Abbreviation of the Introduction to Astrology* (9th century)
- Guido Bonatti, *Liber Astronomiae* (13th century)
- William Lilly, *Christian Astrology* (1647)
- Robert Zoller, *The Arabic Parts in Astrology* (modern synthesis)
