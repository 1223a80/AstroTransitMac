import Foundation

public enum MomentError: Error, CustomStringConvertible {
    case invalidTimezone(String)
    case invalidDate(String)
    case invalidISO8601(String)

    public var description: String {
        switch self {
        case .invalidTimezone(let value):
            return "Invalid time zone identifier: \(value)"
        case .invalidDate(let value):
            return "Invalid calendar moment: \(value)"
        case .invalidISO8601(let value):
            return "Invalid ISO-8601 instant: \(value)"
        }
    }
}

/// A civil date-time together with an IANA time zone.
///
/// The Python backend accepts exactly these fields. Keeping the same shape
/// lets the CLI forward a request without reinterpreting the user's clock.
public struct Moment: Codable, Hashable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int
    public var hour: Int
    public var minute: Int
    public var second: Int?
    public var timezone: String
    public var fold: Int?

    public init(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int? = nil,
        timezone: String,
        fold: Int? = nil
    ) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.timezone = timezone
        self.fold = fold
    }

    enum CodingKeys: String, CodingKey {
        case year, month, day, hour, minute, second, timezone, fold
    }

    public var date: Date {
        get throws {
            guard let zone = TimeZone(identifier: timezone) else {
                throw MomentError.invalidTimezone(timezone)
            }
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = zone
            var components = DateComponents()
            components.calendar = calendar
            components.timeZone = zone
            components.year = year
            components.month = month
            components.day = day
            components.hour = hour
            components.minute = minute
            components.second = second ?? 0
            components.nanosecond = 0
            guard let date = calendar.date(from: components) else {
                throw MomentError.invalidDate(isoLike)
            }
            let check = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
            guard check.year == year,
                  check.month == month,
                  check.day == day,
                  check.hour == hour,
                  check.minute == minute,
                  (check.second ?? 0) == (second ?? 0) else {
                throw MomentError.invalidDate(isoLike)
            }
            return date
        }
    }

    /// Julian Day in UT. The TNP model is slow enough that the UT/TT
    /// difference (delta T) is far below its astrological precision.
    public var julianDayUT: Double {
        get throws {
            try JulianDay.from(date: date)
        }
    }

    public var isoLike: String {
        String(
            format: "%04d-%02d-%02dT%02d:%02d:%02d[%@]",
            year, month, day, hour, minute, second ?? 0, timezone
        )
    }
}

public enum JulianDay {
    /// Unix epoch 1970-01-01T00:00:00Z as a Julian Day.
    public static let unixEpoch = 2_440_587.5

    public static func from(date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400.0 + unixEpoch
    }

    public static func date(fromJulianDay jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - unixEpoch) * 86_400.0)
    }

    /// Parse the UTC instants emitted by the Python backend, e.g.
    /// `1990-01-01T04:00:00+00:00`.
    public static func fromISO8601(_ value: String) throws -> Double {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: value) {
            return from(date: date)
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: value) {
            return from(date: date)
        }
        throw MomentError.invalidISO8601(value)
    }

    public static func iso8601(fromJulianDay jd: Double, timeZone: TimeZone = .gmt) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = timeZone
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date(fromJulianDay: jd))
    }
}
