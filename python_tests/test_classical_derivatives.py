from __future__ import annotations

from astro_backend_api import validate_required_fields
from astro_backend_classical_derivatives import calculate_classical_derivatives


def _req():
    import json
    from pathlib import Path

    return json.loads(Path("Examples/sample-classical-derivatives-request.json").read_text())


def test_api_accepts():
    assert validate_required_fields(_req()) is None


def test_calculate_defining_facts():
    r = calculate_classical_derivatives(_req(), [])
    assert r["meta"]["mode"] == "classical_derivatives"
    assert r.get("calculation_assumptions")
    assert "requested_config" in r and "effective_config" in r
    assert isinstance(r.get("warnings"), list)

    dodeka = r["dodekatemoria"]
    mono = r["monomoiria"]
    topical = r["topical_almutens"]
    assert len(dodeka) >= 7
    assert len(mono) >= 7
    assert len(topical) >= 1
    for row in dodeka:
        assert row.get("source_id")
        assert row.get("dodekatemorion_longitude") is not None
        assert row.get("method_key") == "calc_dodekatemorion"
    for row in mono:
        assert row.get("source_id")
        assert row.get("monomoiria_ruler")
        assert row.get("method_profile") == "sign_domicile_ruler_per_degree_v1"
    for row in topical:
        assert row.get("topic_id")
        assert row.get("winner_id")
        assert row.get("method_key") == "topical_almuten_essential_count_v1"
