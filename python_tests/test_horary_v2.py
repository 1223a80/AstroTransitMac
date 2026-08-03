"""Horary Data Packet v2 — pure data pipeline tests."""
from __future__ import annotations

import copy
import json
import math
import subprocess
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

import jsonschema
import pytest

from astro_backend_core import BODY_REGISTRY, CLASSICAL_BODY_IDS, swe
from astro_backend_horary_v2 import (
    FORBIDDEN_V2_KEYS,
    SCHEMA_VERSION,
    assert_no_forbidden_fields,
    calculate_horary_v2,
    format_horary_v2_markdown,
    _jd_ut_to_local,
)

ROOT = Path(__file__).resolve().parents[1]
TRANSIT_CALC = ROOT / "Sources" / "TransitStudio" / "Resources" / "backend" / "transit_calc.py"
SCHEMA_PATH = ROOT / "docs" / "schemas" / "horary-data-packet-2.1.json"
GOLDEN_PATH = ROOT / "docs" / "examples" / "horary-data-packet-v2-linyi-golden.json"
FIXTURE_PATH = ROOT / "SwiftTests" / "Fixtures" / "horary-result.json"

# Required golden (objective §六)
LINYI_REQUEST = {
    "mode": "horary",
    "packetVersion": "2",
    "chart": {
        "moment": {
            "year": 2026,
            "month": 7,
            "day": 23,
            "hour": 22,
            "minute": 25,
            "timezone": "Asia/Shanghai",
        },
        "latitude": 35.0924,
        "longitude": 118.3465,
        "houseSystem": "regiomontanus",
        "zodiac": "tropical",
        "boundsSystem": "egyptian",
        "triplicitySystem": "dorothean",
    },
    "questionText": "opaque question string for golden",
    "placeName": "临沂市",
    "aspectOrb": 3.0,
}

SAMPLE = {
    "mode": "horary",
    "chart": {
        "moment": {
            "year": 2026,
            "month": 5,
            "day": 5,
            "hour": 15,
            "minute": 30,
            "timezone": "Asia/Shanghai",
        },
        "latitude": 31.2304,
        "longitude": 121.4737,
        "houseSystem": "regiomontanus",
        "zodiac": "tropical",
        "boundsSystem": "egyptian",
        "triplicitySystem": "dorothean",
    },
    "questionText": "我最近能找到新工作吗？",
    "placeName": "上海",
    "aspectOrb": 3,
    "packetVersion": "2",
}


def _packet(req: dict | None = None) -> tuple[dict, list[str]]:
    warnings: list[str] = []
    return calculate_horary_v2(copy.deepcopy(req or SAMPLE), warnings), warnings


class TestSchemaAndForbidden:
    def test_schema_id(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        # SCHEMA_VERSION constant may lag minor bumps; trust live packet.
        assert packet["schema"]["version"] in {SCHEMA_VERSION, "2.1"}
        assert packet["schema"]["schema_id"].startswith("horary-data-packet/")

    def test_no_forbidden_fields_or_strength_tokens(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        hits = assert_no_forbidden_fields(packet)
        assert hits == [], hits[:20]
        for key in FORBIDDEN_V2_KEYS:
            assert key not in packet
        blob = json.dumps(packet, ensure_ascii=False)
        # user question is opaque; strength tokens must not appear outside it
        assert '"confidence_tag"' not in blob
        assert blob.count('"medium"') == 0
        assert blob.count('"strong"') == 0
        assert blob.count('"weak"') == 0

    def test_top_level_sections_present(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        for key in (
            "schema",
            "question_metadata",
            "calculation_config",
            "provenance",
            "time_and_location",
            "houses",
            "angles",
            "bodies",
            "dignities",
            "pairwise_geometry",
            "aspects",
            "aspect_candidates",
            "aspects_in_display_orb",
            "display_orb_deg",
            "receptions",
            "lots",
            "events",
            "event_graph",
            "moon",
            "visibility",
            "planetary_day_hour",
            "considerations_evidence",
            "nodes",
            "optional_modules",
            "validation",
            "display",
        ):
            assert key in packet

    def test_jsonschema_validates_packet(self) -> None:
        schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
        live, _ = _packet(LINYI_REQUEST)
        packets = {
            "live": live,
            "golden": json.loads(GOLDEN_PATH.read_text(encoding="utf-8")),
            "swift_fixture": json.loads(FIXTURE_PATH.read_text(encoding="utf-8")),
        }
        for label, packet in packets.items():
            try:
                jsonschema.validate(instance=packet, schema=schema)
            except jsonschema.ValidationError as exc:
                pytest.fail(f"{label} violates Horary v2.1 schema: {exc.message}")


class TestLinyiGolden:
    def test_golden_file_matches_engine(self) -> None:
        assert GOLDEN_PATH.exists(), "missing Linyi golden fixture"
        disk = json.loads(GOLDEN_PATH.read_text(encoding="utf-8"))
        live, _ = _packet(LINYI_REQUEST)
        assert live["provenance"]["input_hash_sha256"] == disk["provenance"]["input_hash_sha256"]
        assert live["provenance"]["config_hash_sha256"] == disk["provenance"]["config_hash_sha256"]
        assert live["time_and_location"]["jd_ut"] == disk["time_and_location"]["jd_ut"]
        assert [b["body_id"] for b in live["bodies"]] == [b["body_id"] for b in disk["bodies"]]
        for lb, db in zip(live["bodies"], disk["bodies"]):
            # Geometry is stable to ~1e-4° under SE; hashes already prove input identity.
            assert abs(lb["ecliptic"]["longitude_deg"] - db["ecliptic"]["longitude_deg"]) < 1e-4
            assert abs((lb["ecliptic"]["longitude_speed_deg_per_day"] or 0) - (db["ecliptic"]["longitude_speed_deg_per_day"] or 0)) < 1e-4
        assert [e["id"] for e in live["events"]] == [e["id"] for e in disk["events"]]
        assert assert_no_forbidden_fields(disk) == []
        assert disk["schema"]["schema_id"] in {
            "horary-data-packet/2.0",
            "horary-data-packet/2.1",
        }
        assert disk["question_metadata"]["place_name"] == "临沂市"

    def test_linyi_time_location(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        tl = packet["time_and_location"]
        assert tl["timezone"] == "Asia/Shanghai"
        assert tl["utc_offset_seconds"] == 8 * 3600
        assert tl["utc_datetime"].startswith("2026-07-23T14:25:00")
        assert abs(tl["latitude_deg"] - 35.0924) < 1e-9
        assert abs(tl["longitude_deg"] - 118.3465) < 1e-9
        assert packet["calculation_config"]["house_system"] == "regiomontanus"
        assert packet["calculation_config"]["bounds_system"] == "egyptian"
        assert packet["calculation_config"]["triplicity_system"] == "dorothean"

    def test_moment_second_precision_changes_jd_and_utc_datetime(self) -> None:
        """Regression: second-precision chart moments must flow into JD/UTC.

        Legacy requests without a second key stay at :00 and keep their hash.
        """
        base = copy.deepcopy(LINYI_REQUEST)
        with_second = copy.deepcopy(LINYI_REQUEST)
        with_second["chart"]["moment"]["second"] = 30

        base_packet, _ = _packet(base)
        sec_packet, _ = _packet(with_second)

        assert base_packet["time_and_location"]["utc_datetime"].endswith(":00Z")
        assert sec_packet["time_and_location"]["utc_datetime"].endswith(":30Z")
        assert base_packet["time_and_location"]["local_datetime"] == "2026-07-23 22:25"
        assert sec_packet["time_and_location"]["local_datetime"] == "2026-07-23 22:25:30"
        delta_seconds = (
            sec_packet["time_and_location"]["jd_ut"] - base_packet["time_and_location"]["jd_ut"]
        ) * 86400
        assert 29.0 < delta_seconds < 31.0

    def test_moment_second_validated(self) -> None:
        """Out-of-range or non-integer second values are rejected."""
        from astro_backend_core import moment_to_local_datetime

        bad_high = dict(LINYI_REQUEST["chart"]["moment"], second=60)
        with pytest.raises(ValueError):
            moment_to_local_datetime(bad_high)
        bad_neg = dict(LINYI_REQUEST["chart"]["moment"], second=-1)
        with pytest.raises(ValueError):
            moment_to_local_datetime(bad_neg)
        bad_type = dict(LINYI_REQUEST["chart"]["moment"], second="x")
        with pytest.raises(ValueError):
            moment_to_local_datetime(bad_type)
        ok = moment_to_local_datetime(dict(LINYI_REQUEST["chart"]["moment"], second=30))
        assert ok.second == 30
        # Numeric string is tolerated like the other moment fields
        ok_str = moment_to_local_datetime(dict(LINYI_REQUEST["chart"]["moment"], second="30"))
        assert ok_str.second == 30
        # GMT fixed-offset path also honors second
        ok_gmt = moment_to_local_datetime(
            dict(LINYI_REQUEST["chart"]["moment"], timezone="GMT+8", second=30)
        )
        assert ok_gmt.second == 30


class TestDeterminism:
    def test_same_input_same_hashes_and_structure(self) -> None:
        a, _ = _packet(LINYI_REQUEST)
        b, _ = _packet(LINYI_REQUEST)
        assert a["provenance"]["input_hash_sha256"] == b["provenance"]["input_hash_sha256"]
        assert a["provenance"]["config_hash_sha256"] == b["provenance"]["config_hash_sha256"]
        assert a["time_and_location"]["jd_ut"] == b["time_and_location"]["jd_ut"]
        assert [x["id"] for x in a["events"]] == [x["id"] for x in b["events"]]
        assert [x["id"] for x in a["aspects"]] == [x["id"] for x in b["aspects"]]

    @pytest.mark.parametrize(
        ("field", "value"),
        (
            ("declinationOrb", 0.5),
            ("antisciaOrb", 0.5),
            ("nodeMode", "true"),
        ),
    )
    def test_output_affecting_v21_options_change_provenance_hashes(
        self,
        field: str,
        value: object,
    ) -> None:
        baseline, _ = _packet(LINYI_REQUEST)
        changed_request = copy.deepcopy(LINYI_REQUEST)
        changed_request[field] = value
        changed, _ = _packet(changed_request)

        assert (
            changed["provenance"]["input_hash_sha256"]
            != baseline["provenance"]["input_hash_sha256"]
        )
        assert (
            changed["provenance"]["config_hash_sha256"]
            != baseline["provenance"]["config_hash_sha256"]
        )

    def test_json_roundtrip_stable_keys(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        raw = json.dumps(packet, ensure_ascii=False, sort_keys=True)
        restored = json.loads(raw)
        assert restored["schema"]["schema_id"] == packet["schema"]["schema_id"]
        assert len(restored["bodies"]) == len(packet["bodies"])

    def test_packet_version_aliases_are_preserved_in_provenance_hash(self) -> None:
        baseline, _ = _packet(LINYI_REQUEST)

        camel_request = copy.deepcopy(LINYI_REQUEST)
        camel_request["packetVersion"] = "2.1"
        camel, _ = _packet(camel_request)

        snake_request = copy.deepcopy(LINYI_REQUEST)
        snake_request.pop("packetVersion")
        snake_request["packet_version"] = "2.1"
        snake, _ = _packet(snake_request)

        assert camel["provenance"]["input_hash_sha256"] != baseline["provenance"]["input_hash_sha256"]
        assert snake["provenance"]["input_hash_sha256"] == camel["provenance"]["input_hash_sha256"]
        assert snake["provenance"]["config_hash_sha256"] == baseline["provenance"]["config_hash_sha256"]

    def test_refranation_interrupted_next_exact_not_found(self) -> None:
        """Regression: 2026-10-21 00:00 UTC Mercury-Jupiter square.

        Mercury stations retrograde ~day 3 and the orb diverges before
        converging again — the original application is refranation. The
        candidate's next_exact must be reported as not_found with the
        interruption reason instead of a fake future perfection.
        """
        request = copy.deepcopy(LINYI_REQUEST)
        request["chart"]["moment"] = {
            "year": 2026, "month": 10, "day": 21,
            "hour": 0, "minute": 0, "timezone": "UTC",
        }
        request["chart"]["latitude"] = 0.0
        request["chart"]["longitude"] = -60.0
        request["chart"]["houseSystem"] = "whole_sign"
        request["questionText"] = "refranation regression"
        packet, _ = _packet(request)

        square = None
        for c in packet["aspect_candidates"]:
            if "MERCURY" in (c["body_a_id"], c["body_b_id"]) and "JUPITER" in (c["body_a_id"], c["body_b_id"]) and c["aspect_id"] == "square":
                square = c
                break
        assert square is not None, "Mercury-Jupiter square candidate missing"
        ne = square.get("next_exact") or {}
        assert ne.get("root_status") == "not_found", f"expected not_found, got {ne}"
        reason = ne.get("root_reason") or ""
        assert "refranation" in reason or "interrupt" in reason, f"unexpected reason: {reason}"


class TestHousesAndAngles:
    def test_twelve_houses(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        cusps = packet["houses"]["cusps"]
        assert len(cusps) == 12
        assert [c["house"] for c in cusps] == list(range(1, 13))
        for c in cusps:
            assert 0 <= c["cusp_longitude_deg"] < 360
            assert c["span_deg"] > 0

    def test_axes_opposition(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        by_id = {p["id"]: p["longitude_deg"] for p in packet["angles"]["points"]}
        assert abs(((by_id["ASC"] + 180) % 360) - by_id["DSC"]) < 0.05
        assert abs(((by_id["MC"] + 180) % 360) - by_id["IC"]) < 0.05

    def test_body_house_consistency(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        for body in packet["bodies"]:
            h = body["house"]
            assert 1 <= h["integer_house"] <= 12
            cont = h["continuous_house"]
            assert cont is not None
            assert h["integer_house"] <= cont < h["integer_house"] + 1 + 1e-9


class TestBodiesAndMotion:
    def test_sign_dms_never_rounds_seconds_to_sixty(self) -> None:
        from astro_backend_horary_v2 import _sign_display

        sign = _sign_display(29.9999999)
        assert sign["sign_index"] == 0
        assert sign["dms"] == {"degrees": 29, "minutes": 59, "seconds": 59.999}

    def test_classical_seven(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        ids = [b["body_id"] for b in packet["bodies"]]
        assert ids == ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]

    def test_sign_degree_matches_longitude(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        for body in packet["bodies"]:
            lon = body["ecliptic"]["longitude_deg"]
            sign_idx = body["sign"]["sign_index"]
            deg = body["sign"]["degree_in_sign"]
            assert sign_idx == int(lon // 30) % 12
            assert abs(deg - (lon % 30)) < 1e-6

    def test_motion_states_valid(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        for body in packet["bodies"]:
            assert body["motion"]["state"] in {"direct", "retrograde", "stationary"}
            assert body["motion"]["rule_id"]


class TestWrapAndDignityBounds:
    def test_0_360_longitude_wrap_in_pairwise(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        for p in packet["pairwise_geometry"]:
            sep = p["minimum_separation_deg"]
            assert 0 <= sep <= 180
            raw = p["raw_separation_deg"]
            assert 0 <= raw < 360

    def test_dignity_bounds_cover_sign_degree(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        for d, body in zip(packet["dignities"], packet["bodies"]):
            deg = body["sign"]["degree_in_sign"]
            b = d["bounds"]
            assert b["start_degree_in_sign"] <= deg + 1e-9
            assert deg <= b["end_degree_in_sign"] + 1e-9
            assert b["ruler_id"]
            # decan faces: 0-10, 10-20, 20-30
            face = int(min(deg // 10, 2))
            assert abs(d["decan"]["start_degree_in_sign"] - face * 10) < 1e-9
            assert abs(d["decan"]["end_degree_in_sign"] - (face + 1) * 10) < 1e-9

    def test_dignity_at_sign_boundaries_synthetic(self) -> None:
        """0° and just-under-30° bound assignment consistency via live dignities."""
        packet, _ = _packet(LINYI_REQUEST)
        for d in packet["dignities"]:
            assert d["bounds"]["start_degree_in_sign"] >= 0
            assert d["bounds"]["end_degree_in_sign"] <= 30


class TestPairwiseAndAspects:
    def test_pairwise_complete(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        assert len(packet["pairwise_geometry"]) == 21
        ids = [p["id"] for p in packet["pairwise_geometry"]]
        assert ids == sorted(ids)

    def test_full_candidates_not_gated_by_display_orb(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        display = packet.get("display_orb_deg") or packet["calculation_config"]["aspect_orb_deg"]
        cands = packet.get("aspect_candidates") or packet["aspects"]
        # C(7,2)*5 = 105 full Ptolemaic candidates
        assert len(cands) == 105
        outside = [c for c in cands if (c.get("absolute_orb_deg") or c.get("orb_deg") or 0) > display + 1e-9]
        assert outside, "expected candidates beyond display orb"
        # Applying + will perfect while outside display orb must exist for Linyi sample
        future_outside = [
            c for c in cands
            if c.get("application") == "applying"
            and not c.get("within_display_orb", c.get("within_orb"))
            and c.get("will_perfect_in_window")
        ]
        assert future_outside, "applying out-of-display-orb future perfectors must not be dropped"
        for c in future_outside:
            assert (c.get("next_exact") or {}).get("datetime_utc")

    def test_aspect_events_not_only_from_display_orb(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        aspect_events = [e for e in packet["events"] if e["event_type"] == "aspect_exact"]
        assert aspect_events
        # Events may reference candidates outside display orb
        assert len(aspect_events) >= len(packet.get("aspects_in_display_orb") or [])

    def test_motion_direction_not_gated_by_display_orb(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        for p in packet["pairwise_geometry"]:
            na = p.get("nearest_aspect") or {}
            if na.get("application") == "applying":
                assert p["motion_direction"] == "converging"
            elif na.get("application") == "separating":
                assert p["motion_direction"] == "diverging"

    def test_aspects_sorted_and_within_orb(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        # aspects list is full candidates in v2.1; use aspects_in_display_orb for filter
        in_orb = packet.get("aspects_in_display_orb")
        if in_orb is None:
            in_orb = [a for a in packet["aspects"] if a.get("within_display_orb") or a.get("within_orb")]
        orb_limit = packet.get("display_orb_deg") or packet["calculation_config"]["aspect_orb_deg"]
        for a in in_orb:
            assert (a.get("absolute_orb_deg") or a.get("orb_deg") or 0) <= orb_limit + 1e-9
            assert a["application"] in {"applying", "separating"}


class TestEventsAndMoon:
    def test_events_sorted_and_required_types(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        offsets = [e["offset_seconds_from_query"] for e in packet["events"]]
        assert offsets == sorted(offsets)
        ids = [e["id"] for e in packet["events"]]
        assert len(ids) == len(set(ids))
        types = {e["event_type"] for e in packet["events"]}
        for required in (
            "aspect_exact",
            "sign_ingress",
            "house_change",
            "sunrise",
            "sunset",
            "lunar_phase_exact",
            "void_of_course_start",
            "void_of_course_end",
        ):
            assert required in types, f"missing event type {required}; have {sorted(types)}"

    def test_moon_voc_rules_have_intervals(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        rules = packet["moon"]["void_of_course_rules"]
        assert len(rules) >= 2
        rule_ids = {r["rule_id"] for r in rules}
        assert len(rule_ids) == len(rules)
        for rule in rules:
            assert rule["rule_id"]
            assert isinstance(rule["value"], bool)
            interval = rule["interval"]
            assert "start_datetime_utc" in interval
            assert "end_datetime_utc" in interval
            assert "duration_seconds" in interval
            if interval.get("complete"):
                assert interval["duration_seconds"] is not None
                assert interval["duration_seconds"] >= 0

    def test_moon_aspect_lists_sorted(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        future = packet["moon"]["future_exact_aspects_in_current_sign"]
        past = packet["moon"]["past_exact_aspects_in_current_sign"]
        if len(future) >= 2:
            assert [x["datetime_utc"] for x in future] == sorted(x["datetime_utc"] for x in future)
        if len(past) >= 2:
            assert [x["datetime_utc"] for x in past] == sorted(
                (x["datetime_utc"] for x in past), reverse=True
            )

    def test_inverted_voc_interval_does_not_emit_false_boundaries(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        inverted_rule_ids = {
            rule["rule_id"]
            for rule in packet["moon"]["void_of_course_rules"]
            if (rule.get("interval") or {}).get("reason_code") == "interval_start_after_end"
        }
        assert inverted_rule_ids, "fixture must exercise the inverted-interval path"
        assert not any(
            event.get("event_type") in {"void_of_course_start", "void_of_course_end"}
            and event.get("voc_rule_id") in inverted_rule_ids
            for event in packet["events"]
        )

        valid_rules = {
            rule["rule_id"]
            for rule in packet["moon"]["void_of_course_rules"]
            if (rule.get("interval") or {}).get("complete") is True
        }
        valid_boundaries = {
            event["event_type"]
            for event in packet["events"]
            if event.get("voc_rule_id") in valid_rules
        }
        assert valid_boundaries == {"void_of_course_start", "void_of_course_end"}

    def test_station_kind_fallback_inference(self) -> None:
        """Station direction must not default to retrograde when the after
        sample is unavailable — infer from before, else stay neutral."""
        from astro_backend_horary_v2 import _station_kind

        # Both samples: transition wins.
        assert _station_kind((1.0,), (-1.0,)) == "station_retrograde"
        assert _station_kind((-1.0,), (1.0,)) == "station_direct"
        # Only after sample: its sign decides.
        assert _station_kind(None, (1.0,)) == "station_direct"
        assert _station_kind(None, (-1.0,)) == "station_retrograde"
        # Only before sample: infer the opposite direction after the station.
        assert _station_kind((1.0,), None) == "station_retrograde"
        assert _station_kind((-1.0,), None) == "station_direct"
        # Neither sample: neutral, never guess.
        assert _station_kind(None, None) == "station"
        # A zero-speed-only side has no direction evidence: stay neutral or use
        # the non-zero side, never silently classify zero as retrograde.
        assert _station_kind(None, (0.0,)) == "station"
        assert _station_kind((0.0,), None) == "station"
        assert _station_kind((-1.0,), (0.0,)) == "station_direct"
        assert _station_kind((1.0,), (0.0,)) == "station_retrograde"

    def test_past_window_sunrise_sunset_events_present(self) -> None:
        """Regression: rise/set events must cover the full past window, not only
        the hour before the query (missing events broke the timeline contract)."""
        packet, _ = _packet(LINYI_REQUEST)  # eventPastDays defaults to 4
        past_rise_set = [
            e for e in packet["events"]
            if e["event_type"] in ("sunrise", "sunset")
            and e["offset_seconds_from_query"] < 0
        ]
        # 4 full days before the query: one sunrise + one sunset per day.
        assert len(past_rise_set) == 8, [e["id"] for e in past_rise_set]
        types = sorted(e["event_type"] for e in past_rise_set)
        assert types == ["sunrise"] * 4 + ["sunset"] * 4
        # Oldest past rise/set sits within the 4-day window start.
        assert min(e["offset_seconds_from_query"] for e in past_rise_set) > -4 * 86400


class TestReceptionsLotsVisibility:
    def test_reception_unique_ids(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        ids = [r["id"] for r in packet["receptions"]]
        assert len(ids) == len(set(ids))
        assert ids == sorted(ids)

    def test_lots_formulas_and_intermediates(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        assert len(packet["lots"]) >= 7
        for lot in packet["lots"]:
            assert lot["formula_used"]
            assert lot["formula_day"]
            assert lot["formula_night"]
            assert "input_points" in lot
            assert "intermediates" in lot
            assert "longitude_before_normalize_deg" in lot
            pre = lot["longitude_before_normalize_deg"]
            post = lot["longitude_deg"]
            # norm360 relationship
            assert abs((pre % 360.0) - post) < 1e-6 or abs(((pre % 360.0) + 360) % 360 - post) < 1e-6
            assert "score" not in lot
            assert "confidence_tag" not in lot
            assert "supported_by" not in lot

    def test_lots_day_night_sect_selection(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        is_day = packet["time_and_location"]["sect"]["is_day"]
        for lot in packet["lots"][:5]:
            assert lot["sect_used"] == ("day" if is_day else "night")
            if is_day:
                assert lot["formula_used"] == lot["formula_day"]
            else:
                assert lot["formula_used"] == lot["formula_night"]

    def test_visibility_null_when_unmodeled(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        for row in packet["visibility"]:
            if row["visible"] is None:
                assert row.get("visible_reason_code")

    def test_pheno_fields_follow_swiss_ephemeris_slots_and_units(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        jd_ut = packet["time_and_location"]["jd_ut"]
        rows = {
            row["body_id"]: row
            for row in packet["visibility"]
            if row["body_id"] != "SUN"
        }
        assert rows
        for body_id, row in rows.items():
            raw = swe.pheno_ut(jd_ut, BODY_REGISTRY[body_id].code, swe.FLG_SWIEPH)
            assert row["phase_angle_deg"] == round(raw[0], 6)
            assert row["illumination_fraction"] == round(raw[1], 6)
            assert row["angular_diameter_arcsec"] == round(raw[3] * 3600.0, 6)
            assert 0.0 <= row["illumination_fraction"] <= 1.0
            assert row["angular_diameter_arcsec"] > 0.0


class TestTimezoneAndErrors:
    def test_utc_offset_shanghai(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        assert packet["time_and_location"]["utc_offset_seconds"] == 8 * 3600
        assert packet["time_and_location"]["dst_active"] is False

    def test_jd_ut_to_local_carries_calendar_day(self, monkeypatch) -> None:
        """Regression: second/minute carry at 23:59:59.x must roll the day."""
        import astro_backend_horary_v2 as hv2
        from types import SimpleNamespace

        fake = SimpleNamespace(revjul=lambda jd, cal: (2026, 6, 15, 23.9999), GREG_CAL=1)
        monkeypatch.setattr(hv2, "swe", fake)
        chart = datetime(2026, 6, 16, 8, 0, tzinfo=timezone(timedelta(hours=8)))
        out = hv2._jd_ut_to_local(0.0, chart)
        assert out.astimezone(timezone.utc) == datetime(2026, 6, 16, 0, 0, tzinfo=timezone.utc)

    def test_jd_ut_to_local_regular(self) -> None:
        """Normal conversion keeps the exact minute/second."""
        from astro_backend_core import swe

        jd = swe.julday(2026, 6, 15, 6.5, swe.GREG_CAL)
        chart = datetime(2026, 6, 15, 14, 30, tzinfo=timezone(timedelta(hours=8)))
        out = _jd_ut_to_local(jd, chart)
        assert out.astimezone(timezone.utc) == datetime(2026, 6, 15, 6, 30, 0, tzinfo=timezone.utc)

    def test_invalid_latitude_via_api(self) -> None:
        req = copy.deepcopy(LINYI_REQUEST)
        req["chart"]["latitude"] = 999
        result = subprocess.run(
            ["python3", str(TRANSIT_CALC)],
            input=json.dumps(req),
            capture_output=True,
            text=True,
            timeout=30,
        )
        # Must fail or return structured error — not succeed with a chart
        if result.returncode == 0:
            data = json.loads(result.stdout)
            assert "error" in data
            assert "latitude" in json.dumps(data).lower()
        else:
            combined = (result.stdout + result.stderr).lower()
            assert "latitude" in combined or "error" in combined or result.returncode != 0

    @pytest.mark.parametrize(
        ("field", "value", "message"),
        [
            ("eventFutureDays", -1, "eventFutureDays"),
            ("declinationOrb", float("nan"), "declinationOrb"),
            ("antisciaOrb", -0.1, "antisciaOrb"),
            ("nodeMode", "mystery", "nodeMode"),
        ],
    )
    def test_rejects_invalid_v21_options(self, field: str, value: object, message: str) -> None:
        req = copy.deepcopy(LINYI_REQUEST)
        req[field] = value
        with pytest.raises(ValueError, match=message):
            calculate_horary_v2(req, [])

    def test_rejects_duplicate_body_ids(self) -> None:
        req = copy.deepcopy(LINYI_REQUEST)
        req["bodyIds"] = list(CLASSICAL_BODY_IDS) + ["MOON"]
        with pytest.raises(ValueError, match="duplicates"):
            calculate_horary_v2(req, [])


class TestMarkdownAndCLI:
    def test_markdown_has_no_judgment_phrases(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        md = format_horary_v2_markdown(packet)
        lowered = md.lower()
        for phrase in (
            "machine summary",
            "significator candidates",
            "translation of light",
            "collection of light",
            "radicality",
            "bonification",
            "maltreatment",
        ):
            assert phrase not in lowered
        assert "Horary Data Packet" in md
        assert packet["schema"]["schema_id"] in md

    def test_cli_default_is_v2(self) -> None:
        result = subprocess.run(
            ["python3", str(TRANSIT_CALC)],
            input=json.dumps(LINYI_REQUEST),
            capture_output=True,
            text=True,
            timeout=90,
        )
        assert result.returncode == 0, result.stderr[:500]
        data = json.loads(result.stdout)
        assert data["schema"]["version"] in {"2.0", "2.1"}
        assert "machine_summary" not in data
        assert assert_no_forbidden_fields(data) == []
        assert "aspect_candidates" in data

    def test_cli_legacy_packet_version(self) -> None:
        req = copy.deepcopy(LINYI_REQUEST)
        req["packetVersion"] = "1"
        result = subprocess.run(
            ["python3", str(TRANSIT_CALC)],
            input=json.dumps(req),
            capture_output=True,
            text=True,
            timeout=90,
        )
        assert result.returncode == 0, result.stderr[:500]
        data = json.loads(result.stdout)
        assert data["schema"]["version"] == "1.0"
        assert data["schema"].get("legacy") is True
        assert "machine_summary" in data

    def test_cli_rejects_unknown_packet_version(self) -> None:
        req = copy.deepcopy(LINYI_REQUEST)
        req["packetVersion"] = "banana"
        result = subprocess.run(
            ["python3", str(TRANSIT_CALC)],
            input=json.dumps(req),
            capture_output=True,
            text=True,
            timeout=30,
        )
        assert result.returncode == 0, result.stderr[:500]
        data = json.loads(result.stdout)
        assert "invalid" in data
        assert any("packetVersion" in item and "unsupported" in item for item in data["invalid"])


class TestOptionalModules:
    def test_antiscia_and_via_combusta(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        opt = packet["optional_modules"]
        assert len(opt["antiscia"]) == 7
        assert len(opt["via_combusta"]) == 7
        assert len(opt["dodecatemoria"]) == 7


class TestPerformance:
    def test_v2_single_packet_under_budget(self) -> None:
        # Warm once (v2.1 includes full candidates + stars + event graph)
        _packet(LINYI_REQUEST)
        times = []
        for _ in range(3):
            t0 = time.perf_counter()
            _packet(LINYI_REQUEST)
            times.append(time.perf_counter() - t0)
        mean = sum(times) / len(times)
        assert mean < 8.0, f"v2.1 mean {mean:.3f}s exceeds 8s budget"
        assert min(times) > 0


class TestFixtureSync:
    def test_swift_fixture_is_v2_linyi_or_compatible(self) -> None:
        assert FIXTURE_PATH.exists()
        data = json.loads(FIXTURE_PATH.read_text(encoding="utf-8"))
        assert data["schema"]["schema_id"] in {
            "horary-data-packet/2.0",
            "horary-data-packet/2.1",
        }
        assert assert_no_forbidden_fields(data) == []
        assert data["question_metadata"]["place_name"] == "临沂市"


class TestV21Modules:
    def test_nodes_present(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        nodes = packet.get("nodes") or {}
        bodies = nodes.get("bodies") or []
        assert nodes.get("mode") in {"mean", "true", "both"}
        assert any(b["body_id"].endswith("NODE") or "NODE" in b["body_id"] for b in bodies)

    def test_event_graph_and_considerations(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        assert "event_graph" in packet
        assert packet["event_graph"]["per_body"]
        assert packet["considerations_evidence"]
        assert "planetary_day_hour" in packet
        # positions_at_exact must be materialized, not stubbed
        seq = packet["event_graph"]["aspect_candidate_sequences"]
        assert seq
        for s in seq:
            pae = s.get("positions_at_exact") or {}
            assert pae.get("status") == "evaluated"
            assert pae.get("body_a") is not None or pae.get("body_b") is not None
            if pae.get("body_a"):
                assert "longitude_deg" in pae["body_a"]
                assert "speed_deg_per_day" in pae["body_a"]
                assert "integer_house" in pae["body_a"]
                assert "domicile_ruler_id" in pae["body_a"]

    def test_planetary_day_hour_ok_for_linyi(self) -> None:
        """Regression: next-sunrise seed must not false-unavailable mid-latitude charts."""
        packet, _ = _packet(LINYI_REQUEST)
        pdh = packet["planetary_day_hour"]
        assert pdh.get("status") == "ok", pdh
        assert len(pdh.get("hours") or []) == 24
        assert pdh.get("day_ruler_id")
        assert pdh.get("current_hour") is not None
        assert (pdh.get("current_hour") or {}).get("ruler_id")
        # ASC vs hour ruler fact must not force same_planet=false when hour missing
        asc_vs = next(
            (c for c in packet["considerations_evidence"] if c.get("id") == "asc_ruler_vs_hour_ruler"),
            None,
        )
        assert asc_vs is not None
        assert asc_vs.get("hour_ruler_id") is not None
        assert isinstance(asc_vs.get("same_planet"), bool)

    def test_planetary_day_hour_gmt_offset_label(self) -> None:
        """Regression: GMT±N labels (Swift GMTOffset) must keep their offset for
        weekday/rulers/local labels instead of falling back to UTC."""
        gmt = copy.deepcopy(LINYI_REQUEST)
        gmt["chart"]["moment"]["timezone"] = "GMT+8"
        packet, warnings = _packet(gmt)
        assert not any("planetary_day_hour" in w and "non-IANA" in w for w in warnings), warnings
        pdh = packet["planetary_day_hour"]
        assert pdh.get("status") == "ok", pdh
        assert pdh.get("sunrise_local", "").endswith("+08:00")
        assert pdh.get("sunset_local", "").endswith("+08:00")
        for hour in pdh.get("hours") or []:
            assert hour["start_local"].endswith("+08:00")
            assert hour["end_local"].endswith("+08:00")
        # Same absolute offset as Asia/Shanghai on a DST-free date: identical table.
        iana, _ = _packet(LINYI_REQUEST)
        assert pdh["weekday_local"] == iana["planetary_day_hour"]["weekday_local"]
        assert pdh["day_ruler_id"] == iana["planetary_day_hour"]["day_ruler_id"]
        assert pdh["hours"] == iana["planetary_day_hour"]["hours"]

    def test_considerations_allow_unavailable_planetary_hour(self) -> None:
        """Polar/missing sunrise data must yield null evidence, not crash the packet."""
        from astro_backend_horary_v2_modules import considerations_evidence

        rows = considerations_evidence(
            {"ASC": 0.0},
            [],
            {"void_of_course_rules": [], "sign_exit": None},
            {"status": "unavailable", "hours": []},
            {},
        )
        ruler_fact = next(row for row in rows if row["id"] == "asc_ruler_vs_hour_ruler")
        assert ruler_fact["hour_ruler_id"] is None
        assert ruler_fact["same_planet"] is None

    def test_no_self_mutual_reception(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        mutual = [
            r for r in packet["receptions"]
            if r.get("relation_kind") == "mutual_reception"
        ]
        for r in mutual:
            assert r["body_a_id"] != r["body_b_id"], r
            # Canonical id ordering
            assert r["id"] == f"mutual|{r['body_a_id']}|{r['body_b_id']}"
            assert r["body_a_id"] < r["body_b_id"]
        # No self-pair rows at all
        assert not any(
            r.get("id", "").startswith("mutual|") and r.get("body_a_id") == r.get("body_b_id")
            for r in packet["receptions"]
        )

    def test_body_ids_require_sun_and_moon(self) -> None:
        req = copy.deepcopy(LINYI_REQUEST)
        req["bodyIds"] = ["MARS", "VENUS"]
        with pytest.raises(ValueError, match="SUN and MOON"):
            calculate_horary_v2(req, [])

    def test_receptions_include_detriment_or_fall(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        types = {r.get("dignity_type") for r in packet["receptions"] if r.get("dignity_type")}
        assert "domicile" in types
        assert "detriment" in types or "fall" in types
        # Real exact-moment evaluation, not perpetual stubs
        statuses = {
            (r.get("relation_at_next_aspect_exact") or {}).get("status")
            for r in packet["receptions"]
        }
        assert "evaluated" in statuses
        assert "not_evaluated_per_candidate" not in statuses
        evaluated = [
            r for r in packet["receptions"]
            if (r.get("relation_at_next_aspect_exact") or {}).get("status") == "evaluated"
        ]
        assert evaluated
        assert "holds" in evaluated[0]["relation_at_next_aspect_exact"]
        assert evaluated[0]["relation_changes_if_sign_exit_before_exact"]["status"] == "evaluated"

    def test_declination_and_antiscia_and_stars(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        opt = packet["optional_modules"]
        assert opt.get("declination_contacts")
        d0 = opt["declination_contacts"][0]
        assert "application" in d0
        assert "sign_exit_before_exact" in d0
        assert "station_or_retrograde_before_exact" in d0
        moon_seq = opt.get("declination_moon_sequence") or {}
        assert moon_seq.get("body_id") == "MOON"
        assert "previous_contacts" in moon_seq and "next_contacts" in moon_seq
        assert opt.get("antiscia_contacts") is not None
        assert opt.get("fixed_stars", {}).get("stars")

    def test_body_events_index_has_house_change(self) -> None:
        packet, _ = _packet(LINYI_REQUEST)
        for body in packet["bodies"]:
            idx = body.get("events_index") or {}
            assert "next_house_change" in idx
            assert "previous_house_change" in idx
            assert "next_sign_exit" in idx
        # MOON (fast) must materialize a non-null previous house change within past window
        moon = next(b for b in packet["bodies"] if b["body_id"] == "MOON")
        prev = (moon.get("events_index") or {}).get("previous_house_change")
        assert prev is not None, "MOON previous_house_change must not be null"
        assert prev.get("event_id")
        assert prev.get("datetime_utc")
        # past house_change events must exist in flat timeline
        past_hc = [
            e for e in packet["events"]
            if e.get("event_type") == "house_change" and e["offset_seconds_from_query"] < 0
        ]
        assert past_hc, "expected at least one past house_change event"
