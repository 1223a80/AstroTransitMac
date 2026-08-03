# Project Structure

## Root

- `Package.swift` - Swift Package manifest. Product is the macOS executable `TransitStudio`.
- `README.md` - user-facing overview and basic run instructions.
- `AGENTS.md` - project-specific instructions for coding agents.
- `PLANS.md` / `CHANGELOG.md` - task plans and human-readable change log (see AGENTS.md change discipline).
- `requirements.txt` - Python runtime dependency list. Currently requires `pyswisseph`.
- `requirements-dev.txt` - validation dependencies (`pytest` + required JSON Schema validation) layered on the runtime requirements.
- `package_app.sh` - local app packaging script (bumps version, installs to /Applications by default).
- `check_vibe_changes.sh` - one-shot local validation gate (pytest + swift build/test + backend smokes).
- `.github/workflows/ci.yml` - GitHub Actions: swift build/test + pytest + backend smokes on every push.
- `docs/archive/` - completed planning documents kept for history.

## Source

- `Sources/TransitStudio/` - SwiftUI app source.
- `Sources/TransitStudio/Resources/backend/` - Python backend source bundled into the app.
- `Sources/TransitStudio/Resources/ephemeris/` - bundled Swiss Ephemeris files.

Important Swift files:

- `BackendClient.swift` - launches Python backend and decodes JSON.
- `AppState.swift` - shared `@MainActor` ObservableObject owning all persisted settings (UserDefaults-backed), injected via environmentObject.
- `CalculationViewModel.swift` / `AIAnalysisViewModel.swift` - run state, results, tab selections, and per-mode AI analysis storage. `AIStreamBuffer` (in AIAnalysisViewModel.swift) carries hot streaming text observed only by `AIAnalysisView`.
- `DesignTokens.swift` - `TS.*` spacing/font/color/radius token system used across views.
- Result-pane view files split along page boundaries:
  - `ContentView+ResultsPanes.swift` - run section + modern natal / moment / scan / horary panes.
  - `ContentView+ClassicalPane.swift`, `ContentView+ModernPanes.swift`, `ContentView+VedicRectifyPanes.swift` - the remaining panes.
  - `ClassicalResultViews.swift` (tables) + `ClassicalTimingViews.swift` + `ClassicalOverviewViews.swift` - classical result UI.
  - `Vedic*.swift` - one file per vedic data page.
- `ResultToolbarViews.swift` - tab bar + export toolbar; `resultTabTitle()` derives toolbar titles from the same tab lists that feed the toolbar (do not reintroduce per-pane title switches).
- `LLMAnalysisClient.swift` / `AIAnalysisView.swift` / `ContentView+AI.swift` - streaming AI analysis (SSE via `bytes.lines`, ~100ms publish throttling).
- `MarkdownExportBuilder.swift` and `TextExportBuilder.swift` - export surfaces that must stay in sync with backend schema.
- `ContentView+RunActions.swift` and `ContentView+RequestHelpers.swift` - request construction and execution; `performRun` owns the shared isRunning/error/progress lifecycle.
- `AsteroidEphemerisManager.swift` - asteroid .se1 download with SWISSEPH header validation.

Important backend files:

- `transit_calc.py` - executable entrypoint.
- `astro_backend_api.py` - mode router and top-level response assembly.
- `astro_backend_core.py` - shared time, zodiac, body registry, and Swiss Ephemeris helpers.
- `astro_backend_ephemeris.py` - body/house calculations and ephemeris fallback handling.
- `astro_backend_classical.py` - classical composition layer for planets, aspects, receptions, snapshots, and return packet assembly. Re-exports split helpers for compatibility.
- `astro_backend_classical_dignity.py` - dignity tables, sect/hayz/joy logic, solar phase, motion labels, and dodekatemorion helpers.
- `astro_backend_classical_lots.py` - lot formulas and classical lot row assembly.
- `astro_backend_classical_timing.py` - classical profections, Firdaria, Decennials, Zodiacal Releasing, return window config, and timing timeline assembly.
- `astro_backend_classical_audit.py` - prenatal syzygy, almuten figuris, and hyleg/alcocoden audit helpers.
- `astro_backend_scan.py` - transit window scan and crossing refinement.
- `astro_backend_horary.py` - horary mode.
- `astro_backend_primary_directions.py` and `astro_backend_circumambulations.py` - classical timing submodules.

## Tests And Examples

- `python_tests/` - pytest coverage for backend math and classical contracts.
- `SwiftTests/` - Swift Codable/model tests, including `BackendContractTests` which decode real backend outputs.
- `SwiftTests/Fixtures/` - captured backend outputs used by `BackendContractTests`. Regenerate after an intentional schema change with:
  `python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-<mode>-request.json > SwiftTests/Fixtures/<mode>-result.json`
- `Examples/` - sample JSON requests for backend smoke tests (one per mode, including horary and vedic).

## Generated Or Local-Only Folders

These folders are not source-of-truth:

- `.build/` - SwiftPM build output.
- `.pytest_cache/` and `__pycache__/` - Python test/import caches.
- `dist/` - packaged app output.
- `backups/` - historical snapshots.
- `maitreya8-reference/` - offline reference repo for cross-checking calculations.

They are listed in `.gitignore`. Do not edit them to fix behavior; update the real source files instead.
