"""Shared event timeline and body indices. Houses use fixed query-chart cusps."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from collections.abc import Callable
from itertools import combinations
from typing import Any

from astro_backend_classical import aspect_offsets_for_angle
from astro_backend_core import CLASSICAL_BODY_IDS, jd_from_datetime, signed_orb, swe, zodiac_sign_index
from astro_backend_ephemeris import house_for_longitude
from astro_backend_horary import CLASSICAL_ANGLES, sign_exit_search_days_for_body
from astro_backend_horary_v2 import CAZIMI_ORB_DEG, COMBUST_ORB_DEG, UNDER_BEAMS_ORB_DEG
from astro_backend_horary_v3_config import HoraryConfig, TimeWindow, parse_utc
from astro_backend_horary_v3_search import EphemerisSampler, EventLedger, SampleUnavailable, scan_roots


class EventTimeline:
    def __init__(self, config: HoraryConfig, sampler: EphemerisSampler, cusps: list[float]):
        self.config = config
        self.sampler = sampler
        self.cusps = cusps
        self.ledger = EventLedger(config.local_time)
        self.coverage: list[dict[str, Any]] = []

    def _search(self, name: str, sample: Callable[[datetime], float], window: TimeWindow,
                step: float, *, angular: bool = True) -> tuple[datetime, ...]:
        result = scan_roots(sample, window, step, angular=angular)
        self.coverage.append({"id": name, **result.payload()})
        if result.status == "unavailable":
            self.sampler.warnings.append(f"{name}: {result.reason}")
        return result.roots

    def _state(self, body_id: str, t: datetime, classifier: Callable[[float], int]) -> tuple[int | None, int | None]:
        try:
            return (classifier(self.sampler.longitude(body_id, t - timedelta(seconds=1))),
                    classifier(self.sampler.longitude(body_id, t + timedelta(seconds=1))))
        except SampleUnavailable:
            return None, None

    def build(self, body_ids: list[str]) -> None:
        cfg, at = self.config, self.config.instant
        for bid in body_ids:
            step = 1 if bid == "MOON" else 6
            sign_window = TimeWindow(
                min(cfg.window.start, at - timedelta(days=4)) if bid == "MOON" else cfg.window.start,
                at + timedelta(days=max(cfg.future_days, 8 if bid == "MOON" else sign_exit_search_days_for_body(bid))),
            )
            for sign in range(12):
                boundary = float(sign * 30)
                roots = self._search(
                    f"sign_ingress|{bid}|{sign}",
                    lambda t, bid=bid, boundary=boundary: signed_orb(self.sampler.longitude(bid, t), boundary),
                    sign_window, step,
                )
                for t in roots:
                    before, after = self._state(bid, t, zodiac_sign_index)
                    if before == after and before is not None:
                        continue
                    self.ledger.add("sign_ingress", t, (bid,), "event.sign_ingress.v3",
                                    discriminator=str(sign), boundary_longitude_deg=boundary,
                                    state_before={"sign_index": before}, state_after={"sign_index": after})
            for house, boundary in enumerate(self.cusps, 1):
                roots = self._search(
                    f"house_change|{bid}|{house}",
                    lambda t, bid=bid, boundary=boundary: signed_orb(self.sampler.longitude(bid, t), boundary),
                    cfg.window, step,
                )
                for t in roots:
                    before, after = self._state(bid, t, lambda lon: house_for_longitude(lon, self.cusps))
                    if before == after and before is not None:
                        continue
                    self.ledger.add("house_change", t, (bid,), "event.fixed_cusp_house_change.v3",
                                    discriminator=str(house), cusp_longitude_deg=boundary,
                                    state_before={"integer_house": before}, state_after={"integer_house": after},
                                    direction="previous" if t < at else "next",
                                    house_frame="fixed_query_chart_cusps")
            if bid not in {"SUN", "MOON"}:
                station_window = TimeWindow(at - timedelta(days=400), at + timedelta(days=400))
                roots = self._search(f"station|{bid}", lambda t, bid=bid: self.sampler.speed(bid, t),
                                     station_window, 6, angular=False)
                for t in roots:
                    try:
                        before = self.sampler.speed(bid, t - timedelta(hours=1))
                        after = self.sampler.speed(bid, t + timedelta(hours=1))
                        kind = "station_direct" if after > before else "station_retrograde"
                    except SampleUnavailable:
                        kind = "station"
                    self.ledger.add(kind, t, (bid,), "event.station.v3", kind=kind)

        # Moon's independent rule scope always includes the classical six targets.
        pairs = set(combinations(sorted(set(body_ids) & set(CLASSICAL_BODY_IDS)), 2))
        pairs.update(tuple(sorted(("MOON", bid))) for bid in CLASSICAL_BODY_IDS if bid != "MOON")
        for a, b in sorted(pairs):
            window = cfg.window
            if "MOON" in (a, b):
                window = TimeWindow(min(window.start, at - timedelta(days=4)),
                                    max(window.end, at + timedelta(days=8)))
            for aspect, angle in CLASSICAL_ANGLES.items():
                for offset in aspect_offsets_for_angle(angle):
                    roots = self._search(
                        f"aspect_exact|{a}|{b}|{aspect}|{offset}",
                        lambda t, a=a, b=b, offset=offset: signed_orb(
                            self.sampler.longitude(a, t), self.sampler.longitude(b, t) + offset),
                        window, 1 if "MOON" in (a, b) else 6,
                    )
                    for t in roots:
                        self.ledger.add("aspect_exact", t, (a, b), "event.aspect_geometry.v3",
                                        aspect_id=aspect, candidate_id=f"{a}|{b}|{aspect}",
                                        branch_offset_deg=offset)
                        if {a, b} == {"MOON", "SUN"} and angle in (0.0, 180.0):
                            self.ledger.add("lunar_phase_exact", t, ("MOON", "SUN"), "event.lunar_phase.v3",
                                            aspect_id=aspect, phase_name="new_moon" if angle == 0 else "full_moon",
                                            phase_angle_deg=angle)
        for bid in body_ids:
            if bid == "SUN":
                continue
            for label, threshold in (("cazimi", CAZIMI_ORB_DEG), ("combust", COMBUST_ORB_DEG),
                                     ("under_beams", UNDER_BEAMS_ORB_DEG)):
                for offset in (-threshold, threshold):
                    roots = self._search(
                        f"solar_{label}_boundary|{bid}|{offset}",
                        lambda t, bid=bid, offset=offset: signed_orb(
                            self.sampler.longitude(bid, t), self.sampler.longitude("SUN", t) + offset),
                        cfg.window, 1 if bid == "MOON" else 6,
                    )
                    for t in roots:
                        self.ledger.add(f"solar_{label}_boundary", t, ("SUN", bid),
                                        f"event.solar_{label}_boundary.v3", threshold_deg=threshold)
        self._sunrise_sunset()

    def _sunrise_sunset(self) -> None:
        cfg = self.config
        geopos = cfg.longitude, cfg.latitude, cfg.altitude_m
        for rise, kind in ((True, "sunrise"), (False, "sunset")):
            probe = cfg.window.start - timedelta(seconds=1)
            found, failed = 0, False
            while probe <= cfg.window.end:
                try:
                    status, times = swe.rise_trans(jd_from_datetime(probe), swe.SUN,
                                                  swe.CALC_RISE if rise else swe.CALC_SET, geopos, 0.0, 0.0)
                    if status == 0:
                        year, month, day, hour = swe.revjul(times[0], swe.GREG_CAL)
                        t = datetime(year, month, day, tzinfo=timezone.utc) + timedelta(hours=hour)
                        if cfg.window.contains(t):
                            self.ledger.add(kind, t, ("SUN",), f"event.{kind}.swiss_rise_trans.v1",
                                            state_before="below_horizon" if rise else "above_horizon",
                                            state_after="above_horizon" if rise else "below_horizon")
                            found += 1
                        if t > probe:
                            probe = t + timedelta(seconds=1)
                            continue
                except swe.Error as exc:
                    failed = True
                    self.sampler.warnings.append(f"{kind}: {exc}")
                probe += timedelta(days=1)
            self.coverage.append({"id": kind, **cfg.window.payload(), "max_step_hours": 24,
                                  "status": "unavailable" if failed else "found" if found else "not_found_in_window",
                                  "method": "swiss_rise_trans_event_iteration_with_daily_polar_probes"})

    def configured_events(self, body_ids: list[str]) -> list[dict[str, Any]]:
        allowed = set(body_ids)
        return [dict(row, in_configured_window=True) for row in self.ledger.rows(self.config.window)
                if set(row["body_ids"]).issubset(allowed)]

    def attach_body_indices(self, bodies: list[dict[str, Any]]) -> None:
        all_rows = self.ledger.rows()
        at = self.config.instant
        for body in bodies:
            bid = body["body_id"]
            own = [r for r in all_rows if r["body_ids"] == [bid]]
            index = {}
            for key, kinds, previous in (
                ("previous_station", {"station", "station_direct", "station_retrograde"}, True),
                ("next_station", {"station", "station_direct", "station_retrograde"}, False),
                ("next_sign_exit", {"sign_ingress"}, False),
                ("previous_house_change", {"house_change"}, True),
                ("next_house_change", {"house_change"}, False),
            ):
                selected = [r for r in own if r["event_type"] in kinds
                            and ((parse_utc(r["datetime_utc"]) < at) if previous else (parse_utc(r["datetime_utc"]) >= at))]
                row = (selected[-1] if previous else selected[0]) if selected else None
                index[key] = None if row is None else {
                    **row, "event_id": row["id"] if self.config.window.contains(parse_utc(row["datetime_utc"])) else None,
                    "in_configured_window": self.config.window.contains(parse_utc(row["datetime_utc"])),
                }
            index["search_coverage"] = [c for c in self.coverage if c["id"].split("|")[0] in {"station", "sign_ingress", "house_change"}
                                        and f"|{bid}|" in c["id"] + "|"]
            body["events_index"] = index
