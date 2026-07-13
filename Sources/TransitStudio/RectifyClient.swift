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

        let payload = try JSONEncoder().encode(request)
        let stdoutURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rectify-out-\(UUID().uuidString).json")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)

        let process = Process()
        let stdin = Pipe()
        let stderrPipe = Pipe()
        let stderrBuffer = RectifyStderrBuffer()
        let resources = RectifyProcessResources(
            process: process,
            stderrPipe: stderrPipe,
            stdoutHandle: stdoutHandle,
            stdoutURL: stdoutURL
        )
        let state = RectifyContinuationState()

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
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        process.environment = environment

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard state.install(continuation) else { return }

                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    for progress in stderrBuffer.append(data) {
                        progressCallback?(progress)
                    }
                }

                process.terminationHandler = { proc in
                    let outData = (try? Data(contentsOf: stdoutURL)) ?? Data()
                    let errData = stderrBuffer.allData()
                    resources.cleanup(terminate: false)

                    guard proc.terminationStatus == 0 else {
                        let message = String(data: errData, encoding: .utf8) ?? "Unknown error"
                        state.finish(.failure(BackendClientError.processFailed(message)))
                        return
                    }
                    if let backendError = tryDecodeBackendError(from: outData) {
                        state.finish(.failure(backendError))
                        return
                    }
                    do {
                        state.finish(.success(try JSONDecoder().decode(RectifyResponse.self, from: outData)))
                    } catch {
                        let raw = String(data: outData, encoding: .utf8) ?? "<binary>"
                        state.finish(.failure(BackendClientError.invalidOutput(raw)))
                    }
                }

                let watchdog = Task {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(defaultTimeoutSeconds * 1_000_000_000))
                    } catch {
                        return
                    }
                    resources.cleanup(terminate: true)
                    state.finish(.failure(BackendClientError.processFailed(
                        "Python 后端执行超时（超过 \(Int(defaultTimeoutSeconds)) 秒）。"
                    )))
                }
                state.setWatchdog(watchdog)

                do {
                    try process.run()
                    if Task.isCancelled {
                        resources.cleanup(terminate: true)
                        state.finish(.failure(CancellationError()))
                        return
                    }
                    stdin.fileHandleForWriting.write(payload)
                    stdin.fileHandleForWriting.closeFile()
                } catch {
                    resources.cleanup(terminate: true)
                    state.finish(.failure(BackendClientError.processFailed(error.localizedDescription)))
                }
            }
        } onCancel: {
            resources.cleanup(terminate: true)
            state.finish(.failure(CancellationError()))
        }
    }
}

private final class RectifyContinuationState: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<RectifyResponse, Error>?
    private var terminalResult: Result<RectifyResponse, Error>?
    private var watchdog: Task<Void, Never>?

    func install(_ continuation: CheckedContinuation<RectifyResponse, Error>) -> Bool {
        lock.lock()
        if let result = terminalResult {
            lock.unlock()
            continuation.resume(with: result)
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func setWatchdog(_ task: Task<Void, Never>) {
        lock.lock()
        if terminalResult == nil {
            watchdog = task
            lock.unlock()
        } else {
            lock.unlock()
            task.cancel()
        }
    }

    func finish(_ result: Result<RectifyResponse, Error>) {
        lock.lock()
        guard terminalResult == nil else {
            lock.unlock()
            return
        }
        terminalResult = result
        let continuation = continuation
        self.continuation = nil
        let watchdog = watchdog
        self.watchdog = nil
        lock.unlock()

        watchdog?.cancel()
        continuation?.resume(with: result)
    }
}

private final class RectifyProcessResources: @unchecked Sendable {
    private let lock = NSLock()
    private let process: Process
    private let stderrPipe: Pipe
    private let stdoutHandle: FileHandle
    private let stdoutURL: URL
    private var cleaned = false

    init(process: Process, stderrPipe: Pipe, stdoutHandle: FileHandle, stdoutURL: URL) {
        self.process = process
        self.stderrPipe = stderrPipe
        self.stdoutHandle = stdoutHandle
        self.stdoutURL = stdoutURL
    }

    func cleanup(terminate: Bool) {
        lock.lock()
        guard !cleaned else {
            lock.unlock()
            return
        }
        cleaned = true
        lock.unlock()

        stderrPipe.fileHandleForReading.readabilityHandler = nil
        process.terminationHandler = nil
        if terminate, process.isRunning {
            process.terminate()
        }
        try? stdoutHandle.close()
        try? FileManager.default.removeItem(at: stdoutURL)
    }
}

final class RectifyStderrBuffer: @unchecked Sendable {
    private let sharedBuffer = BackendProgressLineBuffer()

    func append(_ data: Data) -> [Double] {
        sharedBuffer.append(data).map(\.progress)
    }

    func allData() -> Data {
        sharedBuffer.allData()
    }
}
