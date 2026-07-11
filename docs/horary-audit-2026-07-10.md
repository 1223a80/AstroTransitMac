# Horary 计算模块专项审计

- 日期：2026-07-10
- 审计分支：`codex/audit-horary-2026-07`
- 基线提交：`49002fe`
- 范围：只读审查、真实星历复现与契约核对；本轮未修改计算业务代码。

## 结论摘要

本轮确认 17 项问题：5 项 P1、10 项 P2、2 项 P3。最需要优先处理的不是 JSON 能否生成，而是 Horary 派生判断没有统一的事件序列模型：当前相位、未来精确相位、停滞/逆行、换座与第三方介入由多组独立 helper 分别判断，导致同一盘面可以同时出现互相冲突的 `Collection / Prohibition / Frustration`，也会把 refranation 后的重新入相误当作原相位连续完成。

现有 Horary 聚焦测试全部通过，但多数测试验证函数形状、单一局部条件或 mock 后的时间顺序，没有覆盖“真实天空中的完整事件链”和 Swift 消费端的数据完整性。因此这些问题大多属于测试盲区，而不是既有测试失败。

## 模块与数据流

| 层 | 主要文件 | 责任 |
|---|---|---|
| Swift 请求 | `RequestModels.swift`、`ContentView+RunActions.swift` | 组装时间、地点、宫制、黄道、界、三分主与 orb |
| 进程契约 | `BackendClient.swift`、`transit_calc.py`、`astro_backend_api.py` | JSON 编解码、字段校验、Python 进程调用 |
| 古典盘快照 | `astro_backend_classical.py` 及 dignity/lots/ephemeris 子模块 | 宫位、七政、尊贵、Lots、相位、接纳、评分 |
| Horary 时间层 | `astro_backend_horary.py:59-530` | 精确相位搜索、换座、Moon storyline |
| Horary 判断层 | `astro_backend_horary.py:533-1279` | 宫主、征象星、关键链接、负接纳、Translation/Collection/Prohibition/Frustration |
| 响应组装 | `astro_backend_horary.py:1282-1367` | meta、派生区块与底层快照合并 |
| Swift 展示/导出 | `HoraryResultModels.swift`、`HoraryResultViews.swift`、`ChartWheelData.swift`、Markdown/CSV builders | 解码、星盘图、总览、JSON/Markdown/CSV、AI 数据包 |

权威口径核查主要参考 William Lilly《Christian Astrology》以及 Skyscript 对传统 perfection/denial 的梳理。Lilly 对 Translation、Collection、Refranation 的原始定义见[公共领域扫描本第 130–145 页](https://krasiancientastrology.com/wp-content/uploads/2016/11/CA-I-copy.pdf)；Graeme Tobyn 对速度、first application 与 denial 顺序的归纳见[Skyscript 专文](https://www.skyscript.co.uk/tobyn2.html)。

## P1：会直接改变核心判断或使核心视图失效

### P1-01 换向后仍把后来重新入相当成原相位完成

位置：

- `astro_backend_classical.py:262-269`：`applying_label()` 只看起盘瞬间的 signed orb 与相对速度。
- `astro_backend_horary.py:704-765`：`exact_datetime_for_signature()` 只限制双方换座，没有验证到 exact 之前 orb 是否持续收敛、是否发生停滞/逆行。

真实复现：

- 时刻：`2026-10-21 00:00 UTC`
- 地点：纬度 `0`、经度 `-60`
- Whole Sign / Tropical / `aspectOrb=3`
- 问题：`财务`

实际输出把 Mercury–Jupiter square 标成 `入相`，并给出 `perfects_before_sign_exit=true`、`2026-12-04 07:02`。但 orb 从 `2.53894°` 扩大到 `20.65122°`；Mercury 中途停滞逆行，之后恢复顺行才重新成相。原始 application 已被 refranation 否决，[Skyscript 对 refranation 的定义](https://www.skyscript.co.uk/glossary/refranation/)也明确说明应用星在成相前逆行即不再完成原相位。

影响：关键征象星链接、degree-based aspects 以及四类 advanced candidates 都复用该函数，会系统性误报“会完成”。

### P1-02 Moon 位于配对右侧时，漏掉已算出的换座前成相

位置：`astro_backend_horary.py:823-849`。

Moon 特例只判断 `left_row["id"] == "MOON"`。但 `Querent ruler – Matter ruler` 的固定顺序会在 Matter ruler 为 Moon 时把 Moon 放在右侧。

真实复现：

- `2026-01-03 00:00 UTC`
- 纬度 `0`、经度 `-10`
- Whole Sign / Tropical / `aspectOrb=3`
- 问题：`工作`

`moon_storyline.before_sign_exit_aspects` 已有 `Moon opposition Venus @ 08:40`；同一响应的 `VENUS|MOON|link` 却返回 `sign-based only`、`perfects_before_sign_exit=false`、无精确时间。相位关系是对称的，两个区块对同一事件给出相反结论。

### P1-03 Translation of Light 可把更慢行星误判为翻译者

位置：`astro_backend_horary.py:1043-1092`。

当前逻辑只要求第三星对一方显示“离相”、对另一方显示“入相”，没有检查它是否比两颗主征象星更快，也没有建立“上一接触 / 下一第一接触”的完整队列。传统 type-1 Translation 要求翻译者是更快的中介；Tobyn 的归纳明确写为“swifter than either”。

真实复现（基于 `Examples/sample-horary-request.json` 覆盖字段）：

- `2015-01-01 12:00 Asia/Shanghai`
- 问题：`房产`
- `aspectOrb=8`

输出：`木星 先离相于 月亮，再入相于 火星`，并标为 detected。实际速度为：

- Jupiter：`-0.0739007°/day`
- Mars：`+0.7828891°/day`
- Moon：`+13.1684695°/day`

木星明显不是承担传光的快行星，属于真实生产路径误报。

### P1-04 Advanced candidates 缺少统一事件队列，会同时输出矛盾证词

位置：

- Collection：`astro_backend_horary.py:1095-1148`
- Prohibition：`astro_backend_horary.py:1151-1200`
- Frustration：`astro_backend_horary.py:1203-1261`
- 四项独立拼装：`astro_backend_horary.py:1264-1279`

真实复现：

- `2010-01-03 00:00 Asia/Shanghai`
- 上海 / Regiomontanus / Tropical
- 问题：`学习`
- `aspectOrb=8`

同一响应给出：

1. Venus–Mercury 主合相：`2010-01-05 18:39`；
2. Collection by Sun：完成时间 `2010-01-12 05:05`；
3. Prohibition by Sun：`2010-01-05 03:06`；
4. Frustration by Sun：同一事件 `2010-01-05 03:06`。

真实时间顺序是 Mercury–Sun → Venus–Mercury 主相位 → Venus–Sun。所谓 Collection 的第二次接触发生在主相位之后，且不是双方的 first application，不可能再作为促成主事件的收集；同一个 Mercury–Sun 事件又被重复列为 Prohibition 和 Frustration。即使采用允许主征象星彼此应用时仍讨论 Collection 的宽口径，也不能忽略 first application 顺序。

根因不是单个 `if`，而是四个 detector 分别搜索自己需要的局部事件，没有共享按 UTC 排序的事件流，也没有优先级、互斥或 subtype 关系。

### P1-05 Horary 星盘图的相位线实际渲染数为 0

位置：

- `ChartWheelData.swift:178-203`
- `ChartWheelCanvas.swift:165-173`

后端 `ClassicalAspectRow.bodyA/bodyB` 是中文显示名（如“太阳”“水星”）；星盘点的 `id` 是 `SUN/MERCURY`。`ChartWheelData(horaryResult:)` 把中文名直接当端点 ID，Canvas 查找失败后逐条 `continue`。

原 Horary sample 有 11 条相位，端点可匹配数为 `0/11`。这也影响复用同一映射的 Classical wheel。修复端点后还需同步标准化“整宫冲相 / 整宫拱相 / 同宫”的颜色 key，否则会统一走 fallback 色。

## P2：确定错误、数据丢失或重要边界问题

### P2-01 IANA 夏令时回拨期间的精确相位搜索会返回伪根

位置：`astro_backend_horary.py:112-172`；同类本地时间轴运算还存在于 previous search 和 sign-exit search。

搜索与二分直接在带 `ZoneInfo` 的本地 `datetime` 上加减 `timedelta`。回拨时 `01:xx` 出现两次，本地时间轴不连续，二分无法正确进入 `fold=1` 的重复小时。

复现：`2000-10-29 00:00 America/New_York` 搜索 Moon–Saturn opposition。

- 本地时间轴搜索返回 `01:59:59 EDT = 05:59:59 UTC`，相位残差 `0.036235°`；
- 在 UTC 时间轴搜索返回 `06:04:05 UTC = 01:04:05 EST`，残差约 `2.0e-7°`。

Swift 桌面端当前只发送固定 `GMT±offset`，不会触发；正式支持 IANA timezone 的 JSON/CLI 契约会触发。因此桌面影响为 P2，若后端被外部直接调用则应提升优先级。

### P2-02 “换座后首相位”固定跳过一分钟，会漏掉真实首相位

位置：`astro_backend_horary.py:501`。

代码从 `sign_exit_dt + 1 minute` 开始搜索。`1905-06-21 12:00 UTC` 的真实星历中：

- Moon 入双鱼：`1905-06-22 02:56:37.398`
- Moon trine Sun：`1905-06-22 02:57:03.937`
- 间隔仅 `26.54` 秒

当前结果跳过 Sun，错误报告 `08:27` conjunction Saturn 为首相位。

### P2-03 四项扩展 Lots 公式偏离仓库声明的 source of truth

位置：

- 规范：`docs/expansion-002/arabic-parts-expanded.md:5,40,49,59,61`
- 实现：`astro_backend_classical_lots.py:108-127`

该规范明确声明表格为项目实现的 source of truth；当前代码却有以下漂移：

| Lot | 项目规范 | 当前实现 |
|---|---|---|
| Marriage（日） | `ASC + Saturn - Venus` | `ASC + Venus - Saturn` |
| Travel（日） | `ASC + H9 cusp - H9 ruler` | 固定减 Jupiter |
| Lost Objects（日） | `ASC + Moon - H2 ruler` | 固定减 Mercury |
| Murder（日） | `ASC + H12 ruler - Saturn` | 固定加 Mercury |

原 sample 中 Marriage 实算 `250.056675°`，按规范应为 `122.306069°`；Travel 实算 `139.299783°`，H9 ruler 为 Mercury 时规范值应为 `214.543247°`；Lost Objects 实算 `56.159937°`，H2 ruler 为 Mars 时规范值应为 `70.778891°`。

核心 `lots_summary` 的 Fortune/Spirit/Eros/Necessity 未发现这类漂移，但完整 Horary `lots` 会向 UI、JSON 与 CSV 暴露错误扩展点。

### P2-04 conditioning 修改分数后没有重算 `score_label`

位置：

- 初始 label：`astro_backend_classical.py:179-189`
- 后续改分：`astro_backend_classical.py:394-399`

原 sample 的 Jupiter 从 `11` 被 Mars maltreatment 减到 `9`，JSON 仍保留 `score_label="强而有力"`。依同文件阈值，9 分应是“状态良好”。Horary 的“评分明细”页会并列显示互相冲突的数值与标签。

### P2-05 双重 negative reception 被 `elif` 截断

位置：`astro_backend_horary.py:987-992`。

当同一星座既是某行星的 detriment 又是 fall 时，当前 `if/elif` 只保留一项。Mercury 同时守护且擢升 Virgo，因此 Pisces 同时是 Mercury 的 detriment 与 fall。

复现：把 sample 时刻改为 `2026-03-10 15:30 Asia/Shanghai`、`aspectOrb=8`。Sun/Mercury/Mars 在 Pisces；输出的 Mercury negative receptions 只有 detriment，全部缺 fall。正接纳实现会逐项保留多个 dignity，负接纳不应静默丢一项。

### P2-06 非 Lahiri 恒星黄道一律被标成 Lahiri

位置：`astro_backend_horary.py:1331-1344`。

实际计算会正确切换 ayanamsha，但 meta 使用 `"Lahiri Sidereal" if sidereal else "Tropical"`：

- `sidereal_raman`：sample Sun `22.045601°`，meta 为 Lahiri；
- `sidereal_krishnamurti`：sample Sun `20.696152°`，meta 仍为 Lahiri。

因此数值来自不同模式，UI/JSON/导出却声称同一模式。Classical API 已有可复用的 label 映射。

### P2-07 Advanced candidate 的动态字段与 exact time 在 Swift 消费端丢失

位置：

- 后端 Frustration：`astro_backend_horary.py:1250-1259`
- Swift 模型：`HoraryResultModels.swift:262-291`
- UI：`HoraryResultViews.swift:223-258`
- Markdown：`MarkdownHoraryExportBuilder.swift:152-157`
- CSV：`TextExportBuilder.swift:370-371`

后端 detected Frustration 同时返回 `frustrated_planet` 与 `frustrating_planet`；Swift 只有前者，解码后重新导出 JSON 会永久丢掉真正的第三方行星。四类 advanced row 的 `exact_time` 虽然已解码，但总览、Markdown、CSV 与 AI 数据包都不显示/导出，只有原始后端 JSON 保留。

### P2-08 Horary Points 页把 experimental Lots 混入正式 “Hermetic Lots”

位置：

- `ContentView+ResultsPanes.swift:407-409`
- `ClassicalResultViews.swift:47-65`

Horary 把全部 `result.lots` 传入正式 lots 参数，同时把 `experimentalLots` 设为 `nil`。原 sample 的 56 项包含 `experimental=3`，三项实验点因此没有橙色警告与 confidence；CSV 也不导出 `lot_group/confidence`。

### P2-09 结果与 AI 数据包缺少本次 orb / 完整计算设置 provenance

位置：

- 请求发送：`ContentView+RunActions.swift:455-471`
- 后端 meta：`astro_backend_horary.py:1331-1345`
- Markdown：`MarkdownHoraryExportBuilder.swift:10-15`

`aspectOrb` 确实参与关键链接、负接纳和 advanced 判断，但响应 meta 不保存它。用户修改 orb 后无法知道当前结果采用哪个值，JSON/Markdown/CSV 不能完整复算。Markdown/AI 的 Chart 行还遗漏 zodiac、bounds 与 triplicity；在 sidereal 或非默认尊贵体系下，AI 不知道数据所用口径。

### P2-10 Horary JSON 页在原页重算后保留旧结果

位置：`ResultUtilityViews.swift:3-26`，调用点 `ContentView+ResultsPanes.swift:417-418`。

`RawJSONView` 只在首次 `onAppear` 生成 JSON，并用 `hasGeneratedJSON` 永久阻止重算。用户停留 JSON 页，修改问题/时间并重新起盘后，父视图传入新 `result`，但相同 SwiftUI 结构身份保留旧 `@State`，页面继续显示上一盘 JSON。

## P3：输入契约与诊断不足

### P3-01 Horary 后端只验证顶层 `chart`

位置：`astro_backend_api.py:603-618`。

`validate_required_fields({"mode":"horary","chart":{}})` 返回 `None`，随后才因 KeyError `moment` 失败。当前未验证 `chart.moment`、经纬度及范围、嵌套对象类型、`questionText`、`aspectOrb` 范围。Swift UI 会阻止空问题，但 JSON/CLI 契约不会。

### P3-02 常见问题没有宫位覆盖或人工 override，会静默停用核心判断

位置：`astro_backend_horary.py:39-47,576-690`；UI 输入见 `ContentView+SidebarSections.swift:143-166`。

当前只靠少量中文 substring 推断 2/4/6/7/9/10 宫，没有让用户显式选择 quesited house。`我的猫会回来吗？` 会返回 Matter/Natural 均为 `unknown`、四类 advanced 均因缺征象星而停用，且 warnings 为空；宠物在传统 Horary 中是标准 6 宫问题，参见[Skyscript house significator 说明](https://www.skyscript.co.uk/horary1dc.html)。子女、朋友、兄弟姐妹、诉讼、失物等常见主题同样没有稳定覆盖。

这更接近功能/产品契约缺口，而非天文数值 bug；建议由用户确认是扩展关键词，还是增加显式宫位选择并把自动推断降为建议值。

## 已验证为正常或暂不列为 bug

- Swift Horary 请求 camelCase 与 Python 读取一致；独立 Horary GMT offset、宫制、黄道、界、三分主均正确传入。
- 有符号 ± 相位分支、合相/冲相穿零、固定时区下的二分精度正常。
- 双方换座截止、目标星先换座过滤、逆行换座方向，以及 exact event 的动态经度/静态 Horary 宫头重算正常。
- Horary tabs 与 `selectedResultView` cases 完整对应；AI `streamKey="horary"` 独立。
- `last_aspect` 跨当前星座回看不列为 bug：字段只承诺“上一精确相位”，而 Lilly 的实际案例也会回溯到前一星座。
- VOC 当前明确声明为“Moon 在换座前与七政完成 Ptolemaic exact aspect”的项目口径。传统文献对 orb、application、跨星座 perfection 存在不同口径；缺少产品决策时不把这一差异判成 bug。
- 统一 `aspectOrb`、默认宫制、ASC 早晚度、Saturn 7H、Hayz 范围等属于已选参数或不完整功能，本轮不按 bug 处理。
- 非相位 mutual reception 当前不会生成 reception row；传统与当前模型边界并未在项目文档中明确，本轮记录为后续业务决策点，不冒充已确认 bug。

## 验证记录与测试盲区

已运行：

```text
PYTHONDONTWRITEBYTECODE=1 /usr/local/bin/python3 -m pytest \
  python_tests/test_horary.py \
  python_tests/test_contracts.py::TestHoraryContract \
  python_tests/test_audit_classical_regressions.py::test_horary_aspect_event_recomputes_exact_longitudes_and_houses \
  python_tests/test_extended_lots.py -q

79 passed in 6.15s
```

Swift `BackendContractTests`：8 项通过，其中 `decodeHoraryResultFromRealOutput()` 通过；这只能证明当前 fixture 可解码，不能覆盖 detected-state 动态字段丢失。

Horary sample smoke：成功，耗时约 `0.15s`，返回 11 条相位且 warnings 为空。验证后已清理 `.build` 与临时审计文件。

现有测试主要缺少：

1. 真实事件序列属性：orb 必须持续收敛、途中 station/retrograde、first application、同一事件不能被矛盾分类；
2. 对称性属性：Moon 在 pair 左/右两侧结果一致；
3. UTC 搜索属性：对任何 timezone 输入，exact UTC 与残差应一致；
4. 项目文档到 `LOT_LIST` 的逐条公式契约；
5. 响应的 detected-state fixtures（当前 fixture 只有 advanced `not detected`）；
6. Wheel endpoint 可解析、RawJSON result 更新、experimental lot 分组与导出 provenance 的 Swift 测试。

## 建议修复顺序

1. 先建立统一 UTC event queue：相位 exact、station/direct/retrograde、sign ingress、first application；让 key links 与 advanced detectors 只消费同一事实流。
2. 修 P1-02 的 Moon pair 对称性，并为真实 Moon-Matter 请求加回归。
3. 以统一事件流重写 Translation/Collection/Prohibition/Frustration 的顺序与分类关系。
4. 修 Wheel endpoint ID，再补 whole-sign aspect 颜色标准化。
5. 修 Lots source-of-truth、score label 与 negative reception，多加数据表驱动契约测试。
6. 最后补 Swift 字段/导出、meta provenance、JSON 刷新和后端嵌套验证。

本轮没有擅自修改上述计算规则；修复应另开任务，并在动手前确认 VOC、reception 与自动宫位推断的产品口径。
