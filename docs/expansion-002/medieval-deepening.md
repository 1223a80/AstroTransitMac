# 中世纪技法深化技术规格

**状态**：规划中
**目标**：在现有古典模块基础上，打通中世纪占星预测体系的核心链路

---

## 1. 阿拉伯点扩展：12 → 50+

### 1.1 当前状态

`astro_backend_classical_lots.py` 已定义 12 个阿拉伯点，日夜反转模式清晰：

```python
# 模式：ASC + 日间A - 日间B（日）/ ASC + 日间B - 日间A（夜）
LOT_DEFINITIONS = [
    ("Fortune",   ASC, SUN, MOON,  True,  False),  # 日夜反转
    ("Spirit",    ASC, MOON, SUN,  True,  False),
    ...
]
```

新增点只需沿用此模式。详见 `arabic-parts-expanded.md` 完整公式表。

### 1.2 分组策略

将 50+ 点分为四组：

| 分组 | 数量 | 说明 | 前端展示 |
|------|------|------|----------|
| **核心点** (core) | 7 个 | Fortune, Spirit, Eros, Necessity, Courage, Victory, Nemesis（已有） | 古典本命 → Lots 标签页主表 |
| **人生领域** (life) | ~20 个 | 婚姻、子女、父母、兄弟、朋友、敌人、死亡、旅行、诉讼、商业等 | 新增"扩展阿拉伯点"标签页或折叠区 |
| **职业与地位** (career) | ~10 个 | 王权、荣誉、职业、仆役、财富等 | 同上 |
| **实验性** (experimental) | ~15 个 | 来源不确定或公式分歧的点 | 默认隐藏，可展开 |

### 1.3 实现要点

- 每个点增加 `source` 字段（如 "Bonatti", "Lilly", "Abu Ma'shar"）
- 公式分歧时取最常见版本，在 `notes` 中注明变体
- 日生/夜生的判断沿用现有的 `is_day` 逻辑
- 保持现有 `confidence` 和 `lot_group` 字段

---

## 2. 三分主星序列

### 2.1 理论背景

中世纪占星中，三分主星（Triplicity Rulers）有多个层次的应用：

1. **行星尊贵评估**（已实现）：单个行星在其所在星座的三分主星地位
2. **Sect Light 的三分主星序列**（本次实现）：日生取太阳所在星座，夜生取月亮所在星座。三位主星接管人生三个阶段：
   - 第一三分主：人生的前 1/3（或到 25 岁）
   - 第二三分主：中年
   - 第三三分主（参与主）：晚年
3. **ASC 的三分主星**（本次实现）：用于辅助判断气质和人生方向

### 2.2 实现

新增函数（放在 `astro_backend_classical_audit.py` 或新建 `astro_backend_classical_medieval.py`）：

```python
def sect_light_triplicity_rulers(positions, is_day, triplicity_system="dorothean"):
    """
    返回 sect light 的三分主星序列。
    
    返回:
    {
        "sect_light": "Sun" | "Moon",
        "light_sign": "Leo",
        "light_house": 10,
        "triplicity_system": "dorothean",
        "rulers": [
            {"planet": "Jupiter", "condition_score": 12, "angular": True, ...},
            {"planet": "Sun", "condition_score": 8, ...},
            {"planet": "Saturn", "condition_score": 3, ...}
        ]
    }
    """
    pass
```

### 2.3 与现有功能的复用

- `TRIPLICITY_RULERS` 字典（`dignity.py:24`）直接使用
- `triplicity_ruler_details()`（`dignity.py:204`）已计算每位三分主星的尊贵条件
- 新增函数仅需**指定目标星座**（sect light 的星座），其余可委派给现有函数
- 三分主星系统必须使用请求中的 `triplicity_system`，默认 `dorothean`；不要在新函数中硬编码一套表

---

## 3. Kurios / Oikodespotes（盘主星）

### 3.1 定义

在希腊/中世纪占星中，Kurios（主星）、Oikodespotes（星盘之主）是盘中最具支配力的行星。不同来源有不同判定方法；本项目采用一个明确标记为 `compound_weighted` 的综合评分法。不要把该算法描述为唯一古法标准。

**候选池**（按权重排序）：
1. **ASC 的主星**（Domicile Ruler of ASC）— 权重 5
2. **Sect Light 的三分主星第一位**（1st Triplicity Ruler of Sect Light）— 权重 4
3. **Almuten Figuris**（已有）— 权重 3
4. **Sect Light 的三分主星第二位**（2nd Triplicity Ruler）— 权重 2
5. **Sect 主星**（日生=太阳，夜生=月亮）— 权重 1

**年度上下文候选**：
- **Year Lord**（Profection Lord）只应进入年度/当前年焦点，不应改变本命 Kurios 的基础判定。若输出中需要把年主纳入比较，应放在 `annual_context` 或 `current_year_modifiers` 下，避免同一个出生盘在不同 reference date 得到不同的 natal Kurios。

### 3.2 综合判定算法

```python
def determine_kurios(candidates: List[KuriosCandidate]) -> KuriosResult:
    """
    综合判定盘主星。
    
    1. 对每个候选行星评估条件：
       - 是否在角宫 (angular) → +3
       - 是否在续宫 (succedent) → +1
       - 是否在果宫 (cadent) → -2
       - 是否逆行 → -2
       - 是否燃烧/日核内 → -1/+2
       - 尊贵评分 (dignity score) → 直接加
       - 是否被凶星刑冲 → -1 per aspect
       - 是否被吉星拱/六合 → +1 per aspect
    
    2. 排序后输出前三名 + 判定理由
    """
    pass
```

**评分边界**：
- 候选角色权重与行星条件分应分开输出，例如 `role_weight`、`condition_score`、`total_score`
- 逆行、燃烧、日核、sect、角续果宫等条件应复用现有古典评估 helper，不能重新写一套口径
- 凶吉星相位加减分必须说明 orb 与相位类型；缺少相位数据时不加不减，不要推断
- 平分时按 `condition_score`、角宫优先、角色权重优先排序；仍平分则保留并列说明

### 3.3 输出结构

```json
{
  "kurios": {
    "primary": {
      "planet": "Jupiter",
      "score": 18,
      "role": "ASC Ruler + 1st Triplicity Ruler",
      "condition": "Angular in 10th, in domicile, direct, in-Sect"
    },
    "candidates": [
      {"planet": "Jupiter", "score": 18, "roles": ["ASC Ruler", "1st Triplicity"], ...},
      {"planet": "Sun", "score": 14, "roles": ["Almuten"], ...},
      {"planet": "Mercury", "score": 9, "roles": ["2nd Triplicity"], ...}
    ],
    "method": "compound_weighted_project_rule",
    "notes": "Project synthesis; not a single-source canonical Kurios method"
  }
}
```

---

## 4. 年主与日返融合解读

### 4.1 当前状态

现有三个独立数据源：
- `profection_summary()` → 年主（Lord of the Year）及其条件
- `return_summary()` → 太阳返照盘（仅做独立星盘快照，无融合解读）
- `ActivatedLordFocus`（orchestration 层）→ 交叉引用年主与其行星返照

### 4.2 缺口

**中世纪占星的核心预测方法**：把年主放入日返盘，评估年主在返照盘中的条件。这不是两个独立解读，而是一个融合体系。

我需要新增的内容：

```
年主 + 日返融合解读
├── 返照 ASC 是否 = 小限星座？
│   ├── 是 → 强化小限主题
│   └── 否 → 当年的关注领域在小限宫位 vs 返照 ASC 之间
├── 年主在返照盘的状态
│   ├── 落入哪个宫位？→ 当年的活动领域
│   ├── 在返照盘的尊贵（庙/旺/三分/界/面）？→ 资源
│   ├── 在返照盘的相位（与谁发生关系）？→ 人际/事件主题
│   ├── 速度、方向（顺逆）、燃烧状态 → 效率
│   └── 是否为返照盘的角宫主 → 被激活
├── 返照盘中的显要行星
│   ├── 返照 ASC 主星的条件
│   ├── 返照 MC 主星的条件
│   └── 星群（stellium）在返照盘的哪个宫位？
└── 机器生成摘要（1-2 段中文）
```

### 4.3 实现计划

#### 后端

新增函数（在 `astro_backend_classical.py` 或 `astro_backend_classical_timing.py`）：

```python
def profection_solar_return_synthesis(
    profection: ProfectionSummary,
    solar_return_snapshot: ClassicalSnapshot,
    natal_data: ClassicalSnapshot
) -> ProfectionSRSynthesis:
    """
    年主与日返盘的融合解读。
    
    返回:
    - profection_asc_matches_sr_asc: bool
    - lord_in_sr: LordInReturnChart  # 年主在返照盘的位置/尊贵/相位
    - sr_highlights: SRHighlights    # 返照盘的关键特征
    - summary_text: str              # 机器生成的中文摘要
    """
    pass
```

#### 关键判断逻辑

1. **小限 ASC vs 返照 ASC**：
   ```python
   prof_asc_sign = zodiac_sign_index(profected_asc_lon)
   sr_asc_sign = zodiac_sign_index(sr_asc_lon)
   match = (prof_asc_sign == sr_asc_sign)
   ```

2. **年主在返照盘中的宫位**：
   使用返照盘的宫位系统，计算年主所在宫位。Whole Sign 可按星座推导；象限宫制必须使用返照盘实际 cusp。

3. **年主在返照盘的尊贵**：
   复用 `dignity_rulers_for_lon()`，传入返照盘中年主的黄经和返照盘自身的日/夜状态。不要混用本命盘 sect。

4. **年主相位**：
   复用 `find_classical_aspects()`，传入返照盘的行星列表。

5. **摘要生成**：
   `summary_text` 应先用确定性模板生成，基于明确字段拼接，不调用 LLM。AI 解读可作为现有 AI 分析层的上层功能，不进入后端计算契约。

#### Swift 模型

```swift
struct ProfectionSRSynthesis: Codable {
    let profectionAscSign: String
    let solarReturnAscSign: String
    let ascSignsMatch: Bool
    let lordOfYear: LordInReturnChart
    let returnChartHighlights: SRHighlights
    let summaryText: String
}

struct LordInReturnChart: Codable {
    let planet: String
    let house: Int
    let houseLabel: String        // e.g. "10th House / Career"
    let dignityScore: Int
    let dignityLabels: [String]   // e.g. ["Domicile", "Triplicity"]
    let isRetrograde: Bool
    let isCombust: Bool
    let keyAspects: [String]      // e.g. ["Trine Jupiter (3° applying)"]
    let conditionSummary: String  // one-line assessment
}

struct SRHighlights: Codable {
    let ascRuler: String
    let ascRulerHouse: Int
    let mcRuler: String
    let mcRulerHouse: Int
    let stelliumHouse: Int?
    let mostAspectedPlanet: String?
}
```

#### UI 展示

在 `ClassicalTimingViews.swift` 的年主区块下方，新增"年主 × 日返"融合卡片：

```
┌─────────────────────────────────────────┐
│  🏰 年主 · 日返融合解读                    │
│                                         │
│  ☉ 小限星座：双子座 ← 返照ASC：双子座 ✓    │
│                                         │
│  年主 水星 在返照盘第10宫                  │
│  · 处于自身庙宫（处女座）— 强              │
│  · 顺行，日核外                           │
│  · 拱木星（入相 3°）— 事业机遇             │
│  · 冲土星（出相 2°）— 遗留责任             │
│                                         │
│  ⚡ 今年事业运突出，注意把握木星带来的       │
│  人脉机会，但土星暗示仍有尚未完成的工作       │
│  需要清理。                               │
└─────────────────────────────────────────┘
```

---

## 5. 月度小限增强

### 5.1 当前状态

`monthly_profection()` 已计算月度小限，但仅作为年主的嵌套子字段。前端显示为"月小限"一节。

### 5.2 增强内容

1. **月小限主的状态**：参照年主增强，显示当月主星在本命盘中的条件
2. **月主 + 当月行运**：当月主星在当月是否存在重要行运触发
3. **日期范围显示**：当月小限的精确起止日期（而非简单显示"第 N 月"）

### 5.3 实现

```python
def enhanced_monthly_profection(birth_jd, current_jd, natal_data, transit_data):
    """
    增强月小限。
    
    返回:
    - month_sign, month_lord
    - date_range: {start_date, end_date}
    - lord_natal_condition: {...}     # 月主本命条件
    - lord_transit_highlights: [...]   # 月主当月行运事件
    """
    pass
```

---

## 6. 界推进深化

### 6.1 当前状态

`circumambulations` 已实现从 ASC 沿界推进，显示在每个界边界的年龄。

### 6.2 增强内容

1. **当前所在界的界主星**：突出显示当前年龄所在的界 + 界主身份
2. **界主在盘中的状态**：界主在本命盘中的尊贵、宫位、相位
3. **界推进与其他技法的交集**：
   - 界主 = 年主 → 强化
   - 界主 = Firdaria 主限主 → 时段一致
   - 界推进年龄接近某主限（Primary Direction）事件年龄 → 标注

### 6.3 实现

主要在前端增强 `ClassicalTimingViews.swift` 的 circumambulation 展示区域。

---

## 7. 测试计划

| 测试 | 内容 |
|------|------|
| `test_extended_lots.py` | 验证新增 38+ 个阿拉伯点公式正确性（与手工验算对比） |
| `test_triplicity_rulers.py` | 验证 sect light 三分主星选择逻辑 |
| `test_kurios.py` | 使用构造盘验证候选角色、权重、平分规则；如使用历史案例，需在 fixture 中记录来源和算法差异 |
| `test_sr_synthesis.py` | 日返融合：验证 ASC 匹配、年主宫位计算 |
| `test_monthly_profection.py` | 验证月小限日期范围和月主条件 |

---

## 8. UI 改动摘要

| 视图 | 改动 |
|------|------|
| `ClassicalResultViews.swift` | 阿拉伯点标签页拆分：核心点 + 扩展点（可折叠分组） |
| `ClassicalTimingViews.swift` | 年主下方新增"年主×日返"卡片；月度小限增强；界推进深化 |
| 新增 `ClassicalMedievalViews.swift` | Kurios/盘主星展示 + 三分主星序列（可选新建文件或并入现有视图） |

---

## 9. 术语表

| 中文 | 英文 | 缩写 |
|------|------|------|
| 年主 | Lord of the Year | LOTY |
| 小限 | Annual Profection | — |
| 日返 | Solar Return | SR |
| 返照盘 | Return Chart | — |
| 三分主星 | Triplicity Ruler | — |
| Sect Light | 日生为日，夜生为月 | — |
| 盘主星 | Kurios / Oikodespotes / Lord of the Nativity | — |
| 界推进 | Distribution through the Bounds | — |
| 月小限 | Monthly Profection | — |
