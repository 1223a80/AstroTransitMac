# Transit Studio

Transit Studio is a macOS SwiftUI prototype for astrology calculations. The UI is written in Swift, and calculation work is delegated to a bundled Python backend using `pyswisseph`.

## What It Does

- Calculates natal and transit positions.
- Finds transit-to-natal aspects for a specific moment.
- Scans a time window for exact aspect hits, ingress events, and stations.
- Supports classical mode with angles, houses, seven traditional planets, Lots, aspects, receptions, antiscia, time-lord summaries, planetary returns, Prenatal Syzygy, Almuten Figuris, and Hyleg / Alcocoden audit data.
- Supports horary mode.
- Exports result data as Markdown, JSON, and CSV-style text from the app.

## Project Layout

- `Sources/TransitStudio/` - SwiftUI app source.
- `Sources/TransitStudio/Resources/backend/` - Python backend source bundled into the app.
- `Sources/TransitStudio/Resources/ephemeris/` - bundled Swiss Ephemeris files.
- `Examples/` - sample backend requests.
- `python_tests/` - pytest coverage for backend logic.
- `SwiftTests/` - Swift package tests.
- `docs/` - project structure, backend contracts, validation notes, and scoped requirements.
- `AGENTS.md` - working notes for coding agents.

Generated folders such as `.build/`, `dist/`, `.pytest_cache/`, `__pycache__/`, and `backups/` are not source-of-truth.

## Setup

```bash
cd AstroTransitMac
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
```

Then open `Package.swift` in Xcode and run the `TransitStudio` executable, or use SwiftPM from the terminal.

If the app cannot find Python, set the Python path in the app to the virtual environment executable, for example:

```text
/Users/yourname/path/to/AstroTransitMac/.venv/bin/python
```

## Swiss Ephemeris

The backend tries Swiss Ephemeris first and falls back where the code permits it. The bundled ephemeris directory is:

```text
Sources/TransitStudio/Resources/ephemeris
```

For external ephemeris files, set the app's Ephemeris folder to the directory containing `.se1` files.

## Run The Backend Directly

```bash
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-scan-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-ingress-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-station-request.json
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json
```

PowerShell equivalent:

```powershell
Get-Content -Raw -Encoding UTF8 Examples/sample-classical-request.json | python Sources/TransitStudio/Resources/backend/transit_calc.py
```

## Validate Changes

```bash
python3 -m pytest python_tests/test_classical.py
swift build
swift test
```

See `docs/validation.md` for smoke tests and sandbox notes.

## Classical Output Shape

`mode: "classical"` returns these main fields:

```text
meta
angles
houses
planets
lots
experimental_lots
aspects
receptions
antiscia
primary_directions
circumambulations
timing
planetary_returns
prenatal_syzygy
almuten_figuris
hyleg_alcocoden
warnings
ambiguity
calculation_assumptions
```

Important contract notes:

- Solar/Lunar/Mercury/Venus/Mars/Jupiter/Saturn returns all live in `planetary_returns`.
- Each return row exposes `previous_return`, `current_cycle_return`, and `next_return`.
- Prenatal Syzygy includes both `sun_position` and `moon_position`.
- Loosing of the Bond is not the same as a normal next-sign transition.
- Hyleg / Alcocoden output is an audit packet and does not include longevity years.

Detailed backend contracts are in `docs/backend-contracts.md`.

## Packaging

```bash
./package_app.sh
```

This creates or updates `dist/TransitStudio.app`. Treat `dist/` as generated output.
