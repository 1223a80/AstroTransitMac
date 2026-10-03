# Horary V3

V3 is an opt-in backend pipeline producing `horary-data-packet/3.0`. The application
continues to request V2.1 by default. V1 and V2 routes and their fixtures are unchanged.

## Run

```bash
python3 Sources/TransitStudio/Resources/backend/transit_calc.py < Examples/sample-horary-v3-request.json
```

Use `mode: "horary"` with `packetVersion: "3"`, `"v3"`, or `"3.0"`. The snake-case
`packet_version` alias also works. Python callers use
`astro_backend_horary_v3.calculate_horary_v3(request, warnings)` and
`format_horary_v3_markdown(packet)`.

## Ownership

| Module | Responsibility |
| --- | --- |
| `astro_backend_horary_v3.py` | Chart context and pipeline orchestration |
| `astro_backend_horary_v3_config.py` | Validated input, defaults and UTC windows |
| `astro_backend_horary_v3_search.py` | Request-local ephemeris cache, sampled root search and event identity |
| `astro_backend_horary_v3_events.py` | Event families, search coverage and body indices |
| `astro_backend_horary_v3_moon.py` | Lunar sequence and VOC rules from the shared timeline |
| `astro_backend_horary_v3_packet.py` | Serialization, provenance and cross-reference validation |
| `astro_backend_horary_v3_markdown.py` | Selective Chinese worksheet for human reading |

The V3 entry point does not call `calculate_horary_v2`. It reuses existing fact
helpers and the dedicated V2 aspect/reception/optional-module calculators. Their
rule and algorithm identifiers remain unchanged; `provenance.shared_calculators`
records that reuse. This release restructures the pipeline and event computation;
it does not redefine traditional dignity, reception or perfection rules.

## Protocol Changes

- The major schema is `3.0`; existing top-level fact blocks and compatibility
  aliases remain available. `event_search` is a new required block.
- `events` contains sampled geometric crossings throughout the requested window:
  classical aspects, sign ingresses, stations, fixed-cusp house changes, solar
  condition boundaries, new/full moons and sunrise/sunset. VOC endpoints describe
  the current lunar sign only, under the two retained rule definitions.
- Geometric aspect events may occur after a sign exit or a station. They are
  distinct from a candidate's rule-qualified `next_exact`. An event's
  `candidate_id` links to the pair/aspect geometry, not a promise of perfection.
- All event windows use elapsed UTC days. Event timestamps preserve microseconds;
  `offset_seconds_from_query` is a number and can be fractional. IDs are opaque
  strings and must not be parsed for their components.
- `rule_ids` retains all rules attached to one event. VOC events also include
  `voc_rule_ids`; there is no singular `voc_rule_id`. `rule_id` remains a primary
  source label for compatible display consumers.
- Each search records `found`, `not_found_in_window`, or `unavailable`. Coverage
  states the searched interval, method and maximum step. A sampled search is not
  an analytic guarantee: multiple crossings inside one sample step can be missed.
  Longitude searches use the existing signed-angle crossing rule and UTC bisection
  to 0.01 seconds; steps are one hour for lunar paths, six hours otherwise.
- The configured past and future limits are each 0 through 400 days. This makes
  the previous 400-day event horizon an explicit resource limit instead of a
  silent truncation. Invalid or non-finite input is rejected before calculation.
- Body station indices retain +/-400 days. Next-sign indices retain the existing
  per-body horizon (up to 1200 days); lunar indices need four preceding and eight
  following days. An index outside the configured event window has
  `in_configured_window: false` and `event_id: null`. Its own timestamp and search
  coverage remain available. Lunar `source_event_id` refers to this internal search
  scope, which can extend beyond the exported `events` list.
- VOC values are `null` with `status: unavailable` when the required lunar search
  is incomplete. No false VOC boundaries are emitted in that state. Both rules
  retain their V2 definitions, including the second rule's four-day future window.
- `jd_tt` is null if Delta T is unavailable. Actual/requested house systems are
  reported separately. The position type is correctly labeled `apparent` for the
  existing Swiss Ephemeris flags; the coordinate calculation itself is unchanged.
- `validation.invariant_check` covers event uniqueness, ordering, window and offset
  consistency, candidate/body references, event graph references, body indices,
  forbidden judgment fields and JSON finiteness. Problems and their warnings are
  included in the returned packet. Check this field before treating a packet as
  validated. Search availability is reported separately in `event_search.status`.

The dedicated V2 candidate solver and optional module searches retain their own
search policies and evidence labels. V3's geometric event coverage does not assert
that those separate calculations have been redesigned or independently audited.

## Consumers And Validation

`docs/schemas/horary-data-packet-3.0.json` is the standalone JSON Schema. The existing
Swift `HoraryDataPacket` supports the shared blocks and preserves extra fields
through its lossless JSON representation. The new example participates in
the live backend-to-Swift contract gate.

## Python Reader Export

`format_horary_v3_markdown(packet)` produces a Chinese horary worksheet, not a
diagnostic dump. Its selection follows the practical questions of choosing
significators, assessing their condition, examining contact and reception, and
following the Moon. It does not infer the question's house from prose or add a
success/failure judgment. Without an explicitly chosen question house it retains
all twelve cusp rulers and the seven bodies as the minimum generic reference.

- Positions, houses, motion/speed, solar classifications and essential dignities
  remain visible in compact tables. Dignity rulers provide a reference for
  reception beyond the selected aspect pairs.
- Aspect rows are the union of the configured display-orb set and candidates
  whose found next exact time lies after the query and within the configured
  future window. No arbitrary row cap is used; out-of-orb rows are labeled.
  Known sign exits, stations/retrograde and refranation are preserved. Absent
  roots are not promises that no later geometric contact exists.
- Directed reception positions are aggregated only for those aspect pairs.
  Detriment/fall relationships are explicitly distinct from positive reception.
- The lunar sequence contains its most recent exact aspect in the current sign,
  all remaining exact aspects before exit, exit itself, and the first contact
  in the next sign. The sign-exit VOC rule is named by definition; alternative
  rule conflicts or invalid intervals are reported without silently repairing
  them. No automated translation/collection or prohibition verdict is added.
- Fortune is the only default lot. Planetary day/hour rulers and triggered
  early/late ASC, Moon via combusta or Saturn seventh-house facts are auxiliary.
- The full candidate matrix, long event stream, other lots, optional contacts,
  raw ephemeris and search audit remain in JSON, not in a Markdown appendix.
  Regenerate from a saved packet without recalculating or changing its moment.

All displayed times are converted from UTC to the requested IANA or fixed-offset
zone, retaining the offset to distinguish DST folds. Positions round to seconds
with carry. Unknown states are not rendered as false; user text is escaped.
This Python reader export does not change the existing Swift exporter or V2.1.

```bash
python3 -m pytest python_tests/test_horary_v3.py python_tests/test_horary_v3_markdown.py python_tests/test_horary_v2.py
bash check_vibe_changes.sh
```

Tests include independent Swiss Ephemeris crossing checks, repeated lunar events,
V2 fact comparisons, request immutability, deterministic output, short search tails,
DST, invalid numbers, missing computations, rule identity, invariant failures,
version routing, schema validation, Swift decoding and export round trips.
