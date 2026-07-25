# Technique Maintenance — Root Causes (2026-07-25)

Branch: `fix/classical-modern-technique-maintenance`  
Fixture chart: 2004-08-09T08:16:00Z / 35.0576N 118.3346E / Whole Sign / Egyptian / Dorothean / ref 2026-07-25T08:44:00Z

## Classical

| ID | Problem | File(s) | Function / area | Root cause |
|---|---|---|---|---|
| C1 | Jupiter Virgo 20°10′ bound = Mars | `astro_backend_classical_dignity.py` | `EGYPTIAN_BOUNDS[5]`, `bounds_ruler` | Virgo Egyptian table wrong (Ven13/Jup17/Mar21); upper edge inclusive |
| C1 | Bound/decan shown as owned when not | same + `astro_backend_classical.py` | `dignity_labels`, planet rows | No separate ownership fields; bound name always printed |
| C2 | Decennials = Firdaria windows | `astro_backend_classical_timing.py` | `DECENNIALS_SEQUENCE_*`, `decennials_summary` | Reused Firdaria year lengths (10/8/13…); claimed “70-year cycle” |
| C3 | Converse PD pre-birth dates | `astro_backend_primary_directions.py`, `distributions_pd.py` | `_make_direction`, `_rekey_direction` | `symbolic_date = birth + signed_age` for negative arcs |
| C3 | SATURN↔DSC double count | `astro_backend_primary_directions.py` | post-process | A→B and B→A both emitted without `symmetric_duplicate_under_proxy` |
| C4 | ZR “LL3” collapse | `astro_backend_classical_timing.py`, `astro_backend_api.py` | `zodiacal_releasing_summary`, `ambiguity` | Finest level mixed into single summary without L1/L2/L3 fields |
| C5 | 2005 Saturn “current” until 2033 | `astro_backend_classical.py` | `return_summary` | Single previous hit labeled current_cycle without cycle clustering / postnatal flag |
| C6 | Multiple Hyleg selected/eligible conflation | `astro_backend_classical_audit.py` | `calculate_hyleg_alcocoden` | `eligible` used as selection; no exclusive `selected` |
| C7 | Alcocoden without witness | same | same | Selected by dignity weight even when `sees_hyleg` false |
| C8 | Almuten “absolute strongest” | same | `calculate_almuten_figuris` | No profile metadata; title implied absolute |
| C10 | Circumamb boundary misread | `astro_backend_circumambulations.py` | `calculate_circumambulations` | End-degree table looked like start-of-bound |
| C11 | ptolemy_key / converse_naibod overclaim | `astro_backend_distributions_pd.py` | `PD_PROFILES` | 1°/y called Ptolemy; arc negation called converse |
| C12–14 | Sect / place / visibility collapsed | `astro_backend_classical_dignity.py`, `classical.py` | sect/solar/house fields | Single labels mixed angularity, place quality, naked-eye visibility |
| C15 | enclosure/chariot overclaim | `astro_backend_hellenistic_audit.py` | enclosure + chariot blocks | Longitude neighbors only; chariot without under-beams requirement |
| C17 | Duplicate lots counted independent | `astro_backend_classical_lots.py` | `calculate_lots` | No `formula_normalized` / `duplicate_formula_group` |
| C18 | Full moon only “Sun degree” | `astro_backend_classical_audit.py` | `calculate_prenatal_syzygy` | Axis not explicit; profile selection unclear |

## Modern

| ID | Problem | File(s) | Root cause |
|---|---|---|---|
| M13 | ASC/MC = natal + ~1°/y | `astro_backend_method_families.py` | Ecliptic proxy, no ARMC rebuild |
| M3 | SA speed = natal speed | `astro_backend_solar_arc.py` | Copied natal `speed` onto SA points |
| M3 | SA internal patterns as “new” | same | Patterns on SA-only points (rotated natal) |
| M7 | new_moon + solar_eclipse double | `astro_backend_cycles.py` | Separate scans, no eclipse_lunation merge |
| M1 | City coords inconsistent | no shared service | Each module accepted free lat/lon without city DB |

## Limitations (still proxy / incomplete)

- Full Placidus/Regiomontanus primary directions (latitude, true converse engines)
- Full traditional Hyleg/Alcocoden longevity
- Full Hellenistic enclosure (rays, intervention, rescue)
- Full heliacal visibility (atmospheric models) as default planet `visible` flag
- Full Local Space great-circle validation globally
- Full harmonic ASC/MC house systems
- armc_361 complete RAMC (only experimental ecliptic proxy remains)
- MC→ARMC inversion residual arcseconds vs full spherical solution
