# Horary Data Packet horary-data-packet/2.1

## Schema & Provenance

- schema: `horary-data-packet/2.1`
- engine: TransitStudio.horary_v2 2.1.0
- algorithm: horary-v2.1-2026-07
- ephemeris: Swiss Ephemeris (pyswisseph) 2.10.03
- input_hash: `3bd06f3e066c8f2c2e139c8764249853da79e287f5821deb1d2473b928bb6678`
- config_hash: `bf3bcf888e643077c8ce944a485eb3bb8fac65e8183eb9c8eeb84d0e63b2b8e6`

## Question Metadata

- question_text: opaque question string for golden
- place_name: 临沂市

## Time & Location

- local: 2026-07-23 22:25
- utc: 2026-07-23T14:25:00Z
- timezone: Asia/Shanghai (offset_seconds=28800, dst_active=False)
- jd_ut: 2461245.1006944445
- jd_tt: 2461245.101491164
- delta_t_seconds: 68.836561
- sidereal_time_hours: 10.50610797
- armc_deg: 275.93811952
- obliquity_deg: 23.43583742
- lat/lon: 35.0924, 118.3465 (east_positive)
- altitude_m: 0.0
- is_day: False (rule_id=sect.sun_above_horizon_by_asc_dsc_arc.v1)

## Calculation Config

- house_system: regiomontanus (Regiomontanus)
- zodiac: tropical (Tropical)
- bounds_system: egyptian
- triplicity_system: dorothean
- aspect_orb_deg: 3.0
- bodies: SUN, MOON, MERCURY, VENUS, MARS, JUPITER, SATURN
- event_window: past 4.0d / future 30.0d

## Angles

- ASC: 9.28063478 (9°16' Aries)
- MC: 275.45125535 (5°27' Capricorn)
- DSC: 189.28063478 (9°16' Libra)
- IC: 95.45125535 (5°27' Cancer)
- VERTEX: 184.00212512 (4°00' Libra)
- ANTIVERTEX: 4.00212512 (4°00' Aries)
- EQUATORIAL_ASCENDANT: 6.467786 (6°28' Aries)
- ARMC: 275.93811952

## Houses

- H1: cusp 9.28063478 (9°16' Aries), span 40.244692°, ruler MARS
- H2: cusp 49.52532659 (19°31' Taurus), span 26.080427°, ruler VENUS
- H3: cusp 75.60575328 (15°36' Gemini), span 19.845502°, ruler MERCURY
- H4: cusp 95.45125535 (5°27' Cancer), span 20.768887°, ruler MOON
- H5: cusp 116.22014283 (26°13' Cancer), span 29.392183°, ruler MOON
- H6: cusp 145.61232617 (25°36' Leo), span 43.668309°, ruler SUN
- H7: cusp 189.28063478 (9°16' Libra), span 40.244692°, ruler VENUS
- H8: cusp 229.52532659 (19°31' Scorpio), span 26.080427°, ruler MARS
- H9: cusp 255.60575328 (15°36' Sagittarius), span 19.845502°, ruler JUPITER
- H10: cusp 275.45125535 (5°27' Capricorn), span 20.768887°, ruler SATURN
- H11: cusp 296.22014283 (26°13' Capricorn), span 29.392183°, ruler SATURN
- H12: cusp 325.61232617 (25°36' Aquarius), span 43.668309°, ruler SATURN

## Bodies

- SUN: lon 120.76378847 lat -0.0001307 speed 0.95485219°/d | 0°45' Leo | H5 (cont 5.154587) | motion direct
- MOON: lon 234.67683925 lat -5.18492654 speed 11.96280692°/d | 24°40' Scorpio | H8 (cont 8.197524) | motion direct
- MERCURY: lon 106.32250903 lat -4.11923863 speed -0.03346944°/d | 16°19' Cancer | H4 (cont 4.523439) | motion stationary
- VENUS: lon 165.19069534 lat 0.63927105 speed 1.0724447°/d | 15°11' Virgo | H6 (cont 6.448343) | motion direct
- MARS: lon 77.3513067 lat -0.01844731 speed 0.68566638°/d | 17°21' Gemini | H3 (cont 3.087957) | motion direct
- JUPITER: lon 125.10187132 lat 0.46545421 speed 0.22128175°/d | 5°06' Leo | H5 (cont 5.30218) | motion direct
- SATURN: lon 14.74108234 lat -2.48703272 speed 0.00549035°/d | 14°44' Aries | H1 (cont 1.135681) | motion direct

## Dignities

- SUN: domicile=SUN exalt=None bound=JUPITER decan=SATURN trip_active=JUPITER peregrine=False
- MOON: domicile=MARS exalt=None bound=SATURN decan=VENUS trip_active=MARS peregrine=False
- MERCURY: domicile=MOON exalt=JUPITER bound=MERCURY decan=MERCURY trip_active=MARS peregrine=False
- VENUS: domicile=MERCURY exalt=MERCURY bound=JUPITER decan=VENUS trip_active=MOON peregrine=False
- MARS: domicile=MERCURY exalt=None bound=MARS decan=MARS trip_active=MERCURY peregrine=False
- JUPITER: domicile=SUN exalt=None bound=JUPITER decan=SATURN trip_active=JUPITER peregrine=False
- SATURN: domicile=MARS exalt=SUN bound=MERCURY decan=SUN trip_active=JUPITER peregrine=False

## Pairwise Geometry

- JUPITER|MARS: min_sep 47.75056462° rel_speed 0.46438463 nearest sextile Δ12.24943538 within_orb=None
- JUPITER|MERCURY: min_sep 18.77936229° rel_speed -0.25475119 nearest conjunction Δ18.77936229 within_orb=None
- JUPITER|MOON: min_sep 109.57496793° rel_speed 11.74152517 nearest trine Δ10.42503207 within_orb=None
- JUPITER|SATURN: min_sep 110.36078898° rel_speed 0.2157914 nearest trine Δ9.63921102 within_orb=None
- JUPITER|SUN: min_sep 4.33808285° rel_speed 0.73357044 nearest conjunction Δ4.33808285 within_orb=None
- JUPITER|VENUS: min_sep 40.08882402° rel_speed 0.85116295 nearest sextile Δ19.91117598 within_orb=None
- MARS|MERCURY: min_sep 28.97120233° rel_speed -0.71913582 nearest conjunction Δ28.97120233 within_orb=None
- MARS|MOON: min_sep 157.32553255° rel_speed 11.27714054 nearest opposition Δ22.67446745 within_orb=None
- MARS|SATURN: min_sep 62.61022436° rel_speed 0.68017603 nearest sextile Δ2.61022436 within_orb=None
- MARS|SUN: min_sep 43.41248177° rel_speed 0.26918581 nearest sextile Δ16.58751823 within_orb=None
- MARS|VENUS: min_sep 87.83938864° rel_speed 0.38677832 nearest square Δ2.16061136 within_orb=None
- MERCURY|MOON: min_sep 128.35433022° rel_speed 11.99627636 nearest trine Δ8.35433022 within_orb=None
- MERCURY|SATURN: min_sep 91.58142669° rel_speed -0.03895979 nearest square Δ1.58142669 within_orb=None
- MERCURY|SUN: min_sep 14.44127944° rel_speed 0.98832163 nearest conjunction Δ14.44127944 within_orb=None
- MERCURY|VENUS: min_sep 58.86818631° rel_speed -1.10591414 nearest sextile Δ1.13181369 within_orb=None
- MOON|SATURN: min_sep 140.06424309° rel_speed 11.95731657 nearest trine Δ20.06424309 within_orb=None
- MOON|SUN: min_sep 113.91305078° rel_speed -11.00795473 nearest trine Δ6.08694922 within_orb=None
- MOON|VENUS: min_sep 69.48614391° rel_speed 10.89036222 nearest sextile Δ9.48614391 within_orb=None
- SATURN|SUN: min_sep 106.02270613° rel_speed 0.94936184 nearest trine Δ13.97729387 within_orb=None
- SATURN|VENUS: min_sep 150.449613° rel_speed 1.06695435 nearest opposition Δ29.550387 within_orb=None
- SUN|VENUS: min_sep 44.42690687° rel_speed -0.11759251 nearest sextile Δ15.57309313 within_orb=None

## Aspects (in orb)

- JUPITER|MARS|conjunction: orb 47.75056462° applying next_exact=None root=not_found refranation=False
- JUPITER|MARS|opposition: orb 132.24943538° separating next_exact=None root=not_found refranation=False
- JUPITER|MARS|sextile: orb 12.24943538° separating next_exact=None root=not_found refranation=False
- JUPITER|MARS|square: orb 42.24943538° separating next_exact=None root=not_found refranation=False
- JUPITER|MARS|trine: orb 72.24943538° separating next_exact=None root=not_found refranation=False
- JUPITER|MERCURY|conjunction: orb 18.77936229° separating next_exact=2026-08-15T11:22:56Z root=found refranation=False
- JUPITER|MERCURY|opposition: orb 161.22063771° applying next_exact=None root=not_found refranation=False

_(summary excerpt; AI uses full markdown)_
