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
- Status: in progress

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
