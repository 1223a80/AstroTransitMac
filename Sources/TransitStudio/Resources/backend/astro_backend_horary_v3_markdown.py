"""Selective, judgment-free horary worksheet; full evidence stays in JSON."""
from __future__ import annotations

import html
import math
from datetime import datetime, timezone
from typing import Any

from astro_backend_core import resolve_timezone
from astro_backend_horary_v3_config import SCHEMA_ID

NAMES = {"SUN": "太阳", "MOON": "月亮", "MERCURY": "水星", "VENUS": "金星",
         "MARS": "火星", "JUPITER": "木星", "SATURN": "土星"}
SIGNS = ("白羊", "金牛", "双子", "巨蟹", "狮子", "处女", "天秤", "天蝎", "射手", "摩羯", "水瓶", "双鱼")
ASPECTS = {"conjunction": "合相", "sextile": "六合", "square": "刑相", "trine": "拱相", "opposition": "对冲"}
DIGNITIES = {"domicile": "入庙", "exaltation": "擢升", "triplicity": "三分性",
             "bound": "界", "decan": "面", "detriment": "失势", "fall": "落陷"}
MISSING = "未返回"


def cell(value: Any) -> str:
    if value is None:
        return MISSING
    if isinstance(value, (dict, list, tuple)):
        raise TypeError("worksheet cells must be scalar")
    text = html.escape(str(value), quote=False)
    for mark in ("\\", "`", "*", "_", "[", "]", "#"):
        text = text.replace(mark, "\\" + mark)
    return text.replace("|", "&#124;").replace("\r\n", "\n").replace("\r", "\n").replace("\n", "<br>")


def number(value: Any, digits: int = 2) -> str:
    if not isinstance(value, (int, float)) or isinstance(value, bool) or not math.isfinite(value):
        return MISSING
    return f"{value:.{digits}f}"


def position(longitude: Any) -> str:
    if number(longitude) == MISSING:
        return MISSING
    seconds = int(math.floor((longitude % 360) * 3600 + 0.5)) % (360 * 3600)
    sign, remainder = divmod(seconds, 30 * 3600)
    degree, remainder = divmod(remainder, 3600)
    minute, second = divmod(remainder, 60)
    return f"{SIGNS[sign]} {degree:02d}°{minute:02d}'{second:02d}\""


def name(body_id: Any) -> str:
    return NAMES.get(body_id, body_id or MISSING)


def truth(value: Any, yes: str = "是", no: str = "否") -> str:
    return yes if value is True else no if value is False else "未确定"


def instant(value: str | None) -> datetime | None:
    if not value:
        return None
    parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("horary worksheet timestamps must include a UTC offset")
    return parsed.astimezone(timezone.utc)


class Worksheet:
    def __init__(self, packet: dict[str, Any]):
        self.p = packet
        self.zone = resolve_timezone(packet["time_and_location"]["timezone"])
        self.query = instant(packet["time_and_location"]["utc_datetime"])
        self.end = instant(packet["event_search"]["window"]["end_utc"])
        self.lines: list[str] = ["# Horary V3 解盘工作表", ""]

    def time(self, value: str | None) -> str:
        stamp = instant(value)
        # Numeric offsets disambiguate repeated local hours during a DST transition.
        return stamp.astimezone(self.zone).isoformat(sep=" ", timespec="seconds") if stamp else MISSING

    def paragraph(self, text: str) -> None:
        self.lines.extend([text, ""])

    def section(self, title: str) -> None:
        self.lines.extend([f"## {title}", ""])

    def table(self, headers: list[str], rows: list[list[Any]]) -> None:
        if not rows:
            self.paragraph("没有符合本节筛选条件的记录。")
            return
        self.lines.append("| " + " | ".join(map(cell, headers)) + " |")
        self.lines.append("| " + " | ".join("---" for _ in headers) + " |")
        self.lines.extend("| " + " | ".join(map(cell, row)) + " |" for row in rows)
        self.lines.append("")

    def selected_candidates(self) -> list[dict[str, Any]]:
        rows = []
        for c in self.p.get("aspect_candidates", []):
            exact = c.get("next_exact") or {}
            at = instant(exact.get("datetime_utc"))
            future = exact.get("root_status") == "found" and at is not None and self.query < at <= self.end
            if c.get("within_display_orb") is True or future:
                rows.append(c)
        return sorted(rows, key=lambda c: (c.get("within_display_orb") is not True,
                      instant((c.get("next_exact") or {}).get("datetime_utc")) or datetime.max.replace(tzinfo=timezone.utc), c["id"]))

    def header(self) -> None:
        meta, loc, cfg = self.p["question_metadata"], self.p["time_and_location"], self.p["calculation_config"]
        self.paragraph(f"**起盘：** {cell(self.time(loc['utc_datetime']))} · {cell(meta.get('place_name') or '地点名称未填写')}")
        self.paragraph(f"**问题：** {cell(meta.get('question_text') or '未填写；尚未指定所问宫位和事项主星。')}")
        sect = truth(loc.get("sect", {}).get("is_day"), "昼盘", "夜盘")
        zodiac = {"tropical": "回归黄道", "sidereal_lahiri": "恒星黄道（Lahiri）"}.get(cfg.get("zodiac"), cfg.get("zodiac"))
        bounds = {"egyptian": "埃及界", "ptolemaic": "托勒密界"}.get(cfg.get("bounds_system"), cfg.get("bounds_system"))
        triplicity = {"dorothean": "Dorothean 三分性", "ptolemaic": "托勒密三分性"}.get(cfg.get("triplicity_system"), cfg.get("triplicity_system"))
        self.paragraph(f"**计算：** {cell(cfg.get('house_system_label'))} 宫制 · {cell(zodiac)} · {cell(bounds)} · {cell(triplicity)} · {sect}。")
        self.paragraph(f"经纬度 {number(loc.get('latitude_deg'), 5)}, {number(loc.get('longitude_deg'), 5)}；时区 {cell(loc['timezone'])}。下文时间均为该地当地时间，显示到秒。")
        validation = self.p.get("validation", {})
        if validation.get("invariant_check") != "passed":
            self.paragraph("**数据检查未通过：以下事实存在内部一致性问题，不能视作已验证数据。**")
        for issue in validation.get("invariant_issues", []):
            detail = f"{issue.get('code', 'unknown')} · {issue.get('path', '')}" if isinstance(issue, dict) else issue
            self.paragraph("数据问题：" + cell(detail))
        for warning in validation.get("warnings", []):
            self.paragraph("计算提示：" + cell(warning))
        if self.p.get("event_search", {}).get("status") != "sampled":
            self.paragraph("**搜索不完整：** 部分事件计算不可用，未列出的记录不能据此排除。")

    def chart(self) -> None:
        self.section("宫位与取用")
        self.table(["宫位", "宫头", "宫主"], [[r.get("house"), position(r.get("cusp_longitude_deg")), name(r.get("domicile_ruler_id"))]
                    for r in self.p.get("houses", {}).get("cusps", [])])
        self.section("七星状态")
        visibility = {r["body_id"]: r for r in self.p.get("visibility", [])}
        rows = []
        for b in self.p.get("bodies", []):
            bid, motion = b["body_id"], b.get("motion", {})
            flags = visibility.get(bid, {}).get("solar_condition_flags", [])
            solar = [label for key, label in (("cazimi", "日心"), ("combust", "燃烧"), ("under_beams", "日光下"))
                     if any(f.get("id") == key and f.get("value") is True for f in flags)]
            known = {f.get("id"): f.get("value") for f in flags}
            solar_text = "、".join(solar) if solar else "不适用" if bid == "SUN" else "均否" if all(known.get(k) is False for k in ("cazimi", "combust", "under_beams")) else "未确定"
            state = {"direct": "顺行", "retrograde": "逆行", "stationary": "停滞"}.get(motion.get("state"), motion.get("state") or MISSING)
            rows.append([name(bid), position(b.get("ecliptic", {}).get("longitude_deg")), b.get("house", {}).get("integer_house"),
                         state, number(motion.get("longitude_speed_deg_per_day"), 3), solar_text])
        self.table(["星体", "位置", "宫位", "运动", "日速（度）", "日光状态"], rows)
        thresholds = self.p["calculation_config"].get("solar_thresholds", {})
        self.paragraph(f"日光状态沿用引擎的互斥分类，黄经距阈值为日心 {number(thresholds.get('cazimi_deg'), 3)}°、燃烧 {number(thresholds.get('combust_deg'))}°、日光下 {number(thresholds.get('under_beams_deg'))}°；“均否”只指这三项。")
        self.section("本质尊贵与定位星")
        rows = []
        for d in self.p.get("dignities", []):
            bid = d["body_id"]
            own = [label for key, label in (("is_in_own_domicile", "入庙"), ("is_in_own_exaltation", "擢升"),
                                            ("is_in_detriment", "失势"), ("is_in_fall", "落陷"), ("is_peregrine", "游离")) if d.get(key) is True]
            for block, key, label in (("triplicity", "active_ruler_id", "三分性"), ("bounds", "ruler_id", "界"), ("decan", "ruler_id", "面")):
                if d.get(block, {}).get(key) == bid:
                    own.append(label)
            rows.append([name(bid), "、".join(own) or "未标记", name(d.get("domicile_ruler_id")), name(d.get("exaltation_ruler_id")) if d.get("exaltation_ruler_id") else "无",
                         name(d.get("triplicity", {}).get("active_ruler_id")), name(d.get("bounds", {}).get("ruler_id")), name(d.get("decan", {}).get("ruler_id"))])
        self.table(["星体", "自身尊贵/失势", "庙主", "擢升主", "当令三分主", "界主", "面主"], rows)

    def aspects(self, selected: list[dict[str, Any]]) -> None:
        self.section("相位与成相候选")
        self.paragraph(f"列出起盘时 {number(self.p.get('display_orb_deg'))}° 显示容许度内的相位，以及从起盘到 {cell(self.time(self.p['event_search']['window']['end_utc']))} 找到的后续精确成相候选。容许度外候选另行标明；精确成相时刻不等于事情兑现时间。")
        rows = []
        for c in selected:
            a, b = c["body_a_id"], c["body_b_id"]
            next_exact = c.get("next_exact") or {}
            at = instant(next_exact.get("datetime_utc"))
            in_window = next_exact.get("root_status") == "found" and at is not None and self.query < at <= self.end
            status = self.time(next_exact.get("datetime_utc")) if in_window else "窗口外（未列时间）" if at else "候选搜索未找到" if next_exact.get("root_status") == "not_found" else "未确定"
            checks = []
            exits = c.get("sign_exit_before_exact") or {}
            for key, bid in (("body_a", a), ("body_b", b)):
                if exits.get(key) is True:
                    checks.append(name(bid) + "先换座")
            if c.get("station_or_retrograde_before_exact") is True:
                checks.append("成相前停滞/逆行")
            if c.get("refranation_detected") is True:
                checks.append("检出撤回")
            if not checks:
                complete = all(c.get(k) is False for k in ("station_or_retrograde_before_exact", "refranation_detected")) and all(exits.get(k) is False for k in ("body_a", "body_b"))
                checks.append("上述变化未检出" if complete and in_window else "未完整确认")
            application = {"applying": "入相", "separating": "离相", "exact": "精确", "stationary": "静止"}.get(c.get("application"), c.get("application") or MISSING)
            orb = number(c.get("orb_deg")) + "°" + ("（容许度外）" if c.get("within_display_orb") is not True else "")
            rows.append([f"{name(a)} / {name(b)}", ASPECTS.get(c.get("aspect_id"), c.get("aspect_id")), orb, application, status, "；".join(checks)])
        self.table(["星对", "相位", "距精确", "方向", "下次精确（当地时间）", "换座/运动检查"], rows)
        self.paragraph("这里只显示已有候选检查，不自动判定禁止、挫败、光的传递或收集是否成立。")
        stations = [e for e in self.p.get("events", []) if e.get("event_type") in {"station_direct", "station_retrograde"}
                    and self.query < instant(e["datetime_utc"]) <= self.end]
        if stations:
            self.table(["星体", "近期运动变化", "当地时间"], [[" / ".join(name(b) for b in e["body_ids"]),
                        "转逆行" if e["event_type"] == "station_retrograde" else "转顺行", self.time(e["datetime_utc"])] for e in stations])

    def receptions(self, selected: list[dict[str, Any]]) -> None:
        self.section("相关星对的接纳位置")
        pairs = {}
        for c in selected:
            a, b = c["body_a_id"], c["body_b_id"]
            pairs.setdefault(frozenset((a, b)), (a, b))
        directed: dict[tuple[str, str], list[str]] = {}
        for r in self.p.get("receptions", []):
            if r.get("receiver_id") and r.get("relation_at_query") is True:
                directed.setdefault((r["receiver_id"], r["received_body_id"]), []).append(DIGNITIES.get(r.get("dignity_type"), r.get("dignity_type")))
        rows = [[f"{name(a)} / {name(b)}", "、".join(directed.get((a, b), [])) or "未列出关系",
                 "、".join(directed.get((b, a), [])) or "未列出关系"] for a, b in pairs.values()]
        self.paragraph("只列上节相位涉及的星对，按起盘位置归类。第二列表示后者位于前者的尊贵或失势位置，第三列反向；“失势/落陷”不算正向接纳，位置关系本身也不等于事情成功。")
        self.table(["前者 / 后者", "后者在前者的哪些位置", "前者在后者的哪些位置"], rows)

    def moon(self) -> None:
        self.section("月亮的推进")
        moon = self.p.get("moon", {})
        phase = moon.get("phase_angle_deg")
        if number(phase) != MISSING:
            phase = phase % 360
            label = "新月" if phase == 0 else "满月" if phase == 180 else "盈月" if phase < 180 else "亏月"
            self.paragraph(f"**月相：** {label}。")
        rows = []
        previous = moon.get("last_exact_aspect_in_current_sign")
        if previous:
            rows.append(["本座最近离开的相位", ASPECTS.get(previous.get("aspect_id")), name(previous.get("target_id")), self.time(previous.get("datetime_utc"))])
        future = sorted(moon.get("future_exact_aspects_in_current_sign", []), key=lambda r: instant(r["datetime_utc"]))
        rows.extend(["出座前后续相位", ASPECTS.get(r.get("aspect_id")), name(r.get("target_id")), self.time(r.get("datetime_utc"))] for r in future)
        exit_row = moon.get("sign_exit") or {}
        rows.append(["离开当前星座", "换座", "剩余 " + number(exit_row.get("remaining_arc_deg")) + "°", self.time(exit_row.get("datetime_utc"))])
        after = sorted(moon.get("aspects_in_next_sign", []), key=lambda r: instant(r["datetime_utc"]))
        if after:
            first = after[0]
            rows.append(["换座后第一相位", ASPECTS.get(first.get("aspect_id")), name(first.get("target_id")), self.time(first.get("datetime_utc"))])
        self.table(["阶段", "事件", "对象/余度", "当地时间"], rows)
        rules = moon.get("void_of_course_rules", [])
        primary = next((r for r in rules if r.get("rule_id") == "voc.modern_exact_before_sign_exit.v1"), None)
        if primary is None or primary.get("status") != "evaluated" or primary.get("value") is None:
            self.paragraph("**空亡状态：未确定。** 月亮搜索数据不足，不把空列表解释成空亡。")
        else:
            self.paragraph(f"**当前是否空亡：{truth(primary.get('value'))}。** 这里采用“出座前不再与七星形成五大精确相位”的口径，不套用起盘时的显示容许度。")
            interval = primary.get("interval") or {}
            if interval.get("complete") is True:
                self.paragraph(f"本座空亡区间：{cell(self.time(interval.get('start_datetime_utc')))} 至 {cell(self.time(interval.get('end_datetime_utc')))}。")
            else:
                self.paragraph("本座空亡区间未完整返回，未列作有效时间区间。")
        for r in rules:
            if r is primary:
                continue
            interval = r.get("interval") or {}
            if interval.get("reason_code") == "interval_start_after_end":
                self.paragraph("补充口径提示：跨座四日搜索的空亡区间起点晚于终点，未形成有效区间；不用于上面的本座空亡结果。")
            elif primary and (r.get("value") != primary.get("value") or r.get("status") != "evaluated"):
                self.paragraph("补充口径与本座口径不同或不可用，详情保留在 JSON；不要合并成一个空亡结论。")
        if not future:
            self.paragraph("出座前后续相位：搜索未返回记录。")

    def context(self) -> None:
        self.section("辅助信息")
        fortune = next((r for r in self.p.get("lots", []) if r.get("id") == "fortune"), None)
        if fortune:
            formula = (fortune.get("formula_used") or "").replace("ASC", "上升")
            self.paragraph(f"**福点：** {cell(position(fortune.get('longitude_deg')))}，第 {cell(fortune.get('house', {}).get('integer_house'))} 宫，定位星 {cell(name(fortune.get('domicile_ruler_id')))}。采用公式：{cell(formula)}。")
        hours = self.p.get("planetary_day_hour", {})
        current = hours.get("current_hour") or {}
        if hours.get("status") == "ok":
            self.paragraph(f"**行星日/时：** 日主 {cell(name(hours.get('day_ruler_id')))}，时主 {cell(name(current.get('ruler_id')))}。")
        else:
            self.paragraph("**行星时：** 未确定。")
        for r in self.p.get("considerations_evidence", []):
            if r.get("fact_type") == "asc_sign_degree":
                if r.get("is_below_early_threshold") is True:
                    self.paragraph(f"**上升度数：** 位于本座前 {number(r.get('early_threshold_deg'))}°，属早度数。")
                elif r.get("is_above_late_threshold") is True:
                    self.paragraph(f"**上升度数：** 超过本座 {number(r.get('late_threshold_deg'))}°，属晚度数。")
            elif r.get("fact_type") == "via_combusta" and r.get("in_interval") is True:
                self.paragraph("**月亮：** 位于燃烧之路。")
            elif r.get("fact_type") == "saturn_house_placement" and r.get("in_seventh") is True:
                self.paragraph("**土星：** 位于第七宫。")
        self.paragraph("这些是取用和审盘的辅助事实，不据此自动否定盘的有效性。")
        self.paragraph("本表仅保留通用解盘核心；完整相位候选、事件序列、其他阿拉伯点、映点、赤纬、恒星、天文参数与搜索证据均保留在原 JSON。")
        checked = self.p.get("validation", {}).get("invariant_check")
        self.paragraph(f"数据版本：{SCHEMA_ID}；内部一致性：{'通过' if checked == 'passed' else '未通过/未确认'}。事件搜索为采样搜索，不保证捕获采样间的每一次变化。")

    def render(self) -> str:
        selected = self.selected_candidates()
        self.header()
        self.chart()
        self.aspects(selected)
        self.receptions(selected)
        self.moon()
        self.context()
        return "\n".join(self.lines).rstrip() + "\n"


def format_horary_v3_markdown(packet: dict[str, Any]) -> str:
    if packet.get("schema", {}).get("schema_id") != SCHEMA_ID:
        raise ValueError("expected a Horary v3 packet")
    return Worksheet(packet).render()
