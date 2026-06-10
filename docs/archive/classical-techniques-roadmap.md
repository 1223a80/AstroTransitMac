# 古典技法剩余需求文档

## 已完成

以下是本轮已实现的古典技法，作为后续工作的基础：

- Hayz、喜乐宫 (Joys)、行星年 (Planetary Years)
- 映点 / 反映点 (Antiscia / Contra-antiscia)
- Primary Directions (Placidus Semi-Arc)，双向，含过去/未来标记
- Annual + Monthly Profection、Profected ASC
- Firdaria 次限
- Zodiacal Releasing L1/L2/L3 + Loosing of the Bond
- 返照盘增强（Profected ASC、宫位叠加、更多行星返照）
- Horary Translation / Collection / Prohibition / Frustration

---

## 未完成项

### 1. Decennials（十年主运）

**优先级：** 中  
**复杂度：** 中  
**涉及文件：** `astro_backend_classical.py`、`ClassicalResultModels.swift`、`ClassicalResultViews.swift`、`astro_backend_api.py`

**说明：**

Hellenistic 占星中的 timing 技法，类似 Firdaria 但以 10 年为周期。每个 10 年周期由一颗行星主宰，再细分为 10 个子周期。

**算法：**

- 周期表（从出生起）：
  - 昼盘：Sun 10 → Venus 8 → Mercury 13 → Moon 9 → Saturn 11 → Jupiter 12 → Mars 7
  - 夜盘：Moon 9 → Saturn 11 → Jupiter 12 → Mars 7 → Sun 10 → Venus 8 → Mercury 13
- 每个主限内按相同序列分配子限（去掉当前主限行星）
- 子限年数 = 主限年数 × (子限行星年数 / 总年数)

**输出：**

- 当前所在主限行星、起止时间
- 子限列表（行星、起止时间、占比）
- 集成到 timeline

**验收标准：**

- 计算结果与手工核对一致
- 子限正确嵌套在主限内
- Swift 视图可展开查看子限
- `swift build` 通过

---

### 2. Circumambulations through the Bounds（沿界推进）

**优先级：** 低  
**复杂度：** 高  
**涉及文件：** 新增 `astro_backend_circumambulations.py`、`ClassicalResultModels.swift`、`ClassicalResultViews.swift`、`astro_backend_api.py`

**说明：**

最精确的古典事件预测技法之一。沿着 Primary Direction 的弧度，逐个遍历界 (Bound) 的边界，每个边界的守护星在对应年龄"交付"事件。

**算法：**

- 从 ASC（或其他方向点）出发，沿黄经推进
- 每遇到一个界边界，记录：
  - 边界守护星
  - 该边界对应的年龄（弧度 / Naibod rate）
  - 交付事件的行星
- 需要 Egyptian Bounds 和 Ptolemaic Bounds 数据（已有）

**输出：**

- 边界推进列表（守护星、起止度数、起止年龄、交付行星）
- 当前所在界及其守护星状态

**验收标准：**

- 边界序列与 Ptolemy / Egyptian 表一致
- 年龄计算与 Primary Directions 一致
- `swift build` 通过

---

### 3. Triplicity Ruler 逐个评估

**优先级：** 低  
**复杂度：** 低  
**涉及文件：** `astro_backend_classical.py`

**说明：**

当前已识别昼主、夜主、参与主，但未分别评估每个主星的条件。完整的 Triplicity 评估应分别判断：

- 昼主 (Day Ruler)：是否入庙、是否顺行、是否在角宫
- 夜主 (Night Ruler)：同上
- 参与主 (Participating Ruler)：同上

**改动：**

- 修改 `dignity_labels()` 函数
- 输出每个 Triplicity Ruler 的独立评分和状态
- 更新 Swift 模型和视图

**验收标准：**

- 每个 Triplicity Ruler 有独立的状态文本
- 评分反映其实际条件
- `swift build` 通过

---

### 4. 更多行星返照盘

**优先级：** 低  
**复杂度：** 低  
**涉及文件：** `astro_backend_classical.py`、`astro_backend_api.py`

**说明：**

当前返照盘只计算 Sun、Moon、Venus。可以扩展到全部古典行星。

**改动：**

- 在 `RETURN_CONFIG` 中增加 Mercury、Mars、Jupiter、Saturn 的配置
- 在 `calculate_classical()` 中调用 `return_summary()` 时传入更多行星
- Swift 模型 `planetaryReturns` 数组自动接收

**配置参考：**

```python
RETURN_CONFIG = {
    "SUN": {"title": "Solar Return", "search_days": 4, "step_hours": 6, "kind": "annual"},
    "MOON": {"title": "Lunar Return", "search_days": 16, "step_hours": 2, "kind": "nearest"},
    "VENUS": {"title": "Venus Return", "search_days": 130, "step_hours": 8, "kind": "nearest"},
    "MERCURY": {"title": "Mercury Return", "search_days": 90, "step_hours": 6, "kind": "nearest"},
    "MARS": {"title": "Mars Return", "search_days": 700, "step_hours": 12, "kind": "nearest"},
    "JUPITER": {"title": "Jupiter Return", "search_days": 400, "step_hours": 12, "kind": "annual"},
    "SATURN": {"title": "Saturn Return", "search_days": 1100, "step_hours": 24, "kind": "nearest"},
}
```

**验收标准：**

- 新增行星返照盘正确计算
- 不影响现有返照盘
- `swift build` 通过

---

### 5. 行星年 Timing 预测

**优先级：** 低  
**复杂度：** 低  
**涉及文件：** `astro_backend_classical.py`、`ClassicalResultModels.swift`、`ClassicalResultViews.swift`

**说明：**

行星年 (Planetary Years) 已输出数值（如 Sun=19, Moon=25），但未用于 timing 预测。可以计算"行星年周期"事件：

- 从出生起，每过 N 年（N = 行星年数）是一个行星年周期
- 每个周期的守护星对应该行星的"回归"

**算法：**

- 对每颗古典行星，计算其行星年周期的倍数年龄
- 标记在 timeline 上

**输出：**

- 行星年周期列表（行星、年龄、日期）
- 集成到 timeline

**验收标准：**

- 周期年龄计算正确
- 在 timeline 中可见
- `swift build` 通过

---

### 6. ZR Loosing of the Bond 深化

**优先级：** 低  
**复杂度：** 中  
**涉及文件：** `astro_backend_classical.py`、`ClassicalResultModels.swift`

**说明：**

当前 Loosing of the Bond 检测只检查 L1 级别的对宫跳转。可以扩展到：

- L2/L3 级别的 Loosing of the Bond
- 更精确的"光线传递"判断（如 Lot 守护星是否在对宫）
- Loosing of the Bond 的"强度"评估（强/中/弱）

**改动：**

- 在 `_zr_sub_levels()` 中加入 Loosing of the Bond 检测
- 每个子周期的 `is_active` 标记旁边增加 `lob` 标记

**验收标准：**

- L2/L3 级别的 Loosing of the Bond 被正确检测
- 标记在 UI 中可见
- `swift build` 通过

---

## 实现建议

| 阶段 | 内容 | 预估工作量 |
|------|------|-----------|
| 第一阶段 | Triplicity Ruler 评估 + 更多返照盘 + 行星年 Timing | 低（改动集中，算法简单） |
| 第二阶段 | Decennials | 中（新算法，需新视图） |
| 第三阶段 | Circumambulations + ZR Loosing of the Bond 深化 | 高（算法复杂，需跨模块协调） |
