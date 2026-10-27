import Darwin
import Foundation
import HamburgCore

enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case unsupported(String)
    case invalidRequest(String)

    var description: String {
        switch self {
        case .usage(let message): return message
        case .unsupported(let message): return message
        case .invalidRequest(let message): return message
        }
    }
}

struct CLIOptions {
    var requestPath: String?
    var format: String = "json"
    var outputPath: String?
    var pythonPath: String?
    var backendPath: String?
    var usePython: Bool = true
}

func usage() -> String {
    """
    hamburg — native Hamburg / Uranian astrology backend for TransitStudio

    Usage:
      hamburg --request request.json [--format json|markdown] [--output FILE]
      cat request.json | hamburg [--format json|markdown]
      hamburg --request request.json --no-python   # points must be supplied in the request

    Options:
      -r, --request PATH     Read the JSON request from PATH (default: stdin).
      -f, --format FORMAT    json (default) or markdown.
      -o, --output PATH      Write the report to PATH instead of stdout.
          --python PATH      Python interpreter used for the existing backend.
          --backend PATH     Path to transit_calc.py.
          --no-python        Never start Python; use the request's points/angles/houses.
      -h, --help             Show this help.

    The standard planets, houses and ASC/MC are obtained from the existing
    Python backend. The eight TNPs, dials, midpoint trees, planetary pictures,
    solar arc and antiscia are computed natively in Swift.
    """
}

func parseArguments(_ arguments: [String]) throws -> CLIOptions {
    var options = CLIOptions()
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "-h", "--help":
            print(usage())
            exit(0)
        case "-r", "--request":
            index += 1
            guard index < arguments.count else { throw CLIError.usage("--request requires a path") }
            options.requestPath = arguments[index]
        case "-f", "--format":
            index += 1
            guard index < arguments.count else { throw CLIError.usage("--format requires a value") }
            options.format = arguments[index].lowercased()
        case "-o", "--output":
            index += 1
            guard index < arguments.count else { throw CLIError.usage("--output requires a path") }
            options.outputPath = arguments[index]
        case "--python":
            index += 1
            guard index < arguments.count else { throw CLIError.usage("--python requires a path") }
            options.pythonPath = arguments[index]
        case "--backend":
            index += 1
            guard index < arguments.count else { throw CLIError.usage("--backend requires a path") }
            options.backendPath = arguments[index]
        case "--no-python":
            options.usePython = false
        default:
            throw CLIError.usage("Unknown argument: \(argument)\n\n\(usage())")
        }
        index += 1
    }
    guard options.format == "json" || options.format == "markdown" else {
        throw CLIError.usage("--format must be 'json' or 'markdown'")
    }
    return options
}

func readInput(path: String?) throws -> Data {
    guard let path, path != "-" else {
        return FileHandle.standardInput.readDataToEndOfFile()
    }
    return try Data(contentsOf: URL(fileURLWithPath: path))
}

func buildChart(
    request: CLIRequest,
    options: CLIOptions
) throws -> (chart: HamburgChart, referenceJulianDay: Double?, engineOptions: HamburgOptions) {
    if let zodiac = request.zodiac, zodiac != "tropical" {
        throw CLIError.unsupported(
            "This native Hamburg core currently accepts tropical positions only; got zodiac=\(zodiac)."
        )
    }

    var julianDay: Double
    if let supplied = request.julianDayUT {
        guard supplied.isFinite else { throw CLIError.invalidRequest("julian_day_ut must be finite") }
        julianDay = supplied
    } else if let moment = request.moment {
        julianDay = try moment.julianDayUT
    } else {
        throw CLIError.invalidRequest("Supply either moment or julian_day_ut.")
    }

    var points: [ChartPoint] = []
    var backendCusps: [Double] = []
    var warnings: [String] = []
    var sunReference: SolarReference?

    if let suppliedPoints = request.points, !suppliedPoints.isEmpty {
        points = suppliedPoints.map { $0.chartPoint() }
        points += (request.angles ?? []).map { $0.chartPoint() }
        backendCusps = request.houses ?? []
        if let sun = points.first(where: { $0.id == "SUN" }) {
            sunReference = SolarReference(
                longitude: sun.longitude,
                latitude: sun.latitude ?? 0,
                distanceAU: SolarEphemeris.distanceAU(julianDay: julianDay)
            )
        }
    } else {
        guard options.usePython else {
            throw CLIError.invalidRequest("No points were supplied and --no-python was requested.")
        }
        guard let moment = request.moment else {
            throw CLIError.invalidRequest("The Python backend path requires a moment.")
        }
        if let location = request.location,
           location.latitude == nil || location.longitude == nil {
            throw CLIError.invalidRequest("location.latitude and location.longitude are required for the backend.")
        }
        let backend = PythonBackend(
            pythonExecutable: options.pythonPath ?? PythonBackend.defaultPython(),
            backendPath: options.backendPath ?? PythonBackend.defaultBackendPath()
        )
        let result = try backend.run(
            moment: moment,
            location: request.effectiveLocation,
            bodyIDs: request.effectiveBodyIDs,
            houseSystem: request.backendHouseSystem,
            zodiac: request.zodiac ?? "tropical"
        )
        points = result.points
        backendCusps = result.cusps
        warnings = result.warnings
        sunReference = result.sunReference
        // Prefer the backend's own UTC instant so DST folds and second-level
        // rounding cannot make native TNPs disagree with Swiss Ephemeris.
        if request.julianDayUT == nil,
           result.julianDayUT.isFinite,
           result.julianDayUT > 0 {
            julianDay = result.julianDayUT
        }
    }

    var engineOptions = request.options ?? HamburgOptions()
    if request.reference == nil && request.referenceJulianDayUT == nil {
        // Solar arc needs an explicit reference instant. Omitting it is a
        // normal "natal only" request, not a degraded calculation.
        engineOptions.solarArcEnabled = false
    }

    let requestedHouseSystem = request.location?.houseSystem ?? "hamburg"
    let houseAssignment = request.houseAssignment
        ?? (requestedHouseSystem == "hamburg" ? .hamburg : .backend)

    let chart = HamburgChart.addingTransneptunians(
        to: points,
        julianDayUT: julianDay,
        moment: request.moment,
        location: request.effectiveLocation,
        backendCusps: backendCusps,
        houseAssignment: houseAssignment,
        includeAriesPoint: true,
        warnings: warnings,
        solar: sunReference,
        applyLightTime: engineOptions.applyTNPlightTime
    )

    let referenceJulianDay: Double?
    if let supplied = request.referenceJulianDayUT {
        guard supplied.isFinite else {
            throw CLIError.invalidRequest("reference_julian_day_ut must be finite")
        }
        referenceJulianDay = supplied
    } else if let reference = request.reference {
        referenceJulianDay = try reference.julianDayUT
    } else {
        referenceJulianDay = nil
    }
    return (chart, referenceJulianDay, engineOptions)
}

func write(_ data: Data, to path: String?) throws {
    if let path {
        let url = URL(fileURLWithPath: path)
        try data.write(to: url, options: .atomic)
    } else {
        FileHandle.standardOutput.write(data)
        if data.last != 0x0A {
            FileHandle.standardOutput.write(Data([0x0A]))
        }
    }
}

do {
    let cliOptions = try parseArguments(Array(CommandLine.arguments.dropFirst()))
    let input = try readInput(path: cliOptions.requestPath)
    let request: CLIRequest
    do {
        request = try JSONDecoder().decode(CLIRequest.self, from: input)
    } catch {
        throw CLIError.invalidRequest("Could not decode request JSON: \(error)")
    }

    let built = try buildChart(request: request, options: cliOptions)
    let engine = HamburgEngine(options: built.engineOptions)
    let report = engine.report(
        chart: built.chart,
        referenceJulianDay: built.referenceJulianDay,
        referenceMoment: request.reference
    )

    let data: Data
    if cliOptions.format == "markdown" {
        data = Data(HamburgMarkdownRenderer.render(report).utf8)
    } else {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        data = try encoder.encode(report)
    }
    try write(data, to: cliOptions.outputPath)
} catch {
    let message: String
    if let cliError = error as? CLIError {
        message = cliError.description
    } else {
        message = String(describing: error)
    }
    FileHandle.standardError.write(Data(("hamburg: \(message)\n").utf8))
    exit(1)
}
