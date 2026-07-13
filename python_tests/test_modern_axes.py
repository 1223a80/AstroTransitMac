from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

import pytest

from astro_backend_core import angular_separation, jd_from_datetime, norm360
import astro_backend_ephemeris as ephemeris
from astro_backend_ephemeris import build_houses, call_houses_ex, point_row


JD = jd_from_datetime(datetime(1990, 1, 1, 12, tzinfo=timezone.utc))
LATITUDE = 31.2304
LONGITUDE = 121.4737


@pytest.mark.parametrize("sidereal", [False, True])
def test_axes_match_same_houses_ex_and_preserve_existing_houses(sidereal: bool) -> None:
    raw_cusps, ascmc = call_houses_ex(JD, LATITUDE, LONGITUDE, "P", sidereal)
    warnings: list[str] = []

    cusps, angles, system_label = build_houses(
        JD, LATITUDE, LONGITUDE, "placidus", sidereal, warnings
    )

    assert system_label == "Placidus"
    assert warnings == []
    assert len(ascmc) > 4
    assert angles["ASC"] == pytest.approx(norm360(ascmc[0]), abs=1e-9)
    assert angles["MC"] == pytest.approx(norm360(ascmc[1]), abs=1e-9)
    assert angles["DSC"] == pytest.approx(norm360(ascmc[0] + 180.0), abs=1e-9)
    assert angles["IC"] == pytest.approx(norm360(ascmc[1] + 180.0), abs=1e-9)
    assert angles["VERTEX"] == pytest.approx(norm360(ascmc[3]), abs=1e-9)
    assert angles["EQUATORIAL_ASCENDANT"] == pytest.approx(
        norm360(ascmc[4]), abs=1e-9
    )
    assert angles["ANTIVERTEX"] == pytest.approx(
        norm360(angles["VERTEX"] + 180.0), abs=1e-9
    )
    assert angular_separation(angles["VERTEX"], angles["ANTIVERTEX"]) == pytest.approx(
        180.0, abs=1e-9
    )

    assert cusps == pytest.approx([norm360(value) for value in raw_cusps], abs=1e-9)
    anti_row = point_row("ANTIVERTEX", "ANTIVERTEX", angles["ANTIVERTEX"], cusps)
    assert anti_row["longitude"] == pytest.approx(norm360(angles["VERTEX"] + 180.0), abs=1e-9)


@pytest.mark.parametrize(
    ("ascmc", "warning_fragments"),
    [
        (
            [100.0, 200.0],
            ("VERTEX", "ascmc[3]", "缺失"),
        ),
        (
            [100.0, 200.0, 0.0, float("nan"), float("inf")],
            ("VERTEX", "ascmc[3]", "非 finite"),
        ),
        (
            [100.0, 200.0, 0.0, object(), "invalid"],
            ("VERTEX", "ascmc[3]", "转换失败"),
        ),
    ],
    ids=["missing", "non-finite", "conversion-failure"],
)
def test_invalid_axis_values_warn_once_and_do_not_change_houses(
    monkeypatch: pytest.MonkeyPatch,
    ascmc: list[Any],
    warning_fragments: tuple[str, str, str],
) -> None:
    raw_cusps = [float(index * 30) for index in range(12)]

    def fake_call_houses_ex(*args: Any, **kwargs: Any) -> tuple[list[float], list[Any]]:
        return list(raw_cusps), list(ascmc)

    monkeypatch.setattr(ephemeris, "call_houses_ex", fake_call_houses_ex)
    warnings: list[str] = []

    first_cusps, first_angles, first_label = build_houses(
        JD, LATITUDE, LONGITUDE, "placidus", False, warnings
    )
    second_cusps, second_angles, second_label = build_houses(
        JD, LATITUDE, LONGITUDE, "placidus", False, warnings
    )

    assert first_label == second_label == "Placidus"
    assert first_cusps == second_cusps == raw_cusps
    assert first_angles == second_angles == {
        "ASC": 100.0,
        "MC": 200.0,
        "DSC": 280.0,
        "IC": 20.0,
    }
    assert "VERTEX" not in first_angles
    assert "EQUATORIAL_ASCENDANT" not in first_angles
    assert "ANTIVERTEX" not in first_angles
    assert len(warnings) == len(set(warnings)) == 2
    assert all(fragment in " ".join(warnings) for fragment in warning_fragments)
