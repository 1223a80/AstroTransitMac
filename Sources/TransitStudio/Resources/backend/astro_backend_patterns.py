from __future__ import annotations

from typing import Any

PATTERN_ASPECT_ORB = 6.0
YOD_QUINCUNX_ORB = 3.0

PATTERN_TYPES: dict[str, str] = {
    "t_square": "T三角",
    "grand_trine": "大三角",
    "grand_cross": "大十字",
    "kite": "风筝",
    "yod": "Yod",
    "mystic_rectangle": "神秘矩形",
    "stellium": "星群",
}

CHART_SHAPE_TYPES: dict[str, str] = {
    "bucket": "提桶",
    "bowl": "碗形",
    "seesaw": "跷跷板",
    "splash": "散射",
    "splay": "不规则",
    "locomotive": "火车头",
    "bundle": "聚集",
    "fan": "扇形",
    "cradle": "摇篮",
}


def _find_stelliums(
    body_lons: dict[str, float],
    house_map: dict[str, int] | None = None,
) -> list[dict[str, Any]]:
    from astro_backend_core import zodiac_sign_index
    results: list[dict[str, Any]] = []
    sign_members: dict[int, list[str]] = {}
    for bid in body_lons:
        si = zodiac_sign_index(body_lons[bid])
        sign_members.setdefault(si, []).append(bid)
    for si, members in sign_members.items():
        if len(members) >= 3:
            results.append({
                "id": f"stellium_sign_{si}",
                "type": "stellium",
                "type_name": PATTERN_TYPES["stellium"],
                "members": sorted(members),
                "aspect_types": [],
                "orb_summary": "stellium",
                "confidence": "high",
                "stellium_sign": si,
                "stellium_house": None,
            })
    if house_map:
        house_members: dict[int, list[str]] = {}
        for bid, h in house_map.items():
            if bid not in body_lons:
                continue
            house_members.setdefault(h, []).append(bid)
        for h, members in house_members.items():
            if len(members) >= 3:
                confl = [r for r in results if r.get("stellium_house") == h]
                if not confl:
                    results.append({
                        "id": f"stellium_house_{h}",
                        "type": "stellium",
                        "type_name": PATTERN_TYPES["stellium"],
                        "members": sorted(members),
                        "aspect_types": [],
                        "orb_summary": "stellium",
                        "confidence": "high",
                        "stellium_sign": None,
                        "stellium_house": h,
                    })
    return results


def find_patterns(
    body_lons: dict[str, float],
    aspects: list[dict[str, Any]],
    house_map: dict[str, int] | None = None,
    main_bodies: set[str] | None = None,
    warnings: list[str] | None = None,
) -> list[dict[str, Any]]:
    from astro_backend_core import angular_separation
    if main_bodies is None:
        main_bodies = {"SUN", "MOON", "MERCURY", "VENUS", "MARS",
                       "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO"}
    patterns: list[dict[str, Any]] = []
    seen_signatures: set[str] = set()

    def _aspect_counts(members: list[str]) -> dict[str, float]:
        counts: dict[str, float] = {}
        for i, a in enumerate(members):
            for b in members[i + 1:]:
                sep = angular_separation(body_lons[a], body_lons[b])
                for aid, angle in [("conjunction", 0), ("opposition", 180), ("trine", 120),
                                    ("square", 90), ("sextile", 60), ("quincunx", 150)]:
                    orb = YOD_QUINCUNX_ORB if aid == "quincunx" else PATTERN_ASPECT_ORB
                    if abs(sep - angle) <= orb + 1e-9:
                        counts[aid] = counts.get(aid, 0) + 1
                        break
        return counts

    def _all_orbs(members: list[str]) -> list[float]:
        orbs: list[float] = []
        for i, a in enumerate(members):
            for b in members[i + 1:]:
                sep = angular_separation(body_lons[a], body_lons[b])
                for aid, angle in [("conjunction", 0), ("opposition", 180), ("trine", 120),
                                    ("square", 90), ("sextile", 60), ("quincunx", 150)]:
                    orb = YOD_QUINCUNX_ORB if aid == "quincunx" else PATTERN_ASPECT_ORB
                    if abs(sep - angle) <= orb + 1e-9:
                        orbs.append(abs(sep - angle))
                        break
        return orbs

    def _confidence(orbs: list[float]) -> str:
        if not orbs:
            return "medium"
        if all(o <= PATTERN_ASPECT_ORB * 0.4 + 1e-9 for o in orbs):
            return "high"
        return "medium"

    def _register(p: dict[str, Any]) -> None:
        sig = tuple(sorted(p["members"]))
        if sig not in seen_signatures:
            seen_signatures.add(sig)
            patterns.append(p)

    all_members = set(body_lons.keys())

    # T-square
    for a in all_members:
        for b in all_members:
            if b <= a:
                continue
            sep_ab = angular_separation(body_lons[a], body_lons[b])
            if abs(sep_ab - 180.0) > PATTERN_ASPECT_ORB + 1e-9:
                continue
            for c in all_members:
                if c in (a, b):
                    continue
                sep_ac = angular_separation(body_lons[a], body_lons[c])
                sep_bc = angular_separation(body_lons[b], body_lons[c])
                sq = sum(1 for s in (sep_ac, sep_bc) if abs(s - 90.0) <= PATTERN_ASPECT_ORB + 1e-9)
                if sq >= 2:
                    members = sorted([a, b, c])
                    orbs = _all_orbs(members)
                    _register({
                        "id": f"t_square_{'_'.join(members)}",
                        "type": "t_square",
                        "type_name": PATTERN_TYPES["t_square"],
                        "members": members,
                        "aspect_types": ["opposition", "square", "square"],
                        "orb_summary": f"{max(orbs):.2f}°" if orbs else "",
                        "confidence": _confidence(orbs),
                    })

    # Grand Trine
    for a in all_members:
        for b in all_members:
            if b <= a:
                continue
            for c in all_members:
                if c <= b:
                    continue
                sep_ab = angular_separation(body_lons[a], body_lons[b])
                sep_bc = angular_separation(body_lons[b], body_lons[c])
                sep_ac = angular_separation(body_lons[a], body_lons[c])
                if all(abs(s - 120.0) <= PATTERN_ASPECT_ORB + 1e-9 for s in (sep_ab, sep_bc, sep_ac)):
                    members = sorted([a, b, c])
                    orbs = _all_orbs(members)
                    _register({
                        "id": f"grand_trine_{'_'.join(members)}",
                        "type": "grand_trine",
                        "type_name": PATTERN_TYPES["grand_trine"],
                        "members": members,
                        "aspect_types": ["trine", "trine", "trine"],
                        "orb_summary": f"{max(orbs):.2f}°" if orbs else "",
                        "confidence": _confidence(orbs),
                    })

    # Grand Cross
    for a in all_members:
        for b in all_members:
            if b <= a:
                continue
            sep_ab = angular_separation(body_lons[a], body_lons[b])
            if abs(sep_ab - 180.0) > PATTERN_ASPECT_ORB + 1e-9:
                continue
            for c in all_members:
                if c in (a, b):
                    continue
                for d in all_members:
                    if d in (a, b, c) or d <= c:
                        continue
                    sep_cd = angular_separation(body_lons[c], body_lons[d])
                    if abs(sep_cd - 180.0) > PATTERN_ASPECT_ORB + 1e-9:
                        continue
                    members = sorted([a, b, c, d])
                    ac = _aspect_counts(members)
                    if ac.get("opposition", 0) >= 2 and ac.get("square", 0) >= 4:
                        orbs = _all_orbs(members)
                        _register({
                            "id": f"grand_cross_{'_'.join(members)}",
                            "type": "grand_cross",
                            "type_name": PATTERN_TYPES["grand_cross"],
                            "members": members,
                            "aspect_types": ["opposition", "opposition", "square", "square", "square", "square"],
                            "orb_summary": f"{max(orbs):.2f}°" if orbs else "",
                            "confidence": _confidence(orbs),
                        })

    # Kite
    for gt in [p for p in patterns if p["type"] == "grand_trine"]:
        gt_members = set(gt["members"])
        remaining = all_members - gt_members
        for d in remaining:
            opp_count = 0
            sextile_count = 0
            for gt_m in gt_members:
                sep = angular_separation(body_lons[d], body_lons[gt_m])
                if abs(sep - 180.0) <= PATTERN_ASPECT_ORB + 1e-9:
                    opp_count += 1
                elif abs(sep - 60.0) <= PATTERN_ASPECT_ORB + 1e-9:
                    sextile_count += 1
            if opp_count >= 1 and sextile_count >= 2:
                members = sorted(gt_members | {d})
                orbs = _all_orbs(members)
                _register({
                    "id": f"kite_{'_'.join(members)}",
                    "type": "kite",
                    "type_name": PATTERN_TYPES["kite"],
                    "members": members,
                    "aspect_types": [
                        "opposition" if angular_separation(body_lons[d], body_lons[m]) <= 180 + PATTERN_ASPECT_ORB
                        else "sextile" for m in gt_members
                    ],
                    "orb_summary": f"{max(orbs):.2f}°" if orbs else "",
                    "confidence": _confidence(orbs),
                })

    # Yod (quincunx orb 3°)
    for a in all_members:
        for b in all_members:
            if b <= a:
                continue
            sep_ab = angular_separation(body_lons[a], body_lons[b])
            if abs(sep_ab - 60.0) > PATTERN_ASPECT_ORB + 1e-9:
                continue
            for c in all_members:
                if c in (a, b):
                    continue
                sep_ac = angular_separation(body_lons[a], body_lons[c])
                sep_bc = angular_separation(body_lons[b], body_lons[c])
                qc = sum(1 for s in (sep_ac, sep_bc) if abs(s - 150.0) <= YOD_QUINCUNX_ORB + 1e-9)
                if qc >= 2:
                    members = sorted([a, b, c])
                    orbs = _all_orbs(members)
                    _register({
                        "id": f"yod_{'_'.join(members)}",
                        "type": "yod",
                        "type_name": PATTERN_TYPES["yod"],
                        "members": members,
                        "aspect_types": ["sextile", "quincunx", "quincunx"],
                        "orb_summary": f"{max(orbs):.2f}°" if orbs else "",
                        "confidence": _confidence(orbs),
                    })

    # Mystic Rectangle
    for a in all_members:
        for b in all_members:
            if b <= a:
                continue
            sep_ab = angular_separation(body_lons[a], body_lons[b])
            if abs(sep_ab - 180.0) > PATTERN_ASPECT_ORB + 1e-9:
                continue
            for c in all_members:
                if c in (a, b):
                    continue
                for d in all_members:
                    if d in (a, b, c) or d <= c:
                        continue
                    sep_cd = angular_separation(body_lons[c], body_lons[d])
                    if abs(sep_cd - 180.0) > PATTERN_ASPECT_ORB + 1e-9:
                        continue
                    members = sorted([a, b, c, d])
                    ac = _aspect_counts(members)
                    if (ac.get("opposition", 0) >= 2 and ac.get("trine", 0) >= 2
                            and ac.get("sextile", 0) >= 2):
                        orbs = _all_orbs(members)
                        _register({
                            "id": f"mystic_rectangle_{'_'.join(members)}",
                            "type": "mystic_rectangle",
                            "type_name": PATTERN_TYPES["mystic_rectangle"],
                            "members": members,
                            "aspect_types": ["opposition", "opposition", "trine", "trine", "sextile", "sextile"],
                            "orb_summary": f"{max(orbs):.2f}°" if orbs else "",
                            "confidence": _confidence(orbs),
                        })

    # Stellium
    stelliums = _find_stelliums(body_lons, house_map)
    for s in stelliums:
        _register(s)

    # Chart shapes (separate signature from aspect patterns)
    try:
        shapes = find_chart_shapes(body_lons, main_bodies)
        shape_seen: set[str] = set()
        for s in shapes:
            sig = s["type"]
            if sig not in shape_seen:
                shape_seen.add(sig)
                patterns.append(s)
    except Exception as exc:
        if warnings is not None:
            warnings.append(f"星盘形状（chart shape）检测失败，已跳过该部分：{exc}")

    patterns.sort(key=lambda p: (p["type"], p["id"]))
    return patterns


def find_chart_shapes(
    body_lons: dict[str, float],
    main_bodies: set[str] | None = None,
) -> list[dict[str, Any]]:
    from astro_backend_core import angular_separation
    if main_bodies is None:
        main_bodies = {"SUN", "MOON", "MERCURY", "VENUS", "MARS",
                       "JUPITER", "SATURN", "URANUS", "NEPTUNE", "PLUTO"}
    lons = {bid: body_lons[bid] for bid in body_lons if bid in main_bodies}
    if len(lons) < 3:
        return []

    sorted_bodies = sorted(lons.keys(), key=lambda b: lons[b])
    sorted_lons = [lons[b] for b in sorted_bodies]
    n = len(sorted_lons)
    shapes: list[dict[str, Any]] = []
    span = sorted_lons[-1] - sorted_lons[0]
    if span < 0:
        span += 360.0

    total_members = list(lons.keys())

    # Bundle: all within 90°
    if span <= 90.0:
        shapes.append({
            "id": "bundle", "type": "bundle", "type_name": CHART_SHAPE_TYPES["bundle"],
            "members": sorted(total_members), "aspect_types": [], "orb_summary": f"{span:.1f}°",
            "confidence": "high" if span <= 60.0 else "medium",
        })

    # Bowl: all within 180°
    if span < 180.0 - 1e-9:
        shapes.append({
            "id": "bowl", "type": "bowl", "type_name": CHART_SHAPE_TYPES["bowl"],
            "members": sorted(total_members), "aspect_types": [], "orb_summary": f"{span:.1f}°",
            "confidence": "high" if span <= 150.0 else "medium",
        })

    # Locomotive: gap of 60-120°, rest within ~300°
    if n >= 4:
        gaps = [(sorted_lons[(i + 1) % n] - sorted_lons[i]) % 360.0 for i in range(n)]
        max_gap = max(gaps)
        max_gap_idx = gaps.index(max_gap)
        if 60.0 <= max_gap <= 150.0:
            leader = sorted_bodies[(max_gap_idx + 1) % n]
            other_members = [b for b in sorted_bodies if b != leader]
            shapes.append({
                "id": "locomotive", "type": "locomotive", "type_name": CHART_SHAPE_TYPES["locomotive"],
                "members": sorted(total_members), "aspect_types": [], "orb_summary": f"缺口{max_gap:.1f}°",
                "confidence": "medium",
                "locomotive_leader": leader,
            })

    # Splash: spread across 8+ signs
    from astro_backend_core import zodiac_sign_index
    signs_used = {zodiac_sign_index(lons[b]) for b in lons}
    if len(signs_used) >= 8:
        shapes.append({
            "id": "splash", "type": "splash", "type_name": CHART_SHAPE_TYPES["splash"],
            "members": sorted(total_members), "aspect_types": [], "orb_summary": f"{len(signs_used)}星座",
            "confidence": "high" if len(signs_used) >= 10 else "medium",
        })

    # Splay: no other shape clearly fits (falls through)
    if not shapes:
        shapes.append({
            "id": "splay", "type": "splay", "type_name": CHART_SHAPE_TYPES["splay"],
            "members": sorted(total_members), "aspect_types": [], "orb_summary": "",
            "confidence": "medium",
        })

    # Bucket: one body opposed to all others
    for focal in lons:
        opp_count = 0
        for other in lons:
            if other == focal:
                continue
            sep = angular_separation(lons[focal], lons[other])
            if abs(sep - 180.0) <= 6.0:
                opp_count += 1
        if opp_count >= 2 and opp_count >= len(lons) - 3:
            shapes.append({
                "id": f"bucket_{focal}", "type": "bucket", "type_name": CHART_SHAPE_TYPES["bucket"],
                "members": sorted(total_members), "aspect_types": [], "orb_summary": f"handle={focal}",
                "confidence": "high" if opp_count >= len(lons) - 2 else "medium",
                "bucket_handle": focal,
            })

    # Seesaw: two clusters separated by ~180°
    if n >= 4:
        for i in range(1, n - 1):
            cluster_a = sorted_bodies[:i]
            cluster_b = sorted_bodies[i:]
            lon_a = sum(lons[b] for b in cluster_a) / len(cluster_a)
            lon_b = sum(lons[b] for b in cluster_b) / len(cluster_b)
            between = angular_separation(lon_a, lon_b)
            if abs(between - 180.0) <= 15.0 and abs(between - 180.0) <= 30.0:
                shapes.append({
                    "id": "seesaw", "type": "seesaw", "type_name": CHART_SHAPE_TYPES["seesaw"],
                    "members": sorted(total_members), "aspect_types": [],
                    "orb_summary": f"聚类间距{between:.1f}°",
                    "confidence": "high" if abs(between - 180.0) <= 10.0 else "medium",
                    "cluster_a": sorted(cluster_a),
                    "cluster_b": sorted(cluster_b),
                })

    # Fan: find a focal planet with 2+ quincunxes
    for focal in lons:
        quincunx_count = 0
        sextile_count = 0
        for other in lons:
            if other == focal:
                continue
            sep = angular_separation(lons[focal], lons[other])
            if abs(sep - 150.0) <= 3.0:
                quincunx_count += 1
            elif abs(sep - 60.0) <= 6.0:
                sextile_count += 1
        if quincunx_count >= 2 and sextile_count >= 1:
            shapes.append({
                "id": f"fan_{focal}", "type": "fan", "type_name": CHART_SHAPE_TYPES["fan"],
                "members": sorted(total_members), "aspect_types": [],
                "orb_summary": f"focal={focal}",
                "confidence": "medium",
                "fan_focal": focal,
            })

    # Cradle: 4 planets forming 2 sextiles + 2 trines
    for a in lons:
        for b in lons:
            if b <= a:
                continue
            sep_ab = angular_separation(lons[a], lons[b])
            if abs(sep_ab - 60.0) > 6.0:
                continue
            for c in lons:
                if c in (a, b):
                    continue
                for d in lons:
                    if d in (a, b, c) or d <= c:
                        continue
                    sep_cd = angular_separation(lons[c], lons[d])
                    if abs(sep_cd - 60.0) > 6.0:
                        continue
                    members = [a, b, c, d]
                    trine_count = 0
                    for i, x in enumerate(members):
                        for y in members[i + 1:]:
                            if abs(angular_separation(lons[x], lons[y]) - 120.0) <= 6.0:
                                trine_count += 1
                    opp_count = 0
                    for i, x in enumerate(members):
                        for y in members[i + 1:]:
                            if abs(angular_separation(lons[x], lons[y]) - 180.0) <= 6.0:
                                opp_count += 1
                    if trine_count >= 2 and opp_count >= 1:
                        shapes.append({
                            "id": f"cradle_{'_'.join(sorted(members))}",
                            "type": "cradle", "type_name": CHART_SHAPE_TYPES["cradle"],
                            "members": sorted(members), "aspect_types": [],
                            "orb_summary": "",
                            "confidence": "medium",
                        })

    seen_sigs: set[str] = set()
    unique_shapes: list[dict[str, Any]] = []
    for s in shapes:
        sig = (s["type"], tuple(s["members"]))
        if sig not in seen_sigs:
            seen_sigs.add(sig)
            unique_shapes.append(s)
    return unique_shapes
