from __future__ import annotations

import ast
import operator
import re
import sys
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

try:
    import swisseph as swe
except ImportError as exc:
    sys.stderr.write(
        "缺少 pyswisseph。请在 Mac 上运行：python3 -m pip install pyswisseph\n"
    )
    raise SystemExit(2) from exc


SIGNS = [
    "白羊",
    "金牛",
    "双子",
    "巨蟹",
    "狮子",
    "处女",
    "天秤",
    "天蝎",
    "射手",
    "摩羯",
    "水瓶",
    "双鱼",
]

SIGN_ALIASES = {
    "aries": 0,
    "白羊": 0,
    "牡羊": 0,
    "taurus": 30,
    "金牛": 30,
    "gemini": 60,
    "双子": 60,
    "cancer": 90,
    "巨蟹": 90,
    "leo": 120,
    "狮子": 120,
    "virgo": 150,
    "处女": 150,
    "libra": 180,
    "天秤": 180,
    "scorpio": 210,
    "天蝎": 210,
    "sagittarius": 240,
    "射手": 240,
    "capricorn": 270,
    "摩羯": 270,
    "山羊": 270,
    "aquarius": 300,
    "水瓶": 300,
    "pisces": 330,
    "双鱼": 330,
}


@dataclass(frozen=True)
class BodySpec:
    body_id: str
    name: str
    code: int
    longitude_offset: float = 0.0


@dataclass(frozen=True)
class TargetSpec:
    name: str
    longitude: float


BODY_REGISTRY: dict[str, BodySpec] = {
    "SUN": BodySpec("SUN", "太阳", swe.SUN),
    "MOON": BodySpec("MOON", "月亮", swe.MOON),
    "MERCURY": BodySpec("MERCURY", "水星", swe.MERCURY),
    "VENUS": BodySpec("VENUS", "金星", swe.VENUS),
    "MARS": BodySpec("MARS", "火星", swe.MARS),
    "JUPITER": BodySpec("JUPITER", "木星", swe.JUPITER),
    "SATURN": BodySpec("SATURN", "土星", swe.SATURN),
    "URANUS": BodySpec("URANUS", "天王星", swe.URANUS),
    "NEPTUNE": BodySpec("NEPTUNE", "海王星", swe.NEPTUNE),
    "PLUTO": BodySpec("PLUTO", "冥王星", swe.PLUTO),
    "CHIRON": BodySpec("CHIRON", "凯龙星", swe.CHIRON),
    "PHOLUS": BodySpec("PHOLUS", "人龙星", swe.PHOLUS),
    "CERES": BodySpec("CERES", "谷神星", swe.CERES),
    "PALLAS": BodySpec("PALLAS", "智神星", swe.PALLAS),
    "JUNO": BodySpec("JUNO", "婚神星", swe.JUNO),
    "VESTA": BodySpec("VESTA", "灶神星", swe.VESTA),
    "MEAN_NODE": BodySpec("MEAN_NODE", "北交点 平", swe.MEAN_NODE),
    "TRUE_NODE": BodySpec("TRUE_NODE", "北交点 真", swe.TRUE_NODE),
    "SOUTH_MEAN_NODE": BodySpec("SOUTH_MEAN_NODE", "南交点 平", swe.MEAN_NODE, 180.0),
    "SOUTH_TRUE_NODE": BodySpec("SOUTH_TRUE_NODE", "南交点 真", swe.TRUE_NODE, 180.0),
    "MEAN_LILITH": BodySpec("MEAN_LILITH", "Lilith 平", swe.MEAN_APOG),
    "OSCU_LILITH": BodySpec("OSCU_LILITH", "Lilith 真", swe.OSCU_APOG),
}

CLASSICAL_BODY_IDS = ["SUN", "MOON", "MERCURY", "VENUS", "MARS", "JUPITER", "SATURN"]
ASTEROID_BODY_IDS = {"CHIRON", "PHOLUS", "CERES", "PALLAS", "JUNO", "VESTA"}

SIGN_RULERS = [
    "MARS",
    "VENUS",
    "MERCURY",
    "MOON",
    "SUN",
    "MERCURY",
    "VENUS",
    "MARS",
    "JUPITER",
    "SATURN",
    "SATURN",
    "JUPITER",
]


def fail(message: str, code: int = 1) -> None:
    sys.stderr.write(message.rstrip() + "\n")
    raise SystemExit(code)


def moment_to_local_datetime(moment: dict[str, Any]) -> datetime:
    zone_text = str(moment.get("timezone", "")).strip()
    offset_match = re.fullmatch(r"(?:GMT|UTC)?\s*([+-])\s*(\d{1,2})(?::?(\d{2}))?", zone_text, re.IGNORECASE)
    if offset_match:
        sign = 1 if offset_match.group(1) == "+" else -1
        hours = int(offset_match.group(2))
        minutes = int(offset_match.group(3) or "0")
        if hours > 14 or minutes >= 60:
            raise ValueError(f"未知时区：{moment.get('timezone')}")
        zone = timezone(sign * timedelta(hours=hours, minutes=minutes), name=f"GMT{offset_match.group(1)}{hours:g}")
    else:
        try:
            zone = ZoneInfo(zone_text)
        except ZoneInfoNotFoundError as exc:
            raise ValueError(f"未知时区：{moment.get('timezone')}") from exc

    return datetime(
        int(moment["year"]),
        int(moment["month"]),
        int(moment["day"]),
        int(moment["hour"]),
        int(moment["minute"]),
        tzinfo=zone,
    )


def jd_from_datetime(dt: datetime) -> float:
    utc = dt.astimezone(timezone.utc)
    hour_ut = (
        utc.hour
        + utc.minute / 60.0
        + utc.second / 3600.0
        + utc.microsecond / 3_600_000_000.0
    )
    return swe.julday(utc.year, utc.month, utc.day, hour_ut, swe.GREG_CAL)


def moment_to_jd(moment: dict[str, Any]) -> tuple[float, str]:
    local_dt = moment_to_local_datetime(moment)
    return jd_from_datetime(local_dt), local_dt.astimezone(timezone.utc).isoformat()


def set_zodiac_mode(zodiac: str) -> bool:
    """Configure sidereal mode for Swiss Ephemeris.

    Supports:
      - "tropical" / "" → tropical mode (False returned)
      - "sidereal_lahiri" (legacy), "sidereal_raman", "sidereal_krishnamurti",
        "sidereal_yukteshwar", plus any key from AYANAMSHA_MAP.
      - Plain ayanamsha names ("lahiri", "raman", etc.) also accepted.
    Returns True if any sidereal mode is active, False for tropical.
    """
    if not zodiac or zodiac == "tropical":
        swe.set_sid_mode(swe.SIDM_FAGAN_BRADLEY)  # reset to default
        return False

    # Strip "sidereal_" prefix if present
    key = zodiac.lower().replace("sidereal_", "")

    # Import ayanamsha map (lazy to avoid circular imports)
    try:
        from astro_backend_jyotish_data import AYANAMSHA_MAP
        sid_code = AYANAMSHA_MAP.get(key)
        if sid_code is not None:
            swe.set_sid_mode(sid_code)
            return True
    except ImportError:
        pass

    # Fallback: only "sidereal_lahiri" recognized without the data module
    if key == "lahiri":
        swe.set_sid_mode(swe.SIDM_LAHIRI)
        return True

    return False


def public_position(row: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in row.items() if not key.startswith("_")}


def norm360(value: float) -> float:
    return value % 360.0


def circular_midpoint(lon1: float, lon2: float) -> float:
    diff = ((lon2 - lon1 + 540.0) % 360.0) - 180.0
    if abs(abs(diff) - 180.0) < 1e-9:
        return norm360(lon1 + 90.0)
    return norm360(lon1 + diff / 2.0)


def zodiac_sign_index(longitude: float) -> int:
    return int(norm360(longitude) // 30)


def sign_degree(longitude: float) -> float:
    return norm360(longitude) % 30.0


def format_longitude(longitude: float) -> tuple[str, str]:
    longitude = longitude % 360.0
    sign_index = int(longitude // 30)
    sign_degree_value = longitude - sign_index * 30
    degree = int(sign_degree_value)
    minute_float = (sign_degree_value - degree) * 60
    minute = int(minute_float)
    second = int(round((minute_float - minute) * 60))

    if second == 60:
        second = 0
        minute += 1
    if minute == 60:
        minute = 0
        degree += 1
    if degree == 30:
        degree = 0
        sign_index = (sign_index + 1) % 12

    sign = SIGNS[sign_index]
    return sign, f"{degree:02d}°{minute:02d}'{second:02d}\" {sign}"


def angular_separation(a: float, b: float) -> float:
    diff = abs((a - b) % 360.0)
    return min(diff, 360.0 - diff)


def aspect_orb(transit_lon: float, target_lon: float, aspect_angle: float) -> float:
    delta = abs(norm360(transit_lon - target_lon))
    delta = min(delta, 360.0 - delta)
    return abs(delta - aspect_angle)


def signed_orb(p_lon: float, exact_lon: float) -> float:
    return ((p_lon - exact_lon + 180.0) % 360.0) - 180.0


def safe_eval_degree_expression(text: str) -> float:
    allowed_binary = {
        ast.Add: operator.add,
        ast.Sub: operator.sub,
        ast.Mult: operator.mul,
        ast.Div: operator.truediv,
    }
    allowed_unary = {
        ast.UAdd: operator.pos,
        ast.USub: operator.neg,
    }

    def eval_node(node: ast.AST) -> float:
        if isinstance(node, ast.Expression):
            return eval_node(node.body)
        if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
            return float(node.value)
        if isinstance(node, ast.BinOp) and type(node.op) in allowed_binary:
            return allowed_binary[type(node.op)](eval_node(node.left), eval_node(node.right))
        if isinstance(node, ast.UnaryOp) and type(node.op) in allowed_unary:
            return allowed_unary[type(node.op)](eval_node(node.operand))
        raise ValueError(f"不支持的度数字段：{text}")

    return eval_node(ast.parse(text, mode="eval"))


def parse_degree(text: str) -> float:
    normalized = text.strip()
    if not normalized:
        raise ValueError("缺少度数")

    if re.search(r"[+*/()]", normalized) and not re.search(r"[°º′'″\"]", normalized):
        return safe_eval_degree_expression(normalized)

    normalized = (
        normalized.replace("度", " ")
        .replace("°", " ")
        .replace("º", " ")
        .replace("d", " ")
        .replace("D", " ")
        .replace("分", " ")
        .replace("′", " ")
        .replace("'", " ")
        .replace("m", " ")
        .replace("M", " ")
        .replace("秒", " ")
        .replace("″", " ")
        .replace('"', " ")
        .replace("s", " ")
        .replace("S", " ")
    )
    numbers = [float(item) for item in re.findall(r"[+-]?\d+(?:\.\d+)?", normalized)]
    if not numbers:
        raise ValueError(f"无法解析度数：{text}")

    degree = numbers[0]
    minute = numbers[1] if len(numbers) > 1 else 0.0
    second = numbers[2] if len(numbers) > 2 else 0.0
    return degree + minute / 60.0 + second / 3600.0


def zodiac_longitude(sign: str, degree_text: str) -> float:
    start = SIGN_ALIASES[sign.lower()]
    return (start + parse_degree(degree_text)) % 360.0


def parse_target_line(line: str) -> TargetSpec:
    if "=" in line:
        name, value = line.split("=", 1)
    elif "," in line:
        parts = [part.strip() for part in line.split(",", 2)]
        if len(parts) < 3:
            raise ValueError(f"目标点格式不完整：{line}")
        name = parts[0]
        value = f"{parts[1]} {parts[2]}"
    else:
        raise ValueError(f"目标点需要使用 '=' 或逗号分隔：{line}")

    name = name.strip()
    value = value.strip()
    if not name or not value:
        raise ValueError(f"目标点格式不完整：{line}")

    lowered = value.lower()
    for alias in sorted(SIGN_ALIASES.keys(), key=len, reverse=True):
        if lowered.startswith(alias):
            degree_text = value[len(alias) :].strip()
            return TargetSpec(name, zodiac_longitude(alias, degree_text))
        if re.search(rf"(?<![a-zA-Z]){re.escape(alias)}(?![a-zA-Z])", lowered):
            degree_text = re.sub(
                rf"(?<![a-zA-Z]){re.escape(alias)}(?![a-zA-Z])",
                " ",
                value,
                count=1,
                flags=re.IGNORECASE,
            ).strip()
            return TargetSpec(name, zodiac_longitude(alias, degree_text))

    return TargetSpec(name, parse_degree(value) % 360.0)


def angle_distance(a: float, b: float) -> float:
    return abs(((a - b + 180.0) % 360.0) - 180.0)


def target_by_name(targets: list[TargetSpec], suffix: str) -> TargetSpec | None:
    suffix = suffix.lower()
    for target in targets:
        normalized = target.name.lower().replace("natal ", "").strip()
        if normalized == suffix:
            return target
    return None


def validate_targets(targets: list[TargetSpec]) -> None:
    sign_buckets = {int(target.longitude // 30) for target in targets}
    if len(targets) >= 4 and len(sign_buckets) <= 1:
        raise ValueError("Targets collapsed into one sign. Check degree_in_sign vs absolute_longitude.")

    for first, second in [("asc", "dsc"), ("mc", "ic"), ("house cusp 3rd", "house cusp 9th")]:
        a = target_by_name(targets, first)
        b = target_by_name(targets, second)
        if a is None or b is None:
            continue
        if abs(angle_distance(a.longitude, b.longitude) - 180.0) > 0.01:
            raise ValueError(f"{a.name} 与 {b.name} 不成对冲。请检查 target 黄经是否被截断。")


def parse_targets(text: str) -> list[TargetSpec]:
    targets: list[TargetSpec] = []
    for line_number, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        try:
            targets.append(parse_target_line(line))
        except ValueError as exc:
            raise ValueError(f"第 {line_number} 行目标点错误：{exc}") from exc

    if not targets:
        raise ValueError("至少需要一个目标点")
    names: set[str] = set()
    duplicates: set[str] = set()
    for target in targets:
        if target.name in names:
            duplicates.add(target.name)
        names.add(target.name)
    if duplicates:
        raise ValueError(f"同一目标异常重复：{', '.join(sorted(duplicates))}")
    validate_targets(targets)
    return targets


def planet_name(body_id: str) -> str:
    return BODY_REGISTRY[body_id].name if body_id in BODY_REGISTRY else body_id


def add_years_approx(dt: datetime, years: float) -> datetime:
    return dt + timedelta(days=365.2425 * years)


def completed_age(birth_dt: datetime, reference_dt: datetime) -> int:
    age = reference_dt.year - birth_dt.year
    birth_tuple = (birth_dt.month, birth_dt.day, birth_dt.hour, birth_dt.minute)
    ref_tuple = (reference_dt.month, reference_dt.day, reference_dt.hour, reference_dt.minute)
    if ref_tuple < birth_tuple:
        age -= 1
    return max(age, 0)


def same_month_day(year: int, source: datetime) -> datetime:
    try:
        return source.replace(year=year)
    except ValueError:
        return source.replace(year=year, day=28)


def format_local(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M")
