# Technique Maintenance — Change Log (implementation)

## Classical modules

### Dignity (`astro_backend_classical_dignity.py`)
- Fixed Egyptian Virgo bounds: Mer 0–7, Ven 7–17, Jup 17–21, Mar 21–28, Sat 28–30
- Bound upper edge exclusive
- Added `dignity_ownership()`, `place_quality_fields()`
- Solar elongation: `free_of_beams` / combust / under_beams / cazimi; not naked-eye visible

### Timing (`astro_backend_classical_timing.py`)
- Decennials rewritten: 129-month minor-years profile `decennials_129_month_minor_years_v1`
- Fully decoupled from Firdaria
- ZR: explicit `l1/l2/l3_*` fields; top-level remains L1

### Primary directions
- Event date always `birth + abs(arc)/key`
- `symbolic_date_from_signed_arc` suppressed (no pre-birth)
- `symmetric_duplicate_under_proxy` on A↔B conjunction pairs
- Independent `aspect` field

### Distributions PD
- Renamed `ptolemy_key_proxy` → `one_degree_per_year_proxy`
- Renamed `converse_naibod_proxy` → `sign_reversal_test_naibod` (test-only, exclude concordance)

### Circumambulations
- Period-based output (`periods` with start/end dates, ages, current_period)

### Hyleg / Alcocoden / Almuten
- Hyleg: eligible vs selected; unique selected; profile flags; no longevity years
- Alcocoden: witness required; rejection_reason
- Almuten: profile title “当前profile下的Almuten Figuris”; contribution sources

### Returns
- Cycle clustering, hit_number/total_hits, postnatal recrossing, valid_until semantics

### Lots
- formula_normalized, duplicate_formula_group, alias_of, operand longitudes

### Prenatal syzygy
- Full-moon axis fields; degree_selection_profile; selected_luminary

### Hellenistic audit
- enclosure → `longitude_bracketed_by_malefics_proxy`
- Chariot only when under beams/combust (non-Sun)

## Modern modules

### Method families (`method_families_v2`)
- `secondary_armc_naibod`: ARMC + Naibod → `houses_armc` rebuild
- `secondary_mc_from_true_solar_arc`: MC + true SA → ARMC invert → rebuild
- `armc_361_ecliptic_proxy_experimental`: explicit experimental proxy
- Solar arc profiles renamed with legacy aliases

### Solar arc
- Arc method keys: true_sun / naibod_mean / custom_key
- Natal speed → `natal_speed_metadata`; SA rate separate
- House fields: natal original / SA in natal house / directed house
- Internal patterns default off; optional `natal_pattern_rotated`
- Activation clusters for multi-target SA hits

### Location service
- New `astro_backend_location_service.py` shared city DB (incl. Osaka)
- Relocation resolves city query / location_id via service

### Modern cycles
- Eclipse + lunation merge into `eclipse_lunation` group fields
- `location_visibility=not_requested` when global

### Ephemeris
- `build_houses_from_armc`, `armc_from_mc`, natal `ARMC` on angles

## Tests added/updated
- `python_tests/test_technique_maintenance_classical.py` (fixture chart suite)
- `python_tests/test_method_families.py` (ARMC rebuild assertions)
- `python_tests/test_distributions_pd.py` (new profile names)
- `python_tests/test_classical.py` (solar phase / bounds / syzygy)

## Field compatibility notes
| Old | New | Notes |
|---|---|---|
| solar_condition=`visible` | `free_of_beams` / display `脱离日光` | Not naked-eye |
| `ptolemy_key_proxy` | `one_degree_per_year_proxy` | Alias map kept |
| `converse_naibod_proxy` | `sign_reversal_test_naibod` | Test-only |
| `secondary_naibod` | `secondary_armc_naibod` | Full ARMC path |
| `secondary_solar_arc_mc` | `secondary_mc_from_true_solar_arc` | |
| `secondary_armc_361` | `armc_361_ecliptic_proxy_experimental` | Experimental |
| SA `speed` | `natal_speed_metadata` + null speed | |
| `enclosure_besiegement` | + `longitude_bracketed_by_malefics_proxy` | Legacy alias retained |
