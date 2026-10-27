# 当前版本与后续工作

更新：2026-10-27。

此页汇总收尾时的交付边界。源码与测试是实现依据；历史验证和实施计划分别见 [PLANS](../PLANS.md)、[CHANGELOG](../CHANGELOG.md)。

## 已有成果

| 任务 | 当前边界 | 入口 |
|---|---|---|
| Horary 生产管线 | 默认 V3，侧栏可选 V2.1；V1 显式兼容 | [V3 文档](horary-v3.md) |
| Horary V3.0.1 | 独立自包含 Python 模块与 8 项测试；未接入 App/API 路由 | [模块](../Sources/TransitStudio/Resources/backend/astro_backend_horary_v3_0_1.py)、[测试](../python_tests/test_horary_v3_0_1.py) |
| 当前位置 | 持续定位、超时与请求隔离已实现；真实新鲜坐标仍待确认 | [实现](../Sources/TransitStudio/CurrentLocationManager.swift)、[测试](../SwiftTests/CurrentLocationManagerTests.swift) |
| 功能规格 | README 记录应用功能与重写基线 | [README](../README.md) |
| 汉堡核心/CLI | 独立 HamburgCore 与 hamburg CLI、33 项核心测试；存在下列审查问题 | [说明](hamburg-astrology.md)、[样例](../HamburgExamples/sample-hamburg-request.json) |
| 汉堡 App 接入 | 方案完成，尚未实施 | [接入方案](hamburg-integration-plan.md) |
| 风筝标签 | 已有修复区分 1 个冲相、2 个六合；JSON 结构保持不变 | [实现](../Sources/TransitStudio/Resources/backend/astro_backend_patterns.py)、[测试](../python_tests/test_patterns.py) |

当前打包脚本与 `/Applications/TransitStudio.app` 安装版均为 **1.6.2 (55)**（本轮读取 Info.plist 核对）。整理阶段完成后，已按用户追加授权推送并快进合入 main（实现合并点 e1508e2）；同步核验见 [PLANS](../PLANS.md) 顶部记录。本次不重新打包或安装。

## 汉堡已确认问题

以下来自 2026-10-26 代码审查记录，收尾时再次核对了对应实现。它们尚未修复；33 项核心测试通过不覆盖这些反例。处理完毕后，再推进 App 接入。

| ID | 问题与代码位置 | 后续修复验收 |
|---|---|---|
| H01 | `TransneptunianEphemeris.geocentricPosition` 在 t−0.5 与 t+0.5 日复用同一个太阳参考，速度未包含太阳参考随日期的变化。位置参考测试未验证该速度。[源码](../Sources/HamburgCore/Transneptunian.swift) | 用随采样日期变化的地心太阳参考求速度；对不同日期、顺逆行状态和传入/回退太阳参考增加独立差分对照。 |
| H02 | CLI 同时接收 moment 与 julian_day_ut，标准行星按 moment 读取，而 TNP 可沿用用户 JD，形成混合时刻。[源码](../Sources/HamburgCLI/main.swift) | 明确双输入一致性规则；不一致请求须拒绝或统一到同一时刻，并验证标准行星、TNP、meta 一致。 |
| H03 | `Moment.date` 未读取 fold；CLI reference 的 DST 重复时间可能取错一次，影响参考时刻与太阳弧。[源码](../Sources/HamburgCore/Moment.swift) | 以明确 UTC 期望验证 fold=0/1 的 DST 重复小时，并保持不存在时间拒绝逻辑。 |
| H04 | 中点命中只对 axis.direct 调用 proximity；360° dial 无法覆盖 opposite 的 180° 对向分支。太阳弧/映点中点路径同样调用此逻辑。[引擎](../Sources/HamburgCore/HamburgEngine.swift)、[几何](../Sources/HamburgCore/Options.swift) | 360° dial 验证 direct/opposite 两支及去重，覆盖树、太阳弧与映点；保持 90°/180° dial 既有折叠行为。 |
| H05 | Python 桥接先读尽 stdout，再读 stderr；stderr 填满管道时子进程可能无法退出，父进程持续等待 stdout EOF。[源码](../Sources/HamburgCLI/PythonBackend.swift) | 同时排空两路输出；用超出管道容量的 stderr 探针验证成功/失败退出均可完成。 |

## 其他待办

- **真实定位确认**：先前系统仅返回过期位置，用户计划连接 Wi-Fi 后重试。自动回归已验证生命周期逻辑，但不能替代实机获得最近 60 秒、精度不超过 1000 米的坐标。本轮不修改系统网络或权限。
- **扫描优化**：已有请求内缓存与语言选型分析，尚未实施生产重写。详见 PLANS 中 2026-10-19 记录。
- **汉堡接入**：未来按 [接入方案](hamburg-integration-plan.md) 冻结契约并分阶段实施；目前 App 没有汉堡导航入口。

## 本轮验证

- `bash check_vibe_changes.sh`：Python 1232 项、Swift build、267 项测试 / 38 suites、44 个 Examples 实时后端解码全部通过。
- 独立汉堡 CLI：JSON、Markdown、`--no-python` 点集模式均实际运行；标准样例返回 22 点、8 个 TNP、116 幅图像、5 棵树，无 warnings。
- 初次复用旧 `.build` 时链接器报对象文件在构建期间被修改；随后使用本轮独立临时目录从头构建，完整门禁通过。
- Markdown 代码围栏、本地文件链接、差异格式及任务提交边界已检查。
- 构建/缓存合计清理 1015.62 MiB（含本轮验证临时产物），项目 `.build` 剩余 4 KiB。
- 六项既有成果与收尾文档已保存为七个逻辑提交；`codex/project-closeout-20261027` 已推送并快进合入远端 main，现工作分支为 main。同步记录追加在主线，最终核验见 PLANS 顶部记录。

## 日常验证与清理

执行 `bash check_vibe_changes.sh` 完成 Python 全量、Swift 构建/测试及 Examples 实时后端解码，再检查完整差异。构建后使用 `swift package clean` 清理可重建产物；保留 `.venv`、星历、测试夹具、`dist/` 发布包及本地参考资料。

## 2026-09-24 版本快照

当时安装版为 1.5.3 (52)；bug fix v2 的完成项与待办项以 [修复计划 v2](bugfix-master-plan-20260922-v2.md) 为准。以下快照保留历史状态，不能当作当前进行中列表。

## 2026-09-07 收尾快照

- 当前执行计划：[PLANS.md](../PLANS.md)。
- 未提交的既有 13 项计算修复按古典、现代、吠陀分别审查收口；它们与后续架构迁移是不同任务。
- 太阳弧 JSON 解码：后端 speed=null 表示不适用，Swift 原先强制 Double 导致整包失败；本轮修复并将年度推运率单列展示/导出。
- 验证缺口：旧的 Python 单测、Swift 静态 fixture 和只检查退出码的 smoke 不能证明前后端实时一致。本轮增加 LiveBackendContractTests，并纳入本地完整门禁与 CI。
- SAV 七曜汇总：P1-1 已独立复现，修复前总分 386，修复后 337；ASC 的单独 BAV 保留。
- 已完成发布前收口：Python 1091 项、Swift 227 项（31 个 suite）及 43 个实时后端→Swift 解码样例均已通过，`git diff --check` 通过。远端主线已整合，`TransitStudio 1.5.2 (51)` 已签名并安装到 `/Applications/TransitStudio.app`；构建、测试和封装缓存已清理。

## 2026-09-07 文档归属快照

| 材料 | 当前用途 | 后续动作 |
|---|---|---|
| [13 项计算修复规范](calculation-audit-repair-spec.md) | 已实施修复的历史依据 | 查代码/测试，不重跑全部任务 |
| [2026-08-26 计算审计](backend-calculation-bug-scan-20260826.md) | 后续缺陷候选与复现线索 | 依据当前源码逐项复核；P1-1 已关闭，其余 35 个编号待处理 |
| [架构方案](architecture-redesign.md) + [评审](architecture-redesign-review.md) | 尚未实施的后续设计 | 先处理评审阻断，再单独开迁移任务；不直接将原稿当施工规格 |
| [历史任务计划](archive/plans-through-2026-09-06.md) | 过去任务、口径和验证记录 | 查询历史，不作为当前进行中清单 |
| [验证说明](validation.md) | 当前可执行检查 | 门禁必须包含实时后端→Swift 解码 |
| 其他带日期的 roadmap、handoff、audit | 当时的设计/审查快照 | 与源码核实后使用，不默认全部待做或全部已做 |

## 2026-09-07 计算审计候选快照

以下保持原报告编号，未在本轮声称修复；部分涉及传统口径或产品选择，需要先复核判定依据。

- P2-1～P2-11：恒星黄道 ARMC、Hellenistic 相位证据、返照起点、Yogini、特殊点/Upagraha、Horary 日近方向、择时日时主字段、扫描入离相、Kite 与多实例格局、Davison 地理中点。
- P3-1～P3-5：输入校验、未知天体、迁移时区、parans 异常、返照缺失告警。
- P3-6～P3-11：赤纬边界、宿边界、闰日截断、大运秒精度、年长口径、DST 排序。
- P3-12～P3-24：宫位/尊贵标签、失败兜底污染、特殊点/恒星/格局定义、会合标签、谐波边界、对置中点、矫正 DST、日出约定及其他细项。

建议先做“输入与时间边界”“确定的字段/公式错误”“传统口径与算法决策”三批；每批单独分支、先复现、修复后同步模型/导出/fixture。JSON 可解码只证明结构兼容，不替代这些数值与规则审计。
