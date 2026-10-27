import Foundation
import Testing
import HamburgCore

struct EphemerisTests {
    private struct Fixture: Decodable {
        let samples: [Sample]

        struct Sample: Decodable {
            let label: String
            let jdUT: Double
            let sun: Sun
            let bodies: [String: Body]

            enum CodingKeys: String, CodingKey {
                case label, sun, bodies
                case jdUT = "jd_ut"
            }
        }

        struct Sun: Decodable {
            let longitude: Double
            let latitude: Double
            let distanceAU: Double

            enum CodingKeys: String, CodingKey {
                case longitude, latitude
                case distanceAU = "distance_au"
            }
        }

        struct Body: Decodable {
            let geoLongitude: Double
            let geoLatitude: Double
            let geoDistanceAU: Double
            let helioLongitude: Double
            let helioLatitude: Double
            let helioDistanceAU: Double

            enum CodingKeys: String, CodingKey {
                case geoLongitude = "geo_longitude"
                case geoLatitude = "geo_latitude"
                case geoDistanceAU = "geo_distance_au"
                case helioLongitude = "helio_longitude"
                case helioLatitude = "helio_latitude"
                case helioDistanceAU = "helio_distance_au"
            }
        }
    }

    private func fixture() throws -> Fixture {
        let url = try #require(
            Bundle.module.url(
                forResource: "tnp-reference",
                withExtension: "json",
                subdirectory: "Fixtures"
            )
        )
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    @Test func eightTNPsHaveIndependentElements() {
        #expect(UranianPlanet.allCases.count == 8)
        let names = Set(UranianPlanet.allCases.map(\.displayName))
        #expect(names.count == 8)
        let periods = UranianPlanet.allCases.map(\.periodYears)
        #expect(zip(periods, periods.dropFirst()).allSatisfy { pair in pair.0 < pair.1 })
    }

    @Test func nativeTNPMatchesSwissEphemerisReference() throws {
        let fixture = try fixture()
        #expect(fixture.samples.count >= 3)
        for sample in fixture.samples {
            let solar = SolarReference(
                longitude: sample.sun.longitude,
                latitude: sample.sun.latitude,
                distanceAU: sample.sun.distanceAU
            )
            for planet in UranianPlanet.allCases {
                let expected = try #require(sample.bodies[planet.rawValue])
                let actual = TransneptunianEphemeris.geocentricPosition(
                    planet: planet,
                    julianDay: sample.jdUT,
                    solar: solar,
                    applyLightTime: true
                )
                let longitudeError = Angle.separation(actual.longitude, expected.geoLongitude)
                let latitudeError = abs(actual.latitude - expected.geoLatitude)
                #expect(
                    longitudeError < 0.02,
                    "\(sample.label) \(planet.displayName) geocentric longitude error \(longitudeError)°"
                )
                #expect(
                    latitudeError < 0.02,
                    "\(sample.label) \(planet.displayName) geocentric latitude error \(latitudeError)°"
                )
                #expect(abs(actual.distanceAU - expected.geoDistanceAU) < 0.02)
            }
        }
    }

    @Test func heliocentricTNPMatchesReference() throws {
        let fixture = try fixture()
        for sample in fixture.samples {
            for planet in UranianPlanet.allCases {
                let expected = try #require(sample.bodies[planet.rawValue])
                let actual = TransneptunianEphemeris.heliocentricPosition(
                    planet: planet,
                    julianDay: sample.jdUT
                )
                let longitudeError = Angle.separation(actual.longitude, expected.helioLongitude)
                let latitudeError = abs(actual.latitude - expected.helioLatitude)
                #expect(
                    longitudeError < 0.02,
                    "\(sample.label) \(planet.displayName) heliocentric longitude error \(longitudeError)°"
                )
                #expect(latitudeError < 0.02)
                #expect(abs(actual.length - expected.helioDistanceAU) < 0.001)
            }
        }
    }

    @Test func j2000TNPLongitudesAreStable() {
        let solar = SolarReference(
            longitude: 280.3689196753,
            latitude: 0.0002323265,
            distanceAU: 0.9833276448
        )
        let cupido = TransneptunianEphemeris.geocentricPosition(
            planet: .cupido,
            julianDay: 2_451_545.0,
            solar: solar
        )
        #expect(abs(Angle.signedSeparation(cupido.longitude, 243.89645838)) < 0.02)
        let poseidon = TransneptunianEphemeris.geocentricPosition(
            planet: .poseidon,
            julianDay: 2_451_545.0,
            solar: solar
        )
        #expect(abs(Angle.signedSeparation(poseidon.longitude, 214.558080)) < 0.02)
    }

    @Test func julianDayAndMomentAgree() throws {
        let moment = Moment(
            year: 2000, month: 1, day: 1, hour: 20, minute: 0,
            timezone: "Asia/Shanghai"
        )
        let jd = try moment.julianDayUT
        let parsed = try JulianDay.fromISO8601("2000-01-01T12:00:00+00:00")
        #expect(abs(jd - 2_451_545.0) < 1e-9)
        #expect(abs(parsed - 2_451_545.0) < 1e-9)
    }
}
