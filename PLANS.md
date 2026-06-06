# Output Audit Fixes — June 2026

## Scope

Fix 12 issues identified in output audit, organized across 3 phases.

## Phase 1 — P0: Output bugs / severe misleading (4 tasks)

| # | Issue | Files | Verification |
|---|-------|-------|-------------|
| 1 | Previous/Current return duplicated | `astro_backend_classical.py:667-669`, + Swift views/export | `current_cycle_return` ≠ `previous_return` for 7 planetary returns |
| 2 | Primary Directions max_age=120 no window | `astro_backend_api.py:191-193`, `calculate_primary_directions()` | Only directions within ±3y of ref age by default |
| 3 | Harmonic self-aspect/node dedup incomplete | `astro_backend_harmonic.py` | No bidirectional dedup, nodes not excluded |
| 4 | Scores lack text labels | `astro_backend_classical_dignity.py` → `ScoreBreakdownItem` | Add `label_text` with human-readable grade |

## Phase 2 — P1: Display / hierarchy / overload (4 tasks)

| # | Issue | Files | Verification |
|---|-------|-------|-------------|
| 5 | Timeline flat, no layering | `astro_backend_classical_timing.py` `timing_timeline()` | Add `active_periods`/`active_returns`/`events`/`historical` layers |
| 6 | Returns always full (7 bodies) | `astro_backend_classical.py` `return_summary` | Add `return_mode` param: compact/relationship/study/full |
| 7 | SA patterns on by default | `astro_backend_solar_arc.py:147-152` | `patterns_enabled=False` by default |
| 8 | Profection lord not highlighted | `astro_backend_classical.py` + Swift timing views | Add `activated_lord_focus` with linked returns |

## Phase 3 — P2: UX polish (4 tasks)

| # | Issue | Files | Verification |
|---|-------|-------|-------------|
| 9 | Birthday transition window | `astro_backend_classical_timing.py` or `classical.py` | Detect profection changed but SR not perfected |
| 10 | Top 5 signatures missing | `astro_backend_classical.py` → new `top_signatures` field | Top hard aspects + activated returns |
| 11 | Harmonic houses unmarked | `astro_backend_harmonic.py` + `MarkdownModernExportBuilder.swift` | Add `experimental: true` to houses output |
| 12 | SA ↔ Progression duplicate theme | `astro_backend_solar_arc.py` + `progressions.py` | Cross-detect same natal target hit, output warning |

## Execution Order

Sequential within each phase, phases in order P0→P1→P2.

## Validation (final)
```bash
python3 -m pytest python_tests/ -x
rm -rf .build && swift build && swift test
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json | python3 -m json.tool | head -30
```

## 2026-06-04 — Output Audit Branch Review

- Task: review `fix/output-audit-june2026` against `main` and verify whether the reported 12 fixes are fully implemented and correctly wired through backend, Swift models, and presentation/export layers.
- Focus: contract drift, partially wired output fields, timeline/return behavior, and validation gaps around new classical / harmonic / solar-arc outputs.
- Method: inspect `git diff main...HEAD`, trace new fields across Python output and Swift consumption, and run only minimal targeted smoke checks for classical / harmonic / solar-arc behavior.
- Status: completed

## 2026-06-04 — Review Follow-up Fixes

- Task: implement the 6 confirmed review findings on `fix/output-audit-june2026`.
- Changes:
  - Fix `birthday_transition` to compare calendar dates rather than same-day datetimes.
  - Emit timeline rows for `previous_return` / `current_cycle_return` / `next_return` instead of a single `or`-selected snapshot.
  - Remove Solar Arc's static duplicate-theme warning and the unused overlap helper.
  - Make invalid `returnMode` values fall back to `full`.
  - Add missing Swift Codable fields for classical summary outputs and Harmonic `houses_experimental`.
  - Rename `primary_directions_method` output to `Naibod`.
- Validation:
  - `python3 -m pytest python_tests/test_classical.py python_tests/test_modern_timebased.py -q`
  - `python3 -m pytest python_tests/ -q --ignore=python_tests/test_contracts.py`
  - `swift build`
  - `swift test --disable-sandbox`
  - Targeted smoke checks for classical timeline / birthday transition and Solar Arc / Harmonic outputs
- Status: completed

## 2026-06-04 — Vedic Integration Review

- Task: review the in-progress Vedic/Jyotish integration in the working tree and identify bugs, regressions, contract mismatches, or validation gaps before merge.
- Focus: Python backend routing/data correctness, Swift Codable/model wiring, UI state flow, and compatibility impact on existing classical/modern modes.
- Method: inspect the current worktree diff and untracked Vedic files, trace request/response contracts end to end, and report findings with file/line references.
- Status: completed

## 2026-06-04 — Vedic Final Fixes + Packaging + Merge

- Task: fix the final Rahu/Ketu label mismatch in shared constants, add the packaging/version rule to `AGENTS.md`, update packaging to bump version and overwrite `/Applications` by default, validate the touched areas, package the app, and merge the verified work back to `main`.
- Planned changes:
  - correct shared `LABELS["body_id"]` for `RAHU` / `KETU`
  - add the requested packaging rule at the top of `AGENTS.md`
  - bump packaged app version from `1.0.0` to `1.1.0` and build number from `16` to `17`
  - make `package_app.sh` install `TransitStudio.app` into `/Applications` by default after building `dist/TransitStudio.app`
  - add a regression assertion so the shared label table cannot drift again
- Validation:
  - `python3 -m pytest python_tests/test_jyotish_smoke.py python_tests/test_jyotish_reference_verify.py python_tests/test_constants.py -q`
  - `swift build`
  - `./package_app.sh`
  - inspect packaged/installed app metadata and merge into `main` if validation passes
- Validation completed:
  - `python3 -m pytest python_tests -q` → 309 passed
  - `swift build` → passed
  - `swift test` → passed
  - `./package_app.sh` → rebuilt `dist/TransitStudio.app` and updated `/Applications/TransitStudio.app`
  - installed app metadata verified as `CFBundleShortVersionString=1.1.0`, `CFBundleVersion=17`
- Status: completed

## 2026-06-04 — README 功能同步

- Task: sync `README.md` with the current codebase's actual functional surface, especially Vedic/Jyotish, export coverage, and backend sample requests.
- Focus:
  - update the top-level product description from modern/classical only to modern/classical/horary/vedic
  - refresh the feature overview to match the currently implemented modes and export capabilities
  - add the Vedic sample request to the backend run examples
  - document actual export formats and major Vedic output areas at a high level
- Validation:
  - manual read-through against current code entrypoints, export builders, and result panes
- Status: completed

## 2026-06-04 — 提交并覆盖安装

- Task: commit the reviewed Vedic/Jyotish integration changes currently in the working tree, then install the packaged app from `dist/` into `/Applications`.
- Focus:
  - preserve the reviewed diff exactly as committed, without mixing in unrelated edits
  - use the canonical packaged artifact `dist/TransitStudio.app` for the install step
  - verify git status and installed app metadata after the copy
- Planned steps:
  - append this close-out note to project tracking files
  - create a single commit for the reviewed working tree changes
  - overwrite `/Applications/TransitStudio.app` from `dist/TransitStudio.app`
  - verify `git status --short` and installed bundle version/build
- Status: superseded by later verified commits on `main`; do not reuse this entry as a live task

## 2026-06-04 — Vedic horoscope 输出硬伤修复

- Task: 只修复 Vedic horoscope 输出结果本身的硬伤，不做解释性文案改写；重点覆盖时区/UTC 基准、D1 anchor 校验、Panchanga / Vimshottari、星座索引、D1/Moon Chart 映射、Shadbala 完整性标注、天然敌友表、Yoga 过度泛化、以及根盘失败时的派生输出早停。
- Constraints:
  - 仅改动真实错误输出，不扩写说明性文本
  - 先修根盘与时间换算，再修依赖 D1 的派生模块
  - 若无法在当前回合完成完整 Shadbala 六分项，则必须显式标注 `incomplete` 并禁止“未达标”判断
  - 尝试创建任务分支，但当前环境对 `.git` 写入受限，分支创建已被执行环境拒绝；先在现有工作树完成修复
- Planned changes:
  - 在 `astro_backend_jyotish.py` 增加时区解析/默认回退、D1 anchor 校验与 failure gate，并统一 meta 中本地/UTC/时区输出
  - 修正 `astro_backend_jyotish_panchanga.py` 的 Karana 计算边界，补足 Vimshottari balance 输出
  - 修正 `astro_backend_jyotish_divisional.py` 的 Moon Chart 度数与 D1/Whole Sign 映射一致性
  - 修正 `astro_backend_jyotish_data.py` / `astro_backend_jyotish_relationships.py` 的天然敌友表与节点处理
  - 修正 `astro_backend_jyotish_shadbala.py` 输出契约，避免用不完整实现给出 `meets_required=false`
  - 收紧 `astro_backend_jyotish_yoga.py` 输出，区分 `condition_only` 与需要强度校验的 yoga
  - 新增/更新针对 2004-08-09 16:16 Asia/Shanghai 样例的 focused pytest
- Validation:
  - `python3 -m pytest python_tests/test_jyotish_smoke.py python_tests/test_jyotish_focused.py -q`
  - `python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-vedic-ai-request.json`
  - 用户给定 2004-08-09 16:16 / Linyi / Asia-Shanghai 样例的定向 JSON smoke check
- Validation completed:
  - `python3 -m pytest python_tests/test_jyotish_smoke.py python_tests/test_jyotish_focused.py -q` → 119 passed
  - `python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-vedic-ai-request.json` → 成功返回完整 Vedic JSON；时区显示为 `Asia/Shanghai` / `UTC+8`，Shadbala 标记为 `incomplete`
  - 用户样例 `2004-08-09 16:16 / Linyi / Asia/Shanghai` → D1 ASC/Moon/Sun/Rahu、Panchanga、Vimshottari balance、Moon Chart 度数、Shadbala incomplete 均与修复目标一致
- Remaining validation gap:
  - `swift build` 已通过
  - `swift test` 需要越过沙箱写入用户 SwiftPM 缓存；已按流程申请，但执行环境提权额度被系统拒绝，本回合无法完成
- Status: completed

## 2026-06-06 — LLM 前端改动审查与拆分提交

- Task: 审查当前未提交的 LLM / AI 前端改动，将其与已提交的 Vedic 修复彻底分离，并在发现真实问题后先修正再提交。
- Focus:
  - 流式 SSE 解析是否正确处理 UTF-8 / 中文 token
  - modern 各子模式的 AI 分析状态是否互相污染
  - 现代模式 AI tab 接入后是否仍可通过本地编译
- Review findings addressed:
  - `LLMAnalysisClient.swift` 的 SSE 逐字节字符串拼接会破坏 UTF-8，多字节中文输出可能乱码；已改为按 `Data` 累积到换行后统一 UTF-8 解码
  - `ContentView.swift` / `ContentView+AI.swift` / `ContentView+ResultsPanes.swift` 仍只共享一份 `modernAIAnalysis` / `modernAIReasoning`，切换 `synastry/composite/davison/progression/solar_arc` 会串台；已改为按 mode key 分桶
- Validation:
  - `swift build`
  - 代码审查：LLMAnalysisClient / ContentView+AI / AIAnalysisView / ContentView+ResultsPanes / ModernResultViews
- Validation completed:
  - `swift build` → passed
- Remaining validation gap:
  - `swift test` 需要越过沙箱写 SwiftPM 用户缓存，当前执行环境未放行
- Status: completed

## 2026-06-06 — Git 历史遗留清理与文档防再犯

- Task: 清理当前仓库里与 Git 状态认知相关的历史遗留问题，同步强化 `AGENTS.md` 和项目文档，避免再次出现“本地已提交但未 push”“多任务混在一个工作树里”“过期 in-progress 计划误导后续任务”的情况，并把当前 `main` 的本地提交统一推送到 GitHub。
- Planned changes:
  - 在 `AGENTS.md` 增加本地/远端状态核对、脏工作树先分拣、过期 `PLANS.md` 状态关闭、push 前后核验等明确规则
  - 在 `README.md` 增加简版 Git 卫生流程，面向人类维护者
  - 在 `docs/` 下新增 Git 流程文档，并加入 `docs/README.md` 索引
  - 关闭 `PLANS.md` 中过期但仍显示 `in progress` 的遗留条目
  - 完成文档提交后，将 `main` 推送到 `origin/main`
- Validation:
  - `git status --short --branch`
  - `git log origin/main..HEAD --oneline`
  - 人工审查新增文档是否和当前项目约束一致
- Validation completed:
  - 文档修改已覆盖 `AGENTS.md`、`README.md`、`docs/README.md`、`docs/git-workflow.md`
  - 已将遗留的“提交并覆盖安装”条目标记为 `superseded`
  - 本地提交已按任务拆分完成，待统一推送到 GitHub
- Status: completed

## 2026-06-06 — P0 修复：窗口扫描开始按钮丢失

- Task: 修复窗口扫描模式缺失“开始扫描 / 扫描窗口”入口按钮导致整个 scan 功能不可用的问题。
- Root cause identified:
  - `sidebar` 始终渲染 `runSection`
  - 但 `runSection` 内部错误地把 `mode == .scan` 的执行按钮排除掉了
  - 同时 `scanSidebarActionBar` 是死代码，从未挂载到任何视图树
- Planned changes:
  - 恢复 scan 模式在共享 `runSection` 中的执行按钮
  - 删除或收敛未使用的 `scanSidebarActionBar` 死代码，避免再次出现“有实现、未接线”的假入口
  - 运行最小编译验证，确认 scan 模式入口恢复且不影响其他模式
- Validation:
  - `swift build`
  - 人工代码审查：确认 `mode == .scan` 时侧边栏存在执行按钮且调用 `runCurrentMode()`
- Validation completed:
  - `rg -n "scanSidebarActionBar|mode != \\.scan" Sources/TransitStudio` → 无匹配，确认错误分支和死代码已移除
  - `swift build` → passed
- Status: completed

## 2026-06-06 — scan 启动按钮位置调整

- Task: 将窗口扫描模式的“扫描窗口”启动按钮从底部共享运行区挪到侧边栏顶部标题行右侧，减少滚动并让入口更显眼。
- Planned changes:
  - 在 `ContentView+SidebarSections.swift` 的标题行中，仅对 `mode == .scan` 显示右侧主按钮
  - scan 模式不再渲染底部共享 `runSection`，避免重复入口
  - 其他模式维持原有布局不变
- Validation:
  - `swift build`
  - 代码审查：确认 scan 模式只有顶部一个主按钮，且仍调用 `runCurrentMode()`
- Validation completed:
  - `swift build` → passed
  - 代码审查确认：scan 模式按钮位于标题行右侧，底部共享 `runSection` 对 scan 已关闭，其他模式仍保留原布局
- Status: completed

## 2026-06-06 — scan P0 收尾打包并推送

- Task: 将窗口扫描相关 P0 修复（恢复入口 + 标题栏按钮调整）打包覆盖到 `/Applications`，然后整理提交并推送到 GitHub。
- Planned changes:
  - 将当前打包 build 号从 `18` 提升到 `19`，保留 `1.1.1` 作为 patch 版本
  - 重新运行 `./package_app.sh` 覆盖安装 `/Applications/TransitStudio.app`
  - 校验安装后 bundle 版本
  - 提交 `scan` 修复相关源码、`package_app.sh`、`PLANS.md`、`CHANGELOG.md`
  - 推送 `main` 到 `origin/main`
- Validation:
  - `./package_app.sh`
  - `plutil -extract CFBundleShortVersionString raw -o - /Applications/TransitStudio.app/Contents/Info.plist`
  - `plutil -extract CFBundleVersion raw -o - /Applications/TransitStudio.app/Contents/Info.plist`
  - `git status --short --branch`
- Validation completed:
  - `./package_app.sh` → passed
  - `dist/TransitStudio.app` version verified as `1.1.1 (19)`
  - `/Applications/TransitStudio.app` version verified as `1.1.1 (19)`
  - 当前工作树仅剩本轮待提交源码 / 文档 / 打包脚本改动
- Status: completed

## 2026-06-06 — ACG 地图算法口径核实与个人计算准备

- Task: 查证 ACG / astrocartography 的主流权威计算口径，确认本项目现有后端哪些天文计算层可以直接复用；若用户未提供出生资料，则先完成方法说明与输入清单，不臆造个人结果。
- Focus:
  - 区分 ACG 四角线、Local Space、Relocation chart 这三类常被混称的方法
  - 核实上升/下降线采用 `in mundo` 还是仅用黄经投影的主流分歧
  - 核实项目内 `Swiss Ephemeris + build_houses()` 是否足以支撑后续一次性计算
- Planned steps:
  - 查阅 astro.com / Astrodienst 与 Swiss Ephemeris 文档中的 ACG / locational astrology 说明
  - 检查本地后端是否已有现成 ACG 输出；若没有，只确认可复用的底层计算能力
  - 向用户返回方法结论、当前能做的计算范围、以及实际个人计算所需出生参数
- Validation:
  - 人工审查外部资料
  - 人工审查 `astro_backend_api.py`、`astro_backend_ephemeris.py`、`astro_backend_core.py`
- Status: completed

## 2026-06-06 — 用户样例 ACG 个人计算

- Task: 基于用户已确认的出生资料，按标准 `in mundo astrocartography` 口径输出个人 ACG 四角线结果；不新建产品接口，只做一次性本地计算。
- Input confirmed:
  - `2004-08-09 16:16`
  - `35.057183N, 118.334337E`
  - `UTC+8 / Asia/Shanghai`
  - `无夏令时`
- Planned steps:
  - 用本地 Swiss Ephemeris 计算出生瞬间主要星体的黄道与赤道坐标
  - 计算各星体 `MC/IC` 子午线与 `ASC/DSC` 升落曲线
  - 汇总为便于阅读的城市/区域级解释，明确这是 ACG 而非 relocation chart
- Validation:
  - 本地 Python / Swiss Ephemeris 计算脚本成功运行
  - 抽查结果几何关系：`IC = MC ± 180°`，`ASC/DSC` 为互补曲线
- Status: in progress
