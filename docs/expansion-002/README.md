# Expansion 002: 恒星与赤纬 + 中世纪技法深化

**日期**：2026-07-01
**状态**：规划中（文档编写阶段）
**分支**：待创建

---

## 概述

在 TransitStudio 当前古典/现代/吠陀/卜卦功能完备的基础上，向两个方向扩展：

1. **恒星与赤纬**（全模式底层增强）—— 新增赤纬、出界、平行/反平行相位、15-30 颗主要恒星合相
2. **中世纪技法深化**（古典模块专项深化）—— 年主与日返融合解读、50+ 阿拉伯点、三分主星序列、Kurios/Oikodespotes

选这两个方向的原因是：方向一低成本全模式受惠，方向二是古典模块的理论纵深——当前已有 Profection/Firdaria/ZR/Decennials，但在中世纪占星中，这些技法与日返盘的融合才是真正的预测核心。

---

## 执行顺序

```
Phase 1：恒星与赤纬（2-3 sessions，全模式收益，低耦合但需严格计算验证）
  │
  ├── 1.1 赤纬管线：calculate_body() 增加 declination / out_of_bounds
  ├── 1.2 平行/反平行：aspect 引擎新增 declination-based 维度
  ├── 1.3 恒星目录：Python 数据模块 + swe.fixstar2_ut() 调用
  ├── 1.4 恒星合相：行运扫描 + 本命盘新增事件类型
  └── 1.5 Swift 模型 + UI：PositionRow 扩展、表格列、事件标签
         │
         ▼
Phase 2：中世纪技法深化（4-6 sessions，仅古典模块）
  │
  ├── 2.1 阿拉伯点扩展：12 → 50+，沿用现有日夜反转模式
  ├── 2.2 三分主星序列：sect light 三分主 + ASC 三分主
  ├── 2.3 Kurios / Oikodespotes：中世纪综合盘主星判定
  ├── 2.4 年主 + 日返融合：返照 ASC vs 小限星座、年主在返照盘的状态
  └── 2.5 月度小限增强 + 界推进深化
```

---

## 影响范围

| 层级 | 恒星与赤纬 | 中世纪深化 |
|------|-----------|-----------|
| Python 后端 | `ephemeris.py`（体位管线）、`scan.py`（新事件类型）、新增 `fixed_stars.py` | `classical_lots.py`、`classical_audit.py`、`classical_timing.py`、`classical.py` |
| Swift 模型 | `TransitResultModels.swift`、`ClassicalCoreModels.swift` | `ClassicalResultModels.swift`、`ClassicalTimingModels.swift` |
| Swift 视图 | 本命表格、行运事件视图、扫描结果 | 古典结果面板时间标签页、新增"年主日返"区块 |
| 测试 | Python 恒星/赤纬单元测试、Swift 模型解码测试 | Python 扩展阿拉伯点单元测试、Kurios 回归测试 |
| 文档 | 计算规则.md 更新（恒星/赤纬 orb 规则） | 计算规则.md 更新（Kurios 判定逻辑、50 点公式表） |

---

## 文档索引

| 文件 | 内容 |
|------|------|
| `README.md`（本文件） | 总体概览与执行路线 |
| `fixed-stars-declinations.md` | 恒星与赤纬技术规格 |
| `star-catalog.md` | 30 颗恒星目录数据 |
| `medieval-deepening.md` | 中世纪技法深化技术规格 |
| `arabic-parts-expanded.md` | 50+ 阿拉伯点完整公式表 |

---

## 计算实现红线

- 赤纬/OOB 必须使用 Swiss Ephemeris `FLG_EQUATORIAL` 返回的赤纬，或使用包含黄纬 β 的完整黄道转赤道公式；不得只用黄经近似。
- Python `pyswisseph` 的黄赤交角常量是 `swe.ECL_NUT`，返回值需要解包；不要照抄 C 文档的 `SE_ECL_NUT`。
- 固定星功能上线前必须提供 `sefstars.txt`，并优先使用 `swe.fixstar2_ut()`；nomenclature fallback 要写成 `",alLeo"` 这种带逗号形式。
- 恒星合相采用黄经投影合相，不是球面角距；`applying` 要通过角距是否缩小判断，不能用顺行/逆行代替。
- Kurios/Oikodespotes 的 `compound_weighted` 是项目综合规则，不是唯一传统算法；Year Lord 只进入年度上下文，不改变本命 Kurios。

---

## 不纳入本次的范围

- 赤纬纬度（ecliptic latitude）在恒星合相中的应用（仅用黄经合相）
- 恒星 paran 关系（需要地平线同时性判断，复杂度高，单独立项）
- 超过 50 个阿拉伯点（保留将来扩展空间）
- 中世纪月度推进（仅深化月度小限，不做独立的月度主限）
- 寿限计算（Hyleg/Alcocoden 已有审计数据，不做具体年限输出）
