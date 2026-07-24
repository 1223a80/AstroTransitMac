# Horary Packet Migration Guide (v1 → v2)

## Version negotiation

| Request | Response |
|---|---|
| `packetVersion` omitted or `"2"` | v2 data packet (`horary-data-packet/2.1`; early builds used `/2.0`) |
| `"1"` / `"legacy"` / `"v1"` | legacy interpretive packet (`horary-data-packet/1.0`, deprecated) |

## Field mapping

| v1 field | v2 fate |
|---|---|
| `meta.*` | Split into `time_and_location`, `calculation_config`, `provenance` |
| `question_text` | `question_metadata.question_text` |
| `angles` / `houses` / `planets` | `angles` / `houses` / `bodies` (richer numeric fields) |
| `aspects` | `aspects` aliases full `aspect_candidates` (v2.1); `aspects_in_display_orb` is the display-orb subset; plus full `pairwise_geometry` |
| `receptions` | `receptions` (directed matrix, no strength labels) |
| `lots` | `lots` (formulas retained; no score/supported_by) |
| `moon_storyline` | `moon` index + `events` timeline |
| `moon_voc_criterion` / VOC bool | `moon.void_of_course_rules[]` with `rule_id` + evidence |
| `planetary_speeds` / `solar_condition` | folded into `bodies.motion` and `visibility` |
| `machine_summary` | **removed** (interpretation) |
| `radicality_flags` | **removed** (judgment); use raw ASC degree / VOC rules if needed |
| `significator_candidates` | **removed** → legacy analysis only |
| `key_significator_links` / `degree_based_key_aspects` | **removed**; use full `aspects` / `pairwise_geometry` |
| `negative_receptions` | **removed** as separate list; detriment/fall are dignity facts |
| `advanced_candidates` (Translation/…) | **removed** from data packet; legacy only |
| `planets[].score` / `bonification` / `maltreatment` | **removed** |
| `lots_summary` | use `lots` |
| `warnings` | `validation.warnings` |

## Consumers

| Consumer | Migration |
|---|---|
| Swift UI / Markdown / CSV / AI | Uses `HoraryDataPacket` v2 only |
| Python `calculate_horary` unit tests | Still call legacy functions directly |
| CLI / transit_calc default | v2 |
| External callers needing significators | Pass `packetVersion: "1"` (deprecated) |

## Determinism

v2 includes `provenance.input_hash_sha256` and `config_hash_sha256`. Same inputs yield the same hashes and stable array orderings (sorted IDs / time offsets).
