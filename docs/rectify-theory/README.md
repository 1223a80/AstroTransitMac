# 生时矫正理论内核

本目录描述后端 `mode=rectify_evidence` 和 `rectification-evidence-packet/1.0`。它是生时矫正「事件证据」工作区的计算与证据层；mode 仍作为 backend-only 契约由现有 `.rectify` 流程消费，不新增导航模式，也不自动断言某个候选是真实出生时间。

## 设计目标

现有 UI 的 `mode=rectify` 主限候选浏览器继续生成三级时间网格并展示大量方向；同一结果区另有「事件证据」工作区，让用户为当前滑杆候选维护人生事件输入并读取方法独立性与候选证据。证据内核解决的是理论和数据契约问题：

1. 同一组有明确时间窗口的人生事件必须用于每个候选。
2. 主运动、行运、次限和太阳弧必须分别输出，不将相关技术机械相加。
3. 代理、正式几何子集、完整方法和实验方法必须使用不同 profile 名称。
4. 事件可以标记为 holdout，供应用层进行样本外检查。
5. 后端只输出证据，不输出任意总分、最佳出生时间或虚假的秒级置信度。

占星生时矫正没有建立科学有效性。这里的 `formal` 只表示公式、输入、求根和方法 provenance 是明确的，不表示占星解释得到科学验证。

## 计算链路

```text
结构化出生资料
  → 候选绝对时间网格
    → 每个候选重算四轴
      → 每个有来源的人生事件窗口
        ├─ 主运动：行星 → ASC/MC/DSC/IC
        ├─ 行运：移动星体 → 候选本命四轴（精确求根）
        ├─ 次限：day-for-year 星体 → 候选本命四轴（精确求根）
        └─ 太阳弧：true-solar-arc 点 → 候选本命四轴（精确求根）
          → 按方法家族和独立性组输出 evidence
```

## 方法层级

| Profile | 状态 | 用途 | 独立性组 |
|---|---|---|---|
| `primary_motion_planet_to_angles_v1` | 正式几何子集 | 精细时间证据 | `primary_motion` |
| `transit_to_natal_angles_exact_root_v1` | 正式天文时序 | 独立复核 | `transit` |
| `secondary_progression_day_for_year_to_angles_v1` | 正式命名 profile | 复核 | `day_for_year` |
| `solar_arc_true_sun_to_angles_v1` | 正式命名 profile | 复核 | `day_for_year_solar_anchor` |

次限和 true solar arc 都使用 day-for-year 太阳锚点，因此只能视为部分独立；应用层不得把它们当作两个完全独立的统计样本。

### 主运动角度方向

`primary_motion_planet_to_angles_v1` 只实现出生时间最敏感、几何定义清楚的行星到四轴合相方向。

1. 使用行星真实黄经和黄纬转换赤经、赤纬：

   ```text
   x = cos β cos λ
   y = cos β sin λ cos ε − sin β sin ε
   z = cos β sin λ sin ε + sin β cos ε
   RA  = atan2(y, x)
   Dec = asin(z)
   ```

2. MC/IC 使用赤经；ASC 使用斜升，DSC 使用斜降：

   ```text
   AD = asin(tan φ tan Dec)
   OA = RA − AD
   OD = RA + AD
   ```

3. 目标轴坐标由 ARMC 得到：MC=`ARMC`、IC=`ARMC+180°`、ASC=`ARMC+90°`、DSC=`ARMC+270°`。
4. 方向弧采用 `target − promissor` 的最短有符号弧；出生后年龄使用绝对弧除以所选 key。
5. `naibod_mean=0.98564733°/年` 与 `one_degree_per_year=1°/年` 是相互独立的 key profile，不混合。
6. 当 `|tan φ tan Dec| > 1` 时，该星体在该纬度下绕极，ASC/DSC 升降方向不伪造；MC/IC 方向仍可计算。

这个 profile **不是完整 Placidus 或 Regiomontanus 主限**。它不含：

- 非角度 significator；
- zodiacal / mundane aspects；
- Placidus under-the-pole；
- 完整 converse 重算；
- 中间宫、福点、固定星方向；
- 不同传统对 promissor/significator 和黄纬的全部选择。

因此不能把旧 `simplified_longitude_semi_arc_proxy_naibod` 静默替换为本 profile，也不能把本 profile 改名为 `full_placidus`。

### 行运、次限与太阳弧

三个家族复用 `astro_backend_modern_timing.calculate_modern_timing`：

- 只允许 `event_types=["aspect"]`；
- 目标点限制为候选四轴；
- 只返回用户事件窗口内实际求得的 exact root；
- aspect、移动星体和 orb 都来自请求或保守默认值；
- 事件 ingress、station、月相等不混入本证据包。

默认配置有意保持克制：行运使用木星至冥王星，次限使用日月，太阳弧使用七曜及 ASC/MC，aspect 只用合、刑、冲。调用方可以显式覆盖，但所有扩展都会增加多重比较风险。

## 事件资料

每个事件必须提供：

- 稳定且唯一的 `id`；
- 明确的 `start` 与 `end` ChartMoment；
- `source_quality`；
- `confidence`（0...1）；
- `holdout`。

`source_quality` 只记录资料来源，不参与当前后端评分：

- `documented_exact`
- `documented_day`
- `remembered_day`
- `remembered_period`
- `approximate`

事件窗口由用户给出，后端不根据模糊描述自动发明 ±天数。推荐至少保留两个 `holdout=true` 事件，不参与未来应用层拟合，只用于复核候选是否具有样本外一致性。

## 为什么当前不加入小限、返照和 Animodar

- 年小限、Firdaria、Decennials、Zodiacal Releasing 更适合提供时期或年度主题，通常不能稳定区分相邻一分钟候选。
- 太阳返照适合作为年度条件层，但返照地点选择会影响轴点，必须先单独固定口径。
- Circumambulations/Distributions 与主运动同属方向家族，不是独立证据。
- Animodar 是历史候选生成规则，不是人生事件的样本外验证；项目当前满月产前朔望的太阳轴 convention 也不能直接当作 Animodar 所需的地平线上发光体。

这些方法以后可以进入 `context_evidence`，但不能与分钟级证据共用一个未校准总分。

## Swift 应用层约束

Swift UI 读取本 packet 时必须遵守：

- 显示每个方法家族，不默认折叠成单一命中数；
- 显示 source quality、holdout 和事件窗口；
- 用候选曲线或时间区间表达结果，不默认精确到一秒；
- 任何评分权重都必须来自单独的校准/回测文档，而不是在 UI 中硬编码；
- `scientific_validation=not_established` 和方法限制必须可见。

当前实现以滑杆选中的绝对时刻作为 evidence `birth.moment`，请求 `candidate_window_seconds=0`、`candidate_step_seconds=1`、`max_candidates=1`。这保留三级滑杆作为唯一候选选择器，避免在证据工作区复制第二套搜索或暗中排名。滑杆任一级变化都会取消在途 evidence 请求并使旧结果失效。

应用的出生/事件时区可为固定 GMT 偏移；Modern Timing 的 `display_timezone` 内部使用 `UTC`（IANA），Swift 再把 `exact_utc` 按当前固定偏移显示，避免将 `GMT+5:30` 等标签误传给只接受 IANA 的显示时区解析器。

字段级说明见 [FIELD_DICTIONARY.md](FIELD_DICTIONARY.md)，验证计划见 [VALIDATION.md](VALIDATION.md)。

## 参考与来源边界

- Ptolemy, *Tetrabiblos* III：历史上的出生度数校正与产前朔望规则。
- Martin Gansten, *Primary Directions: Astrology's Old Master Technique*：不同主限传统与计算口径的现代研究参考。
- Morinus 开源实现：只作为方法范围、speculum 字段和未来外部数值交叉验证参考；本项目没有复制其代码。
- Swiss Ephemeris：星历、宫位和 ARMC 的天文计算来源。
