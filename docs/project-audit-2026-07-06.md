# Project Audit: folders, technical debt, and next steps

Date: 2026-07-06

This audit is a documentation pass. It does not move files or change app behavior. Its purpose is to make the project easier to navigate and to capture known risks before the next implementation task.

## Inputs checked

- `AGENTS.md`
- `README.md`
- `docs/README.md`
- `docs/project-structure.md`
- `docs/backend-contracts.md`
- `docs/validation.md`
- tracked file list from Git
- static searches for generated files, placeholders, broad exception handling, and TODO-like markers
- spot reads of high-risk backend files in modern time-based modes and Vedic modules
- direct backend reproductions for progression, solar arc, harmonic, and progression warning behavior

Validation was not run because this pass only edits documentation.

## Folder organization

### Source of truth

These are the directories to edit for real behavior changes:

| Path | Purpose |
|------|---------|
| `Sources/TransitStudio/` | SwiftUI app, Codable models, export builders, backend process clients |
| `Sources/TransitStudio/Resources/backend/` | Python calculation backend bundled into the app |
| `Sources/TransitStudio/Resources/ephemeris/` | bundled Swiss Ephemeris files |
| `SwiftTests/` | Swift model, export, streaming, and backend fixture contract tests |
| `python_tests/` | Python backend tests |
| `Examples/` | JSON requests used by backend smoke tests |
| `docs/` | durable project docs, contracts, validation, design handoffs, and archived plans |

### Documentation layout

The current docs split is mostly sound:

| Path | Current role | Suggested treatment |
|------|--------------|---------------------|
| `docs/README.md` | docs index | keep as the entrypoint and link this audit |
| `docs/project-structure.md` | folder and module map | keep current; update whenever files move |
| `docs/backend-contracts.md` | backend JSON invariants | keep focused on schema and calculation contracts |
| `docs/validation.md` | local checks and smoke tests | keep operational; link deeper technical debt here |
| `docs/frontend-refactor/` | completed UI refactor specs | keep for history, do not expand for new frontend work |
| `docs/expansion-002/` | fixed stars, declination, medieval expansion specs | keep as feature-specific implementation history |
| `docs/archive/` | completed plans and historical roadmaps | move superseded planning docs here |

`docs/opencode-next-step-requirements.md` mixes a completed preset-management requirement with an unfinished chart-wheel requirement. If the chart wheel becomes active work again, split the active part into a fresh `docs/requirements/chart-wheel.md` or `docs/roadmap/chart-wheel.md`, then archive the completed preset-management section.

### Local-only folders

These folders or files are local state, generated output, or external references. They should not be treated as source:

| Path | Status | Notes |
|------|--------|-------|
| `.venv/` | ignored | local Python environment |
| `.build/` | ignored | SwiftPM output |
| `dist/` | ignored | packaged app output; current local copies contain old `.pyc` files, which should not be inspected as source |
| `.pytest_cache/`, `__pycache__/`, `*.pyc` | ignored | Python caches |
| `maitreya8-reference/` | ignored | offline reference repo |
| `.opencode/` | ignored | local planning/tool state |
| `.reasonix/`, `reasonix.toml` | ignored | local agent/tool state |
| `.DS_Store` | ignored | macOS metadata |
| `.claude/` | local tool state | not listed in `.gitignore` in this checkout; confirm whether it is covered by local Git exclude, or add an explicit ignore rule later |

There is no immediate need to reorganize source folders. The priority should be documenting boundaries and avoiding future edits in generated folders.

## Known technical debt

### P1: Modern time-based modes ignored selected zodiac and house system from the UI

Status: fixed on `codex/fix-modern-timebased-contract`.

Observed contract mismatch:

- Swift `ProgressionRequest`, `SolarArcRequest`, and `HarmonicRequest` encode `birth: BirthSettings`.
- `BirthSettings` contains `houseSystem` and `zodiac`.
- Python `astro_backend_progressions.py`, `astro_backend_solar_arc.py`, and `astro_backend_harmonic.py` read `request.get("zodiac", "tropical")` and `request.get("house_system", "whole_sign")` from the top level.

Confirmed effect: progressions, solar arc, and harmonic charts calculate as tropical + whole sign when the UI selected another zodiac or house system, because the UI does not encode the top-level keys those Python modules read. Direct backend checks showed that changing only `birth.zodiac` from `tropical` to `sidereal_lahiri` did not change Sun longitude, while adding top-level `zodiac: "sidereal_lahiri"` did. Synastry, composite, and Davison already send top-level `zodiac` / `house_system`, so they are not the same risk.

Fix evidence:

1. Python modules now read top-level settings first, then fall back to `birth["zodiac"]` and `birth["houseSystem"]`.
2. Swift `ProgressionRequest`, `SolarArcRequest`, and `HarmonicRequest` now encode top-level `house_system` and `zodiac`.
3. `python_tests/test_modern_timebased.py` covers UI-shaped requests with only `birth.zodiac`.
4. `SwiftTests/ModernRequestEncodingTests.swift` covers top-level request encoding.

### P1: Progressions misreport known exact-hour birth times as unknown

Status: fixed on `codex/fix-modern-timebased-contract`.

`astro_backend_progressions.py` checks `birth.get("hour", False)` even though the hour lives under `birth["moment"]`. It also treats `minute: 0` as false. Direct backend checks showed:

- `minute: 0` returns warning `出生时间不详，progressed angles/houses 可能不准确。`
- `minute: 30` does not return that warning

This is a user-visible false warning and can undermine trust in progressed angles/houses even when a valid birth time was supplied.

Fix evidence:

1. The backend now checks `birth["moment"]` key presence instead of value truthiness.
2. `python_tests/test_modern_timebased.py` covers `hour: 12, minute: 0`, `hour: 0, minute: 0`, and `hour: 12, minute: 30`.

### P1: Classical return rendering is expensive

`docs/validation.md` already documents two related performance debts:

- `classical_snapshot()` repeats position calculation inside one snapshot.
- `return_summary()` rebuilds full snapshots for each return chart.

This can produce many redundant Swiss Ephemeris calls during classical returns. It is not a correctness bug by itself, but it affects responsiveness and makes future chart-wheel integration more expensive.

Suggested fix path:

1. Split a lightweight "positions + houses at JD" helper from `classical_snapshot()`.
2. Use that helper for return-chart packets.
3. Keep `classical_snapshot()` as the public compatibility surface.
4. Add focused timing/shape tests before touching exports.

### P2: Kalachakra Dasa is an explicit placeholder

`README.md` already says `kalachakra_dasa` is not a complete algorithm. The backend currently returns only a note and `current_kalachakra: null`.

Risk: users may treat the field as a delivered Jyotish calculation if the UI/export displays it without a caveat.

Suggested fix path:

1. Keep the placeholder clearly labeled in README, export, and UI.
2. Add a contract test that locks the placeholder shape until a real implementation replaces it.
3. When implementing it, write a separate requirement document with source tradition, expected examples, and validation cases.

### P2: Vedic Ashtakavarga fallback can hide missing ASC data

`compute_ashtakavarga()` accepts `asc_longitude`, but if missing it falls back to Aries (`0`). The current inline comment still describes this as a placeholder.

Risk: if a caller later omits ASC accidentally, Ashtakavarga output remains shaped but may be misleading.

Suggested fix path:

1. Treat missing ASC as a warning or section error rather than a silent Aries fallback.
2. Add a test for missing `asc_longitude`.
3. Update comments after the behavior is clarified.

### P2: Broad exception handling needs an audit policy

Several backend modules intentionally catch section-level exceptions and append warnings so one failed section does not kill the whole response. That is a good product behavior for optional sections.

The risky cases are silent fallbacks such as `except Exception: pass`, especially when they can hide formatting, ayanamsha, pattern, or chart-shape failures.

Suggested policy:

- Section-level optional calculations should append `warnings` and, where already supported, `section_errors`.
- Local formatting fallbacks may return empty labels, but tests should cover the expected output.
- Silent `pass` should be allowed only when the exception is provably non-user-visible.

### P3: Modern advanced diagnostics tabs are not diagnostic views

Status: fixed on `codex/fix-modern-timebased-contract`.

Several modern advanced panes label a tab as `诊断`, but render the full raw JSON rather than a focused warning / section-error view. Harmonic has no diagnostics tab even though `HarmonicResult` decodes `warnings` and `section_errors`.

Risk: failures are technically present in JSON, but users have to inspect raw data to find them.

Fix evidence:

1. Added a reusable modern diagnostics view that displays `warnings` and `section_errors`.
2. Synastry, composite, Davison, progressions, solar arc, and harmonic use it for `diagnostics`.
3. The separate `JSON` tab still renders raw output.

## Historical bug themes

The changelog shows repeated fixes in these areas. They deserve regression tests and extra care in future work:

| Theme | Why it matters |
|-------|----------------|
| AI streaming performance | Previously hit O(n^2) UI stalls; new AI surfaces need unique `streamKey` and must avoid parsing markdown inside `body` |
| Result-pane tabs | Missing switch cases previously made tabs show the wrong default view |
| Backend JSON contracts | Swift Codable models fail or silently empty UI when backend schema drifts |
| Horary exact aspect timing | Several fixes were needed around signed aspects, sign exits, slow planets, and advanced judgment logic |
| Ephemeris packaging | Generated `__pycache__` or missing bundled ephemeris can break packaged app behavior/signing |
| Vedic reference algorithms | Jaimini, Arudha, Ashtottari, Bhava, and relationship mappings have had correctness fixes and need source-backed tests |

## Potential hidden bug checklist

Use this checklist before starting the next bug-sweep:

- Non-default zodiac/house-system paths for every modern mode.
- Exact-hour birth times in progressions (`minute: 0` and `hour: 0`) do not create false "unknown time" warnings.
- Backend warnings are visible in every result pane and export surface.
- `section_errors` are decoded and displayed consistently for modern, classical, Vedic, and Horary result types.
- Every tab id in each result pane appears in the corresponding `selectedResultView` switch.
- Markdown and text exports cover newly added backend fields.
- Fixture tests are regenerated only after intentional schema changes.
- Packaged app smoke checks run against `/Applications/TransitStudio.app` after packaging work.

## Suggested next steps

### 1. Verify and ship the modern time-based request contract fix

This was the highest-value correctness task from this audit because it affected user-visible calculations in existing modes. Keep these checks in the release evidence for the fixing commit.

Validation:

```bash
python3 -m pytest python_tests/test_modern_timebased.py -q
swift test --filter BackendContractTests
```

### 2. Verify progression birth-time warning detection

This was fixed with the modern time-based request contract. Keep this check in the release evidence for the fixing commit.

Validation:

```bash
python3 -m pytest python_tests/test_modern_timebased.py -q
```

### 3. Add a warning/section-error audit pass

Document which backend failures should be fatal, warning-only, or silent. Then convert the remaining silent `pass` cases where users would care.

Validation:

```bash
python3 -m pytest python_tests/test_contracts.py -q
```

### 4. Clarify Vedic placeholder status

Make sure `kalachakra_dasa` and any missing-ASC Ashtakavarga behavior are explicitly marked in UI/export/docs.

Validation:

```bash
python3 -m pytest python_tests/test_jyotish_focused.py -q
python3 -m pytest python_tests/test_jyotish_smoke.py -q
```

### 5. Refactor classical return performance

Do this only after correctness fixes. Keep the backend JSON shape unchanged unless there is a deliberate fixture update.

Validation:

```bash
python3 -m pytest python_tests/test_classical.py -q
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json > /tmp/classical-smoke.json
swift test --filter ClassicalResultTests
```

### 6. Split active roadmap docs from completed handoffs

Keep the root README short. Use `docs/README.md` as the index, archive completed specs, and put future feature requirements under a dedicated active roadmap/requirements area.

Suggested future layout:

```text
docs/
  requirements/
    chart-wheel.md
  roadmap/
    2026-next-steps.md
```

Do not create these folders until there is active work to put in them.
