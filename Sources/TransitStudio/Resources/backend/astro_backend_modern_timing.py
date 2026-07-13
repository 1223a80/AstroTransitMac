from __future__ import annotations

import json
import math
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Optional
from zoneinfo import ZoneInfo

from astro_backend_core import (
    BODY_REGISTRY,
    CLASSICAL_BODY_IDS,
    SIGNS,
    angular_separation,
    moment_to_jd,
    moment_to_local_datetime,
    norm360,
    set_zodiac_mode,
    signed_orb,
    zodiac_sign_index,
)
from astro_backend_ephemeris import (
    body_longitude_at,
    body_speed_at,
    build_houses,
    calculate_positions,
    house_for_longitude,
    resolve_bodies,
)
from astro_backend_modern_points import (
    NODE_BODY_IDS,
    SUPPORTED_ANGLE_IDS,
    finalize_point_set,
    resolve_point_set,
)
from astro_backend_midpoints import (
    build_canonical_midpoint_axis,
    resolve_natal_midpoint_points,
)
from astro_backend_progressions import _calc_progressed_dt
from astro_backend_scan import (
    MAX_SCAN_WORK_UNITS,
    SCAN_CONFIRMATION_WORK_UNITS,
    SCAN_SOFT_WARNING_WORK_UNITS,
    exact_longitudes_for_aspect,
    reject_oversized_scan,
    step_for_body,
)
from astro_backend_solar_arc import true_solar_arc_value


PROGRESSED_STEP = timedelta(days=7)
SOLAR_ARC_STEP = timedelta(days=7)
ROOT_TIME_TOLERANCE_SECONDS = 0.05
ROOT_VALUE_TOLERANCE = 1e-10
EXACT_DEDUPE_SECONDS = 0.5

TECHNIQUE_EVENT_TYPES = {
    "transit": {"aspect", "ingress", "station"},
    "secondary_progression": {"aspect", "moon_ingress", "lunation"},
    "solar_arc": {"aspect"},
}

ANGLE_NAMES = {
    "ASC": "ASC",
    "MC": "MC",
    "DSC": "DSC",
    "IC": "IC",
    "VERTEX": "Vertex",
    "ANTIVERTEX": "Antivertex",
    "EQUATORIAL_ASCENDANT": "East Point (Equatorial Ascendant)",
}

LUNATION_PHASES = {
    0.0: ("new_moon", "新月"),
    90.0: ("first_quarter", "上弦月"),
    180.0: ("full_moon", "满月"),
    270.0: ("last_quarter", "下弦月"),
}


@dataclass(frozen=True)
class TargetPoint:
    point_id: str
    name: str
    kind: str
    longitude: float
    axis_branch: str | None = None


@dataclass(frozen=True)
class PositionValue:
    longitude: float
    speed: float
    name: str
    ephemeris: str


NumericEvaluator = Callable[[datetime], Optional[float]]
PositionEvaluator = Callable[[datetime], Optional[PositionValue]]


def _iso_utc(value: datetime | None) -> str | None:
    if value is None:
        return None
    return value.astimezone(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _iso_local(value: datetime, display_zone: ZoneInfo) -> str:
    return value.astimezone(display_zone).isoformat(timespec="milliseconds")


def _id_stamp(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def _motion(speed: float) -> str:
    if speed > 1e-9:
        return "direct"
    if speed < -1e-9:
        return "retrograde"
    return "stationary"


def _spec_for_id(point_id: str, warnings: list[str]) -> Any | None:
    if point_id in BODY_REGISTRY:
        return BODY_REGISTRY[point_id]
    if point_id.startswith("AST:"):
        try:
            number = int(point_id.split(":", 1)[1])
        except (TypeError, ValueError):
            return None
        specs = resolve_bodies([], [number], warnings)
        return specs[0] if specs else None
    return None


def _step_for(source_type: str, point_id: str, warnings: list[str] | None = None) -> timedelta:
    if source_type == "secondary_progression":
        return PROGRESSED_STEP
    if source_type == "solar_arc":
        return SOLAR_ARC_STEP
    spec = _spec_for_id(point_id, warnings or [])
    return step_for_body(spec) if spec is not None else timedelta(days=2)


def _estimated_steps(start_utc: datetime, end_utc: datetime, step: timedelta) -> int:
    seconds = max((end_utc - start_utc).total_seconds(), 0.0)
    return int(seconds // max(step.total_seconds(), 1.0)) + 1


def estimate_modern_timing_work_units(
    start_utc: datetime,
    end_utc: datetime,
    techniques: list[dict[str, Any]],
    target_count: int,
) -> int:
    total = 0
    for technique in techniques:
        source_type = str(technique.get("id", ""))
        moving_ids = list(dict.fromkeys(technique.get("moving_body_ids", [])))
        event_types = set(technique.get("event_types", []))
        step_counts = {
            point_id: _estimated_steps(start_utc, end_utc, _step_for(source_type, point_id))
            for point_id in moving_ids
        }
        summed_steps = sum(step_counts.values())
        if "aspect" in event_types:
            branch_count = sum(
                len(exact_longitudes_for_aspect(0.0, float(aspect["angle"])))
                for aspect in technique.get("aspects", [])
            )
            total += summed_steps * max(target_count, 1) * max(branch_count, 1)
        if source_type == "transit" and "ingress" in event_types:
            total += summed_steps
        if source_type == "transit" and "station" in event_types:
            total += summed_steps
        if source_type == "secondary_progression" and "moon_ingress" in event_types and "MOON" in moving_ids:
            total += step_counts.get("MOON", _estimated_steps(start_utc, end_utc, PROGRESSED_STEP))
        if source_type == "secondary_progression" and "lunation" in event_types:
            total += _estimated_steps(start_utc, end_utc, PROGRESSED_STEP)
    return max(total, 1)


def _refine_root(
    evaluator: NumericEvaluator,
    left: datetime,
    right: datetime,
) -> tuple[datetime, float] | None:
    f_left = evaluator(left)
    f_right = evaluator(right)
    if f_left is None or f_right is None:
        return None
    if abs(f_left) <= ROOT_VALUE_TOLERANCE:
        return left, abs(f_left)
    if abs(f_right) <= ROOT_VALUE_TOLERANCE:
        return right, abs(f_right)
    if f_left * f_right > 0:
        return None

    for _ in range(80):
        middle = left + (right - left) / 2
        f_middle = evaluator(middle)
        if f_middle is None:
            return None
        if abs(f_middle) <= ROOT_VALUE_TOLERANCE or (right - left).total_seconds() <= ROOT_TIME_TOLERANCE_SECONDS:
            return middle, abs(f_middle)
        if f_left * f_middle <= 0:
            right = middle
            f_right = f_middle
        else:
            left = middle
            f_left = f_middle
    middle = left + (right - left) / 2
    residual = evaluator(middle)
    return (middle, abs(residual)) if residual is not None else None


def _dedupe_roots(values: list[tuple[datetime, float]]) -> list[tuple[datetime, float]]:
    ordered = sorted(values, key=lambda item: item[0])
    result: list[tuple[datetime, float]] = []
    for value in ordered:
        if result and abs((value[0] - result[-1][0]).total_seconds()) < EXACT_DEDUPE_SECONDS:
            if value[1] < result[-1][1]:
                result[-1] = value
            continue
        result.append(value)
    return result


def _find_roots(
    evaluator: NumericEvaluator,
    start_utc: datetime,
    end_utc: datetime,
    step: timedelta,
) -> list[tuple[datetime, float]]:
    roots: list[tuple[datetime, float]] = []
    left = start_utc
    f_left = evaluator(left)
    while left < end_utc:
        right = min(left + step, end_utc)
        f_right = evaluator(right)
        if f_left is not None and f_right is not None:
            if abs(f_left) <= ROOT_VALUE_TOLERANCE:
                roots.append((left, abs(f_left)))
            changed_sign = f_left * f_right < 0
            # A ±180 wrap is not an exact crossing of this branch.
            if changed_sign and abs(f_right - f_left) < 180.0:
                refined = _refine_root(evaluator, left, right)
                if refined is not None:
                    roots.append(refined)
            if right == end_utc and abs(f_right) <= ROOT_VALUE_TOLERANCE:
                roots.append((right, abs(f_right)))
        left = right
        f_left = f_right
    return _dedupe_roots(roots)


def _lifecycle_bounds(
    orb_boundary_evaluator: NumericEvaluator,
    exact_utc: datetime,
    start_utc: datetime,
    end_utc: datetime,
    step: timedelta,
    orb_limit: float,
) -> tuple[datetime | None, datetime | None, bool, bool]:
    if orb_limit <= 1e-12:
        return exact_utc, exact_utc, False, False

    def search_left() -> tuple[datetime | None, bool]:
        inside = exact_utc
        while inside > start_utc:
            outside = max(start_utc, inside - step)
            value = orb_boundary_evaluator(outside)
            if value is None:
                return None, False
            if value > 0:
                refined = _refine_root(orb_boundary_evaluator, outside, inside)
                return (refined[0] if refined is not None else None), False
            if outside == start_utc:
                return None, True
            inside = outside
        return None, True

    def search_right() -> tuple[datetime | None, bool]:
        inside = exact_utc
        while inside < end_utc:
            outside = min(end_utc, inside + step)
            value = orb_boundary_evaluator(outside)
            if value is None:
                return None, False
            if value > 0:
                refined = _refine_root(orb_boundary_evaluator, inside, outside)
                return (refined[0] if refined is not None else None), False
            if outside == end_utc:
                return None, True
            inside = outside
        return None, True

    entering, clipped_start = search_left()
    leaving, clipped_end = search_right()
    return entering, leaving, clipped_start, clipped_end


class TimingContext:
    def __init__(
        self,
        request: dict[str, Any],
        warnings: list[str],
        sidereal: bool,
    ) -> None:
        self.request = request
        self.warnings = warnings
        self.sidereal = sidereal
        self.warning_keys: set[str] = set()
        self.ephemerides: set[str] = set()
        self.birth = request["birth"]
        self.birth_utc = moment_to_local_datetime(self.birth["moment"]).astimezone(timezone.utc)
        self.birth_jd, _ = moment_to_jd(self.birth["moment"])
        self.latitude = float(self.birth["latitude"])
        self.longitude = float(self.birth["longitude"])
        self.house_system = self.birth.get("houseSystem", self.birth.get("house_system", "whole_sign"))
        self.cusps, self.angles, _ = build_houses(
            self.birth_jd,
            self.latitude,
            self.longitude,
            self.house_system,
            sidereal,
            warnings,
        )
        self.natal_cache: dict[str, PositionValue] = {}

    def body_position(self, point_id: str, at_utc: datetime) -> PositionValue | None:
        spec = _spec_for_id(point_id, self.warnings)
        if spec is None:
            return None
        longitude_value = body_longitude_at(
            at_utc, spec, self.warnings, self.warning_keys, sidereal=self.sidereal
        )
        speed_value = body_speed_at(
            at_utc, spec, self.warnings, self.warning_keys, sidereal=self.sidereal
        )
        if longitude_value is None or speed_value is None:
            return None
        longitude, ephemeris_a = longitude_value
        speed, ephemeris_b = speed_value
        self.ephemerides.update((ephemeris_a, ephemeris_b))
        return PositionValue(longitude, speed, spec.name, ephemeris_a)

    def natal_position(self, point_id: str) -> PositionValue | None:
        cached = self.natal_cache.get(point_id)
        if cached is not None:
            return cached
        if point_id in self.angles:
            value = PositionValue(
                float(self.angles[point_id]),
                0.0,
                ANGLE_NAMES.get(point_id, point_id),
                "Swiss Ephemeris",
            )
        else:
            value = self.body_position(point_id, self.birth_utc)
        if value is not None:
            self.natal_cache[point_id] = value
        return value

    def transit_evaluator(self, point_id: str) -> PositionEvaluator:
        return lambda at_utc: self.body_position(point_id, at_utc)

    def progression_evaluator(self, point_id: str) -> PositionEvaluator:
        def evaluate(at_utc: datetime) -> PositionValue | None:
            progressed_utc, _ = _calc_progressed_dt(self.birth_utc, at_utc)
            value = self.body_position(point_id, progressed_utc)
            if value is None:
                return None
            return PositionValue(
                value.longitude,
                value.speed / 365.2422,
                value.name,
                value.ephemeris,
            )

        return evaluate

    def solar_arc_evaluator(self, point_id: str) -> PositionEvaluator:
        natal_point = self.natal_position(point_id)
        natal_sun = self.natal_position("SUN")

        def evaluate(at_utc: datetime) -> PositionValue | None:
            if natal_point is None or natal_sun is None:
                return None
            progressed_utc, _ = _calc_progressed_dt(self.birth_utc, at_utc)
            progressed_sun = self.body_position("SUN", progressed_utc)
            if progressed_sun is None:
                return None
            arc = true_solar_arc_value(natal_sun.longitude, progressed_sun.longitude)
            return PositionValue(
                norm360(natal_point.longitude + arc),
                progressed_sun.speed / 365.2422,
                natal_point.name,
                progressed_sun.ephemeris,
            )

        return evaluate

    def evaluator(self, source_type: str, point_id: str) -> PositionEvaluator:
        if source_type == "transit":
            return self.transit_evaluator(point_id)
        if source_type == "secondary_progression":
            return self.progression_evaluator(point_id)
        if source_type == "solar_arc":
            return self.solar_arc_evaluator(point_id)
        raise ValueError(f"未知 timing technique：{source_type}")


def _build_targets(
    context: TimingContext,
    raw_point_set: Any,
    node_mode: str,
) -> tuple[list[TargetPoint], dict[str, Any]]:
    raw_config = dict(raw_point_set) if isinstance(raw_point_set, dict) else raw_point_set
    midpoint_pairs = _canonical_midpoint_pairs(
        raw_config.get("midpoint_pairs", []) if isinstance(raw_config, dict) else []
    )
    regular_config = dict(raw_config) if isinstance(raw_config, dict) else raw_config
    if isinstance(regular_config, dict):
        regular_config.pop("midpoint_pairs", None)
        if midpoint_pairs:
            # Once midpoint pairs are present, omitted ordinary selectors mean
            # empty rather than resolve_point_set's legacy defaults. Explicit
            # ordinary selectors still opt into mixed targets.
            regular_config.setdefault("body_ids", [])
            regular_config.setdefault("include_nodes", False)
            regular_config.setdefault("custom_asteroids", [])
            regular_config.setdefault("angle_ids", [])
            regular_config.setdefault("house_cusps", [])
            regular_config.setdefault("lot_ids", [])

    point_set = resolve_point_set(regular_config, node_mode=node_mode)
    body_ids = list(point_set["resolved_body_ids"])
    specs = resolve_bodies(
        [point_id for point_id in body_ids if not point_id.startswith("AST:")],
        list(point_set["custom_asteroids"]),
        context.warnings,
    )
    positions = calculate_positions(context.birth_jd, specs, context.warnings, sidereal=context.sidereal)
    targets = [
        TargetPoint(row["body_id"], row["name"], "body", float(row["longitude"]))
        for row in positions
        if row["body_id"] in body_ids
    ]
    available_body_ids = [target.point_id for target in targets]

    available_angles: list[str] = []
    for angle_id in point_set["angle_ids"]:
        longitude = context.angles.get(angle_id)
        if longitude is None or not math.isfinite(float(longitude)):
            context.warnings.append(f"轴点 {angle_id} 不可用，已从 timing target_point_set 移除。")
            continue
        targets.append(TargetPoint(angle_id, ANGLE_NAMES.get(angle_id, angle_id), "angle", float(longitude)))
        available_angles.append(angle_id)

    available_houses: list[int] = []
    for house in point_set["house_cusps"]:
        if 1 <= house <= len(context.cusps):
            targets.append(
                TargetPoint(
                    f"HOUSE_CUSP_{house}",
                    f"第 {house} 宫宫头",
                    "house_cusp",
                    float(context.cusps[house - 1]),
                )
            )
            available_houses.append(house)

    available_lots: list[str] = []
    if point_set["lot_ids"]:
        from astro_backend_classical_lots import calculate_lots

        classical_specs = [BODY_REGISTRY[body_id] for body_id in CLASSICAL_BODY_IDS]
        classical_positions = calculate_positions(
            context.birth_jd, classical_specs, context.warnings, sidereal=context.sidereal
        )
        positions_by_id = {row["body_id"]: row for row in classical_positions}
        sun = positions_by_id.get("SUN")
        is_day = bool(sun and house_for_longitude(float(sun["longitude"]), context.cusps) >= 7)
        lot_rows = calculate_lots(
            context.angles,
            positions_by_id,
            context.cusps,
            is_day,
            mc=context.angles.get("MC"),
            warnings=context.warnings,
        )
        lots_by_id = {row["id"]: row for row in lot_rows}
        for lot_id in point_set["lot_ids"]:
            row = lots_by_id.get(lot_id)
            if row is None:
                context.warnings.append(f"阿拉伯点 {lot_id} 不可用，已从 timing target_point_set 移除。")
                continue
            targets.append(TargetPoint(lot_id, str(row["name"]), "lot", float(row["longitude"])))
            available_lots.append(lot_id)

    effective = finalize_point_set(
        point_set,
        available_body_ids,
        available_angle_ids=available_angles,
        warnings=context.warnings,
    )
    effective["house_cusps"] = available_houses
    effective["lot_ids"] = available_lots

    if midpoint_pairs:
        endpoint_ids = sorted({point_id for pair in midpoint_pairs for point_id in pair})
        endpoint_point_set = _midpoint_endpoint_point_set(endpoint_ids, node_mode)
        endpoint_points, _ = resolve_natal_midpoint_points(
            context,
            endpoint_point_set,
            context.warnings,
            node_mode=node_mode,
        )
        point_by_id = {str(point["point_id"]): point for point in endpoint_points}
        effective_pairs: list[dict[str, str]] = []
        for point_a_id, point_b_id in midpoint_pairs:
            point_a = point_by_id.get(point_a_id)
            point_b = point_by_id.get(point_b_id)
            missing_ids = [
                point_id
                for point_id, point in ((point_a_id, point_a), (point_b_id, point_b))
                if point is None
            ]
            if missing_ids:
                raise ValueError(
                    "timing midpoint pair endpoints are unavailable: " + ", ".join(missing_ids)
                )
            axis = build_canonical_midpoint_axis(point_a, point_b)
            axis_name = f"{axis['point_a_name']}/{axis['point_b_name']} 中点轴"
            targets.extend([
                TargetPoint(
                    str(axis["id"]),
                    axis_name,
                    "midpoint_axis",
                    float(axis["midpoint_longitude"]),
                    "direct",
                ),
                TargetPoint(
                    str(axis["id"]),
                    axis_name,
                    "midpoint_axis",
                    float(axis["opposite_longitude"]),
                    "opposite",
                ),
            ])
            effective_pairs.append({
                "point_a_id": str(axis["point_a_id"]),
                "point_b_id": str(axis["point_b_id"]),
            })
        effective["midpoint_pairs"] = effective_pairs
    return targets, effective


def _canonical_midpoint_pairs(raw_pairs: Any) -> list[tuple[str, str]]:
    if raw_pairs is None:
        return []
    if not isinstance(raw_pairs, list):
        raise ValueError("target_point_set.midpoint_pairs must be an array")
    result: list[tuple[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for index, raw_pair in enumerate(raw_pairs):
        if not isinstance(raw_pair, dict):
            raise ValueError(f"target_point_set.midpoint_pairs[{index}] must be an object")
        point_a_id = raw_pair.get("point_a_id")
        point_b_id = raw_pair.get("point_b_id")
        if not isinstance(point_a_id, str) or not point_a_id or not isinstance(point_b_id, str) or not point_b_id:
            raise ValueError(
                f"target_point_set.midpoint_pairs[{index}] requires non-empty point_a_id and point_b_id"
            )
        if point_a_id == point_b_id:
            raise ValueError(f"target_point_set.midpoint_pairs[{index}] endpoints must be different")
        pair = tuple(sorted((point_a_id, point_b_id)))
        if pair in seen:
            raise ValueError(
                f"target_point_set.midpoint_pairs contains duplicate pair: {pair[0]}|{pair[1]}"
            )
        seen.add(pair)
        result.append(pair)
    return sorted(result)


def _midpoint_endpoint_point_set(endpoint_ids: list[str], node_mode: str) -> dict[str, Any]:
    body_ids: list[str] = []
    custom_asteroids: list[int] = []
    angle_ids: list[str] = []
    house_cusps: list[int] = []
    lot_ids: list[str] = []
    include_nodes = False

    for point_id in endpoint_ids:
        if point_id in NODE_BODY_IDS:
            include_nodes = True
        elif point_id in BODY_REGISTRY:
            body_ids.append(point_id)
        elif point_id.startswith("AST:") and point_id.split(":", 1)[1].isdigit():
            number = int(point_id.split(":", 1)[1])
            if number <= 0:
                raise ValueError(f"invalid timing midpoint asteroid endpoint: {point_id}")
            custom_asteroids.append(number)
        elif point_id in SUPPORTED_ANGLE_IDS:
            angle_ids.append(point_id)
        elif point_id.startswith("HOUSE_CUSP_") and point_id.removeprefix("HOUSE_CUSP_").isdigit():
            house = int(point_id.removeprefix("HOUSE_CUSP_"))
            if not 1 <= house <= 12:
                raise ValueError(f"invalid timing midpoint house cusp endpoint: {point_id}")
            house_cusps.append(house)
        else:
            # Shared point-set validation remains the authority for Lot IDs;
            # unknown free-form endpoints fail there rather than being ignored.
            lot_ids.append(point_id)

    return {
        "body_ids": body_ids,
        "include_nodes": include_nodes,
        "node_mode": node_mode,
        "custom_asteroids": custom_asteroids,
        "angle_ids": angle_ids,
        "house_cusps": house_cusps,
        "lot_ids": lot_ids,
    }


def _aspect_orb(longitude: float, target_longitude: float, angle: float) -> float:
    return abs(angular_separation(longitude, target_longitude) - angle)


def _aspect_events(
    context: TimingContext,
    source_type: str,
    moving_ids: list[str],
    aspects: list[dict[str, Any]],
    targets: list[TargetPoint],
    start_utc: datetime,
    end_utc: datetime,
    display_zone: ZoneInfo,
    progress_tick: Callable[[str], None],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    method_key = {
        "transit": "transit_longitude_bisection",
        "secondary_progression": "secondary_progression_day_for_year_bisection",
        "solar_arc": "true_solar_arc_bisection",
    }[source_type]
    for moving_id in moving_ids:
        evaluator = context.evaluator(source_type, moving_id)
        step = _step_for(source_type, moving_id, context.warnings)
        for target in targets:
            for aspect in aspects:
                angle = float(aspect["angle"])
                orb_limit = float(aspect["orb"])
                exact_longitudes = exact_longitudes_for_aspect(target.longitude, angle)
                for exact_longitude in exact_longitudes:
                    branch_evaluator: NumericEvaluator = lambda at_utc, exact=exact_longitude: (
                        signed_orb(value.longitude, exact)
                        if (value := evaluator(at_utc)) is not None
                        else None
                    )
                    roots = _find_roots(branch_evaluator, start_utc, end_utc, step)
                    for exact_utc, residual in roots:
                        exact_value = evaluator(exact_utc)
                        if exact_value is None:
                            continue
                        boundary_evaluator: NumericEvaluator = lambda at_utc: (
                            _aspect_orb(value.longitude, target.longitude, angle) - orb_limit
                            if (value := evaluator(at_utc)) is not None
                            else None
                        )
                        entering, leaving, clipped_start, clipped_end = _lifecycle_bounds(
                            boundary_evaluator,
                            exact_utc,
                            start_utc,
                            end_utc,
                            step,
                            orb_limit,
                        )
                        branch_suffix = f"|{target.axis_branch}" if target.axis_branch else ""
                        group_id = f"{source_type}|{moving_id}|{aspect['id']}|{target.point_id}{branch_suffix}"
                        rows.append(
                            {
                                "id": f"{group_id}|{_id_stamp(exact_utc)}",
                                "group_id": group_id,
                                "source_type": source_type,
                                "event_type": "aspect",
                                "moving_point_id": moving_id,
                                "moving_point_name": exact_value.name,
                                "target_point_id": target.point_id,
                                "target_point_name": target.name,
                                "target_point_kind": target.kind,
                                "target_axis_branch": target.axis_branch,
                                "aspect_id": aspect["id"],
                                "aspect_name": aspect["name"],
                                "aspect_angle": angle,
                                "orb_limit": orb_limit,
                                "entering_utc": _iso_utc(entering),
                                "exact_utc": _iso_utc(exact_utc),
                                "leaving_utc": _iso_utc(leaving),
                                "exact_local": _iso_local(exact_utc, display_zone),
                                "motion": _motion(exact_value.speed),
                                "moving_longitude": round(exact_value.longitude, 9),
                                "target_longitude": round(target.longitude, 9),
                                "exact_orb": round(min(residual, _aspect_orb(exact_value.longitude, target.longitude, angle)), 12),
                                "pass_index_in_window": 0,
                                "pass_count_in_window": 0,
                                "window_clipped_start": clipped_start,
                                "window_clipped_end": clipped_end,
                                "method_key": method_key,
                            }
                        )
        progress_tick(f"{source_type}:{moving_id}")
    return rows


def _ingress_events(
    context: TimingContext,
    source_type: str,
    moving_ids: list[str],
    event_type: str,
    start_utc: datetime,
    end_utc: datetime,
    display_zone: ZoneInfo,
    progress_tick: Callable[[str], None],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for moving_id in moving_ids:
        evaluator = context.evaluator(source_type, moving_id)
        step = _step_for(source_type, moving_id, context.warnings)
        left = start_utc
        left_value = evaluator(left)
        while left < end_utc:
            right = min(left + step, end_utc)
            right_value = evaluator(right)
            if left_value is None or right_value is None:
                left, left_value = right, right_value
                continue
            left_sign = zodiac_sign_index(left_value.longitude)
            right_sign = zodiac_sign_index(right_value.longitude)
            delta = signed_orb(right_value.longitude, left_value.longitude)
            if left_sign != right_sign and abs(delta) < 20.0:
                direct = delta > 0
                boundary_sign = right_sign if direct else left_sign
                exact_longitude = boundary_sign * 30.0
                root_evaluator: NumericEvaluator = lambda at_utc, exact=exact_longitude: (
                    signed_orb(value.longitude, exact)
                    if (value := evaluator(at_utc)) is not None
                    else None
                )
                refined = _refine_root(root_evaluator, left, right)
                if refined is not None:
                    exact_utc, residual = refined
                    exact_value = evaluator(exact_utc)
                    if exact_value is not None:
                        target_sign = right_sign
                        target_id = f"SIGN_{target_sign}"
                        group_id = f"{source_type}|{moving_id}|{event_type}|{target_id}"
                        rows.append(
                            {
                                "id": f"{group_id}|{_id_stamp(exact_utc)}",
                                "group_id": group_id,
                                "source_type": source_type,
                                "event_type": event_type,
                                "moving_point_id": moving_id,
                                "moving_point_name": exact_value.name,
                                "target_point_id": target_id,
                                "target_point_name": SIGNS[target_sign],
                                "target_point_kind": "sign",
                                "target_axis_branch": None,
                                "aspect_id": None,
                                "aspect_name": None,
                                "aspect_angle": None,
                                "orb_limit": None,
                                "entering_utc": None,
                                "exact_utc": _iso_utc(exact_utc),
                                "leaving_utc": None,
                                "exact_local": _iso_local(exact_utc, display_zone),
                                "motion": "direct" if direct else "retrograde",
                                "moving_longitude": round(exact_value.longitude, 9),
                                "target_longitude": round(exact_longitude, 9),
                                "exact_orb": round(residual, 12),
                                "pass_index_in_window": 0,
                                "pass_count_in_window": 0,
                                "window_clipped_start": False,
                                "window_clipped_end": False,
                                "method_key": (
                                    "transit_ingress_bisection"
                                    if source_type == "transit"
                                    else "secondary_progression_moon_ingress_bisection"
                                ),
                            }
                        )
            left, left_value = right, right_value
        progress_tick(f"{source_type}:{moving_id}:{event_type}")
    return rows


def _station_events(
    context: TimingContext,
    moving_ids: list[str],
    start_utc: datetime,
    end_utc: datetime,
    display_zone: ZoneInfo,
    progress_tick: Callable[[str], None],
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for moving_id in moving_ids:
        evaluator = context.transit_evaluator(moving_id)
        step = _step_for("transit", moving_id, context.warnings)
        speed_evaluator: NumericEvaluator = lambda at_utc: (
            value.speed if (value := evaluator(at_utc)) is not None else None
        )
        for exact_utc, residual in _find_roots(speed_evaluator, start_utc, end_utc, step):
            exact_value = evaluator(exact_utc)
            if exact_value is None:
                continue
            group_id = f"transit|{moving_id}|station"
            rows.append(
                {
                    "id": f"{group_id}|{_id_stamp(exact_utc)}",
                    "group_id": group_id,
                    "source_type": "transit",
                    "event_type": "station",
                    "moving_point_id": moving_id,
                    "moving_point_name": exact_value.name,
                    "target_point_id": None,
                    "target_point_name": None,
                    "target_point_kind": None,
                    "target_axis_branch": None,
                    "aspect_id": None,
                    "aspect_name": None,
                    "aspect_angle": None,
                    "orb_limit": None,
                    "entering_utc": None,
                    "exact_utc": _iso_utc(exact_utc),
                    "leaving_utc": None,
                    "exact_local": _iso_local(exact_utc, display_zone),
                    "motion": "stationary",
                    "moving_longitude": round(exact_value.longitude, 9),
                    "target_longitude": None,
                    "exact_orb": round(residual, 12),
                    "pass_index_in_window": 0,
                    "pass_count_in_window": 0,
                    "window_clipped_start": False,
                    "window_clipped_end": False,
                    "method_key": "transit_station_speed_bisection",
                }
            )
        progress_tick(f"transit:{moving_id}:station")
    return rows


def _lunation_events(
    context: TimingContext,
    start_utc: datetime,
    end_utc: datetime,
    display_zone: ZoneInfo,
    progress_tick: Callable[[str], None],
) -> list[dict[str, Any]]:
    moon_evaluator = context.progression_evaluator("MOON")
    sun_evaluator = context.progression_evaluator("SUN")
    rows: list[dict[str, Any]] = []
    for phase_angle, (phase_id, phase_name) in LUNATION_PHASES.items():
        phase_evaluator: NumericEvaluator = lambda at_utc, angle=phase_angle: (
            signed_orb(norm360(moon.longitude - sun.longitude), angle)
            if (moon := moon_evaluator(at_utc)) is not None
            and (sun := sun_evaluator(at_utc)) is not None
            else None
        )
        for exact_utc, residual in _find_roots(
            phase_evaluator, start_utc, end_utc, PROGRESSED_STEP
        ):
            moon = moon_evaluator(exact_utc)
            sun = sun_evaluator(exact_utc)
            if moon is None or sun is None:
                continue
            group_id = f"secondary_progression|MOON|{phase_id}|SUN"
            rows.append(
                {
                    "id": f"{group_id}|{_id_stamp(exact_utc)}",
                    "group_id": group_id,
                    "source_type": "secondary_progression",
                    "event_type": "lunation",
                    "moving_point_id": "MOON",
                    "moving_point_name": moon.name,
                    "target_point_id": "SUN",
                    "target_point_name": sun.name,
                    "target_point_kind": "body",
                    "target_axis_branch": None,
                    "aspect_id": phase_id,
                    "aspect_name": phase_name,
                    "aspect_angle": phase_angle,
                    "orb_limit": None,
                    "entering_utc": None,
                    "exact_utc": _iso_utc(exact_utc),
                    "leaving_utc": None,
                    "exact_local": _iso_local(exact_utc, display_zone),
                    "motion": _motion(moon.speed),
                    "moving_longitude": round(moon.longitude, 9),
                    "target_longitude": round(sun.longitude, 9),
                    "exact_orb": round(residual, 12),
                    "pass_index_in_window": 0,
                    "pass_count_in_window": 0,
                    "window_clipped_start": False,
                    "window_clipped_end": False,
                    "method_key": "secondary_progression_lunation_bisection",
                }
            )
    progress_tick("secondary_progression:lunation")
    return rows


def _dedupe_and_number_events(events: list[dict[str, Any]]) -> list[dict[str, Any]]:
    by_group: dict[str, list[dict[str, Any]]] = {}
    for event in events:
        by_group.setdefault(str(event["group_id"]), []).append(event)

    result: list[dict[str, Any]] = []
    for group_events in by_group.values():
        ordered = sorted(group_events, key=lambda row: row["exact_utc"])
        unique: list[dict[str, Any]] = []
        for event in ordered:
            exact = datetime.fromisoformat(str(event["exact_utc"]).replace("Z", "+00:00"))
            if unique:
                previous = datetime.fromisoformat(str(unique[-1]["exact_utc"]).replace("Z", "+00:00"))
                if abs((exact - previous).total_seconds()) < EXACT_DEDUPE_SECONDS:
                    if float(event.get("exact_orb") or 0.0) < float(unique[-1].get("exact_orb") or 0.0):
                        unique[-1] = event
                    continue
            unique.append(event)
        count = len(unique)
        for index, event in enumerate(unique, start=1):
            event["pass_index_in_window"] = index
            event["pass_count_in_window"] = count
            result.append(event)
    return sorted(result, key=lambda row: (row["exact_utc"], row["id"]))


def _progress_work_item_count(techniques: list[dict[str, Any]]) -> int:
    count = 0
    for technique in techniques:
        source_type = technique["id"]
        moving_count = len(technique.get("moving_body_ids", []))
        event_types = set(technique.get("event_types", []))
        if "aspect" in event_types:
            count += moving_count
        if source_type == "transit" and "ingress" in event_types:
            count += moving_count
        if source_type == "transit" and "station" in event_types:
            count += moving_count
        if source_type == "secondary_progression" and "moon_ingress" in event_types:
            count += 1
        if source_type == "secondary_progression" and "lunation" in event_types:
            count += 1
    return max(count, 1)


def calculate_modern_timing(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    start_utc = moment_to_local_datetime(request["start"]).astimezone(timezone.utc)
    end_utc = moment_to_local_datetime(request["end"]).astimezone(timezone.utc)
    display_timezone = str(request["display_timezone"])
    display_zone = ZoneInfo(display_timezone)
    birth = request["birth"]
    zodiac = request.get("zodiac") or birth.get("zodiac", "tropical")
    sidereal = set_zodiac_mode(zodiac, warnings)
    raw_point_set = request.get("target_point_set")
    node_mode = str((raw_point_set or {}).get("node_mode", request.get("node_mode", "true_node")))
    techniques = list(request.get("techniques", []))

    context = TimingContext(request, warnings, sidereal)
    targets, effective_point_set = _build_targets(context, raw_point_set, node_mode)
    estimated_work_units = estimate_modern_timing_work_units(
        start_utc, end_utc, techniques, len(targets)
    )
    reject_oversized_scan(
        estimated_work_units,
        warnings,
        confirmed=bool(request.get("confirmed_heavy_scan", False)),
    )

    total_progress_items = _progress_work_item_count(techniques)
    completed_progress_items = 0

    def progress_tick(label: str) -> None:
        nonlocal completed_progress_items
        completed_progress_items += 1
        progress = min(completed_progress_items / total_progress_items, 1.0)
        sys.stderr.write(
            json.dumps({"progress": progress, "label": label}, ensure_ascii=False) + "\n"
        )
        sys.stderr.flush()

    events: list[dict[str, Any]] = []
    section_errors: dict[str, str] = {}
    for technique in techniques:
        source_type = technique["id"]
        moving_ids = list(dict.fromkeys(technique.get("moving_body_ids", [])))
        event_types = set(technique.get("event_types", []))
        try:
            if "aspect" in event_types:
                events.extend(
                    _aspect_events(
                        context,
                        source_type,
                        moving_ids,
                        technique.get("aspects", []),
                        targets,
                        start_utc,
                        end_utc,
                        display_zone,
                        progress_tick,
                    )
                )
            if source_type == "transit" and "ingress" in event_types:
                events.extend(
                    _ingress_events(
                        context,
                        source_type,
                        moving_ids,
                        "ingress",
                        start_utc,
                        end_utc,
                        display_zone,
                        progress_tick,
                    )
                )
            if source_type == "transit" and "station" in event_types:
                events.extend(
                    _station_events(
                        context,
                        moving_ids,
                        start_utc,
                        end_utc,
                        display_zone,
                        progress_tick,
                    )
                )
            if source_type == "secondary_progression" and "moon_ingress" in event_types:
                moon_ids = ["MOON"] if "MOON" in moving_ids else []
                events.extend(
                    _ingress_events(
                        context,
                        source_type,
                        moon_ids,
                        "moon_ingress",
                        start_utc,
                        end_utc,
                        display_zone,
                        progress_tick,
                    )
                )
            if source_type == "secondary_progression" and "lunation" in event_types:
                events.extend(
                    _lunation_events(
                        context, start_utc, end_utc, display_zone, progress_tick
                    )
                )
        except Exception as exc:
            section_errors[source_type] = str(exc)
            warnings.append(f"综合时间线技法 {source_type} 计算失败：{exc}")

    if completed_progress_items < total_progress_items:
        sys.stderr.write(json.dumps({"progress": 1.0, "label": "modern_timing"}) + "\n")
        sys.stderr.flush()

    events = _dedupe_and_number_events(events)
    ephemeris = ", ".join(sorted(context.ephemerides)) if context.ephemerides else "Swiss Ephemeris"
    return {
        "meta": {
            "schema_version": 1,
            "start_utc": _iso_utc(start_utc),
            "end_utc": _iso_utc(end_utc),
            "display_timezone": display_timezone,
            "technique_ids": [technique["id"] for technique in techniques],
            "technique_configs": techniques,
            "target_count": len(targets),
            "estimated_work_units": estimated_work_units,
            "ephemeris": ephemeris,
            "effective_point_set": effective_point_set,
        },
        "events": events,
        "warnings": warnings,
        "section_errors": section_errors or None,
    }


__all__ = [
    "MAX_SCAN_WORK_UNITS",
    "SCAN_CONFIRMATION_WORK_UNITS",
    "SCAN_SOFT_WARNING_WORK_UNITS",
    "TECHNIQUE_EVENT_TYPES",
    "calculate_modern_timing",
    "estimate_modern_timing_work_units",
    "_find_roots",
    "_lifecycle_bounds",
    "_refine_root",
]
