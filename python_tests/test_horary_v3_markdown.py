"""The reader export is selective; scientific evidence remains in the packet."""
from __future__ import annotations

import copy
import json
from datetime import timedelta
from pathlib import Path

import pytest

from astro_backend_horary_v3 import format_horary_v3_markdown
from astro_backend_horary_v3_markdown import Worksheet, cell, instant, position, truth


@pytest.fixture
def packet():
    path = Path(__file__).resolve().parents[1] / "SwiftTests/Fixtures/horary-v3-result.json"
    return json.loads(path.read_text())


def test_reader_structure_without_nested_dumps(packet):
    before = copy.deepcopy(packet)
    text = format_horary_v3_markdown(packet)
    for title in ("宫位与取用", "七星状态", "本质尊贵与定位星", "相位与成相候选", "相关星对的接纳位置", "月亮的推进"):
        assert f"## {title}" in text
    for dump in ("{'", '"body_id"', "events_index", "rule_id", "root_status", "source_event_id", "Event Search Coverage"):
        assert dump not in text
    assert len(text.encode()) < 16000
    assert max(map(len, text.splitlines())) < 300
    assert packet == before


def test_all_house_rulers_and_seven_positions_retained(packet):
    text = format_horary_v3_markdown(packet)
    for cusp in packet["houses"]["cusps"]:
        assert f"| {cusp['house']} | {position(cusp['cusp_longitude_deg'])} |" in text
    for body in packet["bodies"]:
        assert position(body["ecliptic"]["longitude_deg"]) in text


def test_only_fortune_not_all_lots_or_events(packet):
    text = format_horary_v3_markdown(packet)
    fortune = next(r for r in packet["lots"] if r["id"] == "fortune")
    assert position(fortune["longitude_deg"]) in text
    assert "**福点：**" in text
    assert "获取点" not in text
    assert "sunrise" not in text
    assert "赤纬平行" not in text
    assert "完整相位候选、事件序列" in text


def candidate(packet, *, in_orb=False, at=None, root="not_found"):
    c = copy.deepcopy(packet["aspect_candidates"][0])
    c.update(within_display_orb=in_orb, next_exact={"datetime_utc": at, "root_status": root})
    return c


def test_selection_obeys_orb_and_utc_window_not_candidate_flag(packet):
    query = instant(packet["time_and_location"]["utc_datetime"])
    end = instant(packet["event_search"]["window"]["end_utc"])
    visible = candidate(packet, in_orb=True)
    distant = candidate(packet)
    future = candidate(packet, at=end.isoformat(), root="found")
    future["will_perfect_in_window"] = False
    outside = candidate(packet, at=(end + timedelta(seconds=1)).isoformat(), root="found")
    past = candidate(packet, at=(query - timedelta(seconds=1)).isoformat(), root="found")
    unavailable = candidate(packet, at=end.isoformat(), root="unavailable")
    packet["aspect_candidates"] = [visible, distant, future, outside, past, unavailable]
    selected = Worksheet(packet).selected_candidates()
    assert len(selected) == 2
    assert visible in selected and future in selected
    assert "候选搜索未找到" in format_horary_v3_markdown(packet)
    assert "容许度外" in format_horary_v3_markdown(packet)


def test_known_obstacles_not_hidden_and_unknown_is_not_none(packet):
    c = candidate(packet, in_orb=True)
    c.update(refranation_detected=True, station_or_retrograde_before_exact=True,
             sign_exit_before_exact={"body_a": True, "body_b": None})
    packet["aspect_candidates"] = [c]
    text = format_horary_v3_markdown(packet)
    assert "检出撤回" in text
    assert "先换座" in text
    assert "成相前停滞/逆行" in text
    c.update(refranation_detected=None, station_or_retrograde_before_exact=None)
    c["sign_exit_before_exact"] = {"body_a": None, "body_b": None}
    assert "未完整确认" in format_horary_v3_markdown(packet)


def test_reception_direction_and_negative_dignities(packet):
    c = candidate(packet, in_orb=True)
    c.update(body_a_id="SUN", body_b_id="MOON")
    packet["aspect_candidates"] = [c]
    packet["receptions"] = [
        {"receiver_id": "MOON", "received_body_id": "SUN", "dignity_type": "domicile", "relation_at_query": True},
        {"receiver_id": "SUN", "received_body_id": "MOON", "dignity_type": "fall", "relation_at_query": True},
        {"receiver_id": "VENUS", "received_body_id": "MARS", "dignity_type": "bound", "relation_at_query": True},
    ]
    text = format_horary_v3_markdown(packet)
    assert "| 太阳 / 月亮 | 落陷 | 入庙 |" in text
    assert "不算正向接纳" in text
    assert "| 金星 / 火星 |" not in text


def test_moon_keeps_last_and_all_pre_exit_but_only_first_after(packet):
    moon = packet["moon"]
    first = copy.deepcopy(moon["last_exact_aspect_in_current_sign"])
    first.update(target_id="VENUS", aspect_id="sextile", datetime_utc="2026-10-03T02:00:00Z")
    second = dict(first, target_id="JUPITER", datetime_utc="2026-10-03T03:00:00Z")
    moon["future_exact_aspects_in_current_sign"] = [second, first]
    moon["aspects_in_next_sign"] = [second, first]
    text = format_horary_v3_markdown(packet)
    assert text.count("| 出座前后续相位 |") == 2
    assert text.count("| 本座最近离开的相位 |") == 1
    assert text.count("| 换座后第一相位 |") == 1
    assert "| 换座后第一相位 | 六合 | 金星 |" in text


def test_missing_lunar_search_is_not_void_course(packet):
    packet["moon"]["future_exact_aspects_in_current_sign"] = []
    for rule in packet["moon"]["void_of_course_rules"]:
        rule.update(value=None, status="unavailable")
    text = format_horary_v3_markdown(packet)
    assert "空亡状态：未确定" in text
    assert "当前是否空亡：是" not in text
    assert "当前是否空亡：否" not in text


@pytest.mark.parametrize("phase,label", [(0, "新月"), (90, "盈月"), (180, "满月"), (243.85, "亏月")])
def test_lunar_phase_is_a_fact_not_a_judgment(packet, phase, label):
    packet["moon"]["phase_angle_deg"] = phase
    assert f"**月相：** {label}。" in format_horary_v3_markdown(packet)


def test_invalid_secondary_voc_interval_is_not_shown_as_valid(packet):
    rule = packet["moon"]["void_of_course_rules"][1]
    rule["interval"] = {"complete": False, "reason_code": "interval_start_after_end"}
    text = format_horary_v3_markdown(packet)
    assert "未形成有效区间" in text
    assert "不用于上面的本座空亡结果" in text


@pytest.mark.parametrize("zone,utc,expected", [
    ("Asia/Shanghai", "2026-10-01T14:03:10Z", "2026-10-01 22:03:10+08:00"),
    ("GMT+0530", "2026-10-01T14:03:10Z", "2026-10-01 19:33:10+05:30"),
    ("UTC", "2026-10-01T14:03:10Z", "2026-10-01 14:03:10+00:00"),
    ("America/New_York", "2026-11-01T05:30:00Z", "2026-11-01 01:30:00-04:00"),
    ("America/New_York", "2026-11-01T06:30:00Z", "2026-11-01 01:30:00-05:00"),
])
def test_local_time_from_utc_including_dst_fold(packet, zone, utc, expected):
    packet["time_and_location"]["timezone"] = zone
    assert Worksheet(packet).time(utc) == expected


def test_missing_optional_blocks_and_false_states(packet):
    packet.update(lots=[], events=[], receptions=[], aspect_candidates=[], planetary_day_hour={}, moon={})
    packet["visibility"][1]["solar_condition_flags"] = []
    text = format_horary_v3_markdown(packet)
    assert "未确定" in text
    assert "空亡状态：未确定" in text
    assert "没有符合本节筛选条件" in text
    assert truth(None) == "未确定" and truth(False) == "否"


def test_escape_user_metadata_without_table_or_html_injection(packet):
    packet["question_metadata"]["question_text"] = "A|B\n# title <script>x</script> [link](url)"
    text = format_horary_v3_markdown(packet)
    assert "A&#124;B<br>\\# title &lt;script&gt;" in text
    assert "<script>" not in text
    assert cell("a\\b|c\r\nd") == "a\\\\b&#124;c<br>d"
    with pytest.raises(TypeError):
        cell({"nested": "dump"})


@pytest.mark.parametrize("issue", ["bad|reference", {"code": "bad|reference", "path": "events[0]"}])
def test_failures_and_partial_search_are_prominent(packet, issue):
    packet["validation"].update(invariant_check="failed", invariant_issues=[issue])
    packet["event_search"]["status"] = "partial"
    text = format_horary_v3_markdown(packet)
    assert text.index("数据检查未通过") < text.index("## 宫位与取用")
    assert "搜索不完整" in text and "bad&#124;reference" in text
    assert "内部一致性：通过" not in text


@pytest.mark.parametrize("longitude,expected", [
    (29.99999, "金牛 00°00'00\""), (359.99999, "白羊 00°00'00\""),
    (-0.001, "双鱼 29°59'56\""), (90.01551139, "巨蟹 00°00'56\""),
    (None, "未返回"), (float("nan"), "未返回"),
])
def test_degree_rounding_with_carry(longitude, expected):
    assert position(longitude) == expected


def test_reject_other_packet_versions(packet):
    packet["schema"]["schema_id"] = "horary-data-packet/2.1"
    with pytest.raises(ValueError, match="v3"):
        format_horary_v3_markdown(packet)
