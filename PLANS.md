# Horary V3 应用入口补齐（2026-10-03）

状态：功能、验证与覆盖安装完成，进入提交推送收尾。沿用 codex/horary-v3，安装版本 1.6.1 (54)。默认起盘 V3，侧栏提供持久化 V3 / V2.1 切换，应用复制、Markdown 导出及 AI 数据使用同一 Python 阅读版；V2.1 显式入口保留。本记录随修正提交推送，远端同步以最后 Git 核验为准；末尾既有分享检查笔记仅保留本地。

- [x] 接通版本选择、请求和阅读导出，更新契约夹具与针对性测试。
- [x] 运行项目门禁，检查差异与包内默认 / 显式 V2.1 行为。
- [x] 打包覆盖并清理本轮缓存，整理独立任务提交；本提交推送后核验远端同步。

验证记录：最终完整门禁通过，Python 1224 项，Swift build 成功，229 项 / 31 组（含 44 个实时样例）通过。首次门禁唯一失败是旧默认测试仍传 packetVersion=2，修正后专项通过并完整重跑。V3 夹具与前一版本相比仅新增 display.reader_markdown，数值证据未变。Release 构建成功（224.20 秒），arm64 与严格签名检查通过；包内 74 个 Python 模块及星历与源码一致，无字节码缓存。包内缺省请求返回 3.0，显式 2 返回 2.1，均为 7 天体且无 warnings。

安装及界面：正常退出旧版后覆盖 /Applications/TransitStudio.app，安装版本 1.6.1 (54)，二进制 SHA-256 a97a979cf6fded3950e948af98685c4d705133ef890076291415d4152b790a8b 与验证包一致。原生 UI 默认 V3、起盘实际显示 3.0；实际保存 Markdown 为阅读工作表（含既有提示词，133 行 / 6869 字节）；切 V2.1 清空旧结果，实算显示 2.1，计算期间切换禁用。结束时恢复 V3 并清除测试文本/结果，保留既有用户设置；UI 的可选固定星模块提示缺星表，没有擅自改用户星历设置。清理本轮约 766 MB release/debug 构建、输出/暂存、旧包备份和验证文件。

# Horary V3 发布收尾（2026-10-03）

状态：打包覆盖完成。用户授权打包覆盖并 push；继续 `codex/horary-v3`，发布 `1.6.0 (53)`，默认 V2.1 不变。本段发布记录随下一提交一起 push，远端同步以收尾核验为准。当前代码/测试/文档均为本聊天 Horary V3；PLANS.md 末尾 2026-09-28 分享检查是既有未提交记录，保留本地、不混入本次提交。

- [x] 阅读项目要求，核对当前版本、运行中的应用、打包流程和远端；沿用 2026-10-02 完整门禁通过记录。
- [x] 更新版本与发布说明，补跑 V3 专项；在任务专属临时目录构建 release，核对签名、资源及包内后端。
- [x] 正常退出旧应用，覆盖 `/Applications/TransitStudio.app`，核验安装版本/资源并启动新版；不修改用户配置。
- [x] 按任务边界拆分功能和发布记录，清理构建/暂存缓存。发布记录提交后推送当前分支，以 `git status --short --branch`、`git rev-list --left-right --count HEAD...@{upstream}` 及 `git ls-remote` 核验。

验证记录：本轮 V3 专项 74 项通过；Swift release 构建成功（100.97 秒）。输出包及安装包均为 1.6.0 (53) / arm64，严格签名校验通过；74 个 Python 模块与源码逐字节一致，星历资源一致，无 `.pyc` / `__pycache__`。分别从包内 CLI 运行显式 V3 与缺省 V2.1，请求均返回 7 天体且无 warnings，V3 JSON Schema 与内部一致性通过，包内 Python 阅读导出正常。安装二进制 SHA-256 `481ebf24a178762c754f2325668d8b05f34ad69c0e54a7d77a9924df2e240c1f` 与验证包一致；正常退出旧进程后已重新启动安装版。已删除本轮约 267 MB 的 release 构建、输出、暂存、验证脚本与旧包临时备份，仅保留安装版；未改用户设置、未合并 main。

# Horary V3 Markdown 阅读体验修复（2026-10-02）

状态：完成。当前工作区的未提交实现、测试与文档均属于本聊天的 V3 工作，在 `codex/horary-v3` 完成导出层修复。按用户新增要求，将默认 Python Markdown 改成选择性的解盘工作表：时间地点与口径、十二宫宫主、七星位置/尊贵/运动/日光状态、容许度内相位和窗口内成相候选及已知阻碍、相关星对接纳、月亮最近离相/出座前后续/换座后第一相位、福点与必要注意事项。完整候选、事件、其余 Lots、可选模块和采样日志留在 JSON；不猜问题宫位、不产生自动吉凶判断、不修改计算或 JSON 契约。

- [x] 阅读项目规则，确认问题来自 V3 复用的诊断 Markdown 格式；核对现有 Python/Swift 导出、测试和崂山原始数据。
- [x] 实现独立的 V3 人类可读渲染器，补充格式、时区、缺失状态、转义和事实保留测试，更新文档与 CHANGELOG。
- [x] 用原先 2026-10-01 22:03:10 崂山 JSON 重导出原 Markdown 文件，检查实际内容与渲染效果。
- [x] 完成相关测试和项目门禁，检查本轮差异，清理构建缓存并交付阅读版。

运行记录：原 Markdown 691 行 / 251440 字节改为 120 行 / 5993 字节；105 个候选筛选为 8 条、56 Lots 仅默认保留福点、189 事件只选近期驻留变化，月亮按本座推进单独呈现。原 JSON 字节不变，SHA-256 `07111f3db8ed3bec640fc586ca65a459ae8e0f7820c2e4d85e2186cf16ba9d85`。本座 VOC 为否；跨座四日口径端点倒序在阅读版明示，未修改该计算。

验证：完整门禁通过（Python 1219 项、Swift build、229 项 / 31 组，含 44 实时样例）；门禁启动后的最后月相/接纳方向细化另跑最终 V3 专项，74 项通过，其中阅读版 28 项。使用原包重导出且核验无变异；用 Marked + 系统 Chrome/Playwright 实际渲染，1280px 桌面与 390px 手机均为 7 张表、8 条相位，无破列、字典转储或页面溢出；手机宽表局部横向滚动。审阅本轮新增模块和完整工作区差异，`git diff --check` 通过。清理本轮约 493 MB 临时 SwiftPM/浏览器验证目录，无新增 Python 字节码缓存；未打包、安装、提交或推送。

# Horary V3 崂山区当前时刻实盘（2026-10-01）

状态：完成。直接调用本地 `calculate_horary_v3` 和 `format_horary_v3_markdown`，按青岛崂山区代表坐标与本轮读取的当前时刻（北京时间 2026-10-01 22:03:10）计算。沿用 V3 默认 Regiomontanus / tropical / Egyptian / Dorothean 配置；输出后端原生 Markdown、JSON 和请求参数至本聊天的产物目录，核验 schema、内部一致性与时间地点。不修改计算代码，不运行占星解读技能。

- [x] 阅读项目规则，核对 V3 接口、工作区与当前 UTC 时间。
- [x] 核对崂山区代表坐标，直接运行 V3，输出并检查 Markdown 与机器数据。
- [x] 交付 Markdown 文件，记录具体起盘时间、坐标及验证结果。

运行记录：地点使用 Wikidata Q181352 的区级代表坐标（https://www.wikidata.org/wiki/Q181352），36°06′27″N / 120°28′08″E，即 latitude=36.1075、longitude=120.46888888888888；用户未提供具体地址，海拔沿用默认 0 m。起盘时刻 UTC 2026-10-01 14:03:10，questionText 为空。原生 Markdown 691 行 / 251440 字节，7 天体、105 相位候选、189 事件、56 Lots；JSON Schema 和内部一致性检查通过，无 warnings。产物保存于 `/Users/gacu/.codex/visualizations/2026/10/01/01a0f639-fa13-7e71-a1ae-9254981cfa3c/horary-v3-laoshan-20261001-220310.md`，同目录保留 `.json` 与 `-request.json`。使用 `python3 -B` 与 `PYTHONDONTWRITEBYTECODE=1`，未生成构建或字节码缓存。

# Horary V3 结构重写（2026-10-01）

状态：完成，代码保留在本地 `codex/horary-v3` 分支，未提交。授权范围：新增 Horary V3 后端实现及显式请求入口，核对直接依赖、Python/Swift 契约与导出；V2.1 默认入口和既有输出保持兼容。本轮不打包、不推送。原有未提交 PLANS.md 内容属于先前的单文件分析和分享检查，保留。

- [x] 核对请求分发、计算依赖、结果模型、现有测试和验证脚本；新增显式 V3 / schema 3.0 路由，保留 V2.1 默认路径。沿用既有专业计算器和来源标签，重写编排与事件计算。
- [x] 实现经过校验的配置、计算上下文、事件搜索与索引、数据包组装及验证。首个真实临沂请求约 1.2 秒，7 天体 / 105 候选 / 56 Lots / 192 个事件，内部一致性检查通过。
- [x] 增加真实计算、版本路由、结构契约及已发现边界问题的回归测试；更新样例、文档、CHANGELOG，生成独立 V3 真实输出夹具并增加 Swift 无损往返、显示、导出测试。最终 V3 专项 46 项通过；此前与 V2/legacy/classical 聚焦回归 276 项通过。
- [x] 运行聚焦测试和完整本地门禁，检查完整差异，清理本轮构建与测试缓存，记录结果。

最终验证：`bash check_vibe_changes.sh` 通过，Python 1195 项；Swift build 成功，229 项 / 31 组通过，包含 44 个 Examples 实时后端解码。真实 V3 夹具与 CLI 输出逐字节一致；额外极区宫制回退、南半球、DST fold=1 三个请求通过 JSON Schema 和内部一致性检查。门禁期间修正了新增 Markdown 的可选字符串编译错误，以及星历路径非法假值与 null 别名回退边界。完整审阅新增实现和现有文件差异，`git diff --check` 通过。已删除本轮 SwiftPM 临时构建目录（约 492 MB）及 backend/python_tests 字节码缓存，未改旧 V2.1 源文件、默认路由或旧夹具，未更新安装版应用。

实现边界：V3 主模块 185 行，六个职责模块共 967 行，仍复用既有 V2 专业事实计算器并保留其来源标签。几何事件搜索按已声明的采样步长工作，不宣称解析意义上的完全覆盖；候选成相资格、接纳和可选模块算法不在本轮重定义范围。

# Horary V2.1 单文件分析（2026-10-01）

状态：完成。授权范围：仅分析 `Sources/TransitStudio/Resources/backend/astro_backend_horary_v2.py`；不修改业务代码，不扩展阅读依赖模块、测试或历史审查报告。既有 PLANS.md 未提交内容属于 2026-09-28 分享检查任务，完整保留。

- [x] 阅读项目 AGENTS.md，确认文件、版本与既有工作区改动。
- [x] 通读目标文件全部 2,384 行，梳理入口、数据组装、事件搜索、可选模块及导出。
- [x] 使用 AST 提取本文件函数和语句，在内存中以合成依赖执行隔离检查；未导入其他项目模块。复现驻留搜索不足 6 小时及末尾余段漏检、VOC 端点去重丢失规则关联、搜索缺失仍输出确定 VOC、有限巨大时间窗触发 OverflowError、altitudeM 空值容器绕过数值校验、负亚秒事件 offset 截断为 0、禁用字段扫描警告未同步到包内 warnings。验证事件流只收集部分最近事件，以及 Delta T 失败时 jd_tt 回退 jd_ut。
- [x] 在聊天中交付单文件分析、行号证据与验证边界，完成任务记录。

验证边界：上述为本文件控制流及边界行为的隔离复现，不代表真实星历端到端结果；没有检查依赖实现、入口外层校验或 Swift 消费者，没有运行项目测试或构建。业务源码、测试、CHANGELOG 均未修改；使用 `python3 -B`，没有生成本轮构建或字节码缓存。

# bug fix v2 集成版打包覆盖（2026-09-24）

状态：已完成。补齐 `main` 已集成修复的本机发布步骤；按补丁版本更新为 `1.5.3 (52)`，验证应用包后覆盖 `/Applications/TransitStudio.app`，记录安装结果并清理缓存。

- [x] 核对项目打包规则、脚本、已安装版本、当前分支与运行中的应用。
- [x] 更新打包版本及发布记录，检查完整差异；沿用集成后完整门禁（Python 1149、Swift 227、43 个实时样例），发布构建成功。
- [x] 生成并验证 `1.5.3 (52)` 应用包，覆盖安装；安装版签名、版本、arm64、包内代码及二进制 SHA-256 对照通过，无 `.pyc`/`__pycache__`，安装版后端确认 Egyptian ASC 界终点 20°、极值 rate 返回结构化 `invalid`。
- [x] 清理本轮 release 构建、封装暂存与 `dist` 中受 FileProvider 扩展属性影响的中间副本；保留已验证的 `/Applications` 安装版。提交并同步发布记录，最终回到 clean 的 `main`。

# S-P2-2 / W04 Hellenistic 相位 ID/状态适配（2026-09-23）

状态：已完成实现、验证与本地逻辑提交；只修复 Hellenistic audit 与 classical 上游相位行的稳定 ID / 字段值匹配，不包含 Mercury Hayz、Hyleg、syzygy、ZR 或其他 W04 来源项，不重设计 JSON schema。

- [x] 确认 W04 Hayz 提交 `b4c8d66` 已留在独立分支且工作区 clean；从同步计划分支 `codex/bugfix-plan-v2` (`2298535`) 创建独立分支 `codex/fix-hellenistic-aspect-mapping`。
- [x] 完整复读 `AGENTS.md` 和 v2 EV-07、W04 相位适配与 S-P2-2 验收要求；开始核对 classical 上游相位、audit 消费、测试与 Swift 字段消费。
- [x] 先增加独立红测：以 classical 生产 wire shape 的入相/离相行逐行匹配稳定 ID；验证合法 `False` 与 `orb=0` 不会被 `or` 当作缺失；运行旧代码并记录失败证据。
- [x] 最小修复：优先复用/补齐上游稳定 ID 或现有映射；保留当前 wire schema、展示字段和既有状态值，不靠七曜全状态样本代替逐行断言。
- [x] 核对 Swift Codable、Hellenistic 结果视图及 Markdown/JSON 导出；只有调用与 fixture 证据要求时才同步模型或夹具。
- [x] 每次代码改动更新 `CHANGELOG.md`；运行聚焦及相关测试与完整 `bash check_vibe_changes.sh`，清理本任务构建缓存。
- [x] 审阅完整 diff/status，完成一个本地逻辑提交；不 push、不开 PR、不打包。

验证记录：旧代码红测为 3 failed（生产 wire 行未匹配到任何 Mercury 相位；`applying=False` 未生成离相行；`orb=0.0` 被 `exact_orb=2.75` 覆盖）。修复后聚焦 Hellenistic / classical / derivative 测试为 93 passed。用真实 `transit_calc.py` 入口运行 audit 样例、将 `aspect_orb` 设为 15.0，得到 20 条相位证据（10 入相、10 离相）；输出保留 `geometry` 中文相位名及现有 `applying_separating` / `orb` 字段。Swift `HellenisticConditionRow` 已解码这些字段，结果表/Markdown 展示 `geometry`，CSV 导出状态与 orb；JSON schema 未变。既有 fixture 使用 `aspect_orb=3.0`，重算与 fixture 都没有符合门槛的 degree 相位证据行，故不需更新 fixture。完整门禁通过：Python 1094 passed，Swift build 成功、227 tests / 31 suites 通过（43 个 Examples 实时解码），差异格式检查通过；清理了本任务 Swift 临时构建目录及 pytest/backend 字节码缓存。

执行边界：以当前真实生产相位字段与现有类型契约为准；如证据显示报告归因不成立，先将复现/调用证据写入本文与 CHANGELOG，并以“已证明非缺陷”关闭，不扩成别的 W04 修复。

# R-P2-b / W04 Mercury Hayz（2026-09-23）

状态：已完成；只处理 Mercury 的 Hayz 资格判定错误，不包含 W04 的 Hellenistic ID、Hyleg、syzygy、ZR 或其他来源项，不改 `planet_sect` 的语义。

- [x] 确认 W03 提交 `cd516aa` 已留在独立分支且工作区 clean；从同步计划分支 `codex/bugfix-plan-v2` (`2298535`) 创建 `codex/fix-mercury-hayz-sect`。
- [x] 完整复读 `AGENTS.md` 与 v2 W04/R-P2-b/EV-07 要求；开始核查既有 Hayz、sect 接口、测试及 Swift 消费者。
- [x] 先写独立红测：按当前锁定 Hayz 契约覆盖 Mercury 东方/西方、昼/夜、上下半球与黄道星座性别的 16 组正反例；附其他行星通用分支保护断言。旧代码 `test_classical.py` 为 94 passed / 8 failed，失败均由 Hayz 将 Mercury 的 sect 状态误读为 False 导致。
- [x] 最小修复：保持 `hayz_status` 签名及返回结构，改为读取 `sect_status(...)[3]['sect_agreement']`；不改 `planet_sect` 既有语义，不加入来源未授权的新规则。
- [x] 核对 Swift 模型、结果展示与导出：`ClassicalPlanetRow.hayz` 继续解码既有字符串字段，表格与 Markdown 导出直接展示该值；无 JSON shape 变化，不改 Swift / fixture。
- [x] 更新 `CHANGELOG.md`；聚焦 classical/Hellenistic audit/classical derivatives 回归 107 项通过；完整 `bash check_vibe_changes.sh` 通过（Python 1108 项，Swift build，Swift 227 项/31 suites，43 个实时请求解码）；清理本任务构建缓存。
- [x] 检查完整 diff/status，完成一个本地逻辑提交；不 push、不开 PR、不打包。

执行边界：只按现有锁定契约判读昼夜、地平线上下、行星/星座性别。若契约与传统规则或实现边界矛盾，先保留证据并暂停生产修改，报告仲裁所需信息。

# R-P2-g/h / W03 method_families 输入校验（2026-09-23）

状态：已完成；仅修复 `method_families` 中自定义 solar-arc rate 与实验 profile 选项被静默吞值/宽松强转的问题，不调整结果 JSON shape。

- [x] 确认 W01 分支 `eb1ff0b` clean；从同步的 `codex/bugfix-plan-v2` (`2298535`) 创建独立分支 `codex/fix-method-families-inputs`，避免混入 W01。
- [x] 完整复读 `AGENTS.md`，核对 v2 W03 要求；检查 `validate_required_fields`、`_is_finite_number`、`calculate_method_families`、`test_method_families.py`、真实 `transit_calc.py` 入口，以及 Swift request/model/export 调用。
- [x] 旧代码红测：`solar_arc_rate_deg_per_year=0` 被 `or 1.0` 转成 1；`include_experimental_profiles="false"` 被 `bool()` 当真；覆盖缺省值、0、JSON true/false、布尔假数值、NaN/Inf/非法字符串拒绝与入口结构化错误。旧版聚焦测试 15 failed / 6 passed，失败均落在上述缺陷断言。
- [x] 最小实现：在现有 API 校验器复用 `_is_finite_number`，可选 rate 缺失沿用 1°/年、显式有限数（含 0）保留、其他类型/非有限拒绝；实验开关仅在缺失时默认 true，提供时必须为 JSON boolean；计算函数停止 `or` 和 `bool()` 归一化。错误继续返回既有 `mode/error/invalid` 结构。
- [x] 同形风险审查：`solar_arc` 独立模式也有同样的 `or 1.0` rate 表达式，但 W03 来源归属只含 `method_families`。已确认它是分离的 mode handler，Swift `SolarArcRequest` 无该 rate 字段；method_families 通过 `ExpansionGenericRequest` 发送，未发现共享字段契约，故将 solar_arc 留为独立跟进项，不在本分支扩修。
- [x] 检查 Swift generic method_families 请求、Codable/result/导出契约；无 request/result shape 变化，不改 Codable / fixture。
- [x] 每次代码改动更新 `CHANGELOG.md`；聚焦与相关 Python 测试 57 项通过，完整 `bash check_vibe_changes.sh` 通过（Python 1109 项，Swift build，Swift 227 项/31 suites，43 个实时请求解码）；清理本任务构建缓存。
- [x] 审阅完整 diff/status，完成一个本地逻辑提交；不 push、不开 PR、不打包。

边界：计划指定不自创 rate 数值范围。对错误输入通过当前 validator 的 `invalid` 字段可观察拒绝，而不是让 mode handler 崩溃或静默回退。

# R-P1-2 / W02 证据化关闭（2026-09-23）

状态：已完成；本任务仅纠正审查/计划文档，不改业务代码、测试、fixture 或 schema。

- [x] 核对当前 `codex/bugfix-plan-v2` 分支、工作区状态及项目规则。
- [x] 检查 `_display_zone` 全部调用点与 `calculate_declination_timing` 生产时区解析路径。
- [x] 对 `Examples/sample-declination-timing-request.json` 分别以 GMT+8、UTC 运行真实 `transit_calc.py` 入口，对比事件数、UTC 精确时刻与当地时刻。
- [x] 修订 v2 的 EV-04、R-P1-2 来源登记、W02 任务卡和执行顺序；在原审查报告 P1-2 后追加仲裁说明，保留历史正文。
- [x] 更新 CHANGELOG 与本文完成记录；核对 87 个来源 ID、18 个工作包、Markdown 链接/编号/围栏和完整 diff。
- [x] 提交一个本地 docs 逻辑提交；不推送。

证据摘要：`_display_zone` 只有定义，没有生产调用。生产函数先尝试 `ZoneInfo(display_timezone)`，再由 `resolve_timezone` 解析固定偏移。真实入口 GMT+8 / UTC 均返回 262 个事件；首事件 `exact_utc` 均为 `2026-01-02T08:10:49.525Z`，`exact_local` 分别为 `2026-01-02T16:10:49.525+08:00` 与 `2026-01-02T08:10:49.525+00:00`。结论：R-P1-2 是生产误报，关闭为已证明非缺陷；未调用 helper 的局部错误不构成 P1，也不作为 P1 修复项。

# 后端缺陷修复总体计划（2026-09-22）

状态：**计划已产出，未开始修复**。授权范围：汇总 `docs/` 内全部 bug/审查文档待修项并写出可执行修复计划；本轮**不修改任何业务代码**。详细计划：`docs/bugfix-master-plan-20260922.md`。

- [x] 通读 `docs/backend-calculation-review-20260908.md`、`docs/backend-calculation-bug-scan-20260826.md`、`docs/horary-remaining-fixes.md`、`docs/calculation-audit-repair-spec.md`、`docs/current-status.md`、`docs/horary-audit-2026-07-10.md`、`docs/horary-fix-guide-2026-07-11.md`。
- [x] 对照源码核验关键位置（`EGYPTIAN_BOUNDS`、`_display_zone`、composite 重建、Hayz、PD 单方向、orbital_dial modulus、method_families `or 1.0`/`bool()`、Krittika、patterns kite/去重、horary 速度缺失、Frustration 速度约束、declination_parallels 半球、旧扫描 11 项等）。
- [x] 状态分流：已关闭/误报/待修复/需口径决策；产出批次 A–G 任务卡（修法、影响面、测试、fixture、风险）。
- [x] 写出 PR 切分、影响面总表、验证门禁与剩余风险登记。
- [ ] 批次 A（2 项 P1）——待授权开工。
- [ ] 批次 B/C/D（P2）——待授权开工。
- [ ] 批次 E/F（P3）——待授权开工。
- [ ] 批次 G（口径决策）——待人类确认。

## 计划摘要

- **P1 来源线索 2 项**：埃及界 Aries 误用托勒密数值仍待独立来源复核（`astro_backend_classical_dignity.py:57`，对应 W01）；R-P1-2 已通过真实生产入口证明为误报并关闭（未调用的 `_display_zone` helper 局部返回 UTC，不影响 `*_local` 输出）。来源登记仍保留两条以维持可追溯性，当前待修 P1 为 1 项。
- **P2 27 项**（新 16 + 旧 11，去重后）：composite ASC/宫头不一致、Mercury Hayz、PD converse 缺失、orbital_dial modulus、Krittika 译名、Shadbala Jupiter+15/Drik=0、method_families 参数吞噬、horary 速度缺失判离相、station 采样过稀、mundane 无 orb 阈值与 count 矛盾、body 中文名两套、阈值不统一、Frustration 速度约束、declination_parallels 半球、恒星 ARMC flag、hellenistic 证据行恒空、出生瞬间当返照、Yogini 起算、upagraha 占位、approaching_sun 反转、mundane 日时主键名、scan 入离相、Kite 标签、图形去重、Davison 大圆中点。
- **P3 约 54 项**（新 30 + 旧 24）：按输入校验/时间精度/契约静默/horary 语义四组分批。
- **误报 4 项不修**；**已关闭** SAV-337、horary A–J、13 项 audit；**8 项 DECISION_REQUIRED**（PTOLEMAIC_BOUNDS 版本、Shadbala 完整度、PD 双向、moiety orb、年长常数、upagraha 方案、Frustration 变体/事件 id/morning_evening、composite ASC/MC 权威）。
- 执行纪律：先失败测试→最小修复→模块回归；每批独立分支 + CHANGELOG；JSON 形状变更必须同步 Swift 模型/导出/fixture + LiveBackendContractTests；收尾 `bash check_vibe_changes.sh`。

---

# 后端计算代码整体审查（2026-09-08）

状态：完成（只读审查，未改业务代码）。授权范围：`Sources/TransitStudio/Resources/backend/` 全部 61 个 Python 模块（约 31.7k 行），目标找出真实计算 bug，每条给文件:行号与可复现验证。详细报告：`docs/backend-calculation-review-20260908.md`。

- [x] 分组派出 sub agent 深读全部后端模块（12 组：core/classical×2/modern×2/vedic/horary×2/rectify-scan/techniques/api/跨模块一致性）。
- [x] 汇总疑似 bug 清单，逐条在主会话复现验证（pytest 基线 1091 passed + pyswisseph 数值对拍 + 权威资料核对）。
- [x] 输出分级结论并更新本文件状态。

## 结论摘要

基线 `pytest` 1091 passed；核心行星数据、ASC/MC、6 种宫位制、prenatal syzygy、solar return 求解均与 pyswisseph 独立对拍一致。新发现 **2 项 P1**、约 16 项 P2、约 20 项 P3，并确认 2026-08-26 旧扫描文档 11 项仍未修复；仲裁 2 项误报。

- **P1 埃及界 Aries 用了托勒密数值**（`astro_backend_classical_dignity.py:57`）：Aries 12–14°/20–21°/25–26° 界主判错，波及 bound/score/almuten/circumambulations 等全部 Egyptian 口径输出；`test_classical.py:100-105` 固化了错误值；其余 11 星座与 Tetrabiblos I.21 逐界一致。
- **P1 declination_timing 固定偏移时区被静默改成 UTC**（`astro_backend_declination_timing.py:199-205`）：`display_timezone="GMT+8"` 时所有 `*_local` 输出 UTC。
- P2 新发现：composite 非等宫制 ASC 轴与宫头不一致（实测差 18.8°）、Mercury Hayz 判定失效、primary_directions 非合相只取单方向、orbital_dial 忽略 modulus、Krittika 中文名错、Shadbala Jupiter +15/Drik 恒 0、method_families `or 1.0`/`bool()`、horary v2 速度缺失判 separating、mundane 无 orb 阈值、body 中文名两套、orb/阈值跨模块不统一等。
- horary 补审（首轮 `horary.py` 1–1000 行等缺口已补齐）：新增 P2 Frustration 第三方速度约束导致漏报（`horary.py:1483`）、`declination_parallels` 未校验同半球致双判/异号误判（`horary_v2_modules.py:906-947`），另有 10 项 P3；`lot_ruler_condition` 经复核实为误报。
- 误报仲裁：`armc_from_mc` 实为精确（MC 黄纬=0，与 swe ARMC 差 6e-14）；scan 无进度与 Swift 端一致（`BackendClient.scan` 不传回调）。
- 旧项复核仍未修复：hellenistic applying/separating 恒 0 行、Yogini 起算、approaching_sun 反转、scan 相位标签、patterns Kite、Davison 中点、visibility fallback 互换等（详见报告第二节）。

# 前端与桥接层问题审查（2026-09-08）

状态：完成（只读审查，未改业务代码）。授权范围：遍历 SwiftUI 前端与 Swift↔Python 桥接代码，找出真实问题并给出文件:行号证据。

- [x] 审查桥接层（进程调用、进度解析、超时/取消）。
- [x] 审查运行流程与状态管理（CalculationViewModel、RunActions、RunGeneration）。
- [x] 审查 AI 流式链路（SSE、节流、取消）。
- [x] 审查结果面板 tab 契约、请求/响应编解码与导出。
- [x] 汇总分级问题清单并更新本文件状态。

## 结论摘要

桥接契约本身健康：stderr 进度 JSONL 前后端格式一致（`astro_backend_rectify.py:382`、`astro_backend_modern_timing.py:1228`、`astro_backend_rectify_evidence.py:495` ↔ `BackendProgressBuffer.swift`）；scan 工作量阈值前后端一致（`ScanWorkEstimator.swift:4-6` ↔ `astro_backend_scan.py:38-40`）；30 个结果面板的 tab id 全部有渲染路径（8 个主 tab 靠 `default:` 兜底，行为正确）。发现的问题集中在状态清理、AI 流生命周期与固定超时：

- P1 切到吠陀时 Horary/生时矫正页面残留（`ClassicalWorkspace.swift:120-126` 缺重置，vedic rail 无对应按钮 `AppNavigationRail.swift:143-148`；`ClassicalWorkspaceTests.swift:183` 只覆盖 clamp）。
- P1 AI 流式分析无取消路径（`LLMAnalysisClient.swift:94-122` 非结构化 Task + 未处理 onTermination；`AIAnalysisView.swift:80-86` 无停止按钮）。
- P2 `analyze` 无并发防护 + `AIStreamBuffer.append` 不校验 activeKey，并发会串流（`ContentView+AI.swift:141-149`、`AIAnalysisViewModel.swift:41-56`）。
- P2 `RectifyClient` 在 terminationHandler 读 stderr 可能不完整（`RectifyClient.swift:54-71`，对比 `BackendClient.swift:376-388`）。
- P2 固定超时无进度续期：rectify 60s（`RectifyClient.swift:4`）、通用 300s（`BackendClient.swift:412-419`）。
- P3 `finishProgress` 延迟清理无代际检查（`ContentView+Progress.swift:37-43`）；`runModernTiming` 回调中 `!Task.isCancelled` 恒真（`ContentView+RunActions.swift:1458`）；`terminatedByTimeout` 无锁读（`BackendClient.swift:150/438`）；expansion 运行未走 `prepareAsteroidsIfNeeded`（8 处）。

验证：`swift build --disable-sandbox` 通过（35.50s）；tab 契约用一次性脚本核对（脚本在 /tmp，未入库）。未运行 `swift test` / `pytest`。

# 当前版本收尾与实时解码契约修复（2026-09-06）

状态：完成，已发布到本机。授权范围：整理当前未提交分支与待办文档，审查并收口已有计算修复，复现/修复后端真实 JSON 与前端解码不一致，完成验证、逻辑提交、主线收口及必要的版本发布清理。架构重设计仅整理状态，不按草案实施大规模重构。

当前改动分类：古典计算修复、现代计算修复、吠陀计算修复、架构提案/评审、后续计算审计清单和历史工作记录。先保留所有已有内容，依据源码与测试审查后分别提交。

- [x] 盘点完整差异、分支拓扑、文档与验证工具；建立真实后端输出解码基线。
- [x] 审查已有计算改动并完成基线验证；提交阶段按古典、现代、吠陀整理。
- [x] 修复 JSON 契约漂移，加入可重复运行的真实输出→Swift 解码检查，核对展示与导出。
- [x] 整理文档权威入口与已完成/待实施状态，保留后续提案和审计证据。
- [x] 完整验证与差异复核，核实最终源码差异与测试结果。
- [x] 单一逻辑提交并整合远端主线；已打包安装 `1.5.2 (51)` 到 `/Applications/TransitStudio.app`，并清理本轮构建、测试和封装缓存。

## 已取得的证据

- 未修复基线：Python 1088 / Swift 223 全绿，新增实时测试复现太阳弧 null speed 解码失败，其余 42 个样例可解码。
- 太阳弧修复后：43 个实时样例均可解码；日速度与年推运率分别保留，CSV/Markdown/JSON 专项回归补齐。
- SAV 独立回归先确认三组输入总分错误为 386，再修复七曜汇总为 337；相关吠陀测试 231 项通过。
- 完整验证：Python 1091 项通过（本轮复跑）；Swift 227 项、31 个 suite 通过；其中实时后端→Swift 解码样例 43 个全部通过；`git diff --check` 通过。本轮复跑 Swift 时被沙盒拒绝写入 `~/.cache/clang/ModuleCache`，属于环境权限限制；不改变此前成功的完整 Swift 结果。
- 远端主线的 `VIBE_WORKFLOW.md` 更新已无冲突整合。
- 本轮之前的任务记录移至 docs/archive/plans-through-2026-09-06.md；后续设计和审计状态见 docs/current-status.md。
- 已验证安装包 `CFBundleShortVersionString=1.5.2`、`CFBundleVersion=51`；清理 `.build`、`/private/tmp/astrotransit-package-build`、封装暂存目录及测试 scratch，保留 `dist/TransitStudio.app`。


# 修复总计划编写模型能力评价（2026-09-22）

状态：完成。范围：阅读指定计划，抽查接口与方案自洽性，在聊天中评价作者体现的能力；不执行修复。现有未提交变更属于此前审查与计划任务，保留。

- [x] 阅读项目规范与指定计划全文。
- [x] 抽查关键修法、验证设计与任务覆盖：本机 houses_armc 不接受 flags；用现有函数验证 C-1 两相位分支可同号；源报告 P2-j 未获独立任务卡。
- [x] 完成能力评价：组织与工程流程较强，接口核验、数学约束和完整性收口不足；结论交付聊天。


# 修复总计划 v2（2026-09-22）

状态：完成（文档交付，业务修复未开始）。授权范围：保留原版，新建更完善的修复计划；核对全部来源条目、技术方案、决策依赖与验收条件，不实施业务修复。现有 CHANGELOG/PLANS 与两份未跟踪文档属于此前审查任务，保持原样；本任务仅追加记录并新增 v2 文档。

- [x] 通读来源、项目验证及已关闭边界，建立 87 条来源登记（包含候选与可能误报，不代表 87 个确认缺陷）。
- [x] 核验 houses_armc、PD 同号反例、时区、27 宿/Yogini、mundane facts-only、schema 与发布资源，记录 12 条证据。
- [x] 新建 docs/bugfix-master-plan-20260922-v2.md，登记 18 个工作包、14 个决策议题，补充独立验收与完整包发布要求。
- [x] 校验 87 个唯一来源 ID、单一工作包归属、18 个包/14 个决策引用、本地链接、真实测试与 Swift 文件名、代码围栏及 diff；未跑全量业务测试或构建。

# 修复总计划 v2 工作路线分析（2026-09-23）

状态：完成（路线分析）。范围：通读 v2 文档，对照项目现状与依赖关系，给出分阶段执行路线；本轮不修改业务代码。

- [x] 阅读 v2 全文，核对 18 个工作包、14 个决策议题和验证门禁。
- [x] 对照当前工作区与 P1、输入校验、mundane 事实字段和完整门禁脚本，整理可立即开工、待决策和发布收口的顺序。
- [x] 在聊天中交付路线与主要风险；未运行测试或构建，未声称业务缺陷已修复。

# 当前分支文档收尾与验证（2026-09-23）

状态：完成本地收尾。范围：把当前 `codex/bugfix-plan-v2` 的既有审查和计划文档按任务边界提交，验证整条分支并清理本轮缓存；未实施计划中的业务修复或重新打包应用。

- [x] 核对分支与远端基线；将后端/前端审查、原版计划、v2 修订分别提交，原版增加历史版本提示。
- [x] 核验 v2 的 87 个唯一来源 ID、18 个工作包、14 个决策、本地链接及代码围栏；`git diff --check` 通过。
- [x] 完整门禁通过：Python 1091 项、Swift 227 项（31 个 suite），其中 43 个 Examples 实时后端解码样例通过。
- [x] 清理 `/private/tmp/astrotransit-bugfix-plan-v2-validation-20260923` 构建缓存。

# W01/W03/W04 集成与最终审查收尾（2026-09-24）

状态：集成实现、完整验证及远端 main 同步完成。范围为四个已完成的独立修复分支、W03 极值输入返回结构化错误、W01 沿界真实输出夹具迁移，以及合并后的完整验证与 main 同步；不扩展到 v2 其他工作包。

- [x] 阅读项目规则，确认工作区干净、远端 main 与计划分支关系，并核对四个待集成提交及审查发现。
- [x] 按 W01、W03、Mercury Hayz、Hellenistic 相位顺序保留逻辑提交，解决 `PLANS.md` / `CHANGELOG.md` 合并冲突；代码与测试均保留，W01 历史记录末尾的重复 W02 标题已清理。
- [x] W03 极值红测复现巨大整数转换异常、有限 rate 乘实际年龄溢出；修复后经现有 `invalid` 协议返回结构化错误，零年龄仍接受有限极值，`test_method_families.py` 24 项通过。
- [x] 用真实后端请求重建 distributions PD 夹具；旧夹具在新增的 Swift 20° 边界断言下失败，重建后该契约测试通过。生产 packet 同时保留 `periods` 与兼容 `boundaries`，既有 Swift 消费者可继续解码。
- [x] 检查完整集成 diff、运行聚焦回归和 `bash check_vibe_changes.sh`；集成门禁通过（Python 1149、Swift 227/31 组、43 个实时样例），真实沿界夹具与当前后端输出逐字节一致，清理本任务构建缓存。
- [x] 推送经验证的集成结果；将本地 main 同步至最新 origin/main 后合入并推送，确认无 ahead/behind，最后切回 clean 的 main。

# R-P1-1 / W01 Egyptian Aries 界表（2026-09-23）

状态：实现、验证、完整 diff 审阅及本地逻辑提交均已完成。仅将 `EGYPTIAN_BOUNDS` 的 Aries 条目改为独立原典确认值，保持 `PTOLEMAIC_BOUNDS` 和其他 11 个星座不变。

- [x] 确认 W02 文档提交 `2298535` 已同步，工作区干净；创建独立分支 `codex/fix-egyptian-aries-bounds`。
- [x] 核验原典转录：[Ptolemy, Tetrabiblos, Book I §20, “Of the Disposition of Terms”](https://penelope.uchicago.edu/thayer/e/roman/texts/ptolemy/tetrabiblos/1b%2A.html)，“Terms according to the Egyptians” Aries 行为 ♃6 ♀6 ☿8 ♂5 ♄5（累计上界 6/12/20/25/30）；紧接 §21 为 “According to the Chaldaeans”，不是本次 Egyptian 表。项目另有独立 `PTOLEMAIC_BOUNDS` 字典，本任务不改。
- [x] 在旧代码上增加并运行独立期望测试：Aries 三个变化边界的前/值/后，0°、30°/下个星座起点与 360° 归一化，Ptolemaic 独立护栏；旧代码在 12°、20°、25° 三个边界失败（`3 failed, 9 passed`）。
- [x] 最小改表后，核对 bounds → dignity score/ownership → almuten、circumambulations 与 audit 调用路径；增加 Mars 在 20.5° Aries 得 7 分（含界主 +2）及 almuten ASC.bound 贡献测试，并复核 `test_classical.py` 中旧 14°、26° expectation。
- [x] 对比同一个 `Examples/sample-distributions-pd-request.json` 真实请求：ASC=17.616017304° 的 Egyptian Mercury 当前 period 旧表结束 21°、新表结束 20°。静态 `distributions-pd-result.json` 确含受影响的旧 14–21°值，但 JSON 结构已落后当前生产输出（旧 `boundaries` 与现行 `periods` 及其他历史差异）；为避免 W01 顺带改写无关结构，保留该历史快照，以新增真实计算断言覆盖现行 20°边界，并记录后续独立 fixture 迁移需要。
- [x] 检查 Swift `DistributionsPdModels` / classical Codable 模型、沿界范围 UI、Markdown/CSV 导出和相关 fixture/live contract tests；JSON 形状不变，无 Swift 模型或导出修改。
- [x] 更新 `CHANGELOG.md`；相关 6 个 Python 模块 149 项通过、classical 模块 101 项通过；`bash check_vibe_changes.sh` 全门禁通过（Python 1108 项、Swift 227 项 / 31 suites、43 个 Examples live backend → Swift 解码样例）。
- [x] 清理本任务专用 SwiftPM scratch `/private/tmp/astrotransit-w01-validation-20260923`；没有生成项目内 Swift build 产物。
- [x] 审阅完整 `git diff`、`git status` 与 diff stat；仅有本任务的 5 个文件，`git diff --check` 通过；完成一个本地逻辑提交，不 push、不开 PR、不打包。

原典依据：LacusCurtius 所载 Loeb/Robbins 1940 转录，Book I §20 标题及 Egyptian terms 表，页面行 127、135–149；Aries 行直接列出五个分配度数，合计 30°。§21 才进入 Chaldaean method。代码映射为各条目 exclusive upper degree，因此预计 Egyptian Aries 列表为 `JUPITER 6, VENUS 12, MERCURY 20, MARS 25, SATURN 30`。
