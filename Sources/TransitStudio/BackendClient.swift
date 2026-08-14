import Foundation
import OSLog

enum BackendClientError: LocalizedError {
    case scriptNotFound
    case processFailed(String)
    case invalidOutput(String)
    case backendError(String)

    var errorDescription: String? {
        switch self {
        case .scriptNotFound:
            return "找不到 Python 后端脚本。"
        case .processFailed(let message):
            return message
        case .invalidOutput(let output):
            return "Python 后端返回的 JSON 无法解析：\(output)"
        case .backendError(let message):
            return message
        }
    }
}

struct BackendErrorResponse: Decodable {
    let error: String
    let missing: [String]?
    let mode: String?
}

func tryDecodeBackendError(from data: Data) -> BackendClientError? {
    guard let err = try? JSONDecoder().decode(BackendErrorResponse.self, from: data),
          !err.error.isEmpty
    else { return nil }
    return .backendError(err.error)
}

private final class ProcessSharedState: @unchecked Sendable {
    let lock = NSLock()
    var resumed = false
    var terminatedByTimeout = false
    var terminatedByCancellation = false
    var terminationData: Data?
    var terminationError: Data?
    var continuation: CheckedContinuation<Void, Error>?
    var watchdog: Task<Void, Never>?
    var progressMonitor: Task<Void, Never>?
    init() {}

    @discardableResult
    func setContinuation(_ continuation: CheckedContinuation<Void, Error>) -> Bool {
        lock.lock()
        let shouldResume = resumed
        let shouldThrowCancellation = terminatedByCancellation
        if !resumed {
            self.continuation = continuation
        }
        lock.unlock()

        if shouldResume {
            if shouldThrowCancellation {
                continuation.resume(throwing: CancellationError())
            } else {
                continuation.resume()
            }
            return false
        }
        return true
    }

    func finish(outData: Data?, errData: Data?) {
        lock.lock()
        let continuationToResume: CheckedContinuation<Void, Error>?
        let watchdogToCancel: Task<Void, Never>?
        let progressMonitorToCancel: Task<Void, Never>?
        if resumed {
            continuationToResume = nil
            watchdogToCancel = nil
            progressMonitorToCancel = nil
        } else {
            resumed = true
            terminationData = outData
            terminationError = errData
            continuationToResume = continuation
            continuation = nil
            watchdogToCancel = watchdog
            watchdog = nil
            progressMonitorToCancel = progressMonitor
            progressMonitor = nil
        }
        lock.unlock()

        watchdogToCancel?.cancel()
        progressMonitorToCancel?.cancel()
        continuationToResume?.resume()
    }

    func finishLaunchFailure(_ error: Error) {
        lock.lock()
        guard !resumed else {
            lock.unlock()
            return
        }
        resumed = true
        let continuationToResume = continuation
        continuation = nil
        let watchdog = watchdog
        self.watchdog = nil
        let progressMonitor = progressMonitor
        self.progressMonitor = nil
        lock.unlock()

        watchdog?.cancel()
        progressMonitor?.cancel()
        continuationToResume?.resume(throwing: error)
    }

    func setWatchdog(_ task: Task<Void, Never>) {
        lock.lock()
        if resumed {
            lock.unlock()
            task.cancel()
        } else {
            watchdog = task
            lock.unlock()
        }
    }

    func setProgressMonitor(_ task: Task<Void, Never>) {
        lock.lock()
        if resumed {
            lock.unlock()
            task.cancel()
        } else {
            progressMonitor = task
            lock.unlock()
        }
    }

    func finishTimeout() -> Bool {
        lock.lock()
        let continuationToResume: CheckedContinuation<Void, Error>?
        let watchdogToCancel: Task<Void, Never>?
        let progressMonitorToCancel: Task<Void, Never>?
        if resumed {
            continuationToResume = nil
            watchdogToCancel = nil
            progressMonitorToCancel = nil
        } else {
            resumed = true
            terminatedByTimeout = true
            continuationToResume = continuation
            continuation = nil
            watchdogToCancel = watchdog
            watchdog = nil
            progressMonitorToCancel = progressMonitor
            progressMonitor = nil
        }
        lock.unlock()

        watchdogToCancel?.cancel()
        progressMonitorToCancel?.cancel()
        continuationToResume?.resume()
        return continuationToResume != nil
    }

    func finishCancellation() -> Bool {
        lock.lock()
        let continuationToResume: CheckedContinuation<Void, Error>?
        let watchdogToCancel: Task<Void, Never>?
        let progressMonitorToCancel: Task<Void, Never>?
        if resumed {
            continuationToResume = nil
            watchdogToCancel = nil
            progressMonitorToCancel = nil
        } else {
            resumed = true
            terminatedByCancellation = true
            continuationToResume = continuation
            continuation = nil
            watchdogToCancel = watchdog
            watchdog = nil
            progressMonitorToCancel = progressMonitor
            progressMonitor = nil
        }
        lock.unlock()

        watchdogToCancel?.cancel()
        progressMonitorToCancel?.cancel()
        continuationToResume?.resume(throwing: CancellationError())
        return continuationToResume != nil
    }
}

private final class BackendProgressFileMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private let buffer = BackendProgressLineBuffer()
    private var consumedBytes = 0

    func consume(url: URL) -> [BackendProgressUpdate] {
        lock.lock()
        defer { lock.unlock() }
        guard let snapshot = try? Data(contentsOf: url) else { return [] }
        if snapshot.count < consumedBytes {
            consumedBytes = 0
        }
        guard snapshot.count > consumedBytes else { return [] }
        let newData = snapshot.subdata(in: consumedBytes..<snapshot.count)
        consumedBytes = snapshot.count
        return buffer.append(newData)
    }
}

struct BackendClient {
    static func suggestedPythonPath() -> String {
        let candidates = [
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]

        let executableCandidates = candidates.filter {
            FileManager.default.isExecutableFile(atPath: $0)
        }

        for path in executableCandidates where canImportSwisseph(pythonPath: path) {
            return path
        }

        return executableCandidates.first ?? "python3"
    }

    static func swissephStatus(pythonPath: String) async -> String {
        await Task.detached(priority: .utility) {
            canImportSwisseph(pythonPath: pythonPath) ? "已检测到 pyswisseph" : "未检测到 pyswisseph"
        }.value
    }

    private static func canImportSwisseph(pythonPath: String) -> Bool {
        let trimmedPath = pythonPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            return false
        }

        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()

        if trimmedPath.contains("/") {
            guard FileManager.default.isExecutableFile(atPath: trimmedPath) else {
                return false
            }
            process.executableURL = URL(fileURLWithPath: trimmedPath)
            process.arguments = ["-c", "import swisseph"]
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [trimmedPath, "-c", "import swisseph"]
        }

        process.standardOutput = stdout
        process.standardError = stderr
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        process.environment = environment

        do {
            try process.run()
        } catch {
            return false
        }

        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    static func calculate(request: TransitRequest, pythonPath: String) async throws -> TransitResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func scan(request: ScanRequest, pythonPath: String) async throws -> ScanResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func modernTiming(
        request: ModernTimingRequest,
        pythonPath: String,
        progressCallback: (@Sendable (BackendProgressUpdate) -> Void)? = nil
    ) async throws -> ModernTimingResult {
        try await run(request: request, pythonPath: pythonPath, progressCallback: progressCallback)
    }

    static func classical(request: ClassicalRequest, pythonPath: String) async throws -> ClassicalResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func horary(request: HoraryRequest, pythonPath: String) async throws -> HoraryDataPacket {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func kpHorary(request: KPHoraryRequest, pythonPath: String) async throws -> KPHoraryResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func vedic(request: VedicRequest, pythonPath: String) async throws -> VedicResult {
        try await run(request: request, pythonPath: pythonPath)
    }

    static func run<Request: Encodable, Response: Decodable>(
        request: Request,
        pythonPath: String,
        progressCallback: (@Sendable (BackendProgressUpdate) -> Void)? = nil
    ) async throws -> Response {
        let backendTask = Task.detached(priority: .userInitiated) { () async throws -> Response in
            let reqType = type(of: request)
            Logger.backend.debug("run(\(reqType)): starting Task.detached")

            guard let scriptURL = AppResources.url(forResource: "transit_calc", withExtension: "py")
                ?? AppResources.url(forResource: "transit_calc", withExtension: "py", subdirectory: "backend")
            else {
                Logger.backend.error("run(\(reqType)): script not found")
                throw BackendClientError.scriptNotFound
            }

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let payload = try encoder.encode(request)

            let process = Process()
            let stdin = Pipe()
            let temporaryDirectory = FileManager.default.temporaryDirectory
            let stdoutURL = temporaryDirectory.appendingPathComponent("transit-stdout-\(UUID().uuidString).json")
            let stderrURL = temporaryDirectory.appendingPathComponent("transit-stderr-\(UUID().uuidString).txt")

            _ = FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
            _ = FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
            let stdout = try FileHandle(forWritingTo: stdoutURL)
            let stderr = try FileHandle(forWritingTo: stderrURL)
            let progressFileMonitor = BackendProgressFileMonitor()

            let trimmedPath = pythonPath.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedPath.contains("/") {
                process.executableURL = URL(fileURLWithPath: trimmedPath)
                process.arguments = [scriptURL.path]
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = [trimmedPath.isEmpty ? "python3" : trimmedPath, scriptURL.path]
            }

            process.standardInput = stdin
            process.standardOutput = stdout
            process.standardError = stderr
            var environment = ProcessInfo.processInfo.environment
            environment["PYTHONDONTWRITEBYTECODE"] = "1"
            process.environment = environment

            let state = ProcessSharedState()

        process.terminationHandler = { process in
            try? stdout.close()
            try? stderr.close()
            let outData = try? Data(contentsOf: stdoutURL)
            let errData = try? Data(contentsOf: stderrURL)
            if let progressCallback {
                for update in progressFileMonitor.consume(url: stderrURL) {
                    progressCallback(update)
                }
            }
            Logger.backend.debug("terminationHandler: exitCode=\(process.terminationStatus, privacy: .public) outSize=\(outData?.count ?? 0, privacy: .public) errSize=\(errData?.count ?? 0, privacy: .public)")
            try? FileManager.default.removeItem(at: stdoutURL)
            try? FileManager.default.removeItem(at: stderrURL)
            state.finish(outData: outData, errData: errData)
        }

            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    guard state.setContinuation(continuation) else {
                        return
                    }

                    do {
                        Logger.backend.debug("run(\(reqType)): starting process")
                        try process.run()
                        if let progressCallback {
                            let progressTask = Task.detached(priority: .utility) {
                                while !Task.isCancelled {
                                    for update in progressFileMonitor.consume(url: stderrURL) {
                                        progressCallback(update)
                                    }
                                    do {
                                        try await Task.sleep(nanoseconds: 100_000_000)
                                    } catch {
                                        return
                                    }
                                }
                            }
                            state.setProgressMonitor(progressTask)
                        }
                        Logger.backend.debug("run(\(reqType)): process started, writing stdin (\(payload.count) bytes)")
                        stdin.fileHandleForWriting.write(payload)
                        stdin.fileHandleForWriting.closeFile()
                        Logger.backend.debug("run(\(reqType)): stdin written and closed")
                    } catch {
                        try? stdout.close()
                        try? stderr.close()
                        try? FileManager.default.removeItem(at: stdoutURL)
                        try? FileManager.default.removeItem(at: stderrURL)
                        state.finishLaunchFailure(BackendClientError.processFailed("无法启动 Python：\(trimmedPath)\n\(error.localizedDescription)"))
                        return
                    }

                    let watchdog = Task<Void, Never> {
                        do {
                            try await Task.sleep(nanoseconds: 300_000_000_000)
                        } catch {
                            return
                        }
                        if state.finishTimeout() {
                            process.terminate()
                            try? stdout.close()
                            try? stderr.close()
                            try? FileManager.default.removeItem(at: stdoutURL)
                            try? FileManager.default.removeItem(at: stderrURL)
                        }
                    }
                    state.setWatchdog(watchdog)
                }
            } onCancel: {
                _ = state.finishCancellation()
                if process.isRunning {
                    process.terminate()
                }
                try? stdout.close()
                try? stderr.close()
                try? FileManager.default.removeItem(at: stdoutURL)
                try? FileManager.default.removeItem(at: stderrURL)
            }

            if state.terminatedByTimeout {
                throw BackendClientError.processFailed("Python 后端执行超时（超过 300 秒）。")
            }

            let outputData = state.terminationData ?? Data()
            let errorData = state.terminationError ?? Data()
            let outputText = String(data: outputData, encoding: .utf8) ?? ""
            let errorText = String(data: errorData, encoding: .utf8) ?? ""

            guard process.terminationStatus == 0 else {
                let message = errorText.isEmpty ? outputText : errorText
                let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                Logger.backend.error("processFailed: status=\(process.terminationStatus, privacy: .public) messageSize=\(trimmed.count, privacy: .public)")
                Logger.backend.error("processFailed details: \(trimmed.prefix(2000), privacy: .public)")
                throw BackendClientError.processFailed(
                    "Python：\(trimmedPath)\n\(trimmed)"
                )
            }

        if let backendError = tryDecodeBackendError(from: outputData) {
            throw backendError
        }

        do {
            return try JSONDecoder().decode(Response.self, from: outputData)
        } catch {
            let preview = String(outputText.prefix(500))
            let details = String(describing: error)
            Logger.backend.error("JSON decode failed for \(type(of: Response.self)): \(details, privacy: .public)")
            Logger.backend.error("JSON preview: \(preview, privacy: .public)")
            throw BackendClientError.invalidOutput(
                "\(details)\nJSON preview:\n\(preview)"
            )
        }
        }

        return try await withTaskCancellationHandler {
            try await backendTask.value
        } onCancel: {
            backendTask.cancel()
        }
    }
}
