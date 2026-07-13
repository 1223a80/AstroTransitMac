"""Shared point-set parsing for modern astrology modes.

The modern modes historically carried their body lists in separate request
fields.  This module is deliberately small: it validates the new optional
contract and resolves the node/asteroid IDs without duplicating the
ephemeris registry.
"""

from __future__ import annotations

import math
from typing import Any, Iterable

from astro_backend_core import BODY_REGISTRY


# Keeping all body knowledge in ``astro_backend_core`` is important.  These
# constants only name the contract-level node IDs and do not duplicate
# BodySpec definitions.
NODE_BODY_IDS = frozenset({"MEAN_NODE", "TRUE_NODE", "SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE"})
NODE_MODE_IDS = {
    "true_node": ("TRUE_NODE", "SOUTH_TRUE_NODE"),
    "mean_node": ("MEAN_NODE", "SOUTH_MEAN_NODE"),
}
DEFAULT_MODERN_BODY_IDS = (
    "SUN", "MOON", "MERCURY", "VENUS", "MARS",
    "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO",
)
SUPPORTED_ANGLE_IDS = frozenset({
    "ASC", "MC", "DSC", "IC", "VERTEX", "ANTIVERTEX", "EQUATORIAL_ASCENDANT",
})


def _stable_unique(values: Iterable[Any]) -> list[Any]:
    result: list[Any] = []
    seen: set[Any] = set()
    for value in values:
        if value in seen:
            continue
        seen.add(value)
        result.append(value)
    return result


def _validate_positive_asteroids(value: Any, field: str, errors: list[str]) -> list[int]:
    if value is None:
        return []
    if not isinstance(value, list):
        errors.append(f"{field} must be an array")
        return []
    result: list[int] = []
    for index, item in enumerate(value):
        if isinstance(item, bool) or not isinstance(item, int) or item <= 0:
            # Floats, NaN and infinities are rejected explicitly rather than
            # being silently coerced into an asteroid number.
            if isinstance(item, float) and not math.isfinite(item):
                errors.append(f"{field}[{index}] must be a finite positive integer")
            else:
                errors.append(f"{field}[{index}] must be a positive integer")
            continue
        result.append(item)
    return _stable_unique(result)


def validate_point_set(raw: Any, *, node_mode: str = "true_node") -> list[str]:
    """Return human-readable validation errors for an optional point_set."""
    errors: list[str] = []
    if raw is None:
        raw = {}
    if not isinstance(raw, dict):
        return ["point_set must be an object"]

    if node_mode not in NODE_MODE_IDS:
        errors.append("node_mode must be one of: true_node, mean_node")

    body_ids = raw.get("body_ids", [])
    if not isinstance(body_ids, list):
        errors.append("point_set.body_ids must be an array")
    else:
        for index, body_id in enumerate(body_ids):
            if not isinstance(body_id, str) or not body_id:
                errors.append(f"point_set.body_ids[{index}] must be a non-empty string")
                continue
            if body_id in NODE_BODY_IDS:
                errors.append(
                    f"point_set.body_ids[{index}] must not contain node ID {body_id}; use include_nodes and node_mode"
                )
            elif body_id not in BODY_REGISTRY:
                errors.append(f"point_set.body_ids[{index}] is unknown: {body_id}")

    include_nodes = raw.get("include_nodes", False)
    if not isinstance(include_nodes, bool):
        errors.append("point_set.include_nodes must be a boolean")

    angle_ids = raw.get("angle_ids", [])
    if not isinstance(angle_ids, list):
        errors.append("point_set.angle_ids must be an array")
    else:
        for index, angle_id in enumerate(angle_ids):
            if not isinstance(angle_id, str) or angle_id not in SUPPORTED_ANGLE_IDS:
                errors.append(f"point_set.angle_ids[{index}] is unknown: {angle_id}")

    house_cusps = raw.get("house_cusps", [])
    if not isinstance(house_cusps, list):
        errors.append("point_set.house_cusps must be an array")
    else:
        seen_houses: set[int] = set()
        for index, house in enumerate(house_cusps):
            if isinstance(house, bool) or not isinstance(house, int) or not 1 <= house <= 12:
                errors.append(f"point_set.house_cusps[{index}] must be an integer in 1...12")
            elif house in seen_houses:
                errors.append(f"point_set.house_cusps contains duplicate house {house}")
            else:
                seen_houses.add(house)

    lot_ids = raw.get("lot_ids", [])
    if not isinstance(lot_ids, list):
        errors.append("point_set.lot_ids must be an array")
    else:
        # Import lazily: classical_lots imports ephemeris, and ephemeris is a
        # lower-level dependency of the modern backend.
        try:
            from astro_backend_classical_lots import LOT_LIST
            known_lots = {str(item.get("lot_id")) for item in LOT_LIST}
        except Exception:
            known_lots = set()
        for index, lot_id in enumerate(lot_ids):
            if not isinstance(lot_id, str) or lot_id not in known_lots:
                errors.append(f"point_set.lot_ids[{index}] is unknown: {lot_id}")

    _validate_positive_asteroids(raw.get("custom_asteroids", []), "point_set.custom_asteroids", errors)
    return errors


def resolve_point_set(
    raw: Any,
    *,
    default_body_ids: Iterable[str] = DEFAULT_MODERN_BODY_IDS,
    default_include_nodes: bool = True,
    default_angle_ids: Iterable[str] = ("ASC", "MC", "DSC", "IC"),
    node_mode: str = "true_node",
    legacy_custom_asteroids: Iterable[int] = (),
) -> dict[str, Any]:
    """Resolve an optional request point_set into an auditable effective set."""
    errors = validate_point_set(raw, node_mode=node_mode)
    if errors:
        raise ValueError("现代 point_set 校验失败：" + "；".join(errors))

    config = raw if isinstance(raw, dict) else {}
    explicit = raw is not None
    body_ids_raw = config.get("body_ids") if explicit and "body_ids" in config else list(default_body_ids)
    include_nodes = config.get("include_nodes", default_include_nodes)
    angle_ids = config.get("angle_ids", list(default_angle_ids))
    house_cusps = config.get("house_cusps", [])
    lot_ids = config.get("lot_ids", [])
    custom_asteroids = _stable_unique(
        list(legacy_custom_asteroids) + _validate_positive_asteroids(
            config.get("custom_asteroids", []), "point_set.custom_asteroids", []
        )
    )

    body_ids = _stable_unique(body_ids_raw)
    node_ids = list(NODE_MODE_IDS[node_mode]) if include_nodes else []
    resolved_body_ids = _stable_unique(body_ids + node_ids + [f"AST:{number}" for number in custom_asteroids])

    return {
        "body_ids": body_ids,
        "include_nodes": include_nodes,
        "node_mode": node_mode,
        "custom_asteroids": custom_asteroids,
        "angle_ids": _stable_unique(angle_ids),
        "house_cusps": list(house_cusps),
        "lot_ids": _stable_unique(lot_ids),
        "resolved_body_ids": resolved_body_ids,
    }


def body_ids_for_point_set(point_set: dict[str, Any]) -> list[str]:
    """Return IDs suitable for the existing ``resolve_bodies`` helper."""
    return list(point_set.get("resolved_body_ids", []))


def finalize_point_set(
    point_set: dict[str, Any],
    available_body_ids: Iterable[str],
    *,
    available_angle_ids: Iterable[str] | None = None,
    warnings: list[str] | None = None,
) -> dict[str, Any]:
    """Remove points skipped by ephemeris/house fallback from the audit record."""
    available = set(available_body_ids)
    result = {key: (list(value) if isinstance(value, list) else value) for key, value in point_set.items()}
    before = list(result.get("resolved_body_ids", []))
    result["resolved_body_ids"] = [body_id for body_id in before if body_id in available]
    result["body_ids"] = [body_id for body_id in result.get("body_ids", []) if body_id in available]
    result["include_nodes"] = any(body_id in NODE_BODY_IDS for body_id in result["resolved_body_ids"])
    result["custom_asteroids"] = [
        number for number in result.get("custom_asteroids", []) if f"AST:{number}" in available
    ]
    if warnings is not None:
        for body_id in before:
            if body_id not in available:
                warning = f"现代 point_set 点 {body_id} 未进入结果，已从 effective_point_set 移除。"
                if warning not in warnings:
                    warnings.append(warning)
    if available_angle_ids is not None:
        allowed_angles = set(available_angle_ids)
        result["angle_ids"] = [angle_id for angle_id in result.get("angle_ids", []) if angle_id in allowed_angles]
    return result
