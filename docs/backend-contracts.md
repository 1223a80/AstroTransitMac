# Backend Contracts

The backend reads one JSON request from stdin and writes one JSON response to stdout. Swift decodes those responses with Codable models, so field names and nullability matter.

## Entrypoint

Run the backend directly with:

```bash
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-classical-request.json
```

`transit_calc.py` calls `astro_backend_api.main()`, which requires an explicit supported `request.mode`. Unknown, misspelled, or empty modes return a JSON error instead of silently falling back to moment calculation. Supported modes are `moment`, `classical`, `vedic`, `horary`, `scan`, `rectify`, `synastry`, `composite`, `davison`, `progression`, `solar_arc`, and `harmonic`.

Moment objects accept fixed offsets such as `GMT+5:30` and IANA zone names. For an IANA local time inside a DST spring-forward gap, the backend rejects the nonexistent time. For an ambiguous fall-back time, callers must include `fold: 0` or `fold: 1`.

## Classical Top-Level Fields

Classical mode currently returns:

- `meta`
- `angles`
- `houses`
- `planets`
- `lots`
- `experimental_lots`
- `aspects`
- `receptions`
- `antiscia`
- `primary_directions`
- `circumambulations`
- `timing`
- `planetary_returns`
- `prenatal_syzygy`
- `almuten_figuris`
- `hyleg_alcocoden`
- `warnings`
- `ambiguity`
- `calculation_assumptions`

There is no standalone `solar_return` top-level field. Solar return is one item inside `planetary_returns`.

## Planetary Returns

Every row in `planetary_returns` must use the same schema for Sun, Moon, Mercury, Venus, Mars, Jupiter, and Saturn:

```json
{
  "id": "moon",
  "body_id": "MOON",
  "body_name": "月亮",
  "title": "Lunar Return",
  "no_hit_in_user_window": false,
  "suggested_window": null,
  "previous_return": {},
  "current_cycle_return": {},
  "next_return": {},
  "search_start_local": "YYYY-MM-DD HH:MM",
  "search_end_local": "YYYY-MM-DD HH:MM"
}
```

If a search truly fails, keep the three return keys present and set their values to `null`.

`current_cycle_return` is the previous exact return relabeled as the active cycle. Keep `previous_return` as the historical snapshot too, because callers may need both stable labels.

Do not write bare titles such as `Lunar Return 2026-05-17` into the timeline or exports. Use explicit labels such as `Current Lunar Return（当前生效）`, `Previous ...`, or `Next ...`.

## Prenatal Syzygy

`prenatal_syzygy` must include:

- `syzygy_type`: `new_moon` or `full_moon`
- `exact_utc`
- `longitude`
- `sun_position`
- `moon_position`
- `sign`
- `degree`
- `ruler`
- `ruler_id`
- `dignity_rulers`
- `syzygy_degree_used`
- `method_variant`
- `ephemeris`
- `_method`
- `_source_tradition`

The current implementation refines the nearest prenatal new/full moon with Swiss Ephemeris positions. Julian Day conversion uses J2000 noon, not midnight.

For full moons, keep both Sun and Moon positions. Current convention is:

```text
syzygy_degree_used = Sun degree (sun_position; full moon axis, Moon opposite)
```

Regression check: with birth JD for `2004-08-01 00:00 UTC`, the prenatal full moon exact time is `2004-07-31 18:05 UTC`, with Sun near `128.8486` and Moon near `308.8485`.

## Zodiacal Releasing Loosing Of The Bond

Do not treat a normal next-sign transition as Loosing of the Bond.

Loosing of the Bond is flagged only when the active sequence jumps to the loosening point, the sign opposite the relevant origin sign, and that destination is not the ordinary next sign.

Must remain unflagged:

- Leo -> Virgo
- Pisces -> Aries

When flagged, `loosing_of_bond_detail` should describe the jump and the relevant level (`L1`, `L2`, or `L3`).

## Hyleg / Alcocoden

This module is audit-oriented. Do not output longevity years.

`hyleg_alcocoden.hyleg.candidates` should include every candidate checked and a non-empty reason for selection or rejection. At minimum, Sun rejected reason, Moon rejected reason, and ASC selected reason need to be visible when those cases apply.

`hyleg_alcocoden.alcocoden.candidates` must audit these five planets even when a planet has no dignity at the Hyleg degree:

- Saturn
- Mercury
- Mars
- Jupiter
- Venus

Use `dignity_at_hyleg: "none"` and `weight: 0` for audited non-rulers.
