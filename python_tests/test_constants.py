"""Contract test: validates Swift and Python constant definitions match."""

import ast
import os
import re
import sys

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SWIFT_CONSTANTS_PATH = os.path.join(
    PROJECT_ROOT, "Sources", "TransitStudio", "AstroConstants.swift"
)
PYTHON_CONSTANTS_PATH = os.path.join(
    PROJECT_ROOT,
    "Sources",
    "TransitStudio",
    "Resources",
    "backend",
    "astro_backend_constants.py",
)


def _parse_swift_array(text: str, var_name: str) -> list[str]:
    """Extract a String array literal from Swift source via regex."""
    pattern = re.compile(
        rf"static\s+let\s+{re.escape(var_name)}\s*[:=].*?=\s*\[(.*?)\]",
        re.DOTALL,
    )
    m = pattern.search(text)
    if not m:
        raise ValueError(f"Swift constant '{var_name}' not found")
    body = m.group(1)
    items = re.findall(r'"([^"]*)"', body)
    return items


def _parse_swift_set(text: str, var_name: str) -> set[str]:
    """Extract a Set<String> literal from Swift source via regex."""
    items = _parse_swift_array(text, var_name)
    return set(items)


def _parse_python_value(path: str, var_name: str) -> object:
    """Extract a top-level variable value from Python source."""
    with open(path, encoding="utf-8") as f:
        tree = ast.parse(f.read(), filename=path)
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id == var_name:
                    return ast.literal_eval(node.value)
        if isinstance(node, ast.AnnAssign):
            if isinstance(node.target, ast.Name) and node.target.id == var_name:
                return ast.literal_eval(node.value)
    raise ValueError(f"Python constant '{var_name}' not found in {path}")


def _swift_values() -> dict[str, list[str]]:
    with open(SWIFT_CONSTANTS_PATH, encoding="utf-8") as f:
        text = f.read()
    return {
        "ALL_MODES": _parse_swift_array(text, "allModes"),
        "ALL_HOUSE_SYSTEMS": _parse_swift_array(text, "allHouseSystems"),
        "ALL_ZODIACS": _parse_swift_array(text, "allZodiacs"),
        "ALL_BOUNDS_SYSTEMS": _parse_swift_array(text, "allBoundsSystems"),
        "ALL_TRIPLICITY_SYSTEMS": _parse_swift_array(text, "allTriplicitySystems"),
        "ALL_SCAN_KINDS": _parse_swift_array(text, "allScanKinds"),
        "ALL_MOON_FILTERS": _parse_swift_array(text, "allMoonFilters"),
        "ALL_BODY_IDS": _parse_swift_array(text, "allBodyIDs"),
        "CLASSICAL_BODY_IDS": _parse_swift_array(text, "classicalBodyIDs"),
        "ASTEROID_BODY_IDS": sorted(_parse_swift_set(text, "asteroidBodyIDs")),
        "ALL_ASPECT_IDS": _parse_swift_array(text, "allAspectIDs"),
        "ALL_NODE_MODES": _parse_swift_array(text, "allNodeModes"),
        "ALL_PATTERN_IDS": _parse_swift_array(text, "allPatternIDs"),
        "ALL_CHART_SHAPE_IDS": _parse_swift_array(text, "allChartShapeIDs"),
    }


def _python_values() -> dict[str, list[str]]:
    return {
        "ALL_MODES": sorted(_parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_MODES")),
        "ALL_HOUSE_SYSTEMS": sorted(
            _parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_HOUSE_SYSTEMS")
        ),
        "ALL_ZODIACS": sorted(
            _parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_ZODIACS")
        ),
        "ALL_BOUNDS_SYSTEMS": sorted(
            _parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_BOUNDS_SYSTEMS")
        ),
        "ALL_TRIPLICITY_SYSTEMS": sorted(
            _parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_TRIPLICITY_SYSTEMS")
        ),
        "ALL_SCAN_KINDS": sorted(
            _parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_SCAN_KINDS")
        ),
        "ALL_MOON_FILTERS": sorted(
            _parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_MOON_FILTERS")
        ),
        "ALL_BODY_IDS": sorted(
            _parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_BODY_IDS")
        ),
        "CLASSICAL_BODY_IDS": sorted(
            _parse_python_value(PYTHON_CONSTANTS_PATH, "CLASSICAL_BODY_IDS")
        ),
        "ASTEROID_BODY_IDS": sorted(
            list(_parse_python_value(PYTHON_CONSTANTS_PATH, "ASTEROID_BODY_IDS"))
        ),
        "ALL_ASPECT_IDS": sorted(
            _parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_ASPECT_IDS")
        ),
        "ALL_NODE_MODES": sorted(
            _parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_NODE_MODES")
        ),
        "ALL_PATTERN_IDS": sorted(
            _parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_PATTERN_IDS")
        ),
        "ALL_CHART_SHAPE_IDS": sorted(
            _parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_CHART_SHAPE_IDS")
        ),
    }


def test_all_constants_match() -> None:
    swift = _swift_values()
    python = _python_values()
    mismatches: list[str] = []
    for key in sorted(swift):
        sv = swift[key]
        pv = python.get(key, [])
        if sorted(sv) != sorted(pv):
            mismatches.append(
                f"{key}:\n"
                f"  Swift  ({len(sv)}): {sv}\n"
                f"  Python ({len(pv)}): {pv}\n"
                f"  Swift-only:  {set(sv) - set(pv)}\n"
                f"  Python-only: {set(pv) - set(sv)}"
            )
    if mismatches:
        pytest.fail(
            f"Contract mismatch between Swift and Python constants:\n\n"
            + "\n\n".join(mismatches)
        )


def test_body_id_labels() -> None:
    """Validate every body ID has a label in the Python LABELS dict."""
    labels = _parse_python_value(PYTHON_CONSTANTS_PATH, "LABELS")
    body_labels = labels.get("body_id", {})
    body_ids: list[str] = _parse_python_value(
        PYTHON_CONSTANTS_PATH, "ALL_BODY_IDS"
    )
    missing = [bid for bid in body_ids if bid not in body_labels]
    if missing:
        pytest.fail(f"Body IDs missing labels: {missing}")


def test_aspect_id_labels() -> None:
    """Validate every aspect ID has a label in the Python LABELS dict."""
    labels = _parse_python_value(PYTHON_CONSTANTS_PATH, "LABELS")
    aspect_labels = labels.get("aspect_id", {})
    aspect_ids: list[str] = _parse_python_value(
        PYTHON_CONSTANTS_PATH, "ALL_ASPECT_IDS"
    )
    missing = [aid for aid in aspect_ids if aid not in aspect_labels]
    if missing:
        pytest.fail(f"Aspect IDs missing labels: {missing}")


def test_node_mode_ids() -> None:
    swift = _parse_swift_array(open(SWIFT_CONSTANTS_PATH, encoding="utf-8").read(), "allNodeModes")
    python = sorted(_parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_NODE_MODES"))
    if sorted(swift) != sorted(python):
        pytest.fail(f"Node mode mismatch: Swift={swift}, Python={python}")


def test_chart_shape_ids() -> None:
    swift = _parse_swift_array(open(SWIFT_CONSTANTS_PATH, encoding="utf-8").read(), "allChartShapeIDs")
    python = sorted(_parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_CHART_SHAPE_IDS"))
    if sorted(swift) != sorted(python):
        pytest.fail(f"Chart shape ID mismatch: Swift={swift}, Python={python}")

def test_pattern_ids() -> None:
    swift = _parse_swift_array(open(SWIFT_CONSTANTS_PATH, encoding="utf-8").read(), "allPatternIDs")
    python = sorted(_parse_python_value(PYTHON_CONSTANTS_PATH, "ALL_PATTERN_IDS"))
    if sorted(swift) != sorted(python):
        pytest.fail(f"Pattern ID mismatch: Swift={swift}, Python={python}")


# Import pytest only after defining everything above to allow
# the module to be importable without pytest installed.
import pytest  # noqa: E402
