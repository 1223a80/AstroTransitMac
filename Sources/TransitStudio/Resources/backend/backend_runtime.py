"""Runtime request and CLI option helpers for the Transit Studio backend."""

from __future__ import annotations

from typing import Any


def parse_body_id_list(text: str) -> list[str]:
    return [
        token.strip().upper().replace("-", "_")
        for token in text.split(",")
        if token.strip()
    ]


def apply_runtime_options(
    request: dict[str, Any],
    argv: list[str],
    current_require_ephemeris: str,
) -> tuple[bool, str]:
    no_asteroids = bool(request.get("no_asteroids", request.get("noAsteroids", "--no-asteroids" in argv)))
    require_ephemeris = current_require_ephemeris

    for arg in argv[1:]:
        if arg.startswith("--require-ephemeris="):
            require_ephemeris = arg.split("=", 1)[1]
        if arg.startswith("--bodies="):
            request["transitBodies"] = parse_body_id_list(arg.split("=", 1)[1])

    if "--require-ephemeris" in argv:
        index = argv.index("--require-ephemeris")
        if index + 1 < len(argv):
            require_ephemeris = argv[index + 1]

    if "--bodies" in argv:
        index = argv.index("--bodies")
        if index + 1 < len(argv):
            request["transitBodies"] = parse_body_id_list(argv[index + 1])

    require_ephemeris = str(request.get("require_ephemeris", request.get("requireEphemeris", require_ephemeris))).lower()
    if require_ephemeris not in {"strict", "warn", "skip"}:
        raise ValueError("requireEphemeris 必须是 strict、warn 或 skip")

    return no_asteroids, require_ephemeris
