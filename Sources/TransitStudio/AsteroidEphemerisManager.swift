import Foundation

enum AsteroidEphemerisError: LocalizedError {
    case invalidAsteroidID(Int)
    case downloadFailed(Int, String)

    var errorDescription: String? {
        switch self {
        case .invalidAsteroidID(let id):
            return "小行星编号无效：\(id)"
        case .downloadFailed(let id, let reason):
            return "小行星 \(id) 下载失败：\(reason)"
        }
    }
}

struct AsteroidEphemerisResult {
    let effectiveEphemerisPath: String?
    let existing: [Int]
    let downloaded: [Int]
    let failed: [Int]
    let log: String
}

struct AsteroidEphemerisManager {
    /// 推荐的小行星星历目录（中性、非个人路径）。
    /// 优先使用用户配置；否则回落到 ~/Library/Application Support/TransitStudio/ephe
    static var recommendedEphemerisPath: String {
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return appSupport.appendingPathComponent("TransitStudio/ephe", isDirectory: true).path
        }
        // 极端回退（极少发生）
        return NSHomeDirectory() + "/Library/Application Support/TransitStudio/ephe"
    }

    /// 旧名称保留兼容（内部已指向推荐路径）。不要再硬编码个人路径。
    @available(*, deprecated, renamed: "recommendedEphemerisPath")
    static var defaultEphemerisPath: String { recommendedEphemerisPath }

    private static let baseURL = "https://www.dropbox.com/scl/fo/y3naz62gy6f6qfrhquu7u/h/all_ast"
    private static let key = "rlkey=ejltdhb262zglm7eo6yfj2940&dl=1"

    static func ensureAsteroids(
        ids: [Int],
        configuredEphemerisPath: String,
        bundledEphemerisPath: String?,
        requireEphemeris: String,
        progress: (@Sendable (String) async -> Void)? = nil
    ) async throws -> AsteroidEphemerisResult {
        let uniqueIDs = Array(Set(ids)).sorted()
        let configuredPath = configuredEphemerisPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uniqueIDs.isEmpty else {
            return AsteroidEphemerisResult(
                effectiveEphemerisPath: configuredPath.isEmpty ? bundledEphemerisPath : configuredPath,
                existing: [],
                downloaded: [],
                failed: [],
                log: ""
            )
        }

        let targetPath = configuredPath.isEmpty ? recommendedEphemerisPath : configuredPath
        let targetRoot = URL(fileURLWithPath: targetPath, isDirectory: true)
        try FileManager.default.createDirectory(at: targetRoot, withIntermediateDirectories: true)
        try copyBundledBaseEphemeris(from: bundledEphemerisPath, to: targetRoot)

        var existing: [Int] = []
        var downloaded: [Int] = []
        var failed: [Int] = []
        var logLines: [String] = []

        for id in uniqueIDs {
            guard id > 0 else {
                throw AsteroidEphemerisError.invalidAsteroidID(id)
            }

            let fileURL = asteroidFileURL(for: id, root: targetRoot)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                existing.append(id)
                continue
            }

            await progress?("下载小行星 \(id)...")
            do {
                try await downloadAsteroid(id, to: fileURL)
                downloaded.append(id)
                logLines.append("Downloaded asteroid \(id) -> \(fileURL.path)")
            } catch {
                failed.append(id)
                logLines.append("Failed asteroid \(id): \(error.localizedDescription)")
                if requireEphemeris == "strict" {
                    throw AsteroidEphemerisError.downloadFailed(id, error.localizedDescription)
                }
            }
        }

        let summary = summaryText(existing: existing, downloaded: downloaded, failed: failed)
        if !summary.isEmpty {
            logLines.insert(summary, at: 0)
        }

        return AsteroidEphemerisResult(
            effectiveEphemerisPath: targetPath,
            existing: existing,
            downloaded: downloaded,
            failed: failed,
            log: logLines.joined(separator: "\n")
        )
    }

    static func asteroidFileURL(for id: Int, root: URL) -> URL {
        let directory = root.appendingPathComponent("ast\(id / 1000)", isDirectory: true)
        let filename = String(format: "se%05ds.se1", id)
        return directory.appendingPathComponent(filename)
    }

    static func command(for ids: [Int], ephemerisPath: String) -> String {
        let targetPath = ephemerisPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? recommendedEphemerisPath
            : ephemerisPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let idText = Array(Set(ids)).sorted().map(String.init).joined(separator: " ")
        return """
        EPHE="\(targetPath)"
        BASE="\(baseURL)"
        KEY="\(key)"

        mkdir -p "$EPHE"

        for id in \(idText); do
          ast=$((id / 1000))
          file=$(printf "se%05ds.se1" "$id")
          mkdir -p "$EPHE/ast$ast"
          echo "Downloading asteroid $id -> $EPHE/ast$ast/$file"
          curl -L --fail --retry 3 -o "$EPHE/ast$ast/$file" "$BASE/ast$ast/$file?$KEY"
        done

        echo "Done."
        find "$EPHE" -name "se*.se1" | sort
        """
    }

    private static func copyBundledBaseEphemeris(from bundledPath: String?, to targetRoot: URL) throws {
        guard let bundledPath, !bundledPath.isEmpty else {
            return
        }

        let sourceRoot = URL(fileURLWithPath: bundledPath, isDirectory: true)
        let targetStandardized = targetRoot.standardizedFileURL.path
        let sourceStandardized = sourceRoot.standardizedFileURL.path
        guard targetStandardized != sourceStandardized else {
            return
        }

        for filename in ["seas_18.se1", "semo_18.se1", "sepl_18.se1"] {
            let source = sourceRoot.appendingPathComponent(filename)
            let target = targetRoot.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: source.path),
               !FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.copyItem(at: source, to: target)
            }
        }
    }

    private static func downloadAsteroid(_ id: Int, to fileURL: URL) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let asteroidDirectory = "ast\(id / 1000)"
        let filename = String(format: "se%05ds.se1", id)
        guard let url = URL(string: "\(baseURL)/\(asteroidDirectory)/\(filename)?\(key)") else {
            throw AsteroidEphemerisError.downloadFailed(id, "下载地址无效")
        }

        let (temporaryURL, response) = try await URLSession.shared.download(from: url)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            throw AsteroidEphemerisError.downloadFailed(id, "HTTP \(httpResponse.statusCode)")
        }

        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
    }

    private static func summaryText(existing: [Int], downloaded: [Int], failed: [Int]) -> String {
        var parts: [String] = []
        if !existing.isEmpty {
            parts.append("已存在：\(existing.map(String.init).joined(separator: ", "))")
        }
        if !downloaded.isEmpty {
            parts.append("已下载：\(downloaded.map(String.init).joined(separator: ", "))")
        }
        if !failed.isEmpty {
            parts.append("下载失败：\(failed.map(String.init).joined(separator: ", "))")
        }
        return parts.joined(separator: "\n")
    }
}
