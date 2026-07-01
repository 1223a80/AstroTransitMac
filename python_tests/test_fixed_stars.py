"""Tests for fixed star catalogs and conjunction detection."""
from __future__ import annotations

from astro_backend_fixed_stars import (
    STAR_CATALOG,
    compute_star_positions,
    find_star_conjunctions,
)


class TestStarCatalog:
    """Verify star catalog completeness and structure."""

    def test_catalog_has_30_stars(self):
        assert len(STAR_CATALOG) >= 30, f"Expected ≥30 stars, got {len(STAR_CATALOG)}"

    def test_royal_stars_present(self):
        names = {s["name"] for s in STAR_CATALOG}
        for royal in ("Aldebaran", "Regulus", "Antares", "Fomalhaut"):
            assert royal in names, f"{royal} missing from catalog"

    def test_algol_present(self):
        names = {s["name"] for s in STAR_CATALOG}
        assert "Algol" in names

    def test_spica_present(self):
        names = {s["name"] for s in STAR_CATALOG}
        assert "Spica" in names

    def test_all_have_orb(self):
        for s in STAR_CATALOG:
            assert s["orb"] > 0, f"{s['name']} has orb=0"

    def test_all_have_swe_name(self):
        for s in STAR_CATALOG:
            assert s["swe_name"], f"{s['name']} missing swe_name"


class TestStarConjunctions:
    """Star conjunction detection (requires ephemeris path set)."""

    def test_compute_star_positions(self):
        """compute_star_positions returns a list with at least some entries."""
        positions = compute_star_positions(2451545.0)
        assert len(positions) > 0
        for p in positions[:5]:
            assert 0 <= p["longitude"] < 360
            assert "name" in p

    def test_non_empty_at_j2000(self):
        """Most stars should be computable at J2000 epoch."""
        positions = compute_star_positions(2451545.0)
        assert len(positions) >= 25, f"Only {len(positions)} stars computed"

    def test_regulus_longitude_near_29_leo(self):
        """Regulus should be around 29° Leo (approximately, J2000)."""
        positions = compute_star_positions(2451545.0)
        regulus = next((p for p in positions if p["name"] == "Regulus"), None)
        if regulus:
            # Regulus J2000: ~29.8° Leo = ~149.8° absolute
            assert 145 < regulus["longitude"] < 155, f"Regulus at {regulus['longitude']}"

    def test_find_conjunctions(self):
        """Known conjunction: Mars near Antares (1990 birth chart)."""
        planets = [{"body_id": "MARS", "longitude": 250.0}]
        stars = [{"name": "Antares", "longitude": 249.8, "orb": 2.0, "mag": 1.06, "nature": "火/木星", "keyword": "test"}]
        conj = find_star_conjunctions(planets, stars)
        assert len(conj) == 1
        assert conj[0]["star"] == "Antares"
        assert conj[0]["planet"] == "MARS"
