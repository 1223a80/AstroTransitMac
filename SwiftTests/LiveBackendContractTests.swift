import Foundation
import Testing
@testable import TransitStudio

/// Opt-in integration gate: executes the currently built backend through the
/// production transport, then decodes into the same models used by the UI.
/// Snapshot fixtures alone cannot detect a changed backend payload.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["TRANSIT_LIVE_CONTRACTS"] == "1"))
struct LiveBackendContractTests {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()

    static let samples: [String] = (try? FileManager.default.contentsOfDirectory(
        atPath: root.appendingPathComponent("Examples").path
    ))?.filter { $0.hasSuffix(".json") }.sorted() ?? []

    @Test func sampleInventoryIsPresent() {
        #expect(!Self.samples.isEmpty)
        #expect(Self.samples.contains("sample-solar-arc-request.json"))
    }

    @Test(arguments: Self.samples)
    func decodeCurrentBackend(sample: String) async throws {
        let data = try Data(contentsOf: Self.root.appendingPathComponent("Examples/" + sample))
        let request = try JSONDecoder().decode(HoraryV2JSONValue.self, from: data)
        let mode = try #require(request.string("mode"))
        let python = ProcessInfo.processInfo.environment["TRANSIT_TEST_PYTHON"]
            ?? BackendClient.suggestedPythonPath()

        func decode<T: Decodable>(_ type: T.Type) async throws {
            let _: T = try await BackendClient.run(request: request, pythonPath: python)
        }

        switch mode {
        case "moment": try await decode(TransitResult.self)
        case "scan": try await decode(ScanResult.self)
        case "classical": try await decode(ClassicalResult.self)
        case "horary": try await decode(HoraryDataPacket.self)
        case "kp_horary": try await decode(KPHoraryResult.self)
        case "vedic": try await decode(VedicResult.self)
        case "rectify": try await decode(RectifyResponse.self)
        case "rectify_evidence": try await decode(RectificationEvidenceResponse.self)
        case "synastry": try await decode(SynastryResult.self)
        case "composite": try await decode(CompositeResult.self)
        case "davison": try await decode(DavisonResult.self)
        case "progression": try await decode(ProgressionResult.self)
        case "solar_arc": try await decode(SolarArcResult.self)
        case "harmonic": try await decode(HarmonicResult.self)
        case "modern_return": try await decode(ModernReturnResult.self)
        case "modern_timing": try await decode(ModernTimingResult.self)
        case "midpoint": try await decode(MidpointResult.self)
        case "progressed_composite": try await decode(ProgressedCompositeResult.self)
        case "relocation": try await decode(RelocationResult.self)
        case "modern_cycles": try await decode(ModernCyclesResult.self)
        case "declination_timing": try await decode(DeclinationTimingResult.self)
        case "retrograde_cycles": try await decode(RetrogradeCyclesResult.self)
        case "classical_visibility": try await decode(ClassicalVisibilityResult.self)
        case "planetary_synodic": try await decode(PlanetarySynodicResult.self)
        case "hellenistic_condition_audit": try await decode(HellenisticConditionAuditResult.self)
        case "draconic_heliocentric": try await decode(DraconicHeliocentricResult.self)
        case "classical_derivatives": try await decode(ClassicalDerivativesResult.self)
        case "time_lords_extended": try await decode(TimeLordsExtendedResult.self)
        case "method_families": try await decode(MethodFamiliesResult.self)
        case "primary_directions_audit": try await decode(PrimaryDirectionsAuditResult.self)
        case "distributions_pd": try await decode(DistributionsPdResult.self)
        case "prenatal_parans": try await decode(PrenatalParansResult.self)
        case "orbital_dial": try await decode(OrbitalDialResult.self)
        case "mundane_electional": try await decode(MundaneElectionalResult.self)
        case "astrocartography": try await decode(AstrocartographyResult.self)
        case "local_space": try await decode(LocalSpaceResult.self)
        default:
            Issue.record("No frontend decoder registered for sample \(sample), mode \(mode)")
        }
    }
}
