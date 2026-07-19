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

    static func progressedComposite(
        request: ProgressedCompositeRequest,
        pythonPath: String
    ) async throws -> ProgressedCompositeResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func relocation(request: RelocationRequest, pythonPath: String) async throws -> RelocationResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func modernCycles(request: ModernCyclesRequest, pythonPath: String) async throws -> ModernCyclesResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func declinationTiming(
        request: DeclinationTimingRequest,
        pythonPath: String
    ) async throws -> DeclinationTimingResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func retrogradeCycles(
        request: RetrogradeCyclesRequest,
        pythonPath: String
    ) async throws -> RetrogradeCyclesResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func classicalVisibility(
        request: ClassicalVisibilityRequest,
        pythonPath: String
    ) async throws -> ClassicalVisibilityResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func astrocartography(
        request: AstrocartographyRequest,
        pythonPath: String
    ) async throws -> AstrocartographyResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func localSpace(request: LocalSpaceRequest, pythonPath: String) async throws -> LocalSpaceResult {
        try await run(request: request, pythonPath: pythonPath)
    }
}
