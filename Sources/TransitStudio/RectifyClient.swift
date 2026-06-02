import Foundation

enum RectifyClient {
    static let defaultTimeoutSeconds: Double = 60

    static func fetch<T: Encodable>(
        request: T,
        pythonPath: String,
        progressCallback: (@Sendable (Double) -> Void)? = nil
    ) async throws -> RectifyResponse {
        guard let scriptURL = AppResources.url(forResource: "transit_calc", withExtension: "py")
            ?? AppResources.url(forResource: "transit_calc", withExtension: "py", subdirectory: "backend")
        else {
            throw BackendClientError.scriptNotFound
        }

        let encoder = JSONEncoder()
        let payload = try encoder.encode(request)

        let tmpDir = FileManager.default.temporaryDirectory
        let stdoutURL = tmpDir.appendingPathComponent("rectify-out-\(UUID().uuidString).json")

        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)

        let process = Process()
        let stdin = Pipe()
        let stderrPipe = Pipe()

        let trimmedPath = pythonPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedPath.contains("/") {
            process.executableURL = URL(fileURLWithPath: trimmedPath)
            process.arguments = [scriptURL.path]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [trimmedPath.isEmpty ? "python3" : trimmedPath, scriptURL.path]
        }

        process.standardInput = stdin
        process.standardOutput = stdoutHandle
        process.standardError = stderrPipe

        return try await withCheckedThrowingContinuation { continuation in
            let guardState = ContinuationGuard()
            var stderrAccumulator = Data()
            let stderrLock = NSLock()

            // Read stderr in real time for progress callbacks
            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                stderrLock.lock()
                stderrAccumulator.append(data)
                stderrLock.unlock()
                if let str = String(data: data, encoding: .utf8) {
                    for line in str.components(separatedBy: "\n") {
                        guard !line.isEmpty,
                              let json = try? JSONSerialization.jsonObject(with: Data(line.utf8)),
                              let dict = json as? [String: Any],
                              let p = dict["progress"] as? Double
                        else { continue }
                        progressCallback?(p)
                    }
                }
            }

            // Timeout watchdog
            Task {
                try? await Task.sleep(nanoseconds: UInt64(defaultTimeoutSeconds * 1_000_000_000))
                if guardState.tryResume() {
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    process.terminate()
                    stdoutHandle.closeFile()
                    try? FileManager.default.removeItem(at: stdoutURL)
                    continuation.resume(throwing: BackendClientError.processFailed(
                        "Python 后端执行超时（超过 \(Int(defaultTimeoutSeconds)) 秒）。"
                    ))
                }
            }

            process.terminationHandler = { proc in
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                stdoutHandle.closeFile()

                let outData = (try? Data(contentsOf: stdoutURL)) ?? Data()
                stderrLock.lock()
                let errData = stderrAccumulator
                stderrLock.unlock()

                try? FileManager.default.removeItem(at: stdoutURL)

                guard guardState.tryResume() else { return }

                if proc.terminationStatus != 0 {
                    let msg = String(data: errData, encoding: .utf8) ?? "Unknown error"
                    continuation.resume(throwing: BackendClientError.processFailed(msg))
                    return
                }

                if let backendError = tryDecodeBackendError(from: outData) {
                    continuation.resume(throwing: backendError)
                    return
                }

                do {
                    let response = try JSONDecoder().decode(RectifyResponse.self, from: outData)
                    continuation.resume(returning: response)
                } catch {
                    let raw = String(data: outData, encoding: .utf8) ?? "<binary>"
                    continuation.resume(throwing: BackendClientError.invalidOutput(raw))
                }
            }

            do {
                try process.run()
                stdin.fileHandleForWriting.write(payload)
                stdin.fileHandleForWriting.closeFile()
            } catch {
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                guardState.tryResume()
                stdoutHandle.closeFile()
                try? FileManager.default.removeItem(at: stdoutURL)
                continuation.resume(throwing: BackendClientError.processFailed(error.localizedDescription))
            }
        }
    }
}

private final class ContinuationGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func tryResume() -> Bool {
        lock.lock()
        if resumed {
            lock.unlock()
            return false
        }
        resumed = true
        lock.unlock()
        return true
    }
}
