from __future__ import annotations

import math
from datetime import datetime
from typing import Any

from astro_backend_core import (
    ASTEROID_BODY_IDS,
    BODY_REGISTRY,
    BODY_REGISTRY,
    BodySpec,
    SIGN_RULERS,
    declination_from_lon,
    format_longitude,
    jd_from_datetime,
    norm360,
    obliquity,
    planet_name,
    sign_degree,
    swe,
    zodiac_sign_index,
)

NO_ASTEROIDS = False
REQUIRE_EPHEMERIS = "warn"

HOUSE_SYSTEMS = {
    "whole_sign": ("Whole Sign", "W"),
    "placidus": ("Placidus", "P"),
    "porphyry": ("Porphyry", "O"),
    "regiomontanus": ("Regiomontanus", "R"),
    "alcabitius": ("Alcabitius", "B"),
    "equal": ("Equal", "A"),
}


def configure_runtime(no_asteroids: bool, require_ephemeris: str) -> None:
    global NO_ASTEROIDS, REQUIRE_EPHEMERIS
    NO_ASTEROIDS = no_asteroids
    REQUIRE_EPHEMERIS = require_ephemeris


def _append_unique(warnings: list[str], message: str) -> None:
    if message not in warnings:
        warnings.append(message)


def is_asteroid_spec(spec: BodySpec) -> bool:
    return spec.body_id in ASTEROID_BODY_IDS or spec.body_id.startswith("AST:")


def asteroid_skip_message(names: list[str], reason: str) -> str:
    return (
        f"Skipped asteroid targets: {', '.join(names)}\n"
        f"Reason: {reason}\n"
        "Fix: install asteroid ephemeris files or run with --no-asteroids"
    )


def resolve_bodies(body_ids: list[str], asteroid_numbers: list[int], warnings: list[str] | None = None) -> list[BodySpec]:
    specs: list[BodySpec] = []
    seen: set[str] = set()
    skipped: list[str] = []

    for body_id in body_ids:
        if body_id not in BODY_REGISTRY or body_id in seen:
            continue
        if NO_ASTEROIDS and body_id in ASTEROID_BODY_IDS:
            skipped.append(BODY_REGISTRY[body_id].name)
            seen.add(body_id)
            continue
        specs.append(BODY_REGISTRY[body_id])
        seen.add(body_id)

    ast_offset = getattr(swe, "AST_OFFSET", 10000)
    for number in asteroid_numbers:
        body_id = f"AST:{number}"
        if body_id in seen:
            continue
        if NO_ASTEROIDS:
            skipped.append(f"小行星 {number}")
            seen.add(body_id)
            continue
        specs.append(BodySpec(body_id, f"小行星 {number}", ast_offset + number))
        seen.add(body_id)

    if skipped and warnings is not None and REQUIRE_EPHEMERIS != "skip":
        warnings.append(asteroid_skip_message(skipped, "--no-asteroids enabled"))

    return specs


def warn_once(warnings: list[str], warning_keys: set[str] | None, key: str, message: str) -> None:
    if warning_keys is None:
        warnings.append(message)
        return
    if key not in warning_keys:
        warnings.append(message)
        warning_keys.add(key)


def calculate_values(
    jd_ut: float,
    spec: BodySpec,
    warnings: list[str],
    warning_keys: set[str] | None = None,
    sidereal: bool = False,
) -> tuple[tuple[float, ...], str] | None:
    flags = swe.FLG_SWIEPH | swe.FLG_SPEED
    if sidereal:
        flags |= swe.FLG_SIDEREAL

    try:
        values, _ = swe.calc_ut(jd_ut, spec.code, flags)
        return values, "Swiss Ephemeris"
    except swe.Error as swiss_error:
        if is_asteroid_spec(spec):
            reason = str(swiss_error)
            if REQUIRE_EPHEMERIS == "strict":
                raise RuntimeError(asteroid_skip_message([spec.name], reason)) from swiss_error
            if REQUIRE_EPHEMERIS == "warn":
                warn_once(
                    warnings,
                    warning_keys,
                    f"{spec.body_id}:asteroid_ephemeris_missing",
                    asteroid_skip_message([spec.name], reason),
                )
            return None
        try:
            fallback_flags = swe.FLG_MOSEPH | swe.FLG_SPEED
            if sidereal:
                fallback_flags |= swe.FLG_SIDEREAL
            values, _ = swe.calc_ut(jd_ut, spec.code, fallback_flags)
            warn_once(
                warnings,
                warning_keys,
                f"{spec.body_id}:fallback",
                f"{spec.name} 使用 Moshier fallback：{swiss_error}",
            )
            return values, "Moshier fallback"
        except swe.Error as fallback_error:
            warn_once(
                warnings,
                warning_keys,
                f"{spec.body_id}:failed",
                f"无法计算 {spec.name}：{fallback_error}",
            )
            return None


def calculate_body(
    jd_ut: float,
    spec: BodySpec,
    warnings: list[str],
    sidereal: bool = False,
) -> dict[str, Any] | None:
    calculated = calculate_values(jd_ut, spec, warnings, sidereal=sidereal)
    if calculated is None:
        return None

    values, ephemeris_name = calculated
    longitude = (values[0] + spec.longitude_offset) % 360.0
    latitude = values[1]
    speed = values[3]
    sign, degree_text = format_longitude(longitude)

    # 赤纬与出界计算
    # Use equatorial coordinates for accurate declination (covers out-of-bounds).
    # Fall back to longitude-only math if equatorial query fails.
    obliq = obliquity(jd_ut)
    try:
        eq_values, _ = swe.calc_ut(jd_ut, spec.code, swe.FLG_SWIEPH | swe.FLG_EQUATORIAL)
        dec = round(eq_values[1], 4)
        # South Node reuses North Node's swe code with longitude_offset=180.
        # The equatorial call still returns North Node's declination; we must
        # negate it (opposite point on the ecliptic → opposite declination).
        if spec.body_id in ("SOUTH_MEAN_NODE", "SOUTH_TRUE_NODE"):
            dec = round(-dec, 4)
    except swe.Error:
        warnings.append(f"{spec.name}({spec.body_id}) 赤纬计算降级：EQUATORIAL 失败，使用黄经近似")
        dec = round(declination_from_lon(longitude, obliq), 4)
    oob = abs(dec) > obliq

    return {
        "body_id": spec.body_id,
        "name": spec.name,
        "longitude": longitude,
        "latitude": latitude,
        "declination": dec,
        "out_of_bounds": oob,
        "speed": speed,
        "sign": sign,
        "degree_text": degree_text,
        "_ephemeris": ephemeris_name,
    }


def calculate_positions(
    jd_ut: float,
    specs: list[BodySpec],
    warnings: list[str],
    sidereal: bool = False,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for spec in specs:
        row = calculate_body(jd_ut, spec, warnings, sidereal=sidereal)
        if row is not None:
            rows.append(row)
    return rows


def body_longitude_at(
    dt: datetime,
    spec: BodySpec,
    warnings: list[str],
    warning_keys: set[str],
    sidereal: bool = False,
) -> tuple[float, str] | None:
    calculated = calculate_values(jd_from_datetime(dt), spec, warnings, warning_keys, sidereal=sidereal)
    if calculated is None:
        return None
    values, ephemeris_name = calculated
    return (values[0] + spec.longitude_offset) % 360.0, ephemeris_name


def body_speed_at(
    dt: datetime,
    spec: BodySpec,
    warnings: list[str],
    warning_keys: set[str],
    sidereal: bool = False,
) -> tuple[float, str] | None:
    calculated = calculate_values(jd_from_datetime(dt), spec, warnings, warning_keys, sidereal=sidereal)
    if calculated is None:
        return None
    values, ephemeris_name = calculated
    return values[3], ephemeris_name


def call_houses_ex(
    jd_ut: float,
    latitude: float,
    longitude: float,
    house_code: str,
    sidereal: bool,
) -> tuple[list[float], list[float]]:
    flags = swe.FLG_SIDEREAL if sidereal else 0
    code = house_code.encode("ascii")
    attempts = [
        lambda: swe.houses_ex(jd_ut, latitude, longitude, code, flags),
        lambda: swe.houses_ex(jd_ut, flags, latitude, longitude, code),
        lambda: swe.houses_ex(jd_ut, latitude, longitude, code),
        lambda: swe.houses(jd_ut, latitude, longitude, code),
    ]
    last_error: Exception | None = None
    for attempt in attempts:
        try:
            cusps, ascmc = attempt()
            return list(cusps), list(ascmc)
        except TypeError as exc:
            last_error = exc
    raise last_error or RuntimeError("无法调用 Swiss Ephemeris houses")


def build_houses(
    jd_ut: float,
    latitude: float,
    longitude: float,
    house_system: str,
    sidereal: bool,
    warnings: list[str],
) -> tuple[list[float], dict[str, float], str]:
    if house_system not in HOUSE_SYSTEMS:
        _append_unique(warnings, f"未识别的宫位制 '{house_system}'，已改用 Whole Sign。")
        house_system = "whole_sign"
    system_label, house_code = HOUSE_SYSTEMS[house_system]

    try:
        raw_cusps, ascmc = call_houses_ex(jd_ut, latitude, longitude, house_code, sidereal)
    except Exception as exc:
        _append_unique(warnings, f"宫位计算失败，改用 Whole Sign：{exc}")
        raw_cusps, ascmc = call_houses_ex(jd_ut, latitude, longitude, "W", sidereal)
        house_system = "whole_sign"
        system_label = "Whole Sign"

    asc = norm360(ascmc[0])
    mc = norm360(ascmc[1])

    if house_system == "whole_sign":
        first_cusp = zodiac_sign_index(asc) * 30.0
        cusps = [norm360(first_cusp + 30.0 * index) for index in range(12)]
    else:
        if len(raw_cusps) >= 13:
            cusps = [norm360(value) for value in raw_cusps[1:13]]
        elif len(raw_cusps) == 12:
            cusps = [norm360(value) for value in raw_cusps]
        else:
            raise ValueError(f"宫头数量异常：{len(raw_cusps)}")

    if len(cusps) != 12:
        raise ValueError(f"宫头数量异常：{len(cusps)}")
    if len({round(value, 8) for value in cusps}) == 1:
        warnings.append("DATA QUALITY WARNING: All house cusps are identical. House-related hits are suppressed.")

    angles = {"ASC": asc, "MC": mc, "DSC": norm360(asc + 180), "IC": norm360(mc + 180)}
    if math.isclose(angles["ASC"], angles["DSC"], abs_tol=1e-8):
        warnings.append("DATA QUALITY WARNING: ASC 与 DSC 相同。")
    if math.isclose(angles["MC"], angles["IC"], abs_tol=1e-8):
        warnings.append("DATA QUALITY WARNING: MC 与 IC 相同。")

    return cusps, angles, system_label


def longitude_in_interval(longitude: float, start: float, end: float) -> bool:
    value = norm360(longitude)
    start = norm360(start)
    end = norm360(end)
    if end <= start:
        end += 360.0
    if value < start:
        value += 360.0
    return start <= value < end


def house_for_longitude(longitude: float, cusps: list[float]) -> int:
    for index in range(12):
        if longitude_in_interval(longitude, cusps[index], cusps[(index + 1) % 12]):
            return index + 1
    return 1


def point_row(point_id: str, name: str, lon: float, cusps: list[float], formula: str | None = None, formula_day: str | None = None, formula_night: str | None = None, used_formula: str | None = None) -> dict[str, Any]:
    sign, degree_text = format_longitude(lon)
    return {
        "id": point_id,
        "name": name,
        "longitude": norm360(lon),
        "sign": sign,
        "degree_text": degree_text,
        "house": house_for_longitude(lon, cusps),
        "ruler": planet_name(SIGN_RULERS[zodiac_sign_index(lon)]),
        "formula": formula,
        "formula_day": formula_day,
        "formula_night": formula_night,
        "used_formula": used_formula,
    }


def house_rows(cusps: list[float]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for index, cusp in enumerate(cusps, start=1):
        sign, degree_text = format_longitude(cusp)
        rows.append(
            {
                "house": index,
                "sign": sign,
                "cusp_longitude": norm360(cusp),
                "cusp_text": degree_text,
                "ruler": planet_name(SIGN_RULERS[zodiac_sign_index(cusp)]),
            }
        )
    return rows
