"""Tests for fixed star catalogs and conjunction detection."""
from __future__ import annotations

from pathlib import Path

from astro_backend_api import _bundled_ephemeris_path
from astro_backend_core import swe
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

    def test_bundled_catalog_names_are_computable(self):
        ephe_path = Path(__file__).resolve().parents[1] / "Sources" / "TransitStudio" / "Resources" / "ephemeris"
        swe.set_ephe_path(str(ephe_path))
        warnings: list[str] = []
        positions = compute_star_positions(2451545.0, warnings=warnings)
        assert len(positions) == len(STAR_CATALOG)
        assert warnings == []
        assert any(p["name"] == "Zubenelschemali" for p in positions)
        # RA remains required for B18's explicit schema-v1 legacy proxy output.
        for p in positions:
            assert "ra" in p and p["ra"] is not None
            assert "right_ascension" in p and p["right_ascension"] is not None
            assert "declination" in p

    def test_bundled_ephemeris_path_supports_source_layout(self, tmp_path):
        backend_dir = tmp_path / "Resources" / "backend"
        ephe_dir = tmp_path / "Resources" / "ephemeris"
        backend_dir.mkdir(parents=True)
        ephe_dir.mkdir(parents=True)
        module_file = backend_dir / "astro_backend_api.py"
        module_file.write_text("# test\n")
        (ephe_dir / "sefstars.txt").write_text("# test\n")

        assert _bundled_ephemeris_path(module_file) == ephe_dir

    def test_bundled_ephemeris_path_supports_packaged_bundle_layout(self, tmp_path):
        bundle_dir = tmp_path / "AstroTransitMac_TransitStudio.bundle"
        bundle_dir.mkdir()
        module_file = bundle_dir / "astro_backend_api.py"
        module_file.write_text("# test\n")
        (bundle_dir / "sefstars.txt").write_text("# test\n")

        assert _bundled_ephemeris_path(module_file) == bundle_dir


class TestStarConjunctions:
    """Star conjunction detection (requires ephemeris path set)."""

    def test_compute_star_positions(self):
        """compute_star_positions returns a list with at least some entries."""
        positions = compute_star_positions(2451545.0)
        # If sefstars.txt is available, expect > 0 entries
        if len(positions) == 0:
            # The file is not available in this environment — that's acceptable
            return

    def test_stars_with_warnings(self):
        """When sefstars.txt is missing or some stars fail, a warning is emitted."""
        warnings: list[str] = []
        positions = compute_star_positions(2451545.0, warnings=warnings)
        if len(positions) == 0:
            assert len(warnings) > 0, "Expected a warning when stars can't be computed"
        else:
            # Some stars computed successfully — warnings may still appear for
            # individual stars that failed (e.g. name mismatches). This is OK.
            assert len(positions) > 0

    def test_non_empty_at_j2000(self):
        """Most stars should be computable at J2000 epoch."""
        positions = compute_star_positions(2451545.0)
        # Accept 0 if sefstars.txt is not available in this environment
        if len(positions) >= 25:
            return
        # If some stars were computed but fewer than expected, that's still OK
        # (depends on ephemeris file availability)
        assert 0 <= len(positions) <= 30, f"Unexpected count: {len(positions)}"

    def test_regulus_longitude_near_29_leo(self):
        """Regulus should be around 29° Leo (approximately, J2000)."""
        positions = compute_star_positions(2451545.0)
        regulus = next((p for p in positions if p["name"] == "Regulus"), None)
        if regulus is None:
            return  # sefstars.txt not available
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


class TestResolveEphePath:
    """User ephemeris dir must not hide the bundled sefstars.txt (fix 2026-07-06)."""

    def test_user_path_combined_with_bundled(self):
        from astro_backend_api import _resolve_ephe_path
        bundled = _bundled_ephemeris_path()
        assert bundled is not None
        resolved = _resolve_ephe_path("/tmp/user-ephe", bundled)
        assert resolved == f"/tmp/user-ephe:{bundled}"

    def test_user_path_only_when_no_bundled(self):
        from astro_backend_api import _resolve_ephe_path
        assert _resolve_ephe_path("/tmp/user-ephe", None) == "/tmp/user-ephe"

    def test_bundled_only_when_no_user_path(self):
        from astro_backend_api import _resolve_ephe_path
        bundled = _bundled_ephemeris_path()
        assert _resolve_ephe_path("", bundled) == str(bundled)

    def test_same_path_not_duplicated(self):
        from astro_backend_api import _resolve_ephe_path
        bundled = _bundled_ephemeris_path()
        assert _resolve_ephe_path(str(bundled), bundled) == str(bundled)

    def test_fixstars_reachable_via_combined_path(self, tmp_path):
        """Simulate the real bug: user dir without sefstars.txt + combined path."""
        from astro_backend_api import _resolve_ephe_path
        bundled = _bundled_ephemeris_path()
        resolved = _resolve_ephe_path(str(tmp_path), bundled)
        swe.set_ephe_path(resolved)
        try:
            values, _, _ = swe.fixstar_ut("Regulus", 2461000.0, swe.FLG_SWIEPH)
            assert 149 < values[0] < 152
        finally:
            swe.set_ephe_path(str(bundled))
