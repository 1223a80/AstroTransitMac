# Bug Sweep May 2026

## Scope

Five issues from code review assessment, executed in dependency order:

| # | Issue | Type | Effort | Priority |
|---|-------|------|--------|----------|
| 1 | Horary string contract mismatch | Bug fix | 3 lines | P0 |
| 2 | Self-aspect / duplicate aspects in find_aspects | Bug fix | ~20 lines | P0 |
| 3 | Primary Directions mislabeled as "Placidus Semi-Arc" | Cleanup | 1 line | P0 |
| 4 | ContentView 114 @State properties → ViewModel split | Refactor | Multi-file | P1 |
| 5 | classical_snapshot duplicate swe.calc_ut + return_summary N+1 | Optimization | ~100 lines | P1 |

## Execution Steps

### Step 1 — Horary strings (`astro_backend_horary.py`)
- Line 408: `"度数"` → `"degree"`
- Line 452: `"星座"` → `"sign"`
- Line 526: `"度数"` → `"degree"`
- Verify: `python3 -m pytest python_tests/test_horary.py -x`

### Step 2 — Self-aspect filter (`astro_backend_scan.py` + 5 callers)
- Add `skip_self_aspects: bool = False` param to `find_aspects()`
- When True: skip same body_id + dedup A-B/B-A with frozenset
- Set True in 5 same-list callers (harmonic, composite, davison, progressions, solar_arc)
- Verify: `python3 -m pytest python_tests/test_scan.py python_tests/test_classical.py -x`

### Step 3 — Primary Directions rename (`astro_backend_api.py`)
- `"Placidus Semi-Arc"` → `"Naibod"`
- Verify: `swift build`

### Step 4 — ViewModel decomposition (ContentView.swift + 12 extensions)
- AppViewModel: nav state, settings, AI config, profiles, presets, sidebar layout
- ClassicalViewModel: classical reference date, orb, result, tabs, export
- HoraryViewModel: horary date/location/question/result
- ScanViewModel: scan window/kind/filter/targets/result
- MomentViewModel: transit date/targets/result
- ModernRelationshipViewModel: sub-mode/personB data/result
- RectifyViewModel: rectify responses/indices
- Remaining in ContentView: natal date/location, house system, body/aspect selections, running state
- Verify: `swift build && swift test`

### Step 5 — Performance: classical return optimization
- Eliminate duplicate `calculate_positions` inside `classical_snapshot`
- Add JD-based position cache for return_summary search phase
- Optionally parallelize 7 return_summary calls
- Verify: `python3 -m pytest python_tests/test_classical.py -x`
- Benchmark: `time python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json`

## Status

| Step | Status | Validation |
|------|--------|------------|
| 1 — Horary strings | ✅ Done | 34 pytest passed |
| 2 — Self-aspect filter | ✅ Done | 219 pytest passed |
| 3 — Primary Directions rename | ✅ Done | Smoke test confirms "Naibod (Platicus)" |
| 4 — ViewModel decomposition | ✅ Done | swift build + swift test pass |
| 5 — Performance optimization | ✅ Done | classical_snapshot double-calc eliminated + position cache added |

## Validation (final)
```bash
python3 -m pytest python_tests/ -x  # 219 passed
rm -rf .build && swift build && swift test  # build + 10 tests
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json | python3 -m json.tool | head -30
```

## Review Task (2026-06-02)

- Scope: review the working tree changes on `fix/bug-sweep-may2026` against `main`
- Focus: regression risk in SwiftUI state refactor, backend aspect filtering, and classical ephemeris caching
- Method: inspect full diff, verify changed call sites against existing contracts, then report findings ordered by severity
- Status: completed

## Review Follow-up (2026-06-02)

- Scope: re-review the three fixes for cache key collision, dead `@StateObject`s, and primary-directions label
- Method: inspect the updated diff, run minimal targeted checks for sidereal/tropical separation and string residue, then report only remaining findings
- Status: completed
