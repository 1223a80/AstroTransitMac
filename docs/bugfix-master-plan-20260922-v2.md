# 后端计算缺陷修复总体计划 v2（2026-09-22）

> 状态：计划修订完成，业务修复尚未开始。原版 [bugfix-master-plan-20260922.md](bugfix-master-plan-20260922.md) 保留；后续采用本版时，修法、分组与执行条件以本版为准，原始报告继续作为线索与历史证据。
>
> 本版的目标是使每个来源条目都有明确去向，使修复依据可核查、决策依赖可执行。报告中的“发现”、本次代码确认、实际复现、方法选择和已完成修复分别记录，不相互替代。

## 1. 范围、基线与使用方法

### 1.1 授权边界

本轮只新建计划，不修改业务代码、算法、schema、fixture 或安装包。本文规划的实施范围为两份后端计算审查报告及原计划；前端独立审查、架构迁移、功能新增不纳入。后续修复需进入具体工作包，不能把本文中列举的候选方案理解为已经选定。

只影响局部修复的常规技术选择由执行者依据源码和契约解决，不逐项向用户索取确认。存在多个合理传统、产品行为变化、破坏性契约迁移时，按第 5 节记录决策；未决只阻塞对应条目，不能阻塞所有维护工作。

### 1.2 本次核验基线

- 源码 HEAD：`794d35318fd2c2e69c2ddea2469c47790e75559d`。
- 文档任务分支：`codex/bugfix-plan-v2`；由 `codex/stabilize-json-contracts` 创建。
- 开始时已有 `CHANGELOG.md`、`PLANS.md` 未提交改动，以及原计划和 20260908 报告未跟踪文件；它们属于此前审查任务，本轮保留，不宣称已提交或已同步 GitHub。
- 本轮探针环境：Python `3.14.6`，pyswisseph `20230604`，Swiss Ephemeris `2.10.03`。未来实施必须记录实际使用的解释器及版本，不能假定与本轮相同。
- `1091 passed`、Swift `227` 项和 `43` 个实时样例来自历史收尾记录；本轮未运行完整测试，不能用这些数字作为当前修复验收结果。
- 行号仅是历史导航。定位生产文件时使用当前函数名、字段及调用链，不能按旧行号盲改。

### 1.3 证据与状态

登记表中的阶段是**下一步动作**，不是修复完成状态：

| 阶段 | 可以做什么 | 转出条件 |
|---|---|---|
| 修复准备 | 问题机制已有本地代码/探针支持，设计失败测试 | 当前基线复现失败，期望来自独立契约/规则，再进入最小修复 |
| 技术核验 | 查接口、复现、数学验证、确认来源及真实触发范围 | 形成最小输入、旧输出、独立期望和反例；成立则进入修复准备，不成立则有证据关闭 |
| 决策等待 | 整理可比较方案、兼容性与影响，不改该项语义 | 第 5 节对应决策有明确记录；仍须通过技术核验 |
| 暂不改算法 | 保持已有设计，必要时改善事实披露或测试 | 出现新证据或明确新的产品授权才重新评估 |

“修复准备”仍要求旧代码失败，不表示本文完成了端到端复现。登记表未标本轮实测的数值，均是来源报告的待复核线索。禁止将“新增 warnings”“补文档”标成原算法缺陷已修复；应分别记录缓解和完整修复。

## 2. 来源、覆盖口径与本版纠正

### 2.1 来源索引

| 代号 | 来源 | 本版用途 |
|---|---|---|
| R | [20260908 审查报告](backend-calculation-review-20260908.md) | 新 P1、P2、正文 P3、误报和四项传统/产品议题 |
| H | 同一 R 报告的 Horary 补审 | 补审两项 P2、十行 P3 与 lot_ruler_condition 仲裁 |
| S | [20260826 扫描报告](backend-calculation-bug-scan-20260826.md) | 旧 11 项 P2、24 个 P3 编号；P3-24 拆为五个子项 |
| V1 | [原计划](bugfix-master-plan-20260922.md) | 保留 A–G 旧位置便于迁移；其方案不自动成为正确性依据 |
| STATUS | [当前状态](current-status.md) | 已发布与待复核边界 |
| CLOSED | [13 项修复历史规范](calculation-audit-repair-spec.md)、[Horary 已完成与不修表](horary-remaining-fixes.md) | 已关闭项目与兼容性约束 |
| CONTRACT | [后端契约](backend-contracts.md)、[验证说明](validation.md)、根目录 `AGENTS.md` | 当前交付与验收要求 |

原始 R 正文 P3 实为 18 行，其中 phase_angle/receptions/morning_evening 一行包含三项。本版将其拆为 `R-P3-17a/b/c`，形成 20 条记录；H-P3 保持原十行，H-P3-08 中异常和搜索上限必须分别验收。

**来源登记共 87 条，不等于 87 个已确认 bug，也不等于 87 个 PR：**R-P1 两条、R-P2 十四条、H-P2 两条、S-P2 十一条、R-P3 二十条、H-P3 十条、S-P3 二十八条。另列已关闭/误报和决策议题，不重复计入来源登记。第 6 节每条记录恰好归属一个工作包。R-P1-2 保留在来源计数中以维持审查线索追溯，但后续生产路径仲裁已将其证明为误报并关闭；它不再是待修 bug。

### 2.2 不能沿用的 V1 指令

| V1 位置 | 本版处理 |
|---|---|
| C-6 向 `houses_armc` 传 SIDEREAL flags | 实际接口无此参数；改为参考系与历元的专项核验，见 4.3 |
| C-1 把 `±aspect` 等同 direct/converse，并要求结果异号 | 本地反例证伪；两类维度分别建模，见 4.4 |
| B-1 MC 平移后再 ASC 平移 | 后一次平移会抵消前一次 MC 对齐；不作为默认正确修法，见 4.5 |
| C-3 将事实采样改成 ranked candidates | 源码与测试明确禁止自动排名；保留事实矩阵，见 4.6 |
| B-4 对“28 宿”主表做唯一性测试 | `NAKSHATRA_DATA` 实际 27 项；27 宿主表与含 Abhijit 的专用 28 宿表分开 |
| C-9 Yogini 公式及 Krittika→Siddha 期望 | 按当前序列 `(2-5)%8=5` 是 Ulka；来源内部冲突，不能用其建立正确性测试 |
| C-11 停滞速度 0 一律 unknown，仅反转比较号 | 已知 0 不等于缺失；还须考虑太阳自身运动，见 4.8 |
| C-12 修键名同时删除全部 null 兼容 | 极区行星时仍可 unavailable；保留有意义的可空性 |
| E-2 固定偏移下限强制 −12 | 现实民用区划不自动等于应用允许的固定偏移参数域；先查产品输入契约 |
| E-3 schema_version 表达式认定为优先级 bug | 表达式对整数 1 正常得 2；需证明声明版本与真实结构不符，不能“加括号修 bug” |
| F-2 带符号速度排序自动排除逆行 translator | 不能由速度负号推导传统规则；须复核事件顺序、根连续性及采用定义 |
| F-4 把 legacy 分钟 ID 与 v2 秒级不修决定合并 | 两个路径分别调查；v2 不修决定不自动阻止 legacy 碰撞修复 |
| 只替换 `.app/Contents/MacOS/TransitStudio` | Python 后端是打包资源；需完整重打包并核对资源，见第 9 节 |
| 所有数值变化均称“旧值为错误口径” | 只有独立证据确认错误才这样写；传统选择、方法升级需如实标注行为变化 |

## 3. 本轮已取得的核验记录

下列是本轮真实执行或阅读所得；未实施修复。

| 证据 ID | 核验 | 结果与边界 |
|---|---|---|
| EV-01 | 本机 `swe.houses_armc.__doc__` 与关键字探针 | 签名为 `armc, lat, eps, hsys, ascmc9`；传 `flags` 抛 TypeError，否定 V1 接口方案 |
| EV-02 | 现有 `platiclon_to_arc`，promissor=0、sig=100、angle=60、eps=23.44、lat=0、diurnal=True | 两目标 160/40 返回 +161.5340636014587/+37.59104550252263；否定“两个分支必异号”，不证明完整 PD 方法正确 |
| EV-03 | `bounds_ruler(13/20.5/25.5, 'egyptian')` | 当前依次 VENUS/MERCURY/MARS；这是旧输出复现，正确表仍需附独立文本证据 |
| EV-04 | `_display_zone('GMT+8').utcoffset(None)` 与调用图检索 | helper 单独调用得 0:00:00；但全模块只有定义、没有生产调用，因此只证明未调用 helper 自身返回 UTC，不证明产品输出丢失固定偏移 |
| EV-05 | `NAKSHATRA_DATA` 与现有 Yogini 名称序列 | 主表 27 项；V1 公式在 Krittika index=2 时映射 Ulka，与其测试文字冲突 |
| EV-06 | mundane 源码、`test_calculate_defining_facts`、Swift 导出 | 明确 facts only；已有 `scan_sample_count`、`filtered_candidates` 与 legacy alias 说明，不能把数组和计数指向不同语义直接认成算法错误 |
| EV-07 | `sect_status` / `hayz_status` | 已有结构化 `sect_agreement`，Hayz 却读取中文前缀；可复用既有字段，不必重设计返回值 |
| EV-08 | Horary schema 与 Swift 模型 | `application` schema enum 仅 applying/separating，Swift 相应类型为非可空 String；unknown/null 扩展必须同步契约，非单行修复 |
| EV-09 | `calc_special_lagnas` 代码 | 示例依赖 `jd_ut % 1.0`；同一 JD 不会仅因展示时区改变而变值。“占位公式”与“时区漂移”必须分别证明 |
| EV-10 | draconic 源码 | 常量 `SCHEMA_VERSION=1`，输出表达式正常生成 2；是否错版本待对照历史和消费者 |
| EV-11 | `_station_or_retrograde_before_exact` | `steps` 上限 12，实际采样为 `range(steps+1)`，上限 13 点；零速度点不会单独令 detected=True；需区分换向、触零与缺失 |
| EV-12 | packaging / gate 脚本 | 打包复制 Swift 资源 bundle；完整门禁已经运行 Python、Swift build/test、实时 Examples 解码及 diff 检查，勿重复当作独立未包含项目 |
| EV-13 | `Examples/sample-declination-timing-request.json` 经 `transit_calc.py` 真实入口，分别将 `display_timezone` 设为 `GMT+8` / `UTC` | 两次均返回 262 个事件；首事件 `exact_utc` 均为 `2026-01-02T08:10:49.525Z`，`exact_local` 分别为 `2026-01-02T16:10:49.525+08:00` / `2026-01-02T08:10:49.525+00:00`。生产实现正确解析固定偏移并保持同一 instant；Swift 模型、视图及 Markdown/CSV 导出消费 `exact_local`，无 schema 或导出修复需求 |

可在项目根目录重跑以下小探针。它不是测试套件，不写源码或字节码：

```bash
PYTHONDONTWRITEBYTECODE=1 python3 - <<'PY'
import sys
sys.path.insert(0, 'Sources/TransitStudio/Resources/backend')
import swisseph as swe
from astro_backend_primary_directions import platiclon_to_arc
from astro_backend_classical_dignity import bounds_ruler
from astro_backend_declination_timing import _display_zone
from astro_backend_jyotish_data import NAKSHATRA_DATA
print(sys.version.split()[0], swe.__version__, swe.version)
print(swe.houses_armc.__doc__)
try:
    swe.houses_armc(100, 30, 23.44, b'P', flags=swe.FLG_SIDEREAL)
except TypeError as exc:
    print(type(exc).__name__, str(exc))
print([platiclon_to_arc(0, t, 23.44, 0, True) for t in (160, 40)])
print([bounds_ruler(x, 'egyptian') for x in (13, 20.5, 25.5)])
print(_display_zone('GMT+8').utcoffset(None))
print(len(NAKSHATRA_DATA))
PY
```

## 4. 关键修复规格与核验卡

本节补足高影响、原方案错误或跨模块问题。其余局部项按第 6 节的定位、验收和第 8 节共同行为执行；不能仅凭优先级跳过证据门槛。

### 4.1 来源报告中的 P1：逐项核验，区分待修与已关闭

**R-P1-1 / W01：埃及界。**定位 `astro_backend_classical_dignity.py::EGYPTIAN_BOUNDS` 和 `bounds_ruler`。原报告拟修的 Aries 上限为 6/12/20/25/30；落地前记录所用文本的版本、章/页、可访问出处以及五个界主，不能把本报告反复转述当独立来源。仅修对应 Egyptian 表，不调整 Ptolemaic 版本。边界测试覆盖每个变化边界前/值/后及 0、30 的归一化规则；旧 `test_classical.py` 中 20/25 的错误期望应注明依据后更新。全表结构检查不能替代其余 11 星座逐值核对，未核对不得添加“已逐界核对”注释。检查 bounds→尊贵分→almuten→circumambulations 与下游 audit 的数值变化，schema 不因此必然改变。

**R-P1-2 / W02：固定偏移时区——已证明非缺陷并关闭。**EV-04 只复现了 `_display_zone('GMT+8')` 这个 helper 单独返回 UTC；调用图检索确认它没有生产调用。`calculate_declination_timing` 的实际路径先用 `ZoneInfo(display_timezone)`，失败后用 `resolve_timezone(display_timezone)`，固定偏移由后者解析。EV-13 通过真实 `transit_calc.py` 样例请求证实 GMT+8 与 UTC 各有 262 个事件，首事件 `exact_utc` 相同，而 `exact_local` 分别带 `+08:00` 与 `+00:00`。Swift 模型、结果视图、Markdown 与 CSV 消费 `exact_local`；现有生产响应正确，无 JSON、模型或导出变更。故不建立该 P1 的失败测试或生产修复。未调用 helper 自身仍有局部错误；若将来出现真实调用需求，可另立 helper 清理任务，但不能把它追认为本 P1 的实现或关闭前置条件。

### 4.2 局部逻辑与结构化数据复用

**W03 输入参数：**rate 缺失才用默认值；0 保留；bool 不能通过 Python 的 int 子类关系混进数值；拒绝非有限值与非法字符串。`include_experimental_profiles` 复用 API 的真实布尔校验路径。测试同时走 helper 与 `transit_calc.py` 入口，检查错误响应而非仅函数抛错。

**W04 尊贵/标签：**Hayz 优先读取已有 `sect_status(...)[3]['sect_agreement']`，保留既有返回签名。建立 Mercury 东方/西方×昼/夜×上下半球×星座性别的相关正反例，并用其他行星保证通用分支不变；具体传统规则由现有锁定契约决定。`planet_sect` 与 `sect_agreement` 是否混义另记证据，不能连带修改。Hellenistic 相位适配还要保留合法 False 与零 orb，不能使用 `or` 回退将其当缺失；分别构造入相/离相及 orb=0 的正例。Hyleg 仅修展示分类，不增加寿命预测。syzygy 尊贵配置必须追踪实际昼夜来源和 bounds/triplicity 请求，不只补两个参数就声称完成。

**W05 patterns / dial：**Kite 按实际边的角色/相位表输出一条 opposition、两条 sextile；保留成员对应关系。多实例去重需要规范化成员集合，同时保留具有语义的角色字段；不能简单认为所有 tuple 排序都等价。modulus 距离在合法正 modulus 上使用模意义最短距；验证加减整倍 modulus 不改变命中，含半周期边界与原 360° 行为。

### 4.3 W06：恒星 ARMC 重建

问题分为输入参考系、重建输出参考系、历元选择三层。`armc_from_mc` 对其预期的黄道 MC→赤经转换本身不因 MC 黄纬而错误；调用者给恒星 MC 时必须说明如何回到匹配的参考系。

[Swiss Ephemeris 编程文档](https://www.astro.com/swisseph/swephprg.htm) 和 [pyswisseph 宫位文档](https://github.com/astrorigin/pyswisseph/blob/master/docs/programmers_manual/house_cusp_calculation.rst) 区分可带 flags 的 `houses_ex` 与 ARMC 重建，并给出恒星推运的参考步骤：使用热带 ARMC 重建，再处理 ayanamsha。它们是实现调查入口；不能把示例数组循环直接当成本项目所有字段的变换规则。

实施前交付参考系表：每个输入/中间量/输出的坐标系、UT/TT、ayanamsha 模式与历元、章动口径。优先复用现有 `set_zodiac_mode`/宫位 helper，确认它们的全局状态影响。黄经类字段和赤经量 ARMC 不可一律减 ayanamsha；whole_sign 宫头需基于恒星 ASC 重新定星座边界，不能把热带整宫十二宫头机械平移。非传统 sidereal 模式须单独证明适用，未支持则明示，不以一次 Lahiri 对拍概括所有模式。

验收：零推进时与同历元直接 `build_houses` 对照；tropical 回归；覆盖当前支持的 sidereal 配置、代表性象限/等宫/整宫及跨 0°。角度容差由两条算法的相同章动/历元设置与输出精度确定，记录最大残差和原因，不能用宽容差吸收一整个 ayanamsha 或参考系错误。拟扩展 helper 参数前查全部调用者；先通过接口探针，再修改签名。

### 4.4 W07：主方向分支、极区与方法披露

以下分别处理，禁止混为“converse 缺失”：

1. 相位点分支：`sig_lon + aspect` 与 `sig_lon - aspect`。
2. 有符号弧方向：由选定几何与弧定义计算 direct/converse。
3. 年龄过滤、同构结果去重和 id：影响最终输出数量，不能断言所有行数翻倍。

合相与冲相的 ±分支分别落在同一位置，不应重复。EV-02 必须成为反例测试，证明两分支允许同号；分支 id 不能只依赖 direct/converse。保留项目“event date 在出生后”的既有契约，不以负弧生成出生前事件。

极区 `asin` 域外应区分浮点微越界与物理不可达：前者按有依据的数值容差处理，后者输出可观察的不可计算状态或跳过并记录原因，不静默取 ad=0。验收中包含普通纬度不变、临界内/外与实际不可达例。

`direction_class` 可能表示方法类别，`direction_type` 表示正反向；不能因为上游没 type/kind 就用 direction_type 替换类别。先查消费者和 profile 定义，再决定修注释、字段来源或不修。对 ±180 截断同样先明确方法支持域和长弧定义，不默认支持超过现有 max_age 的新功能。DEC-03 只阻塞算法范围变更，枚举拼写与不可计算披露可独立修。

### 4.5 W08：composite / progressed composite / Davison

撤销“再平移到 ASC 即完成宫位修复”。若原宫头为 c，先加 ΔMC、再加 `ASC-(c1+ΔMC)`，总平移为 `ASC-c1`，原 MC 对齐不再保留。固定纬度下分别求两个出生盘 ASC/MC 的中点，不保证得到同一真实宫位几何；是否更换位置/参考几何属于方法选择，不能笼统断言任何条件下都无法同时满足。

DEC-02 需要比较：保留独立角点中点且明确宫头为 proxy；或选定有来源的 ARMC/纬度/黄赤交角重建法并从同一几何导出轴点；或采用明确命名的其他 composite 宫位法。给出各方案具体样本差异后定案，不能伪称项目规范已指定 ASC 优先。

验收按所选方法列约束：象限宫制的相应轴点关系、对宫、宫头顺序、A/B 对称性、跨 0°、整宫自身规则、行星落宫一致性。不是所有宫位制都要求 cusp1=ASC 或 cusp10=MC。

Davison 的算术中点和球面向量中点是不同构造。先查既有产品约定及可引用来源；未锁定方法前，不以“球面更精确”为由改全部结果。若选择球面法，独立验证向量平均、经度跨日界线、高纬、重合点、对跖/近对跖退化；使用完整经纬度输入生成期望，不采用原报告只给城市和截断坐标的数字作为精确 golden。DEC-12 阻塞 Davison 方法变更，不阻塞对置 tie-break 的独立核验。

### 4.6 W09：mundane 事实采样及契约

现有语义：`daily_fact_snapshots` / `scan_samples` 是事实行；`electional_candidates` 是已注明的 legacy alias；`filtered_candidates` 是另一集合。先分别断言 `scan_sample_count == len(scan_samples)`、`candidate_count == len(filtered_candidates)`，并查 Swift 对 count 与列表的配对展示。若仅消费者把两个集合混用，修对应标签/映射，不引入 ranking、score 或自动择时。

`nearest_aspects` 的名称允许表示“最近的主相位”，不自动意味着“已入容许度”。先明确字段语义；需要 display-orb 标记时复用已有配置或走 DEC-11，不默加 8°过滤。若实现 applying/separating，使用真实双方相对运动并区分缺失；exact_time 只有经过求根才填值，不能线性外推后当精确时刻。

修日主/时主真实键名时，保留极区 `unavailable` 的 null 与 warning；测试正常中纬度非 null 与极区可解码。不把所有 Swift Optional 改成必填。

### 4.7 W10：返照、事件阶段与速度量纲

返照先区分出生根、以后再次达到同一黄经、完成一周、公转周期与逆行多次过境；过滤出生根不能被写成已经证明“一整圈”。DEC-13 记录 current/previous/next 在出生前后、首个有效返照前、exact 恰等于 reference 的语义；保留三键，不随意把 previous 与 current 改成完全不同的历史定义。

出生根排除容差来自 solver 的时间分辨率和实际误差，不在 1e-6 秒与 1 秒之间随意选。现代返照的 400 天分组不能仅改成一个更小常数：先定义 cycle_id/pass_index/window_count 的边界，月亮连续回归不能合并成一个周期，逆行多次穿越也不能被误拆。无结果、未覆盖搜索窗和数值失败分别给可观察原因。

scan 在 refine 得到的精确时刻 signed_orb 近 0，直接乘速度不稳定。先选择“查询时刻的阶段”“事件前后侧”或“exact 状态”语义（DEC-14），再做窗口起点平移、步长变化和逆行重复过境测试。精确命中 orb_factor≈1 可能本来正确；不能仅为让排序有差异而重新发明 priority。

`modern_timing` evaluator 接收真实 UTC 时间；速度若定义为每真实日导数，secondary progression 的 `/365.2422` 可能恰是正确链式法则。用同一 evaluator 的中心差分验证单位，再判错；不直接删除除数。太阳弧的“累计弧”与“显示归一化弧”分别命名与验证，不将都以度为单位的两种表示笼统称为量纲不同。

### 4.8 W11：Horary v2 运动状态与寻根

- 缺失速度、已知零速度、相对零速度、精确相位分别建例。相对速度零不意味着两颗天体都 station；瞬时一阶导为零也不证明一段时间里距离恒定。
- 决定 unknown/null/exact 表示前，查 schema、Swift 非可空 String、motion、VOC、refranation 及所有二元 else 分支，不能把 unknown 自动变 diverging。拟扩展 enum 时记录契约兼容性；破坏性变化不得仅改既有 2.1 文件而无迁移说明。
- `approaching_sun` 必须在同一时刻比较行星与太阳的真实相对运动，跨 0°/180°谨慎处理。行星本身 speed=0 时太阳仍在运动；可知几何不应因零值降为 unknown。测试双方一起推进及一方数据缺失，不能只换原比较号。
- R-P2-j 补建独立任务：证实采样能否漏掉一次/两次换向、恰落采样点的零速度、无符号改变的触零以及缺失片段。合成连续速度函数用于证明算法边界，真实星历案例用于证明产品影响；不能用合成函数声称真实水星已复现漏报。
- 优先复用实际 station 求根 helper，先核对参数与边界语义；没有可复用函数再新增局部实现。细化步长须有速度曲线/区间依据和最大调用数预算，记录无法保证完整性的条件，不把固定更多采样点称为数学完备。
- 对已有样例测 station 个数、时刻误差、星历调用次数和运行时间；收敛基准用更细采样加独立根检查，不只断言非空。unknown/截断证据不可写成 detected=false 的可靠否定。
- 赤纬平行用赤纬随时间变化，而非借用黄经 station helper 的名字就认定可复用；根附近用局部导数/多点行为验证 application。半球门槛与零边界按 DEC-14 定义，不能让“一侧恰为 0”被 `not same_side` 无条件归入异侧。

### 4.9 W12 / W13：Horary 语义、来源与隔离

Legacy `astro_backend_horary.py` 的 interpretation helpers 不等于生产 v2 数据包；逐项追调用图确定实际影响，不能笼统要求所有 legacy 改动都重写 v2 schema。

Frustration、Translation、Collection 的期望先附采用文本与事件顺序：谁接近谁、何时精确、是否换座/停滞、第三方先发生哪一事件。带符号速度比较只是几何输入，不能独立决定规则成立。DEC-07 锁定确有分歧的规则；经典来源清楚、现有契约一致的普通缺陷无需再问用户。

Legacy 分钟 ID 先构造同 source/aspect/target 在同分钟的真实或受控重复并追踪覆盖行为。v2 秒级 ID 的既有“不修亚秒”决定继续有效，不能拿它直接否决另一条 legacy 路径；变更 ID 需查引用与稳定性（DEC-08）。

VOC 来源合并保留一个物理事件和全部 rule 归属。先设计关联结构，再决定是否新增数组；不得把同名 string 原地改成 array 而未处理消费者。rule B interval 的 end 与 definition 一并验证，保留已完成的 rule A/B 区别，不重复实现旧任务。

禁止字段防护按受控结构路径/schema 约束设计：正例覆盖合法技术字段，反例覆盖嵌套判定字段；用户输入文本不能因出现 yes/no 被拦截。单测只注入已在黑名单中的 judgment 不足以验证“新扩展”有效。日出失败和搜索截断分别记录原因、实际覆盖范围，不把 unavailable 伪装成无事件。

### 4.10 W14 / W15：传统表、占位实现与完整性

本节是软件审计范围，不启动个人星盘分析流程。实施传统规则前，应记录具体文本版本/页或可信参考实现及版本，并独立核对公式、索引与单位；不能只写“按 BPHS”或“无经典依据”。

Yogini 必须先消除原报告内部矛盾：现有序列 index5=Ulka、index6=Siddha；公式、表与测试期望三者须一致。区分 elapsed 与 remaining，若已行比例为 p，则已行 D×p、余额 D×(1-p)，不能把已行时间称为余额。使用独立映射表覆盖 27 宿与八限主、宿首尾边界，禁止以被测公式计算测试期望。28 宿仅用于明确需要 Abhijit 的规则；Ashtottari 边界先核对其专用表。

Shadbala 的 Jupiter 常数先查来源再决定删改；“未找到依据”不等于已经证明为零。优先核对 UI/导出能否明显表达 partial；不改变数值的完整性披露与完整算法实现拆开。total/percent 的 nullability、命名、分母语义由 DEC-04 决定。

Aux points 按点建立 `已实现/近似/占位/不可用` 清单，Sun 系已有正确链不得整体降为 placeholder。已确认的占位可先披露，但“UTC 小数日导致同一 JD 随展示时区改变”不得沿用；测试同 instant 不同时区表达、相同钟面不同 offset、不同地理位置三类输入。真实算法范围由 DEC-05 决定。

Yoga 六组分别记录宫主条件、关联定义、排除项、正反例和来源；没有完整规则时停在技术核验，不把“全部重写”当可执行任务。Krittika 显示名只改已证实映射，其他译名不顺手统一风格。

### 4.11 W16 / W17 / W18：输入、时间与静默失败

复用 API 现有校验错误结构，补缺字段路径而非发明新平行错误协议。位置输入缺时区时优先沿已明确请求继承，禁止静默覆盖；如要改变允许缺省输入的语义，先记录契约迁移。

时间比较使用 aware datetime 或 UTC instant；DST fold 0/1 按既有契约处理，未给 fold 的歧义时刻才拒绝，不能一律拒绝合法显式 fold。矫正窗口还须明确按真实秒还是当地钟面扫描。闰日年份钳制先决定拒绝还是 clamp，按可解释的年月日处理并给出边界信息。

syzygy、fortune、spirit 缺失不能用有效黄经 0°参与计分：保留 unavailable 的原因，跳过缺失贡献或不给完整聚合结果；不能只加 confidence 字段继续污染 winner。定案后失败注入须断言计分项及 winner 的可用状态，且 0°白羊的真实输入仍正确。

固定星黄经合相与球面角距是两种含义：先披露现用 longitude-only，不默认改成球面阈值。paran 同型轴对是否排除先核定定义。默认常量修复应模拟缺少库常量的 fallback 路径；正常 getattr 路径不变。全局常量“不同”不自动是 bug，不同模式可采用不同 profile；只在语义确实相同后抽取共享常量。

## 5. 决策登记：只阻塞关联条目

下列 14 个决策 ID 是**待锁定的议题，不是本轮向用户提出的 14 个问题**。先查历史产品决定和已有契约，能够据此解决的记录依据后关闭；只有仍存在实质选择才提交用户。记录必须包含选择、依据、批准者或既有授权、日期、受影响 ID、兼容性、拒绝方案及原因。这里的“未选定”不能由执行者擅自解释为默认批准。

| 决策 ID | 需要锁定的内容 | 受影响项/工作包 | 未锁定时可做的工作 |
|---|---|---|---|
| DEC-01 | Ptolemaic bounds 具体文本版本（继承 G-1） | W04 的额外口径议题，不属于 R-P1-1 | 核对来源与差异表；Egyptian 修复独立推进 |
| DEC-02 | composite 宫位构造及独立中点角的展示关系（G-8） | R-P2-a / W08 | 样例对比、几何不变量核验；不默认 ASC 优先 |
| DEC-03 | PD 相位分支、正反弧及支持域（G-3） | R-P2-c、R-P3-13 / W07 | 反例、极区失败可观察性、明确方法限制 |
| DEC-04 | Shadbala partial 展示与完整实现范围（G-2） | R-P2-f / W15 | 逐项依据与 UI 现状审计，不盲删 +15 |
| DEC-05 | 特殊点逐项实现、降级展示或隐藏策略（G-6） | S-P2-5 / W15 | 占位事实清单和可靠披露，保护正确 Sun 系点 |
| DEC-06 | 各 method profile 年长是否应相同及所选常数（G-5） | S-P3-10 / W17 | 量纲、差异影响及既有 profile 约定核验 |
| DEC-07 | Legacy Frustration/Translation/Collection 采用规则及变体（G-7 部分） | H-P2-F、H-P3-01/02/03 / W12 | 来源与事件序列验证；未选定不改变规则 |
| DEC-08 | Legacy 分钟 ID 是否迁移及引用兼容（G-7 部分） | H-P3-04 / W12 | 碰撞复现和调用链；保持 v2 秒 ID 不修亚秒决定 |
| DEC-09 | 日出/日落折射与日面定义、morning_evening 定义（G-7 部分） | R-P3-17c、S-P3-23 / W13 | 展示当前定义、计算差异；不先强行统一 |
| DEC-10 | Horary v2 是否引入 per-planet moiety orb（G-4） | W11 额外口径议题 | 保持当前全局 orb，不以 bugfix 扩展功能 |
| DEC-11 | 各模式 orb/静止阈值适用域，nearest 与 within-orb 区分 | R-P2-k/n / W09、W18 | 语义表、已有配置与测试核验；不默认阈值同一 |
| DEC-12 | Davison 地理中点构造及名称披露 | S-P2-11 / W08 | 两种构造对拍与退化分析；不默认球面法获批准 |
| DEC-13 | 首次返照前状态、出生根、周期与多次过境定义 | S-P2-3、R-P3-05 / W10 | 根列表与已有三元组契约复核；不改变字段含义 |
| DEC-14 | 精确事件的 phase、相对零速度与赤纬零边界语义 | S-P2-8、R-P2-i、H-P2-D、R-P3-07 / W10、W11 | 反例和消费者盘点；不能以任意二元标签兜底 |

未知输入语法、固定偏移参数域、schema 迁移等技术调查若发现额外产品选择，先在此表新增具体决策及受影响 ID，不能用上述某个宽泛议题吞掉新问题。传统表“来源不一致”优先通过核验解决；只有多个受支持传统仍需选择时，才新增决策。

## 6. 全来源登记表（唯一归属）

路径前缀说明：以下生产模块均位于 `Sources/TransitStudio/Resources/backend/`，简称 `core` 即 `astro_backend_core.py`，其他同理。测试位于 `python_tests/`。R/H 的无编号 P3 按来源行序新增稳定 ID；V1 的范围写法只用于旧文导航，不产生额外任务。

每行的“验收/下一步”与第 4、8 节共同构成任务卡；阶段为核验/决策的行，不得照旧文方案直接改代码。优先级继承来源用于风险排序，不代表本版已确认严重度。

### 6.1 P1 来源登记（2 条；1 条待修，1 条已证明非缺陷）

| ID | 问题与位置 | V1 | 阶段 | 工作包 | 验收/下一步 |
|---|---|---|---|---|---|
| R-P1-1 | Egyptian Aries / classical_dignity | A-1 | 修复准备 | W01 | EV-03；独立表来源、逐边界、尊贵/almuten 数值链；test_classical |
| R-P1-2 | 历史线索：固定偏移被改 UTC / 未调用的 declination_timing::_display_zone | A-2 | 已证明非缺陷（关闭） | W02 | EV-04 仅证明 helper 自身错误；EV-13 真实入口对比 GMT+8/UTC，生产 `exact_local` 正确；无业务修复 |

### 6.2 新 P2（14 条）及补审 P2（2 条）

| ID | 问题与位置 | V1 | 阶段 | 工作包 | 验收/下一步 |
|---|---|---|---|---|---|
| R-P2-a | composite 轴与宫头构造 / composite、progressed_composite | B-1 | 决策等待 | W08 | DEC-02；按所选宫制验证整体几何，见 4.5 |
| R-P2-b | Mercury Hayz 中文前缀 / classical_dignity::hayz_status | B-2 | 修复准备 | W04 | EV-07；复用 sect_agreement，昼夜与东方/西方正反例 |
| R-P2-c | PD 单相位分支 / primary_directions::_make_direction | C-1 | 决策等待 | W07 | DEC-03；EV-02 反例、合/冲去重、ID 与年龄过滤 |
| R-P2-d | modulus 距离 / orbital_dial | C-2 | 修复准备 | W05 | 45/90/360、整倍不变性、半周期；test_orbital_dial |
| R-P2-e | Krittika 显示名 / jyotish_data::NAKSHATRA_DATA | B-4 | 技术核验 | W14 | 确认译名依据；27 项主表不扩成 28；只修目标映射 |
| R-P2-f | Shadbala +15 与不完整总分 / jyotish_shadbala | C-4 | 决策等待 | W15 | DEC-04；子项独立来源、partial 展示与分母定义 |
| R-P2-g | rate=0 被吞 / method_families | B-3 | 修复准备 | W03 | 0、缺失、bool、NaN/Inf、非法字符串；入口结构化错误 |
| R-P2-h | 字符串 false 变 True / method_families | B-3 | 修复准备 | W03 | 真/假 JSON bool 分支，字符串拒绝；test_method_families |
| R-P2-i | 缺失/零速度状态 / horary_v2_aspects | B-7 | 技术核验 | W11 | EV-08；缺失/零/相对零/exact 分开，DEC-14 与 schema 消费链 |
| R-P2-j | station 检查采样上限 / horary_v2_aspects::_station_or_retrograde_before_exact | 漏项 | 技术核验 | W11 | EV-11；13 点上限、双换向、触零、缺失；独立根对照与性能 |
| R-P2-k | nearest_aspects 与容许度 / mundane_electional | C-3 | 技术核验 | W09 | nearest 是否本来允许远相位；DEC-11；不自行加 8° |
| R-P2-l | count 与 legacy 数组 / mundane_electional | C-3 | 技术核验 | W09 | EV-06；分别匹配 scan_samples 与 filtered_candidates，不加排名 |
| R-P2-m | 中文名称两表 / core、constants | D-1 | 技术核验 | W18 | body_id 是身份，区分别名/显示名；确认目标显示契约后统一来源 |
| R-P2-n | orb/阈值跨模块不同 / 多模块 | D-2 | 决策等待 | W18 | DEC-11；建立用途表；不同 profile 不强行共用数值 |
| H-P2-F | Frustration 第三方速度过滤 / horary::_detect_frustration | B-8 | 技术核验 | W12 | DEC-07 如需；来源文本、先完美次序与第三方快慢正反例 |
| H-P2-D | 赤纬零附近双判 / horary_v2_modules::declination_parallels | B-9 | 技术核验 | W11 | DEC-14；同号/异号/单零/双零，锁定定义后验证互斥条件 |

### 6.3 旧 P2（11 条）

| ID | 问题与位置 | V1 | 阶段 | 工作包 | 验收/下一步 |
|---|---|---|---|---|---|
| S-P2-1 | 恒星 ARMC 输入/输出坐标系 / ephemeris、method_families | C-6 | 技术核验 | W06 | EV-01；零推进直算对拍、历元、whole_sign、ARMC 不误平移 |
| S-P2-2 | Hellenistic 相位 ID/状态失配 / hellenistic_audit、classical | C-7 | 修复准备 | W04 | 上游补稳定 ID 或复用现有映射；入/离各构造，逐行匹配；不要求任一样本覆盖七曜全部状态 |
| S-P2-3 | 出生根混入 current / classical、classical_timing | C-8 | 技术核验 | W10 | DEC-13；出生前/根附近/首个生后根；三键保留与求根容差 |
| S-P2-4 | Yogini 起算/余额 / jyotish::_calc_yogini_dasa | C-9 | 技术核验 | W14 | EV-05；独立映射表、公式与名称一致；elapsed/remaining 分开 |
| S-P2-5 | 特殊点占位与时区漂移指控 / jyotish_aux_points | C-10 | 决策等待 | W15 | DEC-05；EV-09；逐点审计，三类时区输入，保护 Sun 系点 |
| S-P2-6 | approaching_sun 比较与太阳运动 / horary_v2_modules::accidental_condition | C-11 | 修复准备 | W11 | 双方真实运动、已知 0、缺失、跨角边界；test_horary_v2 |
| S-P2-7 | 日时主键名 / mundane_electional | C-12 | 修复准备 | W09 | 正常 status=ok 非 null；极区 unavailable 保留且可解码 |
| S-P2-8 | scan phase 依赖采样端点 / scan | C-13 | 技术核验 | W10 | DEC-14；同一 exact 的窗口平移/步长不变性与 exact 标签 |
| S-P2-9 | Kite 标签恒 opposition / patterns | B-5 | 修复准备 | W05 | 独立四点图，一对冲两六合，成员角色对应 |
| S-P2-10 | shape 按 type 丢实例 / patterns | B-6 | 修复准备 | W05 | 双实例保留、相同成员规范化去重、输入排列不影响集合 |
| S-P2-11 | Davison 地理构造 / davison | C-5 | 决策等待 | W08 | DEC-12；完整经纬度对拍与对跖退化，方法名称匹配 |

### 6.4 R 正文 P3（20 条）

| ID | 来源问题与位置 | V1 | 阶段 | 工作包 | 验收/下一步 |
|---|---|---|---|---|---|
| R-P3-01 | 极区 asin 域外静默 ad=0 / primary_directions::ascensional_difference | 漏项 | 修复准备 | W07 | 正常值不变；微越界与物理不可达分开；原因可见 |
| R-P3-02 | direction_class 读不存在键 / pd_audit | 漏项 | 技术核验 | W07 | 方法类别不等于正反向；查 profile/消费方，不能盲换字段 |
| R-P3-03 | progression/solar_arc evaluator 速度除年长 / modern_timing | 漏项 | 技术核验 | W10 | 真实日中心差分验证链式法则；若正确有证据关闭 |
| R-P3-04 | arc_value 归一化表示不同 / solar_arc | 漏项 | 技术核验 | W10 | 明确累计/显示弧，跨 360 与负值；不混称量纲错误 |
| R-P3-05 | current 400 天聚合 / modern_return | 漏项 | 技术核验 | W10 | DEC-13；月返照多周期与逆行多次 pass，窗口计数和周期计数分离 |
| R-P3-06 | parse_degree('10-2') 歧义 / core::parse_degree | E-2 | 技术核验 | W16 | 查 UI 支持语法；减法/度分分别测试，拒绝歧义而非猜含义 |
| R-P3-07 | dec=0 分类 / core | E-2 | 决策等待 | W11 | DEC-14；与 H-P2-D 同一零边界规则，两调用点回归 |
| R-P3-08 | 允许 GMT-14 / core::resolve_timezone | E-2 | 暂不改算法 | W16 | 固定偏移参数域与真实民用时区不同；无契约依据不新增拒绝 |
| R-P3-09 | naive datetime 按系统时区 / core::jd_from_datetime | E-2 | 技术核验 | W17 | 查全部调用者；主机时区变化不影响同一显式 instant；选择拒绝或明确解释 |
| R-P3-10 | stellium 冲突字段恒不匹配 / patterns::_find_stelliums | 漏项 | 技术核验 | W05 | 构造同组星座/宫位重叠，先明确是否应合并，再修去重 |
| R-P3-11 | mundane 必填未进 API 校验 / api | E-1 | 修复准备 | W16 | display/location 时区继承与缺失路径，入口结构化错误 |
| R-P3-12 | station ±6h 被用户窗钳制 / retrograde_cycles | E-2 | 技术核验 | W10 | 相同 station 在窗边/窗中 kind 一致，探针缺失可观察 |
| R-P3-13 | 主方向 ±180 截断 / rectify_primary_motion | E-2 | 决策等待 | W07 | DEC-03；证明支持域内实际错误，长弧不能擅加整圈 |
| R-P3-14 | converse_label 枚举 / rectify_primary_motion | E-2 | 修复准备 | W07 | 对照 RectifyModels/rectify 消费，合法值、正负弧与显示一致 |
| R-P3-15 | refine 后 orb_factor≈1 / scan | F-11 | 技术核验 | W10 | 若精确事件本应为1则关闭缺陷；重新评分属于另行产品范围 |
| R-P3-16 | ZR L1 LoB 与 _zr_walk / classical_timing | F-11 | 技术核验 | W04 | 可达域证明、调用图；不混同已仲裁子周期 step24；不新增普通跳宫 LoB |
| R-P3-17a | phase_angle pheno 覆盖/回退 / horary_v2 | F-10 | 技术核验 | W13 | 分别测 pheno 有/无；回退明确标记，不删仍可到达路径 |
| R-P3-17b | _build_receptions 死代码 / horary_v2 | F-10 | 技术核验 | W13 | 全仓调用搜索与包输出不变才可删除；不因名称相同误删其他模块 |
| R-P3-17c | morning_evening 定义 / horary_v2 | F-10 | 决策等待 | W13 | DEC-09；先明确现用几何约定，真实升落算法属方法变化 |
| R-P3-18 | return exact_utc 分钟截断 / classical | E-2 | 修复准备 | W10 | 精确 instant 与生成 return chart 的时间一致；更新格式消费者 |

### 6.5 H 补审 P3（10 条）

| ID | 来源问题与位置 | V1 | 阶段 | 工作包 | 验收/下一步 |
|---|---|---|---|---|---|
| H-P3-01 | Frustration 变体 / horary | F-1 | 决策等待 | W12 | DEC-07；主定义有测试，未授权不扩展变体 |
| H-P3-02 | Translation/Collection abs(speed) / horary | F-2 | 技术核验 | W12 | 顺逆行事件次序与连续性，不以带符号大小替代规则 |
| H-P3-03 | Collection 与直接入相共存 / horary | F-3 | 技术核验 | W12 | 主相位/collection 先后与采用定义，不能无来源全排除 |
| H-P3-04 | legacy 分钟 event id / horary::make_aspect_event | F-4 | 技术核验 | W12 | DEC-08 如需；精确碰撞及引用迁移，不混同 v2 秒精度 |
| H-P3-05 | VOC rule 归属覆盖 / horary_v2 | F-5 | 技术核验 | W13 | 两规则同物理边界仍保留全来源；schema/Swift/导出联动 |
| H-P3-06 | rule B definition/interval 不一致 / horary_v2::_voc_interval | F-6 | 技术核验 | W13 | 覆盖 exact 晚于 sign_exit、start>end、window 截断；不重做旧 B |
| H-P3-07 | delta_t 异常等同 UT / horary_v2 | E-2 | 技术核验 | W13 | 失败注入，TT 可用性/原因可见；不把真实 ΔT=0 当失败 |
| H-P3-08 | 日出异常与 ±400d 探针上限 / horary_v2 | F-7 | 技术核验 | W13 | 两子问题分别验收：失败原因；截断覆盖与边缘事件，不无限扩大窗口 |
| H-P3-09 | forbidden-field 防护覆盖 / horary_v2 | F-8 | 技术核验 | W13 | 新增未覆盖的嵌套反例+合法正例+用户文本；避免全局 yes/no 黑名单 |
| H-P3-10 | 赤纬 application 固定 +6h / horary_v2_modules | F-9 | 技术核验 | W11 | 赤纬导数/根两侧，多点与高精度参照；不可照搬黄经 helper |

### 6.6 S 旧 P3（28 条记录）

| ID | 来源问题与位置 | V1 | 阶段 | 工作包 | 验收/下一步 |
|---|---|---|---|---|---|
| S-P3-1 | classical 缺 birth.moment / api | E-1 | 技术核验 | W16 | 逐缺字段，真实入口输出既有结构化错误，不泄漏 traceback |
| S-P3-2 | 未知 body_id 静默丢 / ephemeris::resolve_bodies | E-1 | 技术核验 | W16 | warnings 列出被丢 ID，合法天体不变；重复警告去重 |
| S-P3-3 | manual 地点默认 UTC / location_service、relocation | E-1 | 技术核验 | W16 | 查继承优先级；给定 display 时区不被隐式 UTC 覆盖 |
| S-P3-4 | paran except continue / prenatal_parans | F-11 | 技术核验 | W18 | 注入一星失败，成功行保留且 warning 有 body/原因 |
| S-P3-5 | previous 缺失无 warning / modern_return | E-1 | 技术核验 | W10 | 搜索未覆盖/无前次/计算失败分开；不强制每个 null 都报警 |
| S-P3-6 | OOB 平/真交角混用 / core、ephemeris | E-2 | 技术核验 | W17 | 查赤纬参考系与传统阈值约定，边界同系对拍；非边界不变 |
| S-P3-7 | Ashtottari Shravana 上限 / jyotish | E-2 | 技术核验 | W14 | 专用 28 宿表来源、覆盖无缝、区间内 portion 单调及宿切换归零 |
| S-P3-8 | 闰日年份 clamp / scan | E-2 | 技术核验 | W17 | 可复现 2/29 触发，明确 clamp/拒绝；常规合法窗不变 |
| S-P3-9 | MD/AD 秒截断 / jyotish | E-2 | 技术核验 | W14 | 内部精确 datetime 判定，边界前/值/后，展示格式不回写逻辑 |
| S-P3-10 | 年长 365.2425/365.2422 / rectify_primary_motion 等 | E-2 | 决策等待 | W17 | DEC-06；分 profile 测量差异；数值不同不自动强行统一 |
| S-P3-11 | 本地 ISO 字典序 / modern_timing | E-2 | 技术核验 | W17 | DST 回拨重复小时按 UTC 排序，pass_index 与事件顺序一致 |
| S-P3-12 | Hyleg angular 分类 / classical_audit | E-3 | 修复准备 | W04 | 4 宫为 angular、9 宫不误标；资格判定不连带改 |
| S-P3-13 | 缺失点 0°污染 almuten / api、classical_audit | E-3 | 技术核验 | W04 | syzygy/fortune/spirit 分别失败注入；不计伪造0°，真实0°仍有效 |
| S-P3-14 | syzygy 尊贵配置硬编码 / classical_audit | E-3 | 修复准备 | W04 | 昼夜来源、bounds/triplicity 逐项传播；输出与所选配置相符 |
| S-P3-15 | ptolemaic 水象昼夜角色 / classical_dignity | E-3 | 技术核验 | W04 | dual-sect 显示标签与得分分开；不趁机更换三分表 |
| S-P3-16 | lots 整宫 fallback 锚 0° / classical_lots | E-3 | 技术核验 | W04 | ASC 跨星座、无 cusps 路径；正常宫头输入不变 |
| S-P3-17 | 恒星只比较黄经 / fixed_stars | E-3 | 暂不改算法 | W18 | 明确 longitude-only 语义；Vega 等高黄纬作披露测试 |
| S-P3-18 | 六组 Yoga 定义 / jyotish_yoga | F-11 | 技术核验 | W14 | 六组逐条来源/正反例，宫主关系与特殊规则；不可笼统重写 |
| S-P3-19 | 冲相跨 ±180 标签 / planetary_synodic | F-11 | 技术核验 | W10 | 179.9→180→180.1 同一分支 unwrap，时间/orb 不变 |
| S-P3-20 | harmonic_order 非正 / harmonic、api | F-11 | 技术核验 | W16 | 正整数契约、0/负/小数/bool；无依据不凭空加上限100 |
| S-P3-21 | 对置中点 A/B 不对称 / composite、progressed_composite | F-11 | 技术核验 | W08 | 精确对置退化约定，交换对称；近对置不强行 snap；稳定身份可用性 |
| S-P3-22 | rectify replace(tzinfo) / rectify | E-3 | 技术核验 | W17 | gap 拒绝；fold 缺省拒绝、显式0/1按契约；窗跨DST扫描定义 |
| S-P3-23 | 同包日出日落不同约定 / horary_v2、visibility | E-3 | 决策等待 | W13 | DEC-09；rsmi/气压/气温/海拔对照，同定义才验时刻一致 |
| S-P3-24a | Seesaw 线性均值 / patterns | E-3 | 修复准备 | W05 | 355/5 附近圆量均值；对称抵消时退化；形态级正反例 |
| S-P3-24b | paran 同型轴对 / prenatal_parans | E-3 | 技术核验 | W18 | 先来源定义，再判 rising/rising 是否合法，不预设全删 |
| S-P3-24c | visibility fallback 常量互换 / visibility | E-3 | 修复准备 | W18 | 核对运行时 MORNING_LAST/EVENING_LAST，模拟常量缺失路径 |
| S-P3-24d | draconic schema_version 表达式 / draconic_heliocentric | E-3 | 技术核验 | W18 | EV-10；核对版本声明/结构/历史；加括号不改变结果不能算修复 |
| S-P3-24e | moon_ingress 未选 Moon / modern_timing | E-3 | 技术核验 | W10 | 明确请求与 effective point set；不可计算原因可见，不静默添星改变范围 |

## 7. 工作包、顺序与依赖

### 7.1 工作包责任与验证范围

每个来源 ID 在第 6 节仅有一个主工作包。一个工作包可拆多个逻辑提交/PR；不同根因不因同为 P3 就按固定数量打包。共享 helper/schema 的后续 PR 需明确依赖已合并的前置提交；不能让多个独立分支互相假定对方已改。

| 包 | 范围与优先顺序 | 显式依赖/阻塞 | 聚焦验证与消费者 |
|---|---|---|---|
| W01 | Egyptian P1；最先 | 独立来源核实；不依赖 DEC-01 | test_classical、test_technique_maintenance_classical、test_hellenistic_condition_audit；classical/derivatives/time-lords/distributions |
| W02 | R-P1-2 生产路径核验与误报关闭；不安排 P1 业务修复 | 无方法决策；关闭依据见 EV-04/EV-13 | `test_declination_timing` 现有输出路径已核对；DeclinationTimingModels / Views / Exports 消费 `exact_local`，无需 schema/fixture 改动 |
| W03 | method_families 输入 | API 现有校验契约 | test_method_families、test_contracts；MethodFamiliesModels / MethodFamiliesExports |
| W04 | 尊贵、ID、缺失计分、ZR 核验 | 各项独立；DEC-01 仅新增版本议题 | test_classical、test_hellenistic_condition_audit、test_classical_derivatives；ClassicalCoreModels / ClassicalResultModels / MarkdownClassicalExportBuilder |
| W05 | patterns 与 orbital dial | 各项失败测试；stellium 先定去重语义 | test_patterns、test_orbital_dial；ModernResultModels 与现代导出 |
| W06 | 恒星 ARMC | 完成 4.3 参考系方案后实现 | test_method_families、test_technique_maintenance_classical；MethodFamiliesModels/Exports |
| W07 | PD/rectify 语义与退化 | DEC-03 仅分支/长弧；其余独立 | test_primary_directions_audit、test_rectify、test_rectify_evidence；RectifyModels / PrimaryDirectionsAuditModels 与导出 |
| W08 | composite、Davison、中点退化 | DEC-02 / DEC-12；仅当选 ARMC 法时依赖 W06 | test_modern_composite_davison_points、test_modern_relationship、test_progressed_composite、test_modern_relationship_timing；ModernResultModels / MarkdownModernExportBuilder |
| W09 | mundane 字段/事实契约 | DEC-11 仅 orb 策略；不依赖任何排名实现 | test_mundane_electional、test_contracts；MundaneElectionalModels / MundaneElectionalExports |
| W10 | returns、scan、现代时序 | DEC-13/14 仅相关语义；UTC 排序可由 W17 先落地 | test_classical、test_modern_return、test_scan、test_modern_timing、test_retrograde_cycles、test_planetary_synodic；TransitResultModels / ModernResultModels / TextExportBuilder |
| W11 | v2 运动、station、赤纬 | DEC-14 边界；schema 迁移方案；DEC-10 不扩功能 | test_horary_v2、test_horary_followup、test_declination；HoraryDataPacketModels / HoraryExtraViews / MarkdownHoraryExportBuilder |
| W12 | legacy 高级规则与 ID | DEC-07/08 对应项；与 v2 数据包区分 | test_horary、test_horary_followup；仅追实际共享调用，必要时补 v2 回归 |
| W13 | v2 VOC、来源、可观察性、日出 | DEC-09 只阻塞定义变更；运动依赖 W11 时明示 | test_horary_v2、test_classical_visibility；schema/golden/字段词典/Swift 导出 |
| W14 | 宿名、Dasha、Yoga | 独立来源消除冲突后；有多传统才提决策 | test_jyotish_focused、test_jyotish_reference_verify、test_audit_vedic_regressions；VedicResultModels / VedicResultViews / MarkdownVedicExportBuilder |
| W15 | Shadbala/特殊点完整性 | DEC-04/05；事实披露与算法实现分别验收 | test_jyotish_focused、test_audit_vedic_regressions、test_jyotish_smoke；Vedic UI / Markdown 导出 |
| W16 | 输入契约/未知天体/地点 | 优先现有契约；新增不兼容规则另记决策 | test_contracts、test_relocation、test_mundane_electional、test_modern_progression_solar_arc_harmonic_points；Swift 请求编码/校验 |
| W17 | UTC/DST/闰日/精度 | DEC-06 仅年长；OOB 参考系先核验 | test_scan、test_modern_timing、test_rectify、test_rectify_evidence、test_declination；时间显示与导出 |
| W18 | 命名、常量、固定星、paran、版本 | DEC-11 仅真正统一数值；其余独立核验 | test_constants、test_fixed_stars、test_prenatal_parans、test_draconic_heliocentric、test_warning_visibility；实际消费模型与导出 |

表中 Python 名称指相应 `.py` 文件。不存在专门的 `test_horary_v2_schema.py`；schema 验证当前在 `test_horary_v2.py` 中。模块名是检索起点，不代表不经调用图调查就要修改所有列出的文件。

### 7.2 推荐执行流

1. W01 仍是本组唯一待修 P1，需独立来源核实后推进；W02 已由 EV-04/EV-13 证明为生产误报并关闭，不进入业务修复队列。两条来源记录仍分别归属 W01、W02，保持 87 条来源 ID 与 18 个工作包的追溯关系。
2. W03、W04 中确定的键/标签项、W05 中确定的恒真条件/去重项、W09 键名、W16 已有错误协议缺口进入小范围修复。
3. W06、W07、W08、W10、W11、W14 的数学/方法核验产出后，再按各项条件实施；W12/W13 严格区分 legacy 与 v2。
4. W15 先处理已确认的不完整结果披露，再执行获选定的完整算法范围；W17/W18 的局部项可以随其真实依赖就绪而推进，不需等所有 P2。
5. 每个 PR 记录本次 ID、未包含的相关 ID、前置提交和未决项。所有来源条目有去向后可宣布“计划覆盖完成”；只有每个应修条目完成或有证据关闭，才可宣布整体修复收口。

不设“每 5–8 项一提交”，不承诺几何/语义大包都属于“中等工作量”。无法估计的核验任务先以证据交付为里程碑，验证后再估实现成本。

## 8. 实施与验证门禁

### 8.1 每个逻辑任务的完成链

1. 阅读根 `AGENTS.md`、本 ID 的任务卡、关联决策与当前代码/调用者。记录 `git status --short --branch`、HEAD、工作区归属及实际解释器。
2. 用 `codex/` 前缀建立单一任务分支；若需从其他修复继承，以明确提交为基线。已有无关改动保留绕开，不能通过一次 `git add .` 混入提交。
3. 对缺陷新增最小失败测试，记录旧实现的失败输出。输入必须说明来源，期望必须来自独立规则、明确契约、可证明性质或参考数据。测试中的常数期望允许且必要；禁止的是在生产代码硬编码样例输出，或用被测实现自己生成“独立”期望。
4. 先确定修法再做最小实现。发现原假设错误，回到技术核验并记录关闭/改判依据，不为保住报告结论更改测试语义。
5. 聚焦测试与相关模块全量通过；对实际显示/导出字段检查 Swift consumer，不只检查后端 JSON 存在。
6. 故意改变 schema、枚举、nullability、ID 或数值时，按 8.2 更新对应契约与真实 fixture；更新 `CHANGELOG.md` 和 `PLANS.md`。
7. 运行完整门禁；检查完整 diff、范围和任务记录；清理本任务构建/测试缓存。代码失败与权限/依赖阻塞分开报告。
8. 完成记录包含本 ID、原失败、独立依据、实现摘要、实际通过结果、契约差异和未完成项。提交/推送只有实际完成并核对远端状态后才报告同步；不因文档完成自动创建修复 PR。

### 8.2 JSON / schema / fixture

先列真实字段差异：增删字段、类型、enum、null、单位、精度、ID、数组语义、默认值。对每个差异查 Python 生产点→Swift Codable→视图→Markdown/CSV→schema/golden。字段可解码不等于语义正确，必须有值级断言与导出断言。

- 兼容字段优先沿现有结构增量表达；不要为了“禁止新旧并存”删除有意 legacy alias。
- String→array、非可空→null、enum 扩展等必须记录旧消费者行为；需要版本升级时制定迁移，不静默重定义既有版本。
- 固定 fixture 只能用其对应真实请求再生；不要把任意 sample 覆盖到相似名字的 fixture。先确认请求与输出的关联，生成到任务临时文件，通过 JSON/schema/核心字段检查后替换指定 fixture。
- Horary golden 当前使用 `python_tests/test_horary_v2.py` 中 `LINYI_REQUEST` 和 `_packet`；Swift fixture 的关联以该测试和 `BackendContractTests` 为准，不能假定 generic sample 的日期/位置相同。
- 当前 Horary golden 测试比较若干哈希、几何和事件 ID，不是完整逐字段语义比较。新增 unknown、VOC rule 来源、日出状态等必须增加针对受影响字段的断言，不能只重生成后看 golden test 通过。
- 数值变而 schema 不变时也审查相关 fixture 值；schema 不变不代表无需回归。反过来，没有受影响输出的 fixture 无需机械全部刷新。

### 8.3 数值、时间、搜索与性能验收

| 类别 | 必须证明的性质 | 不足以验收的做法 |
|---|---|---|
| 角度 | 环形差、坐标系/历元相同、退化行为明确 | 只看小数接近；跨0°直接减 |
| 时间 | aware instant、显示 offset、跨日及 DST、边界包含规则 | 只断言字符串存在；同 instant 的 aware 时间相减期待时差 |
| 搜索 | 相同事件集合、根残差、时刻误差、窗口/步长稳定性、缺失/截断状态 | 只断言非空；增加样本数后称完备 |
| 几何/传统表 | 独立映射/参考、支持域、反例和方法身份 | 让期望与新实现同用一个公式；把新输出写成 golden 即通过 |
| 契约 | 类型与值语义、模型解码、UI/导出、空值与错误路径 | 仅 stdout 可解析或退出码为0 |
| 性能 | 相同请求和环境比较运行时间/星历调用量，满足真实调用方预算 | 用任意“应小于1秒”门槛或无上限扩大搜索 |

容差写进测试并说明由 solver 精度、输出舍入、时间分辨率还是参考算法差异推导。源文已有明确有依据的容差可继承；否则先测量并解释，不能事后扩大到刚好通过。finite-difference 对照要处理角度 unwrap 与步长收敛，不能自身引入跨界误判。

### 8.4 可执行命令与结果记录

依赖优先复用当前完整环境。确需安装时遵循项目国内镜像要求及 [validation.md](validation.md)，不为写计划安装新依赖。

聚焦阶段示例，实际替换为该工作包表中的真实文件：

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m pytest -p no:cacheprovider python_tests/test_declination_timing.py -q
```

代码交付前优先执行现有完整门禁一次：

```bash
SWIFTPM_BUILD_PATH=/private/tmp/astrotransit-bugfix-validation-build \
  bash check_vibe_changes.sh
```

当前脚本本身包含完整 Python 测试、Swift build、Swift tests（启用全部 Examples 实时后端解码）、`git diff --check`。不再无理由紧接着重跑同一整套；后续代码变更、失败或新增疑点才需要重复相应检查。缓存目录使用本任务独占路径；若已存在非本任务产物，换新目录。

额外针对受影响分支做真实请求 smoke，并检查 stdout JSON 中的错误字段、数量、核心值与 warnings；不能仅重定向 `/dev/null` 后看退出码。现有 sample 没有覆盖新增边界时，使用对应回归输入，而不是误以为所有 Examples 全绿已覆盖该边界。

Swift 需要模块缓存权限时按项目沙箱规则申请正常访问，不能修改源文件躲过权限问题。GitHub 凭证操作需在合适权限环境运行，不依据沙箱内假阴性要求用户重新登录。

最终 diff 检查：

```bash
git diff --check
git diff --stat
git diff
git ls-files --others --exclude-standard
git status --short --branch
```

未跟踪的新文件不在普通 diff 中，必须单独完整阅读；报告修改范围时只统计本任务增量，不把此前脏工作区的变更算成本任务。

## 9. 发布、回滚与清理

**本文档任务不构建、不打包、不升级版本、不覆盖 `/Applications`。**未来代码修复完成并进入打包任务时，遵循根 AGENTS：按改动大小更新版本，默认完整安装到 `/Applications`。

1. 用当前 `package_app.sh` 从源码生成完整 `.app`，确认 Swift 可执行文件与 `AstroTransitMac_TransitStudio.bundle` 内 Python 后端均来自该次构建。仅复制 Mach-O 无法部署 backend 修复。
2. 构建前明确 APP_VERSION/BUILD_VERSION 与要安装的提交；资源复制规则变化时使用全新 scratch build，避免旧 bundle 混入。不得把 `.build` 或 `dist` 当源文件编辑。
3. 安装后核对 Info.plist 版本、签名、后端资源文件哈希/内容，并重新启动实际 `/Applications/TransitStudio.app`，运行本次关键功能请求。目录存在或 `ls` 看见文件不证明运行版本正确。
4. 回滚以整个上一已验证安装包或对应提交重新构建为单位；不把新二进制和旧资源拼接。若伴随持久化契约变化，回滚前说明旧版本是否能读取新数据；不自行覆盖用户数据。
5. 保留验证摘要、关键失败/成功证据与必要 fixture，清理本任务产生的 scratch build、pytest cache、`__pycache__`、`.pyc`、封装暂存及探针输出。只删除明确属于本次任务的缓存，不笼统清空用户缓存/虚拟环境/历史备份。

## 10. 已关闭、误报与不修边界

### 10.1 已完成项目

- S-P1-1 SAV 七曜合计 337：已关闭，保留回归，不再列为本次待修。
- 13 项历史计算修复：Arudha、D30、Chara Karaka、Yogakaraka、Ekadhipatya、Nathonatha、ZR/LoB、会合步长、composite 宫位平移、跨0°形态、heliacal previous、Alcocoden 排名、JD 进位。历史完成不表示相关模块以后不可能有独立新缺陷；本版条目必须证明不同触发/根因，不能重跑原清单。
- Horary A–J 与此前已修列表：按 [horary-remaining-fixes.md](horary-remaining-fixes.md) 保持关闭。新 VOC 来源、截断状态、定义一致性必须与已完成任务区分。

### 10.2 仲裁与保留设计

| 条目 | 当前处置 | 重新打开所需证据 |
|---|---|---|
| armc_from_mc 因 MC 黄纬被疑近似错误 | 不改转换公式；W06 可以修错误的近似说明和调用方参考系 | 同参考系输入下独立数值反例，不能重复黄纬指控 |
| scan 无 stderr 进度 | 不修；当前 Swift 不要求该回调 | 真实接口契约变化或实际交互缺陷 |
| ZR 子层 step==24 不可达 | 不修已仲裁路径 | 支持范围内可到达输入；与 R-P3-16 L1 问题分开 |
| jyotish ET/UT ayanamsha 极小差 | 按原仲裁暂不改算法，不重复当 P2 | 超出项目精度预算的实际影响 |
| lot_ruler_condition 中文匹配 | 补审已仲裁匹配正确，不修 | 新的真实字段契约失配 |
| v2 秒级 ID 的亚秒丢失 | 保留既有不修决定 | 明确新需求；不外推到 H-P3-04 legacy 分钟路径 |
| v2 aspects alias、nodes 双位置、UTC 双字段 | 保留兼容契约 | 有版本与消费者迁移计划 |
| 固定偏移无 DST、v2 高级选项无 UI | 既有设计/功能缺口 | 独立功能授权，不混入 bugfix |
| sign_ingress 逆行标记 | 保留既有不修决定 | 新字段/定义的明确产品决定 |

来源报告“已验证干净”表与新发现发生矛盾时，以具体输入、当前代码及独立依据逐项仲裁；不能用一段总括性的“干净”覆盖真实反例，也不能把报告中的每个断言一律当事实。

## 11. 本版文档验收与后续任务记录模板

### 11.1 文档层验收

本版交付前检查：

- 第 6 节 87 个来源 ID 唯一，R/S/H 全部对应，S-P3-24 五子项和 R-P3-17 三子项不丢失。
- 每行只有一个主工作包；18 个 W 包全部定义，14 个 DEC 均可追踪。
- V1 漏项已登记：R-P2-j、R-P3-01/02/03/04/05/10；不以“剩余 P3”笼统带过。
- 关键纠错有实际证据或明确列为待核验；未验证传统定义不冒充已锁定规则。
- 本地 Markdown 链接、命令引用的现有测试和消费者文件可定位；没有伪造的测试文件或不存在的“E-13”。
- 文档任务没有业务源码/fixture/schema 变化，不以未运行的 pytest/Swift 结果宣称全绿。

本次文档校验记录（2026-09-22）：编号集合与来源清单一致；87 条记录无重复且各有唯一归属；18 个工作包与 14 个决策的引用均有定义；本地链接、实际测试/Swift 文件名、代码围栏和尾随空白检查通过。已运行第 3 节接口/数学探针并记录结果。未运行完整 pytest、Swift 或打包流程，本版不宣称业务修复通过。

后续仲裁记录（2026-09-23）：R-P1-2 保留为第 6 节的来源历史记录，但状态改为“已证明非缺陷（关闭）”；EV-04 限定为未调用 helper 的独立行为，EV-13 记录真实入口时区对照。来源 ID 总数仍为 87，每条仍有唯一主工作包，18 个 W 包与 14 个 DEC 定义保持完整；本次未改业务代码、测试或 fixture。

### 11.2 后续每项实施记录模板

```text
来源 ID / 工作包：
当前阶段 / 最终处置：
基线 HEAD / 分支 / 解释器及库版本：
受影响生产文件与消费链：
最小输入 / 旧输出 / 独立期望与来源：
反例、适用域与最大残差：
相关 DEC、决定依据与批准记录（若适用）：
旧代码失败测试与实际输出：
最终实现和契约差异（schema/单位/null/ID/精度）：
聚焦测试 / 模块回归 / 完整门禁结果：
fixture/golden 的真实生成输入与受影响字段：
UI/导出验证 / 发布验证（若适用）：
风险、缓解完成但算法未完成的部分：
对应提交 / PR / 远端同步事实：
缓存清理范围：
```

任务关闭只能选择：已修复并验收、已证明非缺陷、依据明确决策保留现状、被后续任务替代（注明新 ID）。等待证据或决定的项目保持未完成；不能在整体交付时消失。
