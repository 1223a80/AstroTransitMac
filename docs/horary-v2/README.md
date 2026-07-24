# Horary Data Packet v2

Canonical judgment-free data pipeline for horary charts.

- **Schema ID**: `horary-data-packet/2.1`
- **JSON Schema (production)**: [`docs/schemas/horary-data-packet-2.1.json`](../schemas/horary-data-packet-2.1.json)
- **JSON Schema (historical 2.0)**: [`docs/schemas/horary-data-packet-2.0.json`](../schemas/horary-data-packet-2.0.json)
- **Engine**: `Sources/TransitStudio/Resources/backend/astro_backend_horary_v2.py` (+ `*_aspects` / `*_modules`)
- **Legacy adapter**: `packetVersion=1` → `astro_backend_horary.calculate_horary` (deprecated interpretive packet)

## v2.1 notes

- Full `aspect_candidates` (not gated by display orb).
- `horaryHouseSystem` default Regiomontanus; independent `horaryAspectOrb`.
- Event graph / nodes / considerations / fixed stars / declination / antiscia contacts / pheno.
- AI consumes full Markdown (not summary).

## Boundary

| Layer | Contents |
|---|---|
| inputs | question text, place, time, location, calculation config |
| computed_data | geometry, dignities (assignment only), pairwise, aspects, events, lots, VOC rules with `rule_id` |
| validation | technical warnings, root status, forbidden-field scan |

**Not in v2**: machine summary, radicality caution labels, significator selection, key links, scores, bonification/maltreatment, Translation/Collection/Prohibition/Frustration as judgment.

## Request

```json
{
  "mode": "horary",
  "packetVersion": "2",
  "chart": { "moment": { "...": "..." }, "latitude": 0, "longitude": 0, "houseSystem": "regiomontanus", "zodiac": "tropical", "boundsSystem": "egyptian", "triplicitySystem": "dorothean" },
  "questionText": "...",
  "placeName": "...",
  "aspectOrb": 3
}
```

Default when `packetVersion` omitted: **2**.
Unknown packet versions are rejected instead of being silently routed to the current v2 engine.

## Top-level fields

`schema`, `question_metadata`, `calculation_config`, `provenance`, `time_and_location`, `houses`, `angles`, `bodies`, `dignities`, `pairwise_geometry`, `aspects`, `aspect_candidates`, `aspects_in_display_orb`, `display_orb_deg`, `receptions`, `lots`, `events`, `event_graph`, `moon`, `visibility`, `planetary_day_hour`, `considerations_evidence`, `nodes`, `optional_modules`, `validation`, `display`

## Markdown / AI

`MarkdownExportBuilder.horary` and Python `format_horary_v2_markdown` are lossless formatters of the canonical packet. AI analysis receives this data-only Markdown.

## Migration

See [MIGRATION.md](./MIGRATION.md).

## Samples

- JSON: `docs/examples/horary-data-packet-v2-sample.json`
- Markdown: `docs/examples/horary-data-packet-v2-sample.md`
- Example request: `Examples/sample-horary-request.json`
