# Validation

## One-Shot Local Gate

`bash check_vibe_changes.sh` runs the whole local gate in one command: pytest, swift build, swift test, and backend smokes (classical / scan / horary / vedic / rectify). Use it before declaring any change done.

GitHub Actions (`.github/workflows/ci.yml`) runs the same checks automatically on every push; a red ❌ on the repo page means the pushed change broke something.

## Environment

Install Python dependencies once:

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

The system Python may also work if `pyswisseph` is already installed.

## Backend Tests

### Unit Tests

Run all Python unit tests:

```bash
python3 -m pytest python_tests/ -v
```

Run individual test files:

```bash
python3 -m pytest python_tests/test_classical.py -v   # classical dignity, timing, audit, circumambulations, primary directions
python3 -m pytest python_tests/test_horary.py -v      # legacy horary helpers (significators/advanced); call calculate_horary directly
python3 -m pytest python_tests/test_horary_v2.py -v   # horary data packet v2 (default production path)
python3 -m pytest python_tests/test_scan.py -v        # scan engine: aspect matching, priority scoring, ingress/station
python3 -m pytest python_tests/test_contracts.py -v   # integration: JSON contract for all modes
```

Run logic-only tests (no ephemeris required):

```bash
python3 -m pytest python_tests/ -v -m "not requires_ephemeris"
```

### Smoke Tests

```bash
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-scan-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-ingress-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-station-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-horary-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-vedic-ai-request.json
```

### Per-Module Guidance

If the change is in classical helper logic, check the split module that now owns it:

- `astro_backend_classical_dignity.py` — dignities, sect/hayz/joy, solar phase, motion, dodekatemorion
- `astro_backend_classical_lots.py` — lot formulas and lot rows
- `astro_backend_classical_timing.py` — profections, Firdaria, Decennials, Zodiacal Releasing, return windows, timeline
- `astro_backend_classical_audit.py` — prenatal syzygy, almuten figuris, hyleg/alcocoden

For horary backend changes, `test_horary.py` covers:

- `angular_delta()`, `infer_matter_role()`, `infer_natural_significator()`
- `radicality_flags()` (ASC early/late, Saturn in 7, Moon VOC)
- `significator_candidates()`, `house_rulers()`, `planetary_speeds()`
- `solar_condition()`, `negative_receptions()`
- `_detect_translation()`, `_detect_collection()`, `_detect_prohibition()`, `_detect_frustration()`

For scan engine changes, `test_scan.py` covers:

- `find_aspects()`, `exact_longitudes_for_aspect()`, `orb_at()`
- `scan_priority()`, `target_weight()`, `estimated_steps()`
- `reject_oversized_scan()`, `scan_response()` structure

For contract/integration changes, `test_contracts.py` verifies JSON structure of all modes.

`astro_backend_classical.py` remains the stable import surface used by tests and callers.

For classical backend changes, inspect at least:

- `warnings`
- `planetary_returns`
- `prenatal_syzygy`
- `timing.timeline`
- `hyleg_alcocoden`

## Swift Build And Tests

Run all:

```bash
swift build
swift test
```

Run individual test suites (faster when iterating):

```bash
swift test --filter ClassicalResultTests   # classical model JSON decoding
swift test --filter HoraryResultTests      # horary model JSON decoding
swift test --filter TransitResultTests     # transit/moment model JSON decoding
swift test --filter RectifyResultTests     # rectify model JSON decoding + request encoding
swift test --filter MarkdownExportTests    # markdown export for classical and transit
swift test --filter BackendContractTests   # vedic/synastry/composite/davison/progression/solar-arc/harmonic/horary decoding against real backend output fixtures
```

### Backend Contract Fixtures

`BackendContractTests` decode the captured real backend outputs in `SwiftTests/Fixtures/`. If a fixture test fails after a backend change, the Swift models and backend schema have drifted — either fix the unintended backend change or update the Swift model. Only after an **intentional** schema change, regenerate the fixture:

```bash
python3 Sources/TransitStudio/Resources/backend/transit_calc.py \
    < Examples/sample-<mode>-request.json > SwiftTests/Fixtures/<mode>-result.json
```

Never edit fixture files by hand.

In a sandboxed agent environment, `swift test` can fail if SwiftPM cannot write to the user module cache. If `swift build` passes but `swift test` fails with a cache permission error under `~/.cache/clang/ModuleCache`, rerun with the appropriate sandbox approval rather than changing project files.

## Packaging

Package the app with:

```bash
./package_app.sh
```

`dist/` is package output. Do not edit files under `dist/TransitStudio.app` as source changes; rebuild the app instead.

## Recommended Change-Specific Checks

- Backend calculation rule changed: add/update focused pytest coverage.
- Classical dignity / lots / audit helpers changed: run `python3 -m pytest python_tests/test_classical.py` and at least one smoke request that exercises the affected packet.
- Classical timing / returns changed: run `python3 -m pytest python_tests/test_classical.py` and the classical smoke request, then inspect `planetary_returns` and `timing.timeline`.
- Horary logic changed: run `python3 -m pytest python_tests/test_horary.py -v`.
- Scan engine changed: run `python3 -m pytest python_tests/test_scan.py -v`.
- Contract / integration: run `python3 -m pytest python_tests/test_contracts.py -v`.
- Backend JSON shape changed: update the corresponding Swift model file (`ClassicalResultModels.swift`, `HoraryDataPacketModels.swift` / legacy `HoraryResultModels.swift`, `TransitResultModels.swift`, `RectifyModels.swift`, `VedicResultModels.swift`, `ModernResultModels.swift`), regenerate the affected `SwiftTests/Fixtures/` file, and run `swift test` with the relevant filter.
- Horary default packet is v2 (`packetVersion=2`). Use `packetVersion=1` only for the deprecated interpretive adapter.
- Result-pane tab added: add the id to the pane's tab list **and** a matching `case` in its `selectedResultView` switch — a missing case silently falls through to the default view. Titles come from the list via `resultTabTitle()`; do not add a separate title switch.
- Result UI changed: run `swift build` and manually inspect the relevant Swift view when possible.
- Export changed: check both `MarkdownExportBuilder.swift` and `TextExportBuilder.swift`.
- Ephemeris behavior changed: include a deterministic Swiss Ephemeris regression case where possible.
- New backend module or significant refactor: add `python_tests/test_<module>.py` with tests for every public function, and register new test commands in this file.

## Known Technical Debt

See also `docs/project-audit-2026-07-06.md` for the current folder hygiene notes, potential hidden bug checklist, and prioritized next-step recommendations.

### classical_snapshot 重复计算

`classical_snapshot()` 在单次调用内调用了两次 `calculate_positions`：
- 第 1 次（line 492）：仅用于确定 `is_day`（昼/夜盘）
- 第 2 次（line 148，在 `calculate_classical_planets` 内部）：真正计算所有行星位置

可通过将 `is_day` 判断移到 `calculate_classical_planets` 内部来消除冗余调用，将 swe.calc_ut 调用次数减半。

### return_summary 重复重建 snapshot

`calculate_classical()` 为 7 颗古典行星各调用一次 `return_summary()`，每找到一个返照就会调用 `_build_snapshot()` → `classical_snapshot()` 重建完整星盘（含 7 行星 + 宫位 + 尊贵表）。在 7 颗行星都找到前后返照的典型场景下：

| 调用来源 | classical_snapshot 次数 |
|----------|----------------------|
| 本命星盘 | 1 |
| 7 颗行星 × 2 次返照 | 14 |
| **合计** | **15** |

每次 `classical_snapshot` 产生 14 次 `swe.calc_ut` 调用，总计约 210 次（不含搜索迭代）。

如果后续需要优化返照盘渲染或集成图形盘面，这是最值得优先清理的性能瓶颈。修复方向是将返照需要的子数据（指定时间的行星位置 + 宫位）从 `classical_snapshot` 中剥离，避免每次都重新计算全部尊贵表/相位/接纳。
