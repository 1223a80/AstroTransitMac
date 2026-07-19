# Transit Studio：B6 后现代与古典占星计算扩展规划

日期：2026-07-19
状态：规划中，本文所列项目除“现有能力”外均不代表已经实现
基线：B6 已完整收口、通过门禁并合入 `main`

## 1. 目标与边界

下一阶段的目标不是继续堆界面标签，也不是先生成解释性文案，而是扩展可以在本机完成、可以复算、可以审计的占星计算能力，并为每一种能力提供结构化 JSON 与可选择章节的 Markdown 输出。

本文主要讨论现代占星和古典占星。吠陀占星仅保留为远期路线，不占当前施工优先级。

本轮不重复规划已经由 B1–B6 完成的能力，包括：

- 现代 point set、Vertex / Antivertex / Equatorial Ascendant 等轴点。
- 本命赤纬、平行 / 反平行、OOB 静态结果。
- Solar / Lunar Return v1。
- 现代综合时间线的 entering / exact / leaving、逆行多次命中编号。
- Midpoint 360° 轴、行运 / 次限 / 太阳弧激活。
- Composite / Davison 关系推运与 Progressed Composite。
- Relocation、现代朔望 / 食相、Astrocartography、Local Space。
- 古典年小限、月小限、Firdaria、Decennials、ZR L1–L3、七政返照、主限、沿界推进、产前朔望、Almuten、Hyleg / Alcocoden 审计。

## 2. 规划原则

### 2.1 计算事实优先

每个新功能先输出事实：坐标、时间、周期、相位、容许度、速度、方法、公式参数和异常。不要把解释文本作为算法正确性的替代品。

### 2.2 方法必须显式

同名技法若有不同流派或公式，必须使用显式 `method_profile`，并在 `meta` 与 Markdown 中显示。例如：

- `node_mode=true|mean`
- `progressed_angles=naibod|solar_arc_mc|armc_361`
- `primary_direction_method=placidian_semiarc|regiomontanus`
- `latitude_mode=include|ignore`
- `solar_arc_key=true_sun|naibod_mean|custom`

禁止把方法差异隐藏在 UI 文案或默认值里。

### 2.3 输出可追溯

建议所有新响应遵循：

```text
meta
requested_config
effective_config
results
timing_events（如适用）
warnings
section_errors
calculation_assumptions
```

每个关键结果尽量包含：

```text
method_key
source_profile
input_values
formula_trace
exact_utc / exact_local
longitude / declination / speed
orb_limit / exact_orb
quality_flags
```

### 2.4 Markdown 是正式交付面

每个功能都必须有 Markdown，不接受“只有 Raw JSON”。Markdown 至少包括：

1. 输入与方法；
2. 结果表；
3. 时间线或周期表；
4. 计算假设；
5. 警告与未计算项。

长结果应接入 section picker，不强迫用户导出全部内容。

### 2.5 不为每个技法增加一级导航

优先采用“现代特殊盘”“现代周期”“古典状态”“古典时间技法”等计算包，在现有实践模式下增加子模式或可选模块。后端仍保持一技法一模块，UI 不必一模块一入口。

## 3. 当前真正值得补的现代占星能力

### M1. 动态赤纬事件与 OOB 时间线

优先级：P0
工作量：M
价值：很高

当前已有静态赤纬和静态平行 / 反平行，但动态时间线只搜索黄经事件。下一步应增加：

- 行运体对本命点的精确平行。
- 行运体对本命点的精确反平行。
- 次限点、太阳弧点的平行 / 反平行事件。
- 进入 OOB、离开 OOB。
- 最大北赤纬 / 最大南赤纬时刻，即赤纬速度过零。
- 赤纬容许度的 entering / exact / leaving 生命周期。
- 同一事件因逆行或赤纬回转产生的多次命中分组。

建议事件字段：

```text
coordinate_kind=declination
event_type=parallel|contraparallel|oob_entry|oob_exit|declination_station
moving_declination
target_declination
declination_speed
oob_threshold
threshold_method
```

必须明确 OOB 阈值采用“事件时刻真实黄赤交角”还是固定值；建议采用事件时刻黄赤交角，并在 `meta` 中记录。

Markdown 示例：

```markdown
## 赤纬动态事件

| 精确时间 | 来源 | 移动点 | 事件 | 目标点 | 赤纬 | 精确差值 | 命中次数 |
```

### M2. 任意行星返照

优先级：P0
工作量：S–M
价值：很高

现代返照后端目前只允许太阳和月亮，但现有 return solver 和古典七政返照已经证明通用求根路径可用。建议扩展：

- Mercury / Venus / Mars / Jupiter / Saturn Return。
- Uranus / Neptune / Pluto Return。
- 可选 Chiron Return。
- 每个周期保留全部精确穿越，而不是假设只有一次命中。
- previous / current cycle / next 语义。
- 返照盘内部相位、返照对本命相位、宫位叠加。
- 返照地点、黄道、宫制、节点模式和 precession correction provenance。

第一期不建议把月交点返照和普通行星返照混在一起；节点运动方向、真 / 平交点及多根语义应单独设计。

Markdown 示例：

```markdown
## 木星返照

- 周期序号：2
- 精确时间：...
- 同周期穿越：第 2 / 3 次
- 返照地点与宫制：...

### 返照盘
### 返照对本命相位
### 宫位叠加
```

### M3. 任意行星对的会合周期工作台

优先级：P0
工作量：M
价值：很高

B6 已有日月朔望和食相，但还没有通用行星对周期。建议增加：

- 任意两星的合、冲、四分和可配置相位周期。
- 相邻两次合相定义一个 synodic cycle。
- 当前周期的开始、结束、完成比例与当前相位。
- 精确时间、双方黄经、相对速度、顺逆行状态。
- 同一相位因逆行产生的多次命中。
- 周期事件对本命 point set 的接触。
- Jupiter–Saturn 等长周期的历史 / 下一周期输出。

推荐后端形状：

```text
mode=planetary_cycles 或扩展 modern_cycles
pair={body_a, body_b}
phases=[0,90,180,270]
start/end
target_point_set
```

该功能可覆盖火星周期、金星会合、木土周期及外行星相互周期，而不需要为每一对行星创造独立算法。

### M4. 逆行完整周期与阴影区

优先级：P0–P1
工作量：M
价值：很高

已有 station 事件，但还缺完整逆行周期包：

- 逆行站与顺行站。
- 逆行站度数、顺行站度数。
- 前阴影进入：首次到达顺行站度数。
- 后阴影离开：再次越过逆行站度数。
- 逆行区间、前阴影、后阴影的起止时间。
- 逆行期间重复命中的本命点。
- 周期内每个目标的第 1 / 2 / 3 次命中。

阴影区必须用实际两次 station 的黄经定义，不能用固定天数近似。

### M5. Draconic 计算包

优先级：P1
工作量：S–M
价值：高

建议交付：

- Draconic Natal。
- Natal ↔ Draconic comparison。
- Draconic Synastry。
- 真交点 / 平交点选择。
- 行星、轴点、宫头、Lots 的统一平移。
- Natal–Draconic 跨盘相位与互落宫。

计算定义应显式为：把选定北交点平移到 0° Aries，其他点使用相同角度平移。单一 Draconic 盘内部相位不会因整体平移而变化，产品重点应放在星座位置和跨黄道比较，不应重复制造一份“新内部相位”。

### M6. 次限方法族

优先级：P1
工作量：L
价值：高

当前已有 day-for-year 次限及其精确事件。建议扩展为方法族：

- Converse Secondary Progression。
- Tertiary Progression I。
- Tertiary / Minor Progression II。
- Progressed angles 方法选择：
  - 现有 progressed-date houses；
  - Naibod key；
  - MC from solar arc；
  - ARMC 361° / progressed day。
- 推进月亮换宫、推进角点事件。
- 各种方法对同一参考日期的并排比较。

不同软件对推进轴点的方法并不一致，不能把它们视为等价。请求与结果必须显示 rate、year length、reference UTC、progressed JD 和 angle method。

### M7. 太阳弧方法族

优先级：P1
工作量：M
价值：高

当前只有 true solar arc。建议增加：

- True Solar Arc。
- Mean / Naibod Arc。
- Direct / Converse。
- 用户自定义 arc key。
- 按选定方法推进 planets / angles / cusps。
- 精确事件时间线与方法对照。

每一条命中必须记录弧值、方向、key 和被推进点类型。

### M8. 行星节点与近日点 / 远日点

优先级：P1–P2
工作量：M
价值：中高

本机 Swiss Ephemeris 已提供 `nod_aps_ut`，可以离线计算：

- 各行星升交点 / 降交点。
- Perihelion / Aphelion。
- mean / osculating / barycentric osculating 等 method flag。
- 这些轨道点的本命位置、相位和动态激活。
- 行星穿越自身或其他行星轨道点的时间。

必须把这些点与月交点分开命名，避免 UI 和 Markdown 中的“北交点”歧义。

### M9. 行星天文现象数据包

优先级：P1–P2
工作量：S–M
价值：中高

本机 `pheno_ut` 可直接输出：

- phase angle。
- illuminated fraction。
- elongation。
- apparent diameter。
- apparent magnitude。
- 月球 horizontal parallax。
- 地心距离、日心距离和速度可由现有位置管线补齐。

该功能适合做成“纯天文事实”区块，供现代周期、古典可见性和 Markdown 报告复用。

### M10. Heliocentric / Geocentric 对照盘

优先级：P2
工作量：M
价值：中等

建议交付：

- Heliocentric planets + Earth。
- 无 houses / ASC / MC 的明确降级。
- heliocentric 内部相位。
- geocentric ↔ heliocentric 跨坐标对照。
- `coordinate_center=geocentric|heliocentric` 明确写入每一行。

### M11. 45° / 90° Dial 与 planetary pictures

优先级：P2
工作量：L
价值：中高、专业化

现有 midpoint v1 明确限制 modulus=360。下一步可以增加：

- 45° / 90° modulus。
- 半和、全和与对径轴。
- A/B = C/D midpoint equivalence。
- A = B/C、A+B−C 等 planetary pictures。
- 行运 / 次限 / 太阳弧对 dial 的精确命中。
- 纯 Markdown 的 midpoint tree 与命中表。

第一期只使用真实天体和现有 point set，不引入 Uranian hypothetical planets。

### M12. 年龄调和与关系调和盘

优先级：P2
工作量：S–M
价值：中等

复用现有 harmonic 引擎增加：

- Age Harmonic。
- Harmonic Synastry。
- Harmonic Composite。
- 指定 5 / 7 / 9 等阶数的批量对照。
- houses 继续保持 experimental 或默认关闭。

### M13. Persona Charts

优先级：P3
工作量：M
价值：中等、解释依赖较强

可定义为出生后太阳首次精确合相本命指定点的时刻盘。需要：

- 指定 natal planet / angle。
- first-after-birth 根搜索。
- 精确时刻盘、对本命相位和方法来源。
- 轴点 Persona 在高纬或出生时间不明时禁用。

应在 Draconic、进阶推运和周期工作台之后实施。

## 4. 当前真正值得补的古典占星能力

### C0. Primary Directions 方法审计与方法化

优先级：P0 先审计，P2 再扩展
工作量：审计 M；完整实现 XL
价值：极高，但风险也最高

当前实现是单一、简化的 arc 模型：固定 Naibod rate、基于黄经推导赤经 / 赤纬、没有完整保留行星黄纬，也没有形成传统方法 profile。它适合作为已有实验方法，但不能直接向上叠加十几个选项并声称“完整主限”。

第一阶段应先：

- 明确当前算法名称和适用边界。
- 为每条方向输出 promissor、significator、zodiacal / mundane、latitude mode、key、arc trace。
- 建立至少两套外部参考盘和容差表。
- 将“算法计算失败”与“该方向在年龄窗口外”分开。

完成基线审计后，再考虑 C9 的完整方法族。

### C1. Heliacal Phases / 可见相位

优先级：P0
工作量：M
价值：很高

Swiss Ephemeris 本机接口已经支持行星和恒星的 heliacal phenomena。建议增加：

- Morning first / heliacal rising。
- Evening last / heliacal setting。
- Mercury、Venus、Moon 的 evening first / morning last。
- 事件时刻、方位、高度、太阳高度、视星等和可见性参数。
- 本命日前后最近一次可见事件。
- 指定年份 / 时间窗内的可见事件时间线。
- 大气压、温度、湿度、海拔、观测方式的默认与有效值。

官方接口对适用纬度有边界，超界必须明确 warning，不能回退成普通日出日落。

此功能应输出天文可见性事实；“phasis 属于哪一种古典状态”的判断另由 source profile 完成。

### C2. Hellenistic Planetary Condition Audit

优先级：P0–P1
工作量：M–L
价值：很高

现有 essential dignity、sect、hayz、joy、solar phase、motion、reception 已经是很好的基础。建议增加一套证据化状态审计：

- oriental / occidental。
- superior / inferior planet relationship。
- overcoming / being overcome。
- enclosure / besiegement。
- bonification / maltreatment。
- spear-bearing / doryphory。
- chariot 条件。
- applying assistance 与 separating testimony。
- angularity 与 Sun-relative phase 的联合证据。

输出应是条件列表，不应先合成为“吉 / 凶分数”。每条记录包括：

```text
condition_id
subject
actors
geometry
applying/separating
orb
source_profile
evidence
```

不同作者的定义应作为可选 profile，不能混为一个自创规则。

### C3. 完整 Dodekatemoria / Twelfth-parts 盘

优先级：P1
工作量：S–M
价值：高

当前只在七政行中附带 twelfth-part longitude / ruler。建议扩展为完整派生盘：

- 七政、四轴、Lots 的 dodekatemoria。
- 派生点所在本命宫。
- dodekatemoria 彼此的 sign-based aspects。
- dodekatemoria 对本命七政 / 角点 / Lots 的接触。
- 独立 Markdown 表与 cross-reference。

### C4. Monomoiria / Degree Rulers

优先级：P1
工作量：S–M
价值：中高

增加每一度的 ruler：

- planets、angles、lots 的 degree ruler。
- method profile 和度数边界。
- degree ruler 的本命状态、宫位与接纳。
- 不同 monomoiria 表之间的对照，若项目选择支持多个传统。

### C5. Topical Almutens

优先级：P1
工作量：M
价值：高

已有 Almuten Figuris 的尊贵分表，可以复用为专题 Almuten 引擎：

- 各宫 cusp 的 Almuten。
- profession / marriage / children / property 等主题点集。
- 主题 Lots、宫主、宫内行星、自然征象星的贡献。
- 每个候选的 domicile / exaltation / triplicity / bound / face 明细。
- 冲突、并列和缺失证据。

必须把“计算出的最高尊贵贡献者”与“解释结论”分开。

### C6. Profections 扩展

优先级：P1
工作量：M
价值：高

现有 ASC 年 / 月小限可扩展为：

- Daily Profection。
- 从 Sun、Moon、Fortune、Spirit、MC 及用户选择点起算。
- 每层 activated sign / house / lord。
- 年 → 月 → 日三级嵌套时间线。
- 年主 / 月主 / 日主在 natal 和 return chart 中的状态对照。
- 与现有 Solar Return synthesis 合并成 concordance 表，而不是再写一段不可审计的自动解读。

### C7. Zodiacal Releasing 深化

优先级：P1
工作量：M
价值：高

当前已有 L1–L3 和 Loosing of the Bond。建议增加：

- L4。
- Fortune / Spirit / Eros 的显式起点选择。
- peak periods、angular periods、completion / transition flags。
- 当前参考时刻上下文和未来 N 年 transition 列表。
- 多个 Lot 的并排时间线，但不自动合成吉凶判断。

Loosing of the Bond 必须继续使用真实跳转逻辑，不能退回普通相邻星座切换标记。

### C8. Circumambulations / Distributions 扩展

优先级：P1–P2
工作量：M–L
价值：高

当前沿界推进可以扩展：

- 可选择 ASC、Sun、Moon、Fortune、Syzygy 等 significator。
- Egyptian / Ptolemaic bounds。
- direct / converse。
- bound lord change、ray contact 和时间窗口。
- 多 significator 的同年重叠表。

必须先确认每种 significator 的 arc 与 key 规则，避免简单复制 ASC 逻辑。

### C9. 完整 Primary Directions 方法族

优先级：P2，需 C0 完成后
工作量：XL
价值：极高

候选能力：

- Placidus semi-arc。
- Regiomontanus。
- zodiacal / mundane directions。
- direct / converse。
- promissor latitude include / ignore。
- conjunction 与 aspect rays。
- Naibod / Ptolemy / Cardan / custom key。
- planets / angles / Lots / selected significators。

这是应单独建分支、单独写规格、单独做参考验证的项目，不能与普通功能批次混做。

### C10. Prenatal Syzygy Chart Packet

优先级：P1
工作量：S–M
价值：高

当前已精确求出产前朔望及 Sun / Moon 位置，可进一步输出：

- 产前朔望完整盘。
- syzygy chart → natal cross aspects。
- syzygy angles / houses / ruler。
- 是否为 eclipse、交点距离与 eclipse classification。
- prenatal new moon / full moon 的选择证据。
- 与 Almuten / Hyleg 候选的引用关系。

### C11. Fixed-star Parans

优先级：P1–P2
工作量：L
价值：高、专业化

现有固定星黄经合相可以扩展为本地地平事件：

- 星体 / 固定星的 rise、set、upper culmination、lower culmination。
- 同一地方恒星日内的 event pairing。
- 允许时间差或 RA 容差。
- star–planet 与 star–angle paran。
- 极区无升落时明确缺失原因。

需要区分：

- 出生时刻恰在角点附近；
- 同一日内发生的真实 paran；
- 解释体系定义的扩展时间窗。

三者不能混用一个 `orb` 字段。

### C12. Planetary Days / Hours

优先级：P1
工作量：S
价值：中高

这是低成本、高 Markdown 价值的本地计算：

- 地方日出 / 日落。
- 昼夜各十二不等时。
- Chaldean order。
- 当前 planetary hour lord。
- 指定日期全天时间表。
- 极昼 / 极夜和缺失日出日落处理。

可以与 electional / horary 共用，但先作为古典历法事实输出。

### C13. Classical Revolutions Concordance

优先级：P1
工作量：M
价值：高

现有七政返照和 profection–solar-return synthesis 可以进一步形成年度证据矩阵：

- 年主、月主、Firdaria ruler、Decennial ruler、ZR ruler。
- 它们在 natal / solar return 中的 dignity、house、sect、motion。
- Primary Direction / Circumambulation 在同一时间窗的重合。
- 返照轴点对本命宫位的落入。
- 只输出“哪些技法同时指向同一行星 / 宫位 / 时间窗”，不自动断言事件。

### C14. Mundane Ingress & Planetary Cycle Pack

优先级：P2
工作量：L
价值：高，但属于新工作流

可复用现代周期与古典 snapshot：

- Aries / Cancer / Libra / Capricorn ingress charts。
- 本地、首都或用户地点的 house chart。
- 新月 / 满月 / eclipse charts。
- Jupiter–Saturn conjunction cycles。
- ingress / lunation / eclipse 对指定国家或事件盘的 cross aspects。
- 每张图的 sect、ruler、angular planets、dignities 和 provenance。

### C15. Electional Fact Scanner

优先级：P2–P3
工作量：L
价值：中高

不做“自动替用户选择吉时”，只计算候选窗口中的事实条件：

- Moon void / sign exit / next aspect。
- Moon phase、speed、latitude、nodes proximity。
- ASC / MC ruler 状态。
- benefics / malefics angularity。
- requested topic house ruler dignity。
- planetary hour ruler。
- 用户定义的 hard constraints。

输出每个候选时间的 evidence matrix，允许用户自己排序或导出 Markdown。

### C16. Temperament Profiles

优先级：P3
工作量：M
价值：中等、流派差异大

若实施，应提供 Lilly / Gadbury 等明确 profile，并输出 ASC、Moon、season、chart ruler 等贡献明细。不得把自创加权分数标为唯一古典算法。

## 5. 跨现代 / 古典共用的底层计算

### 5.1 Generic Event Solver

把以下重复能力抽成受测试的公共原语：

- scalar root bracketing / refinement。
- circular longitude root。
- declination root。
- speed-zero station。
- orb boundary entering / leaving。
- pass grouping / dedupe。
- previous / current / next cycle selection。

现有 `modern_timing`、`modern_cycles`、return solver、scan 已经各自实现了其中一部分。抽取时必须保持既有 JSON 兼容，不能为“代码漂亮”破坏已经验证的事件语义。

### 5.2 Observer & Visibility Service

共用：

- rise / set / upper / lower culmination。
- true horizon / refraction。
- heliacal events。
- azimuth / altitude。
- atmospheric and observer defaults。
- polar / circumpolar error contract。

这层可同时服务古典 phasis、fixed-star parans、现代天文现象和吠陀日历。

### 5.3 Coordinate-labelled Point

任何结果点都显式带：

```text
coordinate_system=tropical_ecliptic|sidereal_ecliptic|equatorial|horizontal
coordinate_center=geocentric|topocentric|heliocentric
epoch/equinox
zodiac/ayanamsha
```

这能避免未来把黄经、赤纬、地平坐标和地理经度混入同一 `longitude` 语义。

## 6. 推荐施工批次

每批一个分支、一个计划、一组提交，不把所有功能塞进同一工作树。

| 批次 | 内容 | 价值 | 风险 |
|---|---|---:|---:|
| B7 | M1 动态赤纬事件与 OOB 时间线 | 极高 | 中 |
| B8 | M2 任意行星返照 + M4 逆行周期 | 极高 | 中 |
| B9 | C1 Heliacal phases + C12 planetary hours | 极高 | 中 |
| B10 | M3 行星对周期 + M9 天文现象数据 | 极高 | 中 |
| B11 | C2 Hellenistic condition audit | 很高 | 中高 |
| B12 | M5 Draconic + M10 Heliocentric | 高 | 中 |
| B13 | C3 Dodekatemoria + C4 Monomoiria + C5 Topical Almutens | 高 | 中 |
| B14 | C6 Profections + C7 ZR + C13 Revolutions concordance | 很高 | 中高 |
| B15 | M6 次限方法族 + M7 太阳弧方法族 | 很高 | 高 |
| B16 | C0 Primary Directions 审计 | 极高 | 高 |
| B17 | C8 Distributions + C9 完整 Primary Directions | 极高 | 极高 |
| B18 | C10 Prenatal packet + C11 fixed-star parans | 高 | 高 |
| B19 | M8 轨道点 + M11 dial / planetary pictures | 中高 | 高 |
| B20 | C14 Mundane + C15 Electional fact scanner | 高 | 高 |

### 最适合立即施工的前三批

1. **B7 动态赤纬事件**：现有静态数据与时间线框架都能复用，新增价值明显，方法争议较小。
2. **B8 任意行星返照 + 逆行周期**：return solver、station、pass grouping 已存在，可快速形成大量本地可计算信息。
3. **B9 Heliacal phases + planetary hours**：本机 binding 已确认，古典侧差异化强，Markdown 输出非常自然。

不要把 B16 / B17 主限完整化作为“顺手多做一点”；它需要独立参考数据与算法审查。

## 7. 每批 Definition of Done

每个新功能至少完成：

- 后端独立模块或清晰复用现有模块。
- API 白名单、嵌套校验、范围校验和结构化错误。
- `method_key`、requested/effective config、warnings、section errors。
- Swift request / response Codable。
- 结果页 tab list 与 switch 完整对应。
- Markdown 全量与 section picker。
- JSON；表格型结果同时提供 CSV。
- 一个 Example request。
- 一个真实 backend fixture。
- Python 单元 / 聚焦回归。
- Swift contract / Markdown tests。
- smoke 纳入 CI 和 `check_vibe_changes.sh`。
- 对至少一个外部参考结果做数值交叉验证。
- 完整 diff 审核、`PLANS.md`、`CHANGELOG.md`。
- 构建后清理 `.build`、pytest cache、`__pycache__`、`.pyc`。

## 8. 不建议优先实施

- 继续堆小行星名称或静态解释包。
- 在结构化结果完成前为每个新技法增加 AI 解读。
- 未完成普通 midpoint / dial 前引入 Uranian hypothetical planets。
- 无明确文本许可证的 Sabian Symbols 或度数解释。
- 把 Classical Primary Directions 的多个流派公式混成一个默认算法。
- 把 astronomical visibility、传统 phasis 与解释性“影响窗口”混为一谈。
- 自动输出寿命年数；继续遵守 Hyleg / Alcocoden 仅审计的产品边界。
- 复制 GPL 参考项目代码进入仓库。可以用来理解行为和制作独立测试，但实现应独立编写，并确认许可证边界。

## 9. 技术依据

项目内现有基础：

- `astro_backend_modern_timing.py`：黄经事件、orb 生命周期、多次命中。
- `astro_backend_return_solver.py`：返照求根。
- `astro_backend_cycles.py`：朔望 / 食相周期。
- `astro_backend_modern_points.py`：统一 point set 与轴点。
- `astro_backend_primary_directions.py`：当前简化主限实现。
- `astro_backend_classical_timing.py`：古典 time-lord 与返照时间线。
- `astro_backend_fixed_stars.py`：固定星位置与合相。
- `MarkdownClassical*` / `MarkdownModern*`：现有 Markdown 交付面。

已确认本机 `pyswisseph` 暴露：

- `heliacal_ut` / `heliacal_pheno_ut`
- `vis_limit_mag`
- `rise_trans` / `rise_trans_true_hor`
- `pheno_ut`
- `nod_aps_ut`
- `gauquelin_sector`
- `lun_occult_when_glob` / `lun_occult_when_loc` / `lun_occult_where`

官方资料：

- Swiss Ephemeris Programmer’s Manual：<https://www.astro.com/swisseph/swephprg.htm>
- Swiss Ephemeris 功能说明：<https://www.astro.com/ftp/swisseph/doc/swisseph.htm>
- Astrodienst Chart Types：<https://www.astro.com/cgi/h.cgi?f=gch&h=gchrtype&lang=e>
- Astrodienst Draconic 定义：<https://www.astro.com/cgi/h.cgi?f=gch&h=gch202&lang=e>
- Astrodienst Persona 定义：<https://www.astro.com/cgi/h.cgi?f=gch&h=gch28&lang=e>

这些资料只用于校准计算定义与可实现性，不构成对占星有效性的科学背书。

## 10. 初步结论

B6 之后，最好的扩展方向不是更多地点 UI，而是把现有强大的黄经计算体系扩展到四个新的事实维度：

1. **赤纬随时间变化**；
2. **任意行星返照、会合与逆行周期**；
3. **真实可见性、升落与 heliacal phenomena**；
4. **古典状态证据与多层 time-lord concordance**。

这四条线都能完全本地计算、天然适合 Markdown、可以提供明确公式和 provenance，也能继续复用项目当前的 Python → JSON → Swift 架构。
