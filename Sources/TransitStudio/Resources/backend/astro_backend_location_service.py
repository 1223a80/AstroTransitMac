"""Unified location resolution for Relocation, Returns, Local Space, maps.

Same city name must resolve to the same coordinates across modules.
Users may override with explicit lat/lon or a venue-level selection.
"""

from __future__ import annotations

from typing import Any

# Built-in major cities (lat, lon, IANA timezone, country, aliases).
# Coordinates are city-center defaults; venue overrides are allowed separately.
CITY_DB: list[dict[str, Any]] = [
    {
        "id": "cn-beijing",
        "name_zh": "北京",
        "name_en": "Beijing",
        "aliases": ["北京", "Beijing", "Peking"],
        "country": "CN",
        "admin1": "Beijing",
        "latitude": 39.9042,
        "longitude": 116.4074,
        "timezone": "Asia/Shanghai",
        "source": "builtin_city_center",
    },
    {
        "id": "cn-shanghai",
        "name_zh": "上海",
        "name_en": "Shanghai",
        "aliases": ["上海", "Shanghai"],
        "country": "CN",
        "admin1": "Shanghai",
        "latitude": 31.2304,
        "longitude": 121.4737,
        "timezone": "Asia/Shanghai",
        "source": "builtin_city_center",
    },
    {
        "id": "jp-osaka",
        "name_zh": "大阪",
        "name_en": "Osaka",
        "aliases": ["大阪", "Osaka", "おおさか", "オオサカ"],
        "country": "JP",
        "admin1": "Osaka",
        "latitude": 34.6937,
        "longitude": 135.5023,
        "timezone": "Asia/Tokyo",
        "source": "builtin_city_center",
    },
    {
        "id": "jp-tokyo",
        "name_zh": "东京",
        "name_en": "Tokyo",
        "aliases": ["东京", "東京", "Tokyo"],
        "country": "JP",
        "admin1": "Tokyo",
        "latitude": 35.6762,
        "longitude": 139.6503,
        "timezone": "Asia/Tokyo",
        "source": "builtin_city_center",
    },
    {
        "id": "us-new-york",
        "name_zh": "纽约",
        "name_en": "New York",
        "aliases": ["纽约", "New York", "NYC", "New York City"],
        "country": "US",
        "admin1": "New York",
        "latitude": 40.7128,
        "longitude": -74.0060,
        "timezone": "America/New_York",
        "source": "builtin_city_center",
    },
    {
        "id": "gb-london",
        "name_zh": "伦敦",
        "name_en": "London",
        "aliases": ["伦敦", "London"],
        "country": "GB",
        "admin1": "England",
        "latitude": 51.5074,
        "longitude": -0.1278,
        "timezone": "Europe/London",
        "source": "builtin_city_center",
    },
    {
        "id": "au-sydney",
        "name_zh": "悉尼",
        "name_en": "Sydney",
        "aliases": ["悉尼", "Sydney"],
        "country": "AU",
        "admin1": "NSW",
        "latitude": -33.8688,
        "longitude": 151.2093,
        "timezone": "Australia/Sydney",
        "source": "builtin_city_center",
    },
    {
        "id": "cn-hong-kong",
        "name_zh": "香港",
        "name_en": "Hong Kong",
        "aliases": ["香港", "Hong Kong", "HK"],
        "country": "HK",
        "admin1": "Hong Kong",
        "latitude": 22.3193,
        "longitude": 114.1694,
        "timezone": "Asia/Hong_Kong",
        "source": "builtin_city_center",
    },
    {
        "id": "tw-taipei",
        "name_zh": "台北",
        "name_en": "Taipei",
        "aliases": ["台北", "臺北", "Taipei"],
        "country": "TW",
        "admin1": "Taipei",
        "latitude": 25.0330,
        "longitude": 121.5654,
        "timezone": "Asia/Taipei",
        "source": "builtin_city_center",
    },
    {
        "id": "sg-singapore",
        "name_zh": "新加坡",
        "name_en": "Singapore",
        "aliases": ["新加坡", "Singapore"],
        "country": "SG",
        "admin1": "Singapore",
        "latitude": 1.3521,
        "longitude": 103.8198,
        "timezone": "Asia/Singapore",
        "source": "builtin_city_center",
    },
]


def search_locations(query: str, limit: int = 10) -> list[dict[str, Any]]:
    """Search builtin cities by Chinese/English name or alias."""
    q = (query or "").strip().lower()
    if not q:
        return []
    hits: list[dict[str, Any]] = []
    for city in CITY_DB:
        names = [city["name_zh"], city["name_en"], *city.get("aliases", [])]
        if any(q in str(n).lower() or str(n).lower() in q for n in names):
            hits.append(_public_city(city))
        if len(hits) >= limit:
            break
    return hits


def resolve_location(
    *,
    query: str | None = None,
    location_id: str | None = None,
    latitude: float | None = None,
    longitude: float | None = None,
    timezone: str | None = None,
    name: str | None = None,
    allow_manual: bool = True,
    warnings: list[str] | None = None,
) -> dict[str, Any]:
    """Resolve a single location record for shared use across modules.

    Priority:
    1. Explicit location_id
    2. Exact/alias city query
    3. Manual lat/lon (advanced)
    """
    warnings = warnings if warnings is not None else []

    if location_id:
        for city in CITY_DB:
            if city["id"] == location_id:
                return _resolved(city, override=False)

    if query:
        hits = search_locations(query, limit=20)
        if len(hits) == 1:
            city = next(c for c in CITY_DB if c["id"] == hits[0]["id"])
            return _resolved(city, override=False)
        if len(hits) > 1:
            # Prefer exact alias match
            q = query.strip().lower()
            for city in CITY_DB:
                aliases = [str(a).lower() for a in [city["name_zh"], city["name_en"], *city.get("aliases", [])]]
                if q in aliases:
                    return _resolved(city, override=False)
            return {
                "resolved": False,
                "candidates": hits,
                "error": "ambiguous_city",
                "query": query,
            }
        warnings.append(f"location query '{query}' not found in builtin city DB")

    if allow_manual and latitude is not None and longitude is not None:
        return {
            "resolved": True,
            "id": "manual",
            "name": name or "Manual coordinates",
            "name_zh": name or "手动坐标",
            "name_en": name or "Manual coordinates",
            "latitude": float(latitude),
            "longitude": float(longitude),
            "timezone": timezone or "UTC",
            "source": "manual_coordinates",
            "country": None,
            "admin1": None,
            "is_city_center": False,
            "override": True,
            "note": "Advanced manual lat/lon; not from shared city center table",
        }

    return {
        "resolved": False,
        "error": "location_unresolved",
        "query": query,
        "candidates": [],
    }


def _public_city(city: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": city["id"],
        "name_zh": city["name_zh"],
        "name_en": city["name_en"],
        "country": city["country"],
        "admin1": city.get("admin1"),
        "latitude": city["latitude"],
        "longitude": city["longitude"],
        "timezone": city["timezone"],
        "source": city["source"],
        "aliases": list(city.get("aliases") or []),
    }


def _resolved(city: dict[str, Any], *, override: bool) -> dict[str, Any]:
    row = _public_city(city)
    row.update({
        "resolved": True,
        "name": city["name_zh"] or city["name_en"],
        "is_city_center": True,
        "override": override,
    })
    return row


__all__ = ["search_locations", "resolve_location", "CITY_DB"]
