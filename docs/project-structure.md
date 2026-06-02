# Project Structure

## Root

- `Package.swift` - Swift Package manifest. Product is the macOS executable `TransitStudio`.
- `README.md` - user-facing overview and basic run instructions.
- `AGENTS.md` - project-specific instructions for coding agents.
- `requirements.txt` - Python dependency list. Currently requires `pyswisseph`.
- `package_app.sh` - local app packaging script.

## Source

- `Sources/TransitStudio/` - SwiftUI app source.
- `Sources/TransitStudio/Resources/backend/` - Python backend source bundled into the app.
- `Sources/TransitStudio/Resources/ephemeris/` - bundled Swiss Ephemeris files.

Important Swift files:

- `BackendClient.swift` - launches Python backend and decodes JSON.
- `ClassicalResultModels.swift` - Codable models for classical backend output.
- `ClassicalResultViews.swift` - classical result UI.
- `MarkdownExportBuilder.swift` and `TextExportBuilder.swift` - export surfaces that must stay in sync with backend schema.
- `ContentView+RunActions.swift` and `ContentView+RequestHelpers.swift` - request construction and execution.

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
- `SwiftTests/` - Swift Codable/model tests.
- `Examples/` - sample JSON requests for backend smoke tests.

## Generated Or Local-Only Folders

These folders are not source-of-truth:

- `.build/` - SwiftPM build output.
- `.pytest_cache/` and `__pycache__/` - Python test/import caches.
- `dist/` - packaged app output.
- `backups/` - historical snapshots.
- `Sources/TransitStudio.zip` - local archive copy.

They are listed in `.gitignore`. Do not edit them to fix behavior; update the real source files instead.
