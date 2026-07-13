"""Midpoint axes, focus trees, and single-reference activations.

The public natal-point and canonical-axis helpers intentionally have no
dependency on ``astro_backend_modern_timing``.  Timing can therefore import
them to resolve midpoint-pair endpoint IDs without creating an import cycle
or trusting client-provided longitudes.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
import math
from typing import Any, Iterable, Mapping

from astro_backend_classical_lots import calculate_lots
from astro_backend_core import (
    BODY_REGISTRY,
    CLASSICAL_BODY_IDS,
    angular_separation,
    circular_midpoint,
    format_longitude,
    jd_from_datetime,
    moment_to_jd,
    moment_to_local_datetime,
    norm360,
    set_zodiac_mode,
)
from astro_backend_ephemeris import (
    build_houses,
    calculate_positions,
    house_for_longitude,
    resolve_bodies,
)
from astro_backend_modern_points import finalize_point_set, resolve_point_set
from astro_backend_progressions import _calc_progressed_dt
from astro_backend_solar_arc import true_solar_arc_value


SUPPORTED_ACTIVATION_SOURCES = (
    "natal",
    "transit",
    "secondary_progression",
    "solar_arc",
)

ANGLE_NAMES = {
    "ASC": "ASC",
    "MC": "MC",
    "DSC": "DSC",
    "IC": "IC",
    "VERTEX": "Vertex",
    "ANTIVERTEX": "Antivertex",
    "EQUATORIAL_ASCENDANT": "East Point (Equatorial Ascendant)",
}


@dataclass
class _BirthContext:
    birth: dict[str, Any]
    birth_jd: float
    birth_utc: datetime
    latitude: float
    longitude: float
    house_system: str
    sidereal: bool
    warnings: list[str]
    ephemerides: set[str] = field(default_factory=set)


def _append_warning(warnings: list[str], message: str) -> None:
    if message not in warnings:
        warnings.append(message)


def _public_longitude(value: float) -> float:
    rounded = round(norm360(float(value)), 6)
    return 0.0 if rounded >= 360.0 else rounded


def _finite_longitude(value: Any, field: str) -> float:
    try:
        longitude = float(value)
    except (TypeError, ValueError, OverflowError) as exc:
        raise ValueError(f"{field} must be a finite longitude") from exc
    if not math.isfinite(longitude):
        raise ValueError(f"{field} must be a finite longitude")
    return norm360(longitude)


def _point_id(row: Mapping[str, Any]) -> str:
    value = row.get("point_id", row.get("id", row.get("body_id")))
    if not isinstance(value, str) or not value:
        raise ValueError("midpoint point requires a non-empty point_id")
    return value


def _canonical_point(row: Mapping[str, Any]) -> dict[str, Any]:
    point_id = _point_id(row)
    longitude = _finite_longitude(row.get("longitude"), f"point {point_id}.longitude")
    return {
        "point_id": point_id,
        "name": str(row.get("name", point_id)),
        "kind": str(row.get("kind", "body")),
        "longitude": longitude,
    }


def build_canonical_midpoint_axis(
    point_a: Mapping[str, Any],
    point_b: Mapping[str, Any],
) -> dict[str, Any]:
    """Build one stable 360-degree axis from two authoritative point rows.

    Point IDs, rather than input order, choose the first argument passed to
    ``circular_midpoint``.  This makes its documented 180-degree tie-break
    deterministic for a canonical pair.
    """

    left = _canonical_point(point_a)
    right = _canonical_point(point_b)
    if left["point_id"] == right["point_id"]:
        raise ValueError("midpoint pair endpoints must be different")
    if right["point_id"] < left["point_id"]:
        left, right = right, left

    midpoint = circular_midpoint(left["longitude"], right["longitude"])
    opposite = norm360(midpoint + 180.0)
    _, midpoint_text = format_longitude(midpoint)
    _, opposite_text = format_longitude(opposite)

    return {
        "id": f"midpoint|{left['point_id']}|{right['point_id']}",
        "point_a_id": left["point_id"],
        "point_a_name": left["name"],
        "point_b_id": right["point_id"],
        "point_b_name": right["name"],
        "midpoint_longitude": _public_longitude(midpoint),
        "opposite_longitude": _public_longitude(opposite),
        "midpoint_text": midpoint_text,
        "opposite_text": opposite_text,
        "trace": {
            "input_longitudes": [
                _public_longitude(left["longitude"]),
                _public_longitude(right["longitude"]),
            ],
        },
    }


def build_midpoint_axes(points: Iterable[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """Build exactly N*(N-1)/2 canonical axes from unique point IDs."""

    by_id: dict[str, dict[str, Any]] = {}
    for raw_point in points:
        point = _canonical_point(raw_point)
        existing = by_id.get(point["point_id"])
        if existing is None:
            by_id[point["point_id"]] = point
            continue
        if angular_separation(existing["longitude"], point["longitude"]) > 1e-9:
            raise ValueError(
                f"duplicate midpoint point ID {point['point_id']} has conflicting longitudes"
            )

    ordered = [by_id[point_id] for point_id in sorted(by_id)]
    axes = [
        build_canonical_midpoint_axis(ordered[left], ordered[right])
        for left in range(len(ordered))
        for right in range(left + 1, len(ordered))
    ]
    expected = len(ordered) * (len(ordered) - 1) // 2
    if len(axes) != expected or len({axis["id"] for axis in axes}) != expected:
        raise RuntimeError("midpoint canonical-pair completeness assertion failed")
    return axes


def build_midpoint_hits(
    source_points: Iterable[Mapping[str, Any]],
    axes: Iterable[Mapping[str, Any]],
    *,
    activation_orb: float,
    source_type: str,
    reference_utc: str | None,
    include_opposite_axis: bool = True,
    focus_point: Mapping[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """Match source/focus points to direct and optional opposite branches."""

    orb_limit = _validated_orb(activation_orb)
    focus = _canonical_point(focus_point) if focus_point is not None else None
    hits: list[dict[str, Any]] = []
    for raw_source in source_points:
        source = _canonical_point(raw_source)
        for axis in axes:
            branches = [("direct", axis["midpoint_longitude"])]
            if include_opposite_axis:
                branches.append(("opposite", axis["opposite_longitude"]))
            for branch, hit_longitude in branches:
                separation = angular_separation(source["longitude"], float(hit_longitude))
                if separation > orb_limit + 1e-9:
                    continue
                actual_orb = round(separation, 6)
                hit_id = "|".join(
                    (
                        "midpoint_hit",
                        source_type,
                        focus["point_id"] if focus is not None else "snapshot",
                        source["point_id"],
                        str(axis["id"]),
                        branch,
                        reference_utc or "none",
                    )
                )
                hits.append(
                    {
                        "id": hit_id,
                        "focus_point_id": focus["point_id"] if focus is not None else None,
                        "focus_point_name": focus["name"] if focus is not None else None,
                        "source_point_id": source["point_id"],
                        "source_point_name": source["name"],
                        "axis_id": axis["id"],
                        "axis_branch": branch,
                        "hit_longitude": _public_longitude(source["longitude"]),
                        "axis_longitude": _public_longitude(float(hit_longitude)),
                        "separation": actual_orb,
                        "orb": actual_orb,
                        "source_type": source_type,
                        "reference_utc": reference_utc,
                    }
                )
    return sorted(
        hits,
        key=lambda row: (
            row["source_point_id"],
            row["orb"],
            row["axis_id"],
            0 if row["axis_branch"] == "direct" else 1,
        ),
    )


def _context_from_birth_or_request(
    birth_or_request: Mapping[str, Any],
    warnings: list[str],
    *,
    zodiac: str | None,
    house_system: str | None,
) -> _BirthContext:
    if "birth" in birth_or_request and "moment" not in birth_or_request:
        request = birth_or_request
        birth = request["birth"]
        zodiac = zodiac or request.get("zodiac")
        house_system = house_system or request.get("house_system")
    else:
        birth = birth_or_request

    if not isinstance(birth, dict) or not isinstance(birth.get("moment"), dict):
        raise ValueError("midpoint birth must contain a moment object")
    effective_zodiac = zodiac or birth.get("zodiac", "tropical")
    effective_house_system = (
        house_system
        or birth.get("houseSystem")
        or birth.get("house_system")
        or "whole_sign"
    )
    sidereal = set_zodiac_mode(str(effective_zodiac), warnings)
    birth_jd, _ = moment_to_jd(birth["moment"])
    birth_utc = moment_to_local_datetime(birth["moment"]).astimezone(timezone.utc)
    return _BirthContext(
        birth=dict(birth),
        birth_jd=birth_jd,
        birth_utc=birth_utc,
        latitude=float(birth["latitude"]),
        longitude=float(birth["longitude"]),
        house_system=str(effective_house_system),
        sidereal=sidereal,
        warnings=warnings,
    )


def _is_context(value: Any) -> bool:
    return all(
        hasattr(value, field)
        for field in ("birth_jd", "birth_utc", "latitude", "longitude", "house_system", "sidereal")
    )


def _point_rows_at_jd(
    context: Any,
    jd: float,
    point_set: dict[str, Any],
    warnings: list[str],
    *,
    precomputed_cusps: list[float] | None = None,
    precomputed_angles: dict[str, float] | None = None,
    finalize: bool,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    body_ids = list(point_set["resolved_body_ids"])
    specs = resolve_bodies(
        [point_id for point_id in body_ids if not point_id.startswith("AST:")],
        list(point_set["custom_asteroids"]),
        warnings,
    )
    positions = calculate_positions(jd, specs, warnings, sidereal=bool(context.sidereal))
    if hasattr(context, "ephemerides"):
        context.ephemerides.update(
            str(row.get("_ephemeris", "Swiss Ephemeris")) for row in positions
        )
    selected_positions = [row for row in positions if row["body_id"] in body_ids]

    if precomputed_cusps is None or precomputed_angles is None:
        cusps, angles, _ = build_houses(
            jd,
            float(context.latitude),
            float(context.longitude),
            str(context.house_system),
            bool(context.sidereal),
            warnings,
        )
    else:
        cusps = list(precomputed_cusps)
        angles = dict(precomputed_angles)

    rows: list[dict[str, Any]] = [
        {
            "point_id": row["body_id"],
            "name": str(row.get("name", row["body_id"])),
            "kind": "body",
            "longitude": norm360(float(row["longitude"])),
        }
        for row in selected_positions
    ]
    available_body_ids = [row["point_id"] for row in rows]

    available_angle_ids: list[str] = []
    for angle_id in point_set["angle_ids"]:
        value = angles.get(angle_id)
        if value is None or not math.isfinite(float(value)):
            _append_warning(
                warnings,
                f"轴点 {angle_id} 不可用，已从 midpoint effective_point_set 移除。",
            )
            continue
        rows.append(
            {
                "point_id": angle_id,
                "name": ANGLE_NAMES.get(angle_id, angle_id),
                "kind": "angle",
                "longitude": norm360(float(value)),
            }
        )
        available_angle_ids.append(angle_id)

    available_houses: list[int] = []
    for house in point_set["house_cusps"]:
        if not 1 <= house <= len(cusps) or not math.isfinite(float(cusps[house - 1])):
            _append_warning(
                warnings,
                f"第 {house} 宫宫头不可用，已从 midpoint effective_point_set 移除。",
            )
            continue
        rows.append(
            {
                "point_id": f"HOUSE_CUSP_{house}",
                "name": f"第 {house} 宫宫头",
                "kind": "house_cusp",
                "longitude": norm360(float(cusps[house - 1])),
            }
        )
        available_houses.append(house)

    available_lots: list[str] = []
    if point_set["lot_ids"]:
        classical_specs = [BODY_REGISTRY[body_id] for body_id in CLASSICAL_BODY_IDS]
        classical_positions = calculate_positions(
            jd, classical_specs, warnings, sidereal=bool(context.sidereal)
        )
        if hasattr(context, "ephemerides"):
            context.ephemerides.update(
                str(row.get("_ephemeris", "Swiss Ephemeris"))
                for row in classical_positions
            )
        positions_by_id = {row["body_id"]: row for row in classical_positions}
        sun = positions_by_id.get("SUN")
        is_day = bool(sun and house_for_longitude(float(sun["longitude"]), cusps) >= 7)
        lot_rows = calculate_lots(
            angles,
            positions_by_id,
            cusps,
            is_day,
            mc=angles.get("MC"),
            warnings=warnings,
        )
        lots_by_id = {row["id"]: row for row in lot_rows}
        for lot_id in point_set["lot_ids"]:
            lot = lots_by_id.get(lot_id)
            if lot is None or not math.isfinite(float(lot["longitude"])):
                _append_warning(
                    warnings,
                    f"阿拉伯点 {lot_id} 不可用，已从 midpoint effective_point_set 移除。",
                )
                continue
            rows.append(
                {
                    "point_id": lot_id,
                    "name": str(lot.get("name", lot_id)),
                    "kind": "lot",
                    "longitude": norm360(float(lot["longitude"])),
                }
            )
            available_lots.append(lot_id)

    effective = {key: (list(value) if isinstance(value, list) else value) for key, value in point_set.items()}
    if finalize:
        effective = finalize_point_set(
            point_set,
            available_body_ids,
            available_angle_ids=available_angle_ids,
            warnings=warnings,
        )
        effective["house_cusps"] = available_houses
        effective["lot_ids"] = available_lots
    return rows, effective


def resolve_natal_midpoint_points(
    birth_or_context: Mapping[str, Any] | Any,
    point_set: Any,
    warnings: list[str] | None = None,
    *,
    node_mode: str | None = None,
    zodiac: str | None = None,
    house_system: str | None = None,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Resolve authoritative natal midpoint points and the effective set.

    ``birth_or_context`` accepts either a birth object/full request or an
    existing timing-like context with birth JD, coordinates, houses, and
    zodiac state.  Returned point rows always expose
    ``point_id/name/kind/longitude`` so timing can resolve pair endpoint IDs.
    """

    if _is_context(birth_or_context):
        context = birth_or_context
        if warnings is None:
            warnings = getattr(context, "warnings", [])
    else:
        warnings = warnings if warnings is not None else []
        if not isinstance(birth_or_context, Mapping):
            raise ValueError("birth_or_context must be a birth object or chart context")
        context = _context_from_birth_or_request(
            birth_or_context,
            warnings,
            zodiac=zodiac,
            house_system=house_system,
        )

    warnings = warnings if warnings is not None else []
    effective_node_mode = node_mode
    if (
        effective_node_mode is None
        and isinstance(point_set, dict)
        and "node_mode" in point_set
    ):
        effective_node_mode = point_set["node_mode"]
    effective_node_mode = str(
        "true_node" if effective_node_mode is None else effective_node_mode
    )
    resolved = resolve_point_set(point_set, node_mode=effective_node_mode)

    precomputed_cusps = getattr(context, "cusps", None)
    precomputed_angles = getattr(context, "angles", None)
    rows, effective = _point_rows_at_jd(
        context,
        float(context.birth_jd),
        resolved,
        warnings,
        precomputed_cusps=precomputed_cusps,
        precomputed_angles=precomputed_angles,
        finalize=True,
    )
    return [_canonical_point(row) for row in rows], effective


def _validated_orb(value: Any) -> float:
    try:
        orb = float(value)
    except (TypeError, ValueError, OverflowError) as exc:
        raise ValueError("activation_orb must be a finite non-negative number") from exc
    if not math.isfinite(orb) or orb < 0:
        raise ValueError("activation_orb must be a finite non-negative number")
    return orb


def _validated_string_list(value: Any, field: str) -> list[str]:
    if not isinstance(value, list):
        raise ValueError(f"{field} must be an array")
    result: list[str] = []
    for index, item in enumerate(value):
        if not isinstance(item, str) or not item:
            raise ValueError(f"{field}[{index}] must be a non-empty string")
        if item not in result:
            result.append(item)
    return result


def _validate_request(request: Mapping[str, Any]) -> tuple[float, bool, list[str], list[str]]:
    if request.get("mode") != "midpoint":
        raise ValueError("mode must be midpoint")
    if "birth" not in request:
        raise ValueError("midpoint request requires birth")

    modulus = request.get("modulus", 360)
    if isinstance(modulus, bool):
        raise ValueError("midpoint v1 modulus must be 360")
    try:
        modulus_value = float(modulus)
    except (TypeError, ValueError, OverflowError) as exc:
        raise ValueError("midpoint v1 modulus must be 360") from exc
    if not math.isfinite(modulus_value) or modulus_value != 360.0:
        raise ValueError("midpoint v1 modulus must be 360")

    include_opposite = request.get("include_opposite_axis", True)
    if not isinstance(include_opposite, bool):
        raise ValueError("include_opposite_axis must be a boolean")
    activation_orb = _validated_orb(request.get("activation_orb", 1.0))
    focus_ids = _validated_string_list(request.get("focus_point_ids", []), "focus_point_ids")
    activation_sources = _validated_string_list(
        request.get("activation_sources", list(SUPPORTED_ACTIVATION_SOURCES)),
        "activation_sources",
    )
    unknown_sources = [
        source for source in activation_sources if source not in SUPPORTED_ACTIVATION_SOURCES
    ]
    if unknown_sources:
        raise ValueError(
            "activation_sources contains unsupported values: " + ", ".join(unknown_sources)
        )
    return activation_orb, include_opposite, focus_ids, activation_sources


def _activation_points_for_source(
    source_type: str,
    context: Any,
    effective_point_set: dict[str, Any],
    natal_points: list[dict[str, Any]],
    reference_utc: datetime,
    warnings: list[str],
) -> list[dict[str, Any]]:
    if source_type == "natal":
        return list(natal_points)

    if source_type == "transit":
        rows, _ = _point_rows_at_jd(
            context,
            jd_from_datetime(reference_utc),
            effective_point_set,
            warnings,
            finalize=False,
        )
        return rows

    progressed_utc, _ = _calc_progressed_dt(context.birth_utc, reference_utc)
    progressed_jd = jd_from_datetime(progressed_utc)
    if source_type == "secondary_progression":
        rows, _ = _point_rows_at_jd(
            context,
            progressed_jd,
            effective_point_set,
            warnings,
            finalize=False,
        )
        return rows

    if source_type == "solar_arc":
        sun_spec = BODY_REGISTRY["SUN"]
        natal_sun_rows = calculate_positions(
            float(context.birth_jd), [sun_spec], warnings, sidereal=bool(context.sidereal)
        )
        progressed_sun_rows = calculate_positions(
            progressed_jd, [sun_spec], warnings, sidereal=bool(context.sidereal)
        )
        if hasattr(context, "ephemerides"):
            context.ephemerides.update(
                str(row.get("_ephemeris", "Swiss Ephemeris"))
                for row in natal_sun_rows + progressed_sun_rows
            )
        if not natal_sun_rows or not progressed_sun_rows:
            raise RuntimeError("Solar Arc Sun anchor is unavailable")
        arc = true_solar_arc_value(
            float(natal_sun_rows[0]["longitude"]),
            float(progressed_sun_rows[0]["longitude"]),
        )
        return [
            {
                **point,
                "longitude": norm360(float(point["longitude"]) + arc),
            }
            for point in natal_points
        ]

    raise ValueError(f"unsupported midpoint activation source: {source_type}")


def calculate_midpoints(request: dict[str, Any], warnings: list[str]) -> dict[str, Any]:
    """Calculate the independent B4 Midpoints v1 response."""

    activation_orb, include_opposite, focus_ids, activation_sources = _validate_request(request)
    context = _context_from_birth_or_request(
        request,
        warnings,
        zodiac=request.get("zodiac"),
        house_system=request.get("house_system"),
    )
    raw_point_set = request.get("point_set")
    if isinstance(raw_point_set, dict) and "node_mode" in raw_point_set:
        node_mode = str(raw_point_set["node_mode"])
    else:
        node_mode = str(request.get("node_mode", "true_node"))
    natal_points, effective_point_set = resolve_natal_midpoint_points(
        context,
        raw_point_set,
        warnings,
        node_mode=node_mode,
    )
    axes = build_midpoint_axes(natal_points)
    point_by_id = {point["point_id"]: point for point in natal_points}
    birth_utc_text = context.birth_utc.isoformat()

    trees: list[dict[str, Any]] = []
    for focus_id in focus_ids:
        focus = point_by_id.get(focus_id)
        if focus is None:
            _append_warning(
                warnings,
                f"中点焦点 {focus_id} 不可用，已从 trees 移除。",
            )
            continue
        trees.append(
            {
                "focus_point_id": focus_id,
                "focus_point_name": focus["name"],
                "hits": build_midpoint_hits(
                    [focus],
                    axes,
                    activation_orb=activation_orb,
                    source_type="natal",
                    reference_utc=birth_utc_text,
                    include_opposite_axis=include_opposite,
                    focus_point=focus,
                ),
            }
        )

    snapshot_activations: list[dict[str, Any]] = []
    section_errors: dict[str, str] = {}
    reference_utc_text: str | None = None
    if request.get("reference") is not None:
        reference = request["reference"]
        reference_utc = moment_to_local_datetime(reference).astimezone(timezone.utc)
        reference_utc_text = reference_utc.isoformat()
        for source_type in activation_sources:
            try:
                source_points = _activation_points_for_source(
                    source_type,
                    context,
                    effective_point_set,
                    natal_points,
                    reference_utc,
                    warnings,
                )
                snapshot_activations.extend(
                    build_midpoint_hits(
                        source_points,
                        axes,
                        activation_orb=activation_orb,
                        source_type=source_type,
                        reference_utc=reference_utc_text,
                        include_opposite_axis=include_opposite,
                    )
                )
            except Exception as exc:
                section_errors[source_type] = str(exc)
                _append_warning(
                    warnings,
                    f"中点激活源 {source_type} 计算失败：{exc}",
                )

    return {
        "meta": {
            "schema_version": 1,
            "method": "circular_midpoint_axis_360",
            "modulus": 360,
            "activation_orb": round(activation_orb, 6),
            "include_opposite_axis": include_opposite,
            "activation_sources": activation_sources,
            "birth_utc": birth_utc_text,
            "reference_utc": reference_utc_text,
            "ephemeris": (
                ", ".join(sorted(context.ephemerides))
                if context.ephemerides
                else "Swiss Ephemeris"
            ),
            "effective_point_set": effective_point_set,
        },
        "axes": axes,
        "trees": trees,
        "snapshot_activations": snapshot_activations,
        "warnings": warnings,
        "section_errors": section_errors or None,
    }


__all__ = [
    "SUPPORTED_ACTIVATION_SOURCES",
    "build_canonical_midpoint_axis",
    "build_midpoint_axes",
    "build_midpoint_hits",
    "calculate_midpoints",
    "resolve_natal_midpoint_points",
]
