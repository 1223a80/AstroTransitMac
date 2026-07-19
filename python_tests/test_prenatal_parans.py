from __future__ import annotations

from pathlib import Path

from astro_backend_api import validate_required_fields
from astro_backend_core import swe
from astro_backend_prenatal_parans import calculate_prenatal_parans

EPHE_PATH = Path(__file__).resolve().parents[1] / "Sources" / "TransitStudio" / "Resources" / "ephemeris"


def _req():
    import json

    return json.loads(Path("Examples/sample-prenatal-parans-request.json").read_text())


def test_api_accepts():
    assert validate_required_fields(_req()) is None


def test_calculate_defining_facts():
    swe.set_ephe_path(str(EPHE_PATH))
    r = calculate_prenatal_parans(_req(), [])
    assert r["meta"]["mode"] == "prenatal_parans"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)

    packet = r["prenatal_packet"]
    syz = packet["prenatal_syzygy"]
    assert syz.get("syzygy_type") in {"new_moon", "full_moon"}
    assert syz.get("exact_jd") is not None or syz.get("jd") is not None
    assert "syzygy_chart" in packet, "syzygy_chart must be built from exact_jd"
    chart = packet["syzygy_chart"]
    assert chart.get("planets")
    assert chart.get("angles")
    assert chart.get("method_key") == "syzygy_chart_from_exact_jd"

    parans = r["fixed_star_parans"]
    assert isinstance(parans, list)
    # Default 1° RA orb should yield co-culmination hits when star RA is present.
    assert len(parans) >= 1, f"expected non-empty fixed_star_parans; warnings={r.get('warnings')}"
    for p in parans[:3]:
        assert p.get("planet_id")
        assert p.get("star_name")
        assert p.get("planet_ra") is not None
        assert p.get("star_ra") is not None
        assert p.get("method_key") == "fixed_star_paran_ra_proxy_v1"
