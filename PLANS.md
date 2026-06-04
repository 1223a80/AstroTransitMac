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
