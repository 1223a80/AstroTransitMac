# Horary Data Packet v2.1 — Field Dictionary (summary)

Units unless noted: degrees in [0, 360) for longitudes; signed degrees for directed orbs; AU for distance; deg/day for speeds; seconds for offsets. Times ISO-8601 UTC with `Z`.

Schema ID: `horary-data-packet/2.1`. JSON Schema: `docs/schemas/horary-data-packet-2.1.json`.

## provenance

| Field | Meaning |
|---|---|
| `engine_name` / `engine_version` | Computation engine identity |
| `algorithm_version` | Rule bundle version string |
| `ephemeris_provider` / `ephemeris_version` | Swiss Ephemeris identity |
| `input_hash_sha256` | SHA-256 of canonical input object |
| `config_hash_sha256` | SHA-256 of calculation_config |

## calculation_config

| Field | Default / notes |
|---|---|
| `house_system` | Horary default `regiomontanus` (independent of natal/classical) |
| `aspect_orb_deg` | **Display orb only** — does not gate candidate computation |
| `event_window` | past/future days for timeline + exact roots |

## bodies[]

Ecliptic / equatorial / horizontal geometry, house (integer + continuous), motion with thresholds, `accidental` (angular/succedent/cadent, hayz evidence, oriental/occidental, speed vs mean, station proximity — all with `rule_id`, no strength scores), `distance_to_angles_deg`, `events_index` (`previous_house_change` / `next_house_change` / stations / sign exit), `precision`.

## dignities[]

Assignment-only: domicile/exaltation/detriment/fall, triplicity, bounds, decan, peregrine flag. No scores.

## pairwise_geometry[]

All seven-planet pairs: delta, relative speed, `motion_direction` (converging/diverging from relative geometry — **not** gated by display orb).

## aspect_candidates[] / aspects[] / display_orb_deg

- `aspect_candidates`: full 7×6/2×5 = 105 classical pair × Ptolemaic aspects with orbs, application, exact times, sign-exit/station-before-exact, `within_display_orb`, refranation flags.
- `aspects` (v2.1): **aliases the full candidate matrix** (compat name); not a display-orb subset.
- `aspects_in_display_orb`: rows where `within_display_orb` is true (display filter only).
- `display_orb_deg`: user display filter only; does not gate candidate geometry or events.
- AI/export should prefer `aspect_candidates` (or `aspects`) for full matrix and `aspects_in_display_orb` for the filtered view.

## receptions[]

Directed dignity relations including domicile/exaltation/triplicity/bound/decan/**detriment/fall**, mutual/mixed tags, `relation_at_next_aspect_exact` + sign-exit change evaluation. Neutral field names only.

## lots[]

`input_points`, `intermediates`, `longitude_before_normalize_deg`, normalized `longitude_deg`, formulas, sect. No confidence tags.

## events[] / event_graph

Flat timeline: `aspect_exact`, `sign_ingress`, `house_change`, stations, sunrise/sunset, lunar phase, VOC boundaries, solar thresholds.
`event_graph`: per-body prev/next, aspect candidate sequences with `positions_at_exact`, moon ordered contacts — facts for manual ToL/Collection/etc., **not** those conclusions.

## moon

In-sign past/future exacts, next-sign sequence, multi-`rule_id` VOC with intervals, phase/illumination.

## nodes

Mean (default) and optional true lunar nodes; south node source recorded; contacts to bodies/angles; **not** domicile rulers.

## planetary_day_hour / considerations_evidence

Sunrise/sunset bounds, day/hour rulers, unequal hours, polar reason codes; ASC early/late, Via Combusta, Saturn–H7, VOC, hour/ASC ruler match — **evidence only**, no unified `radical=true/false`.

## visibility[]

`pheno_ut` phase angle (degrees), illuminated fraction (`0...1`), apparent diameter (converted from degrees to arcseconds), and magnitude when available; altitude/azimuth; heliacal fields when model allows. `visible = null` + `reason_code` when atmosphere/model insufficient — never invented.

## optional_modules

| Key | Content |
|---|---|
| `declination_contacts` | Parallel / contra-parallel with independent declination orb |
| `declination_moon_sequence` | Moon prev/next declination contacts |
| `antiscia` / `antiscia_contacts` | Positions + contact matrix (bodies, angles, cusps, lots, nodes) |
| `fixed_stars` | Versioned core traditional catalog + contacts/events |
| `via_combusta` / `dodecatemoria` | Neutral placement facts |
| `nodes` | Mean/true node mode + node body rows (mirrors top-level `nodes`) |

No `not_computed_in_core` placeholder keys are emitted: every key carries real data. Declination parallel data lives under `declination_contacts` (there is no separate `declination_parallels` key).

## Markdown

- **App / Swift** (`MarkdownExportBuilder.horary`): compact field-level Markdown for humans and AI; deliberately selective.
- **Backend diagnostic helper** (`format_horary_v2_markdown`): separate structural formatter used by Python-side diagnostics; it may retain serialized evidence fragments and is not the app export path.
- **Summary**: human skim only (`docs/examples/horary-data-packet-v2-summary.md`).
- **Lossless source**: JSON export only; neither Markdown formatter is a lossless packet representation.

## Forbidden judgment fields

`machine_summary`, significator selection, yes/no, radical unified conclusion, ToL/Collection/Prohibition/Frustration as verdicts, strength/confidence scores.

## Known limitations

- Photometric absolute visibility requires atmosphere model; otherwise `visible=null` + reason.
- Fixed stars default to core traditional set, not full SE catalog dump into main packet.
- Continuous house uses ecliptic longitude (stated on packet).
- Nested JSON Schema still allows `additionalProperties` on some evidence objects for forward evolution; top-level packet is closed.
- Legacy `packetVersion=1` interpretive packet remains available but deprecated for production.
