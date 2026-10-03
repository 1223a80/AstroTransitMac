"""V3 boundaries, real ephemeris evidence, CLI routing and packet invariants."""
from __future__ import annotations

import copy
import json
import math
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import jsonschema
import pytest

import astro_backend_horary_v3 as v3
from astro_backend_core import BODY_REGISTRY, jd_from_datetime, swe, zodiac_sign_index
from astro_backend_horary_v2 import calculate_horary_v2
from astro_backend_horary_v3_config import HoraryConfig, TimeWindow, parse_utc
from astro_backend_horary_v3_events import EventTimeline
from astro_backend_horary_v3_moon import build_moon_index
from astro_backend_horary_v3_packet import assemble_packet, validate_packet
from astro_backend_horary_v3_search import EphemerisSampler, EventLedger, SampleUnavailable, scan_roots

ROOT = Path(__file__).resolve().parents[1]
CLI = ROOT / "Sources/TransitStudio/Resources/backend/transit_calc.py"
ORIGIN = datetime(2026, 10, 1, tzinfo=timezone.utc)


@pytest.fixture
def request_v3():
    request = json.loads((ROOT / "Examples/sample-horary-request.json").read_text())
    request["packetVersion"] = "3"
    return request


@pytest.fixture(scope="module")
def packet():
    request = json.loads((ROOT / "Examples/sample-horary-request.json").read_text())
    request["packetVersion"] = "3"
    return v3.calculate_horary_v3(request, [])


@pytest.mark.parametrize("field,value", [
    ("altitudeM", False), ("altitudeM", []), ("altitudeM", {}), ("altitudeM", ""), ("altitudeM", None),
    ("aspectOrb", 10**400), ("aspectOrb", float("nan")), ("aspectOrb", float("inf")),
    ("eventFutureDays", 1e12), ("eventPastDays", -1), ("eventFutureDays", 401),
    ("bodyIds", ["SUN"]), ("bodyIds", ["SUN", "MOON", "MOON"]), ("nodeMode", "invalid"),
    ("ephemerisPath", []), ("ephemerisPath", False), ("ephemeris_path", {}),
])
def test_bad_inputs_are_value_errors(request_v3, field, value):
    request_v3[field] = value
    with pytest.raises(ValueError):
        HoraryConfig.from_request(request_v3)


def test_config_copies_request_and_uses_elapsed_utc_days(request_v3):
    request_v3["chart"]["moment"] = dict(year=2026, month=10, day=31, hour=12, minute=0, timezone="America/New_York")
    request_v3["eventFutureDays"] = 1
    before = copy.deepcopy(request_v3)
    cfg = HoraryConfig.from_request(request_v3)
    assert request_v3 == before
    assert (cfg.window.end - cfg.instant).total_seconds() == 86400
    assert cfg.window.end.astimezone(cfg.local_time.tzinfo).hour == 11
    cfg.chart["moment"]["year"] = 2000
    assert request_v3 == before


def test_null_ephemeris_path_keeps_snake_case_alias(request_v3):
    request_v3.update(ephemerisPath=None, ephemeris_path="/custom/ephemeris")
    assert HoraryConfig.from_request(request_v3).ephemeris_path == "/custom/ephemeris"


@pytest.mark.parametrize("second", [False, 1.5, "1", 60])
def test_invalid_seconds_are_not_coerced(request_v3, second):
    request_v3["chart"]["moment"]["second"] = second
    with pytest.raises(ValueError, match="second"):
        HoraryConfig.from_request(request_v3)


@pytest.mark.parametrize("duration,root_hour", [(3, 2), (9, 7), (3, 3), (3, 0)])
def test_root_search_includes_short_tail_and_endpoints(duration, root_hour):
    result = scan_roots(lambda t: (t - ORIGIN).total_seconds() / 3600 - root_hour,
                        TimeWindow(ORIGIN, ORIGIN + timedelta(hours=duration)), angular=False)
    assert result.status == "found"
    assert len(result.roots) == 1
    assert abs((result.roots[0] - ORIGIN).total_seconds() - root_hour * 3600) < 0.01


def test_scan_all_roots_and_reject_angular_discontinuity():
    result = scan_roots(lambda t: math.cos((t - ORIGIN).total_seconds() * math.pi / 21600),
                        TimeWindow(ORIGIN, ORIGIN + timedelta(days=1)), 1, angular=False)
    assert len(result.roots) == 4
    result = scan_roots(lambda t: 179 if t < ORIGIN + timedelta(hours=3) else -179,
                        TimeWindow(ORIGIN, ORIGIN + timedelta(hours=6)))
    assert result.status == "not_found_in_window"


def test_missing_sample_is_not_no_events():
    def sample(t):
        if t > ORIGIN:
            raise SampleUnavailable("synthetic_failure")
        return 1
    result = scan_roots(sample, TimeWindow(ORIGIN, ORIGIN + timedelta(hours=1)))
    assert result.status == "unavailable"
    assert result.reason == "synthetic_failure"


def test_ledger_preserves_voc_rules_and_negative_subsecond_offsets():
    ledger = EventLedger(ORIGIN)
    t = ORIGIN - timedelta(seconds=0.5)
    for rule in ("rule_a", "rule_b"):
        ledger.add("void_of_course_start", t, ("MOON",), rule, voc_rule_ids=[rule])
    row, = ledger.rows()
    assert row["offset_seconds_from_query"] == -0.5
    assert row["rule_ids"] == row["voc_rule_ids"] == ["rule_a", "rule_b"]


def test_moon_search_failure_keeps_voc_unknown(request_v3, packet):
    cfg = HoraryConfig.from_request(request_v3)
    timeline = EventTimeline(cfg, EphemerisSampler(False, []), list(range(0, 360, 30)))
    timeline.coverage = [{"id": "sign_ingress|MOON|0", "status": "unavailable"}]
    moon = build_moon_index(timeline, {b["body_id"]: b for b in packet["bodies"]})
    assert all(rule["value"] is None and rule["status"] == "unavailable" for rule in moon["void_of_course_rules"])
    assert not timeline.ledger.rows()


def test_delta_t_failure_does_not_fabricate_tt(monkeypatch, request_v3):
    monkeypatch.setattr(v3, "_delta_t_seconds", lambda jd: float("nan"))
    warnings = []
    ctx = v3.ChartContext.calculate(HoraryConfig.from_request(request_v3), warnings)
    output = assemble_packet(ctx, {})
    assert output["time_and_location"]["jd_tt"] is None
    assert output["time_and_location"]["delta_t_reason_code"] == "delta_t_unavailable"
    assert warnings


def test_required_moon_failure_is_explicit(monkeypatch, request_v3):
    real = v3._full_body_calc
    monkeypatch.setattr(v3, "_full_body_calc", lambda jd, bid, *a, **kw: None if bid == "MOON" else real(jd, bid, *a, **kw))
    with pytest.raises(ValueError, match="required body MOON"):
        v3.ChartContext.calculate(HoraryConfig.from_request(request_v3), [])


def test_real_packet_schema_and_invariants(packet):
    schema = json.loads((ROOT / "docs/schemas/horary-data-packet-3.0.json").read_text())
    jsonschema.Draft202012Validator(schema).validate(packet)
    assert packet["schema"]["schema_id"] == "horary-data-packet/3.0"
    assert packet["validation"]["invariant_check"] == "passed"
    assert packet["validation"]["forbidden_field_scan"] == "passed"
    assert len(packet["aspect_candidates"]) == 105
    assert len(packet["lots"]) > 0
    assert all(e["in_configured_window"] for e in packet["events"])
    assert packet["moon"]["distance_to_north_node_deg"] is not None
    json.dumps(packet, allow_nan=False)


def test_real_ingresses_cover_repeated_crossings_and_match_ephemeris(packet):
    lunar = [e for e in packet["events"] if e["event_type"] == "sign_ingress" and e["body_ids"] == ["MOON"]]
    assert len(lunar) >= 12
    assert any(e["offset_seconds_from_query"] < 0 for e in lunar)
    assert sum(e["event_type"] == "house_change" and e["body_ids"] == ["MOON"] for e in packet["events"]) >= 12
    for event in lunar:
        instant = parse_utc(event["datetime_utc"])
        before = swe.calc_ut(jd_from_datetime(instant - timedelta(seconds=1)), swe.MOON)[0][0]
        after = swe.calc_ut(jd_from_datetime(instant + timedelta(seconds=1)), swe.MOON)[0][0]
        assert event["state_before"]["sign_index"] == zodiac_sign_index(before)
        assert event["state_after"]["sign_index"] == zodiac_sign_index(after)
        assert zodiac_sign_index(before) != zodiac_sign_index(after)


def test_v2_facts_are_preserved(request_v3, packet):
    legacy = calculate_horary_v2({**request_v3, "packetVersion": "2"}, [])
    for old, new in zip(legacy["bodies"], packet["bodies"]):
        for section in ("ecliptic", "sign", "equatorial", "horizontal", "house", "motion"):
            assert old[section] == new[section]
    for section in ("dignities", "lots", "pairwise_geometry", "aspects", "receptions"):
        assert packet[section] == legacy[section]


def test_new_pipeline_does_not_call_v2_entry_and_is_deterministic(monkeypatch, request_v3):
    import astro_backend_horary_v2
    def forbidden(*args, **kwargs):
        pytest.fail("V3 must not call the V2 packet entry")
    monkeypatch.setattr(astro_backend_horary_v2, "calculate_horary_v2", forbidden)
    request_v3.update(bodyIds=["SUN", "MOON"], eventPastDays=0.1, eventFutureDays=0.2)
    before = copy.deepcopy(request_v3)
    first = v3.calculate_horary_v3(request_v3, [])
    second = v3.calculate_horary_v3(request_v3, [])
    assert first == second
    assert request_v3 == before


def test_invariant_failures_are_returned_with_warnings(packet):
    altered = copy.deepcopy(packet)
    altered["score"] = 1
    altered["events"][0]["offset_seconds_from_query"] += 2
    altered["event_graph"]["per_body"][0]["next_event_id"] = "missing"
    warnings = []
    issues = validate_packet(altered, warnings)
    assert {i["code"] for i in issues} >= {"forbidden_field", "event_offset_mismatch", "dangling_event_reference"}
    assert altered["validation"]["warnings"] == warnings
    assert altered["validation"]["invariant_check"] == "failed"


@pytest.mark.parametrize("version", ["3", "v3", "3.0"])
def test_cli_version_routing(request_v3, version):
    request_v3.update(packetVersion=version, bodyIds=["SUN", "MOON"], eventPastDays=0, eventFutureDays=0.125)
    result = subprocess.run([sys.executable, "-B", str(CLI)], input=json.dumps(request_v3),
                            text=True, capture_output=True, check=True, timeout=30)
    packet = json.loads(result.stdout)
    assert packet["schema"]["schema_id"] == "horary-data-packet/3.0"
    assert packet["validation"]["invariant_check"] == "passed"


def test_cli_rejects_invalid_window_before_calculation(request_v3):
    request_v3["eventFutureDays"] = 1e12
    result = subprocess.run([sys.executable, "-B", str(CLI)], input=json.dumps(request_v3),
                            text=True, capture_output=True, check=True, timeout=10)
    assert any("eventFutureDays" in item for item in json.loads(result.stdout)["invalid"])


def test_markdown_identifies_v3_and_coverage(packet):
    text = v3.format_horary_v3_markdown(packet)
    assert "horary-data-packet/3.0" in text
    assert "Horary V3 解盘工作表" in text
    assert "内部一致性：通过" in text


@pytest.mark.parametrize("zodiac,node_mode", [("sidereal_lahiri", "true"), ("tropical", "both")])
def test_zodiac_nodes_and_zero_event_window(request_v3, zodiac, node_mode):
    request_v3["chart"]["zodiac"] = zodiac
    request_v3.update(nodeMode=node_mode, bodyIds=["SUN", "MOON"], eventPastDays=0, eventFutureDays=0)
    packet = v3.calculate_horary_v3(request_v3, [])
    assert packet["validation"]["invariant_check"] == "passed"
    assert packet["events"] == []
    assert len(packet["nodes"]["bodies"]) == (2 if node_mode == "true" else 4)
    assert packet["moon"]["sign_exit"]["datetime_utc"] is not None


def test_sunrise_search_advances_from_each_event(request_v3, monkeypatch):
    cfg = HoraryConfig.from_request(request_v3)
    timeline = EventTimeline(cfg, EphemerisSampler(False, []), list(range(0, 360, 30)))
    start_jd = jd_from_datetime(cfg.window.start)
    # A sub-24h recurrence deliberately straddles successive daily probes.
    expected = [start_jd + 0.001 + i * 0.99 for i in range(40)]
    def rise_trans(jd, *args):
        future = [t for t in expected if t > jd]
        return (0, (future[0],)) if future else (-2, ())
    monkeypatch.setattr(swe, "rise_trans", rise_trans)
    timeline._sunrise_sunset()
    actual = [e for e in timeline.configured_events(["SUN"]) if e["event_type"] == "sunrise"]
    assert len(actual) == sum(t <= jd_from_datetime(cfg.window.end) for t in expected)
