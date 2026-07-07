# PLANS

按 `AGENTS.md` 约定：开始任务前在此写计划，执行中更新状态；已完结的历史任务批次归档到 `docs/archive/`（如 `plans-frontend-refactor-2026-06.md`）。

---

# 前端重设计 2026-07（观星台布局 + Dark Mode）— 进行中（2026-07-07）

## 分支
`codex/frontend-redesign-2026-07`（任务书在 `main` 上，施工在该分支）

## 用户确认的范围
- 重点：古典排盘、Horary、行运扫描；吠陀只保证不回归，不做新视图。
- 配色：羊皮纸保留为浅色主题，深空夜色做成 Dark Mode（程序设置可选 跟随系统/浅色/深色）。

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 设计方案与用户确认 | ✅ | 布局：档案胶囊+流派+运行按钮上顶栏、参数抽屉自动收起、结果区垂直目录、扫描时间轴、AI 侧滑 |
| 02 任务书 00/01/02 + 交接提示词 | ✅ | `docs/frontend-redesign-2026-07/`（00 总览、01 Dark Mode、02 顶栏布局、HANDOFF_PROMPT） |
| 03 第 1 期施工（Dark Mode，1.2.0/36） | ✅ | 施工完成，等待验收。门禁 check_vibe_changes.sh 全绿，版本 1.2.0/36 |
| 04 第 1 期验收 | ⬜ | 评审模型 diff 验收 + DoD 核对 |
| 05 第 2 期施工（顶栏布局，1.2.1/37） | ⬜ | 执行 Agent 按 02 任务书施工 |
| 06 第 2 期验收 | ⬜ | 验收后补写 03（结果区垂直目录）任务书 |
| 07 第 3–5 期（垂直目录/扫描时间轴/AI 侧滑） | ⬜ | 任务书随前期落定逐期补写 |

---

# 代码审计续查 — 已完成（2026-07-06）

## 分支
`codex/fix-modern-timebased-contract`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 核对规则与当前改动边界 | ✅ | 已读取 `AGENTS.md`；当前仅有上一轮文档改动 |
| 02 复查现代时基模式请求契约 | ✅ | 已确认 progression / solar_arc / harmonic UI 请求不传顶层 zodiac/house_system，后端忽略 birth 内设置 |
| 03 扫描结果页 tab / section_errors 风险 | ✅ | 已确认 tab case 基本对应；现代高级诊断页多为 Raw JSON，harmonic 无诊断页 |
| 04 扫描后端 silent fallback 高风险点 | ✅ | 已记录 silent fallback 审计策略，并补充次限整点出生误报 warning |
| 05 输出代码审计结论 | ✅ | 已更新审计文档，并将在本轮回复按严重度列 findings、复现依据、建议验证 |
| 06 修复并补回归 | ✅ | 已修现代时基请求契约、次限整点 warning、现代诊断页，并补 Python/Swift 回归 |
| 07 验证与打包覆盖 | ✅ | Python 492、Swift 27、一键门禁通过；已打包覆盖 `/Applications` 为 `1.1.13 (33)`，签名/无 pyc/安装后端 smoke 通过 |

---

# 文档整理与技术债审计 — 已完成（2026-07-06）

## 分支
`main`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 核对项目规则与仓库状态 | ✅ | 已读取 `AGENTS.md`；当前 `main` 领先 `origin/main` 15 个提交 |
| 02 梳理文档目录与源/生成边界 | ✅ | 已扫描 tracked 文件、source-of-truth、生成产物与历史文档 |
| 03 汇总技术债与历史遗留 bug | ✅ | 已汇总文档已知债务、历史 bug 主题、占位实现与契约风险 |
| 04 记录潜在未发现 bug 风险 | ✅ | 已记录异常吞噬、占位实现、schema 漂移、测试空白与现代时基模式契约风险 |
| 05 补全文档与下一步建议 | ✅ | 已更新 docs/README 与 validation，新增 `docs/project-audit-2026-07-06.md` 并记录演进路线 |

---

# main 合并后打包覆盖 /Applications — 已完成（2026-07-02）

## 分支
`main`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 核对当前状态 | ✅ | 工作区干净；`package_app.sh` 版本为 `1.1.12 (32)` |
| 02 执行打包覆盖 | ✅ | 已运行 `./package_app.sh`，覆盖 `/Applications/TransitStudio.app` |
| 03 验证安装产物 | ✅ | 安装版 `1.1.12 (32)`；codesign 通过；无 `.pyc`/`__pycache__`；AppIcon 与仓库文件一致；classical smoke 通过 |

---

# 合并 expansion-002 与 Claude 图标优化入 main — 已完成（2026-07-02）

## 分支
- 当前分支：`codex/expansion-002`
- 额外合并分支：`claude/confident-leavitt-08051a`
- 目标分支：`main`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 核对分支与工作区 | ✅ | 当前工作区干净；`main` 在 `4aa7b68`，两个待合并分支均存在 |
| 02 预判冲突面 | ✅ | 已确认 `CHANGELOG.md`、`PLANS.md`、`package_app.sh` 会在第二次合并时需要重点核对 |
| 03 合并当前分支到 main | ✅ | `main` 已快进合并 `codex/expansion-002`，包含本地计划提交 `9ec9d80` |
| 04 合并 Claude 分支到 main | ✅ | 已保留最新版本号 `1.1.12 (32)`，并叠加 AppIcon 预生成优化 |
| 05 验证结果 | ✅ | `PATH=/usr/local/bin:$PATH bash check_vibe_changes.sh` 通过：486 Python、Swift build/test、5 个 smoke |

---

# 打包脚本图标预生成 — 已完成（2026-07-02）

## 分支

`claude/confident-leavitt-08051a`（worktree）

## 背景

`package_app.sh` 每次打包都用纯 Python 逐像素重新生成 10 张完全相同的 PNG（最大 1024×1024，纯 CPython 需 1–2 分钟），且依赖 PATH 上的 python3。曾导致外部修复 Agent 在此步骤卡死超时（iconset 目录为空）。

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 一次性生成 AppIcon.icns 并提交到 `assets/` | ✅ | 用现有生成逻辑产出，`iconutil` 打包为 icns |
| 02 `package_app.sh` 优先拷贝已提交的 icns | ✅ | 仅当 `assets/AppIcon.icns` 缺失时回退到原生成逻辑 |
| 03 `SKIP_INSTALL=1 ./package_app.sh` 验证产物 | ✅ | 确认 app 内 AppIcon.icns 正常且与提交文件一致 |

---

# Expansion 002 代码评审修复（F1-F5）— 已完成（2026-07-02）

## 分支
`codex/expansion-002`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| F1 magistery 公式文本修复 | ✅ | 5 处代码修改 + 2 个回归测试，昼/夜公式文本正确显示 MC |
| F2 lots 容错（KeyError 守卫） | ✅ | 加 warnings 参数 + try/except KeyError + 2 调用方补传 + 4 个回归测试 |
| F3 宫位标签边界守卫 | ✅ | 引入 _HOUSE_LABELS + 守卫式取值 + 3 个回归测试 |
| F4 删除死代码 | ✅ | 删除 4 个函数 + 清理 BODY_REGISTRY import，零回归 |
| F5 fixed_stars 复用 core 工具 | ✅ | import + 2 处替换，恒星测试全绿 |
| 门禁验证 | ✅ | 聚焦 45 通过、全量 Python 486 通过、Swift 24 通过、5 个后端 smoke 通过 |
| 记录与打包 | ✅ | CHANGELOG.md/PLANS.md 已更新，版本号 1.1.12 (32) |

---

# Firdaria 主流算法接轨 — 已完成（2026-07-01）

## 分支
`codex/expansion-002`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 核对主流口径 | ✅ | 已对照本地 Sira Uysal Firdaria PDF：主限昼/夜序列、七曜次限从主限星开始、七等分，交点不拆次限 |
| 02 修正后端算法 | ✅ | `firdaria_sub_periods()` 已改为七曜 7 等分、主限星起始、交点不拆次限 |
| 03 补回归与记录 | ✅ | 已更新 Python 测试、`CHANGELOG.md` 与打包版本 `1.1.11 (31)` |
| 04 验证与打包 | ✅ | 全量 Python、Swift build/test、后端 smokes 均通过；已覆盖 `/Applications/TransitStudio.app` 为 `1.1.11 (31)` |

---

# Expansion 002 Markdown 数据补全与打包覆盖 — 已完成（2026-07-01）

## 分支
`codex/expansion-002`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 确认导出缺口 | ✅ | 已确认后端/Codable 有赤纬、固定星与 medieval 数据，但 Markdown 导出未渲染 |
| 02 补齐 Markdown 渲染 | ✅ | 增加赤纬/OOB、赤纬相位、固定星合相、中世纪深化章节，并修正 packaged ephemeris 默认路径与 pycache 签名污染 |
| 03 补测试与记录 | ✅ | 增加 Markdown 导出与 packaged ephemeris path 回归测试，更新 `CHANGELOG.md` |
| 04 运行验证 | ✅ | pycache 签名污染修复后 `swift test` 与 `check_vibe_changes.sh` 均通过 |
| 05 打包覆盖 `/Applications` | ✅ | 已覆盖 `/Applications/TransitStudio.app`，安装版本 `1.1.10 (30)`；codesign、无 pycache、installed backend smoke 均通过 |

---

# Expansion 002 复查与打包覆盖 — 已完成（2026-07-01）

## 分支
`codex/expansion-002`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 最新提交与工作区核对 | ✅ | 当前 HEAD 为 `85ac41f` 起继续复查，工作区仅本轮计划/修补改动 |
| 02 复查新增修复 | ✅ | 已修固定星名称/warning、cross 赤纬生成、Swift 前缀过滤与 backend 默认 ephemeris path |
| 03 运行本地门禁 | ✅ | focused pytest、全量 pytest、`swift build`、`swift test`、`check_vibe_changes.sh` 均通过 |
| 04 无阻断问题后打包覆盖 | ✅ | `package_app.sh` 版本递增到 `1.1.9 (29)` 并覆盖 `/Applications/TransitStudio.app` |
| 05 记录结果 | ✅ | `CHANGELOG.md` 已记录，安装产物 Info.plist 与 codesign 已验证 |

---

# Expansion 002: 恒星与赤纬 + 中世纪技法深化 — 规划中（2026-07-01）

## 状态
✅ 全部 Phase 已完成（编码 + 测试）

## 计算规范核对修订（2026-07-01）

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 核对联网资料与本地接口 | ✅ | 已确认 Swiss Ephemeris 固定星接口、`FLG_EQUATORIAL`、黄道/赤道转换与 OOB 判定口径 |
| 02 修正文档计算方式 | ✅ | 修正赤纬公式、OOB 示例、固定星调用、恒星合相入相判定与中世纪技法实现边界 |
| 03 复核 diff 与记录 | ✅ | 核对文档差异，补充 CHANGELOG 记录 |

## 分支
`codex/expansion-002`（已完成）

## 执行计划

### Phase 1：恒星与赤纬

| 项目 | 状态 | 说明 |
|------|------|------|
| 1.1 赤纬管线 | ✅ | `calculate_body()` 增加 declination / out_of_bounds 字段 |
| 1.2 平行/反平行 | ✅ | `astro_backend_core.py` 新增 `find_declination_aspects()` |
| 1.3 恒星模块 | ✅ | 新建 `astro_backend_fixed_stars.py`，30 颗恒星合相检测 |
| 1.4 Swift 模型 | ✅ | `PositionRow` 扩展 + `FixedStarConjunction` / `DeclinationAspect` |
| 1.6 测试 | ✅ | 赤纬验算、出界、平行/反平行、恒星合相单元测试已添加 |

### Phase 2：中世纪技法深化

| 项目 | 状态 | 说明 |
|------|------|------|
| 2.1 阿拉伯点扩展 | ✅ | 12 → 56 点 |
| 2.2 三分主星序列 | ✅ | Sect light 三分主星 + ASC 三分主星 |
| 2.3 Kurios / Oikodespotes | ✅ | 综合权重判定盘主星 |
| 2.4 年主+日返融合 | ✅ | 返照 ASC vs 小限 + 年主在返照盘的状态 + 机器摘要 |
| 2.5 月小限增强 | 🔲 | 推迟（前端改动为主） |
| 2.6 界推进深化 | 🔲 | 推迟（前端改动为主） |
| 2.7 测试 | ✅ | 10 个中世纪技法单元测试已添加 |
| 2.2 三分主星序列 | ⬜ | Sect light 三分主星 + ASC 三分主星 |
| 2.3 Kurios / Oikodespotes | ⬜ | 综合权重判定盘主星 |
| 2.4 年主+日返融合 | ⬜ | 返照 ASC vs 小限 + 年主在返照盘的状态 + 机器摘要 |
| 2.5 月小限增强 | ⬜ | 月主条件 + 当月行运触发 |
| 2.6 界推进深化 | ⬜ | 当前界主突出 + 与其他技法交叉标注 |
| 2.7 测试 | ⬜ | 扩展阿拉伯点、三分主星、Kurios、日返融合回归测试 |

## 详细文档
见 `docs/expansion-002/`

---


# 审计确认问题修复 — 已完成（2026-07-01）

## 分支
`codex/fix-audit-bugs`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 建立任务边界 | ✅ | 已切到 `codex/fix-audit-bugs`，忽略无关未跟踪 OCR Markdown |
| 02 修复 P0/P1 计算错误 | ✅ | 已修复关系页映射、Bhava 角点、Primary Directions 纬度、T-square、Ashtottari、月小限 |
| 03 修复 P2/P3/P4 边界问题 | ✅ | 已修复 Arudha 对宫例外、Jaimini Rahu 逆算、超时文案、定位新鲜度/精度、非法 JSON |
| 04 补回归测试与记录 | ✅ | 已新增 focused pytest 回归，更新 `CHANGELOG.md` |
| 05 运行门禁并复核 diff | ✅ | targeted pytest、`swift build`、`swift test`、一键门禁和单独 rectify smoke 已通过 |

# 审计问题真实性核验 — 已完成（2026-07-01）

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 记录工作区边界 | ✅ | 当前在 `main`，仅有一个未跟踪 OCR Markdown，与本轮核验无关 |
| 02 读取前端/后端目标实现 | ✅ | 已对照用户列出的 11 个位置与实际数据契约、调用路径 |
| 03 判断真实性与影响面 | ✅ | 已将每项标记为真实/部分真实/需口径确认，并记录源码与最小复现依据 |
| 04 形成修复优先级建议 | ✅ | 本轮不改业务代码，只输出后续修复与验证建议 |

# Vedic 恋爱窗口推算 — 已完成（2026-06-28）

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 确认数据来源 | ✅ | 已读取整理好的本命、Dasha、Chara、Mudda、过运、年返/月返资料；未使用既有恋爱报告作为依据 |
| 02 复核计算接口 | ✅ | 已确认 `/usr/local/bin/python3` 的 `pyswisseph 2.10.03` 可用，并查询项目 Vedic 后端结构 |
| 03 独立计算窗口 | ✅ | 已以 2026-06-28 至 2027-06-28 为未来一年，重算 Whole Sign 过运、精确合相/相位与日评分 |
| 04 输出结论 | ✅ | 已整理按机会强弱排序的恋爱窗口、关键日期、依据和谨慎段 |

---

# 审计确认 bug 修复 — 已完成（2026-06-16）

## 分支
`codex/fix-audit-confirmed-bugs`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 确认工作区与目标位置 | ✅ | 已确认工作区仅有未跟踪 reasonix 本地配置，目标代码位置与审计描述一致 |
| 02 修复后端边界问题 | ✅ | 已修复 Horary 月亮异常速度 fallback、Whole Sign fallback、JSON NaN 输出、composite 吞异常、classical timing 零除保护 |
| 03 修复 Swift 超时与 ignore | ✅ | BackendClient 超时已改 300s，`.gitignore` 已加入 reasonix 本地配置 |
| 04 验证与 diff 复核 | ✅ | `bash check_vibe_changes.sh` 已通过；已检查 `git diff --stat` 与完整 diff |

---

# Horary 数据包增强方案评估 — 已完成（2026-06-12）

## 分支
`codex/fix-horary-perfection-timing`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 盘点当前实现 | ✅ | 已核对 horary 后端、Swift 模型、Markdown 导出、fixture 与现有脏工作区状态 |
| 02 映射 A 中建议 | ✅ | 已按“已有底层数据 / 仅缺导出 / 需要新增计算 / 牵动契约”分类 |
| 03 评估难度与路线 | ✅ | 已完成按当前实现的分级难度、推荐迭代顺序、关键风险与测试边界评估 |

---

# Horary 慢行星成相窗口与高级判定补修 — 已完成（2026-06-12）

## 分支
`codex/fix-horary-perfection-timing`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 确认问题 | ✅ | 已确认 exact 搜索窗口仍固定 30 天、Frustration 恒 not detected、`before_sign_exit_aspects` 截断会影响 key link 计算 |
| 02 修复慢行星成相窗口 | ✅ | 按双方最早换座时间动态决定搜索窗口，不再用 30 天硬上限 |
| 03 修复月亮列表截断 | ✅ | `before_sign_exit_aspects` 返回完整计算列表，显示截断留给前端；key link 不再吃截断数据 |
| 04 实现 Frustration | ✅ | 增加真实“主相位前较慢方先与第三方成相”检测与回归 |
| 05 回归、验证与打包 | ✅ | 已加真实木星-土星慢相位回归、列表截断回归、Frustration 回归；fixture 已刷新，门禁通过并已打包覆盖 `1.1.7 (26)` |

---

# Horary 月亮故事线边界修复与打包 — 已完成（2026-06-11）

## 分支
`codex/fix-horary-perfection-timing`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 确认问题 | ✅ | 已确认月亮 VOC 过滤未检查对方先换座、分钟字符串排序丢秒、月亮特例 orb 被写成 0.0 |
| 02 修复 moon_storyline | ✅ | 改为内部 datetime 排序/过滤，并在 before-sign-exit 过滤里排除目标行星先换座的相位 |
| 03 修复月亮特例 orb | ✅ | `key_significator_links` 使用当前度数 orb，不再把未来 exact 显示为当前 0.0 |
| 04 回归与 fixture | ✅ | 新增目标先换座、同分钟先后顺序、月亮特例 orb 回归；已刷新 horary fixture |
| 05 验证与打包 | ✅ | Python/Swift/一键门禁均通过；版本已升至 1.1.6 (25) 并覆盖 `/Applications`，codesign verify 通过 |

---

# Horary xhigh 复查补修 — 已完成（2026-06-11）

## 分支
`codex/fix-horary-perfection-timing`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 xhigh 复查 | ✅ | 复核 horary 计算链后追加确认：同星角色会产生 self-aspect 假成相，高级判定需排除同星主相位，逆行 ingress 标签用错目标星座，驻留阈值仍是一刀切 |
| 02 修复同星假成相 | ✅ | `key_significator_links` / `exact_datetime_for_signature` / 高级判定统一排除同一行星自相位 |
| 03 修复辅助计算口径 | ✅ | horary 驻留改行星独立阈值；scan 逆行换座目标星座显示改为实际进入的星座 |
| 04 补回归与 fixture | ✅ | 已增加同星角色、高级判定、驻留阈值、逆行 ingress 回归；已刷新 horary fixture |
| 05 验证与 diff 复核 | ✅ | horary/scan/classical pytest、horary smoke、Swift build/test、一键门禁与 diff 边界检查均通过 |

---

# Horary 成相时间与入离相修复 — 已完成（2026-06-11）

## 分支
`codex/fix-horary-perfection-timing`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 复核现状 | ✅ | 已复现月日合相/冲相 30 天内找不到、月亮近精确拱相误判离相、degree key aspects 为空 |
| 02 修正计算链 | ✅ | 已改有符号相位分支扫描、瞬时入离相、精算换座与 before sign exit 判断 |
| 03 修正高级判定 | ✅ | Translation / Collection / Prohibition / Frustration 已按时间顺序和古典定义收口 |
| 04 补回归测试 | ✅ | 已覆盖合冲精确时间、degree geometry、月亮入相、换座前成相、高级判定误报 |
| 05 Fixture 与验证 | ✅ | 已刷新 horary fixture；pytest、swift build/test、check_vibe_changes.sh 均通过 |

---

# AI 修复合并推送打包 — 已完成（2026-06-11）

## 分支
`codex/ai-streaming-stutter-followup`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 收口当前改动 | ✅ | 已复核 diff，当前分支包含 AI 流式性能修复、DeepSeek V4 输出预算修复与默认模型切换 |
| 02 完成验证 | ✅ | `swift test`（24 tests）、`bash check_vibe_changes.sh`、单独 rectify smoke 已通过 |
| 03 提交并合并到 `main` | ✅ | 已提交 `2ec3def fix: harden ai streaming for deepseek v4`，并 fast-forward 合并到 `main` |
| 04 推送远端 | ✅ | `main` 已推送到 `origin/main`，当前分支不再 ahead |
| 05 打包覆盖 | ✅ | `./package_app.sh` 已完成覆盖安装，`/Applications/TransitStudio.app` 为 `1.1.5 (24)` 且 codesign verify 通过 |

---

# AI 思考过程截断修复与打包 — 进行中（2026-06-10）

## 分支
`codex/ai-streaming-stutter-followup`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 查询请求参数 | ✅ | 已看到 `LLMAnalysisClient` 固定 `max_tokens=4096`，默认 `reasoning_effort=max` |
| 02 查询 SSE 结束处理 | ✅ | 当前代码未解析 `finish_reason`，服务端 `length` 等结束原因会被误判为正常完成 |
| 03 调整 DeepSeek V4 请求 | ✅ | DeepSeek V4 请求改用官方最大输出 `384000`，并显式发送 `thinking` enabled/disabled |
| 04 更新默认模型 | ✅ | 新安装默认 Base URL / 模型改为 DeepSeek V4 Flash，保留 V4 Pro 选项 |
| 05 验证与打包 | ✅ | `swift build`、`swift test`（24 tests）、`bash check_vibe_changes.sh` 与单独 rectify smoke 已通过；版本已递增到 `1.1.5 (24)` |

---

# AI 流式性能修复打包覆盖 — 已完成（2026-06-10）

## 分支
`codex/ai-streaming-stutter-followup`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 确认打包版本 | ✅ | 当前脚本为 `1.1.3 (22)`；本轮 AI 流式性能修复递增为 patch 版本 |
| 02 更新打包脚本与记录 | ✅ | `package_app.sh` 已更新为 `1.1.4 (23)`，`CHANGELOG.md` 已同步 |
| 03 执行覆盖安装 | ✅ | 第二次运行 `./package_app.sh` 成功，已覆盖 `/Applications/TransitStudio.app` |
| 04 验证产物 | ✅ | `/Applications/TransitStudio.app` Info.plist 为 `1.1.4 (23)`，codesign verify 通过 |

---

# AI 流式输出二次卡顿定位 — 已完成（2026-06-10）

## 分支
`codex/ai-streaming-stutter-followup`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 复查当前流式路径 | ✅ | 已查询 `ContentView+AI` / `AIAnalysisView` / `AIStreamBuffer` / SSE 客户端与调用点 |
| 02 定位剩余卡顿来源 | ✅ | 剩余热区是 MainActor per-token 消费、flush 后 growing string COW 拷贝、`Text(全文)` 长文重排与流式 text selection |
| 03 最小修复 | ✅ | 流消费 helper 显式 `nonisolated`；buffer 改追加 delta segment；流式视图改分段 `LazyVStack` |
| 04 验证与记录 | ✅ | `swift build`、`swift test`、`bash check_vibe_changes.sh`（提权跑完整门禁）与单独 rectify smoke 已通过；`CHANGELOG.md` 已更新 |

---

# AI 流式输出性能修复 — 已完成（2026-06-10）

## 分支
`refactor/frontend-tokens-views-vm`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 定位根因 | ✅ | 每 token 全量重发布 + 全文 markdown 重解析，O(n²) 压死主线程 |
| 02 消费端节流 | ✅ | `analyze()` 100ms 合并发布，结束时一次性落盘最终文本 |
| 03 失效范围隔离 | ✅ | 新增 `AIStreamBuffer`，流式热文本只触发 `AIAnalysisView` 重渲染 |
| 04 渲染降级与缓存 | ✅ | 流式期间纯 Text；结束后一次性分块解析并缓存于 `@State` |
| 05 SSE 解析提速 | ✅ | 逐字节迭代改 `bytes.lines` |
| 06 验证与记录 | ✅ | swift build/test 通过；CHANGELOG 已更新；提交 `2a7ec9a` |

---

# 全项目体检与防腐加固 — 已完成（2026-06-10）

## 分支
`refactor/frontend-tokens-views-vm`

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 全项目扫描 | ✅ | 危险写法/重复/超长文件/依赖/仓库卫生全量排查，报告见会话记录 |
| 02 分支与备份 | ✅ | 删除废弃分支（bug-sweep 留 archive tag）；重构分支推送 GitHub |
| 03 小行星下载校验 | ✅ | 下载内容校验 SWISSEPH 文件头，HTML 错误页不再污染星历目录 |
| 04 后端契约测试 | ✅ | `BackendContractTests` 7 个，fixture 为后端真实输出；Swift 测试 10 → 17 |
| 05 计算样板去重 | ✅ | `performRun` 收口 14 处 isRunning/错误/进度样板 |
| 06 大文件拆分 | ✅ | ClassicalResultViews / ContentView+ResultsPanes 按页面边界拆为 7 个文件 |
| 07 吠陀死 tab 修复 | ✅ | AI 分析/诊断/JSON 三个 tab 接通（含完整流式 AI 管线） |
| 08 tab 标题查表化 | ✅ | 11 个结果页 `resultTabTitle()` 查表，治愈 5 处标题漂移并消灭该 bug 类 |
| 09 CI | ✅ | GitHub Actions：push 即跑 swift build/test + pytest + 5 个 smoke |
| 10 仓库卫生 | ✅ | 计划文档归档、horary 样例补齐、check_vibe 升级、git gc |
| 11 打包覆盖 | ✅ | `1.1.3 (22)` 已覆盖安装 /Applications |

## 跳过项（用户决定）

- 本命档案导出/备份（建议后续单独做：当前档案只存 UserDefaults，无迁移机制）
- LLM API key 迁 Keychain；后端 60 秒硬超时调整

---

# 文档同步 — 已完成（2026-06-10）

## 执行计划

| 项目 | 状态 | 说明 |
|------|------|------|
| 01 PLANS.md 归档与补记 | ✅ | 旧批次移入 docs/archive，本轮任务补记 |
| 02 project-structure.md | ✅ | 同步拆分后的文件结构、状态对象、Fixtures、CI |
| 03 validation.md | ✅ | 补 BackendContractTests、fixture 再生成、CI、check_vibe |
| 04 AGENTS.md | ✅ | 验证清单与 Source of Truth 更新，新增 AI 流式与 tab 约定 |
