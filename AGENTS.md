打包时视改动大小更新版本号，无特殊说明默认覆盖 /Applications

# Agent Notes

以瞎猜接口为耻，以认真查询为荣。
以模糊执行为耻，以寻求确认为荣。
以臆想业务为耻，以人类确认为荣。
以创造接口为耻，以复用现有为荣。
以跳过验证为耻，以主动测试为荣。
以破坏架构为耻，以遵循规范为荣。
以假装理解为耻，以诚实无知为荣。
以盲目修改为耻，以谨慎重构为荣。

## Source Of Truth

- SwiftUI app source: `Sources/TransitStudio/`
- Python backend source: `Sources/TransitStudio/Resources/backend/`
- Bundled ephemeris files: `Sources/TransitStudio/Resources/ephemeris/`
- Swift tests: `SwiftTests/`
- Python tests: `python_tests/`
- Sample backend requests: `Examples/`

### Rectifier-specific files

- `Sources/TransitStudio/RectifyModels.swift` — Codable request/response structs
- `Sources/TransitStudio/RectifyClient.swift` — Process-based Python caller with stderr progress
- `Sources/TransitStudio/PrimaryDirectionRectifierView.swift` — SwiftUI slider + direction table + filter
- `Sources/TransitStudio/Resources/backend/astro_backend_rectify.py` — Python computation module

Do not edit `dist/`, `.build/`, `.pytest_cache/`, `__pycache__/`, or `backups/` as source. They are local build output, cache, package output, or historical snapshots.

## Architecture

The app is a Swift Package executable named `TransitStudio`. Swift calls the Python backend by launching `Sources/TransitStudio/Resources/backend/transit_calc.py` and exchanging JSON through stdin/stdout.

Backend entry flow:

1. `transit_calc.py`
2. `astro_backend_api.py`
3. Mode-specific modules such as `astro_backend_classical.py`, `astro_backend_horary.py`, `astro_backend_scan.py`, and `astro_backend_rectify.py`

### Rectifier (生时矫正)

Navigation rail mode `.rectify` (visible in classical practice mode). Sidebar shows read-only birth data from ContentView `@State`; result pane contains `PrimaryDirectionRectifierView` with three-level slider cascade:

| Level | Precision | API params | Candidates |
|-------|-----------|------------|------------|
| 1 | 1 minute | `window_minutes=30, step_minutes=1` | 61 (±30m) |
| 2 | 5 seconds | `window_seconds=30, step_seconds=5` | 13 (±30s) |
| 3 | 1 second | `window_seconds=5, step_seconds=1` | 11 (±5s) |

Level 1 runs on user clicking "计算生时矫正" button. Levels 2/3 auto-trigger when higher-level slider stops. Python writes `{"progress": …}` lines to stderr for real-time progress display.

Key files:
- `RectifyModels.swift` — request/response Codable structs
- `RectifyClient.swift` — Process call with stderr progress parsing
- `PrimaryDirectionRectifierView.swift` — slider + direction table + filters

Python modules import each other by file name from the backend directory. When adding tests, use the existing `python_tests/conftest.py` path setup instead of inventing another import path.

## Current Classical Contract

Classical mode returns `planetary_returns`, not a standalone `solar_return` field. Each return row for Sun, Moon, Mercury, Venus, Mars, Jupiter, and Saturn must keep the same schema:

- `previous_return`
- `current_cycle_return`
- `next_return`

`Prenatal Syzygy` is Swiss Ephemeris based. For full moons, output both `sun_position` and `moon_position`; `syzygy_degree_used` must say whether the selected degree is Sun, Moon, or an axis convention. Current implementation uses the Sun degree for the full-moon axis.

`Zodiacal Releasing` Loosing of the Bond is not a normal next-sign transition. Only mark `loosing_of_bond` when the sequence actually jumps to the loosening point/opposite sign; ordinary transitions such as Leo to Virgo and Pisces to Aries must stay unflagged.

`Hyleg / Alcocoden` is audit-only. Include candidate reasons and Alcocoden candidates for Saturn, Mercury, Mars, Jupiter, and Venus. Do not output longevity years.

## Required Validation

For backend/classical changes:

```bash
python3 -m pytest python_tests/test_classical.py
```

For Swift model/view/export changes:

```bash
swift build
swift test
```

`swift test` may need normal user cache access outside a sandbox because SwiftPM writes module cache files under the user cache directory.

For end-to-end backend smoke tests:

```bash
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-scan-request.json
```

For rectify mode smoke test:

```bash
echo '{"mode":"rectify","birth_date":"1990-01-01","center_time":"12:00","timezone":"Asia/Shanghai","latitude":31.2304,"longitude":121.4737,"house_system":"whole_sign","zodiac":"tropical","bounds_system":"egyptian","triplicity_system":"dorothean","max_age":90,"window_minutes":3,"step_minutes":3}' | python3 Sources/TransitStudio/Resources/backend/transit_calc.py 2>/dev/null | python3 -m json.tool | head -20
```

## Change Discipline

- **After every code change, append a brief note to the root `CHANGELOG.md`; create the file first if it does not already exist.**
- Before starting a task, write a task plan to `PLANS.md` in the project root. During execution, read and reference this file; update it as progress is made or plans change.
- Query existing models and call sites before changing JSON shape.
- Prefer extending existing Swift Codable models and backend helpers over adding parallel structures.
- Keep generated artifacts out of source edits.
- If changing a calculation rule, add or update a focused Python test.
- If changing a displayed/exported field, check Swift build and at least the relevant markdown/text export code.

## Git Workflow

- This project is now a Git repository with `main` tracking `origin/main`.
- Treat `main` as the review baseline, not the default scratch space for experimental edits.
- For non-trivial work, create a task branch first. Branch names should be descriptive, such as `feature/modern-ui-export` or `fix/rectify-timeout`.
- Keep one task per branch. Do not mix unrelated fixes into the same branch just because the files are nearby.
- `PLANS.md` explains intended work, `git diff` proves actual code changes, and `CHANGELOG.md` summarizes the result for humans. Do not use any one of the three as a substitute for the other two.
- Before editing, read the relevant code and confirm the target files and contracts. Do not start from a guessed patch shape.
- Before asking for review or declaring completion, run the required validation for the touched area and inspect `git diff --stat` plus the full `git diff`.
- If the diff contains unrelated noise, stop and clean the task boundary before review.
- Push branches to GitHub only after the local diff and validation output match the task plan.
- Never force-push or rewrite shared history unless the human explicitly asks for it.
