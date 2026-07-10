import Foundation
import Testing
@testable import TransitStudio

struct AuditP1RequestTests {
    private let moment = ChartMoment(
        year: 1990,
        month: 1,
        day: 1,
        hour: 12,
        minute: 0,
        timezone: "GMT+8"
    )

    @Test func dateTimeFormatterUsesSelectedTimeZone() throws {
        let utcPlusEight = try #require(TimeZone(secondsFromGMT: 8 * 3600))
        let formatter = DateTimeInput.makeFormatter(timeZone: utcPlusEight)
        let epoch = Date(timeIntervalSince1970: 0)

        #expect(formatter.string(from: epoch) == "1970-01-01 08:00")
        #expect(formatter.date(from: "1970-01-01 08:00") == epoch)
    }

    @Test func momentRequestEncodesSameChartFlag() throws {
        let request = TransitRequest(
            mode: "moment",
            natal: moment,
            transit: moment,
            birth: nil,
            natalBodies: ["SUN"],
            transitBodies: ["SUN"],
            customAsteroids: [],
            aspects: [],
            ephemerisPath: nil,
            noAsteroids: false,
            requireEphemeris: "warn",
            sameChart: true
        )

        let dict = try encodedDictionary(request)
        #expect(dict["sameChart"] as? Bool == true)
    }

    @Test func scanRequestEncodesZodiac() throws {
        let request = ScanRequest(
            mode: "scan",
            scanKind: "aspect",
            label: "test",
            start: moment,
            end: moment,
            transitBodies: ["SUN"],
            customAsteroids: [],
            aspects: [],
            targetText: "Sun = 0",
            ephemerisPath: nil,
            noAsteroids: false,
            requireEphemeris: "warn",
            moonFilter: "include",
            confirmedHeavyScan: false,
            zodiac: "sidereal_lahiri"
        )

        let dict = try encodedDictionary(request)
        #expect(dict["zodiac"] as? String == "sidereal_lahiri")
    }

    private func encodedDictionary<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
