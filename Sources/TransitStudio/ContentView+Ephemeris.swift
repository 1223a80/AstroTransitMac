import SwiftUI

extension ContentView {
var normalizedEphemerisPath: String? {
        let trimmed = ephemerisPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
        return bundledEphemerisPath
    }

    var bundledEphemerisPath: String? {
        if let url = AppResources.url(forResource: "seas_18", withExtension: "se1", subdirectory: "ephemeris") {
            return url.deletingLastPathComponent().path
        }
        if let url = AppResources.url(forResource: "seas_18", withExtension: "se1") {
            return url.deletingLastPathComponent().path
        }
        if let bundle = AppResources.bundle {
            let candidate = bundle.bundleURL.appendingPathComponent("ephemeris")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate.path
            }
        }
        return nil
    }

    @MainActor
    func prepareAsteroidsIfNeeded(_ asteroidIDs: [Int]) async throws -> String? {
        guard !asteroidIDs.isEmpty, !noAsteroids, autoDownloadAsteroids else {
            return normalizedEphemerisPath
        }

        asteroidPreparationMessage = "检查小行星星历..."
        let result = try await AsteroidEphemerisManager.ensureAsteroids(
            ids: asteroidIDs,
            configuredEphemerisPath: ephemerisPath,
            bundledEphemerisPath: bundledEphemerisPath,
            requireEphemeris: requireEphemeris
        ) { message in
            await MainActor.run {
                asteroidPreparationMessage = message
            }
        }

        if ephemerisPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let effectivePath = result.effectiveEphemerisPath,
           !effectivePath.isEmpty {
            ephemerisPath = effectivePath
        }

        if result.log.isEmpty {
            asteroidPreparationMessage = "小行星星历已就绪。"
        } else {
            asteroidPreparationMessage = result.log
        }

    return result.effectiveEphemerisPath
}
}
