# 现代占星扩展能力评估（2026-07-13）

## 结论

进一步扩展的可行性高。项目已经具备稳定的 Swiss Ephemeris 位置/宫位计算、JSON 模式分发、精确过境求根、关系盘、次限、太阳弧、调和盘、图形识别、Swift Codable/导出和回归测试。下一阶段不需要重写架构，重点是把现有原语组合成完整工作流，并把方法选择显式写入请求与 `meta`。

这里的“价值”指现代占星软件用户的使用频率、分析闭环和产品区分度，不代表对占星有效性作科学背书。

## 当前现代能力基线

| 领域 | 已有能力 | 主要边界 |
|---|---|---|
| 本命 | 十大行星；可选 Chiron、Pholus、Ceres、Pallas、Juno、Vesta、真/平均交点、Lilith、自定义小行星；宫位、主要/次要/自定义相位 | 图形/盘型引擎没有接入现代本命页；Vertex、East Point 未输出 |
| 赤纬与恒星 | 精确赤纬、平行/反平行、出界、固定星合相已由后端计算；Markdown 导出已包含 | 现代本命 UI 没有独立入口；高级现代模式没有统一继承这些字段 |
| 行运 | 单时点行运对本命；精确窗口扫描支持相位、入宫/换座边界目标、星座 ingress、station、宫头/Lot/自定义度数目标 | 没有 entering-orb / exact / leaving-orb 生命周期，没有多次逆行命中分组，也不能混合推进/太阳弧/食相事件 |
| 关系 | Synastry 跨盘行星相位、互落宫；Composite；Davison；部分盘型识别 | Synastry 相位只使用行星列表，不含双方角点；没有关系推运、Composite/Davison 行运或 Progressed Composite |
| 推运 | 次限推进（day-for-year）单时点、推进盘/本命相位、推进盘内部相位、推进月相快照 | 当前月相快照不能区分盈亏；没有精确事件时间线、推进月亮换座/换宫、月相精确日期、tertiary/minor/converse 变体 |
| 太阳弧 | true solar arc 单时点，行星/角点/宫头同弧推进，SA→本命相位，可选图形 | 没有事件搜索、Naibod/mean key、converse 或其他 arc key |
| 调和盘 | 任意整数阶调和盘、行星与相位 | 宫位明确标为 experimental；没有年龄调和、调和合盘或调和时间线 |
| 图形 | T 三角、大三角、大十字、风筝、Yod、神秘矩形、星群和九类 chart shape | 当前主要接入 Composite/Davison，现代本命未使用 |

现代时基与关系模块现有聚焦回归：`45 passed`。

## 扩展前应先修的基线问题

1. **非 Whole Sign Composite 宫位必然降级。** `astro_backend_composite.py` 用两个变量接收 `build_houses()` 的三个返回值；非整宫分支因此触发 `too many values to unpack (expected 2)`，随后回退等宫。现有 sample 使用 Whole Sign，没有覆盖此路径。
2. **推进月相不能区分盈亏。** `_calc_lunation()` 使用只返回 `0...180°` 的 `angular_separation()`，所以 Moon 位于 Sun 前方 90° 与后方 90° 都输出“上弦月”；225°、270°、315° 三个配置角永远不可达。新增推进时间线前应先改为有向日月相位角并补回归。

这两项属于现有正确性债务，不应和新技法混在同一个“新增功能”提交里。

## 推荐优先级

规模定义：`S` 为主要复用现有响应/视图；`M` 为新增一个完整模式或事件模型；`L` 为跨模式时间搜索或地图工作流；`XL` 为新计算体系加专用交互。

### P0：先补齐高频闭环

| 技法/能力 | 价值 | 复用与工作量 | 必须明确的口径 |
|---|---|---|---|
| 现代本命结构层：盘型/相位图形、元素/模式/极性、半球/象限、强调点 | 很高；本命页目前偏“原始数据表”，缺少现代综合阅读入口 | 图形与 chart shape 已有，新增分布统计与展示，`S–M` | 采用哪些天体、星群阈值、是否计入交点/小行星 |
| Vertex、East Point（Equatorial Ascendant）及其相位 | 高；尤其关系盘和事件触发常用 | Swiss houses 结果已经包含额外轴点，本地适配器目前只保留 ASC/MC，`S` | 高纬度异常、是否默认启用、出生时间不详时禁用 |
| 赤纬技法完整露出：parallel、contraparallel、OOB | 高；计算已经存在，是最低成本增益 | 主要是 UI、统一模型与筛选，`S` | 各场景 orb；纬度相位与赤纬相位是否分开 |
| Solar Return / Lunar Return 现代返照盘 | 很高；补齐预测核心工作流 | 古典模块已有精确 return 搜索和完整 snapshot 经验，应抽出通用 solver，再生成现代盘，`M` | 返照地点、本命地点还是现居地；热带/恒星；precession correction；双盘 overlay |
| 综合动态时间线 | 最高；把已有“单点计算”升级为真正可用的预测工具 | 复用 scan 的步进/二分求根、station/ingress 与现有推进/SA 计算，`M–L` | entering/exact/leaving、逆行三次命中分组、事件去重、各技法独立 orb/权重 |

### P1：形成产品差异

| 技法/能力 | 价值 | 复用与工作量 | 必须明确的口径 |
|---|---|---|---|
| Midpoints：本命中点表、中点树、行运/推进/SA 命中 | 很高；现代、Cosmobiology、Uranian 共用的基础 | 已有 circular midpoint 与 Composite 中点逻辑，先做 360° 中点树，后加 45°/90° dial，`M` | 两个对径中点的表示、半和/全和、容许度、敏感点集合 |
| 关系时间技法：Transits/Progressions/SA → Composite/Davison；Progressed Composite | 高；直接放大现有关系盘投入 | 复用关系盘与三种时基模块，`M–L` | Composite 宫位方法、两人独立出生时区、参考地点、是否推进双方后再取中点 |
| 食相与朔望周期：新月/满月、日月食、对本命接触 | 高；可进入预测时间线和月度视图 | 已安装的 Swiss Ephemeris 暴露 solar/lunar eclipse API；朔望可复用求根，`M` | 本地可见性 vs 全球事件、交点距离、食相前后影响窗不应伪装成天文量 |
| Relocation Chart | 高；计算简单、实用闭环清楚 | 同一出生 UTC 重算新地点宫位/角点即可，`S–M` | 行星保持地心位置；地点时区只用于显示，不能重新解释出生时刻 |
| Astrocartography + Local Space | 高潜力，但 UI 成本高 | Swiss Ephemeris 提供 houses、sidereal time、azimuth/altitude 原语；需要全球线求解、地图、反子午线/极区处理，`L–XL` | A*C*G 四轴线、parans 是否纳入、地图数据/缓存、地点比较与容差 |
| 现代关系盘补全 | 高；是现有功能的明显缺口 | 将双方 ASC/MC/DSC/IC、Vertex、交点、Chiron/Lilith/小行星纳入可配置 point set；补赤纬跨盘相位，`S–M` | 角点与非实体点的 orb 应独立；出生时间不详时自动降级 |

### P2：成熟度扩展

| 技法/能力 | 价值 | 复用与工作量 | 必须明确的口径 |
|---|---|---|---|
| Draconic natal / natal-draconic / draconic synastry | 中高、实现相对轻 | 以选定北交点为 0° 白羊，统一平移行星和宫头，`S–M` | 真/平均交点；需标注为解释性、争议较大的体系 |
| 次限事件化与变体 | 中高 | 先做推进月亮换座/换宫、推进相位精确日期、推进朔望；再考虑 converse、tertiary、minor，`M–L` | 年长、日年换算、推进角点算法、直接/逆向 |
| 太阳弧方法扩展 | 中高 | 在现有 true solar arc 上增加 mean/Naibod key、direct/converse、用户 arc，`M` | key、角点/宫头处理、弧方向必须写入 provenance |
| Composite/Davison 方法变体与 Multi-Composite | 中 | Astrodienst 等成熟软件提供 midpoint/reference-place、Davison 多变体与多人组合；当前实现只有单一路径，`M–L` | 参考地点、球面/经纬中点、对径 midpoint 决策、多人权重 |
| 年龄调和与调和关系盘 | 中 | 复用现有 harmonic 转换，`M` | 年龄定义、Houses 默认应关闭或继续标 experimental |
| 图形星历 / 45°、90° dial | 中高但属专用工作流 | 复用动态事件和 midpoint，专用可视化工作量较大，`L` | modulus、点集、线条密度与交互筛选 |

### P3：有价值但不应抢先

- Persona charts。
- 行星交点、近日点/远日点、Priapus；Swiss Ephemeris 有 nodes/apsides API。
- Heliocentric charts 与地心/日心对照。
- 固定星 parans、heliacal rising/setting。
- 完整 Uranian 体系：8 hypothetical planets、planetary pictures、90° dial。建议先完成普通 midpoint tree，再决定是否引入假想星体。
- 地理占星的 geodetic/Johndro 变体。
- Tertiary/minor progressions、phase returns、demi/quarti returns。

## 不建议当前优先

- **继续堆小行星名称与解释包**：项目已支持自定义小行星编号，先解决跨模式 point set 一致性和筛选体验更有价值。
- **Sabian symbols/大量度数文本**：这是内容与授权问题，不是当前计算能力瓶颈；需要单独确认文本来源和许可证。
- **先做 AI 解释再补结构化结果**：应先产出可验证的事件、方法、orb、时间与 provenance，再让现有 AI 层消费。
- **把所有技法塞进一个 mode**：继续采用一技法一模块或共享 event engine + 明确 source type，避免响应契约失控。

## 推荐施工顺序

1. **Modern Baseline Fixes**：修复 Composite 非整宫分支与推进盈亏月相，补 focused regression。
2. **Modern Completeness**：现代本命图形/盘型、Vertex/East Point、赤纬/OOB UI；统一高级现代 point set。
3. **Modern Returns**：Solar Return + Lunar Return，共用通用 return solver，支持返照地点和本命 overlay。
4. **Forecast Timeline v1**：Transits + station/ingress + Secondary Progression + Solar Arc 精确命中，支持多次命中分组。
5. **Midpoints v1**：本命中点树、行运/推进/SA 命中；暂不引入 Uranian hypothetical planets。
6. **Relationship Timing**：Composite/Davison 行运、推进、太阳弧及 Progressed Composite。
7. **Locality & Cycles**：Relocation、食相/朔望；随后再单独立项 Astrocartography/Local Space。

## 架构实施注意事项

- 新模式必须同步：`astro_backend_api.py` 白名单/校验/分发、Python 模块、Swift request/result、`ModernSubMode`、结果 tab、Markdown/CSV/JSON 导出、Example、Python 聚焦测试、真实 fixture 和 Swift contract test。
- 不要给动态事件复用当前 snapshot `AspectHit`。建议独立 `ModernTimingEvent`，至少包含 `source_type`、moving/fixed point、aspect、phase、exact UTC/local、orb window、pass index/count、method/provenance。
- 将高级现代模块中硬编码的“十大行星 + Node”改为共享 `point_set`，但先保持现有默认值，避免契约突然膨胀。
- 出生时间不详时，行星黄经类技法仍可运行；角点、宫位、Vertex、relocation/locality、关系互落宫必须明确降级或禁用。
- 动态时间线沿用 scan 的工作量估计、确认阈值、取消与进度机制。
- 方法差异必须进入请求和 `meta`；不能用 UI 文案掩盖后端默认值。

## 依据

项目内：

- `Sources/TransitStudio/ModernResultModels.swift`
- `Sources/TransitStudio/Resources/backend/astro_backend_api.py`
- `Sources/TransitStudio/Resources/backend/astro_backend_scan.py`
- `Sources/TransitStudio/Resources/backend/astro_backend_progressions.py`
- `Sources/TransitStudio/Resources/backend/astro_backend_solar_arc.py`
- `Sources/TransitStudio/Resources/backend/astro_backend_synastry.py`
- `Sources/TransitStudio/Resources/backend/astro_backend_composite.py`
- `Sources/TransitStudio/Resources/backend/astro_backend_davison.py`
- `Sources/TransitStudio/Resources/backend/astro_backend_harmonic.py`
- `Sources/TransitStudio/Resources/backend/astro_backend_patterns.py`
- `Sources/TransitStudio/Resources/backend/astro_backend_classical.py`

外部能力/行业基线：

- Astrodienst, Overview Chart Types: <https://www.astro.com/cgi/h.cgi?f=gch&h=gchrtype&lang=e>
- Astrodienst, Solar Return Chart: <https://www.astro.com/cgi/h.cgi?f=gch&h=gch32&lang=e>
- Astrodienst, Draconic Chart: <https://www.astro.com/cgi/h.cgi?f=gch&h=gch202&lang=e>
- Swiss Ephemeris Programming Interface: <https://www.astro.com/swisseph/swephprg.htm>
- Solar Fire feature baseline (official publisher): <https://www.alabe.com/sf6p2.htm>

## 本轮验证

```text
PYTHONDONTWRITEBYTECODE=1 .venv/bin/python -m pytest -q -p no:cacheprovider \
  python_tests/test_modern_timebased.py python_tests/test_modern_relationship.py

45 passed in 0.16s
```

六个现代高级 sample（Synastry、Composite、Davison、Progression、Solar Arc、Harmonic）均成功输出预期顶层结构，且 warning count 为 0。

另外做了两个只读边界探针：

```text
Composite + placidus → "Composite 宫位重建失败，已回退等宫：too many values to unpack (expected 2)"
progressed Sun/Moon = 0°/90°  → 上弦月
progressed Sun/Moon = 0°/270° → 上弦月
```
