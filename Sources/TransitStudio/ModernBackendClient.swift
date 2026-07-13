import Foundation

extension BackendClient {
    static func synastry(request: SynastryRequest, pythonPath: String) async throws -> SynastryResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func composite(request: CompositeRequest, pythonPath: String) async throws -> CompositeResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func davison(request: DavisonRequest, pythonPath: String) async throws -> DavisonResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func progression(request: ProgressionRequest, pythonPath: String) async throws -> ProgressionResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func solarArc(request: SolarArcRequest, pythonPath: String) async throws -> SolarArcResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func harmonic(request: HarmonicRequest, pythonPath: String) async throws -> HarmonicResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func modernReturn(request: ModernReturnRequest, pythonPath: String) async throws -> ModernReturnResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func midpoint(request: MidpointRequest, pythonPath: String) async throws -> MidpointResult {
        try await run(request: request, pythonPath: pythonPath)
    }
}
