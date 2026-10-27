import Foundation
import HamburgCore

struct BackendChart {
    let julianDayUT: Double
    let points: [ChartPoint]
    let cusps: [Double]
    let warnings: [String]
    let sunReference: SolarReference?
}

enum BackendError: Error, CustomStringConvertible {
    case missingPaths(String)
    case processFailed(String)
    case invalidOutput(String)
    case backendError(String)

    var description: String {
        switch self {
        case .missingPaths(let message): return message
        case .processFailed(let message): return message
        case .invalidOutput(let message): return message
        case .backendError(let message): return "Backend error: \(message)"
        }
    }
}

struct PythonBackend {
    var pythonExecutable: String
    var backendPath: String

    static func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    static func defaultBackendPath() -> String {
        repositoryRoot()
            .appendingPathComponent("Sources/TransitStudio/Resources/backend/transit_calc.py")
            .path
    }

    static func defaultPython() -> String {
        let root = repositoryRoot()
        let candidates = [
            root.appendingPathComponent(".venv/bin/python").path,
            "/usr/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
        ]
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return "python3"
    }

    func run(
        moment: Moment,
        location: ChartLocation?,
        bodyIDs: [String],
        houseSystem: String,
        zodiac: String
    ) throws -> BackendChart {
        let backendURL = URL(fileURLWithPath: backendPath)
        guard FileManager.default.fileExists(atPath: backendURL.path) else {
            throw BackendError.missingPaths("Python backend not found at \(backendURL.path)")
        }
        let request = makeMomentRequest(
            moment: moment,
            location: location,
            bodyIDs: bodyIDs,
            houseSystem: houseSystem,
            zodiac: zodiac
        )
        let input = try JSONSerialization.data(withJSONObject: request, options: [])
        let output = try execute(input: input)
        return try decode(output: output, fallbackMoment: moment)
    }

    private func makeMomentRequest(
        moment: Moment,
        location: ChartLocation?,
        bodyIDs: [String],
        houseSystem: String,
        zodiac: String
    ) -> [String: Any] {
        let momentDictionary = dictionary(for: moment)
        var request: [String: Any] = [
            "mode": "moment",
            "natal": momentDictionary,
            "transit": momentDictionary,
            "sameChart": true,
            "natalBodies": bodyIDs,
            "transitBodies": bodyIDs,
            "aspects": [],
        ]
        if let location {
            request["birth"] = [
                "moment": momentDictionary,
                "latitude": location.latitude,
                "longitude": location.longitude,
                "houseSystem": houseSystem,
                "zodiac": zodiac,
                "boundsSystem": "egyptian",
                "triplicitySystem": "dorothean",
            ]
        }
        request["point_set"] = [
            "body_ids": bodyIDs.filter { !$0.contains("NODE") },
            "include_nodes": bodyIDs.contains { $0.contains("NODE") },
            "node_mode": "true_node",
            "custom_asteroids": [],
            "angle_ids": ["ASC", "MC"],
            "house_cusps": [],
            "lot_ids": [],
        ]
        return request
    }

    private func dictionary(for moment: Moment) -> [String: Any] {
        var value: [String: Any] = [
            "year": moment.year,
            "month": moment.month,
            "day": moment.day,
            "hour": moment.hour,
            "minute": moment.minute,
            "timezone": moment.timezone,
        ]
        if let second = moment.second { value["second"] = second }
        if let fold = moment.fold { value["fold"] = fold }
        return value
    }

    private func execute(input: Data) throws -> Data {
        let process = Process()
        if pythonExecutable.contains("/") {
            process.executableURL = URL(fileURLWithPath: pythonExecutable)
            process.arguments = [backendPath]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [pythonExecutable, backendPath]
        }

        let standardInput = Pipe()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardInput = standardInput
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            throw BackendError.processFailed("Could not start Python backend: \(error.localizedDescription)")
        }

        standardInput.fileHandleForWriting.write(input)
        standardInput.fileHandleForWriting.closeFile()

        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let errorText = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            throw BackendError.processFailed(
                "Python backend exited with status \(process.terminationStatus). \(errorText)"
            )
        }
        return outputData
    }

    private func decode(output: Data, fallbackMoment: Moment) throws -> BackendChart {
        let response: BackendResponse
        do {
            response = try JSONDecoder().decode(BackendResponse.self, from: output)
        } catch {
            let preview = String(data: output.prefix(500), encoding: .utf8) ?? "<binary>"
            throw BackendError.invalidOutput("Could not decode backend JSON: \(error). Output: \(preview)")
        }
        if let error = response.error, !error.isEmpty {
            throw BackendError.backendError(error)
        }
        guard let rows = response.natalPositions, !rows.isEmpty else {
            throw BackendError.invalidOutput("Backend returned no natal positions.")
        }

        let julianDay = response.meta?.natalUTC.flatMap { try? JulianDay.fromISO8601($0) }
            ?? ((try? fallbackMoment.julianDayUT) ?? 0)

        var points: [ChartPoint] = []
        for row in rows {
            let kind: ChartPoint.Kind = row.bodyID.uppercased().contains("NODE") ? .node : .planet
            points.append(ChartPoint(
                id: row.bodyID,
                name: englishName(row.bodyID, fallback: row.name),
                nameLocal: row.name,
                kind: kind,
                longitude: row.longitude,
                latitude: row.latitude,
                speed: row.speed,
                source: .backend
            ))
        }
        for angle in response.angles ?? [] {
            points.append(ChartPoint(
                id: angle.id,
                name: englishName(angle.id, fallback: angle.name),
                nameLocal: angle.name,
                kind: .angle,
                longitude: angle.longitude,
                latitude: nil,
                speed: nil,
                source: .backend
            ))
        }

        let cusps = (response.houses ?? [])
            .sorted { $0.house < $1.house }
            .map(\.cuspLongitude)
        let sun = rows.first { $0.bodyID == "SUN" }
        let sunReference = sun.map {
            SolarReference(
                longitude: $0.longitude,
                latitude: $0.latitude ?? 0,
                distanceAU: SolarEphemeris.distanceAU(julianDay: julianDay)
            )
        }
        let warnings = (response.warnings ?? []).filter {
            !$0.contains("SOUTH_TRUE_NODE")
        }
        return BackendChart(
            julianDayUT: julianDay,
            points: points,
            cusps: cusps,
            warnings: warnings,
            sunReference: sunReference
        )
    }

    private func englishName(_ id: String, fallback: String) -> String {
        switch id.uppercased() {
        case "SUN": return "Sun"
        case "MOON": return "Moon"
        case "MERCURY": return "Mercury"
        case "VENUS": return "Venus"
        case "MARS": return "Mars"
        case "JUPITER": return "Jupiter"
        case "SATURN": return "Saturn"
        case "URANUS": return "Uranus"
        case "NEPTUNE": return "Neptune"
        case "PLUTO": return "Pluto"
        case "TRUE_NODE", "MEAN_NODE": return "Lunar Node"
        case "ASC": return "Ascendant"
        case "MC": return "Midheaven"
        default: return fallback
        }
    }
}

private struct BackendResponse: Decodable {
    let meta: BackendMeta?
    let natalPositions: [BackendPosition]?
    let angles: [BackendAngle]?
    let houses: [BackendHouse]?
    let warnings: [String]?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case meta, angles, houses, warnings, error
        case natalPositions = "natal_positions"
    }
}

private struct BackendMeta: Decodable {
    let natalUTC: String?

    enum CodingKeys: String, CodingKey {
        case natalUTC = "natal_utc"
    }
}

private struct BackendPosition: Decodable {
    let bodyID: String
    let name: String
    let longitude: Double
    let latitude: Double?
    let speed: Double?

    enum CodingKeys: String, CodingKey {
        case name, longitude, latitude, speed
        case bodyID = "body_id"
    }
}

private struct BackendAngle: Decodable {
    let id: String
    let name: String
    let longitude: Double
}

private struct BackendHouse: Decodable {
    let house: Int
    let cuspLongitude: Double

    enum CodingKeys: String, CodingKey {
        case house
        case cuspLongitude = "cusp_longitude"
    }
}
